-- Static silhouette/details pass. No physics, particles, external assets, or frame loop.
-- Keep six fronds / three segments: the complete archipelago adds fewer than 420
-- parts. Their CanQuery=false also keeps fishing, weapon rays, and AI unobstructed.
local Scenery = {}
local VERSION = "tropical-scenery-1"
local FROND_COUNT = 6
local FROND_SEGMENTS = 3

local function visual(parent, name, size, frame, color, shape, shadow)
    local object = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
    object.Name = name
    object.Size = size
    object.CFrame = frame
    object.Color = color
    object.Material = Enum.Material.SmoothPlastic
    object.Anchored = true
    object.CanCollide = false
    object.CanTouch = false
    object.CanQuery = false
    object.CastShadow = shadow == true
    object.TopSurface = Enum.SurfaceType.Smooth
    object.BottomSurface = Enum.SurfaceType.Smooth
    if shape == "Ball" then object.Shape = Enum.PartType.Ball end
    if shape == "Cylinder" then object.Shape = Enum.PartType.Cylinder end
    object.Parent = parent
    return object
end

local function fresh(parent, name, anchor, theme)
    local key = VERSION .. ":" .. tostring(theme.Version or 1)
    local old = parent:FindFirstChild(name)
    if old and old:GetAttribute("SceneryVersion") == key
        and old:GetAttribute("AnchorX") == anchor.X
        and old:GetAttribute("AnchorY") == anchor.Y
        and old:GetAttribute("AnchorZ") == anchor.Z then
        return nil
    end
    -- Only replace this module's own versioned folder; leave user folders alone.
    if old and old:GetAttribute("SceneryVersion") then old:Destroy()
    elseif old then return nil end
    local folder = Instance.new("Folder")
    folder.Name = name
    folder:SetAttribute("SceneryVersion", key)
    folder:SetAttribute("AnchorX", anchor.X)
    folder:SetAttribute("AnchorY", anchor.Y)
    folder:SetAttribute("AnchorZ", anchor.Z)
    folder.Parent = parent
    return folder
end

local function palm(folder, trunk, leaves, palette)
    local height = trunk.Size.Y
    local crown = trunk.CFrame:PointToWorldSpace(Vector3.new(0, height * 0.5, 0))
    local spread = math.clamp(height / 18, 0.82, 1.12)
    visual(folder, "PalmCrown", Vector3.new(3.5, 1.8, 3.5) * spread,
        CFrame.new(crown), leaves, "Ball", true)
    local leafLight = leaves:Lerp(palette.LeafLight, 0.30)
    local points = {
        {Radius = 0.5, Rise = 0.2, Width = 2.4},
        {Radius = 3.1, Rise = 1.5, Width = 3.0},
        {Radius = 6.7, Rise = 0.8, Width = 1.7},
        {Radius = 10.5, Rise = -1.7, Width = 0.5},
    }
    for index = 1, FROND_COUNT do
        local angle = index * math.pi * 2 / FROND_COUNT + trunk.Position.X * 0.013
        local direction = Vector3.new(math.sin(angle), 0, math.cos(angle))
        for segment = 1, FROND_SEGMENTS do
            local first, last = points[segment], points[segment + 1]
            local a = crown + (direction * first.Radius + Vector3.new(0, first.Rise, 0)) * spread
            local b = crown + (direction * last.Radius + Vector3.new(0, last.Rise, 0)) * spread
            local frame = CFrame.lookAt((a + b) * 0.5, b)
            -- Rounded overlapping lobes create an arch; a tapered final wedge
            -- supplies a readable pointed tip rather than the old flat plank.
            visual(folder, "PalmFrond", Vector3.new(first.Width * spread, 0.58 * spread, (b - a).Magnitude + 0.6),
                frame, index % 2 == 0 and leafLight or leaves,
                segment == FROND_SEGMENTS and "Wedge" or "Ball", segment < FROND_SEGMENTS)
        end
    end
    for index = 1, 3 do
        local angle = index * math.pi * 2 / 3
        local offset = Vector3.new(math.sin(angle) * 1.05, -0.85, math.cos(angle) * 1.05) * spread
        visual(folder, "Coconut", Vector3.new(1.35, 1.65, 1.35) * spread,
            CFrame.new(crown + offset) * CFrame.Angles(0.2, angle, 0.12), palette.WoodDark, "Ball", false)
    end
    for _, fraction in ipairs({0.58, 0.81}) do
        visual(folder, "PalmCollar", Vector3.new(0.16, trunk.Size.X * 1.08, trunk.Size.Z * 1.08),
            trunk.CFrame * CFrame.new(0, height * (fraction - 0.5), 0) * CFrame.Angles(0, 0, math.pi / 2),
            palette.WoodLight, "Cylinder", false)
    end
end

local function hideOldFronds(parent, center, radius)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("BasePart") and child.Name == "PalmLeaf"
            and Vector3.new(child.Position.X - center.X, 0, child.Position.Z - center.Z).Magnitude <= radius then
            if child:GetAttribute("QCOriginalTransparency") == nil then
                child:SetAttribute("QCOriginalTransparency", child.Transparency)
            end
            if child:GetAttribute("QCOriginalCanQuery") == nil then
                child:SetAttribute("QCOriginalCanQuery", child.CanQuery)
            end
            if child:GetAttribute("QCOriginalCanTouch") == nil then
                child:SetAttribute("QCOriginalCanTouch", child.CanTouch)
            end
            child.Transparency = 1
            -- Retired invisible fronds must not catch musket/fishing rays or
            -- touch handlers. Keep the original flags for a reversible migration.
            child.CanQuery = false
            child.CanTouch = false
        end
    end
end

local function owns(parent, name)
    local folder = parent:FindFirstChild(name)
    return folder and folder:GetAttribute("SceneryVersion") ~= nil
end

local function palms(parent, folder, center, radius, biome, palette)
    local count = 0
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("BasePart") and (child.Name == "PalmTrunk" or child.Name == "TreeTrunk") then
            local distance = Vector3.new(child.Position.X - center.X, 0, child.Position.Z - center.Z).Magnitude
            if distance <= radius then
                palm(folder, child, biome.Leaves, palette)
                count += 1
            end
        end
    end
    return count
end

local function rocks(folder, position, color, angle)
    visual(folder, "ShoreRock", Vector3.new(4.8, 3.2, 4.2),
        CFrame.new(position + Vector3.new(0, 1.0, 0)) * CFrame.Angles(0.1, angle, 0.12), color, "Wedge", true)
    visual(folder, "ShorePebble", Vector3.new(3.0, 2.0, 2.7),
        CFrame.new(position + Vector3.new(math.cos(angle) * 2.2, 0.6, math.sin(angle) * 2.2)),
        color:Lerp(Color3.new(1, 1, 1), 0.13), "Ball", true)
end

local function flower(folder, position, color, leaves, cream, angle)
    visual(folder, "FlowerStem", Vector3.new(0.14, 1.0, 0.14),
        CFrame.new(position + Vector3.new(0, 0.5, 0)), leaves, nil, false)
    for index = 1, 3 do
        local a = angle + index * math.pi * 2 / 3
        local offset = Vector3.new(math.sin(a) * 0.42, 1, math.cos(a) * 0.42)
        visual(folder, "FlowerPetal", Vector3.new(0.8, 0.24, 0.8),
            CFrame.new(position + offset), color, "Ball", false)
    end
    visual(folder, "FlowerHeart", Vector3.new(0.42, 0.26, 0.42),
        CFrame.new(position + Vector3.new(0, 1.10, 0)), cream, "Ball", false)
end

local function grass(folder, position, leaves, angle)
    for index = -1, 1 do
        visual(folder, "BeachPlant", Vector3.new(0.65, 2.4 - math.abs(index) * 0.5, 0.65),
            CFrame.new(position + Vector3.new(index * 0.45, 0.85, 0)) * CFrame.Angles(0.12, angle, index * -0.32),
            leaves, "Wedge", false)
    end
end

local function coral(folder, position, color, angle)
    for index = -1, 1 do
        visual(folder, "CoralBranch", Vector3.new(0.9, 2.5 - math.abs(index) * 0.6, 0.9),
            CFrame.new(position + Vector3.new(index * 0.65, 0.7, 0)) * CFrame.Angles(0, angle, -index * 0.45),
            color, "Ball", false)
    end
end

local function styleMap(map, config, theme)
    local sand = map:FindFirstChild("IslandSand")
    local reef = map:FindFirstChild("ReefSand")
    if not sand or not reef then return end
    local folder = map:FindFirstChild("QCScenery")
    if not folder then folder = Instance.new("Folder"); folder.Name = "QCScenery"; folder.Parent = map end
    local homeBiome, reefBiome = theme.Biomes.home, theme.Biomes.reef
    local home = fresh(folder, "Cove", sand.Position, theme)
    if home then
        palms(map, home, sand.Position, 120, homeBiome, theme.Palette)
        local grassSurface = map:FindFirstChild("IslandGrass") or sand
        local origin = Vector3.new(sand.Position.X, grassSurface.Position.Y + grassSurface.Size.Y * 0.5 + 0.05, sand.Position.Z)
        for index, point in ipairs({{-44, -24}, {44, 25}, {-45, 29}}) do
            rocks(home, origin + Vector3.new(point[1], 0, point[2]), homeBiome.Rock, index * 1.4)
        end
        flower(home, origin + Vector3.new(-27, 0, 26), theme.Palette.Coral, homeBiome.Leaves, theme.Palette.Gold, 0.3)
        flower(home, origin + Vector3.new(35, 0, -13), theme.Palette.Cream, homeBiome.Leaves, theme.Palette.Gold, 1.2)
    end
    local reefDetails = fresh(folder, "Reef", reef.Position, theme)
    if reefDetails then
        palms(map, reefDetails, reef.Position, 60, reefBiome, theme.Palette)
        local top = reef.Position.Y + reef.Size.Y * 0.5
        for index, side in ipairs({-1, 1}) do
            rocks(reefDetails, Vector3.new(reef.Position.X + side * 18, top, reef.Position.Z - 2), reefBiome.Rock, index)
        end
        for index = 1, 3 do
            coral(reefDetails, Vector3.new(reef.Position.X - 20 + index * 10, -0.8, reef.Position.Z + 22),
                index % 2 == 0 and theme.Palette.Purple or theme.Palette.Coral, index)
        end
    end
    if owns(folder, "Cove") then hideOldFronds(map, sand.Position, 120) end
    if owns(folder, "Reef") then hideOldFronds(map, reef.Position, 60) end
end

local function styleIsland(model, definition, theme)
    local plateau = model:FindFirstChild("Plateau")
    if not plateau then return end
    local biome = theme.Biomes[definition.Theme]
    if not biome then return end
    local folder = fresh(model, "QCScenery", plateau.Position, theme)
    if not folder then return end
    local center = Vector3.new(plateau.Position.X, plateau.Position.Y + plateau.Size.X * 0.5, plateau.Position.Z)
    -- Plateau is a cylinder rotated onto Y; its local X stores vertical height.
    local radius = definition.Radius
    if definition.Theme == "sand" then
        palms(model, folder, center, radius, biome, theme.Palette)
        hideOldFronds(model, center, radius)
    end
    -- All ground details sit at the rim (|X| > .60 radius). The ten-stud
    -- north/south route, dock access and Sahur landing/combat lane stay open.
    for index, point in ipairs({{-0.74, -0.30}, {0.72, 0.39}, {-0.69, 0.48}}) do
        rocks(folder, center + Vector3.new(point[1] * radius, 0, point[2] * radius), biome.Rock, index * 1.8)
    end
    if definition.Theme == "sand" then
        for index = 1, 3 do
            grass(folder, center + Vector3.new(-radius * 0.62, 0, -radius * 0.40 + index * 11), biome.Leaves, index)
        end
    elseif definition.Theme == "storm" then
        for index = 1, 3 do
            local position = center + Vector3.new(radius * 0.64, 0, -radius * 0.45 + index * 15)
            visual(folder, "CrystalShard", Vector3.new(1.5, 3.4, 1.6),
                CFrame.new(position + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0.15, index, -0.2),
                biome.Accent, "Wedge", true)
            visual(folder, "CrystalChip", Vector3.new(1.0, 1.8, 1.1),
                CFrame.new(position + Vector3.new(1.1, 0.65, 0.3)) * CFrame.Angles(0, -index, 0.25),
                theme.Palette.Purple, "Wedge", false)
        end
    else
        local count = definition.Theme == "bloom" and 3 or 2
        for index = 1, count do
            flower(folder, center + Vector3.new(-radius * 0.65, 0, -radius * 0.5 + index * 15),
                biome.Accent, biome.Leaves, theme.Palette.Gold, index)
        end
    end
end

function Scenery.Apply(map, archipelago, config, theme)
    if map then styleMap(map, config, theme) end
    if archipelago then
        for _, definition in ipairs(config.Islands) do
            if definition.Theme ~= "home" and definition.Theme ~= "reef" then
                local model = archipelago:FindFirstChild(definition.Id)
                if model then styleIsland(model, definition, theme) end
            end
        end
    end
end

return Scenery
