-- Export actual production-generated scenery for a Blender geometry preview.
-- Run: lune run tools/preview_world.luau [/workspace/outputs/quiet-cove-world.json]
-- Rendering is an approximation of lighting, not a Roblox Studio screenshot.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local roblox=require("@lune/roblox")
local process=require("@lune/process")
local serde=require("@lune/serde")
local V,CF=roblox.Vector3,roblox.CFrame
local parts={Part=true,WedgePart=true,MeshPart=true,SpawnLocation=true}
local Node={}
local function new(class)
    local properties={ClassName=class,Name=class,Children={},Attributes={},CFrame=CF.new(),Size=V.new(1,1,1),Pivot=CF.new(),
        Color=roblox.Color3.fromRGB(163,162,165),Transparency=0,CanCollide=true,CanQuery=true,CanTouch=true}
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
function Node:GetAttribute(key)return self.Attributes[key]end
function Node:SetAttribute(key,value)self.Attributes[key]=value end
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
load("VisualTheme","src/shared/VisualTheme.luau")
load("SceneryVegetation","src/server/SceneryVegetation.luau")
load("SceneryLandmarks","src/server/SceneryLandmarks.luau")
load("WorldScenery","src/server/WorldScenery.luau")
load("WorldVisuals","src/server/WorldVisuals.luau")
local world=load("World","src/server/World.luau")
local archipelago=load("Archipelago","src/server/Archipelago.luau")

archipelago.Attach(world.Build())
local out={Parts={},Islands={},Water={},Palette={},
    RendererNote="Actual production geometry; Blender lighting is an approximation, not a Studio screenshot."}
for _,object in ipairs(workspace:GetDescendants()) do
    if object:IsA("BasePart") and object.Transparency<0.95 then
        local components={object.CFrame:GetComponents()}
        local c=object.Color
        local chain={object.Name};local parent=object.Parent
        while parent and parent~=workspace do table.insert(chain,1,parent.Name);parent=parent.Parent end
        table.insert(out.Parts,{Name=table.concat(chain,"/"),Class=object.ClassName,
            Shape=object.Shape and object.Shape.Name or "Block",Material=object.Material and object.Material.Name or "SmoothPlastic",
            Frame=components,Size={object.Size.X,object.Size.Y,object.Size.Z},
            Color={c.R,c.G,c.B},Transparency=object.Transparency,CastShadow=object.CastShadow~=false})
    end
end
-- This authored model is mapped separately by Rojo rather than World.Build.
-- Deserialization reads geometry only; no model scripts are ever run.
local stall=roblox.deserializeModel(fs.readFile("assets/weapons/WeaponStall.rbxmx"))[1]
for _,object in ipairs(stall:GetDescendants())do
    if object:IsA("BasePart") and object.Transparency<0.95 then
        local c=object.Color;local shape="Block"
        pcall(function() shape=object.Shape.Name end)
        local chain={object.Name};local parent=object.Parent
        while parent do table.insert(chain,1,parent.Name);parent=parent.Parent end
        table.insert(out.Parts,{Name=table.concat(chain,"/"),Class=object.ClassName,
            Shape=shape,Material=object.Material.Name,Frame={object.CFrame:GetComponents()},
            Size={object.Size.X,object.Size.Y,object.Size.Z},Color={c.R,c.G,c.B},
            Transparency=object.Transparency,CastShadow=object.CastShadow})
    end
end
for _,island in ipairs(config.Islands)do
    table.insert(out.Islands,{Id=island.Id,X=island.X,Z=island.Z,Radius=island.Radius})
end
for key,value in pairs(loaded.VisualTheme.Palette)do out.Palette[key]={value.R,value.G,value.B}end
for _,object in ipairs(out.Parts)do
    for _,value in ipairs(object.Frame)do
        assert(value==value and math.abs(value)<math.huge,"Non-finite production CFrame: "..object.Name)
    end
end
local function metadata(value)
    if typeof(value)=="Color3"then return{value.R,value.G,value.B}end
    if typeof(value)=="EnumItem"then return value.Name end
    if type(value)=="table"then
        local result={}
        for key,item in pairs(value)do result[key]=metadata(item)end
        return result
    end
    return value
end
out.Lighting=metadata(loaded.VisualTheme.Lighting)
out.LightingStyle=loaded.VisualTheme.LightingStyle
out.Effects=metadata(loaded.VisualTheme.Effects)
out.Water=metadata(loaded.VisualTheme.Water)
local output=process.args[1] or "/workspace/outputs/quiet-cove-world.json"
fs.writeFile(output,serde.encode("json",out,true))
print(string.format("Exported %d actual production parts to %s",#out.Parts,output))
