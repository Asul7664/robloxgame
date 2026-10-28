-- Local presentation only. Authored NPC roots, prompts and physics never move.
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local STEP, RANGE, LOOK_RANGE=1/30,70,24
local entries,connections={},{}
local function restore(entry)
    for joint,frame in pairs(entry.Base) do if joint.Parent then joint.C0=frame end end
    entry.Active=false; entry.Yaw=0; entry.Pitch=0
end
local function register(object)
    local rig=object
    while rig and not (rig:IsA("Model") and rig.Name=="VisualRig") do rig=rig.Parent end
    if not rig or entries[rig] or rig:GetAttribute("QCNPC")~=true then return end
    local root,torso=rig:FindFirstChild("HumanoidRootPart"),rig:FindFirstChild("Torso")
    if not root or not torso then return end
    local rootJoint=root:FindFirstChild("RootJoint")
    local neck,left,right=torso:FindFirstChild("Neck"),torso:FindFirstChild("Left Shoulder"),torso:FindFirstChild("Right Shoulder")
    if not rootJoint or not neck or not left or not right then return end
    entries[rig]={Root=root,Neck=neck,Left=left,Right=right,RootJoint=rootJoint,
        Base={[rootJoint]=rootJoint.C0,[neck]=neck.C0,[left]=left.C0,[right]=right.C0},
        Phase=(root.Position.X*0.13+root.Position.Z*0.19)%(math.pi*2),Yaw=0,Pitch=0,Active=false}
end
for _,object in ipairs(Workspace:GetDescendants()) do
    if object.Name=="VisualRig" then register(object) end
end
table.insert(connections,Workspace.DescendantAdded:Connect(function(object)
    if object.Name=="VisualRig" or object.Name=="Neck" or object.Name=="RootJoint"
        or object.Name=="Left Shoulder" or object.Name=="Right Shoulder" then register(object) end
end))
table.insert(connections,Workspace.DescendantRemoving:Connect(function(object)
    local entry=entries[object]
    if entry then restore(entry); entries[object]=nil end
end))
local accumulated,elapsed=0,0
table.insert(connections,RunService.RenderStepped:Connect(function(dt)
    accumulated+=dt; elapsed+=dt
    if accumulated<STEP then return end
    local delta=math.min(accumulated,0.1); accumulated=0
    local character=player.Character
    local target=character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
    local camera=Workspace.CurrentCamera
    local viewpoint=camera and camera.CFrame.Position or (target and target.Position)
    local alpha=1-math.exp(-delta*7)
    for rig,entry in pairs(entries) do
        if not rig:IsDescendantOf(Workspace) then restore(entry); entries[rig]=nil
        elseif not viewpoint or (entry.Root.Position-viewpoint).Magnitude>RANGE then
            if entry.Active then restore(entry) end
        else
            local yaw,pitch=0,0
            if target and (target.Position-entry.Root.Position).Magnitude<LOOK_RANGE then
                local direction=entry.Root.CFrame:VectorToObjectSpace(target.Position-entry.Root.Position-Vector3.new(0,1.5,0))
                -- A character behind the merchant should not twist their neck backwards.
                if direction.Z<0 then
                    yaw=math.clamp(-math.atan2(direction.X,-direction.Z),-math.rad(25),math.rad(25))
                    pitch=math.clamp(math.atan2(direction.Y,math.max(0.01,Vector3.new(direction.X,0,direction.Z).Magnitude)),-math.rad(8),math.rad(8))
                end
            end
            entry.Active=true
            entry.Yaw+=(yaw-entry.Yaw)*alpha; entry.Pitch+=(pitch-entry.Pitch)*alpha
            local breath=math.sin(elapsed*1.7+entry.Phase)
            entry.RootJoint.C0=entry.Base[entry.RootJoint]*CFrame.new(0,breath*0.018,0)*CFrame.Angles(breath*0.003,0,0)
            entry.Neck.C0=entry.Base[entry.Neck]*CFrame.Angles(entry.Pitch,entry.Yaw,0)
            entry.Left.C0=entry.Base[entry.Left]*CFrame.Angles(breath*0.005,0,0)
            entry.Right.C0=entry.Base[entry.Right]*CFrame.Angles(-breath*0.005,0,0)
        end
    end
end))
table.insert(connections,script.Destroying:Connect(function()
    for _,entry in pairs(entries) do restore(entry) end
    table.clear(entries)
    for _,connection in ipairs(connections) do connection:Disconnect() end
    table.clear(connections)
end))
