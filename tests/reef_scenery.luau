-- Real native instances and CFrame bounds. This does not simulate terrain/water.
local fs=require('@lune/fs')
local luau=require('@lune/luau')
local R=require('@lune/roblox')
local E={Instance=R.Instance,Vector3=R.Vector3,CFrame=R.CFrame,Color3=R.Color3,Enum=R.Enum}
local Reef=luau.load(fs.readFile('src/server/ReefScenery.luau'),{environment=E})()
local theme=luau.load(fs.readFile('src/shared/VisualTheme.luau'),{environment=E})()
local expansion=luau.load(fs.readFile('src/shared/BrainrotExpansion.luau'))()
local config=luau.load(fs.readFile('src/shared/Config.luau'),{environment={
    script={Parent={WaitForChild=function(_,name)return name end}},require=function()return expansion end,
}})()
config.Seabed=config.Seabed or {ReefPatchesPerIsland=6}
local checks=0
local function check(ok,message)checks+=1;assert(ok,message)end
local function heightAt(x,z)return -16+2*math.sin(x/280)*math.cos(z/220)end
local function build()
    local parent=R.Instance.new('Model')
    return parent,Reef.Build(parent,config,theme,heightAt)
end
local parent,root=build()
local byId={}
for _,island in config.Islands do byId[island.Id]=island end
local physical,counts,names=0,{},{}
local function listParts(model)
    local out={}
    for _,p in model:GetDescendants() do if p:IsA('BasePart') then table.insert(out,p) end end
    return out
end
for _,patch in root:GetChildren() do
    local id=patch:GetAttribute('IslandId');local island=byId[id]
    check(island~=nil,'Every reef is associated with an authored island')
    counts[id]=(counts[id] or 0)+1
    local x,z=patch:GetAttribute('AnchorX'),patch:GetAttribute('AnchorZ')
    local radius=math.sqrt((x-island.X)^2+(z-island.Z)^2)
    check(radius>island.Radius+35 and radius<island.Radius+90,'Reef patch stays outside the walkable island')
    check(math.abs(patch:GetAttribute('GroundY')-heightAt(x,z))<.00001,'Patch anchoring uses actual floor height')
    for _,p in patch:GetDescendants() do
        if p:IsA('SpecialMesh') then
            check(p.MeshType==R.Enum.MeshType.Sphere and p.Scale==R.Vector3.one,'Ellipsoids use built-in native Sphere mesh')
            continue
        end
        check(p:IsA('BasePart'),'Reef contains no scripts, remotes or controllers')
        physical+=1;names[p.Name]=true
        check(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery,'Reef cannot interfere with boats, rays or player movement')
        for _,value in {p.CFrame:GetComponents()} do check(value==value and math.abs(value)<math.huge,'Finite reef part frame') end
        check(p.Size.X>0 and p.Size.Y>0 and p.Size.Z>0,'Reef uses nondegenerate geometry')
        check(math.abs(p.CFrame.RightVector:Dot(p.CFrame.UpVector))<.0001,'Branches use an orthogonal stable basis')
        local top=-math.huge
        for _,sx in {-1,1} do for _,sy in {-1,1} do for _,sz in {-1,1} do
            top=math.max(top,p.CFrame:PointToWorldSpace(R.Vector3.new(sx*p.Size.X/2,sy*p.Size.Y/2,sz*p.Size.Z/2)).Y)
        end end end
        check(top<config.Ocean.SurfaceY-5,'Reef tops leave ample water clearance for boats')
        if p.Name=='ReefFoundation' then
            local base=p.CFrame.Position.Y-p.Size.Y/2
            local ground=heightAt(p.CFrame.Position.X,p.CFrame.Position.Z)
            check(base<ground and ground-base<.3,'Stone mound is grounded, not floating above sand')
        end
    end
end
for _,island in config.Islands do check(counts[island.Id]==6,'Every island receives six localized gardens') end
check(physical>=900 and physical<=1400,'Default detail budget remains bounded across the whole ocean')
for _,name in {'ReefFoundation','CoralTrunk','CoralFork','SeaFanLobe','SeaFanVein','TableCoral','ReefSponge','SpongeOpening','Seagrass'} do
    check(names[name],'Reef includes recognizable marine detail '..name)
end
local parent2,root2=build()
local a,b=listParts(root),listParts(root2)
check(#a==#b,'Rebuild is deterministic in part count')
for index,p in a do
    check(p.CFrame==b[index].CFrame and p.Size==b[index].Size and p.Color==b[index].Color,'Rebuild is deterministic in shape and palette')
end
local restored=R.deserializeModel(R.serializeModel({root},true))[1]
check(#listParts(restored)==physical,'Reef survives native Roblox model serialization')
local shallow=Reef.Build(R.Instance.new('Model'),config,theme,function()return -8 end)
check(#shallow:GetChildren()==0,'Unexpected user shallow areas never create reefs near the surface')
parent:Destroy();parent2:Destroy();restored:Destroy();shallow:Destroy()
print('PASS reef scenery: '..checks..' native geometry, floor contact, clearance and determinism checks ('..physical..' parts)')
