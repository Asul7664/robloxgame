-- Connected, asset-free vegetation silhouettes. This module only builds static
-- visual overlays; the original tree's size, frame and collision remain intact.
local Vegetation = {}
local UP = Vector3.new(0, 1, 0)
local TAU = math.pi * 2

local function part(parent, collection, name, size, frame, color, shape, material, shadow)
    local object = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
    object.Name = name
    object.Size = size
    object.CFrame = frame
    object.Color = color
    object.Material = material or Enum.Material.SmoothPlastic
    object.Anchored = true
    object.CanCollide = false
    object.CanQuery = false
    object.CanTouch = false
    object.CastShadow = shadow ~= false
    object.TopSurface = Enum.SurfaceType.Smooth
    object.BottomSurface = Enum.SurfaceType.Smooth
    if shape == "Cylinder" then object.Shape = Enum.PartType.Cylinder end
    if shape == "Ball" then object.Shape = Enum.PartType.Ball end
    object.Parent = parent
    table.insert(collection, object)
    return object
end

local function cylinder(parent, collection, name, a, b, diameter, color, shadow)
    local delta = b - a
    local axis = delta.Unit
    local reference = math.abs(axis:Dot(UP)) > 0.95 and Vector3.new(0, 0, 1) or UP
    local back = axis:Cross(reference).Unit
    local up = back:Cross(axis).Unit
    return part(parent, collection, name, Vector3.new(delta.Magnitude + 0.08, diameter, diameter),
        CFrame.fromMatrix((a + b) * 0.5, axis, up, back),
        color, "Cylinder", Enum.Material.Wood, shadow)
end

-- A WedgePart tapers in local Y, not in local X. Split the actual triangle at
-- the perpendicular to its longest edge, then orient the two right triangles.
-- This produces a pointed planform even when the leaf is viewed from below.
local function triangle(parent, collection, name, a, b, c, color, thickness, shadow)
    local ab, ac, bc = b - a, c - a, c - b
    local ab2, ac2, bc2 = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
    if ab2 > ac2 and ab2 > bc2 then
        c, a = a, c
    elseif ac2 > bc2 and ac2 > ab2 then
        a, b = b, a
    end
    ab, ac, bc = b - a, c - a, c - b
    local cross = ac:Cross(ab)
    if cross.Magnitude < 0.0001 or bc.Magnitude < 0.0001 then return end
    local right = cross.Unit
    local back = bc.Unit
    local up = back:Cross(right).Unit
    local height = math.abs(ab:Dot(up))
    local firstLength = math.abs(ab:Dot(back))
    local secondLength = math.abs(ac:Dot(back))
    -- Degenerate halves can arise when a perpendicular lands on a vertex.
    -- Skip them rather than introducing a zero-size wedge or NaN frame.
    if firstLength > 0.002 then
        part(parent, collection, name, Vector3.new(thickness, height, firstLength),
            CFrame.fromMatrix((a + b) * 0.5, right, up, back), color, "Wedge", nil, shadow)
    end
    if secondLength > 0.002 then
        part(parent, collection, name, Vector3.new(thickness, height, secondLength),
            CFrame.fromMatrix((a + c) * 0.5, -right, up, -back), color, "Wedge", nil, shadow)
    end
end

local function hideTrunk(trunk)
    if trunk:GetAttribute("QCOriginalTransparency") == nil then
        trunk:SetAttribute("QCOriginalTransparency", trunk.Transparency)
    end
    trunk.Transparency = 1
end

local function leaf(parent, collection, name, root, crest, tip, width, color, thickness, shadow)
    local outward = Vector3.new(tip.X - root.X, 0, tip.Z - root.Z)
    if outward.Magnitude < 0.001 then return end
    local side = outward.Unit:Cross(UP) * width * 0.5
    local left, right = crest + side, crest - side
    triangle(parent, collection, name, root, left, crest, color, thickness, shadow)
    triangle(parent, collection, name, crest, left, tip, color, thickness, shadow)
    local underside = color:Lerp(Color3.new(0.10, 0.22, 0.12), 0.06)
    triangle(parent, collection, name, root, crest, right, underside, thickness, shadow)
    triangle(parent, collection, name, crest, tip, right, underside, thickness, shadow)
end

function Vegetation.Palm(parent, trunk, biome, palette)
    local objects = {}
    local height = trunk.Size.Y
    local scale = math.clamp(height / 18, 0.76, 1.18)
    local base = trunk.CFrame:PointToWorldSpace(Vector3.new(0, -height * 0.5, 0))
    local top = trunk.CFrame:PointToWorldSpace(Vector3.new(0, height * 0.5, 0))
    local phase = trunk.Position.X * 0.037 + trunk.Position.Z * 0.023
    local lean = Vector3.new(math.sin(phase), 0, math.cos(phase)) * 0.85 * scale
    local wood = palette.WoodDark:Lerp(palette.Wood, 0.28)
    local bark = wood:Lerp(palette.WoodLight, 0.16)
    local function spine(t)
        return base:Lerp(top, t) + lean * math.sin(t * math.pi * 0.8)
    end
    -- The seven touching sections taper along a gentle bow, rather than leaving
    -- the old rectangular trunk visible behind disconnected decorative rings.
    for index = 1, 7 do
        local t0, t1 = (index - 1) / 7, index / 7
        cylinder(parent, objects, "PalmBark", spine(t0), spine(t1),
            (2.15 - t0 * 0.9) * scale, index % 2 == 0 and bark or wood)
    end
    for _, fraction in ipairs({0.18, 0.39, 0.60, 0.81}) do
        local center = spine(fraction)
        local tangent = (spine(fraction + 0.01) - spine(fraction - 0.01)).Unit
        cylinder(parent, objects, "PalmBarkRing", center - tangent * 0.10, center + tangent * 0.10,
            (2.15 - fraction * 0.9) * scale + 0.12, wood:Lerp(palette.WoodDark, 0.40), false)
    end
    local crown = spine(1)
    local leaves = biome.Leaves
    local midrib = leaves:Lerp(palette.LeafLight, 0.22)
    for index = 1, 7 do
        local angle = phase + index * TAU / 7
        local radial = Vector3.new(math.sin(angle), 0, math.cos(angle))
        local root = crown + radial * 0.12
        local crest = crown + (radial * (4.0 + index % 2 * 0.45) + UP * 1.65) * scale
        local tip = crown + (radial * (10.0 + index % 3 * 0.55) - UP * (1.65 + index % 2 * 0.4)) * scale
        local color = index % 2 == 0 and leaves:Lerp(palette.LeafLight, 0.12) or leaves
        leaf(parent, objects, "PalmFrond", root, crest, tip, 3.4 * scale, color, 0.12 * scale, true)
        for segment, points in ipairs({{root, crest}, {crest, tip}}) do
            local rib = cylinder(parent, objects, "PalmMidrib", points[1], points[2],
                (segment == 1 and 0.13 or 0.09) * scale, midrib, false)
            rib.Material = Enum.Material.SmoothPlastic
            rib:SetAttribute("FrondId", index)
            rib:SetAttribute("Segment", segment)
            rib:SetAttribute("Start", points[1])
            rib:SetAttribute("End", points[2])
        end
    end
    for index = 1, 3 do
        local angle = phase + index * TAU / 3
        local offset = Vector3.new(math.sin(angle) * 0.72, -0.65, math.cos(angle) * 0.72) * scale
        part(parent, objects, "Coconut", Vector3.new(1.05, 1.30, 1.05) * scale,
            CFrame.new(crown + offset), wood:Lerp(palette.WoodDark, 0.65), "Ball", nil, false)
    end
    hideTrunk(trunk)
    return objects
end

function Vegetation.Broadleaf(parent, trunk, biome, palette)
    local objects = {}
    local height = trunk.Size.Y
    local scale = math.clamp(height / 22, 0.85, 1.25)
    local base = trunk.CFrame:PointToWorldSpace(Vector3.new(0, -height * 0.5, 0))
    local crown = trunk.CFrame:PointToWorldSpace(Vector3.new(0, height * 0.5, 0))
    local phase = trunk.Position.X * 0.028 + trunk.Position.Z * 0.014
    local bend = Vector3.new(math.sin(phase), 0, math.cos(phase)) * 1.0 * scale
    local wood = palette.WoodDark:Lerp(palette.Wood, 0.20)
    local previous = base
    for index = 1, 3 do
        local t = index / 3
        local nextPoint = base:Lerp(crown, t) + bend * math.sin(t * math.pi * 0.75)
        cylinder(parent, objects, "TreeBark", previous, nextPoint, (3.1 - t * 1.05) * scale, wood)
        previous = nextPoint
    end
    crown = previous
    for index = 1, 3 do
        local angle = phase + index * TAU / 3
        local radial = Vector3.new(math.sin(angle), 0, math.cos(angle))
        cylinder(parent, objects, "TreeBough", crown - UP * 6.5 * scale,
            crown + radial * 6.1 * scale - UP * 0.6, 1.05 * scale, wood)
        cylinder(parent, objects, "TreeRoot", base + radial * 2.9 * scale + UP * 0.14,
            base + UP * 2.7 * scale, 1.0 * scale, wood)
    end
    -- A closed irregular hull: both the top and shaded underside are continuous
    -- leaf surfaces, with branches physically meeting the crown. Six facets keep
    -- the canopy readable at distance without the old three giant bubble balls.
    local edge = {}
    for index = 1, 6 do
        local angle = phase + index * TAU / 6
        local reach = 1 + math.sin(index * 2.1 + phase) * 0.10
        edge[index] = crown + Vector3.new(math.sin(angle) * 10.0 * reach,
            -0.4 + math.sin(index * 1.7) * 0.70, math.cos(angle) * 7.9 * reach) * scale
    end
    local apex = crown + Vector3.new(0.8, 3.9, -0.5) * scale
    local underside = crown + Vector3.new(-0.5, -3.0, 0.3) * scale
    local darkLeaves = biome.Leaves:Lerp(Color3.fromRGB(23, 62, 46), 0.20)
    for index = 1, 6 do
        local nextIndex = index % 6 + 1
        local topColor = index % 3 == 0 and biome.Leaves:Lerp(palette.Cream, 0.10) or biome.Leaves
        triangle(parent, objects, "TreeLeafCrown", apex, edge[index], edge[nextIndex], topColor, 0.15, true)
        triangle(parent, objects, "TreeLeafUnderside", underside, edge[nextIndex], edge[index], darkLeaves, 0.15, true)
    end
    hideTrunk(trunk)
    return objects
end

function Vegetation.Understory(parent, position, biome, palette, seed)
    local objects = {}
    local phase = (seed or 1) * 1.712
    local leaves = biome.Leaves
    -- Four pointed leaves share one grounded rosette. Their four solid triangles
    -- stay attached from the base to the tip, including when seen at eye level.
    for index = 1, 4 do
        local angle = phase + index * TAU / 4
        local radial = Vector3.new(math.sin(angle), 0, math.cos(angle))
        local root = position + UP * 0.06
        local crest = root + radial * 0.72 + UP * (1.35 + index % 2 * 0.25)
        local tip = root + radial * (1.85 + index % 2 * 0.25) + UP * 0.65
        local color = index % 2 == 0 and leaves:Lerp(palette.LeafLight, 0.12) or leaves
        -- One filled triangle per side is sufficient for these small leaves.
        local side = radial:Cross(UP) * 0.35
        triangle(parent, objects, "UnderstoryLeaf", root, crest + side, tip, color, 0.08, false)
        triangle(parent, objects, "UnderstoryLeaf", root, tip, crest - side, color, 0.08, false)
    end
    return objects
end

return Vegetation
