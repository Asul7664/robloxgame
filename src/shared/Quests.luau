-- Server-owned daily/weekly objectives. State lives in the existing player profile.
-- All clocks are injected UTC Unix timestamps; this module never yields or saves.
local Quests = {}
local DAY, WEEK = 86400, 604800
local MAX_TIME, MAX_COINS = 7258118400, 1000000000
local ORDER = {"catch_total", "species_1", "species_2", "island_catch", "fishing_time"}
local KINDS = {catch_total="catch", species_1="species", species_2="species", island_catch="island", fishing_time="activity"}

local function finite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end
local function number(value, lo, hi, fallback, whole)
    if not finite(value) then return fallback end
    value = math.clamp(value, lo, hi)
    return whole and math.floor(value) or value
end
local function identifier(value)
    return type(value) == "string" and #value <= 80 and value:match("^[%w_%-]+$") ~= nil
end
local function timestamp(now)
    -- ServerTimeNow has subsecond precision. Keep it for interval accounting;
    -- only periodInfo rounds to whole UTC days.
    return number(now, 0, MAX_TIME, os.time(), false)
end
local function periodInfo(kind, now)
    local day = math.floor(now / DAY)
    if kind == "Daily" then
        return "d:" .. day, (day + 1) * DAY, day * DAY
    end
    -- 1970-01-01 was Thursday; week starts on Monday at 00:00 UTC.
    local week = math.floor((day + 3) / 7)
    local start = (week * 7 - 3) * DAY
    return "w:" .. week, start + WEEK, start
end
local function randomFor(userId, key)
    local hash = number(userId, 0, 9007199254740991, 0, true) % 2147483647
    for index = 1, #key do hash = (hash * 31 + key:byte(index)) % 2147483647 end
    if hash == 0 then hash = 1 end
    return function(lo, hi)
        hash = (hash * 48271) % 2147483647
        return lo + hash % (hi - lo + 1)
    end
end

local LIMITS = {
    Daily={catch_total={60,80,100,250}, species_1={10,14,120,300}, species_2={10,14,120,300},
        island_catch={25,35,120,300}, fishing_time={1200,86400,200,500}},
    Weekly={catch_total={200,260,600,1300}, species_1={40,60,550,1192}, species_2={40,60,550,1192},
        island_catch={90,120,500,1083}, fishing_time={7200,604800,800,1733}},
}
local function cleanTask(raw, kind)
    if type(raw) ~= "table" or not KINDS[raw.Id] or raw.Kind ~= KINDS[raw.Id] then return nil end
    local limits = LIMITS[kind][raw.Id]
    if not finite(raw.Target) or raw.Target < limits[1] or raw.Target > limits[2] then return nil end
    if not finite(raw.Reward) or raw.Reward < limits[3] or raw.Reward > limits[4] then return nil end
    if raw.Kind == "species" and not identifier(raw.Species) then return nil end
    if raw.Kind == "island" and not identifier(raw.Zone) then return nil end
    local target = math.floor(raw.Target)
    local claimed = raw.Claimed == true
    local progress = claimed and target or number(raw.Progress, 0, target, 0, false)
    return {Id=raw.Id, Kind=raw.Kind, Species=raw.Kind == "species" and raw.Species or nil,
        Zone=raw.Kind == "island" and raw.Zone or nil, Target=target,
        Reward=math.floor(raw.Reward), Progress=progress, Claimed=claimed}
end
local function cleanPeriod(raw, kind)
    local prefix = kind == "Daily" and "d:" or "w:"
    if type(raw) ~= "table" or type(raw.Key) ~= "string" or #raw.Key > 20
        or not raw.Key:match("^" .. prefix .. "%d+$") or not finite(raw.ResetAt) then return nil end
    local out = {Key=raw.Key, ResetAt=number(raw.ResetAt, 0, MAX_TIME, 0, true),
        Tier=number(raw.Tier, 1, 4, 1, true), ReducedPool=raw.ReducedPool == true, Tasks={}, Paid={}}
    if type(raw.Paid) == "table" then
        for _, id in ipairs(ORDER) do if raw.Paid[id] == true then out.Paid[id] = true end end
    end
    local seen = {}
    if type(raw.Tasks) == "table" then
        -- Do not walk arbitrary dictionaries or unbounded saved arrays.
        for index = 1, 20 do
            local source = raw.Tasks[index]
            if type(source) == "table" and KINDS[source.Id] and source.Claimed == true then out.Paid[source.Id] = true end
            local task = cleanTask(source, kind)
            if task and not seen[task.Id] then
                if out.Paid[task.Id] then task.Claimed, task.Progress = true, task.Target end
                seen[task.Id] = true
                table.insert(out.Tasks, task)
            end
        end
    end
    for _, task in ipairs(out.Tasks) do
        if out.Paid[task.Id] then task.Claimed, task.Progress = true, task.Target end
    end
    return out
end
function Quests.Clean(raw)
    raw = type(raw) == "table" and raw or {}
    return {Version=1, Daily=cleanPeriod(raw.Daily, "Daily"), Weekly=cleanPeriod(raw.Weekly, "Weekly"),
        ActivityAt=number(raw.ActivityAt, 0, MAX_TIME, nil, false)}
end

local function capabilities(data, config)
    local rods = config.Rods or {}
    local rod = rods[number(data.Rod, 1, math.max(#rods, 1), 1, true)] or rods[1]
        or {MaxKg=8, Quality=1, Luck=1}
    -- Current games store the purchased upgrade in Rod. Support owned-rod tables
    -- as well, so changing an equipped rod never makes an assigned quest reroll.
    if type(data.OwnedRods) == "table" then
        for _, owned in ipairs(rods) do
            if data.OwnedRods[owned.Id] == true and (owned.Quality or 1) > (rod.Quality or 1) then rod = owned end
        end
    end
    local xp = number(data.XP, 0, 100000000, 0, true)
    local level = config.Level and config.Level(xp) or 1 + math.floor(xp / (config.XPPerLevel or 100))
    local boat = false
    if type(data.OwnedBoats) == "table" then
        for id, owned in pairs(data.OwnedBoats) do
            if owned == true and config.BoatById and config.BoatById[id] then boat = true; break end
        end
    end
    local islands = {}
    for _, island in ipairs(config.Islands or {}) do
        if level >= (island.Level or 1) and (boat or island.Id == "Cove" or island.Id == "Reef") then
            table.insert(islands, island)
        end
    end
    return rod, islands, math.clamp(rod.Quality or 1, 1, 4)
end
local function poolFor(config, island, rod)
    local pool, total = {}, 0
    for _, fish in ipairs(config.Fish or {}) do
        if not fish.Night and (fish.MinKg or 0) <= (rod.MaxKg or 8)
            and (fish.MinRodQuality or 1) <= (rod.Quality or 1) then
            local weight = config.ZoneWeight(fish, island.Id)
            if weight > 0 then
                if config.RollWeight then weight = config.RollWeight(fish, rod.Luck or 1, island.Id) end
                total += weight
                if (fish.Rarity or 1) <= 4 then table.insert(pool, {Fish=fish, Weight=weight}) end
            end
        end
    end
    local common = {}
    for _, entry in ipairs(pool) do
        if total > 0 and entry.Weight / total >= 0.10 then table.insert(common, entry.Fish) end
    end
    return common
end
local function chooseDestinations(config, rod, islands, random)
    local suitable, remote = {}, {}
    for _, island in ipairs(islands) do
        local pool = poolFor(config, island, rod)
        if #pool >= 2 then
            local choice = {Island=island, Pool=pool}
            table.insert(suitable, choice)
            if island.Id ~= "Cove" and island.Id ~= "Reef" then table.insert(remote, choice) end
        end
    end
    local choices = #remote > 0 and remote or suitable
    if #choices == 0 then
        -- Malformed/empty configuration cannot introduce an impossible species.
        return nil, nil, nil
    end
    local destination = choices[random(1, #choices)]
    local first = random(1, #destination.Pool)
    local second = random(1, #destination.Pool - 1)
    if second >= first then second += 1 end
    return destination.Island, destination.Pool[first], destination.Pool[second]
end
local function makePeriod(data, config, kind, now, userId, fixedTier)
    local key, reset = periodInfo(kind, now)
    local random = randomFor(userId, key)
    local rod, islands, tier = capabilities(data, config)
    tier = fixedTier or tier
    local island, first, second = chooseDestinations(config, rod, islands, random)
    local daily = kind == "Daily"
    local multiplier = 1 + (tier - 1) * 0.5
    local rewards = daily and {100, 120, 120, 120, 200} or {600, 550, 550, 500, 800}
    -- Keep the weekly reward within the existing rod/boat economy at every tier.
    if not daily then multiplier = math.min(multiplier, 6500 / 3000) end
    local settings = type(config.Quests) == "table" and config.Quests or {}
    local targetTime = daily and number(settings.DailyActiveSeconds, 1200, 86400, 1200, true)
        or number(settings.WeeklyActiveSeconds, 7200, 604800, 7200, true)
    local tasks = {
        {Id="catch_total", Kind="catch", Target=daily and random(60, 80) or random(200, 260)},
        {Id="species_1", Kind="species", Species=first and first.Id, Target=daily and random(10, 14) or random(40, 60)},
        {Id="species_2", Kind="species", Species=second and second.Id, Target=daily and random(10, 14) or random(40, 60)},
        {Id="island_catch", Kind="island", Zone=island and island.Id, Target=daily and random(25, 35) or random(90, 120)},
        {Id="fishing_time", Kind="activity", Target=targetTime},
    }
    local available = {}
    for index, task in ipairs(tasks) do
        task.Reward = math.floor(rewards[index] * multiplier + 0.5)
        task.Progress, task.Claimed = 0, false
        if (task.Kind ~= "species" or task.Species) and (task.Kind ~= "island" or task.Zone) then
            table.insert(available, task)
        end
    end
    -- Broken/empty pools retain only general-catch and activity tasks. Never
    -- emit duplicate task IDs or requirements for a nonexistent species.
    return {Key=key, ResetAt=reset, Tier=tier, ReducedPool=not island, Tasks=available, Paid={}}
end
local function samePredicate(first, second)
    return first.Kind == second.Kind and first.Species == second.Species and first.Zone == second.Zone
end
local function validDefinition(task, config)
    return task.Kind ~= "species" or (config.ById and config.ById[task.Species])
end
function Quests.Ensure(data, config, now, userId)
    now = timestamp(now)
    local state, changed = Quests.Clean(data.Quests), false
    data.Quests = state
    if state.ActivityAt and state.ActivityAt > now then state.ActivityAt = now; changed = true end
    for _, kind in ipairs({"Daily", "Weekly"}) do
        local key, reset = periodInfo(kind, now)
        local current = state[kind]
        if not current or current.Key ~= key or current.ResetAt ~= reset then
            state[kind], changed = makePeriod(data, config, kind, now, userId), true
        else
            local found, complete = {}, true
            for _, task in ipairs(current.Tasks) do
                found[task.Id] = task
                if not validDefinition(task, config) or (task.Kind == "island"
                    and not (config.IslandById and config.IslandById[task.Zone])) then complete = false end
            end
            local required = current.ReducedPool and {"catch_total", "fishing_time"} or ORDER
            for _, id in ipairs(required) do if not found[id] then complete = false end end
            if not complete then
                local repaired = makePeriod(data, config, kind, now, userId, current.Tier)
                for id, paid in pairs(current.Paid) do repaired.Paid[id] = paid end
                for _, task in ipairs(repaired.Tasks) do
                    local old = found[task.Id]
                    if old and validDefinition(old, config) and (old.Kind ~= "island"
                        or (config.IslandById and config.IslandById[old.Zone])) then
                        -- Valid saved assignments stay locked even during repair.
                        for field, value in pairs(old) do task[field] = value end
                    elseif old then
                        if samePredicate(old, task) then task.Progress = math.min(task.Target, old.Progress) end
                        -- Removing a species must never offer a second reward for
                        -- a task that was already paid in this period.
                        if old.Claimed then task.Progress, task.Claimed = task.Target, true end
                    end
                    if repaired.Paid[task.Id] then task.Progress, task.Claimed = task.Target, true end
                end
                state[kind], changed = repaired, true
            end
        end
    end
    return state, changed
end
function Quests.RecordCatch(data, config, record, zone, now, userId)
    local state = Quests.Ensure(data, config, now, userId)
    if type(record) ~= "table" or not (config.ById and config.ById[record.Species])
        or not finite(record.Kg) or record.Kg <= 0 then return false end
    -- Integration calls once after a won catch has been accepted by the ledger. Failed
    -- reels, ledger replay and catch previews must never call this function.
    local changed = false
    for _, kind in ipairs({"Daily", "Weekly"}) do
        for _, task in ipairs(state[kind].Tasks) do
            if not task.Claimed and task.Progress < task.Target and (task.Kind == "catch"
                or (task.Kind == "species" and task.Species == record.Species)
                or (task.Kind == "island" and task.Zone == zone)) then
                task.Progress = math.min(task.Target, task.Progress + 1)
                changed = true
            end
        end
    end
    return changed
end
function Quests.AddActivity(data, config, seconds, now, userId)
    now = timestamp(now)
    local state = Quests.Ensure(data, config, now, userId)
    seconds = number(seconds, 0, 30, 0, false)
    if seconds <= 0 then return false end
    local elapsed = math.min(seconds, math.max(0, now - (state.ActivityAt or (now - seconds))))
    state.ActivityAt = now
    local changed = false
    for _, kind in ipairs({"Daily", "Weekly"}) do
        local _, _, start = periodInfo(kind, now)
        local credited = math.min(elapsed, math.max(0, now - start))
        for _, task in ipairs(state[kind].Tasks) do
            if task.Kind == "activity" and not task.Claimed and task.Progress < task.Target and credited > 0 then
                task.Progress = math.min(task.Target, task.Progress + credited)
                changed = true
            end
        end
    end
    return changed
end
function Quests.Claim(data, config, kind, taskId, now, userId)
    local state = Quests.Ensure(data, config, now, userId)
    if kind ~= "Daily" and kind ~= "Weekly" then return false, "invalid_period", 0 end
    for _, task in ipairs(state[kind].Tasks) do
        if state[kind].Key .. ":" .. task.Id == taskId then
            if task.Claimed then return false, "already_claimed", 0 end
            if task.Progress < task.Target then return false, "not_completed", 0 end
            local coins = number(data.Coins, 0, MAX_COINS, 0, true)
            -- No yielding occurs between the claim marker and currency update.
            task.Claimed, data.Coins = true, math.min(MAX_COINS, coins + task.Reward)
            state[kind].Paid[task.Id] = true
            return true, "claimed", data.Coins - coins
        end
    end
    return false, "unknown_task", 0
end
local function titleFor(task, config)
    if task.Kind == "catch" then return "Поймай " .. task.Target .. " существ" end
    if task.Kind == "species" then return "Поймай: " .. config.ById[task.Species].Name end
    if task.Kind == "island" then return "Улов на острове «" .. config.IslandById[task.Zone].Name .. "»" end
    return "Активная рыбалка: " .. math.floor(task.Target / 60) .. " минут"
end
function Quests.Snapshot(data, config, now, userId)
    now = timestamp(now)
    local state = Quests.Ensure(data, config, now, userId)
    local snapshot = {ServerNow=now, ResetTimezone="UTC"}
    for _, kind in ipairs({"Daily", "Weekly"}) do
        local period = state[kind]
        local public = {Key=period.Key, ResetAt=period.ResetAt, Tasks={}}
        for _, task in ipairs(period.Tasks) do
            table.insert(public.Tasks, {Id=period.Key .. ":" .. task.Id, Kind=task.Kind, Species=task.Species, Zone=task.Zone,
                Title=titleFor(task, config), Progress=math.floor(task.Progress), Target=task.Target,
                Reward=task.Reward, Claimed=task.Claimed, Unit=task.Kind == "activity" and "seconds" or "catches"})
        end
        snapshot[kind] = public
    end
    return snapshot
end
return Quests
