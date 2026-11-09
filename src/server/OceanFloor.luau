-- A continuous sand heightfield below our existing Terrain water. Nothing
-- writes/clears Terrain, and the owned subtree is replaceable without islands.
local Reefs=require(script.Parent:WaitForChild('ReefScenery'))
local Ocean={}
local VERSION='sand-heightfield-1'
local THICKNESS=1
local function dimensions(config)
    local settings=config.Seabed
    local half=config.Ocean.HalfExtent+100
    local cells=math.max(1,math.ceil(half*2/math.clamp(settings.CellSize,128,512)))
    return half,cells,half*2/cells
end
local function smooth(t)
    t=math.clamp(t,0,1)
    return t*t*(3-2*t)
end
local function vertexHeight(x,z,config)
    local s=config.Seabed
    local wave=math.sin(x/440)*2.4+math.cos(z/570)*2.0+math.sin((x+z)/730)*1.5
    local depth=19+wave
    local shelf=0
    for _,island in ipairs(config.Islands) do
        local dx,dz=x-island.X,z-island.Z
        local distance=math.sqrt(dx*dx+dz*dz)
        shelf=math.max(shelf,1-smooth((distance-island.Radius-40)/330))
    end
    local coastal=13.6+math.sin(x/190)*.8+math.cos(z/220)*.65
    depth=depth+(coastal-depth)*shelf
    -- The water column ends 28 studs below sea level in World.Build.
    -- Always retain navigable water and keep valleys above its bottom.
    local minimum=math.clamp(s.MinDepth,10,26)
    local maximum=math.clamp(s.MaxDepth,minimum,26)
    return config.Ocean.SurfaceY-math.clamp(depth,minimum,maximum)
end
function Ocean.HeightAt(x,z,config)
    local half,cells,step=dimensions(config)
    local gx=math.clamp((x+half)/step,0,cells)
    local gz=math.clamp((z+half)/step,0,cells)
    local ix,iz=math.min(cells-1,math.floor(gx)),math.min(cells-1,math.floor(gz))
    local u,v=gx-ix,gz-iz
    local ax,az=-half+ix*step,-half+iz*step
    local a=vertexHeight(ax,az,config)
    local b=vertexHeight(ax+step,az,config)
    local c=vertexHeight(ax+step,az+step,config)
    local d=vertexHeight(ax,az+step,config)
    if u>=v then return a+(b-a)*u+(c-b)*v end
    return a+(c-d)*u+(d-a)*v
end
local function wedge(parent,size,frame,color)
    local part=Instance.new('WedgePart')
    part.Name='SandSlope';part.Size=size;part.CFrame=frame
    part.Color=color;part.Material=Enum.Material.Sand
    part.Anchored=true;part.CanCollide=true;part.CanQuery=true;part.CanTouch=false
    part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
    part:SetAttribute('QCSeabed',true)
    part.Parent=parent
end
local function triangle(parent,a,b,c,color)
    local ab,ac,bc=b-a,c-a,c-b
    if ab:Dot(ab)>ac:Dot(ac) and ab:Dot(ab)>bc:Dot(bc) then c,a=a,c
    elseif ac:Dot(ac)>bc:Dot(bc) and ac:Dot(ac)>ab:Dot(ab) then a,b=b,a end
    ab,ac,bc=b-a,c-a,c-b
    local right=ac:Cross(ab).Unit
    local back=bc.Unit
    local up=back:Cross(right).Unit
    local normal=right.Y>=0 and right or -right
    -- Both half-prisms sit below the same authored triangle; their upward
    -- face is exactly the height function, not thickness/2 above the floor.
    local shift=-normal*(THICKNESS*.5)
    local height=math.abs(ab:Dot(up))
    local first,second=math.abs(ab:Dot(back)),math.abs(ac:Dot(back))
    if first>.001 then wedge(parent,Vector3.new(THICKNESS,height,first),CFrame.fromMatrix((a+b)*.5+shift,right,up,back),color) end
    if second>.001 then wedge(parent,Vector3.new(THICKNESS,height,second),CFrame.fromMatrix((a+c)*.5+shift,-right,up,-back),color) end
end
local function fingerprint(config,theme)
    local s=config.Seabed
    local fields={VERSION,tostring(Reefs.Version),tostring(theme.Version),tostring(config.Ocean.HalfExtent),tostring(config.Ocean.SurfaceY),
        tostring(s.CellSize),tostring(s.MinDepth),tostring(s.MaxDepth),tostring(s.ReefPatchesPerIsland)}
    for _,island in ipairs(config.Islands) do
        table.insert(fields,table.concat({island.Id,tostring(island.X),tostring(island.Z),tostring(island.Radius),island.Theme},':'))
    end
    return table.concat(fields,'|')
end
function Ocean.Apply(workspace,config,theme)
    local old=workspace:FindFirstChild('QuietCoveSeabed')
    if old and old:GetAttribute('QCOceanFloor')~=true then return nil end
    if not config.Seabed.Enabled then
        if old then old:Destroy() end
        return nil
    end
    local key=fingerprint(config,theme)
    if old and old:GetAttribute('SeabedVersion')==key then return old end
    local model=Instance.new('Model');model.Name='QuietCoveSeabed'
    model:SetAttribute('QCOceanFloor',true);model:SetAttribute('SeabedVersion',key)
    local floor=Instance.new('Folder');floor.Name='Sand';floor.Parent=model
    local half,cells,step=dimensions(config)
    local vertices={}
    for ix=0,cells do
        vertices[ix]={}
        for iz=0,cells do
            local x,z=-half+ix*step,-half+iz*step
            vertices[ix][iz]=Vector3.new(x,vertexHeight(x,z,config),z)
        end
    end
    for ix=0,cells-1 do
        for iz=0,cells-1 do
            local a,b,c,d=vertices[ix][iz],vertices[ix+1][iz],vertices[ix+1][iz+1],vertices[ix][iz+1]
            local variation=(math.sin((a.X+a.Z)/620)+1)*.025
            local color=theme.Palette.Sand:Lerp(theme.Palette.Cream,variation)
            triangle(floor,a,b,c,color);triangle(floor,a,c,d,color)
        end
    end
    local ok,reason=pcall(function()
        Reefs.Build(model,config,theme,function(x,z) return Ocean.HeightAt(x,z,config) end)
    end)
    if not ok then model:Destroy();error(reason,0) end
    if old then old:Destroy() end
    model.Parent=workspace
    return model
end
return Ocean
