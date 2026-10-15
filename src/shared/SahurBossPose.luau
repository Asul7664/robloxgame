-- Pure, clock-driven offsets; no uploaded animation IDs or imported scripts.
local Pose = {}
local function smooth(t)
    t = math.clamp(t, 0, 1)
    return t*t*(3-2*t)
end
local function angle(x,y,z)
    return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end
local WIND = {
    RightShoulder=angle(-132,-24,28), RightElbow=angle(-65,0,0),
    LeftShoulder=angle(-35,15,-20), LeftElbow=angle(-30,0,0),
    Waist=angle(-10,-28,-5), Neck=angle(7,18,0),
    RightHip=angle(12,0,0), LeftHip=angle(-12,0,0),
}
local HIT = {
    RightShoulder=angle(-28,30,-14), RightElbow=angle(-10,0,0),
    LeftShoulder=angle(-46,-12,-16), LeftElbow=angle(-20,0,0),
    Waist=angle(18,30,6), Neck=angle(-10,-15,0),
    RightHip=angle(-12,0,0), LeftHip=angle(15,0,0),
}
function Pose.Sample(now, attackAt, moving, settings)
    local out = {}
    local elapsed = attackAt and now - attackAt or -1
    local duration = settings.Windup + settings.Strike + settings.Recovery
    if elapsed >= 0 and elapsed < duration then
        local a,b,t
        if elapsed < settings.Windup then
            a,b,t={},WIND,smooth(elapsed/settings.Windup)
        elseif elapsed < settings.Windup+settings.Strike then
            a,b,t=WIND,HIT,smooth((elapsed-settings.Windup)/settings.Strike)
        else
            a,b,t=HIT,{},smooth((elapsed-settings.Windup-settings.Strike)/settings.Recovery)
        end
        for name in pairs(WIND) do
            out[name]=(a[name] or CFrame.new()):Lerp(b[name] or CFrame.new(),t)
        end
    elseif moving then
        local stride = math.sin(now*7.8)
        out.RightHip=angle(stride*22,0,0); out.LeftHip=angle(-stride*22,0,0)
        out.RightKnee=angle(math.max(0,-stride)*24,0,0)
        out.LeftKnee=angle(math.max(0,stride)*24,0,0)
        out.LeftShoulder=angle(stride*12,0,-4)
        out.RightShoulder=angle(-stride*7,0,4)
        out.Waist=angle(2,stride*4,stride*1.5)
    else
        out.Waist=angle(math.sin(now*1.8)*.6,0,0)
    end
    return out
end
return Pose
