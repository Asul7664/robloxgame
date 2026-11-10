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
    check(prompt and prompt.ActionText=="Talk","Talk prompt missing")
    local rig=model.VisualRig
    check(rig and rig:GetAttribute("QCNPC")==true,"Rig identity missing")
    check(rig:FindFirstChildOfClass("Humanoid")~=nil,"NPC is not a Humanoid character")
    check(rig.Humanoid:FindFirstChildOfClass("Animator")~=nil,"Animator missing")
    check(rig.PrimaryPart==rig.HumanoidRootPart and rig.HumanoidRootPart.Anchored,"Root is not anchored")
    local approach=(role=="Merchant" and R.Vector3.new(20,0,6))
        or (role=="Rodsmith" and R.Vector3.new(-20,0,6))
        or (role=="Captain" and R.Vector3.new(7,0,-11)) or R.Vector3.new(-7,0,4)
    check(rig.HumanoidRootPart.CFrame.LookVector:Dot(approach.Unit)>.97,"NPC faces away from the normal player approach")
    local headMesh=rig.Head:FindFirstChildOfClass("SpecialMesh")
    check(rig.Head.Shape==R.Enum.PartType.Block and headMesh and headMesh.MeshType==R.Enum.MeshType.Sphere,
        "Head needs a built-in sphere mesh with reliable ellipsoid proportions")
    if role=="Merchant" or role=="Buyer" then
        local rear,crown=rig.HairBack,rig.FisherHairCrown
        local function inside(object,headPoint)
            local point=object.CFrame:PointToObjectSpace(rig.Head.CFrame:PointToWorldSpace(headPoint))
            return (point.X/(object.Size.X/2))^2+(point.Y/(object.Size.Y/2))^2+(point.Z/(object.Size.Z/2))^2<1
        end
        local center=rig.Head.CFrame:PointToObjectSpace(rear.CFrame.Position)
        for _,x in ipairs({-.6,-.3,0,.3,.6}) do for _,y in ipairs({-.15,.1,.35}) do
            local headZ=rig.Head.Size.Z/2*math.sqrt(1-(x/(rig.Head.Size.X/2))^2-(y/(rig.Head.Size.Y/2))^2)
            local remaining=1-((x-center.X)/(rear.Size.X/2))^2-((y-center.Y)/(rear.Size.Y/2))^2
            check(remaining>0,"Hair rear silhouette breaks into disconnected side patches")
            local rearZ=center.Z+rear.Size.Z/2*math.sqrt(remaining)
            check(rearZ>headZ+.03,"Skin cuts through the back of the hairstyle")
        end end
        check(inside(rear,R.Vector3.new(0,.4,.63)) and inside(crown,R.Vector3.new(0,.4,.63)),"Hair crown is detached from the back")
        if role=="Merchant" then
            check(inside(rear,R.Vector3.new(0,-.12,.8)) and inside(rig.HairBun,R.Vector3.new(0,-.12,.8)),"Mara's bun floats behind the hairstyle")
        end
        local brimY=rig.Head.CFrame:PointToObjectSpace(rig.StrawHatBrim.CFrame.Position).Y-rig.StrawHatBrim.Size.X/2
        local crownTop=rig.Head.CFrame:PointToObjectSpace(crown.CFrame.Position).Y+crown.Size.Y/2
        check(crownTop>=brimY,"Straw hat floats above the hair")
    end
    check(not rig.Head:FindFirstChildOfClass("Decal"),"Head still depends on an external face texture")
    check(rig.Humanoid.AutomaticScalingEnabled==false,"Automatic body scaling can overwrite authored R6 joint offsets")
    local eyes,smiles,brows=0,0,0
    for _,object in ipairs(rig:GetChildren()) do
        if object.Name=="FaceEye" or object.Name=="FaceSmile" or object.Name=="FaceBrow" then
            local localPoint=rig.Head.CFrame:PointToObjectSpace(object.CFrame.Position)
            check(localPoint.Z<-.45 and localPoint.Z>-.85,"Facial feature is hidden inside or detached from the front of the head")
            check(object.OutfitWeld.Part0==rig.Head,"Face does not move with the animated head")
            if object.Name=="FaceEye" then eyes+=1
            elseif object.Name=="FaceSmile" then smiles+=1 else brows+=1 end
        end
    end
    check(eyes==2 and smiles==4 and brows==2,"Actual modeled expression is incomplete")
    for _,arm in ipairs({rig["Left Arm"],rig["Right Arm"]}) do
        check(arm.CFrame.UpVector.Y>.98,"An arm is raised into a T-pose")
        check(arm.CFrame.Position.Y<rig.Torso.CFrame.Position.Y+.1,"Arm hangs above the torso instead of beside it")
    end
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
        elseif object:IsA("SpecialMesh") then
            check(object.MeshType==R.Enum.MeshType.Sphere and object.Scale==R.Vector3.new(1,1,1),"Rounded surfaces use only built-in unit sphere meshes")
            check(object.Parent:IsA("Part") and object.Parent.Shape==R.Enum.PartType.Block,"Ellipsoids must not depend on native Ball scaling")
        elseif object:IsA("BasePart") then
            check(not object:IsA("Part") or object.Shape~=R.Enum.PartType.Ball,"Native Ball aspect ratios can distort NPC faces/hair in Studio")
            parts+=1
            check(not object.CanCollide and not object.CanQuery and not object.CanTouch,"NPC blocks shots/navigation")
            check(object==rig.HumanoidRootPart or not object.Anchored,"Limb cannot be posed by Motor6D")
            check(object.Size.X>0 and object.Size.Y>0 and object.Size.Z>0,"Invalid geometry size")
            for _,value in ipairs({object.CFrame:GetComponents()}) do check(value==value and math.abs(value)<1e8,"Nonfinite NPC frame") end
        end
    end
    check(motors==6,"R6 must have six articulating joints")
    check(parts>=28 and parts<45 and welds>=20,"Outfit is empty or excessive: "..role.." parts="..parts..", welds="..welds)
    local floor=(role=="Captain" or role=="Buyer") and 7.5 or 7
    local foot=rig["Left Leg"].CFrame:PointToWorldSpace(R.Vector3.new(0,-1,0))
    check(math.abs(foot.Y-floor)<0.03,"Character does not stand on the existing ground/deck")
    Models.Upgrade(model,role)
    check(model.VisualRig==rig and model.Body==body and body.CFrame==frame,"Repeated upgrade replaces stable identity/frame")
    check(body[role.."Prompt"]==prompt,"Existing interaction prompt replaced")
    check(body.Anchored,"Interaction anchor can fall through the island")
    -- A saved current rig may be reused after only Body was moved. All its
    -- connected parts must follow, even without a physics/PivotTo simulator.
    local relatives={}
    for _,p in ipairs(rig:GetDescendants()) do if p:IsA("BasePart") then
        relatives[p]=rig.HumanoidRootPart.CFrame:ToObjectSpace(p.CFrame)
    end end
    local moved=R.CFrame.new(31,body.CFrame.Position.Y,44)*R.CFrame.Angles(0,.37,0)
    body.CFrame=moved
    Models.Upgrade(model,role)
    local angles={Merchant=-110,Rodsmith=110,Captain=-32.5,Buyer=120}
    local expected=moved*R.CFrame.new(0,(role=="Captain" or role=="Buyer") and 1.2 or .8,0)
        *R.CFrame.Angles(0,math.rad(angles[role]),0)
    check(model.VisualRig==rig and body[role.."Prompt"]==prompt,"Realignment replaced the rig or prompt")
    check((rig.HumanoidRootPart.CFrame.Position-expected.Position).Magnitude<.001
        and rig.HumanoidRootPart.CFrame.LookVector.Unit:Dot(expected.LookVector.Unit)>.99999,"Current rig did not follow moved Body")
    for p,relative in pairs(relatives) do
        local actual=rig.HumanoidRootPart.CFrame:ToObjectSpace(p.CFrame)
        check((actual.Position-relative.Position).Magnitude<.001 and actual.UpVector.Unit:Dot(relative.UpVector.Unit)>.99999,
            "Moving the current rig broke relative frame: "..role.." / "..p.Name.." / "..tostring((actual.Position-relative.Position).Magnitude).." / "..tostring(actual.UpVector:Dot(relative.UpVector)))
    end
    Models.Upgrade(model,role,nil,frame)
    check(body.CFrame==frame and model.VisualRig==rig and body[role.."Prompt"]==prompt,
        "Canonical fourth argument must restore the Body frame without replacing references")
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
check(body.Anchored and head.Anchored and eye.Anchored,"Hidden legacy parts can fall out of the world")
check(body:GetAttribute("QCOriginalAnchored")==false,"Legacy anchoring state was not recorded")
check(body:GetAttribute("QCOriginalTransparency")==0,"Old visual properties were not preserved")
check(userPart.Transparency==.25 and userPart.CanCollide,"User nested model was modified")
local savedCount=#legacy:GetDescendants()
Models.Upgrade(legacy)
check(#legacy:GetDescendants()==savedCount,"Saved NPC duplicated on repeated apply")

local custom=R.Instance.new("Model"); custom.Name="Merchant";custom.Parent=world
local customBody=R.Instance.new("Part");customBody.Name="Body";customBody.Parent=custom
local customHead=R.Instance.new("MeshPart");customHead.Name="Head";customHead.Parent=custom
local customFrame=customBody.CFrame
Models.Upgrade(custom,"Merchant",nil,R.CFrame.new(99,12,99))
check(custom:FindFirstChild("VisualRig")==nil and customHead.Transparency==0,"Hand-authored mesh NPC replaced")
check(customBody.CFrame==customFrame and not customBody.Anchored,"Canonical placement changed a custom mesh NPC")
local customHumanoid=R.Instance.new("Model");customHumanoid.Name="Rodsmith";customHumanoid.Parent=world
local humanoidBody=R.Instance.new("Part");humanoidBody.Name="Body";humanoidBody.Parent=customHumanoid
local userHumanoid=R.Instance.new("Humanoid");userHumanoid.Parent=customHumanoid
Models.Upgrade(customHumanoid,"Rodsmith",nil,R.CFrame.new(99,12,99))
check(humanoidBody.CFrame==R.CFrame.new() and not humanoidBody.Anchored and not customHumanoid:FindFirstChild("VisualRig"),
    "Canonical placement changed a custom Humanoid NPC")
local unknown=R.Instance.new("Model");unknown.Name="Merchant";unknown.Parent=world
local unknownBody=R.Instance.new("Part");unknownBody.Name="Body";unknownBody.Parent=unknown
local unknownRig=R.Instance.new("Model");unknownRig.Name="VisualRig";unknownRig.Parent=unknown
Models.Upgrade(unknown,"Merchant",nil,R.CFrame.new(99,12,99))
check(unknownBody.CFrame==R.CFrame.new() and not unknownBody.Anchored and unknown.VisualRig==unknownRig,
    "Canonical placement changed an unrecognized user rig")

-- Saved v1 rig is replaced, while Body and conversation prompt identity remain.
local migration=R.Instance.new("Model"); migration.Name="Rodsmith";migration.Parent=world
local migrationBody=R.Instance.new("Part");migrationBody.Name="Body";migrationBody.CFrame=R.CFrame.new(20,9.2,-25);migrationBody.Parent=migration
local migrationPrompt=R.Instance.new("ProximityPrompt");migrationPrompt.Name="NPCDialoguePrompt";migrationPrompt.Parent=migrationBody
local v1=R.Instance.new("Model");v1.Name="VisualRig";v1:SetAttribute("QCNPCVersion",1);v1.Parent=migration
local brokenFace=R.Instance.new("Part");brokenFace.Name="FacelessHead";brokenFace.Parent=v1
Models.Upgrade(migration,"Rodsmith")
check(migration.VisualRig~=v1 and v1.Parent==nil,"Saved faceless rig was not upgraded")
check(migration.Body==migrationBody and migrationBody.NPCDialoguePrompt==migrationPrompt,"Rig upgrade replaced conversation anchor")
check(migration.VisualRig:GetAttribute("QCNPCVersion")==4,"New rig lacks upgrade identity")
-- Hair-v2 installations must be rebuilt too, keeping the live conversation anchor.
migration.VisualRig:SetAttribute("QCNPCVersion",2)
local previousRig=migration.VisualRig
Models.Upgrade(migration,"Rodsmith")
check(previousRig.Parent==nil and migration.VisualRig~=previousRig,"Saved v2 rig was retained")
check(migrationBody.NPCDialoguePrompt==migrationPrompt,"Hair update replaced the dialogue prompt")

-- The previous v3 factory used native Balls and must be rebuilt to v4.
migration.VisualRig:SetAttribute("QCNPCVersion",3)
local v3=migration.VisualRig
local canonical=R.CFrame.new(20,9.2,-25)
Models.Upgrade(migration,"Rodsmith",nil,canonical)
check(v3.Parent==nil and migration.VisualRig~=v3 and migration.VisualRig:GetAttribute("QCNPCVersion")==4,
    "Saved v3 native Ball rig was retained")
check(migration.Body==migrationBody and (migrationBody.CFrame.Position-canonical.Position).Magnitude<.001 and migrationBody.Anchored
    and migrationBody.NPCDialoguePrompt==migrationPrompt,"Canonical v3 migration lost placement/interaction")
-- A current version tag alone cannot certify an intact skeleton.
local damaged=migration.VisualRig
damaged.Torso.Neck:Destroy()
Models.Upgrade(migration,"Rodsmith")
check(damaged.Parent==nil and migration.VisualRig~=damaged and migration.VisualRig.Torso:FindFirstChild("Neck"),
    "Malformed current rig with a missing joint was reused")
local missingRoot=migration.VisualRig
missingRoot.HumanoidRootPart:Destroy()
Models.Upgrade(migration,"Rodsmith")
check(missingRoot.Parent==nil and migration.VisualRig~=missingRoot and migration.VisualRig.HumanoidRootPart.Anchored,
    "Malformed current rig with a missing root was reused")
check(migration.Body==migrationBody and migrationBody.NPCDialoguePrompt==migrationPrompt,
    "Repairing a malformed rig lost the interaction Body or prompt")

local bytes=R.serializeModel({world},true)
local restored=R.deserializeModel(bytes)[1]
local restoredRig=restored.Captain.VisualRig
check(restoredRig.Torso["Right Shoulder"].Part1==restoredRig["Right Arm"],"Serialized Motor6D references escaped their rig")
local restoredEyes=0
for _,object in ipairs(restoredRig:GetChildren()) do if object.Name=="FaceEye" then restoredEyes+=1;check(object.OutfitWeld.Part0==restoredRig.Head,"Serialized face weld lost") end end
check(restoredEyes==2,"Serialized face geometry lost")
local restoredMesh=restoredRig.Head:FindFirstChildOfClass("SpecialMesh")
check(restoredMesh and restoredMesh.MeshType==R.Enum.MeshType.Sphere and restoredMesh.Scale==R.Vector3.new(1,1,1),
    "Serialized head lost its built-in sphere proportions")
check(restored.Captain.Body.Anchored,"Serialized interaction anchor can fall into the ocean")
print(string.format("PASS %d Roblox NPC rig checks; all four roles and legacy upgrade",checks))
