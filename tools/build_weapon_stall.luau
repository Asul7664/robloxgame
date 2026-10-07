-- Original main-island weapon shop. Rebuild from the repository root with:
-- lune run tools/build_weapon_stall.luau
-- Display weapons reuse the game's own Tool assets; this script converts
-- their visible geometry into anchored Models, never collectible Tools.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local Enum = roblox.Enum

local origin = Vector3.new(24, 7.3, 8)
local colors = {
	wood = Color3.fromRGB(110, 69, 42),
	plank = Color3.fromRGB(151, 100, 60),
	trim = Color3.fromRGB(65, 39, 26),
	brass = Color3.fromRGB(199, 153, 65),
	rust = Color3.fromRGB(162, 57, 38),
	canvas = Color3.fromRGB(234, 206, 147),
	text = Color3.fromRGB(255, 239, 199),
	rack = Color3.fromRGB(47, 38, 30),
}

local stall = Instance.new("Model")
stall.Name = "WeaponStall"
stall:SetAttribute("WeaponShop", true)
stall:SetAttribute("GeneratedVersion", 1)

local function part(parent, name, size, position, color, collide, material)
	local item = Instance.new("Part")
	item.Name = name
	item.Size = size
	item.CFrame = CFrame.new(origin + position)
	item.Color = color
	item.Material = material or Enum.Material.WoodPlanks
	item.Anchored = true
	item.CanCollide = collide == true
	item.CanTouch = false
	item.CanQuery = collide == true
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
end

local function label(parent, name, text, color, size)
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 75
	gui.LightInfluence = 0
	gui.Parent = parent
	local item = Instance.new("TextLabel")
	item.Name = "Text"
	item.BackgroundTransparency = 1
	item.Size = roblox.UDim2.fromScale(1, 1)
	item.Text = text
	item.Font = Enum.Font.GothamBold
	item.TextColor3 = color or colors.text
	item.TextSize = size or 48
	item.TextScaled = true
	item.TextWrapped = false
	item.TextStrokeTransparency = 0.82
	item.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = roblox.UDim.new(0.025, 0)
	pad.PaddingRight = roblox.UDim.new(0.025, 0)
	pad.PaddingTop = roblox.UDim.new(0.08, 0)
	pad.PaddingBottom = roblox.UDim.new(0.08, 0)
	pad.Parent = item
	return gui
end

-- The top of the floor lies at 7.3, level with the island's flat ground.
local floor = part(stall, "Floor", Vector3.new(14, 0.3, 10), Vector3.new(0, -0.15, 0), colors.wood, true)
stall.PrimaryPart = floor
for index = 0, 9 do
	part(stall, "FloorBoard" .. index, Vector3.new(13.95, 0.035, 0.94),
		Vector3.new(0, 0.02, -4.5 + index), index % 2 == 0 and colors.plank or colors.wood)
end

for xIndex, x in { -6.5, 6.5 } do
	for zIndex, z in { -4.45, 4.45 } do
		part(stall, "Post" .. xIndex .. zIndex, Vector3.new(0.4, 6.7, 0.4), Vector3.new(x, 3.35, z), colors.trim)
		part(stall, "PostFoot" .. xIndex .. zIndex, Vector3.new(0.58, 0.35, 0.58), Vector3.new(x, 0.18, z), colors.wood)
	end
end
part(stall, "FrontRoofBeam", Vector3.new(14, 0.27, 0.28), Vector3.new(0, 6.45, -4.55), colors.trim)
part(stall, "BackRoofBeam", Vector3.new(14, 0.27, 0.28), Vector3.new(0, 7.22, 4.55), colors.trim)
part(stall, "LeftRoofBeam", Vector3.new(0.27, 0.27, 10), Vector3.new(-6.5, 6.85, 0), colors.trim)
part(stall, "RightRoofBeam", Vector3.new(0.27, 0.27, 10), Vector3.new(6.5, 6.85, 0), colors.trim)

local roofPitch = -math.atan(0.8 / 10.4)
for index = 0, 13 do
	local color = index % 2 == 0 and colors.rust or colors.canvas
	local stripe = part(stall, "AwningStripe" .. index, Vector3.new(1.035, 0.13, 10.4),
		Vector3.new(-6.5 + index, 7.08, 0), color, false, Enum.Material.Fabric)
	stripe.CFrame *= CFrame.Angles(roofPitch, 0, 0)
	part(stall, "AwningFrill" .. index, Vector3.new(1.035, 0.42, 0.13),
		Vector3.new(-6.5 + index, 6.45, -5.2), color, false, Enum.Material.Fabric)
end

local sign = part(stall, "ShopSign", Vector3.new(11.5, 1.0, 0.22), Vector3.new(0, 5.8, -5.15), colors.trim)
label(sign, "ShopName", "ОРУЖЕЙНАЯ ЛАВКА", colors.text, 54)
part(stall, "SignTopTrim", Vector3.new(11.7, 0.08, 0.26), Vector3.new(0, 6.3, -5.15), colors.brass, false, Enum.Material.Metal)
part(stall, "SignBottomTrim", Vector3.new(11.7, 0.08, 0.26), Vector3.new(0, 5.3, -5.15), colors.brass, false, Enum.Material.Metal)

local counter = part(stall, "Counter", Vector3.new(12.3, 2.7, 1.6), Vector3.new(0, 1.35, -3.5), colors.wood, true)
part(stall, "CounterTop", Vector3.new(12.9, 0.2, 1.9), Vector3.new(0, 2.8, -3.5), colors.plank, true)
for index = 0, 10 do
	part(stall, "CounterSlat" .. index, Vector3.new(1.04, 2.5, 0.05),
		Vector3.new(-5.5 + index * 1.1, 1.36, -4.325), index % 2 == 0 and colors.plank or colors.wood)
end
part(stall, "CounterLowerRail", Vector3.new(12.45, 0.13, 0.12), Vector3.new(0, 0.34, -4.35), colors.trim)
part(stall, "CounterUpperRail", Vector3.new(12.45, 0.13, 0.12), Vector3.new(0, 2.55, -4.35), colors.trim)

local prompt = Instance.new("ProximityPrompt")
prompt.Name = "WeaponShopPrompt"
prompt.ActionText = "Открыть оружейную"
prompt.ObjectText = "Сабля и мушкет"
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.MaxActivationDistance = 12
prompt.HoldDuration = 0.2
prompt.RequiresLineOfSight = false
prompt.Parent = counter

local displays = Instance.new("Folder")
displays.Name = "Displays"
displays.Parent = stall

local function displayWeapon(weaponName, localHandle, plaqueX, text)
	local source = roblox.deserializeModel(fs.readFile("assets/weapons/" .. weaponName .. ".rbxmx"))
	assert(#source == 1 and source[1]:IsA("Tool"), "Expected the existing " .. weaponName .. " Tool asset")
	local model = Instance.new("Model")
	model.Name = weaponName .. "Display"
	model:SetAttribute("WeaponType", weaponName)
	model.Parent = displays
	-- Local Y is the weapon's long axis. Lay it left-to-right with the broad
	-- silhouette facing the front of the counter (-Z), rather than edge-on.
	local target = CFrame.fromMatrix(origin + localHandle, Vector3.zAxis, Vector3.xAxis, Vector3.yAxis)
	for _, child in source[1]:GetChildren() do
		assert(not child:IsA("LuaSourceContainer"), "Weapon display source must not contain scripts")
		if child:IsA("BasePart") then
			local copy = child:Clone()
			for _, descendant in copy:GetDescendants() do
				if descendant:IsA("WeldConstraint") or descendant:IsA("JointInstance") then
					descendant:Destroy()
				end
			end
			copy.CFrame = target * child.CFrame
			copy.Anchored = true
			copy.CanCollide = false
			copy.CanTouch = false
			copy.CanQuery = false
			copy.Parent = model
		end
	end
	model.PrimaryPart = model:FindFirstChild("Handle")
	local rack = part(stall, weaponName .. "Rack", Vector3.new(5.0, 1.7, 0.22),
		Vector3.new(plaqueX, 3.7, -3.05), colors.rack)
	local plaque = part(stall, weaponName .. "Label", Vector3.new(4.9, 0.65, 0.12),
		Vector3.new(plaqueX, 2.05, -4.42), colors.trim)
	plaque:SetAttribute("WeaponType", weaponName)
	label(plaque, "WeaponName", text, colors.text, 44)
	-- Small brass pins hold the display without obscuring the silhouette.
	for _, x in { plaqueX - 1.7, plaqueX + 1.7 } do
		part(stall, weaponName .. "RackPin", Vector3.new(0.08, 0.24, 0.35),
			Vector3.new(x, 3.1, -3.25), colors.brass, false, Enum.Material.Metal)
	end
	return model, rack
end

displayWeapon("Saber", Vector3.new(-4.8, 3.75, -3.25), -3.2, "1. САБЛЯ")
displayWeapon("Musket", Vector3.new(2.9, 3.75, -3.25), 3.2, "2. МУШКЕТ")

-- Rear shelf and crates give the shop a silhouette from the island path.
part(stall, "RearShelf", Vector3.new(11.2, 0.18, 1.0), Vector3.new(0, 2.9, 3.8), colors.plank)
part(stall, "RearShelfSupportLeft", Vector3.new(0.3, 2.9, 0.7), Vector3.new(-4.8, 1.45, 3.8), colors.trim)
part(stall, "RearShelfSupportRight", Vector3.new(0.3, 2.9, 0.7), Vector3.new(4.8, 1.45, 3.8), colors.trim)
for index, x in { -4.5, -1.75, 1.0 } do
	part(stall, "StockCrate" .. index, Vector3.new(2.1, 1.5, 1.5), Vector3.new(x, 3.75, 3.7), colors.wood)
	for _, offset in { -0.8, 0.8 } do
		part(stall, "CrateBand" .. index, Vector3.new(0.12, 1.57, 1.56),
			Vector3.new(x + offset, 3.75, 3.7), colors.trim)
	end
end
local lantern = part(stall, "Lantern", Vector3.new(0.46, 0.75, 0.46), Vector3.new(5.0, 3.36, 3.8), colors.canvas, false, Enum.Material.Neon)
part(stall, "LanternTop", Vector3.new(0.57, 0.10, 0.57), Vector3.new(5.0, 3.78, 3.8), colors.trim, false, Enum.Material.Metal)
part(stall, "LanternBase", Vector3.new(0.57, 0.10, 0.57), Vector3.new(5.0, 2.95, 3.8), colors.trim, false, Enum.Material.Metal)
local light = Instance.new("PointLight")
light.Name = "WarmShopLight"
light.Color = colors.canvas
light.Brightness = 0.8
light.Range = 12
light.Shadows = false
light.Parent = lantern

local function verify(model)
	assert(model:IsA("Model") and model.Name == "WeaponStall", "One named Model root is required")
	assert(model:GetAttribute("WeaponShop") == true, "Shop marker must survive serialization")
	local floorPart = model:FindFirstChild("Floor")
	assert(floorPart and model.PrimaryPart == floorPart, "Root placement uses the floor")
	assert((floorPart.CFrame.Position - Vector3.new(24, 7.15, 8)).Magnitude < 0.001, "Stall must be on the main island")
	assert(math.abs(floorPart.CFrame.Position.Y + floorPart.Size.Y / 2 - 7.3) < 0.001, "Floor must sit on the island surface")
	local actualPrompt = model:FindFirstChild("Counter"):FindFirstChild("WeaponShopPrompt")
	assert(actualPrompt and actualPrompt:IsA("ProximityPrompt"), "Counter needs the shop interaction")
	assert(actualPrompt.KeyboardKeyCode == Enum.KeyCode.E and actualPrompt.MaxActivationDistance == 12, "E / shop range")
	assert(math.abs(actualPrompt.HoldDuration - 0.2) < 0.001 and not actualPrompt.RequiresLineOfSight, "Prompt must remain usable from the front")
	assert(actualPrompt.ActionText == "Открыть оружейную" and actualPrompt.ObjectText == "Сабля и мушкет", "Russian prompt text must survive UTF-8 round trip")
	local count = 0
	local minimum = Vector3.new(math.huge, math.huge, math.huge)
	local maximum = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, child in model:GetDescendants() do
		assert(not child:IsA("Tool") and not child:IsA("LuaSourceContainer") and not child:IsA("Humanoid"), "Shop must contain no Tools, scripts, or mob")
		if child:IsA("BasePart") then
			count += 1
			assert(child.Anchored and not child.CanTouch, "Every part must be static")
			assert(not child.CanCollide or child.Name == "Floor" or child.Name == "Counter" or child.Name == "CounterTop", "Only floor and counter may collide")
			assert(child.CFrame.Position.Y > 6.9 and child.CFrame.Position.Y < 15, "All shop geometry must remain near the island ground")
			assert(math.abs(child.CFrame.Position.X - 24) < 7.1 and math.abs(child.CFrame.Position.Z - 8) < 5.4, "Stall must fit its planned footprint")
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local corner = child.CFrame:PointToWorldSpace(child.Size * Vector3.new(x, y, z) * 0.5)
						minimum = Vector3.new(math.min(minimum.X, corner.X), math.min(minimum.Y, corner.Y), math.min(minimum.Z, corner.Z))
						maximum = Vector3.new(math.max(maximum.X, corner.X), math.max(maximum.Y, corner.Y), math.max(maximum.Z, corner.Z))
					end
				end
			end
		end
	end
	assert(minimum.Y >= 6.99 and maximum.Y < 15.2, "Actual model bounds must sit on the main-island ground")
	assert(minimum.X > 16.7 and maximum.X < 31.3 and minimum.Z > 2.5 and maximum.Z < 13.5, "Rotated part bounds must fit the stall footprint")
	assert(math.abs((minimum.X + maximum.X) * 0.5 - 24) < 0.1, "Model bounding box must remain centered at the weapon-shop location")
	local weaponDisplays = model:FindFirstChild("Displays")
	assert(weaponDisplays and #weaponDisplays:GetChildren() == 2, "Exactly two complete weapon displays")
	for _, weapon in { "Saber", "Musket" } do
		local display = weaponDisplays:FindFirstChild(weapon .. "Display")
		local original = roblox.deserializeModel(fs.readFile("assets/weapons/" .. weapon .. ".rbxmx"))[1]
		assert(display and display:IsA("Model") and display.PrimaryPart.Name == "Handle", "Display must be an anchored Model with a Handle")
		local expectedParts, displayParts = 0, 0
		for _, child in original:GetDescendants() do
			if child:IsA("BasePart") then expectedParts += 1 end
		end
		for _, child in display:GetDescendants() do
			if child:IsA("BasePart") then
				displayParts += 1
				assert(not child.CanCollide and not child.CanTouch and not child.CanQuery, "Displays must not block movement, prompts, or combat rays")
			end
		end
		assert(displayParts == expectedParts, "Display must reuse the full " .. weapon .. " geometry")
	end
	assert(model:FindFirstChild("ShopSign"):FindFirstChild("ShopName"):FindFirstChild("Text").Text == "ОРУЖЕЙНАЯ ЛАВКА", "Shop sign text must remain valid UTF-8")
	assert(model:FindFirstChild("SaberLabel"):FindFirstChild("WeaponName"):FindFirstChild("Text").Text == "1. САБЛЯ", "First weapon is the saber")
	assert(model:FindFirstChild("MusketLabel"):FindFirstChild("WeaponName"):FindFirstChild("Text").Text == "2. МУШКЕТ", "Second weapon is the musket")
	return count
end

verify(stall)
local path = "assets/weapons/WeaponStall.rbxmx"
fs.writeFile(path, roblox.serializeModel({ stall }, true))
local loaded = roblox.deserializeModel(fs.readFile(path))
assert(#loaded == 1, "XML round trip must preserve a single Model root")
local count = verify(loaded[1])
print(string.format("PASS %s: %d anchored parts, two complete weapon displays, prompt, UTF-8, placement, collision, and XML round-trip", path, count))
