-- From the repository root:
-- lune run tools/sahur/export_attack.luau [sample-rate, default 120]
-- Produces editable native KeyframeSequences from the SAME authored runtime
-- clip. No imported asset code is executed and no animation is uploaded.
local fs = require('@lune/fs')
local luau = require('@lune/luau')
local process = require('@lune/process')
local roblox = require('@lune/roblox')
local Instance, Enum, CF = roblox.Instance, roblox.Enum, roblox.CFrame
local function module(path)
    return luau.load(fs.readFile(path), {
        environment = {CFrame = CF, Vector3 = roblox.Vector3},
    })()
end
local settings = module('src/shared/SahurBossSettings.luau')
local clip = module('src/shared/SahurAttackClip.luau')
local rate = tonumber(process.args[1]) or 120
assert(rate >= 30 and rate <= 240, 'Sample rate must be between 30 and 240 Hz')
local source = clip.Keyframes(settings, rate)
local rig = roblox.deserializeModel(fs.readFile('assets/creatures/SahurBoss.rbxm'))[1]
local root = assert(rig:FindFirstChild('HumanoidRootPart'), 'Missing imported rig root')

-- Use the real imported motor hierarchy, not a second hand-maintained rig.
-- Animation Poses are named after Part1; their CFrame is the Motor6D offset.
local children, jointCount = {}, 0
for _, joint in rig:GetDescendants() do
    if joint:IsA('Motor6D') then
        assert(joint.Part0 and joint.Part1, 'Unbound native rig motor '..joint.Name)
        children[joint.Part0] = children[joint.Part0] or {}
        table.insert(children[joint.Part0], joint)
        jointCount += 1
    end
end
assert(jointCount == #clip.Joints, 'Runtime clip and imported rig have different joint counts')
for _, list in pairs(children) do
    table.sort(list, function(a,b) return a.Name < b.Name end)
end

local sequence = Instance.new('KeyframeSequence')
sequence.Name = 'SahurHeavyStrike'
sequence.Priority = Enum.AnimationPriority.Action
sequence.Loop = false
sequence:SetAttribute('RuntimeSource', 'ReplicatedStorage.QuietCove.SahurAttackClip')
sequence:SetAttribute('RigAsset', 'assets/creatures/SahurBoss.rbxm')
sequence:SetAttribute('BakeRate', rate)
sequence:SetAttribute('Windup', settings.Windup)
sequence:SetAttribute('Strike', settings.Strike)
sequence:SetAttribute('Recovery', settings.Recovery)
sequence:SetAttribute('Duration', clip.Duration(settings))

local function pose(parent, part, offset, frame)
    local node = Instance.new('Pose')
    node.Name = part.Name
    node.CFrame = offset
    node.Weight = 1
    node.EasingStyle = assert(Enum.PoseEasingStyle[frame.EasingStyle])
    node.EasingDirection = assert(Enum.PoseEasingDirection[frame.EasingDirection])
    node.Parent = parent
    for _, joint in children[part] or {} do
        pose(node, joint.Part1, assert(frame.Pose[joint.Name], 'Missing offset '..joint.Name), frame)
    end
end
for _, frame in source do
    local key = Instance.new('Keyframe')
    key.Name = frame.Name
    key.Time = frame.Time
    key.Parent = sequence
    pose(key, root, CF.new(), frame)
end

local function near(a,b)
    local x,y = {a:GetComponents()}, {b:GetComponents()}
    for index = 1,12 do
        assert(math.abs(x[index]-y[index]) < .00001, 'Native pose round-trip changed its CFrame')
    end
end
local function verify(model)
    assert(model:IsA('KeyframeSequence') and model.Name == sequence.Name)
    assert(model.Priority == Enum.AnimationPriority.Action and model.Loop == false)
    local keys = model:GetChildren()
    table.sort(keys, function(a,b) return a.Time < b.Time end)
    assert(#keys == #source, 'Native keyframe count changed')
    assert(math.abs(keys[#keys].Time-clip.Duration(settings)) < .000001, 'Native duration changed')
    for index,key in keys do
        local frame = source[index]
        assert(key:IsA('Keyframe') and key.Name == frame.Name)
        assert(math.abs(key.Time-frame.Time) < .000001, 'Native keyframe time changed')
        local count = 0
        local function branch(parent, part, expected)
            local current = assert(parent:FindFirstChild(part.Name), 'Missing native Pose '..part.Name)
            assert(current:IsA('Pose') and current.Weight == 1)
            assert(current.EasingStyle == Enum.PoseEasingStyle[frame.EasingStyle])
            assert(current.EasingDirection == Enum.PoseEasingDirection[frame.EasingDirection])
            near(current.CFrame, expected)
            count += 1
            local list = children[part] or {}
            assert(#current:GetChildren() == #list, 'Native pose hierarchy changed')
            for _, joint in list do branch(current,joint.Part1,frame.Pose[joint.Name]) end
        end
        assert(#key:GetChildren() == 1, 'Keyframe must have one root Pose')
        branch(key, root, CF.new())
        assert(count == jointCount+1, 'Native rig pose is incomplete')
    end
end

fs.writeDir('assets/animations')
for _, item in {{Path='assets/animations/SahurHeavyStrike.rbxm', XML=false},
    {Path='assets/animations/SahurHeavyStrike.rbxmx', XML=true}} do
    local data = roblox.serializeModel({sequence},item.XML)
    local roundTrip = roblox.deserializeModel(data)
    assert(#roundTrip == 1)
    verify(roundTrip[1])
    fs.writeFile(item.Path,data)
end
print(string.format('PASS: SahurHeavyStrike, %d keyframes, %d poses/frame, %.3fs, %gHz; binary/XML round-trips verified',
    #source,jointCount+1,clip.Duration(settings),rate))
