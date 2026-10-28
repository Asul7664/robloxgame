-- Static, repeatable art pass over our authored world only. Gameplay geometry is retained.
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("QuietCove")
local Theme = require(shared:WaitForChild("VisualTheme"))
local Config = require(shared:WaitForChild("Config"))
local Scenery = require(script.Parent:WaitForChild("WorldScenery"))
local NPCModels = require(script.Parent:WaitForChild("NPCModels"))
local P = Theme.Palette
local V = {}

local function paint(object, color, material)
    if not object:IsA("BasePart") then return end
    if color then object.Color = color end
    if material then object.Material = material end
end
local function labels(model)
    -- Only our own label-bearing parts/NPCs are passed in, never arbitrary descendants.
    local gui = model:FindFirstChild("Label")
    local text = gui and gui:FindFirstChildOfClass("TextLabel")
    if text then text.TextColor3=P.Cream; text.TextStrokeColor3=P.Ink; text.TextStrokeTransparency=0.12 end
end
local function person(model, shirt)
    if model:FindFirstChildOfClass("Humanoid") then return end
    for _,child in ipairs(model:GetChildren()) do if child:IsA("MeshPart") then return end end
    for _, object in ipairs(model:GetChildren()) do
        if object.Name=="Body" or object.Name=="Arm" or object.Name=="HatBand" then paint(object,shirt)
        elseif object.Name=="Hat" then paint(object,P.Cream)
        elseif object.Name=="Leg" then paint(object,P.Ink) end
        labels(object)
    end
end
local wood = {PierPlank=true, FishingPlatform=true, FerryGangway=true, ReefPier=true,
    FishingPier=true, FishingDeck=true, Boardwalk=true, Jetty=true, WaterStep=true, BoatDeck=true}
local posts = {PierSupport=true, AwningPole=true, FishingSign=true, ReefSign=true,
    FishingMarker=true, DockSign=true, Pile=true, ShopPole=true, Branch=true}
local function common(object, biome)
    if not object:IsA("BasePart") then return end
    local name=object.Name
    if wood[name] then
        local variation=(math.sin(object.Position.X*1.7+object.Position.Z*0.9)+1)*0.035
        paint(object,P.Wood:Lerp(P.WoodLight,variation),Enum.Material.WoodPlanks)
    elseif posts[name] then paint(object,P.WoodDark,Enum.Material.Wood)
    elseif name=="PalmTrunk" or name=="TreeTrunk" then paint(object,P.Wood,Enum.Material.Wood)
    elseif name=="PalmLeaf" or name=="LeafCanopy" then paint(object,biome.Leaves,Enum.Material.SmoothPlastic)
    elseif name=="IslandBeacon" then paint(object,biome.Accent,Enum.Material.Neon)
    elseif name=="Bollard" then paint(object,P.Ink,Enum.Material.SmoothPlastic) end
    labels(object)
end

function V.ApplyEnvironment()
    for key,value in pairs(Theme.Lighting) do Lighting[key]=value end
    -- Compatibility for an older Studio: the rest of the art pass still applies.
    pcall(function()
        Lighting.LightingStyle=Enum.LightingStyle[Theme.LightingStyle]
        Lighting.PrioritizeLightingQuality=Theme.PrioritizeLightingQuality
    end)
    for name,settings in pairs(Theme.Effects) do
        local effect=Lighting:FindFirstChild(name)
        if effect and effect.ClassName~=settings.Class then effect:Destroy(); effect=nil end
        if not effect then effect=Instance.new(settings.Class); effect.Name=name; effect.Parent=Lighting end
        if effect:IsA("ColorGradingEffect") and effect:GetAttribute("QCOriginalTonemapper")==nil then
            effect:SetAttribute("QCOriginalTonemapper",effect.TonemapperPreset.Name)
            effect:SetAttribute("QCOriginalEnabled",effect.Enabled)
        end
        for key,value in pairs(settings.Properties) do
            if key=="TonemapperPreset" then value=Enum.TonemapperPreset[value] end
            effect[key]=value
        end
    end
    -- Only one Atmosphere should control the sky. Preserve the old one for editing.
    for _,object in ipairs(Lighting:GetChildren()) do
        if object:IsA("Atmosphere") and object.Name~="QCAtmosphere" then
            local backup=Lighting:FindFirstChild("QCPreviousAtmosphere")
            if not backup then backup=Instance.new("Folder"); backup.Name="QCPreviousAtmosphere"; backup.Parent=Lighting end
            object.Parent=backup
        elseif object:IsA("ColorGradingEffect") and object.Name~="ColorGrading" then
            local backup=Lighting:FindFirstChild("QCPreviousColorGrading")
            if not backup then backup=Instance.new("Folder");backup.Name="QCPreviousColorGrading";backup.Parent=Lighting end
            if object:GetAttribute("QCOriginalEnabled")==nil then object:SetAttribute("QCOriginalEnabled",object.Enabled) end
            object.Enabled=false;object.Parent=backup
        end
    end
    for key,value in pairs(Theme.Water) do Workspace.Terrain[key]=value end
end

function V.ApplyMap(map)
    for _,object in ipairs(map:GetChildren()) do
        common(object,Theme.Biomes.home)
        local name=object.Name
        if name=="IslandRock" then paint(object,P.Rock,Enum.Material.Rock)
        elseif name=="IslandSand" or name=="ReefSand" or name=="BeachStep" then paint(object,P.Sand,Enum.Material.Sand)
        elseif name=="IslandGrass" then paint(object,P.Grass,Enum.Material.Grass)
        elseif name=="Path" then paint(object,P.Path,Enum.Material.Ground)
        elseif name=="ReefRock" then paint(object,Theme.Biomes.reef.Rock,Enum.Material.Rock)
        elseif name=="Coral" then paint(object,object.Position.X%5<2.5 and P.Coral or P.Purple,Enum.Material.SmoothPlastic)
        elseif name=="ShopCounter" then paint(object,P.WoodLight,Enum.Material.SmoothPlastic)
        elseif name=="Awning" then paint(object,object.Position.X<0 and P.Gold or P.Shallows,Enum.Material.SmoothPlastic)
        elseif name=="Lighthouse" then
            local band=math.floor((object.Position.Y-9)/5+0.5)
            paint(object,band%2==0 and P.Cream or P.Coral,Enum.Material.SmoothPlastic)
        elseif name=="LighthouseRoof" or name=="Ferry" or name=="ReturnFerry" then paint(object,P.Ink)
        elseif name=="Beacon" then
            paint(object,P.Gold)
            local light=object:FindFirstChildOfClass("PointLight")
            if light then light.Color=P.Gold end
        elseif name=="BoatHull" then paint(object,P.Shallows,Enum.Material.SmoothPlastic)
        elseif name=="Merchant" then person(object,P.Gold);NPCModels.Upgrade(object,"Merchant",Theme)
        elseif name=="Rodsmith" then person(object,P.Shallows);NPCModels.Upgrade(object,"Rodsmith",Theme) end
    end
    Scenery.Apply(map,nil,Config,Theme)
end

function V.ApplyArchipelago(folder)
    for _,object in ipairs(folder:GetChildren()) do
        if object.Name=="HarborPath" then paint(object,P.Path,Enum.Material.Ground)
        elseif object.Name=="HomeHarborSign" then paint(object,P.WoodDark,Enum.Material.SmoothPlastic); labels(object) end
    end
    for _,d in ipairs(Config.Islands) do
        local biome=Theme.Biomes[d.Theme]
        local island=folder:FindFirstChild(d.Id)
        if island then
            for _,object in ipairs(island:GetChildren()) do
                common(object,biome)
                local name=object.Name
                if name=="IslandStone" then paint(object,biome.Rock,Enum.Material.Rock)
                elseif name=="Shore" then paint(object,P.Sand,Enum.Material.Sand)
                elseif name=="Plateau" then paint(object,biome.Ground,d.Theme=="sand" and Enum.Material.Sand or (d.Theme=="storm" and Enum.Material.Slate or Enum.Material.Grass))
                elseif name=="IslandPath" then paint(object,d.Theme=="storm" and Color3.fromRGB(132,145,163) or P.Path,Enum.Material.Ground)
                elseif name=="TempleTier" or name=="Obelisk" then paint(object,P.Sand:Lerp(biome.Rock,0.28),Enum.Material.Sandstone)
                elseif name=="SunCap" then paint(object,P.Gold)
                elseif name=="Oasis" then paint(object,P.Shallows)
                elseif name=="MushroomCap" then paint(object,biome.Accent,Enum.Material.SmoothPlastic)
                elseif name=="MushroomStem" then paint(object,P.Cream,Enum.Material.SmoothPlastic)
                elseif name=="GroveArch" or name=="GroveArchTop" then paint(object,biome.Rock,Enum.Material.SmoothPlastic)
                elseif name=="BasaltSpire" then paint(object,biome.Rock,Enum.Material.SmoothPlastic)
                elseif name=="StormCrystal" then paint(object,P.Purple)
                elseif name=="CupPlinth" then paint(object,biome.Rock,Enum.Material.SmoothPlastic)
                elseif name=="CappuccinoCup" or name:match("^CupHandle") or name=="LatteFoam" then paint(object,P.Cream,Enum.Material.SmoothPlastic) end
            end
        end
        local dock=folder:FindFirstChild("Dock_"..d.Id)
        if dock then
            for _,object in ipairs(dock:GetChildren()) do
                common(object,biome)
                if object.Name=="Canopy" then paint(object,biome.Accent,Enum.Material.SmoothPlastic)
                elseif object.Name=="Captain" then person(object,P.Shallows);NPCModels.Upgrade(object,"Captain",Theme)
                elseif object.Name=="Buyer" then person(object,P.Gold);NPCModels.Upgrade(object,"Buyer",Theme) end
            end
        end
    end
    Scenery.Apply(nil,folder,Config,Theme)
end

-- Command Bar (outside Play): require(game.ServerScriptService.QuietCove.WorldVisuals).ApplyAll()
function V.ApplyAll()
    V.ApplyEnvironment()
    local map=Workspace:FindFirstChild("QuietCoveMap")
    local islands=Workspace:FindFirstChild("QuietCoveArchipelago")
    if map then V.ApplyMap(map) end
    if islands then V.ApplyArchipelago(islands) end
end
return V
