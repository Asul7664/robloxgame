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
    if class=="ColorGradingEffect"then p.Enabled=true;p.TonemapperPreset=roblox.Enum.TonemapperPreset.Default end
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
    Instance={new=new},Vector3=V,CFrame=CF,Color3=C,UDim2=roblox.UDim2,Enum=roblox.Enum,
}
local function load(name,path)
    local source=fs.readFile(path);luau.compile(source)
    loaded[name]=luau.load(source,{environment=environment})()
    return loaded[name]
end
load("BrainrotExpansion","src/shared/BrainrotExpansion.luau")
local config=load("Config","src/shared/Config.luau")
local theme=load("VisualTheme","src/shared/VisualTheme.luau")
-- Softer scene colors must retain readable interface labels and choice buttons.
local function luminance(color)
    local function linear(v)return v<=.04045 and v/12.92 or ((v+.055)/1.055)^2.4 end
    return linear(color.R)*.2126+linear(color.G)*.7152+linear(color.B)*.0722
end
local function contrast(a,b)
    local first,second=luminance(a),luminance(b)
    return (math.max(first,second)+.05)/(math.min(first,second)+.05)
end
check(contrast(theme.UI.Ink,theme.UI.Panel)>=4.5,"Soft dialogue panels lose readable body text")
check(contrast(theme.UI.Muted,theme.UI.Panel)>=4.5,"Muted quest hints lose readable contrast")
check(contrast(theme.UI.Bg,theme.UI.Aqua)>=4.5,"Aqua dialogue choices lose readable text")
check(contrast(theme.UI.Bg,theme.UI.Gold)>=4.5,"Gold reward choices lose readable text")
load("SceneryVegetation","src/server/SceneryVegetation.luau")
load("SceneryLandmarks","src/server/SceneryLandmarks.luau")
load("WorldScenery","src/server/WorldScenery.luau")
load("NPCModels","src/server/NPCModels.luau")
local visuals=load("WorldVisuals","src/server/WorldVisuals.luau")

local map=child(workspace,"Model","QuietCoveMap")
child(map,"Part","IslandSand",V.new(0,5,0),V.new(119,2,89))
child(map,"Part","IslandGrass",V.new(0,6.5,5),V.new(99,1,68))
local path=child(map,"Part","Path",V.new(0,7.1,-5),V.new(12,.2,56))
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
local handmade=child(map,"Model","Rodsmith")
child(handmade,"Humanoid","Humanoid")
local handmadeBody=child(handmade,"Part","Body",V.new(20,9.2,-25))
local handmadeHead=child(handmade,"Part","Head",V.new(20,11.4,-25))
local sign=child(map,"Part","FishingSign")
local signText=child(child(sign,"BillboardGui","Label"),"TextLabel","TextLabel")
signText.Text="РЫБАЛКА";signText.TextColor3=C.new(1,1,1)
local prompt=child(pier,"ProximityPrompt","Travel");prompt.ActionText="На риф"

local archipelago=child(workspace,"Model","QuietCoveArchipelago")
local harborPath=child(archipelago,"Part","HarborPath",V.new(0,7.25,38),V.new(11,.15,56))
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
        elseif definition.Theme=="moss"or definition.Theme=="bloom"then
            child(island,"Part","TreeTrunk",V.new(definition.X+35,16,definition.Z+10),V.new(2.8,20,2.8))
            child(island,"Part","LeafCanopy",V.new(definition.X+35,28,definition.Z+10),V.new(18,11,15)).CanCollide=false
            child(island,"Part","Branch",V.new(definition.X+39,20,definition.Z+10),V.new(2.2,10,2.2)).CanCollide=false
        end
    end
    local dock=child(archipelago,"Model","Dock_"..definition.Id)
    child(dock,"Part","Boardwalk",V.new(definition.DockX,7,definition.DockZ-9))
    child(dock,"Part","Canopy")
    local captain=child(dock,"Model","Captain")
    child(captain,"Part","Body",V.new(definition.DockX-7,9.3,definition.DockZ+2))
    child(captain,"Part","Head",V.new(definition.DockX-7,11.5,definition.DockZ+2))
end

-- A saved place can contain the previous owned generation and unrelated user art.
-- Only the former should be replaced when this generation changes.
local previousOwned={}
local oldMapScenery=child(map,"Folder","QCScenery")
for _,name in ipairs({"Cove","Reef"})do
    local old=child(oldMapScenery,"Folder",name)
    old:SetAttribute("SceneryVersion","tropical-scenery-1:1")
    table.insert(previousOwned,child(old,"Part","SavedOldFrond"))
end
local userScenery=child(oldMapScenery,"Folder","MyHandmadeDetails")
local userRock=child(userScenery,"Part","MyRock",V.new(-25,8,8))
for _,definition in ipairs(config.Islands)do
    if definition.Theme~="home"and definition.Theme~="reef"then
        local old=child(archipelago[definition.Id],"Folder","QCScenery")
        old:SetAttribute("SceneryVersion","tropical-scenery-1:1")
        table.insert(previousOwned,child(old,"Part","SavedOldPebble"))
    end
end

-- Identical names outside our direct authored geometry must not attract the art pass.
local untouched={}
table.insert(untouched,handmadeBody)
table.insert(untouched,handmadeHead)
table.insert(untouched,userRock)
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
-- The uploaded place contains an enabled legacy Retro tonemapper. It must not
-- silently keep clipping scene colors after the newer lighting preset is applied.
local legacyGrading=child(lighting,"ColorGradingEffect","ColorGrading")
legacyGrading.Enabled=true;legacyGrading.TonemapperPreset=roblox.Enum.TonemapperPreset.Retro
local extraGrading=child(lighting,"ColorGradingEffect","UserExtraGrading")
extraGrading.Enabled=true;extraGrading.TonemapperPreset=roblox.Enum.TonemapperPreset.Retro
local wrongBloom=child(lighting,"Folder","QCBloom")
local sky=child(lighting,"Sky","UserSky")

local originals={}
local function legacyNPC(object)
    local model=object.Parent
    if not model or not model:FindFirstChild("Body")or model:FindFirstChildOfClass("Humanoid")then return false end
    local scoped=(model.Parent==map and (model.Name=="Merchant"or model.Name=="Rodsmith"))
        or (model.Parent and model.Parent.Parent==archipelago and model.Parent.Name:match("^Dock_")
            and (model.Name=="Captain"or model.Name=="Buyer"))
    return scoped and ({Body=true,Head=true,Hat=true,HatBand=true,Arm=true,Leg=true,Eye=true})[object.Name]==true
end
local function npcRig(object)
    local current=object.Parent
    while current and current~=workspace do
        if current.Name=="VisualRig"and current:GetAttribute("QCNPC")==true then return current end
        current=current.Parent
    end
end
for _,object in ipairs(workspace:GetDescendants())do
    if object:IsA("BasePart")and not table.find(previousOwned,object)then
        object.CFrame=object.CFrame*CF.Angles(.05,.17,.02)
        originals[object]={CFrame=object.CFrame,Size=object.Size,CanCollide=object.CanCollide,
            CanTouch=object.CanTouch,CanQuery=object.CanQuery,Color=object.Color,Material=object.Material,Transparency=object.Transparency}
    end
end
visuals.ApplyAll()
for _,object in ipairs(previousOwned)do check(object.Parent==nil,"Saved v1-owned decoration was retained")end
check(userScenery.Parent==oldMapScenery and userRock.Parent==userScenery,"Migration removed unrelated saved scenery")
check(map.IslandGrass.Color==theme.Palette.Grass,"Home ground does not use the accepted palette")
check(map.IslandGrass.Material==roblox.Enum.Material.Grass,"Home grass is still a flat plastic sheet")
check(path.Material==roblox.Enum.Material.Ground and path.Color==theme.Palette.Path,
    "Main path retains the bright rippled sand material instead of muted ground")
check(harborPath.Material==roblox.Enum.Material.Ground and harborPath.Color==theme.Palette.Path,
    "Harbor path no longer shares the muted ground material")
check(map.ReefRock.Color==theme.Biomes.reef.Rock,"Reef lost its biome color")
local function colorDistance(a,b)
    return math.sqrt((a.R-b.R)^2+(a.G-b.G)^2+(a.B-b.B)^2)
end
check(pier.Material==roblox.Enum.Material.WoodPlanks,"Pier lacks the readable wood-plank material")
check(colorDistance(pier.Color,theme.Palette.Wood)
    <=colorDistance(theme.Palette.Wood:Lerp(theme.Palette.WoodLight,.075),theme.Palette.Wood),
    "Pier variation leaves the accepted warm wood palette")
check(merchantBody.Color==theme.Palette.Gold,"Existing merchant was not restyled")
check(signText.Text=="РЫБАЛКА"and prompt.ActionText=="На риф","Art pass changed gameplay text")
check(signText.TextStrokeColor3==theme.Palette.Ink,"World labels lack readable outline")
for _,definition in ipairs(config.Islands)do
    if definition.Theme~="home"and definition.Theme~="reef"then
        local island=archipelago[definition.Id]
        check(island.Plateau.Color==theme.Biomes[definition.Theme].Ground,"Biome ground color mismatch")
        if definition.Theme~="sand"and definition.Theme~="storm"then
            check(island.Plateau.Material==roblox.Enum.Material.Grass,"Green island retains plastic terrain")
        end
        check(island.IslandPath.Material==roblox.Enum.Material.Ground
            and island.IslandPath.Color~=theme.Palette.Sand,"Island route retains yellow sand instead of ground")
        if definition.Theme~="storm"then check(island.IslandPath.Color==theme.Palette.Path,"Island route leaves the muted path palette")end
        check(island.IslandBeacon.Color==theme.Biomes[definition.Theme].Accent,"Biome marker lost its accent")
        check(island:FindFirstChild("QCScenery")~=nil,"Saved island did not receive details")
    end
    check(archipelago["Dock_"..definition.Id].Canopy.Color==theme.Biomes[definition.Theme].Accent,"Dock color no longer matches its island")
end
for object,saved in pairs(originals)do
    check(object.Parent~=nil,"Art pass removed an original part")
    near(object.Position,saved.CFrame.Position,"Art pass moved an original part")
    near(object.CFrame.LookVector,saved.CFrame.LookVector,"Art pass rotated an original part")
    near(object.CFrame.UpVector,saved.CFrame.UpVector,"Art pass rolled or tilted an original part")
    near(object.Size,saved.Size,"Art pass resized an original part")
    for _,key in ipairs({"CanCollide","CanTouch","CanQuery"})do
        local retired=object.Name=="PalmLeaf"or object.Name=="LeafCanopy"or object.Name=="Branch"
        if legacyNPC(object) then
            check(object:GetAttribute("QCOriginal"..key)==saved[key],"NPC upgrade lost its prior physics flags")
            check(object[key]==false,"NPC character anchor blocks movement or rays")
        elseif retired and key~="CanCollide"and object:GetAttribute("QCOriginal"..key)~=nil then
            check(object:GetAttribute("QCOriginal"..key)==saved[key],"Retired frond lost its original query/touch flag")
            check(object[key]==false,"Invisible retired frond intercepts queries or touch events")
        else
            check(object[key]==saved[key],"Art pass changed an original physics flag: "..object.Name.."."..key)
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
local vegetationParts=0
local cargoProps=0
for _,object in ipairs(workspace:GetDescendants())do
    if object:IsA("BasePart")and not originals[object]then
        local rig=npcRig(object)
        if not rig then added+=1 end
        check((rig~=nil or object.Anchored==true)and not object.CanCollide and not object.CanTouch and not object.CanQuery,
            "New decoration blocks movement, weapon shots or AI queries")
        local current=object.Parent
        while current and current.Name~="QCScenery"do current=current.Parent end
        check(current~=nil or rig~=nil,"New decoration escaped its owned scenery/NPC folder")
        if rig then
            check(object.Name=="HumanoidRootPart"and object.Anchored==true or object.Massless==true,
                "NPC rig has a physical limb outside its anchored assembly")
        end
        check(object.Size.X>.005 and object.Size.Y>.005 and object.Size.Z>.005,
            "Decoration has an empty or degenerate rendered surface")
        check(object.Position.X==object.Position.X and object.Position.Y==object.Position.Y and object.Position.Z==object.Position.Z,
            "Decoration contains a NaN frame: "..object.Name.." in "..object.Parent.Name)
        check(math.abs(object.CFrame.RightVector.Magnitude-1)<.001
            and math.abs(object.CFrame.UpVector.Magnitude-1)<.001
            and math.abs(object.CFrame.LookVector.Magnitude-1)<.001,
            "Decoration has a non-finite or collapsed orientation: "..object.Name.." in "..object.Parent.Name)
        if object.Name:match("^Palm")or object.Name:match("^TreeLeaf")or object.Name=="UnderstoryLeaf"then
            vegetationParts+=1
            check(object.Material~=roblox.Enum.Material.Neon,"Vegetation uses emissive material instead of shaded leaf surfaces")
        end
        if object.Parent==archipelago.Dunes.QCScenery then
            check(math.abs(object.Position.X-config.IslandById.Dunes.X)>12,"Dunes details obstruct the Sahur landing/combat lane")
        end
    end
    if object:IsA("Model")and object.Name=="SlattedSupplyCrate"then
        cargoProps+=1
        local body=object:FindFirstChild("CrateBody")
        check(body~=nil,"Supply crate has trim with no solid body")
        for _,piece in ipairs(object:GetDescendants())do
            if piece:IsA("BasePart")then
                local relative=body.CFrame:PointToObjectSpace(piece.Position)
                check(math.abs(relative.X)<body.Size.X*.7 and math.abs(relative.Y)<body.Size.Y*.7
                    and math.abs(relative.Z)<body.Size.Z*.7,"Cargo trim floats away from its crate")
            end
        end
    end
end
check(added>800 and added<3000,"Static visual detail budget is unexpectedly empty or excessive")
check(vegetationParts>150,"Detail pass omitted the connected shaded vegetation")
check(cargoProps>=6,"Docks still lack coherent purpose-built cargo props")
-- White ColorShift adds light to every face; a saturated palette then clips to
-- neon yellow/green. Keep the directional tint subtle rather than relying on
-- the fact that the runtime and serialized settings happen to match each other.
check(math.max(theme.Lighting.ColorShift_Top.R,theme.Lighting.ColorShift_Top.G,theme.Lighting.ColorShift_Top.B)<=.10,
    "Directional lighting washes out material colors into bright neon")
check(theme.Effects.QCColor.Properties.Saturation<=.10,"Postprocessing oversaturates the diffuse material palette")
for key,value in pairs(theme.Lighting)do check(lighting[key]==value,"Lighting preset differs: "..key)end
check(lighting.LightingStyle==roblox.Enum.LightingStyle.Soft,"Stylized soft lighting was not selected")
check(lighting.PrioritizeLightingQuality==true,"Lighting quality preference is missing")
for key,value in pairs(theme.Water)do check(workspace.Terrain[key]==value,"Water preset differs: "..key)end
check(oldAtmosphere.Parent==lighting.QCPreviousAtmosphere and oldAtmosphere.Density==.5,"Previous atmosphere was lost instead of retained")
check(lighting.ColorGrading==legacyGrading and legacyGrading.Enabled==true
    and legacyGrading.TonemapperPreset==roblox.Enum.TonemapperPreset.Default,
    "Uploaded Retro tonemapper was not adopted and changed to the controlled Default grade")
check(legacyGrading:GetAttribute("QCOriginalTonemapper")=="Retro"
    and legacyGrading:GetAttribute("QCOriginalEnabled")==true,"Original legacy grade settings were not retained")
check(extraGrading.Parent==lighting.QCPreviousColorGrading and extraGrading.Enabled==false
    and extraGrading.TonemapperPreset==roblox.Enum.TonemapperPreset.Retro
    and extraGrading:GetAttribute("QCOriginalEnabled")==true,"Competing grade was lost or remains active")
check(customCorrection.Parent==lighting and customCorrection.Saturation==.03,"User postprocessing was changed")
check(sky.Parent==lighting,"User sky was replaced")
check(wrongBloom.Parent==nil and lighting.QCBloom.ClassName=="BloomEffect","Wrong class did not migrate to the owned effect")
local effects={}
local function effectValue(key,value)
    return key=="TonemapperPreset"and roblox.Enum.TonemapperPreset[value]or value
end
for name,settings in pairs(theme.Effects)do
    local effect=lighting:FindFirstChild(name)
    effects[name]=effect
    check(effect and effect.ClassName==settings.Class,"Missing owned environment effect")
    for key,value in pairs(settings.Properties)do check(effect[key]==effectValue(key,value),"Environment effect differs: "..name.."."..key)end
end
local count=#workspace:GetDescendants()
local lightingCount=#lighting:GetDescendants()
visuals.ApplyAll()
check(#workspace:GetDescendants()==count,"Second art pass duplicates decorations")
check(#lighting:GetDescendants()==lightingCount,"Second art pass duplicates environment effects")
check(legacyGrading:GetAttribute("QCOriginalTonemapper")=="Retro"
    and legacyGrading:GetAttribute("QCOriginalEnabled")==true,"Repeat application overwrites the original grade settings")
check(extraGrading:GetAttribute("QCOriginalEnabled")==true and extraGrading.Enabled==false,
    "Repeated application re-enables or loses the competing grade backup")
check(leaf:GetAttribute("QCOriginalTransparency")==.25,"Repeated art pass overwrites original frond transparency")
check(leaf:GetAttribute("QCOriginalCanQuery")==true and leaf:GetAttribute("QCOriginalCanTouch")==true,
    "Repeated art pass overwrites the original retired-frond flags")
for name,object in pairs(effects)do check(lighting[name]==object,"Second art pass replaced an existing owned effect")end
local atmosphereCount=0
for _,object in ipairs(lighting:GetChildren())do if object:IsA("Atmosphere")then atmosphereCount+=1 end end
check(atmosphereCount==1,"Multiple active atmospheres compete for the sky")
local activeGrades=0
for _,object in ipairs(lighting:GetDescendants())do
    if object:IsA("ColorGradingEffect")and object.Enabled then activeGrades+=1 end
end
check(activeGrades==1,"Multiple active tonemappers compete for the scene")

-- Inspect the actual rendered cylinder axes, not only the metadata. Both halves
-- of every curved leaf must meet, start at the trunk, and form an arch. These
-- checks catch floating ribs/fronds even if the color preset itself is correct.
local vegetation=loaded.SceneryVegetation
local isolated=new("Folder")
local testTrunk=child(isolated,"Part","PalmTrunk",V.new(3,16,-4),V.new(1.8,20,1.8))
testTrunk.Transparency=.2
testTrunk.CFrame*=CF.Angles(0,0,.08)
local palmParts=vegetation.Palm(isolated,testTrunk,theme.Biomes.home,theme.Palette)
local ribs,bark,frondWedges={},{},0
local function cylinderEnds(object)
    return object.CFrame:PointToWorldSpace(V.new(-object.Size.X*.5,0,0)),
        object.CFrame:PointToWorldSpace(V.new(object.Size.X*.5,0,0))
end
for _,object in ipairs(palmParts)do
    if object.Name=="PalmMidrib"then
        local id,segment=object:GetAttribute("FrondId"),object:GetAttribute("Segment")
        check(type(id)=="number"and type(segment)=="number","Palm lacks connected-frond identifiers")
        ribs[id]=ribs[id]or{};ribs[id][segment]=object
        local a,b=cylinderEnds(object)
        local first,last=object:GetAttribute("Start"),object:GetAttribute("End")
        check(typeof(first)=="Vector3"and typeof(last)=="Vector3","Palm rib lacks inspectable endpoints")
        check(math.min((a-first).Magnitude,(b-first).Magnitude)<.051
            and math.min((a-last).Magnitude,(b-last).Magnitude)<.051,"Rendered rib is detached from its endpoints")
    elseif object.Name=="PalmBark"then table.insert(bark,object)
    elseif object.Name=="PalmFrond"then
        check(object:IsA("WedgePart"),"Palm frond returned to disconnected ellipsoid leaf chunks")
        frondWedges+=1
    end
end
check(#bark>=3 and #bark<=10,"Palm trunk lacks a continuous tapered silhouette")
check(frondWedges>=28,"Palm canopy lacks filled pointed leaf surfaces")
local base=testTrunk.CFrame:PointToWorldSpace(V.new(0,-testTrunk.Size.Y*.5,0))
local nextPoint=base
for _,object in ipairs(bark)do
    local a,b=cylinderEnds(object)
    if(b-nextPoint).Magnitude<(a-nextPoint).Magnitude then a,b=b,a end
    check((a-nextPoint).Magnitude<.10,"Palm trunk sections float apart")
    nextPoint=b
end
local frondCount=0
for _,segments in pairs(ribs)do
    frondCount+=1
    check(segments[1]~=nil and segments[2]~=nil,"Palm leaf is missing a connected half")
    local first,last=segments[1],segments[2]
    near(first:GetAttribute("End"),last:GetAttribute("Start"),"Palm frond segments are disconnected")
    check((first:GetAttribute("Start")-nextPoint).Magnitude<.25,"Palm frond floats away from its crown")
    check(first:GetAttribute("End").Y>first:GetAttribute("Start").Y+.6
        and last:GetAttribute("End").Y<last:GetAttribute("Start").Y-.6,"Palm frond is a flat plank instead of an arch")
end
check(frondCount>=6 and frondCount<=9,"Palm canopy is visibly sparse or exceeds its silhouette budget")
check(testTrunk.Transparency==1 and testTrunk:GetAttribute("QCOriginalTransparency")==.2,
    "Curved palm overlay did not retain the old trunk reversibly")

-- Cached static scenery must follow saved-map relocation: stale generation
-- attributes may not pin props at the previous island coordinates.
local oldDunes=archipelago.Dunes.QCScenery
local moved=V.new(117,0,-83)
local previousDunes={}
for _,object in ipairs(oldDunes:GetDescendants())do
    if object:IsA("BasePart")then previousDunes[object]=object.Position end
end
for _,object in ipairs(archipelago.Dunes:GetDescendants())do
    if object:IsA("BasePart")then
        object.CFrame+=moved
    end
end
visuals.ApplyAll()
local relocated=archipelago.Dunes.QCScenery
check(relocated~=oldDunes and oldDunes.Parent==nil,"Relocated island retained a stale scenery cache")
check(relocated:GetAttribute("AnchorX")==archipelago.Dunes.Plateau.Position.X
    and relocated:GetAttribute("AnchorZ")==archipelago.Dunes.Plateau.Position.Z,"Scenery anchor does not follow the saved island")
check(next(previousDunes)~=nil,"Relocation fixture contains no details")
for object in pairs(previousDunes)do check(object.Parent==nil,"Relocated island retained old owned detail parts")end
local relocatedCount=#workspace:GetDescendants()
visuals.ApplyAll()
check(#workspace:GetDescendants()==relocatedCount,"Repeated relocation rebuild duplicates decoration")

-- A custom unversioned QCScenery folder is user-owned, even when its name is
-- identical to ours. Declining to decorate this one island preserves that work.
local customArch=new("Model")
local customDunes=child(customArch,"Model","Dunes")
local source=archipelago.Dunes.Plateau
local customPlateau=child(customDunes,"Part","Plateau",source.Position,source.Size)
local reserved=child(customDunes,"Folder","QCScenery")
local reservedPart=child(reserved,"Part","MyCustomStatue",source.Position+V.new(0,10,0))
loaded.WorldScenery.Apply(nil,customArch,config,theme)
check(customDunes.QCScenery==reserved and reservedPart.Parent==reserved,"Art migration replaced a user's unversioned scenery folder")
check(#reserved:GetDescendants()==1,"Art migration inserted procedural details into user-owned scenery")

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
    for key,value in pairs(settings.Properties)do matching(effect[key],effectValue(key,value),"Stale serialized effect property: "..name.."."..key)end
end
check(#serializedLighting:GetChildren()==serializedEffectCount,"Serialized lighting has duplicate or stale effects")
print(string.format("PASS %d visual theme checks; %d static non-query decorations",checks,added))
