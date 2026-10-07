local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer
local combat = ReplicatedStorage:WaitForChild("Combat")
local animator = require(combat:WaitForChild("WeaponAnimator"))
local swingRemote = combat:WaitForChild("Swing")
local shotRemote = combat:WaitForChild("Shot")
local confirmRemote = combat:WaitForChild("ConfirmHit")

local camera = workspace.CurrentCamera
local combo = 0
local lastSwing = 0
local busy = false
local ammo = 1
local reloading = false
local pendingHit

local function character()
	return player.Character
end

local function tool()
	local c = character()
	return c and c:FindFirstChildOfClass("Tool")
end

local function kind()
	local t = tool()
	return t and t:GetAttribute("WeaponType")
end

local function kickCamera(pitch, fov, time)
	local start = camera.FieldOfView
	TweenService:Create(camera, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = start + fov }):Play()
	task.delay(0.06, function()
		TweenService:Create(camera, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = 70 }):Play()
	end)
	local hum = character() and character():FindFirstChildOfClass("Humanoid")
	if hum then
		TweenService:Create(hum, TweenInfo.new(0.05), { CameraOffset = Vector3.new(pitch, 0.05, 0) }):Play()
		task.delay(0.05, function()
			if hum.Parent then
				TweenService:Create(hum, TweenInfo.new(0.18), { CameraOffset = Vector3.new(0, 0, 0) }):Play()
			end
		end)
	end
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
	if busy then
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
	local blade = t:FindFirstChild("Blade") or t:FindFirstChild("Handle")
	local tr = trail(blade)
	if tr then
		tr.Enabled = true
	end
	whoosh(c:FindFirstChild("HumanoidRootPart") or t)
	kickCamera(combo == 3 and 0.35 or 0.16, combo == 3 and -6 or -3, 0.2)
	animator.playSaber(c, combo, function(reply)
		pendingHit = reply
		swingRemote:FireServer(combo)
	end)
	task.delay(0.5, function()
		if tr then
			tr.Enabled = false
		end
		busy = false
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

local function musket()
	if busy or reloading or ammo <= 0 then
		return
	end
	local c = character()
	local t = tool()
	if not c or not t then
		return
	end
	busy = true
	ammo -= 1
	reloading = true
	local root = c:FindFirstChild("HumanoidRootPart")
	local muzzle = t:FindFirstChild("Muzzle", true)
	local origin = muzzle and muzzle.WorldPosition or (root.Position + Vector3.new(0, 1.4, 0))
	local dir = camera.CFrame.LookVector
	animator.playMusket(c, "kick")
	kickCamera(0.55, -8, 0.28)
	local s = Instance.new("Sound")
	s.SoundId = "rbxasset://sounds/Rocket whoosh 01.wav"
	s.Volume = 0.85
	s.PlaybackSpeed = 0.72
	s.Parent = root or t
	s:Play()
	game:GetService("Debris"):AddItem(s, 1.4)
	puff(origin, dir)
	shotRemote:FireServer(origin, dir)
	task.delay(0.35, function()
		busy = false
	end)
	task.delay(1.7, function()
		ammo = 1
		reloading = false
	end)
end

UIS.InputBegan:Connect(function(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	local k = kind()
	if k == "Saber" then
		saber()
	elseif k == "Musket" then
		musket()
	end
end)

confirmRemote.OnClientEvent:Connect(function(didHit)
	if pendingHit then
		pendingHit(didHit)
		pendingHit = nil
	end
	if didHit then
		kickCamera(0.22, -2, 0.12)
	end
end)

local function mountHealth(char)
	local hum = char:WaitForChild("Humanoid")
	local gui = Instance.new("ScreenGui")
	gui.Name = "HealthBar"
	gui.ResetOnSpawn = true
	gui.Parent = player:WaitForChild("PlayerGui")
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
	hum.HealthChanged:Connect(redraw)
end

player.CharacterAdded:Connect(mountHealth)
if player.Character then
	mountHealth(player.Character)
end
