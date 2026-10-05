-- Asset-free, editable low-poly island. Build() can also be run from Studio's Command Bar.
local World = {}
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("QuietCove"):WaitForChild("Config"))
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local function part(parent, name, size, position, color, material)
    local p = Instance.new("Part")
    p.Name, p.Size, p.Position = name, size, position
    p.Anchored = true; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
    p.Color = Color3.fromRGB(color[1], color[2], color[3])
    p.Material = material or Enum.Material.SmoothPlastic
    p.Parent = parent
    return p
end
local function label(parent, text, height, width)
    local gui = Instance.new("BillboardGui")
    gui.Name = "Label"; gui.Size = UDim2.fromOffset(width or 260, 58)
    gui.StudsOffset = Vector3.new(0, height or 3, 0); gui.MaxDistance = 120
    gui.AlwaysOnTop = false; gui.Parent = parent
    local t = Instance.new("TextLabel")
    t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1
    t.TextColor3 = Color3.fromRGB(248, 240, 216); t.TextStrokeTransparency = 0.25
    t.Font = Enum.Font.GothamBold; t.TextSize = 19; t.TextWrapped = true; t.Text = text; t.Parent = gui
end
local function prompt(parent, name, action, object)
    local p = Instance.new("ProximityPrompt")
    p.Name = name; p.ActionText = action; p.ObjectText = object
    p.KeyboardKeyCode = Enum.KeyCode.E; p.HoldDuration = 0.2
    p.MaxActivationDistance = 12; p.RequiresLineOfSight = false; p.Parent = parent
    return p
end
local function npc(parent, name, x, z, shirt, text, action)
    local model = Instance.new("Model"); model.Name = name; model.Parent = parent
    local body = part(model, "Body", Vector3.new(2.5, 2.8, 1.4), Vector3.new(x, 9.2, z), shirt)
    part(model, "Head", Vector3.new(1.7, 1.7, 1.7), Vector3.new(x, 11.4, z), {224, 181, 139})
    part(model, "Hat", Vector3.new(2.5, 0.35, 2.2), Vector3.new(x, 12.35, z), {53, 66, 65})
    for _, side in ipairs({-1, 1}) do
        part(model, "Arm", Vector3.new(0.65, 2.5, 1), Vector3.new(x + side * 1.65, 9.2, z), shirt)
        part(model, "Leg", Vector3.new(0.9, 1.5, 1.2), Vector3.new(x + side * 0.65, 7.15, z), {48, 59, 65})
        local eye = part(model, "Eye", Vector3.new(0.17, 0.17, 0.1), Vector3.new(x + side * 0.36, 11.55, z - 0.86), {28, 39, 48})
        eye.CanCollide = false
    end
    label(body, text, 5.5)
    prompt(body, name .. "Prompt", action, text)
    return body
end
local function palm(parent, x, z, height)
    local trunk = part(parent, "PalmTrunk", Vector3.new(1.8, height, 1.8), Vector3.new(x, 7 + height / 2, z), {136, 96, 62}, Enum.Material.Wood)
    trunk.CFrame = trunk.CFrame * CFrame.Angles(0, 0, math.rad(7))
    for i = 0, 5 do
        local a = i * math.pi / 3
        local leaf = part(parent, "PalmLeaf", Vector3.new(3.3, 0.65, 11), Vector3.new(x + math.sin(a) * 3.5, 7 + height, z + math.cos(a) * 3.5), {52, 126 + i * 4, 88}, Enum.Material.Grass)
        leaf.CFrame = CFrame.new(leaf.Position) * CFrame.Angles(0, a, math.rad(8))
        leaf.CanCollide = false
    end
end
local function refs(model)
    local reef = Config.IslandById.Reef
    return {
        Model = model,
        Merchant = model.Merchant.Body,
        Shop = model.Rodsmith.Body,
        Ferry = model.Ferry,
        ReturnFerry = model.ReturnFerry,
        Spawn = Vector3.new(0, 11, -19),
        ReefSpawn = Vector3.new(reef.X, 11, reef.Z - 20),
        Spots = {
            Cove = {Center = Vector3.new(0, 8, -99), Name = "Тихая бухта", Radius = 20},
            Reef = {Center = Vector3.new(reef.X, 8, reef.Z - 32), Name = "Коралловый риф", Radius = 17},
        },
    }
end
local function syncReef(model)
    local reef = Config.IslandById.Reef
    local rock = model:FindFirstChild("ReefRock")
    if not rock then return end
    -- The saved place has flat children, including duplicate palm names. Move the
    -- reef's whole local neighborhood together, instead of creating a second reef.
    local origin = rock.Position
    local offset = Vector3.new(reef.X - origin.X, 0, reef.Z - origin.Z)
    if offset.Magnitude > 0.001 then
        for _, object in ipairs(model:GetDescendants()) do
            if object:IsA("BasePart") then
                local relative = object.Position - origin
                if Vector3.new(relative.X, 0, relative.Z).Magnitude <= 120 then
                    object.CFrame = object.CFrame + offset
                end
            end
        end
    end
    local sign = model:FindFirstChild("ReefSign")
    local gui = sign and sign:FindFirstChild("Label")
    local text = gui and gui:FindFirstChildOfClass("TextLabel")
    if text then text.Text = "КОРАЛЛОВЫЙ РИФ\n" .. reef.Target end
end
function World.Build()
    local reef = Config.IslandById.Reef
    local waterSize = (Config.Ocean.HalfExtent + 100) * 2
    Workspace.Terrain:FillBlock(CFrame.new(0, -14, 0), Vector3.new(waterSize, 28, waterSize), Enum.Material.Water)
    Workspace.Terrain.WaterColor = Color3.fromRGB(31, 139, 155)
    Workspace.Terrain.WaterTransparency = 0.25; Workspace.Terrain.WaterWaveSize = 0.18
    Workspace.Terrain.WaterWaveSpeed = 8
    Lighting.ClockTime = 11; Lighting.Brightness = 2.4
    Lighting.Ambient = Color3.fromRGB(92, 115, 128); Lighting.OutdoorAmbient = Color3.fromRGB(120, 144, 153)
    Lighting.FogColor = Color3.fromRGB(153, 208, 213)
    Lighting.FogStart = 1200; Lighting.FogEnd = Config.Ocean.HalfExtent * 2
    local oceanPreview = Workspace:FindFirstChild("QuietCoveOceanPreview")
    if oceanPreview then oceanPreview:Destroy() end
    local existing = Workspace:FindFirstChild("QuietCoveMap")
    if existing then
        syncReef(existing)
        return refs(existing)
    end
    local preview = Workspace:FindFirstChild("StartHere")
    if preview then preview:Destroy() end
    local model = Instance.new("Model"); model.Name = "QuietCoveMap"; model.Parent = Workspace
    part(model, "IslandRock", Vector3.new(124, 16, 94), Vector3.new(0, -3, 0), {118, 139, 136}, Enum.Material.Rock)
    part(model, "IslandSand", Vector3.new(119, 2, 89), Vector3.new(0, 5, 0), {231, 215, 168}, Enum.Material.Sand)
    part(model, "IslandGrass", Vector3.new(99, 1, 68), Vector3.new(0, 6.5, 5), {89, 153, 108}, Enum.Material.Grass)
    part(model, "Path", Vector3.new(12, 0.2, 56), Vector3.new(0, 7.1, -5), {219, 201, 158}, Enum.Material.Sand)
    for i = 0, 19 do
        part(model, "PierPlank", Vector3.new(14, 1, 3.6), Vector3.new(0, 7, -36 - i * 3.65), {141, 106, 74}, Enum.Material.WoodPlanks)
    end
    part(model, "FishingPlatform", Vector3.new(28, 1, 18), Vector3.new(0, 7, -103), {159, 118, 79}, Enum.Material.WoodPlanks)
    for z = -39, -109, -14 do
        for _, x in ipairs({-6, 6}) do
            part(model, "PierSupport", Vector3.new(1.2, 13, 1.2), Vector3.new(x, 1.5, z), {107, 76, 54}, Enum.Material.Wood)
        end
    end
    local fishingSign = part(model, "FishingSign", Vector3.new(1, 4, 1), Vector3.new(-10, 9, -101), {106, 74, 55}, Enum.Material.Wood)
    label(fishingSign, "РЫБАЛКА\nЗажми и отпусти ЛКМ", 3, 300)
    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "CoveSpawn"; spawn.Size = Vector3.new(8, 0.2, 8)
    spawn.Position = Vector3.new(0, 7.3, -19); spawn.Anchored = true; spawn.Neutral = true
    spawn.Duration = 0; spawn.Transparency = 1; spawn.CanCollide = false; spawn.Parent = model
    npc(model, "Merchant", -20, -25, {215, 155, 82}, "МАРА · ПРОДАЖА УЛОВА", "Продать весь улов")
    npc(model, "Rodsmith", 20, -25, {76, 139, 151}, "ЛЕВ · МАСТЕР УДОЧЕК", "Выбрать удочку")
    for _, x in ipairs({-20, 20}) do
        part(model, "ShopCounter", Vector3.new(10, 2.4, 3.3), Vector3.new(x, 7.3, -29), {114, 84, 65}, Enum.Material.WoodPlanks)
        for _, dx in ipairs({-5, 5}) do
            part(model, "AwningPole", Vector3.new(0.6, 9, 0.6), Vector3.new(x + dx, 10.5, -25), {113, 85, 57}, Enum.Material.Wood)
        end
        part(model, "Awning", Vector3.new(12, 0.5, 8), Vector3.new(x, 15, -25), x < 0 and {209, 156, 101} or {93, 174, 167})
    end
    palm(model, -39, -12, 18); palm(model, 41, 4, 20); palm(model, 23, 27, 17); palm(model, -5, 25, 19)
    for i = 0, 4 do
        local tower = part(model, "Lighthouse", Vector3.new(10 - i * 0.6, 5, 10 - i * 0.6), Vector3.new(-32, 9 + i * 5, 17), i % 2 == 0 and {238, 231, 210} or {193, 108, 87})
        tower.Shape = Enum.PartType.Cylinder; tower.CFrame = tower.CFrame * CFrame.Angles(0, 0, math.pi / 2)
        tower.Size = Vector3.new(5, 10 - i * 0.6, 10 - i * 0.6)
    end
    local lamp = part(model, "Beacon", Vector3.new(6, 4, 6), Vector3.new(-32, 34, 17), {255, 224, 152}, Enum.Material.Neon)
    local light = Instance.new("PointLight"); light.Range = 55; light.Brightness = 2; light.Color = lamp.Color; light.Parent = lamp
    part(model, "LighthouseRoof", Vector3.new(10, 1, 10), Vector3.new(-32, 36.5, 17), {55, 76, 83})
    part(model, "FerryGangway", Vector3.new(18, 1, 8), Vector3.new(10, 7, -78), {141, 106, 74}, Enum.Material.WoodPlanks)
    local ferry = part(model, "Ferry", Vector3.new(1, 5, 1), Vector3.new(17, 9, -78), {59, 104, 126})
    label(ferry, "ПЕРЕПРАВА НА РИФ\nСо 2-го уровня", 4)
    prompt(ferry, "Travel", "На коралловый риф", "Переправа · уровень 2")
    part(model, "BoatHull", Vector3.new(9, 2, 17), Vector3.new(24, 1, -78), {90, 67, 52}, Enum.Material.WoodPlanks)
    part(model, "BoatDeck", Vector3.new(7, 0.5, 14), Vector3.new(24, 2.2, -78), {173, 135, 93}, Enum.Material.WoodPlanks)
    part(model, "ReefRock", Vector3.new(47, 12, 38), Vector3.new(reef.X, -1, reef.Z), {96, 142, 144}, Enum.Material.Rock)
    part(model, "ReefSand", Vector3.new(45, 1.5, 36), Vector3.new(reef.X, 5.6, reef.Z), {236, 222, 177}, Enum.Material.Sand)
    part(model, "ReefPier", Vector3.new(18, 1, 35), Vector3.new(reef.X, 7, reef.Z - 27), {137, 104, 80}, Enum.Material.WoodPlanks)
    local returnFerry = part(model, "ReturnFerry", Vector3.new(1, 5, 1), Vector3.new(reef.X + 6, 9, reef.Z - 15), {59, 104, 126})
    label(returnFerry, "ТИХАЯ БУХТА\nОбратно к торговцам", 4)
    prompt(returnFerry, "Travel", "Вернуться в бухту", "Обратная переправа")
    local reefSign = part(model, "ReefSign", Vector3.new(1, 4, 1), Vector3.new(reef.X - 7, 9, reef.Z - 37), {106, 74, 55})
    label(reefSign, "КОРАЛЛОВЫЙ РИФ\n" .. reef.Target, 3.5, 300)
    palm(model, reef.X - 11, reef.Z + 10, 14); palm(model, reef.X + 15, reef.Z + 10, 17)
    for i = 1, 10 do
        local a = i * 2.4
        local coral = part(model, "Coral", Vector3.new(2.3, 3 + i % 4, 2.3), Vector3.new(reef.X + math.sin(a) * 29, -1.3, reef.Z - 15 + math.cos(a) * 29), i % 2 == 0 and {207, 115, 136} or {129, 136, 214})
        coral.Shape = Enum.PartType.Ball; coral.CanCollide = false
    end
    -- A short staircase lets swimmers get back onto the main island.
    for i = 0, 7 do
        part(model, "BeachStep", Vector3.new(5, 1, 14), Vector3.new(77 - i * 3, i - 1, 7), {215, 202, 161}, Enum.Material.Sand)
    end
    return refs(model)
end
return World
