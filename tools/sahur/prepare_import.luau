-- lune run tools/sahur/prepare_import.luau <original.rbxm>
-- Deserialize only: imported code is never executed.
local fs = require('@lune/fs')
local roblox = require('@lune/roblox')
local process = require('@lune/process')
local roots = roblox.deserializeModel(fs.readFile(assert(process.args[1], 'Pass source .rbxm')))
assert(#roots == 1 and roots[1]:IsA('Model'), 'Expected one model')
local model = roots[1]
local root = assert(model:FindFirstChild('HumanoidRootPart'), 'Missing rig root')
local originalPivot = root.CFrame
local factor = 2
local function scaled(cf)
    return roblox.CFrame.new(cf.Position * factor) * (cf - cf.Position)
end
local removed, parts, joints = 0, 0, 0
local before = {}
for _, item in model:GetDescendants() do
    if item:IsA('LuaSourceContainer') or item:IsA('PackageLink') then
        item:Destroy(); removed += 1
    elseif item:IsA('BasePart') then
        before[item.Name] = item.Size
        item.CFrame = scaled(originalPivot:ToObjectSpace(item.CFrame))
        item.Size *= factor
        item.PivotOffset = scaled(item.PivotOffset)
        item.CanTouch = false
        parts += 1
    elseif item:IsA('JointInstance') then
        item.C0 = scaled(item.C0); item.C1 = scaled(item.C1)
        joints += 1
    elseif item:IsA('Attachment') then
        item.CFrame = scaled(item.CFrame)
    elseif item:IsA('Humanoid') then
        item.HipHeight *= factor
        item.AutomaticScalingEnabled = false
        item.DisplayDistanceType = roblox.Enum.HumanoidDisplayDistanceType.None
    end
end
model.Name = 'sahur'
model.PrimaryPart = root
model:SetAttribute('QCImportedSahur', true)
model:SetAttribute('QCSizeMultiplier', factor)
for _, item in model:GetDescendants() do
    assert(not item:IsA('LuaSourceContainer'), 'Imported code survived')
    if item:IsA('BasePart') then
        assert((item.Size - before[item.Name] * factor).Magnitude < .0001, 'Size mismatch '..item.Name..' '..tostring(item.Size)..' expected '..tostring(before[item.Name]*factor))
    elseif item:IsA('JointInstance') then
        assert(item.Part0 and item.Part1, 'Broken joint')
    end
end
local xml = roblox.serializeModel(roots, true)
-- ScaleFactor is a serialized, non-scriptable Model property in Roblox.
xml = xml:gsub('(<float name="ScaleFactor">)(.-)(</float>)', function(a, value, b)
    return a .. tostring(assert(tonumber(value)) * factor) .. b
end, 1)
roots = roblox.deserializeModel(xml)
local binary = roblox.serializeModel(roots)
local reloaded = roblox.deserializeModel(binary)
assert(#reloaded[1]:GetDescendants() == #model:GetDescendants(), 'Round-trip mismatch')
fs.writeFile('assets/creatures/SahurBoss.rbxm', binary)
fs.writeFile('assets/creatures/SahurBoss.rbxmx', roblox.serializeModel(roots, true))
print(string.format('PASS: removed %d code/package objects; %d parts doubled, %d joints preserved', removed, parts, joints))
