-- Lease-based session ownership. Failed loads never overwrite saved profiles.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("QuietCove"):WaitForChild("Config"))
local CatchLedger = require(game:GetService("ReplicatedStorage"):WaitForChild("QuietCove"):WaitForChild("CatchLedger"))
local Quests = require(game:GetService("ReplicatedStorage"):WaitForChild("QuietCove"):WaitForChild("Quests"))
local WeaponCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("QuietCove"):WaitForChild("WeaponCatalog"))
local TesterAccess = require(script.Parent:WaitForChild("TesterAccess"))
local Profiles = {Records = {}}
local memoryOnly = RunService:IsStudio() and not Config.SaveInStudio
local store = nil
if not memoryOnly then
    store = DataStoreService:GetDataStore(Config.DataStoreName .. (RunService:IsStudio() and "_TEST" or ""))
end
local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}; for k, v in pairs(value) do out[k] = copy(v) end; return out
end
local function integer(value, lo, hi, fallback)
    if type(value) ~= "number" or value ~= value then return fallback end
    return math.max(lo, math.min(hi, math.floor(value)))
end
local function clean(raw)
    raw = type(raw) == "table" and raw or {}
    local data = {Coins = integer(raw.Coins, 0, 1000000000, 0), XP = integer(raw.XP, 0, 100000000, 0),
        Rod = integer(raw.Rod, 1, #Config.Rods, 1), TotalCaught = integer(raw.TotalCaught, 0, 100000000, 0),
        Bag = {}, Bestiary = {}, OwnedWeapons = {}}
    if type(raw.OwnedWeapons)=="table" then
        for id,owned in pairs(raw.OwnedWeapons) do
            if WeaponCatalog.ById[id] and owned==true then data.OwnedWeapons[id]=true end
        end
    end
    if type(raw.Bag) == "table" then
        for _, record in ipairs(raw.Bag) do
            if #data.Bag >= Config.BagCapacity then break end
            if type(record) == "table" then
                local fish = Config.ById[record.Species]
                if fish and type(record.Kg) == "number" and record.Kg == record.Kg then
                    local kg = math.max(fish.MinKg, math.min(fish.MaxKg, record.Kg))
                    local mutation = (record.Mutation == "gold" or record.Mutation == "glow") and record.Mutation or "normal"
                    table.insert(data.Bag, {Species = fish.Id, Kg = kg, Mutation = mutation, Value = Config.Value(fish, kg, mutation)})
                    data.Bestiary[fish.Id] = true
                end
            end
        end
    end
    if type(raw.Bestiary) == "table" then
        for id, found in pairs(raw.Bestiary) do
            if Config.ById[id] and found == true then data.Bestiary[id] = true end
        end
    end
    data.OwnedBoats={};data.Visited={Cove=true}
    if type(raw.OwnedBoats)=="table" then
        for id,owned in pairs(raw.OwnedBoats) do
            if Config.BoatById[id] and owned==true then data.OwnedBoats[id]=true end
        end
    end
    data.BoatId=type(raw.BoatId)=="string" and data.OwnedBoats[raw.BoatId] and raw.BoatId or ""
    if type(raw.Visited)=="table" then
        for id,visited in pairs(raw.Visited) do
            if Config.IslandById[id] and visited==true then data.Visited[id]=true end
        end
    end
    -- Won catches already advanced quests at reservation time. Recovering
    -- their bag entry must preserve that progress, never count it a second time.
    data.Quests = Quests.Clean(raw.Quests)
    CatchLedger.Recover(data, Config, raw)
    return data
end
function Profiles.Get(player)
    local p = Profiles.Records[player]
    if not p or p.Closing then return nil end
    if not p.SandboxChecked then
        p.TestData = TesterAccess.Sandbox(player, p.Data)
        p.SandboxChecked = true
    end
    -- Keep p.Data untouched for tester sessions. Only the throwaway copy changes.
    if p.TestData then return TesterAccess.Refresh(p.TestData) end
    return p.Data
end
function Profiles.Load(player)
    if memoryOnly then
        Profiles.Records[player] = {Data = clean(nil), Memory = true, LastSave = os.clock()}
        return true
    end
    local token = HttpService:GenerateGUID(false)
    local result, reason
    for attempt = 1, 3 do
        local blocked = false
        local ok, value = pcall(function()
            return store:UpdateAsync("u_" .. player.UserId, function(old)
                old = type(old) == "table" and old or {}
                local session = old.Session
                if type(session) == "table" and session.Id ~= token and (tonumber(session.Expires) or 0) > os.time() then
                    blocked = true; return nil
                end
                return {Version = 1, Data = clean(old.Data), Session = {Id = token, Expires = os.time() + Config.SessionLeaseSeconds}}
            end)
        end)
        if ok and value and value.Session and value.Session.Id == token then result = value; break end
        reason = blocked and "Профиль ещё открыт на другом сервере. Подождите немного и войдите снова." or tostring(value)
        if attempt < 3 then task.wait(attempt) end
    end
    if not result then warn("[QuietCove] Profile load failed:", player.UserId, reason); return false end
    Profiles.Records[player] = {Data = clean(result.Data), Token = token, LastSave = os.clock(), Busy = false, Closing = false}
    return true
end
function Profiles.Save(player, release)
    local p = Profiles.Records[player]
    if not p then return true end
    if release then p.Closing = true end
    if p.Memory then if release then Profiles.Records[player] = nil end; return true end
    local waitStart = os.clock()
    while p.Busy and os.clock() - waitStart < 20 do task.wait(0.1) end
    if p.Busy then return false end
    if Profiles.Records[player] ~= p then return true end
    p.Busy = true
    local snapshot = copy(p.Data)
    local success, lostOwnership = false, false
    for attempt = 1, 3 do
        lostOwnership = false
        local ok, result = pcall(function()
            return store:UpdateAsync("u_" .. player.UserId, function(old)
                if type(old) ~= "table" or type(old.Session) ~= "table" or old.Session.Id ~= p.Token then
                    lostOwnership = true; return nil
                end
                local value = {Version = 1, Data = snapshot}
                if not release then value.Session = {Id = p.Token, Expires = os.time() + Config.SessionLeaseSeconds} end
                return value
            end)
        end)
        if ok and result and not lostOwnership then success = true; break end
        if lostOwnership then break end
        warn("[QuietCove] Save retry:", player.UserId, tostring(result))
        if attempt < 3 then task.wait(attempt) end
    end
    p.Busy = false
    if success then p.LastSave = os.clock() end
    if lostOwnership then
        p.Closing = true
        if player.Parent == Players then player:Kick("Профиль открыт в другой сессии. Войдите снова.") end
    end
    if release then
        if not success then warn("[QuietCove] FINAL SAVE FAILED for", player.UserId) end
        Profiles.Records[player] = nil
    elseif not success and os.clock() - p.LastSave > Config.SessionLeaseSeconds - 35 then
        p.Closing = true
        if player.Parent == Players then player:Kick("Сохранение временно недоступно. Войдите снова, чтобы не потерять прогресс.") end
    end
    return success
end
function Profiles.Start()
    task.spawn(function()
        while task.wait(Config.AutoSaveSeconds) do
            for player, p in pairs(Profiles.Records) do
                if not p.Closing and not p.Busy then task.spawn(Profiles.Save, player, false) end
            end
        end
    end)
    game:BindToClose(function()
        local remaining = 0
        for player in pairs(Profiles.Records) do
            remaining = remaining + 1
            task.spawn(function() Profiles.Save(player, true); remaining = remaining - 1 end)
        end
        local started = os.clock()
        while remaining > 0 and os.clock() - started < 25 do task.wait(0.1) end
    end)
end
Profiles.MemoryOnly = memoryOnly
return Profiles
