-- Native Roblox Instances/CFrames, exact triangulated surface and no Terrain
-- mutation. Physics, water rendering and boat motion still require Studio.
local fs=require('@lune/fs')
local luau=require('@lune/luau')
local R=require('@lune/roblox')
local checks=0
local function check(ok,message)checks+=1;assert(ok,message)end
local expansion=luau.load(fs.readFile('src/shared/BrainrotExpansion.luau'))()
local config=luau.load(fs.readFile('src/shared/Config.luau'),{environment={
    Vector3=R.Vector3,script={Parent={WaitForChild=function(_,name)return name end}},
    require=function(name)assert(name=='BrainrotExpansion');return expansion end,
}})()
config.Seabed=config.Seabed or {Enabled=true,CellSize=256,MinDepth=12,MaxDepth=26,ReefPatchesPerIsland=6}
local theme=luau.load(fs.readFile('src/shared/VisualTheme.luau'),{environment={Color3=R.Color3}})()
local reefCalls=0
local failReefs=false
local Ocean
Ocean=luau.load(fs.readFile('src/server/OceanFloor.luau'),{environment={
    script={Parent={WaitForChild=function(_,name)return name end}},
    require=function(name)
        assert(name=='ReefScenery')
        return {Build=function(parent,_,_,heightAt)
            reefCalls+=1
            if failReefs then error('Simulated decoration failure') end
            local marker=R.Instance.new('Folder');marker.Name='Reefs';marker.Parent=parent
            check(heightAt(0,0)==Ocean.HeightAt(0,0,config),'Reefs sample the same rendered height')
        end}
    end,
    Instance=R.Instance,Vector3=R.Vector3,CFrame=R.CFrame,Color3=R.Color3,Enum=R.Enum,
}})()
local workspace=R.Instance.new('Folder')
local user=R.Instance.new('Part');user.Name='UserIsland';user.CFrame=R.CFrame.new(50,5,-80);user.Parent=workspace
local userFrame=user.CFrame
-- Lua closures in the fake dependency above see the post-load binding here.
local function apply()return Ocean.Apply(workspace,config,theme)end
local model=apply()
check(model and model.Parent==workspace and model:GetAttribute('QCOceanFloor')==true,'Floor has an owned isolated model')
check(user.Parent==workspace and user.CFrame==userFrame,'Island authored geometry is unchanged')
local parts=model.Sand:GetChildren()
check(#parts<=2100 and #parts>=1900,'Default ocean uses about two thousand native wedges, not a dense per-stud grid')
local low,high=math.huge,-math.huge
for _,part in parts do
    check(part:IsA('WedgePart') and part.Material==R.Enum.Material.Sand,'Seabed is actual native sand geometry')
    check(part.Anchored and part.CanCollide and part.CanQuery and not part.CanTouch,'Only the physical sand floor collides')
    check(part:GetAttribute('QCSeabed')==true,'Water hazard can identify owned underwater support')
    local frame,size=part.CFrame,part.Size
    local normal=frame.RightVector.Y>=0 and frame.RightVector or -frame.RightVector
    check(normal.Y>.99,'Undulations retain gentle navigable slopes')
    local x=frame.RightVector.Y>=0 and size.X*.5 or -size.X*.5
    local points={R.Vector3.new(x,-size.Y*.5,-size.Z*.5),R.Vector3.new(x,-size.Y*.5,size.Z*.5),R.Vector3.new(x,size.Y*.5,size.Z*.5)}
    for _,localPoint in points do
        local point=frame:PointToWorldSpace(localPoint)
        local rendered=Ocean.HeightAt(point.X,point.Z,config)
        check(math.abs(rendered-point.Y)<.003,'Native wedge top matches the exact sampled surface')
        check(point.Y<=config.Ocean.SurfaceY-12+.003 and point.Y>=config.Ocean.SurfaceY-26-.003,'Sand is submerged and stays in existing water volume')
        low=math.min(low,point.Y);high=math.max(high,point.Y)
    end
end
check(high-low>5,'Sand has visible crests and hollows instead of a flat slab')
for _,island in config.Islands do
    for _,offset in {{0,0},{30,15},{-10,5}} do
        local h=Ocean.HeightAt(island.DockX+offset[1],island.DockZ+offset[2],config)
        check(config.Ocean.BoatHeight-.9-h>10,'Hull and docking areas retain more than ten studs clearance')
    end
end
local half=config.Ocean.HalfExtent+100
local cells=math.ceil(half*2/config.Seabed.CellSize)
local step=half*2/cells
for i=1,cells-1 do
    for _,z in {-half+10,-450,0,720,half-10} do
        local x=-half+i*step
        check(math.abs(Ocean.HeightAt(x-1e-5,z,config)-Ocean.HeightAt(x+1e-5,z,config))<1e-4,'Adjacent cells share continuous edge heights')
    end
end
check(apply()==model and reefCalls==1,'Repeated build reuses owned terrain and reefs')
local oldTheme=theme.Version;theme.Version+=1
failReefs=true
check(not pcall(apply) and model.Parent==workspace,'Failed decoration staging leaves the previous floor intact')
failReefs=false
local rebuilt=apply()
check(rebuilt~=model and model.Parent==nil and reefCalls==3,'Theme update replaces only the owned floor once')
local restored=R.deserializeModel(R.serializeModel({rebuilt},true))[1]
check(#restored.Sand:GetChildren()==#parts,'Seabed survives Roblox native serialization')
config.Seabed.Enabled=false
check(apply()==nil and rebuilt.Parent==nil and user.Parent==workspace,'Disable removes owned floor only')
local foreign=R.Instance.new('Model');foreign.Name='QuietCoveSeabed';foreign.Parent=workspace
config.Seabed.Enabled=true
check(apply()==nil and foreign.Parent==workspace,'Foreign same-named model is never overwritten')
print('PASS ocean floor: '..checks..' native geometry, water depth, route clearance, continuity and ownership checks')
