-- lune run tests/combat.luau
-- Exercise real server handlers, client UI/input and procedural animation.
local Environment = require("./helpers/combat_environment")
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local V, CF = roblox.Vector3, roblox.CFrame
local checks = 0
local function check(value, label) checks += 1; assert(value, label) end
local function near(actual, expected, label) check(math.abs(actual - expected) < 1e-4, label) end
local function setup(kind)
    local env = Environment.new()
    local bank = env:Node("Folder", "Weapons", env.Storage)
    env:Weapon("Saber", bank); env:Weapon("Musket", bank)
    local player = env:AddPlayer(1, true)
    local victim, hum = env:Character("Victim")
    env:StartServer()
    -- The shop owns issuance now. Equip a purchased-model fixture explicitly;
    -- isolated CombatServer tests must not depend on its old free weapon grant.
    local tool = bank[kind or "Saber"]:Clone(); tool.Parent = player.Character
    return env, player, victim, hum, tool
end

-- CombatServer owns health/remotes, while the profile-backed shop owns weapons.
-- Loading it for existing or newly joining players must never grant free tools.
do
    local env = Environment.new()
    local bank = env:Node("Folder", "Weapons", env.Storage)
    env:Weapon("Saber", bank); env:Weapon("Musket", bank)
    local player = env:AddPlayer(1, true)
    env:StartServer()
    check(player.Character.Humanoid.Health == 100 and player.Character.Humanoid.MaxHealth == 100, "Existing player starts at 100 health")
    check(not player.Backpack.Saber and not player.Character.Saber, "CombatServer does not grant a free saber")
    check(not player.Backpack.Musket and not player.Character.Musket, "CombatServer does not grant a free musket")
    local newcomer = env:AddPlayer(2); env:Flush()
    check(not newcomer.Backpack.Saber and not newcomer.Backpack.Musket, "Joining player receives no weapons outside the shop")
    local char, hum = env:Character("Respawn")
    hum.MaxHealth = 250; hum.Health = 5
    newcomer.Character = char; newcomer.CharacterAdded:Fire(char)
    check(hum.MaxHealth == 100 and hum.Health == 100, "New player's respawn gets configured health")
    check(env.Combat.Swing:IsA("RemoteEvent") and env.Combat.Shot:IsA("RemoteEvent") and env.Combat.ConfirmHit:IsA("RemoteEvent"), "Server creates required remotes")
end

-- One humanoid may contribute several body parts to an overlap; damage must
-- happen once, and the attacker's own body can never take its own damage.
for combo = 1, 3 do
    local env, player, victim, hum = setup()
    env.BoxParts = {victim.HumanoidRootPart, victim.Torso, player.Character.Torso}
    env.Combat.Swing.OnServerEvent:Fire(player, combo)
    check(#hum.DamageCalls == 1, "Overlap deduplicates humanoid for combo " .. combo)
    check(hum.DamageCalls[1] == (combo == 3 and 26 or 18), "Server applies configured combo damage")
    check(#player.Character.Humanoid.DamageCalls == 0, "Own character is never damaged")
    check(env.Queries[1].Params.FilterDescendantsInstances[1] == player.Character, "Overlap query excludes attacker")
    check(env.Queries[1].Params.FilterType == env.Enum.RaycastFilterType.Exclude, "Overlap exclusion filter is used")
    local size = env.Queries[1].Size
    check(combo ~= 3 or size.X > 4.4 and size.Z > 5.4, "Third slash has a larger hitbox")
    check(env.Messages[#env.Messages].Args[1] == true, "Successful server hit is confirmed")
    check(victim:GetAttribute("IFrame"), "Successful hit sets server immunity")
    env:Advance(.27); check(victim:GetAttribute("IFrame"), "Hit immunity survives for 0.27 seconds")
    env:Advance(.02); check(not victim:GetAttribute("IFrame"), "Hit immunity expires after 0.28 seconds")
end

do
    local env, player, victim, hum, tool = setup()
    env.BoxParts = {victim.Torso}; victim:SetAttribute("IFrame", true)
    env.Combat.Swing.OnServerEvent:Fire(player, 1)
    check(#hum.DamageCalls == 0 and env.Messages[#env.Messages].Args[1] == false, "Existing dodge immunity prevents saber damage")
    victim:SetAttribute("IFrame", false)
    env.Combat.Swing.OnServerEvent:Fire(player, 1)
    check(#env.Queries == 1, "Immediate repeated slash is server limited")
    env:Advance(.43); env.Combat.Swing.OnServerEvent:Fire(player, 2)
    check(#hum.DamageCalls == 1, "Slash is allowed after cooldown")
    env:Advance(.43); tool.Parent = player.Backpack
    local before = #env.Queries; env.Combat.Swing.OnServerEvent:Fire(player, 1)
    check(#env.Queries == before, "Unequipped saber cannot attack")
    env:Weapon("Musket", player.Character); env.Combat.Swing.OnServerEvent:Fire(player, 1)
    check(#env.Queries == before, "Wrong weapon cannot use saber remote")
end

-- The client sends no hit target. Actual server raycasting chooses the victim,
-- caps travel length and corrects an out-of-bounds ray origin.
do
    local env, player, victim, hum = setup("Musket")
    env.RayResult = {Instance = victim.Torso}
    env.Combat.Shot.OnServerEvent:Fire(player, V.new(0, 1, 0), V.new(10, 0, 0))
    check(#hum.DamageCalls == 1 and hum.DamageCalls[1] == 28, "Server raycast musket deals 28")
    near(env.Rays[1].Direction.Magnitude, 140, "Musket ray range is normalized to 140")
    check(env.Rays[1].Params.FilterDescendantsInstances[1] == player.Character, "Shot excludes own character")
    check(env.Messages[#env.Messages].Args[1] == true, "Server confirms musket hit")
    env.Combat.Shot.OnServerEvent:Fire(player, V.zero, V.xAxis)
    check(#env.Rays == 1, "Immediate repeated shot is server limited")
    env:Advance(1.8); env.Combat.Shot.OnServerEvent:Fire(player, V.new(1000, 0, 0), V.xAxis)
    check(env.Rays[2].Origin == player.Character.HumanoidRootPart.Position + V.new(0, 1.4, 0), "Origin beyond eight studs is corrected by server")
    env:Advance(1.8); env.RayResult = nil
    env.Combat.Shot.OnServerEvent:Fire(player, V.zero, V.xAxis)
    check(env.Messages[#env.Messages].Args[1] == false, "A missed ray confirms no hit")
    env:Advance(1.8); local before = #env.Rays
    env.Combat.Shot.OnServerEvent:Fire(player, "spoofed", V.xAxis)
    env.Combat.Shot.OnServerEvent:Fire(player, V.zero, "spoofed")
    env.Combat.Shot.OnServerEvent:Fire(player, V.zero, V.zero)
    check(#env.Rays == before, "Malformed vector values and zero directions are rejected")
end
do
    local env, player, victim, hum = setup("Musket")
    env.RayResult = {Instance = victim.Torso}; victim:SetAttribute("IFrame", true)
    env.Combat.Shot.OnServerEvent:Fire(player, V.zero, V.xAxis)
    check(#hum.DamageCalls == 0 and env.Messages[#env.Messages].Args[1] == false, "Dodge immunity prevents musket damage")
    env:Advance(1.8); victim:SetAttribute("IFrame", false); hum.Health = 0
    env.Combat.Shot.OnServerEvent:Fire(player, V.zero, V.xAxis)
    check(#hum.DamageCalls == 0, "Dead targets do not receive further damage")
end

-- WeaponPlaceholders now bootstraps WeaponModels rather than constructing
-- plain tools. Compile its real source here; native tests/weapon_models cover
-- model geometry, shared construction and migration of old fallback tools.
luau.load(fs.readFile("src/combat/WeaponPlaceholders.server.luau"))

-- Run the actual procedural animator, including the hit activation callback and
-- normal completed/cancelled RenderStepped cleanup.
for combo = 1, 3 do
    local env = Environment.new()
    local char = env:Character()
    local grip = char:FindFirstChild("RightGrip", true)
    local original = CF.new(.1, .2, .3); grip.C0 = original
    local animator = env:Execute("src/combat/WeaponAnimator.luau")
    local calls = 0
    local name = animator.playSaber(char, combo, function(reply) calls += 1; reply(true) end)
    check(type(name) == "string" and #name > 0, "Animator identifies each saber pose")
    env:Advance(.1); check(calls == 0, "Saber hit callback waits through windup")
    check(grip.C0 ~= original, "Saber changes grip through actual CFrame blend")
    env:Advance(.2); check(calls == 1, "Saber activation callback fires once")
    env:Advance(.5); check(calls == 1 and env.Run.RenderStepped:Count() == 0, "Saber animation finishes and disconnects")
    check(grip.C0 == original, "Completed saber returns captured grip")
    animator.playMusket(char, "kick"); env:Advance(.4)
    check(env.Run.RenderStepped:Count() == 0 and grip.C0 == original, "Musket kick finishes and restores grip")
    animator.playSaber(char, 1); char.Parent = nil; env:Advance(.02)
    check(env.Run.RenderStepped:Count() == 0, "Removed character disconnects animator frame listener")
end

-- Client health is read-only: it changes UI, not Humanoid damage. Red responds
-- at once; the delayed yellow tween begins at the specified 0.45 second mark.
do
    local env = Environment.new(); local player = env:AddPlayer(1, true)
    env:StartClient(); env:Advance(.5)
    local gui = player.PlayerGui.HealthBar
    check(gui and gui.ResetOnSpawn, "Client mounts health bar")
    local frame = gui:FindFirstChildOfClass("Frame")
    local label = frame:FindFirstChildOfClass("TextLabel")
    local fill, ghost
    for _, child in ipairs(frame:GetChildren()) do
        if child:IsA("Frame") then
            if child.ZIndex == 2 then fill = child else ghost = child end
        end
    end
    local hum = player.Character.Humanoid
    hum.Health = 63.2; hum.HealthChanged:Fire(hum.Health)
    check(label.Text == "64 / 100", "Health label follows current and maximum health")
    near(fill.Size.X.Scale, .632, "Red bar target follows damage immediately")
    near(ghost.Size.X.Scale, 1, "Yellow health initially remains behind")
    env:Advance(.44); near(ghost.Size.X.Scale, 1, "Yellow bar waits for delay")
    env:Advance(.02); near(ghost.Size.X.Scale, .632, "Yellow bar updates after 0.45 seconds")
    check(#hum.DamageCalls == 0, "Client UI never applies damage")
end

-- Input exercises the real local script with its real animator, trail, sounds,
-- cooldown and magazine; it sends requests only during the hit-active phase.
do
    local env = Environment.new(); local player = env:AddPlayer(1, true)
    local saber = env:Weapon("Saber", player.Character); env:StartClient()
    env:Click(true); env:Advance(.3); check(#env.Requests == 0, "Processed UI/chat click is ignored")
    env:Click(); check(#env.Requests == 0, "Saber request waits for animation windup")
    local trail = saber.Blade.SwingTrail
    check(trail and trail.Enabled and trail.Attachment0 and trail.Attachment1, "Saber has active blade trail")
    env:Click(); env:Advance(.25)
    check(#env.Requests == 1 and env.Requests[1].Remote == "Swing" and env.Requests[1].Args[1] == 1, "First swing requests combo one exactly once")
    env.Combat.ConfirmHit.OnClientEvent:Fire(true)
    env:Advance(.3); check(not trail.Enabled, "Saber trail disables at completion")
    env:Click(); env:Advance(.25); check(env.Requests[2].Args[1] == 2, "Next quick slash requests combo two")
    env:Advance(.3); env:Click(); env:Advance(.25); check(env.Requests[3].Args[1] == 3, "Next quick slash requests combo three")
    env:Advance(1); env:Click(); env:Advance(.25); check(env.Requests[4].Args[1] == 1, "Combo restarts after a pause")
    check(#player.Character.Humanoid.DamageCalls == 0, "Saber client never applies damage")
    env:Advance(.4); saber.Parent = player.Backpack
    local musket = env:Weapon("Musket", player.Character)
    env:Click(); local shots = #env.Requests
    check(env.Requests[shots].Remote == "Shot", "Musket sends a shot request")
    check(env.Requests[shots].Args[1] == musket:FindFirstChild("Muzzle", true).WorldPosition, "Musket fires from its muzzle")
    check(env.Requests[shots].Args[2] == env.World.CurrentCamera.CFrame.LookVector, "Musket requests camera aim direction")
    env:Advance(.4); env:Click(); check(#env.Requests == shots, "Empty magazine prevents fire during reload")
    env:Advance(1.2); env:Click(); check(#env.Requests == shots, "Reload still blocks fire at 1.6 seconds")
    env:Advance(.11); env:Click(); check(#env.Requests == shots + 1, "Musket fires again after 1.7 seconds")
    local emissions = 0
    for _, object in ipairs(env.Objects) do if object:IsA("ParticleEmitter") then emissions += object.Emitted or 0 end end
    check(emissions >= 36, "Both musket shots emit smoke")
    check(#player.Character.Humanoid.DamageCalls == 0, "Musket client never applies damage")
end

print(string.format("Combat: %d behavior checks passed (engine doubles; visual Studio test still required).", checks))
