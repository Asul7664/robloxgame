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
check(#parts<=6500 and #parts>=3500,'Only coastal cells receive detail; ocean part budget remains bounded')
check(model:GetAttribute('DetailCells')>0,'Coastal terrain contains refined cells')
local low,high=math.huge,-math.huge
for _,part in parts do
    check(part:IsA('WedgePart') and part.Material==R.Enum.Material.Sand,'Seabed is actual native sand geometry')
    check(part.Anchored and part.CanCollide and part.CanQuery and not part.CanTouch,'Only the physical sand floor collides')
    check(part:GetAttribute('QCSeabed')==true,'Water hazard can identify owned underwater support')
    local frame,size=part.CFrame,part.Size
    local normal=frame.RightVector.Y>=0 and frame.RightVector or -frame.RightVector
    check(normal.Y>.9,'Visible slopes remain stable walkable sand, not cliff walls')
    local x=frame.RightVector.Y>=0 and size.X*.5 or -size.X*.5
    local points={R.Vector3.new(x,-size.Y*.5,-size.Z*.5),R.Vector3.new(x,-size.Y*.5,size.Z*.5),R.Vector3.new(x,size.Y*.5,size.Z*.5)}
    local centroid=R.Vector3.zero
    for _,localPoint in points do
        local point=frame:PointToWorldSpace(localPoint)
        centroid+=point
        local rendered=Ocean.HeightAt(point.X,point.Z,config)
        check(math.abs(rendered-point.Y)<.003,'Native wedge top matches the exact sampled surface')
        check(point.Y<=config.Ocean.SurfaceY-math.max(10,config.Seabed.MinDepth)+.003 and point.Y>=config.Ocean.SurfaceY-26-.003,'Sand is submerged and stays in existing water volume')
        low=math.min(low,point.Y);high=math.max(high,point.Y)
    end
    centroid/=3
    check(math.abs(Ocean.HeightAt(centroid.X,centroid.Z,config)-centroid.Y)<.003,'Every rendered wedge interior agrees with the reef height sampler')
end
check(high-low>10,'Sand has visible crests and hollows instead of a flat slab')
local nearbyLow,nearbyHigh=math.huge,-math.huge
local nearbyStep=0
for x=80,240,10 do
    for z=-160,40,10 do
        local h=Ocean.HeightAt(x,z,config)
        nearbyLow=math.min(nearbyLow,h);nearbyHigh=math.max(nearbyHigh,h)
        nearbyStep=math.max(nearbyStep,math.abs(h-Ocean.HeightAt(x+64,z,config)))
    end
end
check(nearbyHigh-nearbyLow>=8,'Cove relief is visible within a short swim, not only across the full map')
check(nearbyStep>=4,'Nearby sand ridges change height appreciably over sixty-four studs')
for _,island in config.Islands do
    for _,offset in {{0,0},{30,15},{-10,5}} do
        local h=Ocean.HeightAt(island.DockX+offset[1],island.DockZ+offset[2],config)
        check(config.Ocean.BoatHeight-.9-h>9,'Hull and docking areas retain more than nine studs clearance')
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
-- Sample every coarse-cell boundary at several fine-edge positions. Fine/coarse
-- seams must be straight on BOTH sides; this specifically rejects T-junction gaps.
for edge=1,cells-1 do
    local boundary=-half+edge*step
    for cell=0,cells-1 do
        for fraction=0,4 do
            local across=-half+(cell+fraction/4)*step
            check(math.abs(Ocean.HeightAt(boundary-1e-5,across,config)-Ocean.HeightAt(boundary+1e-5,across,config))<.001,
                'Fine/coarse X boundary remains crack-free')
            check(math.abs(Ocean.HeightAt(across,boundary-1e-5,config)-Ocean.HeightAt(across,boundary+1e-5,config))<.001,
                'Fine/coarse Z boundary remains crack-free')
        end
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
print('PASS ocean floor ('..#parts..' wedges, local relief '..string.format('%.1f',nearbyHigh-nearbyLow)..' studs): '..checks..' native geometry, water depth, route clearance, continuity and ownership checks')
