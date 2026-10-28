-- Classic Roblox characters, authored locally without downloaded avatar assets.
-- Body remains the stable interaction anchor used by shops, boats and dialogues.
local NPCModels = {}
local VERSION = 1
local rgb = Color3.fromRGB
local UP = Vector3.new(0, 1, 0)
local ROLES = {
    Merchant={Giver="merchant",Name="Мара",Job="Улов и поручения",Shirt=rgb(239,184,90),Skin=rgb(232,187,147)},
    Rodsmith={Giver="rodsmith",Name="Лев",Job="Удочки и мастерская",Shirt=rgb(69,169,185),Skin=rgb(218,171,129)},
    Captain={Giver="captain",Name="Капитан Мирон",Job="Лодки и экспедиции",Shirt=rgb(54,101,152),Skin=rgb(199,146,112)},
    Buyer={Giver="merchant",Name="Рыбак артели",Job="Улов и поручения",Shirt=rgb(221,169,91),Skin=rgb(232,187,147)},
}
local INK, CREAM = rgb(37,51,73),rgb(255,246,222)
local OLD = {Head=true,Hat=true,HatBand=true,Arm=true,Leg=true,Eye=true}

local function part(parent,name,size,frame,color)
    local p=Instance.new("Part")
    p.Name=name; p.Size=size; p.CFrame=frame; p.Color=color
    p.Material=Enum.Material.SmoothPlastic
    p.Anchored=false; p.Massless=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false
    p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
    p.Parent=parent; return p
end
local function attachment(part0,part1)
    local weld=Instance.new("WeldConstraint")
    weld.Name="OutfitWeld"; weld.Part0=part0; weld.Part1=part1; weld.Parent=part1
end
local function accessory(rig,bone,name,size,offset,color,shape)
    local p=part(rig,name,size,bone.CFrame*offset,color)
    if shape then p.Shape=shape end
    attachment(bone,p); return p
end
local function joint(parent,name,part0,part1,c0,c1)
    local motor=Instance.new("Motor6D")
    motor.Name=name; motor.Part0=part0; motor.Part1=part1; motor.C0=c0; motor.C1=c1
    part1.CFrame=part0.CFrame*c0*c1:Inverse()
    motor.Parent=parent; return motor
end
local function hide(p)
    if p:GetAttribute("QCOriginalTransparency")==nil then p:SetAttribute("QCOriginalTransparency",p.Transparency) end
    if p:GetAttribute("QCOriginalCanCollide")==nil then p:SetAttribute("QCOriginalCanCollide",p.CanCollide) end
    if p:GetAttribute("QCOriginalCanQuery")==nil then p:SetAttribute("QCOriginalCanQuery",p.CanQuery) end
    if p:GetAttribute("QCOriginalCanTouch")==nil then p:SetAttribute("QCOriginalCanTouch",p.CanTouch) end
    p.Transparency=1; p.CanCollide=false; p.CanQuery=false; p.CanTouch=false
end
local function label(body,info)
    local gui=body:FindFirstChild("Label")
    if not gui then gui=Instance.new("BillboardGui"); gui.Name="Label"; gui.Parent=body end
    gui.Size=UDim2.fromOffset(230,50); gui.StudsOffset=Vector3.new(0,4.3,0)
    gui.AlwaysOnTop=false; gui.MaxDistance=48
    local t=gui:FindFirstChildOfClass("TextLabel")
    if not t then t=Instance.new("TextLabel"); t.Parent=gui end
    t.Size=UDim2.fromScale(1,1); t.BackgroundTransparency=1
    t.Font=Enum.Font.GothamBold; t.TextSize=15; t.TextWrapped=true
    t.TextColor3=CREAM; t.TextStrokeColor3=INK; t.TextStrokeTransparency=0.25
    t.Text=info.Name.."\n"..info.Job
end
local function interaction(model,body,info)
    model:SetAttribute("NPCGiver",info.Giver); model:SetAttribute("NPCName",info.Name)
    body:SetAttribute("NPCGiver",info.Giver); body:SetAttribute("NPCName",info.Name)
    for _,child in ipairs(body:GetChildren()) do
        if child:IsA("ProximityPrompt") then child.ActionText="Поговорить"; child.ObjectText=info.Name end
    end
    label(body,info)
end
local function clothes(rig,torso,head,left,right,role,info)
    local shirt=info.Shirt
    for _,arm in ipairs({left,right}) do
        accessory(rig,arm,"ShirtSleeve",Vector3.new(1.04,0.82,1.04),CFrame.new(0,0.57,0),shirt)
        accessory(rig,arm,"SleeveCuff",Vector3.new(1.06,0.13,1.06),CFrame.new(0,0.14,0),CREAM)
    end
    accessory(rig,torso,"WaistBelt",Vector3.new(2.03,0.22,1.04),CFrame.new(0,-0.74,0),INK)
    accessory(rig,torso,"BeltBuckle",Vector3.new(0.3,0.22,0.1),CFrame.new(0,-0.74,-0.57),rgb(247,199,89))
    if role=="Captain" then
        for _,side in ipairs({-1,1}) do
            accessory(rig,torso,"NavyLapel",Vector3.new(0.28,1.45,0.13),
                CFrame.new(side*0.44,0.15,-0.56)*CFrame.Angles(0,0,side*0.15),CREAM)
            accessory(rig,torso,"CaptainEpaulette",Vector3.new(0.55,0.14,1.1),CFrame.new(side*0.76,1.04,0),rgb(247,199,89))
        end
        accessory(rig,head,"CaptainCapBand",Vector3.new(2.06,0.26,1.17),CFrame.new(0,0.52,0),INK)
        accessory(rig,head,"CaptainCap",Vector3.new(2.14,0.33,1.32),CFrame.new(0,0.77,0),CREAM)
        accessory(rig,head,"CapVisor",Vector3.new(1.9,0.12,0.75),CFrame.new(0,0.48,-0.7),INK)
        accessory(rig,head,"CapBadge",Vector3.new(0.33,0.27,0.10),CFrame.new(0,0.72,-0.7),rgb(247,199,89))
    elseif role=="Rodsmith" then
        accessory(rig,torso,"WorkshopApron",Vector3.new(1.65,1.6,0.13),CFrame.new(0,-0.05,-0.57),rgb(120,86,62))
        accessory(rig,torso,"ApronPocket",Vector3.new(1.02,0.43,0.12),CFrame.new(0,-0.25,-0.68),rgb(163,120,79))
        for _,side in ipairs({-1,1}) do
            accessory(rig,head,"GoggleLens",Vector3.new(0.63,0.39,0.13),CFrame.new(side*0.39,0.45,-0.58),rgb(100,193,211))
            accessory(rig,torso,"ApronStrap",Vector3.new(0.17,0.75,0.13),CFrame.new(side*0.64,0.77,-0.55),rgb(120,86,62))
        end
        accessory(rig,head,"HairCap",Vector3.new(1.88,0.29,1.03),CFrame.new(0,0.53,0.04),rgb(84,58,43))
        accessory(rig,torso,"ToolHandle",Vector3.new(0.15,0.7,0.15),CFrame.new(0.56,-0.48,-0.76)*CFrame.Angles(0,0,-0.13),rgb(207,162,93))
        accessory(rig,torso,"ToolHead",Vector3.new(0.42,0.20,0.22),CFrame.new(0.61,-0.12,-0.76),INK)
    else
        accessory(rig,torso,"FisherApron",Vector3.new(1.6,1.55,0.13),CFrame.new(0,-0.10,-0.57),rgb(76,134,125))
        accessory(rig,torso,"ApronPocket",Vector3.new(0.86,0.42,0.1),CFrame.new(0,-0.28,-0.67),rgb(112,170,147))
        local hat=accessory(rig,head,"StrawHatBrim",Vector3.new(0.15,2.9,2.0),
            CFrame.new(0,0.57,0)*CFrame.Angles(0,0,math.pi/2),rgb(222,184,113),Enum.PartType.Cylinder)
        hat.CastShadow=true
        accessory(rig,head,"StrawHatCrown",Vector3.new(1.8,0.55,1.07),CFrame.new(0,0.86,0),rgb(235,201,132))
        accessory(rig,head,"HatRibbon",Vector3.new(1.83,0.16,1.10),CFrame.new(0,0.68,0),rgb(76,134,125))
        accessory(rig,head,"HairBack",Vector3.new(1.78,0.7,0.26),CFrame.new(0,0.12,0.49),rgb(92,62,45))
    end
end

function NPCModels.Upgrade(model,role,theme)
    local body=model:FindFirstChild("Body")
    if not body or not body:IsA("BasePart") then return nil end
    role=ROLES[role] and role or model.Name
    local source=ROLES[role]
    if not source then return body end
    -- A hand-authored replacement is not an old block NPC to overwrite.
    if model:FindFirstChildOfClass("Humanoid") then return body end
    for _,child in ipairs(model:GetChildren()) do
        if child:IsA("MeshPart") then return body end
    end
    local old=model:FindFirstChild("VisualRig")
    local frame=body.CFrame
    if old and old:GetAttribute("QCNPCVersion")==VERSION then
        for _,child in ipairs(model:GetChildren()) do
            if child:IsA("BasePart") and (child==body or OLD[child.Name]) then hide(child) end
        end
        interaction(model,body,source)
        return body
    end
    if old and old:GetAttribute("QCNPCVersion") then old:Destroy()
    elseif old then return body end
    local info=table.clone(source)
    if theme and theme.UI then info.Shirt=role=="Rodsmith" and theme.UI.Aqua or info.Shirt end
    local rig=Instance.new("Model"); rig.Name="VisualRig"; rig:SetAttribute("QCNPCVersion",VERSION)
    rig:SetAttribute("QCNPC",true); rig:SetAttribute("NPCRole",role)
    local heightOffset=(role=="Captain" or role=="Buyer") and 1.2 or 0.8
    local root=part(rig,"HumanoidRootPart",Vector3.new(2,2,1),frame*CFrame.new(0,heightOffset,0),INK)
    root.Transparency=1; root.Anchored=true; root.Massless=false
    local torso=part(rig,"Torso",Vector3.new(2,2,1),root.CFrame,info.Shirt)
    joint(root,"RootJoint",root,torso,CFrame.new(),CFrame.new())
    local head=part(rig,"Head",Vector3.new(2,1,1),torso.CFrame,info.Skin)
    local mesh=Instance.new("SpecialMesh"); mesh.Name="HeadMesh"; mesh.MeshType=Enum.MeshType.Head; mesh.Scale=Vector3.new(1.25,1.25,1.25); mesh.Parent=head
    joint(torso,"Neck",torso,head,CFrame.new(0,1,0),CFrame.new(0,-0.5,0))
    local face=Instance.new("Decal"); face.Name="face"; face.Face=Enum.NormalId.Front
    face.Texture="rbxasset://textures/face.png"; face.Parent=head
    local left=part(rig,"Left Arm",Vector3.new(1,2,1),torso.CFrame,info.Skin)
    local right=part(rig,"Right Arm",Vector3.new(1,2,1),torso.CFrame,info.Skin)
    joint(torso,"Left Shoulder",torso,left,CFrame.new(-1,0.5,0)*CFrame.Angles(math.rad(-5),0,math.rad(-7)),CFrame.new(0.5,0.5,0))
    joint(torso,"Right Shoulder",torso,right,CFrame.new(1,0.5,0)*CFrame.Angles(math.rad(-9),0,math.rad(7)),CFrame.new(-0.5,0.5,0))
    for _,side in ipairs({-1,1}) do
        local leg=part(rig,side<0 and "Left Leg" or "Right Leg",Vector3.new(1,2,1),torso.CFrame,INK)
        joint(torso,side<0 and "Left Hip" or "Right Hip",torso,leg,
            CFrame.new(side*0.5,-1,0)*CFrame.Angles(0,0,side*math.rad(1)),CFrame.new(0,1,0))
        accessory(rig,leg,"Boot",Vector3.new(1.02,0.36,1.12),CFrame.new(0,-0.85,-0.05),rgb(67,57,53))
    end
    clothes(rig,torso,head,left,right,role,info)
    local humanoid=Instance.new("Humanoid"); humanoid.Name="Humanoid"
    humanoid.RigType=Enum.HumanoidRigType.R6
    humanoid.MaxHealth=100; humanoid.Health=100; humanoid.WalkSpeed=0; humanoid.AutoRotate=false
    humanoid.BreakJointsOnDeath=false; humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
    humanoid.Parent=rig
    local animator=Instance.new("Animator"); animator.Parent=humanoid
    rig.PrimaryPart=root
    rig.Parent=model
    for _,child in ipairs(model:GetChildren()) do
        if child:IsA("BasePart") and (child==body or OLD[child.Name]) then hide(child) end
    end
    interaction(model,body,info)
    return body
end

function NPCModels.Create(parent,name,x,z,shirt,title,action)
    local model=Instance.new("Model"); model.Name=name; model.Parent=parent
    local body=part(model,"Body",Vector3.new(2.5,2.8,1.4),
        CFrame.new(x,(name=="Captain" or name=="Buyer") and 9.3 or 9.2,z),rgb(shirt[1],shirt[2],shirt[3]))
    body.Anchored=true
    local prompt=Instance.new("ProximityPrompt")
    prompt.Name=name.."Prompt"; prompt.ActionText="Поговорить"; prompt.ObjectText=title
    prompt.KeyboardKeyCode=Enum.KeyCode.E; prompt.HoldDuration=0.15; prompt.MaxActivationDistance=12
    prompt.RequiresLineOfSight=false; prompt.Parent=body
    NPCModels.Upgrade(model,name)
    return body
end
return NPCModels
