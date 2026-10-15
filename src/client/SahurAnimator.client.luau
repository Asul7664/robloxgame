local CollectionService = game:GetService('CollectionService')
local RunService = game:GetService('RunService')
local shared = game:GetService('ReplicatedStorage'):WaitForChild('QuietCove')
local Pose = require(shared:WaitForChild('SahurBossPose'))
local settings = require(shared:WaitForChild('SahurBossSettings'))
local tracked = {}
local function add(model)
    if tracked[model] then return end
    local joints = {}
    for _, item in model:GetDescendants() do
        if item:IsA('Motor6D') then joints[item] = item.C0 end
    end
    tracked[model] = joints
end
local function remove(model)
    local joints = tracked[model]
    if joints then
        for joint, base in pairs(joints) do
            if joint.Parent then joint.C0 = base end
        end
    end
    tracked[model] = nil
end
CollectionService:GetInstanceAddedSignal('QCSahurBoss'):Connect(add)
CollectionService:GetInstanceRemovedSignal('QCSahurBoss'):Connect(remove)
for _, model in CollectionService:GetTagged('QCSahurBoss') do add(model) end
RunService.PreSimulation:Connect(function(dt)
    local now = workspace:GetServerTimeNow()
    local blend=1-math.exp(-math.max(0,dt)*24)
    for model, joints in pairs(tracked) do
        if not model:IsDescendantOf(workspace) then
            remove(model)
        else
            local pose = Pose.Sample(now, model:GetAttribute('SahurAttackAt'),
                model:GetAttribute('SahurMoving'), settings)
            for joint, base in pairs(joints) do
                if joint.Parent then
                    joint.C0 = joint.C0:Lerp(base * (pose[joint.Name] or CFrame.new()),blend)
                end
            end
        end
    end
end)
