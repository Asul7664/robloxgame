local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureRemotes()
	local folder = ReplicatedStorage:FindFirstChild("Combat") or Instance.new("Folder")
	folder.Name = "Combat"
	folder.Parent = ReplicatedStorage
	for _, name in { "Swing", "Shot", "ConfirmHit" } do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	return folder
end

local combat = ensureRemotes()
local config = require(combat:WaitForChild("Config"))
local swingRemote = combat:WaitForChild("Swing")
local shotRemote = combat:WaitForChild("Shot")
local confirmRemote = combat:WaitForChild("ConfirmHit")
local lastSwing = {}
local lastShot = {}

local function living(model)
	if not model then
		return nil
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		return hum
	end
end

local function damage(attacker, victimHum, amount)
	local model = victimHum.Parent
	if model:GetAttribute("IFrame") then
		return false
	end
	if victimHum.Parent == attacker then
		return false
	end
	victimHum:TakeDamage(amount)
	model:SetAttribute("IFrame", true)
	task.delay(0.28, function()
		if model.Parent then
			model:SetAttribute("IFrame", false)
		end
	end)
	return true
end

swingRemote.OnServerEvent:Connect(function(player, combo)
	local now = os.clock()
	if lastSwing[player] and now - lastSwing[player] < config.Saber.Cooldown then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local equipped = char and char:FindFirstChildOfClass("Tool")
	if not root or not equipped or equipped:GetAttribute("WeaponType") ~= "Saber" then
		return
	end
	lastSwing[player] = now
	local reach = combo == 3 and Vector3.new(5.2, 4.4, 6.2) or config.Saber.Hitbox
	local box = root.CFrame * CFrame.new(0, 1.1, -3.1)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local hit = false
	local seen = {}
	for _, part in workspace:GetPartBoundsInBox(box, reach, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		local hum = model and living(model)
		if hum and not seen[hum] then
			seen[hum] = true
			local amount = config.Saber.Damage + (combo == 3 and 8 or 0)
			if damage(char, hum, amount) then
				hit = true
			end
		end
	end
	confirmRemote:FireClient(player, hit)
end)

shotRemote.OnServerEvent:Connect(function(player, origin, direction)
	local now = os.clock()
	if lastShot[player] and now - lastShot[player] < config.Musket.Cooldown then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local equipped = char and char:FindFirstChildOfClass("Tool")
	if not root or not equipped or equipped:GetAttribute("WeaponType") ~= "Musket" then
		return
	end
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end
	if (origin - root.Position).Magnitude > 8 then
		origin = root.Position + Vector3.new(0, 1.4, 0)
	end
	if direction.Magnitude < 0.01 then
		return
	end
	lastShot[player] = now
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local result = workspace:Raycast(origin, direction.Unit * config.Musket.Range, params)
	if not result then
		confirmRemote:FireClient(player, false)
		return
	end
	local model = result.Instance:FindFirstAncestorOfClass("Model")
	local hum = model and living(model)
	local hit = hum and damage(char, hum, config.Musket.Damage) or false
	confirmRemote:FireClient(player, hit)
end)

local function applyHealth(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.MaxHealth = config.MaxHealth
		hum.Health = config.MaxHealth
	end
end

-- WeaponShop in QuietCove.Main grants purchased Tools from the saved profile.
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(applyHealth)
end)
for _, player in Players:GetPlayers() do
	if player.Character then
		applyHealth(player.Character)
	end
end
