-- lune run tests/weapon_models.luau
-- Exercise the runtime display -> Tool factory with real Roblox XML models,
-- CFrames, attachments and cloned weld references; no mocked geometry.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Instance, CF, V = roblox.Instance, roblox.CFrame, roblox.Vector3
local checks = 0
local function check(value, label)
    checks += 1
    assert(value, label)
end
local function closeFrame(a, b, label)
    local first, second = {a:GetComponents()}, {b:GetComponents()}
    for index = 1, 12 do
        check(math.abs(first[index] - second[index]) < 0.0001, label .. " / component " .. index)
    end
end
local function parts(parent)
    local found = {}
    for _, item in parent:GetDescendants() do
        if item:IsA("BasePart") then table.insert(found, item) end
    end
    return found
end
local function countParts(parent)
    local count = 0
    for _, item in parent:GetDescendants() do
        if item:IsA("BasePart") then count += 1 end
    end
    return count
end
local baseEnvironment = {
    Instance = Instance, CFrame = CF, Vector3 = V,
    Color3 = roblox.Color3, Enum = roblox.Enum,
    warn = function() end,
}
local Models = luau.load(fs.readFile("src/server/WeaponModels.luau"), {
    environment = baseEnvironment,
})()
local function stall()
    return roblox.deserializeModel(fs.readFile("assets/weapons/WeaponStall.rbxmx"))[1]
end
local source = stall()
local displays = source:FindFirstChild("Displays")
local expectedParts = {Saber = 52, Musket = 43}
local expectedGrips = {
    Saber = CF.new(0, 0.02, 0),
    Musket = CF.new(0, 0.02, 0) * CF.Angles(math.pi * 0.5, 0, 0),
}
local built = {}
local function verify(display, tool, id, label)
    local displayParts, toolParts = parts(display), parts(tool)
    local reference = display:FindFirstChild("Handle")
    local handle = tool:FindFirstChild("Handle")
    check(tool:IsA("Tool") and tool.Name == id, label .. ": correct Tool root")
    check(tool:GetAttribute("WeaponType") == id, label .. ": combat weapon identity")
    check(tool.RequiresHandle and not tool.CanBeDropped, label .. ": safe Tool settings")
    check(handle and handle:IsA("BasePart"), label .. ": direct Handle")
    check(countParts(tool) == expectedParts[id], label .. ": complete display geometry")
    check(tool:GetAttribute("WeaponModelKey") == Models.Key(display, id), label .. ": current source key")
    closeFrame(tool.Grip, expectedGrips[id], label .. ": weapon-specific native grip")
    local expectedAxis = id == "Saber" and V.yAxis or V.new(0, 0, -1)
    check(tool.Grip:VectorToObjectSpace(V.yAxis):Dot(expectedAxis) > .999,
        label .. ": blade/barrel preserves its native hand axis")
    local welds, welded = 0, {}
    for _, item in tool:GetDescendants() do
        check(not item:IsA("LuaSourceContainer"), label .. ": no executable model descendants")
        if item:IsA("WeldConstraint") then
            welds += 1
            check(item.Part0 == handle and item.Part1 and item.Part1 ~= handle,
                label .. ": weld uses this Tool's actual Handle")
            check(table.find(toolParts, item.Part1) ~= nil, label .. ": weld target remains inside cloned Tool")
            check(not welded[item.Part1], label .. ": no duplicate decorative weld")
            welded[item.Part1] = true
        elseif item:IsA("JointInstance") then
            check(false, label .. ": no copied display joints")
        end
    end
    check(welds == expectedParts[id] - 1, label .. ": one weld per decorative part")
    for _, original in displayParts do
        local name = original.Name
        local expected = reference.CFrame:ToObjectSpace(original.CFrame)
        local copy
        -- Some details share names (the two stock inlays); identify their
        -- actual handle-local placement instead of collapsing a name map.
        for _, candidate in toolParts do
            if candidate.Name == name
                and (handle.CFrame:ToObjectSpace(candidate.CFrame).Position - expected.Position).Magnitude < .0001 then
                copy = candidate
                break
            end
        end
        check(copy ~= nil and copy.ClassName == original.ClassName, label .. ": preserves part " .. name)
        check(copy.Size == original.Size and copy.Color == original.Color
            and copy.Material == original.Material and copy.Transparency == original.Transparency,
            label .. ": preserves dimensions and appearance of " .. name)
        check(copy.Reflectance == original.Reflectance and copy.CastShadow == original.CastShadow,
            label .. ": preserves shading of " .. name)
        closeFrame(handle.CFrame:ToObjectSpace(copy.CFrame), reference.CFrame:ToObjectSpace(original.CFrame),
            label .. ": preserves relative geometry of " .. name)
        check(not copy.Anchored and copy.Massless and not copy.CanCollide
            and not copy.CanTouch and not copy.CanQuery, label .. ": safe equipped physics for " .. name)
        check(copy == handle or welded[copy], label .. ": decorative part connected to hand " .. name)
    end
    if id == "Saber" then
        local blade = tool:FindFirstChild("Blade")
        check(blade and blade.Transparency == 1 and blade.Size.Y > 3,
            label .. ": preserves invisible full-length trail anchor")
        check(tool:FindFirstChild("CurvedSteel10") and tool:FindFirstChild("KnuckleGuard10")
            and tool:FindFirstChild("Point"), label .. ": preserves curved blade, bow and point")
    else
        local barrel, displayBarrel = tool:FindFirstChild("Barrel"), display:FindFirstChild("Barrel")
        local muzzle, displayMuzzle = barrel:FindFirstChild("Muzzle"), displayBarrel:FindFirstChild("Muzzle")
        check(muzzle and muzzle:IsA("Attachment"), label .. ": preserves actual muzzle attachment")
        closeFrame(muzzle.CFrame, displayMuzzle.CFrame, label .. ": muzzle remains at same barrel-local position")
        closeFrame(handle.CFrame:ToObjectSpace(barrel.CFrame * muzzle.CFrame),
            reference.CFrame:ToObjectSpace(displayBarrel.CFrame * displayMuzzle.CFrame),
            label .. ": muzzle remains at the true barrel end")
        check(tool:FindFirstChild("Stock") and tool:FindFirstChild("FlintHammer")
            and tool:FindFirstChild("TriggerGuard12"), label .. ": preserves stock, lock and trigger guard")
    end
end
local originalFrames = {}
for _, id in {"Saber", "Musket"} do
    local display = displays:FindFirstChild(id .. "Display")
    check(countParts(display) == expectedParts[id], id .. ": detailed authoritative display fixture")
    for _, part in parts(display) do originalFrames[part] = part.CFrame end
    local tool = Models.Build(display, id)
    built[id] = tool
    verify(display, tool, id, "build " .. id)
    local roundTrip = roblox.deserializeModel(roblox.serializeModel({tool}, true))[1]
    verify(display, roundTrip, id, "XML round trip " .. id)
    local static = roblox.deserializeModel(fs.readFile("assets/weapons/" .. id .. ".rbxmx"))[1]
    closeFrame(static.Grip, expectedGrips[id], id .. ": static Tool matches runtime grip")
    check(countParts(static) == expectedParts[id], id .. ": static Tool retains all display details")
end
for part, frame in originalFrames do
    check(part.Anchored, "Building equipped Tools leaves each displayed part anchored")
    closeFrame(part.CFrame, frame, "Building equipped Tools leaves display placement unchanged")
end

local function legacy(id, parent)
    local tool = Instance.new("Tool")
    tool.Name = id
    tool:SetAttribute("WeaponType", id)
    local handle = Instance.new("Part")
    handle.Name = "Handle"; handle.Size = V.new(.2, 1.1, .2); handle.Parent = tool
    local extra = Instance.new("Part")
    extra.Name = id == "Saber" and "Blade" or "Barrel"
    extra.Size = V.new(.08, 3.4, .28); extra.Parent = tool
    tool.Parent = parent
    return tool
end
local bank = Instance.new("Folder")
bank.Name = "Weapons"
local oldSaber, oldMusket = legacy("Saber", bank), legacy("Musket", bank)
local keys = Models.Sync(bank, displays)
check(oldSaber.Parent == nil and oldMusket.Parent == nil, "Stock migration removes legacy two-part templates")
check(#bank:GetChildren() == 2, "Stock migration retains exactly two templates")
local firstSaber, firstMusket = bank:FindFirstChild("Saber"), bank:FindFirstChild("Musket")
check(countParts(firstSaber) == 52 and countParts(firstMusket) == 43,
    "Stock migration replaces stubs with the full displayed weapons")
check(keys.Saber == firstSaber:GetAttribute("WeaponModelKey")
    and keys.Musket == firstMusket:GetAttribute("WeaponModelKey"), "Stock sync returns authoritative model keys")
Models.Sync(bank, displays)
check(bank:FindFirstChild("Saber") == firstSaber and bank:FindFirstChild("Musket") == firstMusket,
    "Repeated sync keeps already current stock instances")
local curved = displays:FindFirstChild("SaberDisplay"):FindFirstChild("CurvedSteel10")
local previousKey = Models.Key(displays:FindFirstChild("SaberDisplay"), "Saber")
curved.Size += V.new(0, .035, 0)
local changedKey = Models.Key(displays:FindFirstChild("SaberDisplay"), "Saber")
check(changedKey ~= previousKey, "Changing the displayed geometry invalidates its model key")
keys = Models.Sync(bank, displays)
check(bank:FindFirstChild("Saber") ~= firstSaber and firstSaber.Parent == nil,
    "A changed display replaces its obsolete stock template")
check(bank:FindFirstChild("Saber"):FindFirstChild("CurvedSteel10").Size == curved.Size,
    "Rebuilt stock uses the updated display dimensions")
check(bank:FindFirstChild("Musket") == firstMusket,
    "A Saber display update preserves unchanged Musket stock")

-- Real shop grants must retire stubs already in hands or backpack without
-- repurchasing weapons or touching the user's ordinary fishing equipment.
local modelsScript = Instance.new("ModuleScript")
modelsScript.Name = "WeaponModels"
local shopEnvironment = table.clone(baseEnvironment)
-- Lune's XML Instance type intentionally omits yielding WaitForChild.
-- Adapt only these two lookup interfaces; models and inventory remain native.
shopEnvironment.script = {Parent = {WaitForChild = function(_, name)
    check(name == "WeaponModels", "Shop looks up its server model module")
    return modelsScript
end}}
shopEnvironment.require = function(module)
    check(module == modelsScript, "Shop uses its existing server WeaponModels dependency")
    return Models
end
local Shop = luau.load(fs.readFile("src/server/WeaponShop.luau"), {environment = shopEnvironment})()
local Catalog = luau.load(fs.readFile("src/shared/WeaponCatalog.luau"))()
local character = Instance.new("Model")
local humanoid = Instance.new("Humanoid"); humanoid.Health = 100; humanoid.Parent = character
local backpack = Instance.new("Backpack")
local player = {Character = character}
function player:FindFirstChild(name) return name == "Backpack" and backpack or nil end
local owned = {Saber = true, Musket = true}
local data = {OwnedWeapons = owned, Coins = 1234}
local profiles = {Get = function(requested)
    check(requested == player, "Grant reads this player's existing profile")
    return data
end}
local freshStall = stall()
local oldHand = legacy("Saber", character)
local oldBag = legacy("Musket", backpack)
local rod = Instance.new("Tool")
rod.Name = "FishingRod"; rod:SetAttribute("QuietCoveRod", true); rod.Parent = character
local unrelated = Instance.new("Tool")
unrelated.Name = "UnrelatedEquipment"; unrelated:SetAttribute("WeaponType", "Other"); unrelated.Parent = backpack
local counter = {Position = freshStall:FindFirstChild("Counter").CFrame.Position,
    Parent = {WaitForChild = function(_, name)
        check(name == "Displays", "Shop synchronizes from its actual stall displays")
        return freshStall:FindFirstChild("Displays")
    end}}
local shop = Shop.new(Catalog, profiles, bank, counter,
    function() end, function() end, function() return false end, function() end)
local granted = shop:Grant(player, character)
check(oldHand.Parent == nil and oldBag.Parent == nil,
    "Grant replaces legacy owned weapons from both character and backpack")
check(granted.Saber and countParts(granted.Saber) == 52
    and granted.Musket and countParts(granted.Musket) == 43,
    "Existing ownership grants the actual detailed display models")
check(granted.Saber:GetAttribute("WeaponModelKey") == bank:FindFirstChild("Saber"):GetAttribute("WeaponModelKey")
    and granted.Musket:GetAttribute("WeaponModelKey") == bank:FindFirstChild("Musket"):GetAttribute("WeaponModelKey"),
    "Granted inventory carries the current model keys")
check(data.Coins == 1234 and data.OwnedWeapons == owned and owned.Saber and owned.Musket,
    "Inventory migration preserves money and purchase ownership without charging again")
check(rod.Parent == character and unrelated.Parent == backpack,
    "Inventory migration preserves the fishing rod and unrelated equipment")
local again = shop:Grant(player, character)
check(again.Saber == granted.Saber and again.Musket == granted.Musket,
    "Repeated grant does not replace or duplicate current detailed owned weapons")
local currentCount = 0
for _, parent in {character, backpack} do
    for _, item in parent:GetChildren() do
        if item:IsA("Tool") and Catalog.ById[item:GetAttribute("WeaponType")] then currentCount += 1 end
    end
end
check(currentCount == 2, "Each owned weapon appears exactly once after repeated migration")

-- A grip-only revision must invalidate a full detailed Tool, not just the
-- old two-part placeholder, and use the ordinary free ownership grant path.
local correctGrip = Models.Grip
local display = freshStall:FindFirstChild("Displays"):FindFirstChild("SaberDisplay")
local currentKey = Models.Key(display, "Saber")
Models.Grip = function(id)
    return id == "Saber" and expectedGrips.Musket or correctGrip(id)
end
local oldGripKey = Models.Key(display, "Saber")
check(oldGripKey ~= currentKey, "Grip matrix alone changes the model fingerprint")
local oldDetailedSaber = Models.Build(display, "Saber")
closeFrame(oldDetailedSaber.Grip, expectedGrips.Musket, "Previous full-detail Saber retains old quarter-turn fixture")
check(countParts(oldDetailedSaber) == 52, "Grip migration fixture retains all existing Saber geometry")
Models.Grip = correctGrip
check(Models.Key(display, "Saber") == currentKey, "Restoring native grip restores the current fingerprint")
granted.Saber:Destroy()
oldDetailedSaber.Parent = character
local corrected = shop:Grant(player, character)
check(oldDetailedSaber.Parent == nil and corrected.Saber ~= oldDetailedSaber,
    "Owned detailed Saber is replaced when only its grip revision is stale")
verify(display, corrected.Saber, "Saber", "owned grip-only migration")
check(corrected.Musket == granted.Musket, "Saber grip migration preserves the existing current Musket")
check(data.Coins == 1234 and data.OwnedWeapons == owned and owned.Saber and owned.Musket,
    "Grip-only migration never charges existing owners or clears ownership")
check(rod.Parent == character and unrelated.Parent == backpack,
    "Grip-only migration preserves the fishing rod and unrelated equipment")
local final = shop:Grant(player, character)
check(final.Saber == corrected.Saber and final.Musket == corrected.Musket,
    "Corrected native grips remain stable on subsequent grants")

-- Genuine v1 inventory keys from the unchanged 52/43-part display fixture.
local v1Keys = {Saber = "display-237815b3", Musket = "display-33d7bfd4"}
for _, id in {"Saber", "Musket"} do
    check(Models.Key(freshStall:FindFirstChild("Displays"):FindFirstChild(id .. "Display"), id) ~= v1Keys[id],
        id .. ": v2 fingerprint invalidates the previous deployed revision")
end

print("PASS weapon display/runtime identity: " .. checks .. " checks (real 52/43-part XML models, stock sync, owned inventory migration)")
