-- Server-side forward kinematics of the ORIGINAL imported rig. These capsule
-- markers were fitted to its embedded physical hulls, not its misleading R15
-- wrist/grip (the auto-rigger split the bat itself into three arm meshes).
local Club = {}
local IDENTITY = CFrame.new()
local MARKERS = {
    {Part='RightLowerArm', A=Vector3.new(-.701247,1.321459,.710923),
        B=Vector3.new(.556049,-1.162436,-.479218), Radius=.45676},
    {Part='RightHand', A=Vector3.new(-.337078,.577097,.311359),
        B=Vector3.new(.266139,-.614610,-.259639), Radius=.49267},
}
function Club.Capture(model)
    local root=model:FindFirstChild('HumanoidRootPart')
    if not root then return nil end
    local rig={Root=root, Joints={}, Parts={}}
    for _,item in model:GetDescendants() do
        if item:IsA('Motor6D') and item.Part0 and item.Part1 then
            rig.Joints[item.Part1]={Name=item.Name, Parent=item.Part0, C0=item.C0, C1=item.C1:Inverse()}
        end
    end
    for _,marker in MARKERS do
        local part=model:FindFirstChild(marker.Part)
        if not part or not rig.Joints[part] then return nil end
        table.insert(rig.Parts,{Part=part,Marker=marker})
    end
    -- Refuse a broken/incompatible skeleton rather than falling back to an
    -- invisible front cone. The original model has exactly this complete chain.
    for _,entry in rig.Parts do
        local part,seen=entry.Part,{}
        while part~=root do
            if seen[part] or not rig.Joints[part] then return nil end
            seen[part]=true;part=rig.Joints[part].Parent
        end
    end
    return rig
end
function Club.Segments(rig,rootFrame,pose)
    local cache={[rig.Root]=rootFrame}
    local function frame(part)
        if not cache[part] then
            local joint=rig.Joints[part]
            cache[part]=frame(joint.Parent)*joint.C0*(pose[joint.Name] or IDENTITY)*joint.C1
        end
        return cache[part]
    end
    local result={}
    for _,entry in rig.Parts do
        local cf,marker=frame(entry.Part),entry.Marker
        table.insert(result,{A=cf:PointToWorldSpace(marker.A),B=cf:PointToWorldSpace(marker.B),Radius=marker.Radius})
    end
    return result
end
-- Exact closest points between a segment and an oriented box. In box space,
-- squared distance is a convex, piecewise quadratic function of segment time.
-- Solve each interval between crossings of the six box planes; no oversized
-- character sphere or padded cube corner can turn a nearby miss into a hit.
local function nearest(a,b,part)
    local start=part.CFrame:PointToObjectSpace(a)
    local finish=part.CFrame:PointToObjectSpace(b)
    local delta=finish-start
    local half=part.Size*.5
    local starts,changes,extents={start.X,start.Y,start.Z},{delta.X,delta.Y,delta.Z},{half.X,half.Y,half.Z}
    local cuts={0,1}
    for axis=1,3 do
        if math.abs(changes[axis])>1e-9 then
            for _,sign in {-1,1} do
                local t=(sign*extents[axis]-starts[axis])/changes[axis]
                if t>0 and t<1 then table.insert(cuts,t) end
            end
        end
    end
    table.sort(cuts)
    local best,tBest=math.huge,0
    local function evaluate(t)
        local p=start+delta*t
        local q=Vector3.new(math.clamp(p.X,-half.X,half.X),math.clamp(p.Y,-half.Y,half.Y),math.clamp(p.Z,-half.Z,half.Z))
        local d=(p-q):Dot(p-q)
        if d<best then best=d;tBest=t end
    end
    for index=1,#cuts-1 do
        local low,high=cuts[index],cuts[index+1]
        local middle=(low+high)*.5
        local numerator,denominator=0,0
        for axis=1,3 do
            local value=starts[axis]+changes[axis]*middle
            if math.abs(value)>extents[axis] then
                local outside=starts[axis]-(value>0 and extents[axis] or -extents[axis])
                numerator+=changes[axis]*outside;denominator+=changes[axis]^2
            end
        end
        evaluate(low);evaluate(high)
        if denominator>1e-12 then evaluate(math.clamp(-numerator/denominator,low,high)) end
    end
    local point=start+delta*tBest
    local boxPoint=Vector3.new(math.clamp(point.X,-half.X,half.X),math.clamp(point.Y,-half.Y,half.Y),math.clamp(point.Z,-half.Z,half.Z))
    return best,part.CFrame:PointToWorldSpace(boxPoint)
end
function Club.Contact(previous,current,character)
    for _,part in character:GetChildren() do
        -- Real body geometry only: tools, hats and the oversized invisible root
        -- never extend a player's damage area.
        if part:IsA('BasePart') and part.Name~='HumanoidRootPart' then
            for index,segment in current do
                local old=previous[index]
                -- At <=1/120 s the short curved motion is resolved by these
                -- interpolated shaft segments and their endpoint trajectories.
                local lines={
                    {segment.A,segment.B},{old.A,segment.A},{old.B,segment.B},
                    {old.A:Lerp(segment.A,.5),old.B:Lerp(segment.B,.5)},
                }
                for _,line in lines do
                    local distance,point=nearest(line[1],line[2],part)
                    if distance<=segment.Radius^2 then return point end
                end
            end
        end
    end
    return nil
end
return Club
