-- One presentation clock: the release marker lives INSIDE the forward stroke.
-- Authoritative water destination/timing; no rewards and no client decisions here.
local Cast={}
local function clamp(x,a,b)return math.max(a,math.min(b,x))end
function Cast.Smooth(t)t=clamp(t,0,1);return t*t*t*(t*(t*6-15)+10)end
-- Reachable grips ahead of the body, short butt behind the right hand.
local REST={X=.15,Y=.10,Z=-1.65,Pitch=-65,Yaw=0,Roll=0,Lean=-4,Twist=0,Drop=.02,ShiftX=0,ShiftZ=0}
local function lerp(a,b,t)local out={};for k,v in pairs(a)do out[k]=v+(b[k]-v)*t end;return out end
local function charged(power)
    -- Loading stays upright/slightly forward; a backward shaft cuts through the head.
    local back={X=.25,Y=.68,Z=-1.10,Pitch=-8,Yaw=-8,Roll=0,Lean=2,Twist=-6,Drop=.03,ShiftX=.01,ShiftZ=0}
    return lerp(REST,back,Cast.Smooth(power))
end
-- Time-aware cubic Hermite spline. Internal velocities are continuous, including release.
local function spline(keys,time)
    local idx=1
    while idx<#keys-1 and time>keys[idx+1].T do idx=idx+1 end
    local a,b=keys[idx],keys[idx+1];local span=b.T-a.T
    local u=clamp((time-a.T)/span,0,1);local u2,u3=u*u,u*u*u
    local prev=keys[math.max(1,idx-1)];local after=keys[math.min(#keys,idx+2)]
    local out={}
    for k,v in pairs(a.P)do
        local m0=idx==1 and 0 or (b.P[k]-prev.P[k])/(b.T-prev.T)*0.68
        local m1=idx+1==#keys and 0 or (after.P[k]-a.P[k])/(after.T-a.T)*0.68
        out[k]=(2*u3-3*u2+1)*v+(u3-2*u2+u)*span*m0+(-2*u3+3*u2)*b.P[k]+(u3-u2)*span*m1
    end
    return out
end
function Cast.Frame(stage,elapsed,power,config)
    power=clamp(power or 0,0,1)
    local windup=config.WindupSeconds or .045
    local strokeEnd=config.StrokeEndSeconds or .34
    local out=lerp(REST,REST,0)
    if stage=='Charging' then out=charged(power)
    elseif stage=='Casting' then
        local start=charged(power)
        local load=lerp(start,start,0);load.Pitch=math.min(-3,load.Pitch+4);load.Twist=load.Twist-2
        local follow={X=.15,Y=.06,Z=-1.78,Pitch=-77,Yaw=0,Roll=0,Lean=-8,Twist=4,Drop=.04,ShiftX=0,ShiftZ=-.04}
        out=spline({{T=0,P=start},{T=windup,P=load},{T=strokeEnd,P=follow},
            {T=config.SettleSeconds or .66,P=REST}},elapsed)
    elseif stage=='Waiting' then out.Pitch=out.Pitch+math.sin(elapsed*1.55)*.85
    elseif stage=='Bite' then out.Pitch=out.Pitch+math.sin(elapsed*10)*1.4
    elseif stage=='Reeling' then out.Pitch=-61+math.sin(elapsed*3.5)*1.0;out.Lean=-6;out.Drop=.035
    elseif stage=='Landing' then out.Pitch=-52;out.Y=.22;out.Lean=-3;out.Drop=.025
    end
    out.Slash=stage=='Casting' and elapsed>=windup and elapsed<=strokeEnd+.025
    return out
end
function Cast.RodFrame(frame)
    return CFrame.new(frame.X,frame.Y,frame.Z)*CFrame.Angles(0,math.rad(frame.Yaw),0)*CFrame.Angles(math.rad(frame.Pitch),0,math.rad(frame.Roll))
end
function Cast.Release(root,tip,power,config)
    local t=config.SwingSeconds
    local before=root*Cast.RodFrame(Cast.Frame('Casting',t-.005,power,config))*tip
    local now=root*Cast.RodFrame(Cast.Frame('Casting',t,power,config))*tip
    local direction=(now-before).Magnitude>.001 and (now-before).Unit or root.LookVector
    return now,direction,(now-before)/.005
end
function Cast.Position(origin,target,t,height,direction,velocity,flight)
    t=clamp(t,0,1)
    local delta=target-origin;local length=delta.Magnitude
    local launch=direction or (delta+Vector3.new(0,height*2,0)).Unit
    local a=origin+(velocity and velocity*((flight or 1)/3)or launch*(length*.39)) -- matches tip speed at release
    local b=target-delta*.22+Vector3.new(0,height,0)
    local u=1-t
    return origin*(u*u*u)+a*(3*u*u*t)+b*(3*u*t*t)+target*(t*t*t)
end
function Cast.Timing(power,config)
    power=clamp(power,0,1)
    return config.SwingSeconds,config.FlightSeconds+power*config.ExtraFlightSeconds,config.ArcHeight+power*config.ExtraArcHeight
end
function Cast.Progress(now,started,swing,flight)return clamp((now-started-swing)/math.max(.1,flight),0,1)end
-- Legacy consumers can inspect scalar pose values, but CastingRig solves actual grip targets.
function Cast.Pose(stage,t,power,config)
    local f=Cast.Frame(stage,t,power,config)
    return {Right=76,Left=60,Twist=f.Twist,Lean=f.Lean,Elbow=30,Wrist=0,Grip=0,Slash=f.Slash}
end
return Cast
