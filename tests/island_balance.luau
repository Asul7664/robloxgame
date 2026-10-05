-- Run from the repository root: lune run tests/island_balance.luau [optional-v6.rbxlx]
-- Real CFrame math and production modules; only engine instances/terrain are doubled.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local roblox=require("@lune/roblox")
local process=require("@lune/process")
local serde=require("@lune/serde")
local V,CF=roblox.Vector3,roblox.CFrame
local checks=0
local function check(ok,message)checks+=1;assert(ok,message)end
local function near(a,b,message)check((a-b).Magnitude<0.002,message)end
local parts={Part=true,WedgePart=true,MeshPart=true,SpawnLocation=true}
local Node={}
local function new(class)
    local properties={ClassName=class,Name=class,Children={},CFrame=CF.new(),Size=V.new(1,1,1),Pivot=CF.new()}
    return setmetatable({_p=properties},{
        __index=function(self,key)
            if key=="Position"then return properties.CFrame.Position end
            return Node[key]or properties[key]or self:FindFirstChild(key)
        end,
        __newindex=function(self,key,value)
            if key=="Parent"then
                if properties.Parent then
                    for i,child in ipairs(properties.Parent.Children)do
                        if child==self then table.remove(properties.Parent.Children,i);break end
                    end
                end
                properties.Parent=value
                if value then table.insert(value.Children,self)end
            elseif key=="Position"then properties.CFrame=CF.new(value)*(properties.CFrame-properties.CFrame.Position)
            else properties[key]=value end
        end,
    })
end
function Node:IsA(class)return self.ClassName==class or(class=="BasePart"and parts[self.ClassName]==true)end
function Node:FindFirstChild(name)for _,child in ipairs(self.Children)do if child.Name==name then return child end end end
function Node:WaitForChild(name)return assert(self:FindFirstChild(name),"Missing child "..name)end
function Node:FindFirstChildOfClass(class)for _,child in ipairs(self.Children)do if child:IsA(class)then return child end end end
function Node:GetChildren()return table.clone(self.Children)end
function Node:GetDescendants()
    local out={}
    local function visit(parent)for _,child in ipairs(parent.Children)do table.insert(out,child);visit(child)end end
    visit(self);return out
end
function Node:Destroy()for _,child in ipairs(self:GetChildren())do child:Destroy()end;self.Parent=nil end
function Node:GetPivot()return self.Pivot end
function Node:PivotTo(frame)
    local delta=frame*self.Pivot:Inverse()
    for _,child in ipairs(self:GetDescendants())do if child:IsA("BasePart")then child.CFrame=delta*child.CFrame end end
    self.Pivot=frame
end
function Node:FillBlock(frame,size,material)self.LastFill={Frame=frame,Size=size,Material=material}end
local function child(parent,class,name,position)
    local object=new(class);object.Name=name;object.Parent=parent
    if position then object.Position=position end
    return object
end
local function caption(parent)
    local gui=child(parent,"BillboardGui","Label")
    local text=child(gui,"TextLabel","TextLabel");text.Text="old target";return text
end
local workspace=new("Workspace");child(workspace,"Terrain","Terrain")
local lighting=new("Lighting")
local loaded={}
local environment={
    game={GetService=function(_,name)return({Workspace=workspace,Lighting=lighting,ReplicatedStorage={
        WaitForChild=function()return{WaitForChild=function(_,module)return module end}end,
    }})[name]end},
    script={Parent={WaitForChild=function(_,name)return name end}},
    require=function(name)return assert(loaded[name],"Unloaded module "..tostring(name))end,
    Instance={new=new},Vector3=V,CFrame=CF,Color3=roblox.Color3,UDim2=roblox.UDim2,Enum=roblox.Enum,
}
local function load(name,path)
    local source=fs.readFile(path);luau.compile(source)
    loaded[name]=luau.load(source,{environment=environment})()
    return loaded[name]
end
load("BrainrotExpansion","src/shared/BrainrotExpansion.luau")
local config=load("Config","src/shared/Config.luau")
local world=load("World","src/server/World.luau")
local archipelago=load("Archipelago","src/server/Archipelago.luau")
local previous={Cove={0,0},Reef={262.5,-325},Moss={-950,475},Dunes={-825,-850},Bloom={825,475},Storm={975,-1050}}
local sceneText=serde.decode("json",fs.readFile("world-text.project.json")).tree

-- Every pair is farther apart; all boat berths and fishing decks still fit the map/ocean.
for i,island in ipairs(config.Islands)do
    check(math.abs(island.X)+island.Radius+120<config.Ocean.HalfExtent,"Island outside ocean: "..island.Id)
    check(math.abs(island.Z)+island.Radius+120<config.Ocean.MapSpan/2,"Island outside map: "..island.Id)
    check(math.abs(island.DockX+30)<config.Ocean.HalfExtent,"Boat berth X outside ocean")
    check(math.abs(island.DockZ+15)<config.Ocean.HalfExtent,"Boat berth Z outside ocean")
    if island.Weights then
        local part=island.Id=="Reef"and sceneText.QuietCoveMap.ReefSign
            or sceneText.QuietCoveArchipelago[island.Id].FishingMarker
        check(part.Label.TextLabel["$properties"].Text:find(island.Target,1,true)~=nil,"Rojo catch caption disagrees with pool")
    end
    for j=i+1,#config.Islands do
        local other=config.Islands[j]
        local first,second=previous[island.Id],previous[other.Id]
        local old=(V.new(first[1],0,first[2])-V.new(second[1],0,second[2])).Magnitude
        local distance=(V.new(island.X,0,island.Z)-V.new(other.X,0,other.Z)).Magnitude
        check(distance>old*1.4,"Insufficient separation: "..island.Id.."/"..other.Id)
    end
end
local function probabilities(zone,rod,night)
    local weights,total={},0
    for _,fish in ipairs(config.Fish)do
        if config.Eligible(fish,zone,rod.MaxKg,night,rod.Quality)then
            local weight=config.RollWeight(fish,1,zone);weights[fish.Id]=weight;total+=weight
        end
    end
    check(total>0,"Empty catch pool: "..zone)
    for id,weight in pairs(weights)do weights[id]=weight/total end
    return weights
end
for _,island in ipairs(config.Islands)do
    if island.Weights then
        for id,weight in pairs(island.Weights)do
            check(config.ById[id]~=nil and weight>0,"Invalid habitat weight: "..id)
        end
    end
    for _,rod in ipairs(config.Rods)do
        for _,night in ipairs({false,true})do
            local pool=probabilities(island.Id,rod,night)
            for id in pairs(pool)do
                local fish=config.ById[id]
                check(fish.MinKg<=rod.MaxKg and(rod.Quality>=(fish.MinRodQuality or 1)),"Ineligible catch")
                check(night or not fish.Night,"Night fish in day pool")
            end
        end
    end
end
local reef=probabilities("Reef",config.Rods[1],false)
local moss=probabilities("Moss",config.Rods[1],false)
check(reef.patapim<0.04 and reef.ambalabu<0.03,"Reef still overproduces Moss fish")
check(moss.patapim>0.4 and moss.ambalabu>0.3,"Moss lacks its specialty")
check(moss.patapim/reef.patapim>10 and moss.ambalabu/reef.ambalabu>10,"Travel has no meaningful catch advantage")
for fish,home in pairs({chimpanzini="Bloom",frigocamelo="Dunes",lavacca="Storm"})do
    for _,island in ipairs(config.Islands)do
        check((config.ZoneWeight(config.ById[fish],island.Id)>0)==(island.Id==home),"Exclusive species duplicated")
    end
end

-- Saved-world migration: use the uploaded scene when supplied, otherwise a compact old scene.
if process.args[1]then
    local bytes=fs.readFile(process.args[1]):gsub("^<%?xml.-%?>%s*","")
    local place=roblox.deserializePlace(bytes)
    local function clone(source,parent)
        local object=child(parent,source.ClassName,source.Name)
        if object:IsA("BasePart")then object.CFrame=source.CFrame;object.Size=source.Size end
        if source:IsA("TextLabel")then object.Text=source.Text end
        for _,descendant in ipairs(source:GetChildren())do clone(descendant,object)end
        return object
    end
    for _,name in ipairs({"QuietCoveMap","QuietCoveArchipelago"})do clone(place.Workspace[name],workspace)end
else
    local map=child(workspace,"Model","QuietCoveMap")
    for _,name in ipairs({"Merchant","Rodsmith"})do child(child(map,"Model",name),"Part","Body")end
    child(map,"Part","Ferry",V.new(17,9,-78))
    local reefPosition=V.new(previous.Reef[1],-1,previous.Reef[2])
    child(map,"Part","ReefRock",reefPosition)
    child(map,"Part","PalmTrunk",reefPosition+V.new(15,20,10))
    child(map,"Part","ReturnFerry",reefPosition+V.new(6,10,-15))
    caption(child(map,"Part","ReefSign",reefPosition+V.new(-7,10,-37)))
    local folder=child(workspace,"Model","QuietCoveArchipelago")
    for _,island in ipairs(config.Islands)do
        local old=previous[island.Id]
        if island.Theme~="home"and island.Theme~="reef"then
            local model=child(folder,"Model",island.Id)
            child(model,"Part","IslandStone",V.new(old[1],-2,old[2]))
            caption(child(model,"Part","FishingMarker",V.new(old[1]-10,9,old[2]-island.Radius-27)))
            caption(child(model,"Part","IslandBeacon",V.new(old[1],9,old[2]+18)))
        end
        local dock=child(folder,"Model","Dock_"..island.Id)
        local oldDockZ=island.Id=="Cove"and 70 or(island.Id=="Reef"and -284 or old[2]+island.Radius+22)
        child(dock,"Part","Boardwalk",V.new(old[1],7,oldDockZ-9))
        child(child(dock,"Model","Captain"),"Part","Body",V.new(old[1]-7,9.3,oldDockZ+2))
        caption(child(dock,"Part","DockSign",V.new(old[1]+8,9,oldDockZ+1)))
        if island.Theme~="home"and island.Theme~="reef"then child(child(dock,"Model","Buyer"),"Part","Body")end
    end
end
local map=workspace.QuietCoveMap
local folder=workspace.QuietCoveArchipelago
folder.Moss.Pivot=CF.new(-800,12,90)*CF.Angles(0.2,0.7,0.1)
local additions=child(folder.Moss,"Model","PlayerDecoration")
local extra=child(additions,"Part","RotatedDecoration",folder.Moss.IslandStone.Position+V.new(12,22,18))
extra.CFrame=extra.CFrame*CF.Angles(0.3,0.5,0.2)
local original,expected={},{ }
local reefAnchor=map.ReefRock.Position
for _,object in ipairs(workspace:GetDescendants())do
    if object:IsA("BasePart")then original[object]=object.CFrame;expected[object]=V.zero end
end
for _,object in ipairs(map:GetDescendants())do
    if object:IsA("BasePart")then
        local relative=object.Position-reefAnchor
        if V.new(relative.X,0,relative.Z).Magnitude<=120 then
            expected[object]=V.new(config.IslandById.Reef.X-reefAnchor.X,0,config.IslandById.Reef.Z-reefAnchor.Z)
        end
    end
end
for _,island in ipairs(config.Islands)do
    for _,entry in ipairs({{Name=island.Id,Anchor="IslandStone",X=island.X,Z=island.Z},
        {Name="Dock_"..island.Id,Anchor="Boardwalk",X=island.DockX,Z=island.DockZ-9}})do
        local model=folder:FindFirstChild(entry.Name)
        if model then
            local old=model:WaitForChild(entry.Anchor).Position
            for _,object in ipairs(model:GetDescendants())do
                if object:IsA("BasePart")then expected[object]=V.new(entry.X-old.X,0,entry.Z-old.Z)end
            end
        end
    end
end
local count=#workspace:GetDescendants()
local refs=archipelago.Attach(world.Build())
check(#workspace:GetDescendants()==count,"Migration added duplicate geometry")
for object,frame in pairs(original)do
    near(object.Position,frame.Position+expected[object],"Incorrect saved-part relocation: "..object.Name)
    near(object.CFrame.LookVector,frame.LookVector,"Relocation rotated user geometry")
end
near(refs.ReefSpawn,V.new(config.IslandById.Reef.X,11,config.IslandById.Reef.Z-20),"Ferry destination mismatch")
for _,island in ipairs(config.Islands)do
    local dock=folder:WaitForChild("Dock_"..island.Id)
    near(dock.Boardwalk.Position,V.new(island.DockX,7,island.DockZ-9),"Dock refs detached from actual pier")
    near(refs.Docks[island.Id].Berth,V.new(island.DockX+30,config.Ocean.BoatHeight,island.DockZ+15),"Incorrect boat berth")
    if island.Theme~="home"and island.Theme~="reef"then
        check(folder[island.Id].FishingMarker.Label.TextLabel.Text:find(island.Target,1,true)~=nil,"Old island catch caption")
        near(refs.Spots[island.Id].Center,V.new(island.X,8,island.Z-island.Radius-25),"Wrong fishing spot")
    end
end
local migrated={}
for object in pairs(original)do migrated[object]=object.CFrame end
archipelago.Attach(world.Build())
check(#workspace:GetDescendants()==count,"Second Build duplicates geometry")
for object,frame in pairs(migrated)do near(object.Position,frame.Position,"Repeated migration drifts geometry")end

-- A new place still builds without depending on a saved v6 scene.
workspace.QuietCoveMap:Destroy();workspace.QuietCoveArchipelago:Destroy()
local fresh=archipelago.Attach(world.Build())
check(#fresh.Buyers==5,"New map lacks buyers")
check(#workspace.QuietCoveArchipelago:GetChildren()==12,"Unexpected fresh island/dock count")
check(workspace.Terrain.LastFill.Size.X==(config.Ocean.HalfExtent+100)*2,"Terrain does not cover the enlarged ocean")
print(string.format("PASS %d checks; Reef Patapim %.2f%% / Ambalabu %.2f%%; Moss %.2f%% / %.2f%%",checks,
    reef.patapim*100,reef.ambalabu*100,moss.patapim*100,moss.ambalabu*100))
