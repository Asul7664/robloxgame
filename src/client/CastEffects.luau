-- Local presentation driven ONLY by server-approved cast messages/tool attributes.
-- Smooth visible projectile + curved line, full R6/R15 arm swing, white slash and splash.
-- No remotes are sent here; cosmetics cannot choose catches, money, position or timing.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local Cast=require(RS:WaitForChild("QuietCove"):WaitForChild("CastMath"))
local CastingRig=require(script.Parent:WaitForChild("CastingRig"))
local Effects={};Effects.__index=Effects
local WHITE=Color3.fromRGB(248,255,255)
local AQUA=Color3.fromRGB(148,232,242)
local HANDOFF_SECONDS=0.35
local function make(cl,props,parent)
    local o=Instance.new(cl);for k,v in pairs(props)do o[k]=v end;o.Parent=parent;return o
end
local function part(parent,name,size,color)
    return make("Part",{Name=name,Size=size,Color=color or WHITE,Material=Enum.Material.Neon,
        Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false},parent)
end
local function anchor(parent,name)
    local p=part(parent,name,Vector3.new(0.1,0.1,0.1));p.Transparency=1;return p
end
local function beam(parent,a,b,width,color,alpha)
    return make("Beam",{Attachment0=a,Attachment1=b,Width0=width,Width1=width,
        Color=ColorSequence.new(color or WHITE),Transparency=NumberSequence.new(alpha or 0),
        FaceCamera=true,LightEmission=0.8,LightInfluence=0,Segments=1},parent)
end
local function rodOf(character)
    if not character then return nil end
    for _,o in ipairs(character:GetChildren())do
        if o:IsA("Tool")and o:GetAttribute("QuietCoveRod")then return o end
    end
end
local function tipOf(tool)
    local handle=tool and tool:FindFirstChild("Handle")
    return handle and handle:FindFirstChild("Tip")
end
local function line(parent,name)
    local root=anchor(parent,name);local points,beams={},{}
    for i=1,10 do points[i]=make("Attachment",{},root)end
    for i=1,9 do beams[i]=beam(root,points[i],points[i+1],0.048,WHITE,0.13)end
    return {Root=root,Points=points,Beams=beams}
end
local function positionLine(c,tip,position,sag)
    for i,a in ipairs(c.Points)do
        local u=(i-1)/(#c.Points-1)
        a.Position=tip+(position-tip)*u-Vector3.new(0,math.sin(math.pi*u)*sag,0)
    end
end
function Effects:_tip(userId,tool,character)
    local a=self.Actors[userId]
    local player=Players:GetPlayerByUserId(userId)
    if not a or not player or player.Character~=character or a.Character~=character
        or a.Tool~=tool or tool.Parent~=character or not a.Root.Parent then return nil end
    local humanoid=character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health<=0 then return nil end
    local tip=a.Rig and a.Rig.LastRod and a.Tip or tipOf(tool)
    return tip and tip.Parent and tip or nil
end
-- Landing owns the transferred line until its full shared-clock duration ends.
-- Its endpoint is supplied by the actual model animation, never the deleted marker.
function Effects:BeginLanding(p)
    if self.Dead then return nil end
    self:_scan()
    local a=self.Actors[p.UserId];if not a then return nil end
    local latest=self.Latest[p.UserId]
    if not p.Preview and latest and latest.Id~=p.Id and latest.Started>=p.Started then return nil end
    local live=self.Casts[p.UserId]
    if p.Preview and live then return nil end -- a Studio preview cannot steal an active cast
    local c
    if live and live.Data.Id==p.Id then
        self.Casts[p.UserId]=nil;c=live
        c.Bobber:Destroy();c.Cap:Destroy();c.Trail:Destroy()
    else c=line(self.Folder,"LandingLine_"..p.UserId)end
    c.Data=p;c.Tool=a.Tool;c.Character=a.Character
    if not self:_tip(p.UserId,c.Tool,c.Character)then c.Root:Destroy();return nil end
    if not p.Preview then
        local old=self.LandingByUser[p.UserId]
        if old then self:EndLanding(old.Data,old)end
        self.LandingByUser[p.UserId]=c
        self.Latest[p.UserId]={Id=p.Id,Started=p.Started};a.SessionId=p.Id
        self.Closed[p.Id]=workspace:GetServerTimeNow()
    end
    return c
end
function Effects:StepLanding(p,c,position)
    if self.Dead or not c or not c.Root.Parent then return false end
    local tip=self:_tip(p.UserId,c.Tool,c.Character)
    if not tip then self:EndLanding(p,c);return false end
    positionLine(c,tip.WorldPosition,position,0.16)
    return true
end
function Effects:EndLanding(p,c)
    if not c then return end
    if self.LandingByUser[p.UserId]==c then self.LandingByUser[p.UserId]=nil end
    c.Root:Destroy()
end
function Effects:_removeActor(id)
    local a=self.Actors[id];if not a then return end
    for _,j in ipairs(a.Joints)do if j.Motor.Parent and j.Base then j.Motor.Transform=j.Base end end
    if a.Rig then a.Rig:Destroy() end
    for _,o in ipairs(a.Cosmetics)do o:Destroy()end
    if a.Slash then a.Slash.Root:Destroy()end
    self.Actors[id]=nil
end
function Effects:_actor(player,tool)
    local id=player.UserId;local old=self.Actors[id]
    if old and old.Tool==tool and old.Character==player.Character then return old end
    self:_removeActor(id)
    local character=player.Character;local root=character and character:FindFirstChild("HumanoidRootPart")
    local tip=tipOf(tool);if not root or not tip then return nil end
    local rig=CastingRig.new(character,tool,self.Folder);if not rig then return nil end
    local a={Id=id,Tool=tool,Character=character,Root=root,Tip=rig.Tip,BaseGrip=tool.Grip,Joints={},Cosmetics={},Rig=rig}
    tip=rig.Tip
    local handle=rig.Handle
    for i,spec in ipairs({{0.9,0.20},{0.15,0.04}})do
        local p0=make("Attachment",{Name="CastTrailOuter"..i,Position=tip.Position},handle)
        local p1=make("Attachment",{Name="CastTrailInner"..i,Position=tip.Position-Vector3.new(0,spec[1],0)},handle)
        local trail=make("Trail",{Name="WhiteCastSlash"..i,Attachment0=p0,Attachment1=p1,Enabled=false,
            Lifetime=0.20,MinLength=0.025,FaceCamera=true,LightEmission=1,LightInfluence=0,
            Color=ColorSequence.new(WHITE),Transparency=NumberSequence.new({
                NumberSequenceKeypoint.new(0,spec[2]),NumberSequenceKeypoint.new(0.5,0.42),NumberSequenceKeypoint.new(1,1)}),
            WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)})},handle)
        a.Cosmetics[#a.Cosmetics+1]=trail;a.Cosmetics[#a.Cosmetics+1]=p0;a.Cosmetics[#a.Cosmetics+1]=p1
    end
    self.Actors[id]=a;return a
end
function Effects:_scan()
    local localChar=Players.LocalPlayer.Character
    local localRoot=localChar and localChar:FindFirstChild("HumanoidRootPart")
    local seen={}
    for _,p in ipairs(Players:GetPlayers())do
        local tool=rodOf(p.Character);local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if tool and root and (p==Players.LocalPlayer or not localRoot or (root.Position-localRoot.Position).Magnitude<self.Config.Casting.EffectDistance)then
            self:_actor(p,tool);seen[p.UserId]=true
        end
    end
    local gone={};for id in pairs(self.Actors)do if not seen[id]then gone[#gone+1]=id end end
    for _,id in ipairs(gone)do self:_removeActor(id)end
end
function Effects:_state(a,now)
    local stage=a.Tool:GetAttribute("QCFishingStage")or "Idle"
    local at=a.Tool:GetAttribute("QCStageAt")or now
    local power=a.Tool:GetAttribute("QCCastPower")or 0
    if stage=="Charging"then
        at=a.Tool:GetAttribute("QCChargeAt")or at
        power=math.clamp((now-at)/self.Config.ChargeSeconds,0,1)
    elseif stage=="Casting"then at=a.Tool:GetAttribute("QCCastAt")or at end
    if a.Override then
        stage=a.Override.Stage;at=a.Override.At;power=a.Override.Power or power
        if stage=="Charging"then power=math.clamp((now-at)/self.Config.ChargeSeconds,0,1)end
    end
    if a.PosePreview then
        if stage~='Idle' or now>=a.PosePreview.Until then a.PosePreview=nil
        else return a.PosePreview.Stage,now-a.PosePreview.At,a.PosePreview.Power end
    end
    return stage,now-at,power
end

function Effects:PreviewPose(stage,seconds)
    if not RunService:IsStudio()then return false end
    local stages={Idle=true,Charging=true,Casting=true,Waiting=true,Bite=true,Reeling=true,Landing=true}
    assert(stages[stage],"Rod stage: Idle, Charging, Casting, Waiting, Bite, Reeling, Landing")
    assert(type(seconds)=='number' and seconds>=1 and seconds<=20,"Preview duration: 1..20 seconds")
    self:_scan()
    local a=self.Actors[Players.LocalPlayer.UserId]
    assert(a,"Equip a fishing rod and wait for the character to load")
    local now=workspace:GetServerTimeNow()
    a.PosePreview={Stage=stage,At=now,Until=now+seconds,Power=.65}
    return true
end
function Effects:ClearPreviewPoses()
    for _,a in pairs(self.Actors)do a.PosePreview=nil end
end
function Effects:_restoreTransforms()
    for _,a in pairs(self.Actors)do if a.Rig then a.Rig:Restore()end end
end
function Effects:_pose(dt)
    local now=workspace:GetServerTimeNow()
    local gone={}
    for id,a in pairs(self.Actors)do
        if a.Tool.Parent==a.Character and a.Root.Parent then
            local stage,t,power=self:_state(a,now)
            local slash=a.Rig:Step(stage,t,power,self.Config.Casting,dt)
            for _,o in ipairs(a.Cosmetics)do if o:IsA("Trail")then o.Enabled=slash end end
        else gone[#gone+1]=id end
    end
    for _,id in ipairs(gone)do self:_removeActor(id)end
end
function Effects:_splash(position,power)
    local root=anchor(self.Folder,"CastWaterSplash");local rings,drops={},{}
    local base=Vector3.new(position.X,position.Y-0.21,position.Z)
    for ring=1,3 do
        local points,beams={},{};local count=24
        for j=1,count do points[j]=make("Attachment",{Position=base},root)end
        for j=1,count do beams[j]=beam(root,points[j],points[j%count+1],0.12,ring==1 and WHITE or AQUA,0.2)end
        rings[#rings+1]={Points=points,Beams=beams,Delay=(ring-1)*0.13}
    end
    for i=1,16 do
        local a=i*2.39996;local speed=3.4+(i%4)*0.7+power
        local drop=part(root,"SplashDroplet",Vector3.new(0.10,0.16+(i%3)*0.05,0.10),i%2==0 and WHITE or AQUA)
        drop.Shape=Enum.PartType.Ball
        drops[#drops+1]={Part=drop,V=Vector3.new(math.cos(a)*speed,7+(i%5)*1.1+power*2,math.sin(a)*speed)}
    end
    self.Splashes[#self.Splashes+1]={Root=root,Base=base,Rings=rings,Drops=drops,At=workspace:GetServerTimeNow()}
end
function Effects:_updateSplashes(now)
    for i=#self.Splashes,1,-1 do
        local s=self.Splashes[i];local t=now-s.At
        if t>1.65 then s.Root:Destroy();table.remove(self.Splashes,i)
        else
            for _,r in ipairs(s.Rings)do
                local age=t-r.Delay;local u=math.clamp(age/1.3,0,1)
                local radius=0.45+u*5.8
                for j,p in ipairs(r.Points)do
                    local a=2*math.pi*(j-1)/#r.Points
                    p.Position=s.Base+Vector3.new(math.cos(a)*radius,0.025*math.sin(a*3+t*8),math.sin(a)*radius)
                end
                for _,b in ipairs(r.Beams)do
                    b.Transparency=NumberSequence.new(age<0 and 1 or math.min(1,0.20+u*0.80))
                    b.Width0=0.13*(1-u)+0.02;b.Width1=b.Width0
                end
            end
            for _,d in ipairs(s.Drops)do
                local p=s.Base+Vector3.new(0,0.22,0)+d.V*t-Vector3.new(0,21*t*t,0)
                d.Part.Position=p;d.Part.Transparency=p.Y<s.Base.Y and 1 or math.clamp(t/0.75,0,1)
            end
        end
    end
end
function Effects:_end(id)
    local c=self.Casts[id]
    if c then self.Closed[c.Data.Id]=workspace:GetServerTimeNow();c.Root:Destroy();self.Casts[id]=nil end
end
function Effects:Handle(kind,p)
    if self.Dead then return end
    if kind=="CastEnd" then
        local landing=self.LandingByUser[p.UserId]
        if landing and landing.Data.Id==p.Id then return end -- line is already attached to the won fish
        local live=self.Casts[p.UserId]
        if live and live.Data.Id~=p.Id then return end -- stale end must not stop a newer swing
        local a=self.Actors[p.UserId]
        if a and a.SessionId and a.SessionId~=p.Id then return end
        self.Closed[p.Id]=workspace:GetServerTimeNow()
        if live then
            live.EndAt=live.EndAt or workspace:GetServerTimeNow()+HANDOFF_SECONDS
            live.Bobber.Transparency=1;live.Cap.Transparency=1;live.Trail.Enabled=false
        end
        if a then
            if a.Slash then a.Slash.Root:Destroy();a.Slash=nil end
        end
        return
    end
    if kind=="Stage"then
        self:_scan()
        local a=self.Actors[Players.LocalPlayer.UserId]
        if a then
            if p.Stage=="Idle" and a.SessionId and a.SessionId~=p.Id then return end
            a.SessionId=p.Id
            a.Override={Stage=p.Stage,At=p.Started or workspace:GetServerTimeNow(),Power=p.Power}
        end
        if p.Stage=="Charging" then
            self.Latest[Players.LocalPlayer.UserId]={Id=p.Id,Started=p.Started or workspace:GetServerTimeNow()}
        end
        if p.Stage=="Idle" then
            local live=self.Casts[Players.LocalPlayer.UserId]
            if live and live.Data.Id==p.Id then self:_end(Players.LocalPlayer.UserId)end
        end
        return
    end
    if kind~="CastVisual"then return end
    local player=Players:GetPlayerByUserId(p.UserId)
    if not player or not p.Tool or p.Tool.Parent~=player.Character then return end
    local latest=self.Latest[p.UserId]
    if self.Closed[p.Id]or (latest and latest.Id~=p.Id and latest.Started>=p.Started)then return end
    local existing=self.Casts[p.UserId]
    if existing and existing.Data.Id==p.Id then return end -- Ready replay is idempotent.
    local localChar=Players.LocalPlayer.Character
    local localRoot=localChar and localChar:FindFirstChild("HumanoidRootPart")
    if localRoot and (localRoot.Position-p.Target).Magnitude>self.Config.Casting.EffectDistance then return end
    local a=self:_actor(player,p.Tool);if not a then return end
    self.Latest[p.UserId]={Id=p.Id,Started=p.Started};a.SessionId=p.Id
    self:_end(p.UserId)
    local c=line(self.Folder,"VisibleCast_"..p.UserId);local root=c.Root
    local bobber=part(root,"VisibleBobber",Vector3.new(0.40,0.6,0.40),Color3.fromRGB(250,164,101));bobber.Shape=Enum.PartType.Ball
    local cap=part(root,"BobberWhiteCap",Vector3.new(0.29,0.20,0.29),WHITE);cap.Shape=Enum.PartType.Ball
    local tail0=make("Attachment",{Position=Vector3.new(-0.07,0,0)},bobber)
    local tail1=make("Attachment",{Position=Vector3.new(0.07,0,0)},bobber)
    local trail=make("Trail",{Name="FlyingLineGlint",Attachment0=tail0,Attachment1=tail1,Lifetime=0.20,
        MinLength=0.03,FaceCamera=true,LightEmission=1,Color=ColorSequence.new(WHITE),
        Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.1),NumberSequenceKeypoint.new(1,1)})},bobber)
    local elapsed=workspace:GetServerTimeNow()-p.Started
    local late=elapsed>p.Swing+p.Flight+0.2
    c.Bobber=bobber;c.Cap=cap;c.Trail=trail;c.Data=p;c.Tip=a.Tip;c.Impact=late;c.LastPosition=p.Origin
    self.Casts[p.UserId]=c
    -- White Trails use actual rod-tip motion; no unrelated fixed crescent.
end
function Effects:_render()
    if self.Dead then return end
    local now=workspace:GetServerTimeNow()
    if now>=self.ScanAt then self.ScanAt=now+0.20;self:_scan()end
    for id,c in pairs(self.Casts)do
        local p=c.Data
        local player=Players:GetPlayerByUserId(id)
        local currentTip=player and self:_tip(id,p.Tool,player.Character)
        if not currentTip then self:_end(id)
        else
            if p.Marker and not p.Marker.Parent and not c.EndAt then c.EndAt=now+HANDOFF_SECONDS end
            if c.EndAt and (now>=c.EndAt or p.Tool:GetAttribute("QCFishingStage")=="Idle")then
                self:_end(id);continue
            end
            local elapsed=now-p.Started;local t=Cast.Progress(now,p.Started,p.Swing,p.Flight)
            local tip=currentTip.WorldPosition
            local position
            if c.EndAt then position=c.LastPosition or p.Target
            elseif elapsed<p.Swing then
                position=tip;c.PreviousTip=tip;c.PreviousTipAt=now
            elseif t<1 then
                if not c.LaunchOrigin then
                    c.LaunchOrigin=p.Origin;c.VisualVelocity=p.LaunchVelocity
                    -- Interpolate the actual grip-adjusted tip at the release instant.
                    -- Starting at the first AFTER-release frame would add an extra-frame jump.
                    local span=c.PreviousTipAt and now-c.PreviousTipAt
                    if c.PreviousTip and span and span>0 and span<.15 and t<.16 then
                        local alpha=math.clamp((p.Started+p.Swing-c.PreviousTipAt)/span,0,1)
                        local v=(tip-c.PreviousTip)/span
                        if v.Magnitude<160 then
                            c.LaunchOrigin=c.PreviousTip+(tip-c.PreviousTip)*alpha
                            if v.Magnitude>.1 then c.VisualVelocity=v end
                        end
                    end
                end
                position=Cast.Position(c.LaunchOrigin,p.Target,t,p.Arc,p.LaunchDirection,c.VisualVelocity,p.Flight)
            else
                if not c.Impact then c.Impact=true;self:_splash(p.Target,p.Power)end
                local stage=p.Tool:GetAttribute("QCFishingStage")
                local rate=stage=="Bite" and 18 or 3
                position=p.Target+Vector3.new(0,math.sin(now*rate)*0.10,0)
            end
            c.LastPosition=position
            c.Bobber.Position=position;c.Cap.Position=position+Vector3.new(0,0.22,0)
            c.Trail.Enabled=not c.EndAt and elapsed>=p.Swing and t<1
            local sag=t<1 and math.sin(math.pi*t)*2.6 or 0.5
            positionLine(c,tip,position,sag)
        end
    end
    self:_updateSplashes(now)
    for id,at in pairs(self.Closed)do if now-at>15 then self.Closed[id]=nil end end
end
function Effects:Destroy()
    if self.Dead then return end;self.Dead=true
    self.Pre:Disconnect();self.Sim:Disconnect();self.Render:Disconnect()
    local ids={};for id in pairs(self.Actors)do ids[#ids+1]=id end
    for _,id in ipairs(ids)do self:_removeActor(id)end
    self.Casts={};self.LandingByUser={};self.Splashes={};self.Folder:Destroy()
end
function Effects.new(config)
    local self=setmetatable({Config=config,Actors={},Casts={},LandingByUser={},Latest={},Closed={},Splashes={},ScanAt=0},Effects)
    self.Folder=make("Folder",{Name="QuietCoveLocalCastEffects"},workspace)
    self.Pre=RunService.PreAnimation:Connect(function()self:_restoreTransforms()end)
    self.Sim=RunService.PreSimulation:Connect(function(dt)self:_pose(math.min(dt,0.1))end)
    self.Render=RunService.RenderStepped:Connect(function()self:_render()end)
    return self
end
return Effects
