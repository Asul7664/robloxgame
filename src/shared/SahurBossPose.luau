-- R15 offsets only. The server owns movement, contact and the one arrival leap.
local Pose = {}
local IDENTITY = CFrame.new()
local TAU = math.pi * 2
local JOINTS = {
    'Root', 'Waist', 'Neck', 'RightShoulder', 'RightElbow', 'RightWrist',
    'LeftShoulder', 'LeftElbow', 'LeftWrist', 'RightHip', 'RightKnee',
    'RightAnkle', 'LeftHip', 'LeftKnee', 'LeftAnkle',
}
local function smooth(t)
    t = math.clamp(t, 0, 1)
    return t*t*(3-2*t)
end
local function angle(x,y,z)
    return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end
local function blend(a,b,t)
    local out = {}
    for _, name in JOINTS do
        out[name] = (a[name] or IDENTITY):Lerp(b[name] or IDENTITY,t)
    end
    return out
end
local function idle(now)
    local breath = math.sin(now*1.7)
    return {
        Root=CFrame.new(0,breath*.008,0), Waist=angle(breath*.45,0,0),
        Neck=angle(-breath*.3,0,0), RightShoulder=angle(-2,0,2),
        RightElbow=angle(5,0,0), LeftShoulder=angle(-3,0,-3),
        LeftElbow=angle(3,0,0),
    }
end
-- Each foot supports the body for 62% of the cycle. Knees flex backwards
-- during the return; ankle counter-rotation keeps the support foot level.
local function leg(phase)
    local cycle = phase/TAU % 1
    local hip,knee,roll
    if cycle < .62 then
        local t = cycle/.62
        -- Nearly linear backward foot travel while planted. A sine-driven
        -- hip would pause at each end and visibly slide against ground motion.
        hip = math.deg(math.asin(math.sin(math.rad(24))*(1-2*t)))
        knee = -4-8*smooth(t)-8*math.sin(math.pi*t)^2
        roll = 8*(1-smooth(t/.18))-16*smooth((t-.70)/.30)
    else
        local t = (cycle-.62)/.38
        local contactSlope=-2*math.tan(math.rad(24))*180/math.pi*.38/.62
        hip = -24+48*smooth(t)+contactSlope*t*(1-t)*(1-2*t)
        knee = -(12-8*smooth(t)+48*math.sin(math.pi*t)^2)
        roll = -16+24*smooth(t)
    end
    return hip,knee,math.clamp(-hip-knee+roll,-28,42)
end
local function walk(phase)
    local rightHip,rightKnee,rightAnkle = leg(phase)
    local leftHip,leftKnee,leftAnkle = leg(phase+math.pi)
    local transfer = math.sin(phase)
    -- Lower the pelvis over the loaded, bent support leg. This small native
    -- rig compensation prevents mid/late-stance feet hovering over the deck.
    local loadedDrop=.16*math.max(0,math.cos(phase*2-math.pi*1.6))
    return {
        Root=CFrame.new(transfer*.085,-.05-.028*math.cos(phase*2)-loadedDrop,0)
            *angle(0,transfer*2,-transfer*1.6),
        Waist=angle(3,-transfer*4,transfer*1.2),
        Neck=angle(-2,transfer*2,-transfer*.5),
        RightHip=angle(rightHip,0,transfer*.6), LeftHip=angle(leftHip,0,transfer*.6),
        RightKnee=angle(rightKnee,0,0), LeftKnee=angle(leftKnee,0,0),
        RightAnkle=angle(rightAnkle,0,0), LeftAnkle=angle(leftAnkle,0,0),
        -- The loaded bat arm swings less; the free arm balances the stride.
        RightShoulder=angle(-rightHip*.27,transfer*2,4),
        LeftShoulder=angle(-leftHip*.55,-transfer*3,-5),
        RightElbow=angle(8+math.max(0,-rightHip)*.2,0,0),
        LeftElbow=angle(9+math.max(0,-leftHip)*.45,0,0),
        RightWrist=angle(0,0,-transfer*1.5), LeftWrist=angle(-3,transfer*2,0),
    }
end
local WIND = {
    Root=CFrame.new(.07,-.18,.05)*angle(-3,-5,-2),
    RightShoulder=angle(-128,-28,22), RightElbow=angle(42,0,0),
    RightWrist=angle(-12,5,12), LeftShoulder=angle(24,16,-24),
    LeftElbow=angle(38,0,0), LeftWrist=angle(-8,0,-8),
    Waist=angle(-8,-30,-5), Neck=angle(5,25,3),
    RightHip=angle(-7,5,2), LeftHip=angle(11,-5,-2),
    RightKnee=angle(-13,0,0), LeftKnee=angle(-9,0,0),
    RightAnkle=angle(20,0,0), LeftAnkle=angle(-2,0,0),
}
local CONTACT = {
    Root=CFrame.new(-.05,-.23,-.13)*angle(3,4,2),
    RightShoulder=angle(32,24,-12), RightElbow=angle(8,0,0),
    RightWrist=angle(15,-6,-8), LeftShoulder=angle(-24,-18,-32),
    LeftElbow=angle(27,0,0), LeftWrist=angle(5,0,-4),
    Waist=angle(14,25,6), Neck=angle(-10,-18,-3),
    RightHip=angle(9,4,2), LeftHip=angle(-8,-4,-2),
    RightKnee=angle(-12,0,0), LeftKnee=angle(-16,0,0),
    RightAnkle=angle(3,0,0), LeftAnkle=angle(24,0,0),
}
local FOLLOW = {
    Root=CFrame.new(-.07,-.25,-.12)*angle(4,5,2),
    RightShoulder=angle(56,37,-22), RightElbow=angle(15,0,0),
    RightWrist=angle(20,-8,-10), LeftShoulder=angle(-30,-20,-25),
    LeftElbow=angle(29,0,0), LeftWrist=angle(5,0,-4),
    Waist=angle(18,33,7), Neck=angle(-12,-24,-4),
    RightHip=angle(10,5,2), LeftHip=angle(-9,-5,-2),
    RightKnee=angle(-14,0,0), LeftKnee=angle(-18,0,0),
    RightAnkle=angle(4,0,0), LeftAnkle=angle(27,0,0),
}
local COIL = {
    Root=CFrame.new(0,-.38,0), Waist=angle(10,0,0), Neck=angle(-8,0,0),
    RightHip=angle(26,0,3), LeftHip=angle(23,0,-3),
    RightKnee=angle(-49,0,0), LeftKnee=angle(-46,0,0),
    RightAnkle=angle(23,0,0), LeftAnkle=angle(23,0,0),
    RightShoulder=angle(-28,0,17), LeftShoulder=angle(-35,0,-20),
    RightElbow=angle(16,0,0), LeftElbow=angle(28,0,0),
}
local TUCK = {
    Root=CFrame.new(0,-.05,0), Waist=angle(-7,0,0), Neck=angle(5,0,0),
    RightHip=angle(40,0,5), LeftHip=angle(32,0,-5),
    RightKnee=angle(-68,0,0), LeftKnee=angle(-58,0,0),
    RightAnkle=angle(20,0,0), LeftAnkle=angle(19,0,0),
    RightShoulder=angle(-65,-12,23), LeftShoulder=angle(48,0,-32),
    RightElbow=angle(30,0,0), LeftElbow=angle(52,0,0),
    RightWrist=angle(-8,0,8), LeftWrist=angle(-8,0,-8),
}
local BRACE = {
    Root=CFrame.new(0,-.18,0), Waist=angle(7,0,0), Neck=angle(-5,0,0),
    RightHip=angle(14,0,4), LeftHip=angle(14,0,-4),
    RightKnee=angle(-26,0,0), LeftKnee=angle(-26,0,0),
    RightAnkle=angle(12,0,0), LeftAnkle=angle(12,0,0),
    RightShoulder=angle(-18,0,18), LeftShoulder=angle(18,0,-26),
    RightElbow=angle(14,0,0), LeftElbow=angle(26,0,0),
}
local LAND = {
    Root=CFrame.new(0,-.58,-.04), Waist=angle(16,0,0), Neck=angle(-11,0,0),
    RightHip=angle(30,0,5), LeftHip=angle(30,0,-5),
    RightKnee=angle(-57,0,0), LeftKnee=angle(-57,0,0),
    RightAnkle=angle(27,0,0), LeftAnkle=angle(27,0,0),
    RightShoulder=angle(-12,0,24), LeftShoulder=angle(26,0,-33),
    RightElbow=angle(22,0,0), LeftElbow=angle(40,0,0),
}
-- Optional motion is supplied from actual root velocity; the four-argument
-- form remains valid for existing preview and deterministic callers.
function Pose.Sample(now, attackAt, moving, settings, motion)
    motion = motion or {}
    local rest = idle(now)
    if motion.Emerging and type(motion.SpawnAt)=='number' then
        local t=math.clamp((now-motion.SpawnAt)/settings.RiseTime,0,1)
        if t<.38 then return blend(COIL,TUCK,smooth(t/.38)) end
        return blend(TUCK,BRACE,smooth((t-.38)/.62))
    end
    local landed=type(motion.LandingAt)=='number' and now-motion.LandingAt or -1
    local landingRecovery=settings.LandingRecovery or .24
    if landed>=0 and landed<landingRecovery then
        local t=landed/landingRecovery
        if t<.30 then return blend(BRACE,LAND,smooth(t/.30)) end
        return blend(LAND,rest,smooth((t-.30)/.70))
    end
    local elapsed=type(attackAt)=='number' and now-attackAt or -1
    local duration=settings.Windup+settings.Strike+settings.Recovery
    if elapsed>=0 and elapsed<duration then
        -- Contact matches server damage at Windup. The fast final downswing
        -- finishes there, then the bat follows through and decelerates.
        local draw=settings.Windup*.73
        if elapsed<draw then return blend(rest,WIND,smooth(elapsed/draw)) end
        if elapsed<settings.Windup then
            return blend(WIND,CONTACT,smooth((elapsed-draw)/(settings.Windup-draw)))
        end
        if elapsed<settings.Windup+settings.Strike then
            return blend(CONTACT,FOLLOW,smooth((elapsed-settings.Windup)/settings.Strike))
        end
        return blend(FOLLOW,rest,smooth((elapsed-settings.Windup-settings.Strike)/settings.Recovery))
    end
    local weight=motion.Weight
    if type(weight)~='number' then weight=moving and 1 or 0 end
    local phase=type(motion.Phase)=='number' and motion.Phase or now*8.1
    return blend(rest,walk(phase),math.clamp(weight,0,1))
end
return Pose
