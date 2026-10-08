local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local combat = ReplicatedStorage:WaitForChild("Combat")
local animator = require(combat:WaitForChild("WeaponAnimator"))
local config = require(combat:WaitForChild("Config"))
local WeaponCamera = require(script.Parent:WaitForChild("WeaponCamera"))
local swingRemote = combat:WaitForChild("Swing")
local shotRemote = combat:WaitForChild("Shot")
local confirmRemote = combat:WaitForChild("ConfirmHit")

local combo = 0
local lastSwing = 0
local busy = false
local ammo = 1
local reloading = false
local pendingHit
local equipped
local boundCharacter
local characterConnections = {}
local lifetimeConnections = {}
local healthGui
local characterSerial = 0
local actionSerial = 0
local activeTrail
local recoil

local function character()
	return player.Character
end

local function tool()
	return equipped and equipped.Parent == character() and equipped or nil
end

local function kind()
	local t = tool()
	return t and t:GetAttribute("WeaponType")
end

local function clearRecoil()
	local saved = recoil
	recoil = nil
	if not saved then return end
	for _, tween in ipairs(saved.Tweens) do tween:Cancel() end
	if saved.Camera.Parent then saved.Camera.FieldOfView = saved.FieldOfView end
end

local function kickCamera(fov, duration)
	clearRecoil()
	local camera = workspace.CurrentCamera
	if not camera then return end
	-- WeaponCamera owns CameraOffset, including the shoulder framing. Recoil
	-- uses FOV and the existing weapon pose without pulling that framing back.
	local saved = {Camera = camera, FieldOfView = camera.FieldOfView, Tweens = {}}
	recoil = saved
	local function tween(object, seconds, properties)
		local value = TweenService:Create(object, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
		table.insert(saved.Tweens, value)
		value:Play()
	end
	tween(camera, .06, {FieldOfView = saved.FieldOfView + fov})
	task.delay(.06, function()
		if recoil ~= saved then return end
		if camera.Parent then tween(camera, duration, {FieldOfView = saved.FieldOfView}) end
	end)
	task.delay(.06 + duration, function()
		if recoil == saved then clearRecoil() end
	end)
end

local weaponCamera = WeaponCamera.new(player, function()
	local c = character()
	return c ~= nil and c:GetAttribute("CombatUIBlocked") ~= true
end, function(c, pitch)
	animator.setAimPitch(c, pitch or 0)
end)

-- A drawn reticle needs no uploaded image asset and stays aligned with the
-- viewport centre, including the top-bar inset. It never captures mouse input.
local aimGui = Instance.new("ScreenGui")
aimGui.Name = "MusketAim"
aimGui.ResetOnSpawn = false
aimGui.IgnoreGuiInset = true
aimGui.DisplayOrder = 30
aimGui.Enabled = false
aimGui.Parent = player:WaitForChild("PlayerGui")
local reticle = Instance.new("Frame")
reticle.Name = "Reticle"
reticle.AnchorPoint = Vector2.new(.5, .5)
reticle.Position = UDim2.fromScale(.5, .5)
reticle.Size = UDim2.fromOffset(32, 32)
reticle.BackgroundTransparency = 1
reticle.Active = false
reticle.Parent = aimGui
local function mark(name, size, position, color, round, stroke)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(.5, .5)
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = stroke and 1 or 0
	frame.BorderSizePixel = 0
	frame.Active = false
	frame.Parent = reticle
	if round then Instance.new("UICorner", frame).CornerRadius = UDim.new(1, 0) end
	if stroke then
		local line = Instance.new("UIStroke")
		line.Color = color; line.Thickness = stroke; line.Parent = frame
	end
	return frame
end
local white = Color3.fromRGB(236, 240, 234)
local dark = Color3.fromRGB(37, 52, 52)
mark("Outline", UDim2.fromOffset(19, 19), UDim2.fromScale(.5, .5), dark, true, 4)
mark("Ring", UDim2.fromOffset(19, 19), UDim2.fromScale(.5, .5), white, true, 2)
mark("Dot", UDim2.fromOffset(3, 3), UDim2.fromScale(.5, .5), white, true)
for _, offset in ipairs({Vector2.new(-14, 0), Vector2.new(14, 0), Vector2.new(0, -14), Vector2.new(0, 14)}) do
	local vertical = offset.X == 0
	mark("TickOutline", UDim2.fromOffset(vertical and 4 or 7, vertical and 7 or 4),
		UDim2.new(.5, offset.X, .5, offset.Y), dark, true)
	mark("Tick", UDim2.fromOffset(vertical and 2 or 5, vertical and 5 or 2),
		UDim2.new(.5, offset.X, .5, offset.Y), white, true)
end
local function syncReticle()
	aimGui.Enabled = weaponCamera:IsAiming() and not WeaponCamera.IsUIBlocked(player)
end
table.insert(lifetimeConnections, RunService.RenderStepped:Connect(syncReticle))

local function canAttack()
	local c = character()
	local h = c and c:FindFirstChildOfClass("Humanoid")
	return tool() ~= nil and h ~= nil and h.Health > 0 and not h.Sit and not h.SeatPart
		and not WeaponCamera.IsUIBlocked(player)
		and c:GetAttribute("CombatUIBlocked") ~= true
		and c:GetAttribute("Dodging") ~= true and c:GetAttribute("LocalDodgeActive") ~= true
		and os.clock() >= (c:GetAttribute("LocalDodgePendingUntil") or 0)
		and c:GetAttribute("Stunned") ~= true and h:GetAttribute("Stunned") ~= true
end

local function cancelAction()
	actionSerial += 1
	busy = false
	pendingHit = nil
	if activeTrail then activeTrail.Enabled = false; activeTrail = nil end
	if boundCharacter then boundCharacter:SetAttribute("CombatAttacking", false) end
	clearRecoil()
end

local function setEquipped(value)
	if equipped == value then return end
	cancelAction()
	equipped = value
	weaponCamera:SetTool(value)
	syncReticle()
	if boundCharacter then animator.setWeapon(boundCharacter, value) end
end

local function trail(blade)
	if not blade or blade:FindFirstChild("SwingTrail") then
		return blade and blade:FindFirstChild("SwingTrail")
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, blade.Size.Y * 0.45, 0)
	a0.Parent = blade
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -blade.Size.Y * 0.35, 0)
	a1.Parent = blade
	local tr = Instance.new("Trail")
	tr.Name = "SwingTrail"
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Lifetime = 0.16
	tr.LightEmission = 0.4
	tr.Color = ColorSequence.new(Color3.fromRGB(235, 230, 214), Color3.fromRGB(168, 146, 96))
	tr.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	tr.Enabled = false
	tr.Parent = blade
	return tr
end

local function whoosh(parent)
	local s = Instance.new("Sound")
	s.SoundId = "rbxasset://sounds/swordslash.wav"
	s.Volume = 0.7
	s.PlaybackSpeed = 0.92 + math.random() * 0.16
	s.Parent = parent
	s:Play()
	game:GetService("Debris"):AddItem(s, 1)
end

local function saber()
	if busy or not canAttack() then
		return
	end
	local c = character()
	local t = tool()
	if not c or not t then
		return
	end
	if os.clock() - lastSwing > 0.85 then
		combo = 0
	end
	combo = (combo % 3) + 1
	lastSwing = os.clock()
	busy = true
	c:SetAttribute("CombatAttacking", true)
	actionSerial += 1
	local serial = actionSerial
	local swingCombo = combo
	local blade = t:FindFirstChild("Blade") or t:FindFirstChild("Handle")
	local tr = trail(blade)
	activeTrail = tr
	animator.playSaber(c, swingCombo, function(reply)
		if actionSerial ~= serial or character() ~= c or tool() ~= t then return end
		pendingHit = {Reply = reply, Character = c, Tool = t, Serial = serial}
		if tr then tr.Enabled = true end
		whoosh(c:FindFirstChild("HumanoidRootPart") or t)
		kickCamera(swingCombo == 3 and -4 or -2, .2)
		swingRemote:FireServer(swingCombo)
		task.delay(config.Saber.Active, function()
			if actionSerial == serial and tr then tr.Enabled = false end
		end)
	end, function()
		if actionSerial ~= serial then return end
		if tr then tr.Enabled = false end
		activeTrail = nil
		pendingHit = nil
		busy = false
		c:SetAttribute("CombatAttacking", false)
	end)
end

local function puff(origin, dir)
	local p = Instance.new("Part")
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Transparency = 1
	p.CanCollide = false
	p.Anchored = true
	p.CFrame = CFrame.new(origin, origin + dir)
	p.Parent = workspace
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
	pe.Lifetime = NumberRange.new(0.25, 0.5)
	pe.Speed = NumberRange.new(4, 9)
	pe.Size = NumberSequence.new(0.4, 1.6)
	pe.Transparency = NumberSequence.new(0.3, 1)
	pe.Parent = p
	pe:Emit(18)
	local flash = Instance.new("PointLight")
	flash.Brightness = 4
	flash.Range = 12
	flash.Color = Color3.fromRGB(255, 186, 92)
	flash.Parent = p
	game:GetService("Debris"):AddItem(p, 0.7)
end

local function shotDirection(c, camera, origin)
	local forward = camera.CFrame.LookVector
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {c}
	-- Aim through the reticle, then converge from the actual muzzle. A parallel
	-- muzzle ray would miss the reticle after moving the camera to the shoulder.
	-- The camera can be zoomed far behind the player; cover the complete muzzle
	-- range from there while leaving the server's weapon range unchanged.
	local aimDistance = config.Musket.Range + (origin - camera.CFrame.Position).Magnitude
	local farPoint = camera.CFrame.Position + forward * aimDistance
	local hit = workspace:Raycast(camera.CFrame.Position, forward * aimDistance, params)
	local point = hit and hit.Position or farPoint
	local direction = point - origin
	-- Close camera occluders can be behind the muzzle: never shoot backwards.
	if direction.Magnitude < .001 or direction:Dot(forward) <= 0 then direction = farPoint - origin end
	return direction.Magnitude > .001 and direction.Unit or forward
end

local function musket()
	if busy or reloading or ammo <= 0 or not canAttack() then
		return
	end
	local c = character()
	local t = tool()
	if not c or not t then
		return
	end
	busy = true
	c:SetAttribute("CombatAttacking", true)
	actionSerial += 1
	local serial = actionSerial
	local life = characterSerial
	ammo -= 1
	reloading = true
	local root = c:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not root or not camera then
		ammo += 1; reloading = false; cancelAction(); return
	end
	local muzzle = t:FindFirstChild("Muzzle", true)
	local origin = muzzle and muzzle.WorldPosition or (root.Position + Vector3.new(0, 1.4, 0))
	local dir = shotDirection(c, camera, origin)
	animator.playMusket(c, "kick")
	kickCamera(-8, .28)
	local s = Instance.new("Sound")
	s.SoundId = "rbxasset://sounds/Rocket whoosh 01.wav"
	s.Volume = 0.85
	s.PlaybackSpeed = 0.72
	s.Parent = root or t
	s:Play()
	game:GetService("Debris"):AddItem(s, 1.4)
	puff(origin, dir)
	pendingHit = {Character = c, Tool = t, Serial = serial}
	shotRemote:FireServer(origin, dir)
	task.delay(0.35, function()
		if actionSerial == serial then
			busy = false
			c:SetAttribute("CombatAttacking", false)
		end
	end)
	task.delay(config.Musket.Reload, function()
		-- Switching weapons does not bypass reloading; respawn invalidates it.
		if characterSerial == life and character() == c then
			ammo = config.Musket.Magazine
			reloading = false
		end
	end)
end

table.insert(lifetimeConnections, UIS.InputBegan:Connect(function(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	local k = kind()
	if k == "Saber" then
		saber()
	elseif k == "Musket" then
		musket()
	end
end))

table.insert(lifetimeConnections, confirmRemote.OnClientEvent:Connect(function(didHit)
	local pending = pendingHit
	if pending and pending.Character == character() and pending.Tool == tool() and pending.Serial == actionSerial then
		if pending.Reply then pending.Reply(didHit) end
		pendingHit = nil
		if didHit and canAttack() then kickCamera(-2, .12) end
	end
end))

local function mountHealth(char)
	local hum = char:WaitForChild("Humanoid")
	local gui = Instance.new("ScreenGui")
	gui.Name = "HealthBar"
	gui.ResetOnSpawn = true
	gui.Parent = player:WaitForChild("PlayerGui")
	healthGui = gui
	local root = Instance.new("Frame")
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.new(0.5, 0, 1, -36)
	root.Size = UDim2.fromOffset(420, 28)
	root.BackgroundColor3 = Color3.fromRGB(18, 16, 14)
	root.BorderSizePixel = 0
	root.Parent = gui
	Instance.new("UICorner", root).CornerRadius = UDim.new(0, 4)
	local ghost = Instance.new("Frame")
	ghost.Size = UDim2.fromScale(1, 1)
	ghost.BackgroundColor3 = Color3.fromRGB(196, 154, 62)
	ghost.BorderSizePixel = 0
	ghost.Parent = root
	Instance.new("UICorner", ghost).CornerRadius = UDim.new(0, 4)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(154, 42, 36)
	fill.BorderSizePixel = 0
	fill.ZIndex = 2
	fill.Parent = root
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(236, 226, 208)
	label.ZIndex = 3
	label.Parent = root
	local function redraw(health)
		local ratio = math.clamp(health / hum.MaxHealth, 0, 1)
		label.Text = string.format("%d / %d", math.ceil(health), math.ceil(hum.MaxHealth))
		TweenService:Create(fill, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromScale(ratio, 1) }):Play()
		task.delay(0.45, function()
			if ghost.Parent then
				TweenService:Create(ghost, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromScale(ratio, 1) }):Play()
			end
		end)
	end
	redraw(hum.Health)
	local connection = hum.HealthChanged:Connect(redraw)
	gui.Destroying:Connect(function() connection:Disconnect() end)
end

local function unbindCharacter()
	cancelAction()
	weaponCamera:SetTool(nil)
	syncReticle()
	if boundCharacter then animator.stop(boundCharacter) end
	for _, connection in ipairs(characterConnections) do connection:Disconnect() end
	characterConnections = {}
	if healthGui then healthGui:Destroy(); healthGui = nil end
	equipped = nil
	boundCharacter = nil
	characterSerial += 1
end

local function bindCharacter(c)
	unbindCharacter()
	boundCharacter = c
	combo = 0; lastSwing = 0; ammo = config.Musket.Magazine; reloading = false
	c:SetAttribute("CombatAttacking", false)
	local function updateTool()
		setEquipped(c:FindFirstChildOfClass("Tool"))
	end
	table.insert(characterConnections, c.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then updateTool() end
	end))
	table.insert(characterConnections, c.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then updateTool() end
	end))
	local hum = c:WaitForChild("Humanoid")
	if boundCharacter ~= c then return end
	table.insert(characterConnections, hum.Died:Connect(function()
		cancelAction(); weaponCamera:SetTool(nil); animator.stop(c)
		syncReticle()
		equipped = nil
	end))
	updateTool()
	mountHealth(c)
end

table.insert(lifetimeConnections, player.CharacterAdded:Connect(bindCharacter))
table.insert(lifetimeConnections, player.CharacterRemoving:Connect(function(c)
	if boundCharacter == c then unbindCharacter() end
end))
script.Destroying:Connect(function()
	unbindCharacter(); weaponCamera:Destroy()
	aimGui:Destroy()
	for _, connection in ipairs(lifetimeConnections) do connection:Disconnect() end
	lifetimeConnections = {}
end)
if player.Character then
	bindCharacter(player.Character)
end
