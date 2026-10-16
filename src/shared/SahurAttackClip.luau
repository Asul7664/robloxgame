-- Authored, deterministic heavy-club clip for assets/creatures/SahurBoss.rbxm.
-- This imported R15 splits the SAME rigid club across three arm meshes. Until
-- the mesh is re-rigged, elbow/wrist MUST stay neutral: bending either tears it.
-- Rotation comes from the shoulder, thorax and planted body weight instead.
local Clip = {}
local CF, V = CFrame, Vector3
local IDENTITY = CF.new()
local JOINTS = {
    'Root', 'Waist', 'Neck', 'RightShoulder', 'RightElbow', 'RightWrist',
    'LeftShoulder', 'LeftElbow', 'LeftWrist', 'RightHip', 'RightKnee',
    'RightAnkle', 'LeftHip', 'LeftKnee', 'LeftAnkle',
}
Clip.Joints = JOINTS

local function channel(x,y,z,px,py,pz)
    return {x or 0,y or 0,z or 0,px or 0,py or 0,pz or 0}
end
local function pose(root, waist, shoulder, leftShoulder, leftElbow, leftWrist)
    return {
        Root = root, Waist = waist,
        -- Counter-rotate the neck so the head watches the locked opponent.
        Neck = channel(-waist[1]*.72,-waist[2]*.92,-waist[3]*.65),
        RightShoulder = shoulder, RightElbow = channel(), RightWrist = channel(),
        LeftShoulder = leftShoulder, LeftElbow = leftElbow, LeftWrist = leftWrist,
    }
end
local REST = pose(channel(),channel(),channel(-2,0,2),channel(-3,0,-3),channel(3),channel())

-- Named poses are useful in Animation Editor; runtime interpolation uses
-- monotone cubic tangents, retaining speed THROUGH contact rather than easing
-- to a stop at every pose. Times are fractions of the server-owned phases.
local AUTHORED = {
    {Name='Ready', Phase='Windup', Fraction=0, Channels=REST},
    {Name='Plant', Phase='Windup', Fraction=.18, Channels=pose(
        channel(0,0,0,.055,-.10,.045), channel(-3,-5,-1), channel(15,-8,10),
        channel(8,7,-18), channel(18), channel(-4,0,-4))},
    {Name='RearFootLoad', Phase='Windup', Fraction=.52, Channels=pose(
        channel(0,0,0,.10,-.25,.09), channel(-7,-23,-3), channel(90,-22,18),
        channel(16,14,-32), channel(41), channel(-9,3,-8))},
    {Name='ClubBehindShoulder', Phase='Windup', Fraction=.82, Channels=pose(
        channel(0,0,0,.09,-.23,.075), channel(-8,-35,-4), channel(145,-26,20),
        channel(10,11,-36), channel(53), channel(-12,6,-8))},
    {Name='ContactStarts', Phase='Strike', Fraction=0, Channels=pose(
        channel(0,0,0,.015,-.25,-.065), channel(3,-8,1), channel(100,-10,5),
        channel(-20,-12,-28), channel(47), channel(-3,-3,-5))},
    {Name='ContactCrosses', Phase='Strike', Fraction=.45, Channels=pose(
        channel(0,0,0,-.075,-.29,-.16), channel(11,23,4), channel(43,8,-10),
        channel(-34,-20,-25), channel(36), channel(4,-7,-3))},
    {Name='ContactEnds', Phase='Recovery', Fraction=0, Channels=pose(
        channel(0,0,0,-.095,-.29,-.16), channel(14,36,5), channel(10,24,-20),
        channel(-36,-24,-20), channel(30), channel(7,-8,-3))},
    {Name='ClubMomentum', Phase='Recovery', Fraction=.19, Channels=pose(
        channel(0,0,0,-.08,-.26,-.11), channel(13,39,5), channel(0,35,-65),
        channel(-30,-24,-18), channel(28), channel(7,-8,-3))},
    {Name='RecoverWeight', Phase='Recovery', Fraction=.65, Channels=pose(
        channel(0,0,0,-.025,-.12,-.025), channel(4,11,1), channel(8,12,-8),
        channel(-12,-9,-10), channel(15), channel(2,-3,-1))},
    {Name='ReadyAgain', Phase='Recovery', Fraction=1, Channels=REST},
}

-- Exact imported C0/C1 positional baselines (all native rotations are identity).
-- A two-bone solve keeps the ORIGINAL ankle positions and sole rotations fixed
-- while the authored pelvis loads the rear foot and shifts into the strike.
-- This avoids floating feet, disconnected translated hips or compensating by
-- moving HumanoidRootPart. The clip never changes world movement itself.
local ROOT0 = CF.new(0,-2.4554749,0)
local ROOT1 = CF.new(.006790161,-.11958313,-.033615112)
local BASE_PELVIS = ROOT0*ROOT1:Inverse()
local LEGS = {
    Right={Hip=V.new(.6817169,-.32556152,-.07803345),
        Upper=V.new(-.062240596,-1.68817144,.13142395),
        Lower=V.new(-.008270262,-2.0950012,.1230468716)},
    Left={Hip=V.new(-.6715851,-.35662842,-.0015411377),
        Upper=V.new(-.017074583,-1.7191925,.07774353),
        Lower=V.new(-.0242919924,-2.04716487,.0961456303)},
}
local function rotateBetween(a,b)
    a,b=a.Unit,b.Unit
    local cross=a:Cross(b)
    if cross.Magnitude<1e-7 then return IDENTITY end
    return CF.fromAxisAngle(cross.Unit,math.atan2(cross.Magnitude,a:Dot(b)))
end
local function flatten(vector,normal)
    local flat=vector-normal*vector:Dot(normal)
    return flat.Magnitude>1e-7 and flat.Unit or V.xAxis
end
local function plantFeet(out)
    local pelvis=ROOT0*out.Root*ROOT1:Inverse()
    local load=math.clamp(-out.Root.Position.Y/.18,0,1)
    load=load*load*(3-2*load)
    for side,rig in pairs(LEGS) do
        local h=pelvis:PointToWorldSpace(rig.Hip)
        local ankle=BASE_PELVIS:PointToWorldSpace(rig.Hip+rig.Upper+rig.Lower)
        local delta=ankle-h
        local direction=delta.Unit
        local l1,l2=rig.Upper.Magnitude,rig.Lower.Magnitude
        local distance=math.clamp(delta.Magnitude,math.abs(l1-l2)+1e-6,l1+l2-1e-7)
        local reach=(l1*l1-l2*l2+distance*distance)/(2*distance)
        local elevation=math.sqrt(math.max(0,l1*l1-reach*reach))
        -- Rotate the native bend plane smoothly into a forward-facing knee.
        -- At zero load the exact original pose is retained, including this
        -- asset's small sideways rest bend rather than assuming vertical bones.
        local pole=flatten(rig.Upper, (rig.Upper+rig.Lower).Unit)
        pole=flatten(pole,direction)
        local forward=flatten(-V.zAxis,direction)
        local swivel=math.atan2(direction:Dot(pole:Cross(forward)),pole:Dot(forward))
        pole=CF.fromAxisAngle(direction,swivel*load):VectorToWorldSpace(pole)
        local knee=h+direction*reach+pole*elevation
        local upper=rotateBetween(rig.Upper,knee-h)
        local lower=rotateBetween(rig.Lower,ankle-knee)
        out[side..'Hip']=pelvis.Rotation:Inverse()*upper
        out[side..'Knee']=upper:Inverse()*lower
        out[side..'Ankle']=lower:Inverse()
    end
    return out
end

local function timing(settings)
    local wind=settings.Windup
    local strike=settings.Strike
    local recovery=settings.Recovery
    return wind,strike,recovery,wind+strike+recovery
end
local cachedSettings,cachedFrames,cachedTimes
local function frames(settings)
    -- Cache only immutable phase lengths, never any game state or wall time.
    local wind,strike,recovery=timing(settings)
    local signature=tostring(wind)..'/'..tostring(strike)..'/'..tostring(recovery)
    if cachedSettings==signature then return cachedFrames,cachedTimes end
    local times={}
    for index,key in AUTHORED do
        times[index]=key.Phase=='Windup' and key.Fraction*wind
            or key.Phase=='Strike' and wind+key.Fraction*strike
            or wind+strike+key.Fraction*recovery
    end
    cachedSettings,cachedFrames,cachedTimes=signature,AUTHORED,times
    return AUTHORED,times
end
local function value(key,joint,axis)
    local values=key.Channels[joint]
    return values and values[axis] or 0
end
local function tangent(keys,times,index,joint,axis)
    if index==1 or index==#keys then return 0 end
    local previous=(value(keys[index],joint,axis)-value(keys[index-1],joint,axis))/(times[index]-times[index-1])
    local next=(value(keys[index+1],joint,axis)-value(keys[index],joint,axis))/(times[index+1]-times[index])
    if previous*next<=0 then return 0 end
    -- Limited harmonic mean retains continuous velocity without spline overshoot.
    return 2*previous*next/(previous+next)
end
local function evaluate(elapsed,settings)
    local keys,times=frames(settings)
    local _,_,_,duration=timing(settings)
    elapsed=math.clamp(elapsed,0,duration)
    local index=1
    while index<#keys-1 and elapsed>times[index+1] do index+=1 end
    local dt=times[index+1]-times[index]
    local t=math.clamp((elapsed-times[index])/dt,0,1)
    local t2,t3=t*t,t*t*t
    local h00,h10,h01,h11=2*t3-3*t2+1,t3-2*t2+t,-2*t3+3*t2,t3-t2
    local out={}
    for _,joint in JOINTS do
        local channels={}
        for axis=1,6 do
            channels[axis]=h00*value(keys[index],joint,axis)
                +h10*dt*tangent(keys,times,index,joint,axis)
                +h01*value(keys[index+1],joint,axis)
                +h11*dt*tangent(keys,times,index+1,joint,axis)
        end
        out[joint]=CF.new(channels[4],channels[5],channels[6])
            *CF.Angles(math.rad(channels[1]),math.rad(channels[2]),math.rad(channels[3]))
    end
    return plantFeet(out)
end

function Clip.Sample(elapsed,settings)
    return evaluate(elapsed,settings)
end
function Clip.ContactWindow(settings)
    return settings.Windup,settings.Windup+settings.Strike
end
function Clip.Duration(settings)
    return select(4,timing(settings))
end
-- Bake the exact runtime curve into editable Animation Editor keyframes. A
-- dense linear bake preserves Hermite speed and planted IK between named poses
-- without depending on an uploaded animation or a second animation definition.
function Clip.Keyframes(settings,sampleRate)
    local _,times=frames(settings)
    local duration=Clip.Duration(settings)
    local entries={}
    for index,key in AUTHORED do entries[times[index]]=key.Name end
    local count=math.ceil(duration*(sampleRate or 120))
    for index=0,count do
        local time=duration*index/count
        if entries[time]==nil then entries[time]='Curve'..index end
    end
    local result={}
    for time,name in pairs(entries) do
        table.insert(result,{Name=name,Time=time,Pose=evaluate(time,settings),
            EasingStyle='Linear',EasingDirection='InOut'})
    end
    table.sort(result,function(a,b) return a.Time<b.Time end)
    return result
end
return Clip
