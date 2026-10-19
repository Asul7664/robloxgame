-- Run with lune run tests/visual_theme.luau. Real art modules, deterministic engine doubles.
-- These checks protect gameplay geometry/queries and repeatable saved-place migration.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local roblox=require("@lune/roblox")
local V,CF,C=roblox.Vector3,roblox.CFrame,roblox.Color3
local checks=0
local function check(value,message)checks+=1;assert(value,message)end
local function near(a,b,message)check((a-b).Magnitude<0.002,message)end
local baseParts={Part=true,WedgePart=true,MeshPart=true,SpawnLocation=true}
local methods={}
local function new(class)
    local p={ClassName=class,Name=class,Children={},Attributes={},CFrame=CF.new(),Size=V.new(1,1,1),
        Color=C.fromRGB(101,82,61),Material=roblox.Enum.Material.Wood,Transparency=0,
        CanCollide=true,CanQuery=true,CanTouch=true}
    return setmetatable({}, {
        __index=function(_,key)
            if key=="Position"then return p.CFrame.Position end
            if methods[key]then return methods[key]end
            if p[key]~=nil then return p[key]end
            for _,child in ipairs(p.Children)do if child.Name==key then return child end end
        end,
        __newindex=function(self,key,value)
            if key=="Parent"then
                if p.Parent then
                    local index=table.find(p.Parent.Children,self)
                    if index then table.remove(p.Parent.Children,index)end
                end
                p.Parent=value
                if value then table.insert(value.Children,self)end
            elseif key=="Position"then p.CFrame=CF.new(value)*(p.CFrame-p.CFrame.Position)
            else p[key]=value end
        end,
    })
end
function methods:IsA(class)return self.ClassName==class or(class=="BasePart"and baseParts[self.ClassName]==true)end
function methods:GetChildren()return table.clone(self.Children)end
function methods:GetDescendants()
    local out={}
    for _,child in ipairs(self.Children)do
        table.insert(out,child)
        for _,nested in ipairs(child:GetDescendants())do table.insert(out,nested)end
    end
    return out
end
function methods:FindFirstChild(name)
    for _,child in ipairs(self.Children)do if child.Name==name then return child end end
end
function methods:FindFirstChildOfClass(class)
    for _,child in ipairs(self.Children)do if child:IsA(class)then return child end end
end
function methods:WaitForChild(name)return assert(self:FindFirstChild(name),name)end
function methods:GetAttribute(key)return self.Attributes[key]end
function methods:SetAttribute(key,value)self.Attributes[key]=value end
function methods:Destroy()
    for _,child in ipairs(self:GetChildren())do child:Destroy()end
    self.Parent=nil
end
local function child(parent,class,name,position,size)
    local object=new(class);object.Name=name;object.Parent=parent
    if position then object.Position=position end
    if size then object.Size=size end
    return object
end
local workspace,lighting=new("Workspace"),new("Lighting")
child(workspace,"Terrain","Terrain")
local loaded={}
local environment={
    game={GetService=function(_,name)return({Workspace=workspace,Lighting=lighting,ReplicatedStorage={
        WaitForChild=function()return{WaitForChild=function(_,module)return module end}end,
    }})[name]end},
    script={Parent={WaitForChild=function(_,name)return name end}},
    require=function(name)return assert(loaded[name],"Unloaded module "..tostring(name))end,
    Instance={new=new},Vector3=V,CFrame=CF,Color3=C,Enum=roblox.Enum,
}
local function load(name,path)
    local source=fs.readFile(path);luau.compile(source)
    loaded[name]=luau.load(source,{environment=environment})()
    return loaded[name]
end
load("BrainrotExpansion","src/shared/BrainrotExpansion.luau")
local config=load("Config","src/shared/Config.luau")
local theme=load("VisualTheme","src/shared/VisualTheme.luau")
load("WorldScenery","src/server/WorldScenery.luau")
local visuals=load("WorldVisuals","src/server/WorldVisuals.luau")

local map=child(workspace,"Model","QuietCoveMap")
child(map,"Part","IslandSand",V.new(0,5,0),V.new(119,2,89))
child(map,"Part","IslandGrass",V.new(0,6.5,5),V.new(99,1,68))
child(map,"Part","IslandRock",V.new(0,-3,0),V.new(124,16,94))
local pier=child(map,"Part","PierPlank",V.new(0,7,-36),V.new(14,1,3.6))
child(map,"Part","PalmTrunk",V.new(41,17,4),V.new(1.8,20,1.8))
local leaf=child(map,"Part","PalmLeaf",V.new(41,27,4),V.new(3.3,.65,11))
leaf.Transparency=.25;leaf.CanCollide=false
local reef=config.IslandById.Reef
child(map,"Part","ReefSand",V.new(reef.X,5.6,reef.Z),V.new(45,1.5,36))
child(map,"Part","ReefRock",V.new(reef.X,-1,reef.Z),V.new(47,12,38))
child(map,"Part","PalmTrunk",V.new(reef.X+15,15,reef.Z+10),V.new(1.8,17,1.8))
local merchant=child(map,"Model","Merchant")
local merchantBody=child(merchant,"Part","Body")
child(merchant,"Part","Arm")
local sign=child(map,"Part","FishingSign")
local signText=child(child(sign,"BillboardGui","Label"),"TextLabel","TextLabel")
signText.Text="РЫБАЛКА";signText.TextColor3=C.new(1,1,1)
local prompt=child(pier,"ProximityPrompt","Travel");prompt.ActionText="На риф"

local archipelago=child(workspace,"Model","QuietCoveArchipelago")
for _,definition in ipairs(config.Islands)do
    if definition.Theme~="home"and definition.Theme~="reef"then
        local island=child(archipelago,"Model",definition.Id)
        child(island,"Part","Plateau",V.new(definition.X,6.5,definition.Z),V.new(1.5,definition.Radius*1.78,definition.Radius*1.78))
        child(island,"Part","Shore",V.new(definition.X,5,definition.Z),V.new(2.6,definition.Radius*2,definition.Radius*2))
        child(island,"Part","IslandPath",V.new(definition.X,7.3,definition.Z),V.new(10,.2,definition.Radius*2+10))
        child(island,"Part","IslandStone",V.new(definition.X,-2,definition.Z))
        child(island,"Part","IslandBeacon",V.new(definition.X,9,definition.Z+18))
        if definition.Theme=="sand"then
            child(island,"Part","TreeTrunk",V.new(definition.X+35,13.5,definition.Z+10),V.new(2.8,15,2.8))
            child(island,"Part","PalmLeaf",V.new(definition.X+35,21,definition.Z+10))
        end
    end
    local dock=child(archipelago,"Model","Dock_"..definition.Id)
    child(dock,"Part","Boardwalk",V.new(definition.DockX,7,definition.DockZ-9))
    child(dock,"Part","Canopy")
end

-- Identical names outside our direct authored geometry must not attract the art pass.
local untouched={}
for _,parent in ipairs({workspace,map,archipelago.Dunes})do
    local custom=child(parent,"Model","PlayerDecoration")
    table.insert(untouched,child(custom,"Part","PierPlank"))
    table.insert(untouched,child(custom,"Part","PalmLeaf"))
end
local character=child(workspace,"Model","PlayerCharacter")
child(character,"Humanoid","Humanoid")
table.insert(untouched,child(character,"Part","Body"))
table.insert(untouched,child(child(character,"Tool","Musket"),"Part","Handle"))
local encounters=child(workspace,"Folder","SahurEncounters")
table.insert(untouched,child(child(encounters,"Model","Sahur"),"MeshPart","Body"))
local customCorrection=child(lighting,"ColorCorrectionEffect","UserCorrection")
customCorrection.Saturation=.03
local oldAtmosphere=child(lighting,"Atmosphere","SavedAtmosphere")
oldAtmosphere.Density=.5
local wrongBloom=child(lighting,"Folder","QCBloom")
local sky=child(lighting,"Sky","UserSky")

local originals={}
for _,object in ipairs(workspace:GetDescendants())do
    if object:IsA("BasePart")then
        object.CFrame=object.CFrame*CF.Angles(.05,.17,.02)
        originals[object]={CFrame=object.CFrame,Size=object.Size,CanCollide=object.CanCollide,
            CanTouch=object.CanTouch,CanQuery=object.CanQuery,Color=object.Color,Material=object.Material,Transparency=object.Transparency}
    end
end
visuals.ApplyAll()
check(map.IslandGrass.Color==theme.Palette.Grass,"Home ground does not use the accepted palette")
check(map.ReefRock.Color==theme.Biomes.reef.Rock,"Reef lost its biome color")
check(pier.Color==theme.Palette.Wood,"Pier does not use clean warm wood")
check(merchantBody.Color==theme.Palette.Gold,"Existing merchant was not restyled")
check(signText.Text=="РЫБАЛКА"and prompt.ActionText=="На риф","Art pass changed gameplay text")
check(signText.TextStrokeColor3==theme.Palette.Ink,"World labels lack readable outline")
for _,definition in ipairs(config.Islands)do
    if definition.Theme~="home"and definition.Theme~="reef"then
        local island=archipelago[definition.Id]
        check(island.Plateau.Color==theme.Biomes[definition.Theme].Ground,"Biome ground color mismatch")
        check(island.IslandBeacon.Color==theme.Biomes[definition.Theme].Accent,"Biome marker lost its accent")
        check(island:FindFirstChild("QCScenery")~=nil,"Saved island did not receive details")
    end
    check(archipelago["Dock_"..definition.Id].Canopy.Color==theme.Biomes[definition.Theme].Accent,"Dock color no longer matches its island")
end
for object,saved in pairs(originals)do
    check(object.Parent~=nil,"Art pass removed an original part")
    near(object.Position,saved.CFrame.Position,"Art pass moved an original part")
    near(object.CFrame.LookVector,saved.CFrame.LookVector,"Art pass rotated an original part")
    near(object.Size,saved.Size,"Art pass resized an original part")
    for _,key in ipairs({"CanCollide","CanTouch","CanQuery"})do
        if object.Name=="PalmLeaf"and key~="CanCollide"and object:GetAttribute("QCOriginal"..key)~=nil then
            check(object:GetAttribute("QCOriginal"..key)==saved[key],"Retired frond lost its original query/touch flag")
            check(object[key]==false,"Invisible retired frond intercepts queries or touch events")
        else
            check(object[key]==saved[key],"Art pass changed an original physics flag")
        end
    end
end
for _,object in ipairs(untouched)do
    local saved=originals[object]
    check(object.Color==saved.Color and object.Material==saved.Material,"Art pass recolored user geometry or an actor")
    check(object.Transparency==saved.Transparency,"Art pass hid user geometry or an actor")
end
check(leaf.Transparency==1 and leaf:GetAttribute("QCOriginalTransparency")==.25,"Old frond visual was not replaced reversibly")
local added=0
for _,object in ipairs(workspace:GetDescendants())do
    if object:IsA("BasePart")and not originals[object]then
        added+=1
        check(object.Anchored==true and not object.CanCollide and not object.CanTouch and not object.CanQuery,
            "New decoration blocks movement, weapon shots or AI queries")
        local current=object.Parent
        while current and current.Name~="QCScenery"do current=current.Parent end
        check(current~=nil,"New decoration escaped its owned folder")
        if object.Parent==archipelago.Dunes.QCScenery then
            check(math.abs(object.Position.X-config.IslandById.Dunes.X)>12,"Dunes details obstruct the Sahur landing/combat lane")
        end
    end
end
check(added>100 and added<420,"Static visual detail budget is unexpectedly empty or excessive")
for key,value in pairs(theme.Lighting)do check(lighting[key]==value,"Lighting preset differs: "..key)end
check(lighting.LightingStyle==roblox.Enum.LightingStyle.Soft,"Stylized soft lighting was not selected")
check(lighting.PrioritizeLightingQuality==true,"Lighting quality preference is missing")
for key,value in pairs(theme.Water)do check(workspace.Terrain[key]==value,"Water preset differs: "..key)end
check(oldAtmosphere.Parent==lighting.QCPreviousAtmosphere and oldAtmosphere.Density==.5,"Previous atmosphere was lost instead of retained")
check(customCorrection.Parent==lighting and customCorrection.Saturation==.03,"User postprocessing was changed")
check(sky.Parent==lighting,"User sky was replaced")
check(wrongBloom.Parent==nil and lighting.QCBloom.ClassName=="BloomEffect","Wrong class did not migrate to the owned effect")
local effects={}
for name,settings in pairs(theme.Effects)do
    local effect=lighting:FindFirstChild(name)
    effects[name]=effect
    check(effect and effect.ClassName==settings.Class,"Missing owned environment effect")
    for key,value in pairs(settings.Properties)do check(effect[key]==value,"Environment effect differs: "..name.."."..key)end
end
local count=#workspace:GetDescendants()
local lightingCount=#lighting:GetDescendants()
visuals.ApplyAll()
check(#workspace:GetDescendants()==count,"Second art pass duplicates decorations")
check(#lighting:GetDescendants()==lightingCount,"Second art pass duplicates environment effects")
check(leaf:GetAttribute("QCOriginalTransparency")==.25,"Repeated art pass overwrites original frond transparency")
check(leaf:GetAttribute("QCOriginalCanQuery")==true and leaf:GetAttribute("QCOriginalCanTouch")==true,
    "Repeated art pass overwrites the original retired-frond flags")
for name,object in pairs(effects)do check(lighting[name]==object,"Second art pass replaced an existing owned effect")end
local atmosphereCount=0
for _,object in ipairs(lighting:GetChildren())do if object:IsA("Atmosphere")then atmosphereCount+=1 end end
check(atmosphereCount==1,"Multiple active atmospheres compete for the sky")

-- The checked-in Rojo preset must be regenerated when the editable palette changes.
-- Exercise the actual Roblox serialization, not the runtime doubles above.
local preset=roblox.deserializeModel(fs.readFile("assets/environment/Lighting.rbxmx"))
check(#preset==1 and preset[1].ClassName=="Lighting","Rojo preset must contain exactly one Lighting service")
local serializedLighting=preset[1]
local function matching(actual,expected,message)
    if typeof(expected)=="number"then check(math.abs(actual-expected)<0.00001,message)
    elseif typeof(expected)=="Color3"then
        check(math.abs(actual.R-expected.R)<0.00001 and math.abs(actual.G-expected.G)<0.00001
            and math.abs(actual.B-expected.B)<0.00001,message)
    else check(actual==expected,message)end
end
for key,value in pairs(theme.Lighting)do matching(serializedLighting[key],value,"Stale serialized Lighting property: "..key)end
matching(serializedLighting.LightingStyle,roblox.Enum.LightingStyle[theme.LightingStyle],"Stale serialized LightingStyle")
matching(serializedLighting.PrioritizeLightingQuality,theme.PrioritizeLightingQuality,"Stale serialized lighting quality preference")
local serializedEffectCount=0
for name,settings in pairs(theme.Effects)do
    serializedEffectCount+=1
    local effect=serializedLighting:FindFirstChild(name)
    check(effect and effect.ClassName==settings.Class,"Missing serialized environment effect: "..name)
    for key,value in pairs(settings.Properties)do matching(effect[key],value,"Stale serialized effect property: "..name.."."..key)end
end
check(#serializedLighting:GetChildren()==serializedEffectCount,"Serialized lighting has duplicate or stale effects")
print(string.format("PASS %d visual theme checks; %d static non-query decorations",checks,added))
