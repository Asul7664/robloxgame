-- A continuous sand heightfield below our existing Terrain water. Nothing
-- writes/clears Terrain, and the owned subtree is replaceable without islands.
local Reefs=require(script.Parent:WaitForChild('ReefScenery'))
local Ocean={}
local VERSION='sand-heightfield-2'
local THICKNESS=1
local plans=setmetatable({},{__mode='k'})
local function smooth(t)
    t=math.clamp(t,0,1)
    return t*t*(3-2*t)
end
local function geometryKey(config)
    local s=config.Seabed
    local key={tostring(config.Ocean.HalfExtent),tostring(config.Ocean.SurfaceY),tostring(s.CellSize),
        tostring(s.DetailCellSize or 64),tostring(s.DetailRadius or 200),tostring(s.MinDepth),tostring(s.MaxDepth)}
    for _,island in ipairs(config.Islands) do
        table.insert(key,table.concat({tostring(island.X),tostring(island.Z),tostring(island.Radius)},':'))
    end
    return table.concat(key,'|')
end
local function rawHeight(x,z,config)
    local s=config.Seabed
    local depth=19+math.sin(x/440)*2.4+math.cos(z/570)*2.0+math.sin((x+z)/730)*1.5
    local strongest,coastal=0,depth
    for index,island in ipairs(config.Islands) do
        local dx,dz=x-island.X,z-island.Z
        local distance=math.sqrt(dx*dx+dz*dz)
        local weight=1-smooth((distance-island.Radius-135)/140)
        if weight>strongest then
            strongest=weight
            -- The old 256-stud grid averaged away its tiny coastal variation.
            -- These broad dunes have 10–16 studs of local relief over a short
            -- swim, resolved by the fine coastal grid below.
            coastal=18+5.7*math.sin(dx/34+index*.45)*math.cos(dz/39-index*.31)
                +2.7*math.sin((dx+dz)/25+index*.63)
        end
    end
    depth=depth+(coastal-depth)*strongest
    local minimum=math.clamp(s.MinDepth,10,26)
    local maximum=math.clamp(s.MaxDepth,minimum,26)
    return config.Ocean.SurfaceY-math.clamp(depth,minimum,maximum)
end
local function planFor(config)
    local key=geometryKey(config)
    local old=plans[config]
    if old and old.Key==key then return old end
    local s=config.Seabed
    local half=config.Ocean.HalfExtent+100
    local cells=math.max(1,math.ceil(half*2/math.clamp(s.CellSize,128,512)))
    local step=half*2/cells
    local plan={Key=key,Half=half,Cells=cells,Step=step,
        Divisions=math.clamp(math.ceil(step/math.clamp(s.DetailCellSize or 64,48,128)),2,8),
        Fine={},Nodes={},DetailCount=0,Config=config}
    for ix=0,cells-1 do
        plan.Fine[ix]={};plan.Nodes[ix]={}
        for iz=0,cells-1 do
            local x,z=-half+ix*step,-half+iz*step
            local fine=false
            for _,island in ipairs(config.Islands) do
                local dx=island.X-math.clamp(island.X,x,x+step)
                local dz=island.Z-math.clamp(island.Z,z,z+step)
                if dx*dx+dz*dz<=(island.Radius+math.clamp(s.DetailRadius or 200,100,300))^2 then fine=true;break end
            end
            plan.Fine[ix][iz]=fine;plan.Nodes[ix][iz]={}
            if fine then plan.DetailCount+=1 end
        end
    end
    plans[config]=plan
    return plan
end
local function fineAt(plan,ix,iz)
    return plan.Fine[ix] and plan.Fine[ix][iz] or false
end
local function point(plan,ix,iz,sx,sz)
    local n=plan.Fine[ix][iz] and plan.Divisions or 1
    local key=sx*(n+1)+sz
    local cached=plan.Nodes[ix][iz][key]
    if cached then return cached end
    local x0,z0=-plan.Half+ix*plan.Step,-plan.Half+iz*plan.Step
    local u,v=sx/n,sz/n
    local x,z=x0+u*plan.Step,z0+v*plan.Step
    local y=rawHeight(x,z,plan.Config)
    -- A fine edge bordering a coarse cell must lie on that cell's straight
    -- edge, rather than adding unmatched intermediate peaks (T-junction gaps).
    if n>1 then
        if (sx==0 and not fineAt(plan,ix-1,iz)) or (sx==n and not fineAt(plan,ix+1,iz)) then
            local a,b=rawHeight(x,z0,plan.Config),rawHeight(x,z0+plan.Step,plan.Config)
            y=a+(b-a)*v
        elseif (sz==0 and not fineAt(plan,ix,iz-1)) or (sz==n and not fineAt(plan,ix,iz+1)) then
            local a,b=rawHeight(x0,z,plan.Config),rawHeight(x0+plan.Step,z,plan.Config)
            y=a+(b-a)*u
        end
    end
    local value=Vector3.new(x,y,z)
    plan.Nodes[ix][iz][key]=value
    return value
end
function Ocean.HeightAt(x,z,config)
    local plan=planFor(config)
    local gx=math.clamp((x+plan.Half)/plan.Step,0,plan.Cells)
    local gz=math.clamp((z+plan.Half)/plan.Step,0,plan.Cells)
    local ix,iz=math.min(plan.Cells-1,math.floor(gx)),math.min(plan.Cells-1,math.floor(gz))
    local n=plan.Fine[ix][iz] and plan.Divisions or 1
    local su,sv=(gx-ix)*n,(gz-iz)*n
    local sx,sz=math.min(n-1,math.floor(su)),math.min(n-1,math.floor(sv))
    local u,v=su-sx,sv-sz
    local a,b,c,d=point(plan,ix,iz,sx,sz).Y,point(plan,ix,iz,sx+1,sz).Y,
        point(plan,ix,iz,sx+1,sz+1).Y,point(plan,ix,iz,sx,sz+1).Y
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
        tostring(s.CellSize),tostring(s.DetailCellSize or 64),tostring(s.DetailRadius or 200),tostring(s.MinDepth),tostring(s.MaxDepth),tostring(s.ReefPatchesPerIsland)}
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
    local plan=planFor(config)
    model:SetAttribute('DetailCells',plan.DetailCount)
    for ix=0,plan.Cells-1 do
        for iz=0,plan.Cells-1 do
            local n=plan.Fine[ix][iz] and plan.Divisions or 1
            for sx=0,n-1 do
                for sz=0,n-1 do
                    local a,b,c,d=point(plan,ix,iz,sx,sz),point(plan,ix,iz,sx+1,sz),
                        point(plan,ix,iz,sx+1,sz+1),point(plan,ix,iz,sx,sz+1)
                    local depth=config.Ocean.SurfaceY-(a.Y+b.Y+c.Y+d.Y)*.25
                    local variation=math.clamp((depth-10)/16,0,1)
                    local color=theme.Palette.Sand:Lerp(theme.Palette.Cream,(1-variation)*.2)
                        :Lerp(theme.Palette.Rock,variation*.16)
                    triangle(floor,a,b,c,color);triangle(floor,a,c,d,color)
                end
            end
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
