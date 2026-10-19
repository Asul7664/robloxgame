-- Authored architectural detail kits. Geometry is visual only: original island,
-- dock, fishing and boss collision geometry remains the source of truth.
local Landmarks = {}
local UP = Vector3.new(0, 1, 0)

local function group(parent, name)
    local model = Instance.new("Model")
    model.Name = name
    model.Parent = parent
    return model
end

local function part(parent, name, size, frame, color, material, shape)
    local p = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
    p.Name = name
    p.Size = size
    p.CFrame = frame
    p.Color = color
    p.Material = material or Enum.Material.SmoothPlastic
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = true
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    if shape == "Ball" then p.Shape = Enum.PartType.Ball end
    p.Parent = parent
    return p
end

local function block(parent, name, position, size, color, material)
    return part(parent, name, size, CFrame.new(position), color, material)
end

local function cylinder(parent, name, position, height, diameter, color, material)
    local p = part(parent, name, Vector3.new(height, diameter, diameter),
        CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), color, material)
    p.Shape = Enum.PartType.Cylinder
    return p
end

local function beam(parent, name, a, b, width, color, round)
    local delta = b - a
    local length = delta.Magnitude
    local direction = delta.Unit
    local reference = math.abs(direction.Y) < 0.98 and UP or Vector3.new(1, 0, 0)
    local across = reference:Cross(direction).Unit
    local up = direction:Cross(across).Unit
    local midpoint = (a + b) * 0.5
    if round then
        -- Cylinder length follows local X. Construct the orthonormal basis
        -- explicitly so Studio and the pinned offline renderer agree on axes.
        local frame = CFrame.fromMatrix(midpoint, direction, up, -across)
        local p = part(parent, name, Vector3.new(length, width, width),
            frame, color)
        p.Shape = Enum.PartType.Cylinder
        return p
    end
    local frame = CFrame.fromMatrix(midpoint, across, up, direction)
    return part(parent, name, Vector3.new(width, width, length), frame, color, Enum.Material.Wood)
end

local function crate(parent, origin, scale, palette)
    local m = group(parent, "SlattedSupplyCrate")
    block(m, "CrateBody", origin + UP * scale * 0.5,
        Vector3.new(scale, scale, scale), palette.Wood, Enum.Material.WoodPlanks)
    for _, side in ipairs({-1, 1}) do
        block(m, "CrateCornerBatten", origin + Vector3.new(side * scale * 0.42, scale * 0.5, -scale * 0.52),
            Vector3.new(scale * 0.13, scale * 1.04, scale * 0.12), palette.WoodLight)
        block(m, "CrateLidBatten", origin + Vector3.new(side * scale * 0.36, scale * 1.02, 0),
            Vector3.new(scale * 0.13, scale * 0.12, scale), palette.WoodDark)
    end
    beam(m, "CrateDiagonalBrace", origin + Vector3.new(-scale * 0.4, scale * 0.12, -scale * 0.54),
        origin + Vector3.new(scale * 0.4, scale * 0.88, -scale * 0.54), scale * 0.14, palette.WoodLight)
end

local function barrel(parent, origin, scale, palette)
    local m = group(parent, "HarborBarrel")
    cylinder(m, "StaveBody", origin + UP * scale * 0.5, scale, scale * 0.78,
        palette.Wood, Enum.Material.WoodPlanks)
    for _, height in ipairs({0.17, 0.79}) do
        cylinder(m, "IronHoop", origin + UP * scale * height, scale * 0.12,
            scale * 0.82, palette.Ink, Enum.Material.Metal)
    end
    cylinder(m, "InsetLid", origin + UP * scale * 1.01, scale * 0.06,
        scale * 0.64, palette.WoodLight, Enum.Material.WoodPlanks)
end

local function lantern(parent, position, palette)
    local m = group(parent, "WarmHarborLantern")
    block(m, "LanternLight", position, Vector3.new(0.6, 0.9, 0.6), palette.Gold, Enum.Material.Neon)
    block(m, "LanternFoot", position - UP * 0.52, Vector3.new(0.9, 0.18, 0.9), palette.Ink)
    block(m, "LanternCap", position + UP * 0.53, Vector3.new(1, 0.22, 1), palette.Ink)
    beam(m, "LanternHanger", position + UP * 0.65, position + UP * 1.35, 0.12, palette.Ink, true)
end

local function window(parent, center, width, height, palette)
    block(parent, "RecessedWindow", center, Vector3.new(width, height, 0.16), palette.Ink)
    for _, sign in ipairs({-1, 1}) do
        block(parent, "WindowJamb", center + Vector3.new(sign * (width + 0.12) * 0.5, 0, -0.08),
            Vector3.new(0.22, height + 0.36, 0.28), palette.Cream)
        block(parent, "WindowSill", center + Vector3.new(0, sign * (height + 0.12) * 0.5, -0.12),
            Vector3.new(width + 0.55, 0.22, 0.4), palette.Cream)
    end
    block(parent, "WindowMullion", center - Vector3.new(0, 0, 0.11),
        Vector3.new(0.14, height, 0.22), palette.WoodLight)
end

local function coveLighthouse(parent, origin, palette)
    local m = group(parent, "LighthouseArchitecture")
    local base = origin + Vector3.new(-32, 0, 17)
    cylinder(m, "TowerFoundation", base + UP * 0.2, 0.8, 12.8, palette.Rock)
    cylinder(m, "FoundationLip", base + UP * 0.65, 0.25, 11.6, palette.Cream)
    -- Existing tower is kept intact; new framed windows sit on its seaward face.
    for _, placement in ipairs({{Height = 7, Radius = 4.8}, {Height = 17, Radius = 4.2}}) do
        window(m, base + Vector3.new(0, placement.Height, -placement.Radius), 1.7, 2.5, palette)
    end
    block(m, "TowerDoor", base + Vector3.new(0, 2.7, -5.06), Vector3.new(2.7, 4.4, 0.2), palette.WoodDark)
    block(m, "DoorLintel", base + Vector3.new(0, 5.05, -5.2), Vector3.new(3.5, 0.4, 0.45), palette.Cream)
    for _, sign in ipairs({-1, 1}) do
        block(m, "DoorJamb", base + Vector3.new(sign * 1.53, 2.7, -5.2),
            Vector3.new(0.3, 4.5, 0.45), palette.Cream)
    end
    cylinder(m, "DoorHandle", base + Vector3.new(0.8, 2.6, -5.25), 0.25, 0.25, palette.Gold)
    cylinder(m, "LanternGalleryFloor", base + UP * 24.65, 0.45, 11.5, palette.Ink)
    local railing = {}
    for index = 1, 8 do
        local angle = index * math.pi / 4
        local foot = base + Vector3.new(math.sin(angle) * 5.25, 24.95, math.cos(angle) * 5.25)
        block(m, "GalleryUpright", foot + UP * 0.95, Vector3.new(0.24, 1.9, 0.24), palette.Cream)
        railing[index] = foot + UP * 1.8
    end
    for index = 1, 8 do
        beam(m, "GalleryHandrail", railing[index], railing[index % 8 + 1], 0.24, palette.Cream)
    end
    for index, offset in ipairs({Vector3.new(-5, 0.2, 2), Vector3.new(4.8, 0, 4.1)}) do
        part(m, "FoundationBoulder", Vector3.new(4, 2.3, 3.5),
            CFrame.new(base + offset) * CFrame.Angles(0.08, index, 0.14), palette.Rock, nil, "Wedge")
    end
end

local function fisherHut(parent, origin, palette)
    local m = group(parent, "FisherWorkshop")
    -- Back-right corner: clear of the central route and weapon stall at +24,+8.
    local base = origin + Vector3.new(34, 0, 25)
    local roofColor = palette.Shallows:Lerp(palette.Ink, 0.2)
    block(m, "RaisedPorch", base + Vector3.new(0, 0.12, -1), Vector3.new(18.8, 0.7, 15), palette.WoodDark)
    for index = 0, 8 do
        block(m, "PorchDeckPlank", base + Vector3.new(-8.4 + index * 2.1, 0.52, -1),
            Vector3.new(2.02, 0.18, 15), palette.WoodLight, Enum.Material.Wood)
    end
    block(m, "PorchStep", base + Vector3.new(0, 0.1, -9), Vector3.new(8, 0.45, 2), palette.Wood)
    block(m, "BackWall", base + Vector3.new(0, 4.3, 5.9), Vector3.new(17, 7.5, 0.6), palette.Cream)
    for _, sign in ipairs({-1, 1}) do
        block(m, "WorkshopSideWall", base + Vector3.new(sign * 8.2, 4.3, 0),
            Vector3.new(0.6, 7.5, 12), palette.Cream)
        block(m, "DoorSideWall", base + Vector3.new(sign * 5.1, 4.3, -5.9),
            Vector3.new(6.2, 7.5, 0.6), palette.Cream)
        for _, depth in ipairs({-6.2, 6.2}) do
            block(m, "CornerTimber", base + Vector3.new(sign * 8.5, 4.5, depth),
                Vector3.new(0.65, 8.2, 0.65), palette.WoodDark)
        end
        window(m, base + Vector3.new(sign * 5.2, 5, -6.26), 2.6, 2.7, palette)
    end
    block(m, "WorkshopDoor", base + Vector3.new(0, 3.5, -6.3), Vector3.new(3.5, 5.8, 0.3), palette.WoodDark)
    block(m, "DoorLintel", base + Vector3.new(0, 7.1, -6.33), Vector3.new(4.3, 0.55, 0.8), palette.Wood)
    block(m, "DoorHandle", base + Vector3.new(1.1, 3.4, -6.52), Vector3.new(0.15, 0.55, 0.18), palette.Gold)
    block(m, "FrontEaveBeam", base + Vector3.new(0, 8.5, -7.3), Vector3.new(19.8, 0.6, 0.65), palette.WoodDark)
    block(m, "RearEaveBeam", base + Vector3.new(0, 8.5, 7.3), Vector3.new(19.8, 0.6, 0.65), palette.WoodDark)
    -- Close the triangular gables below the pitched boards. Wedge thickness is
    -- local X, with its high edge toward local +Z; mirror the two roof halves.
    for _, depth in ipairs({-5.9, 5.9}) do
        for _, side in ipairs({-1, 1}) do
            part(m, "WorkshopGableInfill", Vector3.new(0.4, 4.2, 9.5),
                CFrame.new(base + Vector3.new(side * 4.75, 10.15, depth))
                    * CFrame.Angles(0, side * -math.pi / 2, 0),
                palette.Cream, Enum.Material.WoodPlanks, "Wedge")
        end
    end
    -- Individual overlapping long roof boards produce a proper pitched silhouette.
    for _, sign in ipairs({-1, 1}) do
        for row = 0, 7 do
            part(m, "PitchedRoofBoard", Vector3.new(10.7, 0.42, 2.04),
                CFrame.new(base + Vector3.new(sign * 4.7, 10.4, -7 + row * 2))
                    * CFrame.Angles(0, 0, sign * -0.39),
                row % 2 == 0 and roofColor or roofColor:Lerp(palette.Cream, 0.10))
        end
        beam(m, "GableRafter", base + Vector3.new(0, 12.5, -7.45),
            base + Vector3.new(sign * 9.9, 8.5, -7.45), 0.45, palette.WoodDark)
    end
    block(m, "RoofRidgeCap", base + Vector3.new(0, 12.55, 0), Vector3.new(0.8, 0.55, 16.2), palette.WoodDark)
    -- A hanging net is a purposeful workshop prop, rather than floating debris.
    local net = base + Vector3.new(-8.62, 4.8, 0)
    for index = 0, 4 do
        beam(m, "NetVerticalCord", net + Vector3.new(0, 1.5, -2.6 + index * 1.3),
            net + Vector3.new(0, -2.5, -2.6 + index * 1.3), 0.07, palette.WoodLight, true)
    end
    for index = 0, 3 do
        beam(m, "NetHorizontalCord", net + Vector3.new(0, 1.5 - index * 1.3, -2.6),
            net + Vector3.new(0, 1.5 - index * 1.3, 2.6), 0.07, palette.WoodLight, true)
    end
    lantern(m, base + Vector3.new(3, 6.8, -6.7), palette)
    crate(m, base + Vector3.new(-6.4, 0.65, -7), 2.4, palette)
    barrel(m, base + Vector3.new(6.4, 0.65, -7), 2.8, palette)
end

local function marketStalls(parent, origin, palette)
    local m = group(parent, "MarketStallDetails")
    for _, x in ipairs({-20, 20}) do
        local stall = group(m, x < 0 and "CatchMerchantJoinery" or "RodsmithJoinery")
        local base = origin + Vector3.new(x, 0, -25)
        local accent = x < 0 and palette.Gold or palette.Shallows
        block(stall, "CounterOverhangingTop", base + Vector3.new(0, 1.6, -4),
            Vector3.new(10.6, 0.28, 3.8), palette.WoodLight, Enum.Material.Wood)
        block(stall, "CounterFrontKickboard", base + Vector3.new(0, -0.65, -5.73),
            Vector3.new(10.5, 0.4, 0.32), palette.WoodDark)
        for _, side in ipairs({-1, 1}) do
            block(stall, "CounterCornerBatten", base + Vector3.new(side * 4.95, 0.3, -5.73),
                Vector3.new(0.4, 2.55, 0.32), palette.WoodDark)
            -- The side fascia follows the existing canopy and its modest slope;
            -- diagonal knee braces connect it to the two existing support poles.
            beam(stall, "AwningSideFascia", base + Vector3.new(side * 6.1, 7.45, -4.1),
                base + Vector3.new(side * 6.1, 7.65, 4.1), 0.48, palette.WoodDark)
            for _, depth in ipairs({-1, 1}) do
                beam(stall, "AwningKneeBrace", base + Vector3.new(side * 5, 5.25, 0),
                    base + Vector3.new(side * 5, 7.45, depth * 3.6), 0.32, palette.WoodDark)
            end
        end
        block(stall, "AwningFrontFascia", base + Vector3.new(0, 7.45, -4.15),
            Vector3.new(12.6, 0.48, 0.45), palette.WoodDark)
        block(stall, "AwningRearFascia", base + Vector3.new(0, 7.65, 4.15),
            Vector3.new(12.6, 0.48, 0.45), palette.WoodDark)
        for stripe = 0, 3 do
            block(stall, "StripedCanvasValance", base + Vector3.new(-4.5 + stripe * 3, 6.95, -4.19),
                Vector3.new(2.92, 0.7, 0.15), stripe % 2 == 0 and palette.Cream or accent)
        end
        if x < 0 then barrel(stall, base + Vector3.new(-6.3, 0, 2), 2.7, palette)
        else crate(stall, base + Vector3.new(6.3, 0, 2), 2.5, palette) end
    end
end

function Landmarks.Cove(parent, origin, theme)
    coveLighthouse(parent, origin, theme.Palette)
    fisherHut(parent, origin, theme.Palette)
    marketStalls(parent, origin, theme.Palette)
end

function Landmarks.Dock(parent, definition, deckY, theme)
    local p = theme.Palette
    local base = Vector3.new(definition.DockX, deckY, definition.DockZ)
    local m = group(parent, "HarborCarpentry")
    for _, side in ipairs({-1, 1}) do
        block(m, "BoardwalkEdgeBeam", base + Vector3.new(side * 6.1, -0.35, -9),
            Vector3.new(0.8, 1.1, 36), p.WoodDark)
        block(m, "JettyEdgeBeam", base + Vector3.new(side * 14.6, -0.35, 6),
            Vector3.new(0.8, 1.1, 14), p.WoodDark)
        local previous
        for _, depth in ipairs({-24, -13, -3}) do
            local foot = base + Vector3.new(side * 6.2, 0, depth)
            block(m, "RopeRailPost", foot + UP * 1.3, Vector3.new(0.6, 2.6, 0.6), p.WoodDark)
            if previous then
                beam(m, "RopeHandrail", previous, foot + UP * 2.05, 0.18, p.WoodLight, true)
            end
            previous = foot + UP * 2.05
        end
    end
    -- Cargo stays at the back-right edge; captain, buyer and swim stairs stay clear.
    crate(m, base + Vector3.new(11, 0, -3.7), 2.4, p)
    barrel(m, base + Vector3.new(11.2, 0, 0.1), 2.8, p)
    lantern(m, base + Vector3.new(-13, 2, 9), p)
    local cleat = base + Vector3.new(-13, 1.4, 9)
    beam(m, "MooringLine", cleat, cleat + Vector3.new(-3.5, -1.7, 2), 0.2, p.WoodLight, true)
    beam(m, "MooringLineReturn", cleat + Vector3.new(-3.5, -1.7, 2),
        cleat + Vector3.new(0, -0.2, 0.4), 0.2, p.WoodLight, true)
end

local function duneTemple(parent, origin, p, biome)
    local m = group(parent, "SunTempleCarvings")
    local base = origin + Vector3.new(27, 0, -5)
    -- Three worn front steps lead onto the existing stepped sandstone structure.
    for index = 0, 2 do
        block(m, "TempleApproachStep", base + Vector3.new(0, index * 0.55, -16.5 - (2 - index) * 1.5),
            Vector3.new(8.5 - index * 0.4, 0.65, 2.5), biome.Rock:Lerp(p.Sand, 0.25))
    end
    for tier = 0, 3 do
        local span = 29 - tier * 4
        block(m, "TempleCornice", base + Vector3.new(0, 2.25 + tier * 3, -span * 0.5 - 0.1),
            Vector3.new(span + 0.35, 0.35, 0.65), p.Sand)
        for _, side in ipairs({-1, 1}) do
            block(m, "TempleSideCornice", base + Vector3.new(side * (span * 0.5 + 0.1), 2.25 + tier * 3, 0),
                Vector3.new(0.65, 0.35, span), p.Sand)
        end
    end
    for _, side in ipairs({-1, 1}) do
        block(m, "ShrinePortalPillar", base + Vector3.new(side * 4.15, 16.35, -6.9),
            Vector3.new(0.75, 4.2, 0.9), biome.Rock)
        cylinder(m, "CeremonialUrnBase", base + Vector3.new(side * 11.5, 0.2, -18.8), 0.4, 3, biome.Rock)
        part(m, "CeremonialUrn", Vector3.new(2.8, 3.7, 2.8),
            CFrame.new(base + Vector3.new(side * 11.5, 2.2, -18.8)), p.Wood, nil, "Ball")
        cylinder(m, "UrnRim", base + Vector3.new(side * 11.5, 4.1, -18.8), 0.3, 1.8, p.Cream)
        cylinder(m, "UrnOpening", base + Vector3.new(side * 11.5, 4.27, -18.8), 0.08, 1.2, p.WoodDark)
    end
    block(m, "ShrinePortalLintel", base + Vector3.new(0, 18.6, -6.9), Vector3.new(9, 0.7, 1.2), p.Sand)
    part(m, "SunRelief", Vector3.new(2.4, 2.4, 0.3),
        CFrame.new(base + Vector3.new(0, 18.6, -7.6)), p.Gold, nil, "Ball")
    -- Repeating carved glyphs are inset panels on the temple's seaward face.
    for index = -2, 2 do
        part(m, "TempleDiamondInlay", Vector3.new(0.55, 0.55, 0.12),
            CFrame.new(base + Vector3.new(index * 2.6, 1, -14.62)) * CFrame.Angles(0, 0, math.pi / 4), p.WoodDark)
    end
end

local function mossGrove(parent, origin, p, biome)
    local m = group(parent, "AncientGroveSanctum")
    local base = origin + Vector3.new(24, 0, -8)
    for _, side in ipairs({-1, 1}) do
        block(m, "GroveFooting", base + Vector3.new(side * 9, 0.3, 0), Vector3.new(6, 0.8, 7.2), biome.Rock)
        block(m, "GroveCapital", base + Vector3.new(side * 9, 9.4, 0), Vector3.new(5.3, 0.8, 6.3), p.Cream:Lerp(biome.Rock, 0.6))
        -- Vines follow the uprights, then sag over the arch in a continuous line.
        local previous = base + Vector3.new(side * 10.4, 1, -3)
        for index = 1, 3 do
            local nextPoint = base + Vector3.new(side * (10.4 - (index % 2) * 0.6), 1 + index * 2.9, -3.1)
            beam(m, "GroveClimbingVine", previous, nextPoint, 0.32, biome.Leaves, true)
            previous = nextPoint
        end
        part(m, "VineLeafCluster", Vector3.new(3.8, 1.2, 2.3),
            CFrame.new(base + Vector3.new(side * 8.9, 12.7, -1.7)), biome.Leaves, nil, "Ball")
    end
    for index = -2, 2 do
        local angle = index * 0.17
        part(m, "GroveKeystone", Vector3.new(2.5, 1.1, 6),
            CFrame.new(base + Vector3.new(index * 3.8, 12.6 - math.abs(index) * 0.12, 0)) * CFrame.Angles(0, angle, 0),
            biome.Rock:Lerp(p.Cream, index % 2 == 0 and 0.18 or 0.08))
    end
    cylinder(m, "GroveOfferingPedestal", base + Vector3.new(0, 1.05, 3.5), 2.1, 5.5, biome.Rock)
    cylinder(m, "GroveOfferingRim", base + Vector3.new(0, 2.2, 3.5), 0.35, 6.2, p.Cream:Lerp(biome.Rock, 0.6))
    for index = 1, 4 do
        local angle = index * math.pi / 2
        block(m, "WeatheredGrovePaving", base + Vector3.new(math.sin(angle) * 5.5, 0.1, math.cos(angle) * 5.5 + 3.5),
            Vector3.new(3.5, 0.35, 2.7), biome.Rock:Lerp(p.Cream, 0.15))
    end
end

local function bloomGarden(parent, origin, p, biome)
    local m = group(parent, "CappuccinoGardenTerrace")
    local base = origin + Vector3.new(24, 0, 0)
    -- A radial balustrade gives the existing cup sculpture a designed terrace.
    local previous
    for index = 0, 6 do
        local angle = -math.pi * 0.34 + index * math.pi * 0.78 / 6
        local position = base + Vector3.new(math.cos(angle) * 15, 0, math.sin(angle) * 15)
        cylinder(m, "TerraceBaluster", position + UP * 1.4, 2.8, 0.6, p.Cream)
        part(m, "BalusterFinial", Vector3.new(0.9, 0.9, 0.9), CFrame.new(position + UP * 3), p.Gold, nil, "Ball")
        if previous then beam(m, "TerraceHandrail", previous, position + UP * 2.4, 0.35, p.Cream) end
        previous = position + UP * 2.4
    end
    for _, depth in ipairs({-15, 16}) do
        local seat = base + Vector3.new(1, 0, depth)
        block(m, "GardenBenchSeat", seat + UP * 1.7, Vector3.new(7, 0.4, 2), p.WoodLight)
        block(m, "GardenBenchBack", seat + Vector3.new(0, 2.8, 0.85), Vector3.new(7, 1.8, 0.35), p.Wood)
        for _, side in ipairs({-1, 1}) do
            block(m, "GardenBenchLeg", seat + Vector3.new(side * 2.5, 0.8, 0), Vector3.new(0.6, 1.6, 1.6), p.WoodDark)
        end
    end
    for _, side in ipairs({-1, 1}) do
        local point = base + Vector3.new(side * 8.5, 0, -15)
        cylinder(m, "TerracottaPlanter", point + UP * 0.9, 1.8, 3.5, p.Coral:Lerp(p.Wood, 0.4))
        cylinder(m, "PlanterLip", point + UP * 1.85, 0.25, 3.8, p.Cream)
        part(m, "PlanterBlossoms", Vector3.new(4.1, 1.7, 3.8),
            CFrame.new(point + UP * 2.4), biome.Leaves, nil, "Ball")
    end
end

local function stormObservatory(parent, origin, p, biome)
    local m = group(parent, "StormCrystalResearchCamp")
    local base = origin + Vector3.new(-28, 0, 2)
    cylinder(m, "CrystalSurveyFoundation", base + UP * 0.2, 0.55, 17, biome.Rock)
    cylinder(m, "SurveyRingInset", base + UP * 0.52, 0.15, 14.5, p.Ink)
    cylinder(m, "SurveyInnerPlatform", base + UP * 0.64, 0.15, 12.8, biome.Rock)
    for index = 1, 8 do
        local angle = index * math.pi / 4
        local center = base + Vector3.new(math.sin(angle) * 7.5, 0.66, math.cos(angle) * 7.5)
        part(m, "SurveyCompassInlay", Vector3.new(0.3, 0.08, 1.1),
            CFrame.new(center) * CFrame.Angles(0, angle, 0), p.Gold)
    end
    local bench = base + Vector3.new(-1, 0, 13)
    block(m, "SurveyTableTop", bench + UP * 2.7, Vector3.new(8, 0.45, 3.3), p.Wood)
    for _, side in ipairs({-1, 1}) do
        block(m, "SurveyTableLeg", bench + Vector3.new(side * 2.9, 1.3, 0),
            Vector3.new(0.65, 2.6, 2.5), p.WoodDark)
    end
    part(m, "SurveyMap", Vector3.new(3.2, 0.08, 2.5),
        CFrame.new(bench + Vector3.new(-1.1, 2.99, 0)) * CFrame.Angles(0, 0.12, 0), p.Cream)
    for index = 1, 3 do
        part(m, "SurveyCrystalSample", Vector3.new(0.5, 0.6 + index * 0.25, 0.6),
            CFrame.new(bench + Vector3.new(1.4 + index * 0.4, 3.2, 0)) * CFrame.Angles(0.1, index, 0.2),
            biome.Accent, nil, "Wedge")
    end
    lantern(m, bench + Vector3.new(-3, 3.4, 0), p)
    crate(m, base + Vector3.new(8, 0, 12), 2.5, p)
    for _, side in ipairs({-1, 1}) do
        block(m, "StormWarningStake", base + Vector3.new(side * 9.5, 2, -8), Vector3.new(0.5, 4, 0.5), p.WoodDark)
        block(m, "StormWarningBoard", base + Vector3.new(side * 9.5, 3.1, -8), Vector3.new(2.8, 0.8, 0.22), p.Gold)
    end
end

function Landmarks.Island(parent, definition, topY, theme)
    local origin = Vector3.new(definition.X, topY, definition.Z)
    local biome = theme.Biomes[definition.Theme]
    if not biome then return end
    if definition.Theme == "sand" then duneTemple(parent, origin, theme.Palette, biome)
    elseif definition.Theme == "moss" then mossGrove(parent, origin, theme.Palette, biome)
    elseif definition.Theme == "bloom" then bloomGarden(parent, origin, theme.Palette, biome)
    elseif definition.Theme == "storm" then stormObservatory(parent, origin, theme.Palette, biome)
    end
end

return Landmarks
