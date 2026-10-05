-- Run from the repository root: lune run tests/quests.luau
-- Executes the real quest and configuration modules without Roblox services.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local function load(path, environment)
    return luau.load(fs.readFile(path), {environment=environment or {}})()
end
local expansion = load("src/shared/BrainrotExpansion.luau")
local Config = load("src/shared/Config.luau", {
    script={Parent={WaitForChild=function(_, name) return name end}},
    require=function(name) assert(name == "BrainrotExpansion"); return expansion end,
})
local Quests = load("src/shared/Quests.luau")
local checks = 0
local function check(condition, message)
    checks += 1
    assert(condition, message)
end
local function equal(actual, expected, message)
    check(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function near(actual, expected, message)
    check(math.abs(actual - expected) < 0.000001, message .. ": expected " .. expected .. ", got " .. actual)
end
local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = copy(child) end
    return out
end

local function json(value) return serde.encode("json", value) end
local function starter() return {Rod=1, XP=0, Coins=0, OwnedBoats={}} end
local function task(data, kind, id)
    for _, entry in ipairs(data.Quests[kind].Tasks) do if entry.Id == id then return entry end end
    error("Missing task " .. id)
end
local function publicId(data, kind, id) return data.Quests[kind].Key .. ":" .. id end
local function catch(data, species, zone, now, userId)
    return Quests.RecordCatch(data, Config, {Species=species, Kg=Config.ById[species].MinKg}, zone, now, userId)
end
local NOW, MONDAY = 1791176400, 1791158400 -- Monday 2026-10-05, UTC.

-- Subsecond server clocks retain activity at update and disconnect flushes.
do
    local data = starter()
    Quests.Ensure(data, Config, NOW, 93)
    for tick = 1, 4 do Quests.AddActivity(data, Config, 0.25, NOW + tick * 0.25, 93) end
    near(task(data, "Daily", "fishing_time").Progress, 1, "four quarter-second ticks retain a full second")
    Quests.AddActivity(data, Config, 0.5, NOW + 1.5, 93)
    near(task(data, "Daily", "fishing_time").Progress, 1.5, "fractional disconnect flush is counted")
    Quests.AddActivity(data, Config, 0.5, NOW + 1.5, 93)
    near(task(data, "Daily", "fishing_time").Progress, 1.5, "duplicate fractional flush cannot double count")
    near(data.Quests.ActivityAt, NOW + 1.5, "fractional ActivityAt survives Ensure")
    local boundary = starter()
    Quests.AddActivity(boundary, Config, 0.25, MONDAY - 0.25, 93)
    Quests.AddActivity(boundary, Config, 0.5, MONDAY + 0.25, 93)
    near(task(boundary, "Daily", "fishing_time").Progress, 0.25, "fractional midnight crossing credits only new-day share")
    near(task(boundary, "Weekly", "fishing_time").Progress, 0.25, "fractional Monday crossing credits only new-week share")
end

-- Both periods create independently, have five unique accessible objectives,
-- and survive a serialized profile round trip without resetting progress.
do
    local data = starter()
    local first, created = Quests.Ensure(data, Config, NOW, 42)
    check(created, "new profile generates assignments")
    equal(#first.Daily.Tasks, 5, "five daily quests")
    equal(#first.Weekly.Tasks, 5, "five weekly quests")
    equal(task(data, "Daily", "fishing_time").Target, 1200, "daily minimum active time")
    equal(task(data, "Weekly", "fishing_time").Target, 7200, "weekly active time")
    local other = starter()
    Quests.Ensure(other, Config, NOW, 42)
    equal(json(other.Quests), json(first), "same user and period generate the same assignments")
    local caught = task(data, "Daily", "species_1").Species
    catch(data, caught, "Cove", NOW, 42)
    Quests.AddActivity(data, Config, 0.5, NOW + 1, 42)
    local saved = serde.decode("json", json(data))
    saved.Quests = Quests.Clean(saved.Quests)
    Quests.Ensure(saved, Config, NOW + 2, 42)
    equal(task(saved, "Daily", "catch_total").Progress, 1, "save/rejoin catches persist")
    equal(task(saved, "Daily", "species_1").Progress, 1, "save/rejoin species persist")
    equal(task(saved, "Daily", "fishing_time").Progress, 0.5, "fractional activity persists")
    equal(saved.Quests.ActivityAt, NOW + 1, "activity duplicate guard persists")
    local before = json(saved.Quests.Daily.Tasks)
    saved.Rod, saved.XP, saved.OwnedBoats = 4, 10000, {skiff=true}
    Quests.Ensure(saved, Config, NOW + 20, 42)
    equal(json(saved.Quests.Daily.Tasks), before, "level and equipment changes never reroll existing assignments")
    local snapshot = Quests.Snapshot(saved, Config, NOW + 20, 42)
    snapshot.Daily.Tasks[1].Progress = 9999
    equal(task(saved, "Daily", "catch_total").Progress, 1, "snapshot cannot mutate profile")
end

-- Exact UTC boundaries, leap day, Sunday/Monday and rollover while online.
do
    local data = starter()
    local a = Quests.Snapshot(data, Config, 1709164799, 15) -- 2024-02-28 23:59:59
    equal(a.Daily.ResetAt, 1709164800, "leap-day midnight")
    catch(data, "capybara", "Cove", 1709164799, 15)
    local weeklyKey = data.Quests.Weekly.Key
    local b = Quests.Snapshot(data, Config, 1709164800, 15)
    equal(b.Daily.ResetAt, 1709251200, "leap day has one full day")
    check(a.Daily.Key ~= b.Daily.Key, "daily rollover changes key")
    equal(task(data, "Daily", "catch_total").Progress, 0, "daily rollover clears daily progress")
    equal(data.Quests.Weekly.Key, weeklyKey, "daily rollover retains weekly period")
    equal(task(data, "Weekly", "catch_total").Progress, 1, "daily rollover retains weekly progress")
    local sunday = Quests.Snapshot(data, Config, MONDAY - 1, 15)
    equal(sunday.Weekly.ResetAt, MONDAY, "weekly resets at Monday UTC")
    catch(data, "capybara", "Cove", MONDAY - 1, 15)
    local monday = Quests.Snapshot(data, Config, MONDAY, 15)
    equal(monday.Weekly.ResetAt, 1791763200, "Monday week lasts seven days")
    check(sunday.Weekly.Key ~= monday.Weekly.Key, "Monday rolls weekly key")
    equal(task(data, "Weekly", "catch_total").Progress, 0, "weekly rollover clears progress")
    equal(monday.ResetTimezone, "UTC", "reset timezone published")
    equal(monday.ServerNow, MONDAY, "server time is explicit")
    data.Quests.ActivityAt = MONDAY - 20
    Quests.AddActivity(data, Config, 25, MONDAY + 5, 15)
    equal(task(data, "Daily", "fishing_time").Progress, 5, "midnight interval credits only new-day time")
    equal(task(data, "Weekly", "fishing_time").Progress, 5, "Monday interval credits only new-week time")
    Quests.AddActivity(data, Config, 1, MONDAY + 5, 15)
    equal(task(data, "Daily", "fishing_time").Progress, 5, "same-second activity cannot duplicate")
    Quests.AddActivity(data, Config, 0.25, MONDAY + 6, 15)
    equal(task(data, "Daily", "fishing_time").Progress, 5.25, "fractional active time retained")
end

-- Different players and periods rotate deterministic assignments.
do
    local signatures, days = {}, {}
    for index = 1, 40 do
        local player = starter()
        local q = Quests.Snapshot(player, Config, NOW, index)
        signatures[json(q.Daily.Tasks)] = true
        local nextDay = Quests.Snapshot(starter(), Config, NOW + (index - 1) * 86400, 42)
        days[json(nextDay.Daily.Tasks)] = true
    end
    local users, periods = 0, 0
    for _ in pairs(signatures) do users += 1 end
    for _ in pairs(days) do periods += 1 end
    check(users > 10, "user seeds create varied assignments")
    check(periods > 10, "daily seeds rotate assignments")
end

-- Successful catches advance both periods and only the matching predicates.
-- Invalid records and non-catch objectives do not progress.
do
    local data = starter()
    Quests.Ensure(data, Config, NOW, 27)
    local species = task(data, "Daily", "species_1").Species
    local second = task(data, "Daily", "species_2").Species
    check(species ~= second, "species quests are distinct")
    catch(data, species, "Cove", NOW, 27)
    equal(task(data, "Daily", "catch_total").Progress, 1, "total increments once")
    equal(task(data, "Weekly", "catch_total").Progress, 1, "weekly total increments once")
    equal(task(data, "Daily", "species_1").Progress, 1, "matching species increments")
    equal(task(data, "Daily", "species_2").Progress, 0, "different species unchanged")
    equal(task(data, "Daily", "island_catch").Progress, 1, "matching island increments")
    equal(task(data, "Daily", "fishing_time").Progress, 0, "catches grant no idle time")
    local before = json(data.Quests)
    for _, invalid in ipairs({{}, {Species="cappuccino", Kg=1}, {Species=species, Kg=0},
        {Species=species, Kg=-1}, {Species=species, Kg=0/0}, {Species=species, Kg=math.huge}}) do
        check(not Quests.RecordCatch(data, Config, invalid, "Cove", NOW, 27), "invalid catch is ignored")
    end
    equal(json(data.Quests), before, "invalid catch records cannot alter quest state")
    for _ = 1, 300 do catch(data, species, "Cove", NOW, 27) end
    equal(task(data, "Daily", "catch_total").Progress, task(data, "Daily", "catch_total").Target, "progress saturates at target")
end

-- Claims are synchronous, exactly once and period-scoped, including rejoin.
do
    local data = starter()
    Quests.Ensure(data, Config, NOW, 31)
    local id = publicId(data, "Daily", "catch_total")
    local ok, reason = Quests.Claim(data, Config, "Daily", id, NOW, 31)
    check(not ok and reason == "not_completed", "unfinished claim denied")
    check(not Quests.Claim(data, Config, "Daily", "catch_total", NOW, 31), "unscoped task ID denied")
    check(not Quests.Claim(data, Config, "Monthly", id, NOW, 31), "invalid period denied")
    task(data, "Daily", "catch_total").Progress = task(data, "Daily", "catch_total").Target
    local reward
    ok, reason, reward = Quests.Claim(data, Config, "Daily", id, NOW, 31)
    check(ok and reason == "claimed", "completed claim succeeds")
    equal(data.Coins, reward, "claim changes same-profile balance")
    local saved = serde.decode("json", json(data))
    ok, reason = Quests.Claim(saved, Config, "Daily", id, NOW + 1, 31)
    check(not ok and reason == "already_claimed", "rejoin cannot claim twice")
    equal(saved.Coins, reward, "rejected claim adds no coins")
    Quests.Ensure(saved, Config, NOW + 86400, 31)
    task(saved, "Daily", "catch_total").Progress = task(saved, "Daily", "catch_total").Target
    ok, reason = Quests.Claim(saved, Config, "Daily", id, NOW + 86400, 31)
    check(not ok and reason == "unknown_task", "stale old-day click cannot claim new-day reward")
    equal(saved.Coins, reward, "stale claim leaves balance unchanged")
end

-- All five daily rewards remain impossible before 20 minutes of accepted
-- active fishing. AFK gaps and duplicate calls cannot manufacture activity.
do
    local data = starter()
    Quests.Ensure(data, Config, NOW, 70)
    for _, entry in ipairs(data.Quests.Daily.Tasks) do
        if entry.Kind ~= "activity" then entry.Progress = entry.Target end
    end
    local id = publicId(data, "Daily", "fishing_time")
    for second = 1, 1199 do Quests.AddActivity(data, Config, 1, NOW + second, 70) end
    equal(task(data, "Daily", "fishing_time").Progress, 1199, "1199 active seconds counted")
    check(not Quests.Claim(data, Config, "Daily", id, NOW + 1199, 70), "daily active quest cannot finish before20minutes")
    Quests.AddActivity(data, Config, 1, NOW + 1200, 70)
    check(Quests.Claim(data, Config, "Daily", id, NOW + 1200, 70), "daily active quest finishes after20minutes")
    local weeklyBefore = task(data, "Weekly", "fishing_time").Progress
    Quests.AddActivity(data, Config, 1, NOW + 10000, 70)
    equal(task(data, "Weekly", "fishing_time").Progress, weeklyBefore + 1, "offline/AFK gap grants only supplied active delta")
    Quests.AddActivity(data, Config, math.huge, NOW + 10001, 70)
    equal(task(data, "Weekly", "fishing_time").Progress, weeklyBefore + 1, "nonfinite activity ignored")
end

-- Eligibility matrix uses the real live pools, rod quality, daytime availability,
-- level gates and boat ownership. No night/mythical/overweight targets sneak in.
do
    local remoteSeen, sums = {}, {}
    for rodIndex = 1, #Config.Rods do
        for _, level in ipairs({1, 2, 3, 4, 7, 12}) do
            for _, boat in ipairs({false, true}) do
                for seed = 1, 16 do
                    local data = {Rod=rodIndex, XP=(level - 1) * Config.XPPerLevel, Coins=0,
                        OwnedBoats=boat and {skiff=true} or {}}
                    local q = Quests.Snapshot(data, Config, NOW + (seed % 3) * 86400, seed)
                    for _, kind in ipairs({"Daily", "Weekly"}) do
                        local total, seen, zone = 0, {}, nil
                        for _, entry in ipairs(q[kind].Tasks) do
                            check(not seen[entry.Id], "unique scoped IDs")
                            seen[entry.Id], total = true, total + entry.Reward
                            if entry.Kind == "island" then
                                zone = entry.Zone
                                local island = Config.IslandById[zone]
                                check(level >= island.Level, "assigned island level unlocked")
                                check(boat or zone == "Cove" or zone == "Reef", "no boat means no inaccessible island")
                                if zone ~= "Cove" and zone ~= "Reef" then remoteSeen[zone] = true end
                            end
                        end
                        for _, entry in ipairs(q[kind].Tasks) do
                            if entry.Kind == "species" then
                                local fish, rod = Config.ById[entry.Species], Config.Rods[rodIndex]
                                check(fish and not fish.Night and fish.Rarity <= 4, "quest species is daytime and not legendary/mythical")
                                check(Config.Eligible(fish, zone, rod.MaxKg, false, rod.Quality), "quest species is catchable at assigned island with owned rod")
                            end
                        end
                        check(total <= (kind == "Daily" and 1800 or 6500), "rewards stay within economy cap")
                        if rodIndex == 1 then equal(total, kind == "Daily" and 660 or 3000, "starter reward sum") end
                        sums[kind .. rodIndex] = total
                    end
                end
            end
        end
    end
    check(remoteSeen.Moss and remoteSeen.Dunes and remoteSeen.Bloom and remoteSeen.Storm, "every specialized island can be assigned")
    equal(sums.Daily4, 1650, "top daily reward sum")
    equal(sums.Weekly4, 6500, "top weekly reward sum")
end

-- Malformed save data is bounded and repaired without re-awarding paid tasks.
do
    local nan = 0/0
    for _, raw in ipairs({{}, {Daily="bad", Weekly=9}, {ActivityAt=nan}, {ActivityAt=math.huge}}) do
        local data = starter()
        data.Quests = Quests.Clean(raw)
        Quests.Ensure(data, Config, NOW, 92)
        equal(#data.Quests.Daily.Tasks, 5, "corrupted periods repaired")
        check(data.Quests.ActivityAt == nil or data.Quests.ActivityAt <= NOW, "corrupted clock sanitized")
    end
    local data = starter()
    Quests.Ensure(data, Config, NOW, 92)
    local paid = task(data, "Daily", "catch_total")
    paid.Claimed, paid.Progress = true, nan
    local bad = task(data, "Daily", "species_1")
    bad.Species, bad.Progress, bad.Claimed = "cappuccino", bad.Target, true
    task(data, "Daily", "fishing_time").Target = 1
    task(data, "Weekly", "species_2").Reward = math.huge
    local damagedPaid = task(data, "Daily", "species_2")
    damagedPaid.Claimed, damagedPaid.Reward = true, nan
    data.Quests.ActivityAt = NOW + 999999
    Quests.Ensure(data, Config, NOW, 92)
    check(task(data, "Daily", "catch_total").Claimed, "paid marker survives corrupted progress")
    check(task(data, "Daily", "species_1").Claimed, "removed paid species does not reopen reward")
    check(task(data, "Daily", "species_2").Claimed, "paid marker survives invalid task definition")
    check(Config.ById[task(data, "Daily", "species_1").Species] ~= nil, "removed species repaired")
    equal(task(data, "Daily", "fishing_time").Target, 1200, "corrupted time target cannot bypass20minutes")
    check(task(data, "Weekly", "species_2").Reward < math.huge, "nonfinite reward repaired")
    check(not Quests.Claim(data, Config, "Daily", publicId(data, "Daily", "catch_total"), NOW, 92), "paid corrupted task cannot award again")
    equal(data.Coins, 0, "clean/ensure never award money")
    equal(data.Quests.ActivityAt, NOW, "future activity clock repaired")
    local broken = copy(Config)
    broken.Fish, broken.ById = {}, {}
    local empty = starter()
    Quests.Ensure(empty, broken, NOW, 92)
    equal(#empty.Quests.Daily.Tasks, 2, "empty pools keep only feasible general tasks")
    local _, changed = Quests.Ensure(empty, broken, NOW, 92)
    check(not changed, "empty pool does not repeatedly reset assignments")
end

print("PASS quests: " .. checks .. " assertions; UTC resets, persistence, eligibility, reward claims, activity minimum and corrupt saves")
