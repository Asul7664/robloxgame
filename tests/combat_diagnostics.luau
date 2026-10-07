-- lune run tests/combat_diagnostics.luau
-- Read-only probes of the preserved user-supplied combat routines. Weapon
-- ownership/issuance moved to Main.WeaponShop and is tested separately.
-- These findings are intentionally separate from passing baseline tests; they
-- do not silently fix code the user explicitly requested to preserve.
local Environment = require("./helpers/combat_environment")
local roblox = require("@lune/roblox")
local V, CF = roblox.Vector3, roblox.CFrame
local findings = {}
local function found(message) table.insert(findings, message) end
local function setup(kind)
    local env = Environment.new()
    local bank = env:Node("Folder", "Weapons", env.Storage)
    env:Weapon("Saber", bank); env:Weapon("Musket", bank)
    local player = env:AddPlayer(1, true)
    local victim = env:Character("Victim")
    env:StartServer()
    bank[kind or "Saber"]:Clone().Parent = player.Character
    return env, player, victim
end

do
    local env, player = setup("Musket")
    env.Combat.Shot.OnServerEvent:Fire(player, V.zero, V.xAxis)
    env:Advance(.9)
    env.Combat.Shot.OnServerEvent:Fire(player, V.zero, V.xAxis)
    if #env.Rays == 2 then
        found("Server accepts a second musket shot at 0.90 s: Reload=1.7 is client-only; server uses Cooldown=0.85.")
    end
end
do
    local env, player = setup("Musket")
    env.Combat.Shot.OnServerEvent:Fire(player, V.new(1000, 0, 0), V.xAxis)
    if #env.Rays == 1 then
        found("Origin farther than 8 studs is repositioned and still fires, whereas the prose request says to reject it.")
    end
end
do
    local env, player = setup()
    local nextChar, hum = env:Character("LateRespawn"); hum.MaxHealth = 200; hum.Health = 1
    player.Character = nextChar; player.CharacterAdded:Fire(nextChar)
    if hum.MaxHealth ~= 100 or hum.Health ~= 100 then
        found("Players already present when CombatServer starts do not get its CharacterAdded health hook.")
    end
end
do
    local env, player, victim = setup()
    env.BoxParts = {victim.Torso}
    player.Character.Humanoid.Health = 0
    env.Combat.Swing.OnServerEvent:Fire(player, 1)
    if #victim.Humanoid.DamageCalls > 0 then
        found("A dead attacker with an equipped tool can still invoke Swing: server validates the tool, not attacker health.")
    end
end
do
    local env, player, victim = setup()
    env.BoxParts = {victim.Torso}
    env.Combat.Swing.OnServerEvent:Fire(player, 1)
    env:Advance(.2)
    victim:SetAttribute("Dodging", true)
    victim:SetAttribute("IFrame", true) -- a subsequent server-owned dodge grant
    env:Advance(.09)
    if victim:GetAttribute("Dodging") and not victim:GetAttribute("IFrame") then
        found("The delayed hit-immunity reset clears IFrame even when a later dodge still owns its immunity window.")
    end
end
do
    local function run(fps)
        local env = Environment.new()
        local char = env:Character()
        local animator = env:Execute("src/combat/WeaponAnimator.luau")
        animator.playSaber(char, 1); env:Advance(.7, 1 / fps)
        return char:FindFirstChild("RootJoint", true).Transform,
            char:FindFirstChild("Right Shoulder", true).Transform
    end
    local thirty, shoulder = run(30)
    local hundredTwenty = run(120)
    local relative = thirty:ToObjectSpace(hundredTwenty)
    local _, _, _, a, b, c, d, e, f, g, h, i = relative:GetComponents()
    if math.abs(a - 1) + math.abs(e - 1) + math.abs(i - 1)
        + math.abs(b) + math.abs(c) + math.abs(d) + math.abs(f) + math.abs(g) + math.abs(h) > 1e-3 then
        found("Waist Transform accumulates each render frame: final torso pose differs between 30 and 120 FPS.")
    end
    if shoulder ~= CF.new() then
        found("The animator restores RightGrip after a slash but leaves its shoulder/elbow/waist Transform pose applied.")
    end
end

print("Preserved combat diagnostics: " .. #findings .. " reproducible findings.")
for index, message in ipairs(findings) do print(index .. ". " .. message) end
