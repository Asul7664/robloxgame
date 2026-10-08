-- Short action layered into QuietCoveClient. Roblox keeps its normal movement controller.
local RunService = game:GetService("RunService")
local DodgeAnimator = require(script.Parent:WaitForChild("DodgeAnimator"))
local Controller = {}
Controller.__index = Controller
function Controller.new(player, settings, request, canUse)
    local self=setmetatable({Player=player, Settings=settings, Send=request, CanUse=canUse,
        Tracks={}, Connections={}, Serial=0, NextAt=0, Pose=DodgeAnimator.new()}, Controller)
    local function bind(character)
        self:_finish(true); self:_clearTracks()
        if self.Died then self.Died:Disconnect(); self.Died=nil end
        if self.CreatedAttachment then self.CreatedAttachment:Destroy(); self.CreatedAttachment=nil end
        self:_clearPending()
        self.Character=character; self.NextAt=0
        character:SetAttribute("LocalDodgePendingUntil",nil)
        character:SetAttribute("LocalDodgeActive",false)
        character:SetAttribute("LocalDodgePoseActive",false)
        local h=character:FindFirstChildOfClass("Humanoid")
        if h then self.Died=h.Died:Connect(function()self:_clearPending();self:_finish(true)end)end
    end
    table.insert(self.Connections,player.CharacterAdded:Connect(bind))
    table.insert(self.Connections,player.CharacterRemoving:Connect(function(character)
        if self.Character==character then
            self:_clearPending(); self:_finish(true); self:_clearTracks(); self.Character=nil
            if self.Died then self.Died:Disconnect();self.Died=nil end
            if self.CreatedAttachment then self.CreatedAttachment:Destroy();self.CreatedAttachment=nil end
        end
    end))
    if player.Character then bind(player.Character)end
    return self
end
function Controller:_clearPending()
    local pending=self.Pending
    self.Pending=nil
    if pending then pending.Character:SetAttribute("LocalDodgePendingUntil",nil) end
end
function Controller:IsBusy()
    if self.Pending and os.clock()-self.Pending.At > self.Settings.REQUEST_TIMEOUT then self:_clearPending() end
    return self.Active~=nil or self.Pending~=nil or self.Pose:IsPlaying()
end
function Controller:_clearTracks()
    for _,entry in pairs(self.Tracks)do
        entry.Track:Stop(self.Settings.FADE_OUT);entry.Track:Destroy();entry.Animation:Destroy()
    end
    self.Tracks={}
end
function Controller:_track(humanoid,side)
    if self.Tracks[side]then return self.Tracks[side].Track end
    local id=self.Settings.Animations[side]
    -- Deliberate placeholders never issue failing asset requests.
    if type(id)~="string" or not id:match("^rbxassetid://%d+$") or id=="rbxassetid://0"then return nil end
    local animator=humanoid:FindFirstChildOfClass("Animator")
    if not animator then return nil end
    local animation=Instance.new("Animation");animation.AnimationId=id
    local ok,track=pcall(function()return animator:LoadAnimation(animation)end)
    if not ok then animation:Destroy();return nil end
    track.Priority=Enum.AnimationPriority.Action;track.Looped=false
    self.Tracks[side]={Track=track,Animation=animation}
    return track
end
function Controller:Request(side)
    if self:IsBusy() or os.clock()<self.NextAt or not self.CanUse()then return false end
    local character=self.Player.Character
    local h=character and character:FindFirstChildOfClass("Humanoid")
    local root=character and character:FindFirstChild("HumanoidRootPart")
    if not h or h.Health<=0 or not root or root.Anchored or h.Sit or h.SeatPart
        or h:GetState()==Enum.HumanoidStateType.Swimming
        or h:GetState()==Enum.HumanoidStateType.PlatformStanding
        or self.Settings.Stunned(character,h,workspace:GetServerTimeNow())then return false end
    local direction=self.Settings.Direction(root.CFrame,side);if not direction then return false end
    if not self.Died then self.Died=h.Died:Connect(function()self:_clearPending();self:_finish(true)end)end
    self.Serial=self.Serial%2147483647+1
    self.Pending={Id=self.Serial,Character=character,Side=side,Direction=direction,At=os.clock()}
    -- The expiry is local input coordination, never a server immunity flag.
    -- Lost acknowledgements cannot leave attacks blocked after the timeout.
    character:SetAttribute("LocalDodgePendingUntil",os.clock()+self.Settings.REQUEST_TIMEOUT)
    self.Send(side,self.Serial)
    return true
end
function Controller:_finish(immediate)
    if immediate then self.Pose:Cancel() else self.Pose:Release() end
    local state=self.Active
    if not state then return end
    self.Active=nil
    if state.Heartbeat then state.Heartbeat:Disconnect()end
    if state.Tail then state.Tail:Disconnect()end
    if state.Velocity then state.Velocity:Destroy()end
    if state.Track then state.Track:Stop(self.Settings.FADE_OUT)end
    if state.Humanoid.Parent then
        state.Humanoid.WalkSpeed=state.WalkSpeed
        state.Humanoid.AutoRotate=state.AutoRotate
    end
    state.Character:SetAttribute("LocalDodgeActive",false)
end
function Controller:Handle(kind,payload)
    if kind=="DodgeCancel"then
        if self.Pending and self.Pending.Id==payload.Id and self.Pending.Character==payload.Character then self:_clearPending() end
        if self.Active and self.Active.Id==payload.Id and self.Active.Character==payload.Character then self:_finish()end
        return
    end
    if kind~="DodgeResult"then return end
    local pending=self.Pending
    if not pending or payload.Id~=pending.Id or payload.Side~=pending.Side then return end
    self:_clearPending()
    if not payload.Allowed or pending.Character~=self.Player.Character or payload.Character~=pending.Character
        or os.clock()-pending.At>self.Settings.REQUEST_TIMEOUT
        or workspace:GetServerTimeNow()>=payload.EndsAt or not self.CanUse()then return end
    local c=pending.Character;local h=c:FindFirstChildOfClass("Humanoid");local root=c:FindFirstChild("HumanoidRootPart")
    if not h or h.Health<=0 or not root or root.Anchored or h.Sit or h.SeatPart
        or h:GetState()==Enum.HumanoidStateType.Swimming
        or h:GetState()==Enum.HumanoidStateType.PlatformStanding
        or self.Settings.Stunned(c,h,workspace:GetServerTimeNow())then return end
    if not self.Died then self.Died=h.Died:Connect(function()self:_clearPending();self:_finish(true)end)end
    local attachment=root:FindFirstChild("RootAttachment")
    if not attachment then
        -- Some R6 characters lack the standard attachment. Create exactly one
        -- only when absent, reuse it, and remove our fallback on teardown.
        attachment=Instance.new("Attachment");attachment.Name="RootAttachment";attachment.Parent=root
        self.CreatedAttachment=attachment
    end
    local lv=Instance.new("LinearVelocity")
    lv.Name="SideDodgeVelocity";lv.Attachment0=attachment
    lv.RelativeTo=Enum.ActuatorRelativeTo.World
    lv.VelocityConstraintMode=Enum.VelocityConstraintMode.Vector
    lv.ForceLimitsEnabled=true;lv.ForceLimitMode=Enum.ForceLimitMode.PerAxis
    lv.MaxAxesForce=Vector3.new(self.Settings.MAX_FORCE,0,self.Settings.MAX_FORCE)
    local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances={c};ray.RespectCanCollide=true
    local state={Id=pending.Id,Character=c,Humanoid=h,Root=root,Direction=pending.Direction,Velocity=lv,
        WalkSpeed=h.WalkSpeed,AutoRotate=h.AutoRotate,Started=os.clock(),Ray=ray}
    self.Active=state
    c:SetAttribute("LocalDodgeActive",true)
    self.NextAt=os.clock()+math.max(0,payload.CooldownUntil-workspace:GetServerTimeNow())
    h.WalkSpeed=0;h.AutoRotate=false
    state.Track=self:_track(h,pending.Side)
    if state.Track then
        state.Track:Play(self.Settings.FADE_IN,1,1)
        if state.Track.Length>0 then
            state.Track:AdjustSpeed(state.Track.Length/self.Settings.DASH_TIME);state.TrackTimed=true
        end
    else
        self.Pose:Play(c,pending.Side,self.Settings.DASH_TIME,self.Settings.POSE_RECOVERY)
    end
    lv.VectorVelocity=state.Direction*self.Settings.DASH_SPEED
    -- Do not create a force into a nearby wall, even for the first physics frame.
    if self:_wall(state,1/60)then lv.VectorVelocity=Vector3.zero;state.Blocked=true end
    lv.Parent=root
    state.Heartbeat=RunService.Heartbeat:Connect(function(dt)self:_step(state,dt)end)
end
function Controller:_wall(state,dt)
    local speed=state.Velocity.VectorVelocity.Magnitude
    -- At low FPS look beyond 2 studs if the next physics frame could travel
    -- farther. Three rays cover the body edges; terrain/other players remain solid.
    local length=math.max(self.Settings.WALL_CHECK,speed*math.min(dt,.1)+state.Root.Size.X*.5+.2)
    for _,height in ipairs({-state.Root.Size.Y*.4,0,state.Root.Size.Y*.4})do
        local hit=workspace:Raycast(state.Root.Position+Vector3.new(0,height,0),state.Direction*length,state.Ray)
        if hit and hit.Normal:Dot(state.Direction)<-.15 then return true end
    end
    return false
end
function Controller:_step(state,dt)
    if self.Active~=state then return end
    local h=state.Humanoid
    if self.Player.Character~=state.Character or not state.Root.Parent or h.Health<=0 or h.Sit or h.SeatPart
        or state.Root.Anchored or h:GetState()==Enum.HumanoidStateType.PlatformStanding
        or self.Settings.Stunned(state.Character,h,workspace:GetServerTimeNow())
        or h:GetState()==Enum.HumanoidStateType.Swimming then self:_finish(true);return end
    local t=(os.clock()-state.Started)/self.Settings.DASH_TIME
    if state.Track and not state.TrackTimed and state.Track.Length>0 then
        state.Track:AdjustSpeed(state.Track.Length/self.Settings.DASH_TIME);state.TrackTimed=true
    end
    if not state.Blocked and self:_wall(state,dt)then state.Blocked=true end
    state.Velocity.VectorVelocity=state.Direction*self.Settings.DASH_SPEED*(state.Blocked and 0 or self.Settings.EaseOut(t))
    if state.Track and t>=self.Settings.WEIGHT_FADE_START then
        state.Track:AdjustWeight(math.max(0,(1-t)/(1-self.Settings.WEIGHT_FADE_START)),.04)
    end
    if t>=1 then
        state.Heartbeat:Disconnect();state.Heartbeat=nil
        -- Give the zero-horizontal target one physics solve before destroying
        -- the constraint. Otherwise the final nonzero velocity persists in air.
        -- Y has no force throughout; falling/jumping continues normally.
        state.Tail=RunService.PostSimulation:Connect(function()self:_finish()end)
    end
end
function Controller:Destroy()
    self:_clearPending();self:_finish(true);self:_clearTracks();self.Pose:Destroy()
    if self.Died then self.Died:Disconnect();self.Died=nil end
    if self.CreatedAttachment then self.CreatedAttachment:Destroy();self.CreatedAttachment=nil end
    for _,connection in ipairs(self.Connections)do connection:Disconnect()end
    self.Connections={};self.Character=nil
end
return Controller
