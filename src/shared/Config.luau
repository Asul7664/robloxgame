-- Quiet Cove / Тихая бухта. All balance values live here.
local Config = {}
Config.Title = "ТИХАЯ БУХТА"
Config.Version = "0.2.9-hands-hands-islands-ballet"
Config.BagCapacity = 40
Config.XPPerLevel = 100
Config.SaveInStudio = false -- Keep false for normal local playtests.
Config.DataStoreName = "QuietCove_v2_brainrot"
Config.AutoSaveSeconds = 45
Config.SessionLeaseSeconds = 180
Config.ChargeSeconds = 1.2
-- The cast is not cosmetic-only timing: bites are impossible before touchdown.
Config.Casting = {
    WindupSeconds = 0.045,
    SwingSeconds = 0.18, -- Release marker, inside the fast forward stroke.
    StrokeEndSeconds = 0.34,
    SettleSeconds = 0.66,
    FlightSeconds = 0.86,
    ExtraFlightSeconds = 0.20,
    ArcHeight = 3.5,
    ExtraArcHeight = 2,
    EffectDistance = 240,
}
Config.HookWindow = 3
-- No time limit for Reeling. 0% progress still means the fish escaped.
-- These affect actual motion/loss without changing species, rods or economy.
Config.Reeling = {
    MotionSpeed = 0.60, -- All motion clocks run at 60% of the old speed.
    JerkScale = 0.50,   -- Half-sized jitter, pulses and sudden feints.
    LossScale = 0.60,   -- 40% less progress loss once the grace period ends.
    GraceSeconds = 0.30, -- Time to correct a continuous miss before losing progress.
    SpeedLimitBase = 0.28, -- Track-widths per second; limits impossible-to-follow jumps.
    SpeedLimitPerDifficulty = 0.35,
}
Config.WaterJump = {
    Enabled = true,
    UpwardSpeed = 70, -- Upward velocity target, in studs/second; no horizontal boost.
    Cooldown = 0.90,
    SwimReleaseSeconds = 0.35, -- Briefly leave Swimming so water does not cancel the leap.
    ExitGraceSeconds = 0.18, -- Covers the normal control script changing the state first.
}
Config.Rarities = {
    {Name = "Обычная", Color = {184, 184, 184}},
    {Name = "Необычная", Color = {118, 223, 174}},
    {Name = "Редкая", Color = {103, 185, 255}},
    {Name = "Эпическая", Color = {199, 144, 255}},
    {Name = "Легендарная", Color = {255, 207, 66}},
    {Name = "Мифическая", Color = {250, 106, 222}},
}
Config.Rods = {
    {Id = "wood", Name = "Деревянная", Price = 0, Width = 0.30, Luck = 1, Speed = 1, Resilience = 1, MaxKg = 8, Quality = 1},
    {Id = "carbon", Name = "Карбоновая", Price = 350, Width = 0.36, Luck = 1.7, Speed = 1.25, Resilience = 1.2, MaxKg = 25, Quality = 2},
    {Id = "tide", Name = "Повелитель приливов", Price = 1400, Width = 0.43, Luck = 2.6, Speed = 1.55, Resilience = 1.5, MaxKg = 80, Quality = 3},
    {Id = "astral", Name = "Астральная", Price = 7500, Width = 0.47, Luck = 2.6, Speed = 1.65, Resilience = 1.65, MaxKg = 110, Quality = 4},
}
Config.Fish = {
    {Id = "capybara", Name = "Капибара", Zone = "Cove", Rarity = 1, Chance = 46, MinKg = 0.25, MaxKg = 0.9, Price = 18, Difficulty = 0.05, XP = 24, Pattern = "lazy", HookWindow = 3.2, Nick = "СПОКОЙНАЯ ЛЕГЕНДА"},
    {Id = "skibidi", Name = "Скибиди-шпрот", Zone = "Cove", Rarity = 1, Chance = 28, MinKg = 0.35, MaxKg = 1.4, Price = 25, Difficulty = 0.08, XP = 28, Pattern = "wobble", HookWindow = 2.9, Nick = "СКОЛЬЗКИЙ И БОЛТЛИВЫЙ"},
    {Id = "sigma", Name = "Сигма-сардина", Zone = "Cove", Rarity = 2, Chance = 15, MinKg = 0.8, MaxKg = 3.3, Price = 34, Difficulty = 0.12, XP = 34, Pattern = "drift", HookWindow = 2.7, Nick = "ЛОВИТСЯ С ЛИЦОМ АЛЬФЫ"},
    {Id = "ballerina", Name = "Балерина Капуччина", Zone = "Cove", Rarity = 3, Chance = 6, MinKg = 1.7, MaxKg = 5.8, Price = 58, Difficulty = 0.3, XP = 49, Pattern = "ballet", HookWindow = 2.4, Nick = "КРУЖИТСЯ И ПЕТЛЯЕТ"},
    {Id = "tralalero", Name = "Тралалелетралала", Zone = "Cove", Rarity = 4, Chance = 2, MinKg = 1.8, MaxKg = 6.5, Price = 112, Difficulty = 0.28, XP = 70, Pattern = "zigzag", HookWindow = 2.15, Nick = "ЕГО МЕНЯТЬ НЕ НАДО — ОН И ТАК РЫБА", Night = true},
    {Id = "patapim", Name = "БР-БР Патапим", Zone = "Reef", Rarity = 2, Chance = 37, MinKg = 0.25, MaxKg = 1.2, Price = 40, Difficulty = 0.15, XP = 31, Pattern = "pulse", HookWindow = 2.85, Nick = "ПУЛЬСИРУЕТ И СКАЧЕТ"},
    {Id = "ambalabu", Name = "Бонека Амбалабу", Zone = "Reef", Rarity = 3, Chance = 24, MinKg = 1.4, MaxKg = 6.5, Price = 61, Difficulty = 0.20, XP = 46, Pattern = "phantom", HookWindow = 2.45, Nick = "ЛЮБИТ ЛОЖНЫЕ ДВИЖЕНИЯ"},
    {Id = "bombardiro", Name = "Бомбардиро Крокофиш", Zone = "Reef", Rarity = 3, Chance = 16, MinKg = 3.8, MaxKg = 16.5, Price = 86, Difficulty = 0.23, XP = 56, Pattern = "dart", HookWindow = 2.3, Nick = "РВЁТСЯ В РЫВКИ"},
    {Id = "sahur", Name = "Тун Тун Сахур", Zone = "Reef", Rarity = 5, Chance = 1.5, MinKg = 8, MaxKg = 22, Price = 210, Difficulty = 0.35, XP = 115, Pattern = "berserk", HookWindow = 1.9, Nick = "ЛЕГЕНДАРКА. ОЧЕНЬ КАПРИЗНЫЙ."},
    {Id = "gigachad", Name = "Гигачад-акула", Zone = "Reef", Rarity = 5, Chance = 0.8, MinKg = 24, MaxKg = 60, Price = 380, Difficulty = 0.32, XP = 145, Pattern = "boss", HookWindow = 1.75, Nick = "ФИНАЛЬНЫЙ УЛОВ РИФА"},
}
-- Verity uses its own small weight on Storm; no other existing species weights changed.
table.insert(Config.Fish, {Id="verity", Name="Верити", Zone="Storm", Rarity=6, Chance=0.12,
    MinKg=32, MaxKg=60, Price=420, Difficulty=0.52, XP=170, Pattern="verity", HookWindow=2.2,
    MinRodQuality=3, Night=true, Nick="MYTHICAL · ГЛУБИННЫЙ МИРАЖ"})
Config.ById = {}
for _, fish in ipairs(Config.Fish) do Config.ById[fish.Id] = fish end
function Config.Level(xp) return 1 + math.floor(xp / Config.XPPerLevel) end
function Config.Value(fish, kg, mutation)
    local multiplier = mutation == "gold" and 3 or (mutation == "glow" and 1.8 or 1)
    local rarityBonus = 1 + (fish.Rarity - 1) * 0.08
    return math.floor(fish.Price * rarityBonus * (0.8 + kg * 0.32) * multiplier + 0.5)
end
-- Islands use weights, not fixed percentages. Cove/Reef keep their old pools.
Config.Islands = {
    {Id="Cove", Name="Тихая бухта", X=0, Z=0, Radius=64, Level=1, Color={109,199,183},
        DockX=0, DockZ=70, Target="Старт, торговцы и лодочная верфь", Theme="home"},
    {Id="Reef", Name="Коралловый риф", X = 262.5, Z = -325, Radius=26, Level=2, Color={113,203,219},
        DockX = 262.5, DockZ = -284, Target="Старое место рыбалки и переправа", Theme="reef"},
    {Id="Moss", Name="Мшистый остров", X = -950, Z = 475, Radius=62, Level=2, Color={105,204,128},
        Target="БР-БР Патапим и Бонека Амбалабу", Theme="moss",
        Weights={capybara=10,sigma=3,patapim=55,ambalabu=42,ballerina=2}},
    {Id="Dunes", Name="Пески Сахура", X = -825, Z = -850, Radius=70, Level=3, Color={248,201,102},
        Target="Тун Тун Сахур: повышенный шанс", Theme="sand",
        Weights={capybara=14,skibidi=16,sigma=18,bombardiro=20,sahur=12}},
    {Id="Bloom", Name="Лагуна Капуччино", X = 825, Z = 475, Radius=64, Level=4, Color={238,173,193},
        Target="Балерина; ночью — Тралалелетралала", Theme="bloom",
        Weights={capybara=12,sigma=12,ambalabu=12,ballerina=32,tralalero=12}},
    {Id="Storm", Name="Штормовые скалы", X = 975, Z = -1050, Radius=66, Level=7, Color={160,172,240},
        Target="Гигачад-акула и Бомбардиро; ночью — Верити", Theme="storm",
        Weights={sigma=12,patapim=12,bombardiro=28,sahur=6,tralalero=10,gigachad=10,verity=0.12}},
}
Config.IslandById = {}
for _,island in ipairs(Config.Islands) do
    island.DockX=island.DockX or island.X
    island.DockZ=island.DockZ or (island.Z+island.Radius+22)
    Config.IslandById[island.Id]=island
end
Config.Boats = {
    {Id="skiff",Name="Рыбацкая шлюпка",Price=150,Level=1,Speed=24,Acceleration=18,Turn=1.45,
        Color={139,93,54},Accent={228,186,120},Description="Деревянная лодка с вёслами. Первый выход в море."},
    {Id="motor",Name="Моторка «Искра»",Price=1600,Level=3,Speed=42,Acceleration=22,Turn=1.65,
        Color={67,145,157},Accent={238,235,218},Description="Бирюзовый корпус, мотор и ветровое стекло."},
    {Id="cutter",Name="Катер «Буревестник»",Price=6500,Level=6,Speed=62,Acceleration=26,Turn=1.45,
        Color={53,68,92},Accent={248,185,85},Description="Тёмный скоростной катер с золотистой отделкой."},
    {Id="catamaran",Name="Катамаран «Аврора»",Price=20000,Level=10,Speed=82,Acceleration=30,Turn=1.25,
        Color={220,231,235},Accent={101,226,217},Description="Два корпуса, просторная палуба и светящиеся полосы."},
}
Config.BoatById={}
for _,boat in ipairs(Config.Boats) do Config.BoatById[boat.Id]=boat end
Config.Ocean={HalfExtent = 1700,SurfaceY=0,BoatHeight=0.60, MapSpan = 2800}
Config.CatchVisuals={HaloSize=338,HaloOpacity=0.70,PortraitSizes={capybara=260,patapim=260}}
Config.RodLooks={
    wood="Тёплое дерево, латунная катушка",
    carbon="Серый графит, тонкий гранёный бланк, острый кончик",
    tide="Морской синий, бирюзовые кристаллы и раздвоенная вершина",
    astral="Светлое серебро, фиолетовые кристаллы и звёздное навершие",
}
function Config.ZoneWeight(fish,zone)
    local island=Config.IslandById[zone]
    if not island then return 0 end
    if island.Weights then return island.Weights[fish.Id] or 0 end
    return fish.Zone==zone and fish.Chance or 0
end
function Config.Eligible(fish,zone,maxKg,night,quality)
    if not quality then
        quality=1
        for _,rod in ipairs(Config.Rods) do if maxKg>=rod.MaxKg then quality=rod.Quality end end
    end
    return Config.ZoneWeight(fish,zone)>0 and fish.MinKg<=maxKg and (not fish.Night or night)
        and quality>=(fish.MinRodQuality or 1)
end
function Config.RollWeight(fish,luck,zone)
    local weight=zone and Config.ZoneWeight(fish,zone) or fish.Chance
    return weight*(1+(luck-1)*(fish.Rarity-1)*0.55)
end
function Config.HabitatText(fish)
    local names={}
    for _,island in ipairs(Config.Islands) do
        if Config.ZoneWeight(fish,island.Id)>0 then names[#names+1]=island.Name end
    end
    return table.concat(names,", ")
end
-- World-model celebration. This is not a reeling timeout.
Config.Landing={DurationByRarity={2.15,2.25,2.50,2.75,3.05,3.45},EffectDistance=240,MaxVisible=8}
-- Only these two species have rod-specific fight profiles. No hidden "success roll".
-- Width is a fraction of the track; MotionSpeed scales the movement clock.
Config.SpeciesFights={
    ballerina={
        Default={MotionSpeed = 0.9,SpeedLimit = 0.46,GainScale = 0.9,LossScale = 0.8,GraceSeconds = 0.18,JerkScale = 0.6},
    },
    sahur={
        [1]={Width=0.100,MotionSpeed=0.86,SpeedLimit=0.45,GainScale=0.66,LossScale=1.10,GraceSeconds=0.06,JerkScale=0.65},
        [2]={Width=0.215,MotionSpeed=0.78,SpeedLimit=0.42,GainScale=0.76,LossScale=0.95,GraceSeconds=0.10,JerkScale=0.60},
        [3]={Width=0.270,MotionSpeed=0.69,SpeedLimit=0.40,GainScale=0.85,LossScale=0.85,GraceSeconds=0.14,JerkScale=0.55},
        [4]={Width=0.320,MotionSpeed=0.62,SpeedLimit=0.37,GainScale=0.90,LossScale=0.80,GraceSeconds=0.15,JerkScale=0.50},
    },
    verity={
        [3]={Width=0.205,MotionSpeed=0.91,SpeedLimit=0.58,GainScale=0.78,LossScale=1.00,GraceSeconds=0.08,JerkScale=0.60},
        [4]={Width=0.265,MotionSpeed=0.82,SpeedLimit=0.52,GainScale=0.87,LossScale=0.90,GraceSeconds=0.12,JerkScale=0.55},
    },
}
-- Additional creatures; Cappuccino Assassino has been retired.
local expansion=require(script.Parent:WaitForChild("BrainrotExpansion"))
for _,fish in ipairs(expansion.Fish) do
    assert(not Config.ById[fish.Id],"Duplicate species: "..fish.Id)
    table.insert(Config.Fish,fish)
    Config.ById[fish.Id]=fish
end
for zone,weights in pairs(expansion.IslandWeights) do
    local island=assert(Config.IslandById[zone],"Unknown expansion island: "..zone)
    assert(island.Weights,"Expansion overrides require a weighted island: "..zone)
    for id,weight in pairs(weights) do
        assert(Config.ById[id] and island.Weights[id]==nil,"Expansion weight collision: "..id)
        island.Weights[id]=weight
    end
end
return Config
