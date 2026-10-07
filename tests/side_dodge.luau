-- lune run tests/side_dodge.luau
-- Execute real server entrypoint and client controller with deterministic engine
-- doubles. Physics here verifies horizontal constraints and free fall, not Studio visuals.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Environment = require("./helpers/server_environment")
local V, CF = roblox.Vector3, roblox.CFrame
local checks = 0
local function check(value, label) checks += 1; assert(value, label) end
local function near(a,b,tolerance,label) check(math.abs(a-b)<=tolerance,label) end

-- Requests traverse the actual Main Action handler, rate limiter and Heartbeat.
do
    local env=Environment.new();env:Start()
    local player=env:Player(9901);env.Players.PlayerAdded:Fire(player)
    local c=player.Character;local h=c.Humanoid
    env:Fire(player,"Dodge","Left",1)
    check(env:Last(player,"DodgeResult").Allowed,"Server grants a live idle character")
    check(c:GetAttribute("IFrame") and c:GetAttribute("Dodging"),"Server owns immunity and active state")
    env:Fire(player,"Dodge","Right",2)
    check(not env:Last(player,"DodgeResult").Allowed,"Reentrant dodge denied")
    env:Fire(player,"Begin")
    check(env:Last(player,"Rejected")~=nil,"Fishing cannot take movement lock during dodge")
    env:Advance(.15);check(c:GetAttribute("IFrame"),"Immunity lasts requested short window")
    env:Advance(.034);check(not c:GetAttribute("IFrame") and c:GetAttribute("Dodging"),"Immunity ends before movement")
    env:Advance(.05);check(not c:GetAttribute("Dodging"),"Active state cleared at step end")
    env:Fire(player,"Dodge","Right",3)
    check(not env:Last(player,"DodgeResult").Allowed,"Cooldown outlasts movement")
    env:Advance(.4);env:Fire(player,"Dodge","Right",4)
    check(env:Last(player,"DodgeResult").Allowed,"Next step allowed after cooldown")
    h.Health=0;h.Died:Fire()
    check(not c:GetAttribute("IFrame") and not c:GetAttribute("Dodging"),"Death clears both server attributes")
    env:Advance(1);env:Fire(player,"Dodge","Left",5)
    check(not env:Last(player,"DodgeResult").Allowed,"Dead character denied")
    env:Reset(player);c=player.Character;h=c.Humanoid
    h:SetAttribute("Stunned",true);env:Fire(player,"Dodge","Left",6)
    check(not env:Last(player,"DodgeResult").Allowed,"Stun denied")
    h:SetAttribute("Stunned",false);h.State="Swimming";env:Fire(player,"Dodge","Left",7)
    check(not env:Last(player,"DodgeResult").Allowed,"Swimming denied")
    env:Advance(.5);h.State="Running";env:Fire(player,"Begin")
    env:Fire(player,"Dodge","Left",8)
    check(not env:Last(player,"DodgeResult").Allowed,"Existing fishing session denies dodge")
    env:Reset(player);c=player.Character
    env:Advance(1);env:Fire(player,"Dodge","Left",9)
    check(env:Last(player,"DodgeResult").Allowed,"Respawn resets dodge state")
    env:Reset(player)
    check(not c:GetAttribute("IFrame"),"Respawn clears old character immunity")
    local before=#env.messages
    env:Fire(player,"Dodge",V.new(1,0,0),10)
    env:Fire(player,"Dodge","Left",0/0)
    check(#env.messages==before,"Untrusted vectors and invalid request IDs ignored")
    env:Advance(1);env:Fire(player,"Dodge","Right",11)
    c=player.Character;env:Leave(player)
    check(not c:GetAttribute("IFrame") and not c:GetAttribute("Dodging"),"Leaving clears server state")
end

local function signal()
    local s={Listeners={}}
    function s:Connect(callback)
        local e={Callback=callback,Connected=true};table.insert(self.Listeners,e)
        return {Disconnect=function()e.Connected=false end}
    end
    function s:Fire(...)
        for _,e in ipairs(table.clone(self.Listeners))do if e.Connected then e.Callback(...)end end
    end
    function s:Count()
        local n=0;for _,e in ipairs(self.Listeners)do if e.Connected then n+=1 end end;return n
    end
    return s
end
local function client(animationIDs)
    local env={Time=0,Objects={},Requests={},RayCount=0,CanUse=true,Loads=0}
    local function object(class)
        local o={ClassName=class,Children={},Attributes={},Name=class}
        function o:FindFirstChild(name)
            for _,ch in ipairs(env.Objects)do if ch.Parent==self and ch.Name==name and not ch.Destroyed then return ch end end
        end
        function o:FindFirstChildOfClass(name)
            for _,ch in ipairs(env.Objects)do if ch.Parent==self and ch.ClassName==name and not ch.Destroyed then return ch end end
        end
        function o:GetAttribute(key)return self.Attributes[key]end
        function o:SetAttribute(key,value)self.Attributes[key]=value end
        function o:GetState()return self.State or "Running"end
        function o:Destroy()self.Destroyed=true;self.Parent=nil end
        table.insert(env.Objects,o);return o
    end
    local function character()
        local c=object("Model");c.Parent={}
        local h=object("Humanoid");h.Parent=c;h.Health=100;h.WalkSpeed=19;h.AutoRotate=true;h.Died=signal()
        local r=object("Part");r.Name="HumanoidRootPart";r.Parent=c;r.CFrame=CF.new();r.Position=V.zero;r.Size=V.new(2,2,1)
        local a=object("Attachment");a.Name="RootAttachment";a.Parent=r
        local animator=object("Animator");animator.Parent=h
        function animator:LoadAnimation(animation)
            env.Loads+=1
            local t=object("AnimationTrack");t.Length=.4;t.Weights={};t.Animation=animation
            function t:Play(fade)self.PlayFade=fade end
            function t:AdjustSpeed(speed)self.Speed=speed end
            function t:AdjustWeight(weight,fade)table.insert(self.Weights,{weight,fade})end
            function t:Stop(fade)self.StopFade=fade end
            return t
        end
        return c,h,r,a
    end
    local player={CharacterAdded=signal(),CharacterRemoving=signal()}
    local c,h,r,a=character();player.Character=c
    local run={Heartbeat=signal(),PostSimulation=signal()}
    local world={GetServerTimeNow=function()return env.Time end}
    function world:Raycast(origin,vector,params)
        env.RayCount+=1
        check(params.RespectCanCollide and params.FilterDescendantsInstances[1]==player.Character,"Wall queries exclude character and respect collisions")
        if env.Wall then return {Normal=-vector.Unit}end
        return nil
    end
    local enum={HumanoidStateType={Swimming="Swimming",PlatformStanding="PlatformStanding"},
        AnimationPriority={Action="Action"},ActuatorRelativeTo={World="World"},
        VelocityConstraintMode={Vector="Vector"},ForceLimitMode={PerAxis="PerAxis"},RaycastFilterType={Exclude="Exclude"}}
    local fakeOs=table.clone(os);fakeOs.clock=function()return env.Time end
    local globals={Vector3=V,Enum=enum,os=fakeOs,workspace=world,
        game={GetService=function()return run end},Instance={new=object},RaycastParams={new=function()return {}end}}
    local settings=luau.load(fs.readFile("src/shared/SideDodge.luau"),{environment=globals})()
    if animationIDs then settings.Animations={Left="rbxassetid://123",Right="rbxassetid://456"}end
    local controller=luau.load(fs.readFile("src/client/SideDodgeController.luau"),{environment=globals})()
        .new(player,settings,function(side,id)table.insert(env.Requests,{Side=side,Id=id})end,function()return env.CanUse end)
    env.Controller,env.Player,env.Humanoid,env.Root,env.Attachment,env.Run,env.Settings=controller,player,h,r,a,run,settings
    function env:Grant()
        local req=self.Requests[#self.Requests]
        controller:Handle("DodgeResult",{Allowed=true,Id=req.Id,Side=req.Side,Character=player.Character,
            EndsAt=self.Time+settings.DASH_TIME,CooldownUntil=self.Time+settings.COOLDOWN})
    end
    function env:Tick(dt,air)
        -- Roblox integrates the previous Heartbeat target, then emits PostSimulation and Heartbeat.
        local active=controller.Active
        if active then
            local velocity=active.Velocity.VectorVelocity
            self.Root.Position+=velocity*dt
            self.Horizontal=velocity
        end
        if air then self.YVelocity=(self.YVelocity or 0)-196.2*dt;self.Y=(self.Y or 0)+self.YVelocity*dt end
        self.Time+=dt;run.PostSimulation:Fire(dt);run.Heartbeat:Fire(dt)
    end
    function env:Respawn()
        player.CharacterRemoving:Fire(player.Character)
        c,h,r,a=character();player.Character=c;player.CharacterAdded:Fire(c)
        self.Humanoid,self.Root,self.Attachment=h,r,a
    end
    return env
end

for _,fps in ipairs({30,60,120})do
    local distances={}
    for _,air in ipairs({false,true})do
        local e=client();local ctrl=e.Controller
        check(ctrl:Request("Right"),"Request is responsive")
        check(e.Player.Character:GetAttribute("LocalDodgePendingUntil")==e.Time+e.Settings.REQUEST_TIMEOUT,"Pending dodge input lock has a bounded expiry")
        check(not ctrl.Active and e.Humanoid.WalkSpeed==19,"No force or movement lock before server approval")
        e.Root.CFrame=CF.Angles(0,math.pi/2,0);e:Grant()
        local lv=ctrl.Active.Velocity
        check(e.Player.Character:GetAttribute("LocalDodgePendingUntil")==nil,"Server approval clears the pending input lock")
        check(lv.Attachment0==e.Attachment,"Standard RootAttachment reused")
        check(lv.RelativeTo=="World" and lv.VelocityConstraintMode=="Vector" and lv.ForceLimitMode=="PerAxis","Required constraint modes")
        check(lv.MaxAxesForce==V.new(60000,0,60000),"Finite horizontal force, zero vertical force")
        check(e.Humanoid.WalkSpeed==0 and not e.Humanoid.AutoRotate,"Walk and rotation locked only during step")
        check(e.Player.Character:GetAttribute("LocalDodgeActive")==true,"Local movement flag coordinates weapon camera")
        check(not ctrl:Request("Left"),"No overlapping client movement")
        for _=1,math.ceil(.35*fps)do e:Tick(1/fps,air)end
        check(not ctrl.Active and lv.Destroyed,"Constraint cleaned after step")
        check(e.Run.Heartbeat:Count()==0 and e.Run.PostSimulation:Count()==0,"Both frame connections cleaned")
        check(e.Humanoid.WalkSpeed==19 and e.Humanoid.AutoRotate,"Captured movement settings restored")
        check(e.Player.Character:GetAttribute("LocalDodgeActive")==false,"Local flag cleared after restoring movement")
        check(e.Root.Position.X>=8 and e.Root.Position.X<=14,"Short intended step at different frame rates")
        near(e.Root.Position.Z,0,.001,"Direction fixed at input despite rotation before approval")
        near(e.Horizontal.Magnitude,0,.001,"Last physics solve removes residual horizontal drift")
        if air then check(e.Y<0 and e.YVelocity<0,"Gravity continues throughout air dodge")end
        table.insert(distances,e.Root.Position.X)
        ctrl:Destroy();check(e.Player.CharacterAdded:Count()==0,"Lifecycle listener removed on teardown")
    end
    near(distances[1],distances[2],.001,"Air does not travel farther than ground")
end
do
    local e=client(true);local ctrl=e.Controller
    e.Humanoid.AutoRotate=false;ctrl:Request("Left");e:Grant()
    check(ctrl.Active.Direction.X<0,"Left steps opposite RightVector")
    local t=ctrl.Active.Track;local lv=ctrl.Active.Velocity
    check(t.Priority=="Action" and not t.Looped and t.PlayFade>0,"Action animation has short fade-in")
    for _=1,16 do e:Tick(1/60)end
    check(#t.Weights>0 and t.StopFade==.12,"Animation weight softens and Stop fades")
    check(not e.Humanoid.AutoRotate,"False original AutoRotate preserved")
    e.Time+=1;ctrl:Request("Left");e:Grant();check(e.Loads==1,"Animation cache reused per direction")
    e.Humanoid.Health=0;e.Humanoid.Died:Fire()
    check(not ctrl.Active and e.Run.Heartbeat:Count()==0,"Death tears down current motion")
    check(e.Player.Character:GetAttribute("LocalDodgeActive")==false,"Death clears local movement flag")
    e:Respawn();check(t.Destroyed,"Respawn clears animation cache")
    ctrl:Request("Right");e:Grant();check(e.Loads==2,"Separate direction and new-character track")
    e:Respawn();check(not ctrl.Active and e.Run.Heartbeat:Count()==0,"Respawn tears down force and frame listener")
    ctrl:Destroy();check(lv.Destroyed,"All completed constraints remain destroyed")
end
do
    local e=client();local ctrl=e.Controller;e.Wall=true
    ctrl:Request("Right");e:Grant()
    local lv=ctrl.Active.Velocity
    check(lv.VectorVelocity==V.zero,"Wall cancels force before first solve")
    e:Tick(.1);e.Wall=false;e:Tick(.15);e:Tick(.02)
    near(e.Root.Position.Magnitude,0,.001,"Blocked step never resumes pushing through wall")
    check(lv.Destroyed and e.Loads==0,"Wall cleanup works without animation IDs")
    e.Time+=1;e.Attachment:Destroy();ctrl:Request("Right");e:Grant()
    local fallback=ctrl.CreatedAttachment
    check(fallback and fallback.Name=="RootAttachment","R6 missing standard attachment gets one fallback")
    ctrl:Destroy();check(fallback.Destroyed,"Created fallback removed on teardown")
end
do
    local e=client();local ctrl=e.Controller
    e.CanUse=false;check(not ctrl:Request("Left"),"UI gate blocks input")
    e.CanUse=true;ctrl:Request("Left");e.Time+=1;e:Grant()
    check(not ctrl.Active,"Late approval cannot play stale step")
    ctrl:Request("Right");local req=e.Requests[#e.Requests]
    ctrl:Handle("DodgeCancel",{Id=req.Id,Character=e.Player.Character})
    e:Grant();check(not ctrl.Active,"Cancellation clears a pending request")
    check(e.Player.Character:GetAttribute("LocalDodgePendingUntil")==nil,"Cancellation releases the pending combat gate")
    ctrl:Request("Right");e.CanUse=false;e:Grant()
    check(not ctrl.Active,"Menu opened while awaiting approval cancels playback")
    ctrl:Destroy()
end
do
    local e=client();local ctrl=e.Controller
    ctrl:Request("Right");e:Grant();e:Tick(.06)
    e.Wall=true;e:Tick(.016)
    local position=e.Root.Position;local lv=ctrl.Active.Velocity
    check(lv.VectorVelocity==V.zero,"Wall appearing during step immediately brakes horizontal force")
    e:Tick(.016);near((e.Root.Position-position).Magnitude,0,.001,"No continued push after mid-step wall hit")
    e.Humanoid.Attributes.Stunned=true;e:Tick(.016)
    check(not ctrl.Active and lv.Destroyed,"Mid-step stun cancels and destroys constraint")
    check(e.Humanoid.WalkSpeed==19,"Stun cancellation releases captured movement lock")
    ctrl:Destroy()
end
do
    local e=client();local s=e.Settings
    near(s.EaseOut(0),1,.00001,"Full initial speed")
    near(s.EaseOut(1),0,.00001,"Zero final speed")
    check((s.EaseOut(.999)-s.EaseOut(1))/.001<.01,"Velocity has a soft final slope rather than late sharp braking")
    local previous=1
    for i=0,100 do local value=s.EaseOut(i/100);check(value<=previous,"Velocity never accelerates during dodge");previous=value end
    e.Controller:Destroy()
end
print("PASS side dodge: "..checks.." checks (actual Main/server/client modules; deterministic physics doubles)")
