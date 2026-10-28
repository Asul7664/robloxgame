-- Real Roblox instances and XML round-trip: no network avatar assets required.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local R=require("@lune/roblox")
local checks=0
local function check(value,message) checks+=1; assert(value,message) end
local Models=luau.load(fs.readFile("src/server/NPCModels.luau"),{environment={
    Instance=R.Instance,Color3=R.Color3,Vector3=R.Vector3,CFrame=R.CFrame,Enum=R.Enum,UDim2=R.UDim2,
}})()
local world=R.Instance.new("Model")
local roles={"Merchant","Rodsmith","Captain","Buyer"}
for _,role in ipairs(roles) do
    local body=Models.Create(world,role,20,-25,{100,150,180},"Old title","Old action")
    local model=body.Parent
    local frame=body.CFrame
    check(model.Name==role and model.Body==body,"Stable authored NPC/body identity missing")
    local prompt=body:FindFirstChild(role.."Prompt")
    check(prompt and prompt.ActionText=="Поговорить","Talk prompt missing")
    local rig=model.VisualRig
    check(rig and rig:GetAttribute("QCNPC")==true,"Rig identity missing")
    check(rig:FindFirstChildOfClass("Humanoid")~=nil,"NPC is not a Humanoid character")
    check(rig.Humanoid:FindFirstChildOfClass("Animator")~=nil,"Animator missing")
    check(rig.PrimaryPart==rig.HumanoidRootPart and rig.HumanoidRootPart.Anchored,"Root is not anchored")
    check(rig.Head.HeadMesh.MeshType==R.Enum.MeshType.Head,"Classic rounded head missing")
    check(rig.Head.face.Texture=="rbxasset://textures/face.png","Face requires an external uploaded asset")
    local bones={"Torso","Head","Left Arm","Right Arm","Left Leg","Right Leg"}
    for _,bone in ipairs(bones) do check(rig:FindFirstChild(bone)~=nil,"R6 bone missing: "..bone) end
    local motors,welds,parts=0,0,0
    for _,object in ipairs(rig:GetDescendants()) do
        check(not object:IsA("LuaSourceContainer"),"NPC contains executable imported code")
        if object:IsA("Motor6D") then
            motors+=1
            check(object.Part0 and object.Part1,"Joint endpoint missing")
            local expected=object.Part0.CFrame*object.C0*object.C1:Inverse()
            check((expected.Position-object.Part1.CFrame.Position).Magnitude<0.0001,"Joint rest pose disagrees with physical model")
        elseif object:IsA("WeldConstraint") then
            welds+=1
            check(object.Part0 and object.Part1,"Clothing weld endpoint missing")
        elseif object:IsA("BasePart") then
            parts+=1
            check(not object.CanCollide and not object.CanQuery and not object.CanTouch,"NPC blocks shots/navigation")
            check(object==rig.HumanoidRootPart or not object.Anchored,"Limb cannot be posed by Motor6D")
            check(object.Size.X>0 and object.Size.Y>0 and object.Size.Z>0,"Invalid geometry size")
            for _,value in ipairs({object.CFrame:GetComponents()}) do check(value==value and math.abs(value)<1e8,"Nonfinite NPC frame") end
        end
    end
    check(motors==6,"R6 must have six articulating joints")
    check(parts>=20 and parts<45 and welds>=12,"Outfit is empty or excessive")
    local floor=(role=="Captain" or role=="Buyer") and 7.5 or 7
    local foot=rig["Left Leg"].CFrame:PointToWorldSpace(R.Vector3.new(0,-1,0))
    check(math.abs(foot.Y-floor)<0.03,"Character does not stand on the existing ground/deck")
    Models.Upgrade(model,role)
    check(model.VisualRig==rig and model.Body==body and body.CFrame==frame,"Repeated upgrade replaces stable identity/frame")
    check(body[role.."Prompt"]==prompt,"Existing interaction prompt replaced")
end

-- Saved legacy shop: authored props outside the old NPC body are not touched.
local legacy=R.Instance.new("Model"); legacy.Name="Merchant"; legacy.Parent=world
local body=R.Instance.new("Part"); body.Name="Body"; body.CFrame=R.CFrame.new(-20,9.2,-25);body.Parent=legacy
local head=R.Instance.new("Part"); head.Name="Head"; head.Parent=legacy
local eye=R.Instance.new("Part"); eye.Name="Eye"; eye.Parent=legacy
local user=R.Instance.new("Model"); user.Name="UserDecoration";user.Parent=legacy
local userPart=R.Instance.new("Part");userPart.Name="Head";userPart.Transparency=.25;userPart.Parent=user
local prompt=R.Instance.new("ProximityPrompt");prompt.Name="MerchantPrompt";prompt.Parent=body
local savedFrame=body.CFrame
Models.Upgrade(legacy)
check(body.CFrame==savedFrame and legacy.Body==body and body.MerchantPrompt==prompt,"Saved shop references lost")
check(body.Transparency==1 and head.Transparency==1 and eye.Transparency==1,"Old block NPC remains visible")
check(body:GetAttribute("QCOriginalTransparency")==0,"Old visual properties were not preserved")
check(userPart.Transparency==.25 and userPart.CanCollide,"User nested model was modified")
local savedCount=#legacy:GetDescendants()
Models.Upgrade(legacy)
check(#legacy:GetDescendants()==savedCount,"Saved NPC duplicated on repeated apply")

local custom=R.Instance.new("Model"); custom.Name="Merchant";custom.Parent=world
local customBody=R.Instance.new("Part");customBody.Name="Body";customBody.Parent=custom
local customHead=R.Instance.new("MeshPart");customHead.Name="Head";customHead.Parent=custom
Models.Upgrade(custom)
check(custom:FindFirstChild("VisualRig")==nil and customHead.Transparency==0,"Hand-authored mesh NPC replaced")

local bytes=R.serializeModel({world},true)
local restored=R.deserializeModel(bytes)[1]
local restoredRig=restored.Captain.VisualRig
check(restoredRig.Torso["Right Shoulder"].Part1==restoredRig["Right Arm"],"Serialized Motor6D references escaped their rig")
check(restoredRig.Head:FindFirstChild("face")~=nil,"Serialized face instance lost")
print(string.format("PASS %d Roblox NPC rig checks; all four roles and legacy upgrade",checks))
