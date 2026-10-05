-- Run from the repository root: lune run tests/quest_server.luau
-- Real Main.server, Profiles, Quests, Config and CatchLedger; deterministic service
-- doubles replace Roblox transport, datastore I/O and fishing/world presentation.
local Environment = require("./helpers/server_environment")
local checks = 0
local function check(condition, label)
    checks += 1
    assert(condition, label)
end
local function taskFor(data, kind, id)
    for _, task in ipairs(data.Quests[kind].Tasks) do if task.Id == id then return task end end
    error("Missing task " .. kind .. "/" .. id)
end
local function progress(data, kind, id) return taskFor(data, kind, id).Progress end
local function publicId(env, player, kind, localId)
    local snapshot = env:Last(player, "Quests")
    for _, task in ipairs(snapshot[kind].Tasks) do
        -- IDs may carry a period key to protect claims arriving after reset.
        if task.Id == localId or task.LocalId == localId or task.Id:sub(-#localId) == localId then return task.Id end
    end
    error("Missing snapshot task " .. localId)
end
local function makeServer(id, tester)
    local env = Environment.new(); env:Start()
    local player = env:Player(id, tester); env.Players.PlayerAdded:Fire(player)
    return env, player, env.Profiles.Get(player)
end
local function reachReel(env, player)
    env:Fire(player, "Begin")
    local charging = env:Last(player, "Stage")
    check(charging.Stage == "Charging", "Authoritative Begin accepted")
    env:Advance(.3); env:Fire(player, "Release", charging.Id)
    check(env:Last(player, "Stage").Stage == "Casting", "Authoritative Release accepted")
    for _ = 1, 30 do
        env:Advance(.5)
        if env:Last(player, "Stage").Stage == "Bite" then break end
    end
    check(env:Last(player, "Stage").Stage == "Bite", "Fish bites only after server cast")
    env:Fire(player, "Hook", charging.Id)
    check(env:Last(player, "Stage").Stage == "Reeling", "Authoritative Hook accepted")
    return charging.Id
end

do
    local env, player, data = makeServer(201)
    check(env:Last(player, "Quests") ~= nil, "Initial sync sends quests without fishing session")
    local task = taskFor(data, "Daily", "catch_total")
    local initial = data.Coins
    local id = publicId(env, player, "Daily", "catch_total")
    env:Fire(player, "QuestClaim", "Daily", id)
    check(data.Coins == initial and not taskFor(data, "Daily", "catch_total").Claimed, "Unfinished claim cannot pay")
    for _, malformed in ipairs({{}, 123, string.rep("x", 81)}) do env:Fire(player, "QuestClaim", "Daily", malformed) end
    check(data.Coins == initial, "Malformed claims never pay")
    env:Advance(3)
    task = taskFor(data, "Daily", "catch_total"); task.Progress = task.Target
    env:Fire(player, "QuestClaim", "Daily", id)
    check(data.Coins == initial + task.Reward, "Claim works outside fishing and pays server reward")
    check(taskFor(data, "Daily", "catch_total").Claimed, "Claim marker written with currency")
    env:Fire(player, "QuestClaim", "Daily", id)
    env:Fire(player, "QuestClaim", "Weekly", "not_a_task")
    env:Fire(player, "QuestClaim", "Daily", {Id=id, Reward=1000000000})
    check(data.Coins == initial + task.Reward, "Repeated/unknown/client reward payload cannot pay twice")
    env:Leave(player)
    local rejoin = env:Player(201); env.Players.PlayerAdded:Fire(rejoin)
    local restored = env.Profiles.Get(rejoin)
    check(restored.Coins == initial + task.Reward, "Actual lease save/reload preserves quest currency")
    check(taskFor(restored, "Daily", "catch_total").Claimed, "Actual profile cleaner preserves claimed task")
    env:Fire(rejoin, "QuestClaim", "Daily", publicId(env, rejoin, "Daily", "catch_total"))
    check(restored.Coins == initial + task.Reward, "Reload does not allow claimed reward replay")
end

do
    local env, player, data = makeServer(202)
    env:Advance(8)
    check(progress(data, "Daily", "fishing_time") == 0, "Ordinary idle does not advance activity")
    player.Character.Humanoid.SeatPart = {}
    env:Fire(player, "Begin"); env:Advance(3)
    check(progress(data, "Daily", "fishing_time") == 0, "Sailing/seated Begin cannot farm activity")
    player.Character.Humanoid.SeatPart = nil
    local token = reachReel(env, player)
    check(progress(data, "Daily", "fishing_time") > 0, "Valid server fishing advances activity")
    local before = progress(data, "Daily", "catch_total")
    env:Fire(player, "Input", "wrong-token", true)
    check(progress(data, "Daily", "catch_total") == before, "Forged fishing token does not count catch")
    env.reelResult = "caught"; env:Advance(.1)
    check(env:Last(player, "Stage").Stage == "Landing", "Won reel begins Landing")
    check(progress(data, "Daily", "catch_total") == before + 1, "Won server reservation counts quest immediately")
    check(progress(data, "Weekly", "catch_total") == 1, "Weekly catch also counts once")
    check(data.PendingCatch and data.PendingCatch.Token == token and #data.Bag == 0, "Won fish reserved before presentation commit")
    env:Fire(player, "Cancel", token); env:Advance(.3)
    check(progress(data, "Daily", "catch_total") == before + 1, "Landing and repeated input cannot count again")
    local activityBeforeLanding = progress(data, "Daily", "fishing_time")
    env:Advance(1.1)
    check(progress(data, "Daily", "fishing_time") <= activityBeforeLanding + 1, "Landing presentation cannot farm activity")
    env:Reset(player)
    check(#data.Bag == 1 and data.PendingCatch == nil, "Character reset commits earned fish")
    check(progress(data, "Daily", "catch_total") == before + 1, "Reset commit does not repeat quest progress")
    env:Leave(player)
    local rejoin = env:Player(202); env.Players.PlayerAdded:Fire(rejoin)
    local restored = env.Profiles.Get(rejoin)
    check(#restored.Bag == 1 and restored.TotalCaught == 1, "Earned catch survives actual profile save/rejoin")
    check(progress(restored, "Daily", "catch_total") == before + 1, "Rejoin recovery does not count quest twice")
end

do
    local env, player, data = makeServer(203)
    reachReel(env, player)
    env.reelResult = "lost"; env:Advance(.1)
    check(env:Last(player, "Stage").Stage == "Idle", "Lost reel finishes session")
    check(progress(data, "Daily", "catch_total") == 0 and #data.Bag == 0, "Lost fish cannot advance catch quests")
    env:Advance(1)
    env:Fire(player, "Begin"); env:Advance(.4)
    local tool = player.Character:FindFirstChildOfClass("Tool")
    tool.Parent = player.Backpack
    env:Advance(2)
    local afterInvalid = progress(data, "Daily", "fishing_time")
    env:Advance(4)
    check(progress(data, "Daily", "fishing_time") == afterInvalid, "Unequipped/invalid tool stops activity credit")
    env:Leave(player)
    local raw = env.documents["u_203"].Data
    check(progress(raw, "Daily", "fishing_time") == afterInvalid, "Leave flush is stored in actual profile document")
end

do
    local env, player, data = makeServer(206)
    local oldId = publicId(env, player, "Daily", "catch_total")
    local oldKey = data.Quests.Daily.Key
    env.clock += 86400
    env.RunService.Heartbeat:Fire(1 / 60)
    check(data.Quests.Daily.Key ~= oldKey, "Online player's assignments reset at next UTC day")
    check(progress(data, "Daily", "catch_total") == 0, "New day starts with fresh catch progress")
    local nextTask = taskFor(data, "Daily", "catch_total"); nextTask.Progress = nextTask.Target
    local coins = data.Coins
    env:Fire(player, "QuestClaim", "Daily", oldId)
    check(data.Coins == coins, "Delayed claim from previous day cannot claim a new task")
    local newId = publicId(env, player, "Daily", "catch_total")
    env:Fire(player, "QuestClaim", "Daily", newId)
    check(data.Coins == coins + nextTask.Reward, "Current period ID can claim after online reset")
end

do
    local env, player, data = makeServer(207)
    env:Fire(player, "Begin"); env:Advance(1.5)
    local before = progress(data, "Daily", "fishing_time")
    -- Leave between one-second flushes: earned activity in the live server bucket
    -- must be included in the same saved document as the existing quest state.
    env:Leave(player)
    local saved = env.documents["u_207"].Data
    check(progress(saved, "Daily", "fishing_time") > before, "Disconnect flushes live unflushed fishing activity")
    check(progress(saved, "Daily", "fishing_time") <= 1.6, "Disconnect activity cannot exceed simulated fishing time")
end

do
    local env, player, data = makeServer(208)
    data.Bag = table.create(env.Config.BagCapacity, {Species="capybara", Kg=.5, Mutation="normal", Value=10})
    env:Fire(player, "Begin"); env:Advance(2)
    check(env:Last(player, "Stage") == nil, "Full bag cannot start new fishing reservation")
    check(progress(data, "Daily", "catch_total") == 0 and progress(data, "Daily", "fishing_time") == 0,
        "Full bag rejection cannot advance quests")
    data.Bag = {}
    env:Fire(player, "Begin")
    local token = env:Last(player, "Stage").Id
    env:Fire(player, "Cancel", token); env:Advance(.2)
    check(progress(data, "Daily", "catch_total") == 0 and #data.Bag == 0, "Cancelled cast never counts as an earned catch")
end

do
    local env = Environment.new()
    local first = env:Player(209)
    check(env.Profiles.Load(first), "First published player obtains exclusive lease")
    local data = env.Profiles.Get(first)
    env.Quests.Ensure(data, env.Config, env:Now(), first.UserId)
    data.Coins = 77; env.Profiles.Save(first, false)
    local saved = Environment.Copy(env.documents["u_209"])
    local competitor = env:Player(209)
    check(not env.Profiles.Load(competitor), "Concurrent profile load rejects another live lease")
    check(env.Profiles.Get(competitor) == nil, "Failed load cannot create writable empty profile")
    check(env.documents["u_209"].Data.Coins == 77 and env.documents["u_209"].Session.Id == saved.Session.Id,
        "Failed concurrent load preserves quest-bearing document and ownership")
    check(env.Profiles.Save(first, true), "Original lease remains able to save and release")
end

do
    local env, player, data = makeServer(210)
    local start = env.clock
    local token = reachReel(env, player)
    local target = taskFor(data, "Daily", "fishing_time").Target
    check(target >= 1200, "All daily tasks include at least twenty minutes of active fishing")
    while env.clock - start < target - 2 do
        env:Fire(player, "Input", token, true)
        env:Advance(1)
    end
    check(progress(data, "Daily", "fishing_time") < target, "Activity task cannot complete before required wall time")
    for _ = 1, 5 do env:Fire(player, "Input", token, true); env:Advance(1) end
    check(progress(data, "Daily", "fishing_time") == target, "Twenty minutes of valid server simulation completes daily activity")
    check(progress(data, "Weekly", "fishing_time") >= target, "Same real fishing advances the longer weekly task")
    check(progress(data, "Daily", "catch_total") == 0, "Activity does not fabricate earned catches")
end

do
    -- Simulate a saved reservation during Landing: the two earned pieces of
    -- progress were persisted together, and profile recovery commits only bag/XP.
    local env = Environment.new()
    local player = env:Player(204)
    check(env.Profiles.Load(player), "Published profile load obtains datastore lease")
    local data = env.Profiles.Get(player)
    env.Quests.Ensure(data, env.Config, env:Now(), player.UserId)
    local record = {Species="capybara", Kg=.5, Mutation="normal"}
    check(env.Ledger.Reserve(data, env.Config, record, "saved-landing"), "Real ledger accepts earned reservation")
    env.Quests.RecordCatch(data, env.Config, record, "Cove", env:Now(), player.UserId)
    check(env.Profiles.Save(player, true), "Reservation and quest progress saved together")
    check(env.Profiles.Load(player), "Reservation profile can reopen after released lease")
    local restored = env.Profiles.Get(player)
    check(#restored.Bag == 1 and restored.TotalCaught == 1, "Actual clean/Recover commits saved reservation")
    check(progress(restored, "Daily", "catch_total") == 1, "Recover preserves original earned quest count")
    check(env.Ledger.Commit(restored, env.Config, "saved-landing") == nil, "Ledger replay is idempotent")
    env.Profiles.Save(player, true); env.Profiles.Load(player)
    check(progress(env.Profiles.Get(player), "Daily", "catch_total") == 1, "Second reload preserves count once")
end

do
    local env = Environment.new()
    local player = env:Player(205)
    check(env.Profiles.Load(player), "Original tester profile loads normally")
    local real = env.Profiles.Get(player)
    real.Coins = 47
    env.Quests.Ensure(real, env.Config, env:Now(), player.UserId)
    local task = taskFor(real, "Daily", "catch_total"); task.Progress = task.Target
    local paidId = env.Quests.Snapshot(real, env.Config, env:Now(), player.UserId).Daily.Tasks[1].Id
    check(env.Quests.Claim(real, env.Config, "Daily", paidId, env:Now(), player.UserId), "Original profile quest reward earned")
    env.Profiles.Save(player, true)
    local original = Environment.Copy(env.documents["u_205"].Data)
    player.Tester = true; env.Profiles.Load(player)
    local sandbox = env.Profiles.Get(player)
    check(sandbox.TestMode == true and sandbox ~= env.Profiles.Records[player].Data, "Tester gets a separate throwaway profile")
    local sandboxTask = taskFor(sandbox, "Weekly", "catch_total"); sandboxTask.Progress = sandboxTask.Target
    local sandboxId = env.Quests.Snapshot(sandbox, env.Config, env:Now(), player.UserId).Weekly.Tasks[1].Id
    check(env.Quests.Claim(sandbox, env.Config, "Weekly", sandboxId, env:Now(), player.UserId), "Tester sandbox reward handled separately")
    env.Quests.RecordCatch(sandbox, env.Config, {Species="capybara", Kg=.5}, "Cove", env:Now(), player.UserId)
    env.Profiles.Save(player, true)
    local saved = env.documents["u_205"].Data
    check(saved.Coins == original.Coins, "Tester sandbox coins never overwrite published profile")
    check(taskFor(saved, "Daily", "catch_total").Claimed, "Original paid quest survives tester leave")
    check(not taskFor(saved, "Weekly", "catch_total").Claimed, "Tester sandbox claim marker not persisted")
    check(progress(saved, "Weekly", "catch_total") == progress(original, "Weekly", "catch_total"), "Tester sandbox catch progress not persisted")
end

print("PASS quest server integration: " .. checks .. " checks (real Main/Profiles/Quests/Config/CatchLedger)")
