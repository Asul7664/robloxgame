-- Integrated by Main into its Action remote, Heartbeat and player lifecycle.
-- No client attribute, duration, speed or arbitrary vector grants immunity.
local Service = {}
Service.__index = Service
function Service.new(settings, send, busy)
    return setmetatable({Settings=settings, Send=send, Busy=busy, States={}}, Service)
end
function Service:IsActive(player)
    local state = self.States[player]
    return state ~= nil and state.Active == true
end
function Service:_end(player, state, cancel)
    if state.Died then state.Died:Disconnect(); state.Died=nil end
    state.Active=false
    state.Character:SetAttribute("IFrame", false)
    state.Character:SetAttribute("Dodging", false)
    if cancel then self.Send(player, "DodgeCancel", {Id=state.Id, Character=state.Character}) end
end
function Service:Remove(player)
    local state = self.States[player]
    if state then self:_end(player, state, true); self.States[player]=nil end
end
function Service:Request(player, side, id, now)
    local function reject(reason)
        self.Send(player, "DodgeResult", {Allowed=false, Id=id, Side=side, Reason=reason})
    end
    if (side ~= "Left" and side ~= "Right") or type(id) ~= "number" or id ~= id
        or id % 1 ~= 0 or id < 1 or id > 2147483647 then return end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0
        or root.Anchored or humanoid.Sit or humanoid.SeatPart
        or humanoid:GetState() == Enum.HumanoidStateType.Swimming
        or humanoid:GetState() == Enum.HumanoidStateType.PlatformStanding
        or self.Settings.Stunned(character, humanoid, now) or self.Busy(player) then reject("state"); return end
    local old = self.States[player]
    if (old and (old.Active or now < old.CooldownUntil)) or character:GetAttribute("Dodging") == true then
        reject("cooldown"); return
    end
    local state = {Character=character, Humanoid=humanoid, Root=root, Id=id, Active=true,
        EndAt=now+self.Settings.DASH_TIME, IFrameEnd=now+self.Settings.IFRAME_TIME,
        CooldownUntil=now+self.Settings.COOLDOWN}
    self.States[player]=state
    character:SetAttribute("Dodging", true)
    character:SetAttribute("IFrame", true)
    state.Died=humanoid.Died:Connect(function()
        if self.States[player] == state then self:_end(player, state, true) end
    end)
    self.Send(player, "DodgeResult", {Allowed=true, Id=id, Side=side, Character=character,
        StartedAt=now, EndsAt=state.EndAt, CooldownUntil=state.CooldownUntil})
end
function Service:Step(now)
    for player, state in pairs(self.States) do
        if state.Active then
            local h, c = state.Humanoid, state.Character
            if player.Character ~= c or not c.Parent or h.Health <= 0 or not state.Root.Parent
                or state.Root.Anchored or h:GetState() == Enum.HumanoidStateType.PlatformStanding
                or h.Sit or h.SeatPart or self.Settings.Stunned(c,h,now) or self.Busy(player)
                or h:GetState() == Enum.HumanoidStateType.Swimming then
                self:_end(player, state, true)
            elseif now >= state.EndAt then self:_end(player, state, false)
            elseif now >= state.IFrameEnd then c:SetAttribute("IFrame", false) end
        end
    end
end
function Service:Destroy()
    for player in pairs(self.States) do self:Remove(player) end
end
return Service
