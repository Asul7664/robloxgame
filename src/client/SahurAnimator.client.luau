local CollectionService = game:GetService('CollectionService')
local RunService = game:GetService('RunService')
local shared = game:GetService('ReplicatedStorage'):WaitForChild('QuietCove')
local Pose = require(shared:WaitForChild('SahurBossPose'))
local settings = require(shared:WaitForChild('SahurBossSettings'))
local tracked = {}
local connections = {}
local TAU = math.pi*2
local function remember(state,item)
    if item:IsA('Motor6D') and state.Joints[item]==nil then state.Joints[item]=item.C0 end
end
local function add(model)
    if tracked[model] then return end
    local state={Joints={}, Phase=0, Speed=0, Weight=0}
    tracked[model]=state
    for _,item in model:GetDescendants() do remember(state,item) end
    -- Streaming can deliver the tag before every joint in the existing rig.
    if model.DescendantAdded then
        state.Added=model.DescendantAdded:Connect(function(item) remember(state,item) end)
    end
end
local function remove(model)
    local state=tracked[model]
    if not state then return end
    tracked[model]=nil
    if state.Added then state.Added:Disconnect() end
    for joint,base in pairs(state.Joints) do if joint.Parent then joint.C0=base end end
end
connections[1]=CollectionService:GetInstanceAddedSignal('QCSahurBoss'):Connect(add)
connections[2]=CollectionService:GetInstanceRemovedSignal('QCSahurBoss'):Connect(remove)
for _,model in CollectionService:GetTagged('QCSahurBoss') do add(model) end
connections[3]=RunService.PreSimulation:Connect(function(dt)
    local now=workspace:GetServerTimeNow()
    local step=math.clamp(dt,0,.1)
    local blend=1-math.exp(-step*32)
    for model,state in pairs(tracked) do
        if not model:IsDescendantOf(workspace) then
            remove(model)
        else
            local root=model:FindFirstChild('HumanoidRootPart')
            local speed=0
            local emerging=model:GetAttribute('SahurEmerging')==true
            local attackAt=model:GetAttribute('SahurAttackAt')
            local attackDuration=settings.Windup+settings.Strike+settings.Recovery
            local attacking=type(attackAt)=='number' and now>=attackAt and now<attackAt+attackDuration
            if attacking and state.AttackAt~=attackAt then
                state.AttackAt=attackAt;state.Entry={}
                for joint,base in pairs(state.Joints) do state.Entry[joint]=base:Inverse()*joint.C0 end
            elseif not attacking then state.AttackAt=nil;state.Entry=nil end
            if root then
                -- Intention is not movement: a blocked boss stops stepping.
                local velocity=root.AssemblyLinearVelocity
                if typeof(velocity)=='Vector3' then
                    speed=Vector3.new(velocity.X,0,velocity.Z).Magnitude
                elseif state.Position and dt>0 then
                    local delta=root.Position-state.Position
                    speed=Vector3.new(delta.X,0,delta.Z).Magnitude/dt
                end
                state.Position=root.Position
            end
            if emerging or attacking then speed=0 end
            if speed>settings.WalkSpeed*4 then speed=0 end -- Replicated teleport.
            speed=math.min(speed,settings.WalkSpeed*1.35)
            state.Speed+=(speed-state.Speed)*(1-math.exp(-step*12))
            -- Keep a full grounded stride at approach speed as well as pursuit.
            local target=math.clamp(state.Speed/settings.GaitReferenceSpeed,0,1)
            state.Weight+=(target-state.Weight)*(1-math.exp(-step*10))
            -- 6.2 studs matches the doubled rig's ~3.8-stud support travel
            -- over 62% of a cycle; cadence follows distance, never the clock.
            state.Phase=(state.Phase+speed*step/(settings.StrideLength or 6.2)*TAU)%TAU
            local pose=Pose.Sample(now,attackAt,model:GetAttribute('SahurMoving'),settings,{
                Phase=state.Phase, Weight=state.Weight, Emerging=emerging,
                Pace=state.Speed/settings.GaitReferenceSpeed,
                SpawnAt=model:GetAttribute('SahurSpawnAt'), LandingAt=model:GetAttribute('SahurLandingAt'),
            })
            for joint,base in pairs(state.Joints) do
                if joint.Parent then
                    local offset=pose[joint.Name] or CFrame.new()
                    if attacking then
                        local enter=math.clamp((now-attackAt)/.10,0,1)
                        enter=enter*enter*(3-2*enter)
                        local initial=state.Entry[joint] or offset
                        -- Fade only the entry. Additional exponential smoothing
                        -- during contact would put the visible bat behind the
                        -- server's exact authored curve and its damage sweep.
                        joint.C0=base*initial:Lerp(offset,enter)
                    else joint.C0=joint.C0:Lerp(base*offset,blend) end
                else
                    -- A streamed-out joint may be reparented later. Restore
                    -- its base before a later discovery captures it again.
                    joint.C0=base;state.Joints[joint]=nil
                end
            end
        end
    end
end)
connections[4]=script.Destroying:Connect(function()
    for _,connection in connections do connection:Disconnect() end
    for model in pairs(tracked) do remove(model) end
end)
