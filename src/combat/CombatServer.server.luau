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
local Catalog = require(ReplicatedStorage:WaitForChild("QuietCove"):WaitForChild("WeaponCatalog"))
local Damage = require(combat:WaitForChild("Damage"))
local swingRemote = combat:WaitForChild("Swing")
local shotRemote = combat:WaitForChild("Shot")
local confirmRemote = combat:WaitForChild("ConfirmHit")
local lastSwing = {}
local nextShot = {}

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
	return Damage.Apply(attacker, victimHum, amount)
end

swingRemote.OnServerEvent:Connect(function(player, combo)
	local now = os.clock()
	if combo ~= 1 and combo ~= 2 and combo ~= 3 then return end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local equipped = char and char:FindFirstChildOfClass("Tool")
	local weapon = equipped and Catalog.Resolve(equipped)
	if not root or not living(char) or not weapon or weapon.Kind ~= "Saber" then
		return
	end
	if lastSwing[player] and now-lastSwing[player] < (weapon.Cooldown or config.Saber.Cooldown) then return end
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
			local amount = combo == 3 and weapon.ComboDamage or weapon.Damage
			if damage(char, hum, amount) then
				hit = true
			end
		end
	end
	confirmRemote:FireClient(player, hit)
end)

shotRemote.OnServerEvent:Connect(function(player, origin, direction)
	local now = os.clock()
	if nextShot[player] and now < nextShot[player] then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local equipped = char and char:FindFirstChildOfClass("Tool")
	local weapon = equipped and Catalog.Resolve(equipped)
	if not root or not living(char) or not weapon or weapon.Kind ~= "Musket" then
		return
	end
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end
	for _, value in {origin.X,origin.Y,origin.Z,direction.X,direction.Y,direction.Z,direction.Magnitude} do
		if value ~= value or math.abs(value) == math.huge then return end
	end
	if (origin - root.Position).Magnitude > 8 then
		origin = root.Position + Vector3.new(0, 1.4, 0)
	end
	if direction.Magnitude < 0.01 then
		return
	end
	-- One shot per load. The reload belongs to the player, so swapping a weak
	-- gun for a stronger gun cannot reset it or shorten the shot already fired.
	nextShot[player] = now + math.max(weapon.Reload, weapon.Cooldown or config.Musket.Cooldown)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local result = workspace:Raycast(origin, direction.Unit * weapon.Range, params)
	if not result then
		confirmRemote:FireClient(player, false)
		return
	end
	local model = result.Instance:FindFirstAncestorOfClass("Model")
	local hum = model and living(model)
	local hit = hum and damage(char, hum, weapon.Damage) or false
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
local function playerAdded(player)
	player.CharacterAdded:Connect(function(char)
		lastSwing[player]=nil;nextShot[player]=nil
		applyHealth(char)
	end)
	if player.Character then applyHealth(player.Character) end
end
Players.PlayerAdded:Connect(playerAdded)
Players.PlayerRemoving:Connect(function(player) lastSwing[player]=nil;nextShot[player]=nil end)
for _, player in Players:GetPlayers() do playerAdded(player) end
