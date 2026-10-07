-- Run from the repository root: lune run tests/weapon_shop.luau
-- Exercise the actual Main -> WeaponShop -> Profiles transaction and respawn
-- path, with deterministic service, Tool and datastore doubles.
local Environment = require("./helpers/server_environment")
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local V = roblox.Vector3
local checks = 0
local function check(condition, label)
    checks += 1
    assert(condition, label)
end
local function server(id, tester)
    local env = Environment.new(); env:Start()
    local player = env:Player(id, tester); env.Players.PlayerAdded:Fire(player)
    return env, player, env.Profiles.Get(player)
end
local function approach(env, player)
    player.Character.HumanoidRootPart.Position = env.WeaponCounter.Position + V.new(0, 0, 4)
end
local function tools(player, id)
    local found = {}
    for _, parent in ipairs({player.Character, player.Backpack}) do
        for _, tool in ipairs(parent:GetChildren()) do
            if tool:IsA("Tool") and tool:GetAttribute("WeaponType") == id then table.insert(found, tool) end
        end
    end
    return found
end
local function buy(env, player, id)
    -- Main's existing Action RemoteEvent owns the shop route and rate limit.
    env:Fire(player, "WeaponBuy", "", id)
end
local function messageCount(env, player, kind)
    local count = 0
    for _, message in ipairs(env.messages) do
        if message.Player == player and message.Kind == kind then count += 1 end
    end
    return count
end
local function shop(env, player)
    env.WeaponCounter.WeaponShopPrompt.Triggered:Fire(player)
    return env:Last(player, "WeaponShop")
end

do
    local env, player, data = server(701)
    local catalog = env.modules.WeaponCatalog
    local combat = luau.load(fs.readFile("src/combat/Config.luau"), {environment = {Vector3 = V}})()
    check(#catalog.List == 2 and catalog.List[1].Id == "Saber" and catalog.List[2].Id == "Musket",
        "Shop displays Saber first and Musket second")
    check(catalog.ById.Saber.Damage == combat.Saber.Damage
        and catalog.ById.Saber.ComboDamage == combat.Saber.Damage + 8,
        "Saber shop damage and third combo damage match the existing combat")
    check(catalog.ById.Musket.Damage == combat.Musket.Damage
        and catalog.ById.Musket.Reload == combat.Musket.Reload
        and catalog.ById.Musket.Range == combat.Musket.Range,
        "Musket shop damage, range and reload match the existing combat")
    check(type(data.OwnedWeapons) == "table" and next(data.OwnedWeapons) == nil,
        "New saved profiles have empty weapon ownership")
    check(#tools(player, "Saber") == 0 and #tools(player, "Musket") == 0,
        "New players are not issued free weapons by profile load")
    check(shop(env, player) == nil, "Remote shop cannot open away from the physical stall")
    approach(env, player)
    local payload = shop(env, player)
    check(payload ~= nil, "Stall prompt opens the existing server Update route when nearby")
    check(not data.OwnedWeapons.Saber and not data.OwnedWeapons.Musket and data.Coins == 0,
        "Opening the shop never grants ownership or charges currency")
    data.Coins = 1200
    buy(env, player, "Saber")
    check(data.Coins == 950 and data.OwnedWeapons.Saber == true,
        "Saber costs exactly the server catalog price of 250")
    check(#tools(player, "Saber") == 1 and #tools(player, "Musket") == 0,
        "Saber purchase clones only the purchased template once")
    local saber = tools(player, "Saber")[1]
    check(saber ~= env.Weapons.Saber and saber.Handle ~= env.Weapons.Saber.Handle,
        "Owned Tool and Handle are separate clones of ServerStorage templates")
    check(env.Weapons.Saber.Parent == env.Weapons and env.Weapons.Musket.Parent == env.Weapons,
        "Purchasing never removes stock templates from ServerStorage")
    check(env:Last(player, "Profile").Data.Coins == 950
        and env:Last(player, "Profile").Data.OwnedWeapons.Saber == true,
        "Currency and ownership are synchronized through the ordinary profile snapshot")
    buy(env, player, "Saber")
    check(data.Coins == 950 and #tools(player, "Saber") == 1,
        "Repeated owned Saber request never charges again or duplicates its Tool")
    check(tools(player, "Saber")[1].Parent == player.Character,
        "Selecting an already owned weapon equips it")
    buy(env, player, "Musket")
    check(data.Coins == 50 and data.OwnedWeapons.Musket == true,
        "Musket costs exactly the server catalog price of 900")
    check(#tools(player, "Saber") == 1 and #tools(player, "Musket") == 1,
        "Both weapon types can be owned without losing or duplicating either")
    check(player.leaderstats.Coins.Value == 50, "Weapon purchase updates existing coin leaderstats")
    env:Advance(1)
    buy(env, player, "Musket")
    check(data.Coins == 50 and #tools(player, "Musket") == 1,
        "Repeated owned Musket selection is also free and idempotent")

    -- Simulate Roblox rebuilding the character/backpack after death.
    for _, tool in ipairs(player.Backpack:GetChildren()) do tool:Destroy() end
    env:Reset(player)
    check(#tools(player, "Saber") == 1 and #tools(player, "Musket") == 1,
        "Main's CharacterAdded path restores both purchased weapons after respawn")
    check(data.Coins == 50, "Respawn grants do not buy again or alter currency")
    check(player.Character:FindFirstChildOfClass("Tool"):GetAttribute("QuietCoveRod") == true,
        "Respawn retains ordinary rod equip behavior")
    env:Reset(player)
    check(#tools(player, "Saber") == 1 and #tools(player, "Musket") == 1,
        "Repeated CharacterAdded grants deduplicate existing backpack weapons")
    env:Leave(player)
    check(env.documents.u_701.Data.Coins == 50
        and env.documents.u_701.Data.OwnedWeapons.Saber == true
        and env.documents.u_701.Data.OwnedWeapons.Musket == true,
        "Actual lease save persists currency together with both ownership flags")
    local rejoin = env:Player(701); env.Players.PlayerAdded:Fire(rejoin)
    local loaded = env.Profiles.Get(rejoin)
    check(loaded.Coins == 50 and loaded.OwnedWeapons.Saber and loaded.OwnedWeapons.Musket,
        "Actual profile cleaner and load preserve both purchases on rejoin")
    check(#tools(rejoin, "Saber") == 1 and #tools(rejoin, "Musket") == 1,
        "Main's initial load path restores purchased weapons on a new session")
end

do
    local env, player, data = server(702)
    approach(env, player); data.Coins = 249
    buy(env, player, "Saber")
    check(data.Coins == 249 and not data.OwnedWeapons.Saber and #tools(player, "Saber") == 0,
        "Insufficient coins cannot create a Saber or ownership flag")
    data.Coins = 899
    buy(env, player, "Musket")
    check(data.Coins == 899 and not data.OwnedWeapons.Musket and #tools(player, "Musket") == 0,
        "Insufficient coins cannot create a Musket or ownership flag")
    data.Coins = 5000
    for _, forged in ipairs({"saber", "Sword", "", {}, 250,
        {Id = "Saber", Price = 0, Damage = 99999}}) do
        env:Advance(1); buy(env, player, forged)
    end
    check(data.Coins == 5000 and next(data.OwnedWeapons) == nil,
        "Unknown IDs and client supplied price/damage tables cannot buy any weapon")
    check(#tools(player, "Saber") == 0 and #tools(player, "Musket") == 0,
        "Malformed purchases do not leak Tool instances")
end

do
    local env, player, data = server(703)
    approach(env, player); data.Coins = 1500
    env.Weapons.Saber.Parent = nil
    buy(env, player, "Saber")
    check(data.Coins == 1500 and not data.OwnedWeapons.Saber,
        "Missing stock template is detected before currency or ownership changes")
    env.Weapons.Musket:SetAttribute("WeaponType", "Saber")
    buy(env, player, "Musket")
    check(data.Coins == 1500 and not data.OwnedWeapons.Musket,
        "Wrong template WeaponType is detected before charging")
    env.Weapons.Musket:SetAttribute("WeaponType", "Musket")
    env.Weapons.Musket.Handle:Destroy()
    buy(env, player, "Musket")
    check(data.Coins == 1500 and not data.OwnedWeapons.Musket,
        "A broken template without its Handle cannot charge the player")
end

do
    local env, player, data = server(710)
    approach(env, player); data.Coins = 1500
    env.Weapons.Saber.Archivable = false
    buy(env, player, "Saber")
    check(data.Coins == 1500 and not data.OwnedWeapons.Saber,
        "An uncloneable template is rejected before charging")
    env.Weapons.Saber.Archivable = true
    env.Weapons.Musket.Handle:Destroy()
    local invalidHandle = env.Weapons.Saber:Clone()
    invalidHandle.Name = "Handle"; invalidHandle.Parent = env.Weapons.Musket
    buy(env, player, "Musket")
    check(data.Coins == 1500 and not data.OwnedWeapons.Musket,
        "A template whose Handle is not a BasePart cannot charge the player")
    player.Backpack.Parent = nil
    buy(env, player, "Saber")
    check(data.Coins == 1500 and not data.OwnedWeapons.Saber,
        "Missing Backpack is rejected without charging or ownership changes")
end

do
    local env = Environment.new(); env:Start()
    local player = env:Player(711)
    env.Weapons.Saber:Clone().Parent = player.Backpack
    env.Weapons.Musket:Clone().Parent = player.Character
    local unrelated = env.Weapons.Saber:Clone()
    unrelated:SetAttribute("WeaponType", "UnrelatedEquipment"); unrelated.Parent = player.Backpack
    env.Players.PlayerAdded:Fire(player)
    local data = env.Profiles.Get(player)
    check(#tools(player, "Saber") == 0 and #tools(player, "Musket") == 0,
        "Initial ownership grant retires the old unconditional Saber and Musket gifts")
    check(unrelated.Parent == player.Backpack and not unrelated.Destroyed,
        "Migration preserves unrelated equipment")
    approach(env, player); data.Coins = 1500
    buy(env, player, "Saber")
    env.Weapons.Saber:Clone().Parent = player.Backpack
    check(#tools(player, "Saber") == 2, "Duplicate cleanup fixture contains two copies")
    buy(env, player, "Saber")
    check(#tools(player, "Saber") == 1 and data.Coins == 1250,
        "Owned selection removes an existing duplicate while remaining free")
    check(unrelated.Parent == player.Backpack and not unrelated.Destroyed,
        "Purchased weapon grants preserve unrelated equipment too")
end

do
    local env, player, data = server(704)
    data.Coins = 1500
    buy(env, player, "Saber")
    check(data.Coins == 1500 and not data.OwnedWeapons.Saber,
        "Forged purchase RemoteEvent is rejected beyond 18 studs")
    approach(env, player); player.Character.Humanoid.Health = 0
    buy(env, player, "Saber")
    check(data.Coins == 1500 and not data.OwnedWeapons.Saber,
        "Dead character cannot buy a weapon")
    check(shop(env, player) == nil, "Dead character cannot open the stall")
    player.Character.Humanoid.Health = 100; player.Character.Humanoid.SeatPart = {}
    buy(env, player, "Musket")
    check(data.Coins == 1500 and not data.OwnedWeapons.Musket,
        "Seated/boat character cannot buy a weapon")
    check(shop(env, player) == nil, "Seated character cannot open the stall")
end

do
    local env, player, data = server(712)
    data.Coins = 1500
    player.Character.HumanoidRootPart.Position = env.WeaponCounter.Position + V.new(18.01, 0, 0)
    buy(env, player, "Saber")
    check(data.Coins == 1500 and not data.OwnedWeapons.Saber,
        "Purchase rejects positions just beyond the 18 stud server boundary")
    player.Character.HumanoidRootPart.Position = env.WeaponCounter.Position + V.new(18, 0, 0)
    buy(env, player, "Saber")
    check(data.Coins == 1250 and data.OwnedWeapons.Saber,
        "Purchase accepts the exact 18 stud boundary")
    player.Character = nil
    buy(env, player, "Musket")
    check(data.Coins == 1250 and not data.OwnedWeapons.Musket,
        "Character replacement gap cannot purchase a weapon")
end

do
    local env, player, data = server(705)
    data.Coins = 1500
    env:Fire(player, "Begin")
    check(env:Last(player, "Stage").Stage == "Charging", "Fishing fixture enters a real server session")
    approach(env, player)
    buy(env, player, "Saber")
    check(data.Coins == 1500 and not data.OwnedWeapons.Saber,
        "An active fishing session prevents weapon purchase")
    check(shop(env, player) == nil, "An active fishing session prevents opening the stall")
end

do
    local env, player, data = server(706)
    approach(env, player); data.Coins = 1500
    env:Fire(player, "Dodge", "Left", 1)
    check(env:Last(player, "DodgeResult").Allowed == true, "Dodge fixture gets real server approval")
    buy(env, player, "Saber")
    check(data.Coins == 1500 and not data.OwnedWeapons.Saber,
        "An active server dodge prevents weapon purchase")
    check(shop(env, player) == nil, "An active server dodge prevents opening the stall")
    env:Advance(.3)
    buy(env, player, "Saber")
    check(data.Coins == 1250 and data.OwnedWeapons.Saber,
        "Purchase is available again when the existing dodge finishes")
end

do
    local env = Environment.new()
    local player = env:Player(707)
    check(env.Profiles.Load(player), "Cleaner fixture acquires the actual profile lease")
    local data = env.Profiles.Get(player)
    data.Coins, data.XP, data.TotalCaught = 1234, 876, 7
    data.OwnedWeapons = {Saber = true, Musket = false, Sword = true, Axe = true, saber = true, Extra = 1}
    data.Visited = {Cove = true, Reef = true}
    data.Bestiary.capybara = true
    env.Profiles.Save(player, true); env.Profiles.Load(player)
    local loaded = env.Profiles.Get(player)
    check(loaded.OwnedWeapons.Saber == true and loaded.OwnedWeapons.Musket == nil,
        "Cleaner accepts only true ownership flags")
    check(loaded.OwnedWeapons.Sword == nil and loaded.OwnedWeapons.Axe == nil
        and loaded.OwnedWeapons.saber == nil and loaded.OwnedWeapons.Extra == nil,
        "Cleaner discards unknown, incorrectly cased and non-boolean weapon ownership")
    check(loaded.Coins == 1234 and loaded.XP == 876 and loaded.TotalCaught == 7,
        "Adding weapon ownership preserves existing currency, experience and catches")
    check(loaded.Visited.Cove and loaded.Visited.Reef and loaded.Bestiary.capybara,
        "Adding weapon ownership preserves discovery and bestiary data")
end

do
    local env = Environment.new(); env:Start()
    local originalPlayer = env:Player(708)
    check(env.Profiles.Load(originalPlayer), "Tester fixture opens a normal persistent profile")
    local real = env.Profiles.Get(originalPlayer)
    real.Coins = 73
    env.Profiles.Save(originalPlayer, true)
    local original = Environment.Copy(env.documents.u_708.Data)
    originalPlayer.Parent = nil
    local tester = env:Player(708, true); env.Players.PlayerAdded:Fire(tester)
    approach(env, tester)
    local sandbox = env.Profiles.Get(tester)
    local coins = sandbox.Coins
    buy(env, tester, "Saber"); buy(env, tester, "Musket")
    check(sandbox.TestMode == true and sandbox.Coins == coins,
        "Tester buys both weapons for free in the throwaway profile")
    check(sandbox.OwnedWeapons.Saber and sandbox.OwnedWeapons.Musket
        and #tools(tester, "Saber") == 1 and #tools(tester, "Musket") == 1,
        "Tester can use both real Tool templates in the ephemeral session")
    check(env.Profiles.Records[tester].Data.Coins == 73
        and next(env.Profiles.Records[tester].Data.OwnedWeapons) == nil,
        "Tester purchases never mutate the underlying published profile record")
    env:Leave(tester)
    local saved = env.documents.u_708.Data
    check(saved.Coins == original.Coins and next(saved.OwnedWeapons) == nil,
        "Actual tester leave/save cannot persist free weapons or sandbox coins")
end

do
    local env, player, data = server(709)
    approach(env, player); data.Coins = 5000
    local before = messageCount(env, player, "Profile")
    -- The Main token bucket accepts a small burst, then suppresses additional
    -- traffic; idempotency must still preserve ownership/currency in that burst.
    for _ = 1, 30 do buy(env, player, "Saber") end
    check(data.Coins == 4750 and #tools(player, "Saber") == 1,
        "Burst replay cannot duplicate a purchase even before rate limiting")
    check(messageCount(env, player, "Profile") - before <= 4,
        "WeaponBuy uses Main's existing two-per-second action rate bucket")
end

print("PASS weapon shop integration: " .. checks .. " checks (real Main/WeaponShop/Profiles)")
