-- Export actual native OceanFloor/ReefScenery parts around the home island.
-- lune run tools/preview_ocean.luau [/workspace/outputs/ocean-v2.json]
-- JSON contains Part frames/sizes/colors, Sphere mesh scale and patch types.
-- Far ocean floor is cropped for preview only; production remains complete.
local fs=require('@lune/fs')
local luau=require('@lune/luau')
local R=require('@lune/roblox')
local serde=require('@lune/serde')
local process=require('@lune/process')
local loaded={}
local environment={Instance=R.Instance,Vector3=R.Vector3,CFrame=R.CFrame,Color3=R.Color3,Enum=R.Enum,
    script={Parent={WaitForChild=function(_,name)return name end}},
    require=function(name)return assert(loaded[name],name)end}
local function load(name,path)
    loaded[name]=luau.load(fs.readFile(path),{environment=environment})()
    return loaded[name]
end
load('BrainrotExpansion','src/shared/BrainrotExpansion.luau')
local config=load('Config','src/shared/Config.luau')
local theme=load('Theme','src/shared/VisualTheme.luau')
load('ReefScenery','src/server/ReefScenery.luau')
local ocean=load('OceanFloor','src/server/OceanFloor.luau')
local workspace=R.Instance.new('Model')
local model=ocean.Apply(workspace,config,theme)
local out={Parts={},Patches={},Heights={}}
for _,patch in model.ReefGardens:GetChildren() do
    if patch:GetAttribute('IslandId')=='Cove' then
        table.insert(out.Patches,{Name=patch.Name,Type=patch:GetAttribute('ReefType'),
            Center={patch:GetAttribute('AnchorX'),patch:GetAttribute('GroundY'),patch:GetAttribute('AnchorZ')}})
    end
end
for _,part in model:GetDescendants() do
    if not part:IsA('BasePart') then continue end
    local patch=part.Parent
    local isReef=patch:GetAttribute('ReefType')~=nil
    if isReef and patch:GetAttribute('IslandId')~='Cove' then continue end
    if not isReef then
        local p=part.CFrame.Position;local r=part.Size.Magnitude*.5
        if math.abs(p.X)>420+r or math.abs(p.Z+80)>400+r then continue end
    end
    local mesh=part:FindFirstChildOfClass('SpecialMesh')
    local c=part.Color
    local row={Name=part.Name,Patch=isReef and patch.Name or nil,Type=isReef and patch:GetAttribute('ReefType') or nil,
        Class=part.ClassName,Frame={part.CFrame:GetComponents()},Size={part.Size.X,part.Size.Y,part.Size.Z},
        Color={c.R,c.G,c.B},Shape=part:IsA('Part') and part.Shape.Name or 'Wedge'}
    if mesh then row.MeshType=mesh.MeshType.Name;row.MeshScale={mesh.Scale.X,mesh.Scale.Y,mesh.Scale.Z}end
    table.insert(out.Parts,row)
end
for _,p in {{0,-120},{0,-80},{75,-180},{120,-180},{-75,-180},{120,-80},{50,-220}} do
    table.insert(out.Heights,{p[1],ocean.HeightAt(p[1],p[2],config),p[2]})
end
fs.writeFile(process.args[1] or '/workspace/outputs/ocean-v2.json',serde.encode('json',out,true))
print('Exported '..#out.Parts..' source parts; '..#out.Patches..' Cove patches')
