-- Original, asset-free 3D Tools for the supplied combat scripts.
-- Run from the repository root: lune run tools/build_weapons.luau
-- The .rbxmx files are the runtime assets; this generator is never run in-game.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local Enum = roblox.Enum

local palette = {
	walnut = Color3.fromRGB(85, 47, 29),
	woodHighlight = Color3.fromRGB(128, 78, 46),
	leather = Color3.fromRGB(43, 32, 27),
	brass = Color3.fromRGB(181, 132, 55),
	brassLight = Color3.fromRGB(221, 183, 101),
	steel = Color3.fromRGB(73, 82, 90),
	steelLight = Color3.fromRGB(182, 193, 202),
	blade = Color3.fromRGB(213, 226, 233),
	edge = Color3.fromRGB(238, 246, 251),
	bore = Color3.fromRGB(15, 18, 20),
}

local function part(tool, name, size, frame, color, material, class)
	local item = Instance.new(class or "Part")
	item.Name = name
	item.Size = size
	item.CFrame = frame
	item.Color = color
	item.Material = material or Enum.Material.Metal
	item.CanCollide = false
	item.CanTouch = false
	item.CanQuery = false
	item.Anchored = false
	item.Massless = true
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = tool
	return item
end

local function cylinder(tool, name, start, finish, radius, color, material)
	local axis = (finish - start).Unit
	local up = axis:Cross(math.abs(axis.X) < 0.9 and Vector3.xAxis or Vector3.yAxis).Unit
	local item = part(tool, name, Vector3.new((finish - start).Magnitude, radius * 2, radius * 2),
		CFrame.fromMatrix((start + finish) * 0.5, axis, up, axis:Cross(up)), color, material)
	item.Shape = Enum.PartType.Cylinder
	return item
end

local function seal(tool)
	local handle = tool:FindFirstChild("Handle")
	for _, item in tool:GetDescendants() do
		if item:IsA("BasePart") and item ~= handle then
			local joint = Instance.new("WeldConstraint")
			joint.Name = "HandleWeld"
			joint.Part0 = handle
			joint.Part1 = item
			joint.Parent = item
		end
	end
	return tool
end

local function tool(name)
	local item = Instance.new("Tool")
	item.Name = name
	item.RequiresHandle = true
	item.CanBeDropped = false
	item:SetAttribute("WeaponType", name)
	-- The saber keeps its +Y blade in the native hand orientation. The
	-- musket alone needs the quarter-turn to aim its barrel out of the hand.
	item.Grip = CFrame.new(0, 0.02, 0)
	if name == "Musket" then
		item.Grip *= CFrame.Angles(math.pi * 0.5, 0, 0)
	end
	return item
end

local function saber()
	local item = tool("Saber")
	item.ToolTip = "Сабля · ЛКМ — удар"
	part(item, "Handle", Vector3.new(0.20, 0.72, 0.23), CFrame.new(), palette.leather, Enum.Material.Wood)
	for index = 0, 5 do
		local wrap = part(item, "LeatherWrap" .. index, Vector3.new(0.235, 0.055, 0.265),
			CFrame.new(0, -0.27 + index * 0.105, 0), palette.leather, Enum.Material.Leather)
		wrap.Reflectance = 0
	end
	local pommel = part(item, "Pommel", Vector3.new(0.29, 0.20, 0.31), CFrame.new(0, -0.435, 0), palette.brass)
	pommel.Shape = Enum.PartType.Ball
	part(item, "HiltCollar", Vector3.new(0.26, 0.10, 0.29), CFrame.new(0, 0.35, 0), palette.brassLight)
	cylinder(item, "Crossguard", Vector3.new(0, 0.42, -0.43), Vector3.new(0, 0.42, 0.45), 0.065, palette.brassLight)
	local guardTip = part(item, "QuillonTip", Vector3.new(0.16, 0.16, 0.16), CFrame.new(0, 0.42, -0.44), palette.brass)
	guardTip.Shape = Enum.PartType.Ball
	-- A rounded D-shaped knuckle bow connects the guard to the pommel.
	local prior = Vector3.new(0, 0.42, 0.22)
	for index = 1, 10 do
		local t = index / 10
		local point = Vector3.new(0, 0.42 - 0.82 * t, 0.22 + math.sin(math.pi * t) * 0.31)
		cylinder(item, "KnuckleGuard" .. index, prior, point, 0.045, palette.brass)
		prior = point
	end
	part(item, "Ricasso", Vector3.new(0.065, 0.21, 0.25), CFrame.new(0, 0.54, 0), palette.steelLight)
	-- Blade is a stable, full-length Y-axis trail anchor. Its visible geometry
	-- uses short tangent-aligned pieces so the silhouette curves and tapers.
	local blade = part(item, "Blade", Vector3.new(0.055, 3.10, 0.27), CFrame.new(0, 2.02, 0.17), palette.blade)
	blade.Transparency = 1
	blade.CastShadow = false
	local startY, curvedLength, segments = 0.64, 2.36, 10
	for index = 1, segments do
		local t = (index - 0.5) / segments
		local y = startY + curvedLength * t
		local z = 0.31 * t * t
		local width = 0.26 - 0.065 * t
		local angle = math.atan(0.62 * t / curvedLength)
		local length = curvedLength / segments / math.cos(angle) + 0.013
		local frame = CFrame.new(0, y, z) * CFrame.Angles(angle, 0, 0)
		local steel = part(item, "CurvedSteel" .. index, Vector3.new(0.055, length, width), frame, palette.blade)
		steel.Reflectance = 0.10
		part(item, "SharpenedEdge" .. index, Vector3.new(0.059, length, 0.025),
			frame * CFrame.new(0, 0, width * 0.5 - 0.012), palette.edge)
		if index < 9 then
			part(item, "Fuller" .. index, Vector3.new(0.006, length - 0.015, 0.033),
				frame * CFrame.new(0.03, 0, -width * 0.13), palette.steelLight)
		end
	end
	local tip = part(item, "Point", Vector3.new(0.055, 0.52, 0.19),
		CFrame.new(0, 3.23, 0.369) * CFrame.Angles(0.255, 0, 0), palette.blade, nil, "WedgePart")
	tip.Reflectance = 0.10
	return seal(item)
end

local function musket()
	local item = tool("Musket")
	item.ToolTip = "Мушкет · ЛКМ — выстрел · перезарядка 1.7 с"
	part(item, "Handle", Vector3.new(0.25, 0.50, 0.33), CFrame.new(), palette.walnut, Enum.Material.Wood)
	part(item, "StockNeck", Vector3.new(0.29, 0.57, 0.32),
		CFrame.new(0, -0.30, -0.035) * CFrame.Angles(-0.12, 0, 0), palette.walnut, Enum.Material.Wood)
	part(item, "Stock", Vector3.new(0.34, 0.73, 0.54),
		CFrame.new(0, -0.98, -0.07), palette.walnut, Enum.Material.Wood)
	part(item, "StockTopTaper", Vector3.new(0.33, 0.46, 0.21),
		CFrame.new(0, -0.53, 0.11), palette.walnut, Enum.Material.Wood, "WedgePart")
	part(item, "ButtPlate", Vector3.new(0.36, 0.055, 0.57), CFrame.new(0, -1.36, -0.07), palette.brass)
	part(item, "Forestock", Vector3.new(0.23, 1.52, 0.27), CFrame.new(0, 0.89, 0.025), palette.walnut, Enum.Material.Wood)
	part(item, "ForestockRidge", Vector3.new(0.19, 1.35, 0.045), CFrame.new(0, 0.89, -0.12), palette.woodHighlight, Enum.Material.Wood)
	for _, x in { -0.175, 0.175 } do
		part(item, "StockInlay", Vector3.new(0.009, 0.44, 0.032), CFrame.new(x, -0.99, 0.055), palette.brass)
	end
	local barrel = cylinder(item, "Barrel", Vector3.new(0, 0.15, 0.225), Vector3.new(0, 2.11, 0.225), 0.092, palette.steel)
	barrel.Reflectance = 0.08
	cylinder(item, "Breech", Vector3.new(0, -0.09, 0.225), Vector3.new(0, 0.22, 0.225), 0.106, palette.steelLight)
	for index, y in { 0.28, 0.92, 1.53 } do
		part(item, "BarrelBand" .. index, Vector3.new(0.265, 0.065, 0.365), CFrame.new(0, y, 0.095), palette.brass)
		-- The exposed top face remains visibly steel; bands wrap the stock.
		part(item, "BandTop" .. index, Vector3.new(0.25, 0.07, 0.045), CFrame.new(0, y, 0.312), palette.brassLight)
	end
	cylinder(item, "MuzzleRing", Vector3.new(0, 2.07, 0.225), Vector3.new(0, 2.11, 0.225), 0.111, palette.steelLight)
	cylinder(item, "Bore", Vector3.new(0, 2.103, 0.225), Vector3.new(0, 2.113, 0.225), 0.064, palette.bore, Enum.Material.SmoothPlastic)
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	-- Cylinder axis is local X; the attachment is at the actual open face.
	muzzle.CFrame = barrel.CFrame:ToObjectSpace(CFrame.new(0, 2.113, 0.225))
	muzzle.Parent = barrel
	part(item, "FrontSight", Vector3.new(0.045, 0.11, 0.09), CFrame.new(0, 1.96, 0.347), palette.steel)
	part(item, "RearSight", Vector3.new(0.12, 0.08, 0.055), CFrame.new(0, 0.26, 0.346), palette.steel)
	cylinder(item, "Ramrod", Vector3.new(0.085, 0.35, -0.139), Vector3.new(0.085, 1.91, -0.139), 0.020, palette.steelLight)
	cylinder(item, "RamrodCap", Vector3.new(0.085, 1.84, -0.139), Vector3.new(0.085, 1.94, -0.139), 0.032, palette.brass)
	part(item, "LockPlate", Vector3.new(0.052, 0.40, 0.20), CFrame.new(0.18, 0.035, 0.11), palette.steelLight)
	part(item, "FlashPan", Vector3.new(0.17, 0.12, 0.035), CFrame.new(0.24, 0.11, 0.238), palette.brass)
	part(item, "FlintHammer", Vector3.new(0.065, 0.12, 0.26),
		CFrame.new(0.21, -0.09, 0.34) * CFrame.Angles(-0.39, 0, 0), palette.steel)
	part(item, "Flint", Vector3.new(0.085, 0.13, 0.085), CFrame.new(0.21, -0.028, 0.47), palette.bore)
	part(item, "Frizzen", Vector3.new(0.07, 0.21, 0.15),
		CFrame.new(0.205, 0.12, 0.367) * CFrame.Angles(0.24, 0, 0), palette.steel)
	for index, y in { -0.105, 0.17 } do
		cylinder(item, "LockScrew" .. index, Vector3.new(0.208, y, 0.10), Vector3.new(0.218, y, 0.10), 0.022, palette.brassLight)
	end
	local prior
	for index = 0, 12 do
		local angle = index / 12 * math.pi * 2
		local point = Vector3.new(0, -0.10 + math.sin(angle) * 0.20, -0.20 - math.cos(angle) * 0.135)
		if prior then
			cylinder(item, "TriggerGuard" .. index, prior, point, 0.022, palette.brass)
		end
		prior = point
	end
	cylinder(item, "Trigger", Vector3.new(0, 0.005, -0.08), Vector3.new(0, -0.065, -0.25), 0.018, palette.steel)
	return seal(item)
end

local function verify(item)
	assert(item:IsA("Tool"), "Asset root must be a Tool")
	assert(item:GetAttribute("WeaponType") == item.Name, "WeaponType must match tool name")
	assert(item.RequiresHandle and not item.CanBeDropped, "Tool handling settings")
	local handle = item:FindFirstChild("Handle")
	assert(handle and handle:IsA("Part"), "Tool needs a direct Part Handle")
	assert((handle.CFrame.Position - Vector3.zero).Magnitude < 0.001, "Grip reference must remain at the handle")
	local axis = item.Grip:VectorToObjectSpace(Vector3.yAxis)
	local expectedAxis = item.Name == "Saber" and Vector3.yAxis or Vector3.new(0, 0, -1)
	assert(axis:Dot(expectedAxis) > 0.999, "Weapon must use its correct native hand orientation")
	local partCount, weldCount = 0, 0
	for _, child in item:GetDescendants() do
		assert(not child:IsA("LuaSourceContainer"), "Models must not contain hidden scripts")
		if child:IsA("BasePart") then
			partCount += 1
			assert(not child.Anchored and not child.CanCollide and child.Massless, child.Name .. ": unsafe physics")
			assert(not child.CanTouch and not child.CanQuery, child.Name .. ": geometry must not intercept combat rays")
			if child ~= handle then
				local weld = child:FindFirstChild("HandleWeld")
				assert(weld and weld:IsA("WeldConstraint") and weld.Part0 == handle and weld.Part1 == child,
					child.Name .. ": must be welded to Handle")
			end
		elseif child:IsA("WeldConstraint") then
			weldCount += 1
		end
	end
	assert(weldCount == partCount - 1, "Exactly one weld per decorative part")
	assert(partCount < 70, "Tools should remain compact")
	if item.Name == "Saber" then
		local blade = item:FindFirstChild("Blade")
		assert(blade and blade:IsA("Part") and blade.Size.Y > 3, "CombatClient needs the Y-axis Blade trail anchor")
		assert(blade.Size.Y > blade.Size.X * 10 and blade.Size.Y > blade.Size.Z * 8, "Blade must use its local Y as the long axis")
		local point = item:FindFirstChild("Point")
		assert(point and point.CFrame.Position.Y > 3.1, "Saber tip must lie beyond the handle")
	elseif item.Name == "Musket" then
		local barrel = item:FindFirstChild("Barrel")
		local muzzle = barrel and barrel:FindFirstChild("Muzzle")
		assert(barrel and muzzle and muzzle:IsA("Attachment"), "Musket needs Muzzle on Barrel")
		local muzzlePosition = (barrel.CFrame * muzzle.CFrame).Position
		assert((muzzlePosition - Vector3.new(0, 2.113, 0.225)).Magnitude < 0.001, "Muzzle must sit at the true barrel end")
		local localMuzzle = muzzle.CFrame.Position
		assert(math.abs(localMuzzle.X - barrel.Size.X * 0.5 - 0.003) < 0.001, "Muzzle must be beyond the barrel body, never at its centre")
		assert(localMuzzle.Y ^ 2 + localMuzzle.Z ^ 2 < 0.00001, "Muzzle must be centered in the bore")
		local butt = item:FindFirstChild("ButtPlate")
		local totalLength = muzzlePosition.Y - (butt.CFrame.Position.Y - butt.Size.Y * 0.5)
		assert(totalLength > 3.4 and totalLength < 3.6, "Musket must remain approximately 3.5 studs long")
	end
	return partCount, weldCount
end

fs.writeDir("assets/weapons")
for _, item in { saber(), musket() } do
	verify(item)
	local xml = roblox.serializeModel({ item }, true)
	local path = "assets/weapons/" .. item.Name .. ".rbxmx"
	fs.writeFile(path, xml)
	local reloaded = roblox.deserializeModel(fs.readFile(path))
	assert(#reloaded == 1, "Model serialization must preserve one Tool root")
	local parts, welds = verify(reloaded[1])
	print(string.format("PASS %s: %d parts, %d welds; physics, grip, geometry, and XML round-trip", path, parts, welds))
end
