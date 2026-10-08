-- The standard Roblox CameraModule still owns orbit, zoom and occlusion.
-- Musket aim adds a right-shoulder offset; default zoom and occlusion stay intact.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local TURN_RATE = 28
local SHOULDER_OFFSET = Vector3.new(2.2, 0.5, 0)
local SHOULDER_BLEND_TIME = 0.15
local FIRST_PERSON_DISTANCE = 1
local serial = 0
local WeaponCamera = {}
WeaponCamera.__index = WeaponCamera

local function dodging(character)
    return character:GetAttribute("Dodging") == true
        or character:GetAttribute("LocalDodgeActive") == true
end

function WeaponCamera.IsUIBlocked(player)
    if UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then return true end
    local gui = player:FindFirstChildOfClass("PlayerGui")
    local quiet = gui and gui:FindFirstChild("QuietCoveUI")
    if quiet and quiet.Enabled ~= false then
        for _, name in ipairs({"InventoryAndShop", "QuestWindow", "VoyageWindow", "CatchReveal"}) do
            local window = quiet:FindFirstChild(name)
            if window and window.Visible then return true end
        end
    end
    return false
end

function WeaponCamera.new(player, canAim, onAim)
    serial += 1
    local self = setmetatable({
        Player = player,
        CanAim = canAim,
        OnAim = onAim,
        Connections = {},
        InputStep = "QuietCoveMusketMouse_" .. serial,
        FacingStep = "QuietCoveMusketFacing_" .. serial,
    }, WeaponCamera)
    table.insert(self.Connections, player.CharacterAdded:Connect(function(character)
        self:_bind(character)
    end))
    table.insert(self.Connections, player.CharacterRemoving:Connect(function(character)
        if self.Character == character then self:_bind(nil) end
    end))
    self:_bind(player.Character)
    -- Lock before the normal camera samples mouse delta, then reassert it after
    -- that module updates MouseBehavior. No second camera controller is created.
    RunService:BindToRenderStep(self.InputStep, Enum.RenderPriority.Camera.Value - 1, function(dt)
        self:_prepare(dt)
    end)
    RunService:BindToRenderStep(self.FacingStep, Enum.RenderPriority.Camera.Value + 1, function(dt)
        self:_face(dt)
    end)
    return self
end

function WeaponCamera:_watchHumanoid(humanoid)
    if self.WatchedHumanoid == humanoid then return end
    if self.Died then self.Died:Disconnect(); self.Died = nil end
    self.WatchedHumanoid = humanoid
    if humanoid then
        self.Died = humanoid.Died:Connect(function()
            self.Tool = nil
            self:_release(true)
        end)
    end
end

function WeaponCamera:_bind(character)
    self:_release(true)
    self:_watchHumanoid(nil)
    self.Character = character
    self.Tool = nil
    if character then self:_watchHumanoid(character:FindFirstChildOfClass("Humanoid")) end
end

function WeaponCamera:SetTool(tool)
    if self.Destroyed then return end
    if self.Player.Character ~= self.Character then self:_bind(self.Player.Character) end
    if self.Tool == tool then return end
    self:_release()
    self.Tool = tool
    self:_prepare()
end

function WeaponCamera:IsAiming()
    return self.Active ~= nil
end

function WeaponCamera:_restoreDeferred(force)
    local saved = self.DeferredRotation
    if not saved then return end
    if force or not saved.Character.Parent or not dodging(saved.Character) then
        self.DeferredRotation = nil
        if saved.Humanoid.Parent then saved.Humanoid.AutoRotate = saved.AutoRotate end
    end
end

function WeaponCamera:_resetShoulder()
    local saved = self.Shoulder
    self.Shoulder = nil
    if saved and saved.Humanoid.Parent then saved.Humanoid.CameraOffset = saved.BaseOffset end
end

function WeaponCamera:_stepShoulder(dt, camera)
    local saved = self.Shoulder
    if not saved then return end
    if not saved.Humanoid.Parent or not saved.Character.Parent then self:_resetShoulder(); return end
    local target = Vector3.zero
    if self.Active then
        -- Preserve normal first-person zoom: moving its subject sideways would
        -- put the camera outside the head. Third person keeps the shoulder view.
        local distance = camera and camera.Focus and (camera.CFrame.Position - camera.Focus.Position).Magnitude
        if not distance or distance > FIRST_PERSON_DISTANCE then target = SHOULDER_OFFSET end
    end
    local alpha = 1 - math.exp(-3 * math.clamp(dt or 0, 0, 0.1) / SHOULDER_BLEND_TIME)
    saved.Value = saved.Value:Lerp(target, alpha)
    if (saved.Value - target).Magnitude < 0.0001 then saved.Value = target end
    saved.Humanoid.CameraOffset = saved.BaseOffset + saved.Value
    if not self.Active and saved.Value == Vector3.zero then self:_resetShoulder() end
end

function WeaponCamera:_release(force)
    local state = self.Active
    self.Active = nil
    if state then
        UserInputService.MouseBehavior = state.MouseBehavior
        UserInputService.MouseIconEnabled = state.MouseIconEnabled
        if self.OnAim then self.OnAim(state.Character, nil) end
        if state.Humanoid.Parent then
            if not force and dodging(state.Character) then
                -- Dodge captured AutoRotate=false while the musket was held.
                -- Restore the original value after its movement lock is released.
                self.DeferredRotation = state
            else
                state.Humanoid.AutoRotate = state.AutoRotate
            end
        end
    end
    if force then self:_resetShoulder() end
    self:_restoreDeferred(force)
end

function WeaponCamera:_allowed()
    local character = self.Player.Character
    local tool = self.Tool
    local camera = workspace.CurrentCamera
    if not UserInputService.MouseEnabled or not character or character ~= self.Character
        or not tool or tool.Parent ~= character or tool:GetAttribute("WeaponType") ~= "Musket"
        or not camera or camera.CameraType == Enum.CameraType.Scriptable
        or WeaponCamera.IsUIBlocked(self.Player)
        or character:GetAttribute("CombatUIBlocked") == true
        or (self.CanAim and not self.CanAim()) then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.Health <= 0 or not root or root.Anchored
        or humanoid.Sit or humanoid.SeatPart
        or humanoid:GetState() == Enum.HumanoidStateType.Swimming
        or humanoid:GetState() == Enum.HumanoidStateType.PlatformStanding then return end
    return humanoid, root, camera
end

function WeaponCamera:_prepare(dt)
    if self.Destroyed then return end
    self:_restoreDeferred()
    local humanoid, root, camera = self:_allowed()
    if not humanoid then self:_release(); self:_stepShoulder(dt); return end
    self:_watchHumanoid(humanoid)
    local state = self.Active
    if state and (state.Humanoid ~= humanoid or state.Root ~= root) then
        self:_release(true)
        state = nil
    end
    if not state then
        -- A dodge which began before equipping the musket owns AutoRotate until
        -- it finishes. Leave its captured facing and settings untouched.
        if dodging(self.Character) then self:_stepShoulder(dt); return end
        if self.Shoulder and self.Shoulder.Humanoid ~= humanoid then self:_resetShoulder() end
        if not self.Shoulder then
            -- One owner for CameraOffset; recoil is handled by FOV/weapon pose,
            -- so it cannot overwrite the captured offset or accumulate a drift.
            self.Shoulder = {Character = self.Character, Humanoid = humanoid,
                BaseOffset = humanoid.CameraOffset, Value = Vector3.zero}
        end
        state = {
            Character = self.Character,
            Humanoid = humanoid,
            Root = root,
            AutoRotate = humanoid.AutoRotate,
            MouseBehavior = UserInputService.MouseBehavior,
            MouseIconEnabled = UserInputService.MouseIconEnabled,
        }
        self.Active = state
    end
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    UserInputService.MouseIconEnabled = false
    humanoid.AutoRotate = false
    self:_stepShoulder(dt, camera)
end

function WeaponCamera:_face(dt)
    local state = self.Active
    if self.Destroyed or not state then return end
    local humanoid, root, camera = self:_allowed()
    if humanoid ~= state.Humanoid or root ~= state.Root then self:_release(); return end
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    UserInputService.MouseIconEnabled = false
    -- Sidestep must retain its original facing; camera orbit can continue.
    if dodging(state.Character) then return end
    humanoid.AutoRotate = false
    local look = camera.CFrame.LookVector
    local horizontal = Vector3.new(look.X, 0, look.Z)
    if self.OnAim then self.OnAim(state.Character, math.asin(math.clamp(look.Y, -1, 1))) end
    if horizontal.Magnitude < 0.0001 then return end
    local position = root.Position
    local facing = CFrame.lookAt(position, position + horizontal.Unit)
    local alpha = 1 - math.exp(-TURN_RATE * math.clamp(dt, 0, 0.1))
    -- Rotation only: the current root position is kept exactly. Humanoid and
    -- physics remain responsible for movement, gravity and wall collisions.
    root.CFrame = root.CFrame:Lerp(facing, alpha)
end

function WeaponCamera:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    RunService:UnbindFromRenderStep(self.InputStep)
    RunService:UnbindFromRenderStep(self.FacingStep)
    self:_release(true)
    self:_watchHumanoid(nil)
    for _, connection in ipairs(self.Connections) do connection:Disconnect() end
    self.Connections = {}
    self.Tool = nil
    self.Character = nil
end

return WeaponCamera
