-- Quiet Cove. All rewards, prices, timing and reel progress are server-owned.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")
local shared = RS:WaitForChild("QuietCove")
local Config = require(shared:WaitForChild("Config"))
local VisualTheme = require(shared:WaitForChild("VisualTheme"))
local Reel = require(shared:WaitForChild("Reel"))
local CastMath = require(shared:WaitForChild("CastMath"))
local FightBalance = require(shared:WaitForChild("FightBalance"))
local CatchLedger = require(shared:WaitForChild("CatchLedger"))
local Quests = require(shared:WaitForChild("Quests"))
local DodgeSettings = require(shared:WaitForChild("SideDodge"))
local DodgeService = require(script.Parent:WaitForChild("DodgeService"))
local WaterHazardService = require(script.Parent:WaitForChild("WaterHazardService"))
local WeaponCatalog = require(shared:WaitForChild("WeaponCatalog"))
local WeaponShop = require(script.Parent:WaitForChild("WeaponShop"))
local TesterAccess = require(script.Parent:WaitForChild("TesterAccess"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local World = require(script.Parent:WaitForChild("World"))
local Archipelago = require(script.Parent:WaitForChild("Archipelago"))
local NPCDialogueService = require(script.Parent:WaitForChild("NPCDialogueService"))
local BoatService = require(script.Parent:WaitForChild("BoatService"))
local Models = require(shared:WaitForChild("EquipmentModels"))
local world = Archipelago.Attach(World.Build())
local grantRod, boats, dodges, weaponShop, sahur, dialogues
local function remote(name)
    local r = shared:FindFirstChild(name)
    if not r then r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = shared end
    return r
end
local Action, Update = remote("Action"), remote("Update")
task.spawn(TesterAccess.Resolve)
local rng = Random.new()
local sessions, limits, cooldowns, loading, connections = {}, {}, {}, {}, {}
local questActivity, questSentAt = {}, {}
local limitsPerSecond = {Begin = 2, Release = 4, Shake = 4, Hook = 4, Input = 35, Cancel = 4, Ready = 1, Buy = 2, BoatBuy = 2, BoatSpawn = 0.5, BoatInput = 18, BoatDock = 2, QuestClaim = 3, NPCChoice = 5}
local function allow(player, key, rate)
    local now = os.clock()
    local bucket = limits[player]
    if not bucket then bucket = {}; limits[player] = bucket end
    local b = bucket[key]
    if not b then b = {Tokens = rate * 2, At = now}; bucket[key] = b end
    b.Tokens = math.min(rate * 2, b.Tokens + (now - b.At) * rate); b.At = now
    if b.Tokens < 1 then return false end
    b.Tokens = b.Tokens - 1; return true
end
local function send(player, kind, data)
    if player.Parent == Players then Update:FireClient(player, kind, data) end
end
local function notice(player, text) send(player, "Notice", {Text = text}) end
local waterHazard = WaterHazardService.new(Config.WaterHazard, notice)
dodges = DodgeService.new(DodgeSettings, send, function(player)
    return sessions[player] ~= nil or not Profiles.Get(player)
end)
limitsPerSecond.Dodge = 4
limitsPerSecond.WeaponBuy = 2
local function rootOf(player)
    local c = player.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    local root = c and c:FindFirstChild("HumanoidRootPart")
    if h and root and h.Health > 0 then return root, h end
    return nil, nil
end
local function equipped(player)
    local c = player.Character
    if not c then return nil end
    for _, t in ipairs(c:GetChildren()) do
        if t:IsA("Tool") and t:GetAttribute("QuietCoveRod") then return t end
    end
    return nil
end
local function nearby(player, point, distance)
    local root = rootOf(player)
    return root ~= nil and (root.Position - point).Magnitude <= distance
end
local function zoneAt(root)
    for id, zone in pairs(world.Spots) do
        local delta = root.Position - zone.Center
        if Vector3.new(delta.X, 0, delta.Z).Magnitude <= zone.Radius and math.abs(delta.Y) <= 12 then return id, zone end
    end
    return nil
end
local function syncQuests(player, data)
    data = data or Profiles.Get(player)
    if not data then return end
    send(player, "Quests", Quests.Snapshot(data, Config, workspace:GetServerTimeNow(), player.UserId))
    questSentAt[player] = os.clock()
end
local function sync(player)
    local data = Profiles.Get(player)
    if not data then return end
    local stats = player:FindFirstChild("leaderstats")
    if stats then
        stats.Coins.Value = data.Coins; stats.Level.Value = Config.Level(data.XP); stats.Caught.Value = data.TotalCaught
    end
    send(player, "Profile", {Data = data, MemoryOnly = Profiles.MemoryOnly})
    syncQuests(player, data)
end
local function getSahur()
    if not sahur then
        local SahurService = require(script.Parent:WaitForChild("SahurService"))
        sahur = SahurService.new(function(player, record, token)
            local data = Profiles.Get(player)
            if not data or not CatchLedger.Reserve(data,Config,record,token) then
                notice(player,"Could not add Sahur. Make room in your backpack.");return
            end
            Quests.RecordCatch(data,Config,record,"Dunes",workspace:GetServerTimeNow(),player.UserId)
            local award = CatchLedger.Commit(data,Config,token)
            sync(player)
            if award then send(player,"Caught",award) end
        end, notice)
    end
    return sahur
end
weaponShop = WeaponShop.new(WeaponCatalog, Profiles, ServerStorage:WaitForChild("Weapons"),
    workspace:WaitForChild("WeaponStall"), send, sync, function(player)
        return sessions[player]~=nil or dodges:IsActive(player)
    end, notice, Config.Level)
for family,counter in pairs(weaponShop.Counters) do
    counter:WaitForChild('WeaponShopPrompt').Triggered:Connect(function(player) weaponShop:Open(player,family) end)
end
local function stage(player, s, name, extra)
    s.Stage = name
    if s.Tool and s.Tool.Parent then
        s.Tool:SetAttribute("QCFishingStage", name)
        s.Tool:SetAttribute("QCStageAt", workspace:GetServerTimeNow())
        if name == "Charging" then s.Tool:SetAttribute("QCChargeAt", workspace:GetServerTimeNow()) end
    end
    local payload = extra or {}
    payload.Stage, payload.Id = name, s.Id
    send(player, "Stage", payload)
end
local function finish(player, reason)
    local s = sessions[player]
    if not s then return end
    sessions[player] = nil
    if s.Tool and s.Tool.Parent then
        s.Tool:SetAttribute("QCFishingStage", "Idle")
        s.Tool:SetAttribute("QCStageAt", workspace:GetServerTimeNow())
    end
    if s.CastPayload then Update:FireAllClients("CastEnd", {UserId=player.UserId, Id=s.Id}) end
    if s.Bobber then s.Bobber:Destroy() end
    if s.Beam then s.Beam:Destroy() end
    if s.Humanoid and s.Humanoid.Parent then
        s.Humanoid.WalkSpeed = s.WalkSpeed; s.Humanoid.JumpPower = s.JumpPower
        s.Humanoid.JumpHeight = s.JumpHeight; s.Humanoid.AutoRotate = s.AutoRotate
    end
    cooldowns[player] = os.clock() + 0.6
    send(player, "Stage", {Stage = "Idle", Id = s.Id})
    -- Won catches survive a normal reset/disconnect during the presentation.
    -- Periodic saving is unchanged; this is not a promise against process crashes.
    if s.PendingCatch then
        local data=Profiles.Get(player)
        local award=data and CatchLedger.Commit(data,Config,s.Id)
        if award then
            sync(player);send(player,"Caught",award)
            local fish=Config.ById[award.Record.Species]
            if fish.Rarity>=4 then
                for _,other in ipairs(Players:GetPlayers()) do
                    if other~=player then notice(other,player.DisplayName.." caught "..fish.Name.."!") end
                end
            end
        end
        Update:FireAllClients("CatchVisualEnd",{UserId=player.UserId,Id=s.Id})
    elseif reason then notice(player, reason) end
end
-- Studio-only shortcut; uses the real encounter/reward path, never a remote.
if RunService:IsStudio() then
    local shortcut=Instance.new("BindableFunction")
    shortcut.Name="StudioSahur";shortcut.Parent=ServerStorage
    shortcut.OnInvoke=function(player)
        if not player or player.Parent~=Players then return false,"The player has not joined yet." end
        local root,humanoid=rootOf(player)
        local data=Profiles.Get(player)
        local zone=world.Spots.Dunes
        if not root or not data then return false,"Wait for your character and profile to load." end
        if not ServerStorage:FindFirstChild("SahurBoss") then return false,"First install the model with SahurStudioInstall.Selected()." end
        if not zone then return false,"Sahur Sands has not been created yet." end
        if humanoid.SeatPart then return false,"Leave the boat first." end
        if dodges:IsActive(player) then return false,"Wait for your dodge to finish." end
        if sahur and sahur:IsActive(player) then return false,"You are already fighting Sahur." end
        if #data.Bag>=Config.BagCapacity then return false,"Make room in your backpack." end
        finish(player)
        local position=zone.Center+Vector3.new(0,2,0)
        root.CFrame=CFrame.lookAt(position,position+Vector3.new(0,0,-10))
        root.AssemblyLinearVelocity=Vector3.zero
        local fish=Config.ById.sahur
        local record={Species=fish.Id,Kg=fish.MinKg,Mutation="normal",Value=Config.Value(fish,fish.MinKg,"normal")}
        return getSahur():Start(player,HttpService:GenerateGUID(false),record,zone,Config.IslandById.Dunes)
    end
end
local function chooseFish(zone, rod, power)
    local pool, total = {}, 0
    local night = Lighting.ClockTime >= 18 or Lighting.ClockTime < 6
    for _, fish in ipairs(Config.Fish) do
        if Config.Eligible(fish, zone, rod.MaxKg, night, rod.Quality) then
            local weight = Config.RollWeight(fish, rod.Luck + power * 0.15, zone)
            total = total + weight; table.insert(pool, {Fish = fish, Ceiling = total})
        end
    end
    if #pool == 0 then return nil end
    local roll = rng:NextNumber() * total
    for _, entry in ipairs(pool) do if roll <= entry.Ceiling then return entry.Fish end end
    return pool[#pool].Fish
end
local function makeBobber(player, s, target, origin)
    -- Invisible authoritative marker. Each client draws a smooth presentation
    -- at server-approved positions; no reward/target is ever client supplied.
    local bobber = Instance.new("Part"); bobber.Name = "Bobber_" .. player.UserId
    bobber.Shape = Enum.PartType.Ball; bobber.Size = Vector3.new(0.7, 0.7, 0.7)
    bobber.Position = origin; bobber.Anchored = true; bobber.CanCollide = false
    bobber.CanQuery = false; bobber.CanTouch = false; bobber.Transparency = 1
    bobber.Parent = world.Model
    s.Bobber, s.Target = bobber, target
end
local function releaseCast(player, s)
    if s.Stage ~= "Charging" then return end
    local root = rootOf(player)
    if not root then finish(player); return end
    local power = math.clamp((os.clock() - s.Started) / Config.ChargeSeconds, 0, 1)
    local target = Vector3.new(s.Zone.Center.X + rng:NextNumber(-4, 4), 0.25, s.Zone.Center.Z - 18 - power * 10)
    s.Fish = chooseFish(s.ZoneId, s.Rod, power)
    if not s.Fish then finish(player, "There are no fish here that this rod can catch."); return end
    local swing, flight, arc = CastMath.Timing(power, Config.Casting)
    local tip=s.Tool.Handle:FindFirstChild("Tip")
    local origin,launchDirection,launchVelocity=CastMath.Release(root.CFrame,tip and tip.Position or Vector3.new(0,3,0),power,Config.Casting)
    s.Power, s.CastAt = power, os.clock()
    s.Swing, s.Flight, s.Arc, s.FlightOrigin = swing, flight, arc, origin
    s.LaunchDirection=launchDirection;s.LaunchVelocity=launchVelocity
    s.LandAt = s.CastAt + swing + flight
    s.BiteAt = s.LandAt + math.max(2.5, rng:NextNumber(6, 10) / s.Rod.Speed - power * 1.5)
    s.LastShake = 0
    makeBobber(player, s, target, origin)
    local started = workspace:GetServerTimeNow()
    s.Tool:SetAttribute("QCCastAt", started)
    s.Tool:SetAttribute("QCCastPower", power)
    stage(player, s, "Casting", {Power=power, Zone=s.Zone.Name, Started=started, Swing=swing, Flight=flight})
    s.CastPayload = {UserId=player.UserId, Id=s.Id, Tool=s.Tool, Marker=s.Bobber,
        Origin=origin, Target=target, Started=started, Swing=swing, Flight=flight, Arc=arc, Power=power, LaunchDirection=launchDirection, LaunchVelocity=launchVelocity}
    Update:FireAllClients("CastVisual", s.CastPayload)
end
local function beginCast(player)
    local function reject(text) send(player, "Rejected", {Text = text}) end
    if sahur and sahur:IsActive(player) then reject("Defeat Sahur or leave the fight first."); return end
    if dodges:IsActive(player) then reject("Wait for your dodge to finish."); return end
    if sessions[player] then return end
    local data = Profiles.Get(player)
    if not data then reject("Your profile is still loading."); return end
    if os.clock() < (cooldowns[player] or 0) then reject("Wait a moment before casting again."); return end
    local root, humanoid = rootOf(player)
    local tool = equipped(player)
    if not root or not tool then reject("Equip your fishing rod: press 1 or select it in your Roblox backpack."); return end
    if humanoid:GetState() == Enum.HumanoidStateType.Swimming then
        reject("Climb onto the pier first. Press SPACE to jump out of the water."); return
    end
    if humanoid.SeatPart then reject("Step onto the dock first: press E near the shore."); return end
    local zoneId, zone = zoneAt(root)
    if not zone then reject("Go to the end of the wooden pier, by the FISHING sign."); return end
    local requiredLevel = zone.Level or 1
    if not data.TestMode and Config.Level(data.XP) < requiredLevel then reject(zone.Name .. ": requires level " .. requiredLevel .. "."); return end
    if #data.Bag >= Config.BagCapacity then reject("Your backpack is full. Sell your catch to Mara at the start of the pier."); return end
    local s = {Id = HttpService:GenerateGUID(false), Started = os.clock(), Tool = tool,
        Humanoid = humanoid, WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower,
        JumpHeight = humanoid.JumpHeight, AutoRotate = humanoid.AutoRotate, Origin = root.Position,
        Zone = zone, ZoneId = zoneId, Rod = Config.Rods[data.Rod], LastInput = os.clock(), Held = false}
    sessions[player] = s
    humanoid.WalkSpeed = 0; humanoid.JumpPower = 0; humanoid.JumpHeight = 0; humanoid.AutoRotate = false
    root.CFrame = CFrame.lookAt(root.Position, Vector3.new(root.Position.X, root.Position.Y, root.Position.Z - 10))
    stage(player, s, "Charging", {Started = workspace:GetServerTimeNow()})
end
local function catchFish(player, s)
    if s.Stage~="Reeling" or s.PendingCatch then return end
    local data=Profiles.Get(player);local root=rootOf(player)
    if not data or not root or #data.Bag>=Config.BagCapacity then finish(player,"Could not add your catch.");return end
    local fish=s.Fish
    local kg=math.floor(rng:NextNumber(fish.MinKg,math.min(fish.MaxKg,s.Rod.MaxKg))*100+0.5)/100
    local roll=rng:NextNumber()
    local mutation=roll<0.02 and "gold" or (roll<0.10 and "glow" or "normal")
    local record={Species=fish.Id,Kg=kg,Mutation=mutation,Value=Config.Value(fish,kg,mutation)}
    if fish.Id=="sahur" and s.ZoneId=="Dunes" then
        -- Release fishing controls first so both weapons and sidesteps work.
        -- No persisted catch reservation exists until the encounter is won.
        finish(player)
        if not getSahur():Start(player,s.Id,record,s.Zone,Config.IslandById.Dunes) then
            notice(player,"Could not start the Sahur fight. Check the ServerStorage.SahurBoss model.")
        end
        return
    end
    if not CatchLedger.Reserve(data,Config,record,s.Id) then finish(player,"Could not secure your catch.");return end
    s.PendingCatch=true
    -- The catch is earned now; Landing is presentation only. This guarded,
    -- non-yielding transaction saves the reservation and quest progress together.
    -- Neither preview commands nor catch recovery call RecordCatch again.
    Quests.RecordCatch(data, Config, record, s.ZoneId, workspace:GetServerTimeNow(), player.UserId)
    syncQuests(player, data)
    if s.CastPayload then Update:FireAllClients("CastEnd",{UserId=player.UserId,Id=s.Id});s.CastPayload=nil end
    if s.Bobber then s.Bobber:Destroy();s.Bobber=nil end
    local started=workspace:GetServerTimeNow()
    local duration=Config.Landing.DurationByRarity[fish.Rarity]
    s.LandingUntil=os.clock()+duration
    local finishCF=root.CFrame*CFrame.new(0,1.1,-4.2)
    s.CatchVisual={Id=s.Id,UserId=player.UserId,Species=fish.Id,Mutation=mutation,Kg=kg,
        Origin=Vector3.new(s.Target.X,Config.Ocean.SurfaceY-1.2,s.Target.Z),
        Destination=finishCF.Position,Facing=root.Position,Started=started,Duration=duration,Rarity=fish.Rarity}
    stage(player,s,"Landing",{Started=started,Duration=duration,Species=fish.Id})
    Update:FireAllClients("CatchVisual",s.CatchVisual)
end

local function sell(player)
    if not allow(player, "Sell", 1) then return end
    local validShop = false
    for _,buyer in ipairs(world.Buyers) do
        if nearby(player,buyer.Position,18) then validShop=true; break end
    end
    if not validShop then return end
    local data = Profiles.Get(player)
    if not data then return end
    if sessions[player] then notice(player, "Finish fishing first."); return end
    if #data.Bag == 0 then notice(player, "Your backpack is empty. Try fishing at the end of the pier!"); return end
    local total, count = 0, #data.Bag
    for _, record in ipairs(data.Bag) do total = total + record.Value end
    data.Bag = {}; data.Coins = data.Coins + total
    CatchLedger.Commit(data,Config) -- recover an exceptional full-bag reservation after a sale
    sync(player); notice(player, string.format("Sold %d fish for +%d coins.", count, total))
end
local function buy(player, rodIndex)
    if type(rodIndex) ~= "number" or rodIndex % 1 ~= 0 then return end
    local data = Profiles.Get(player)
    if not data or not nearby(player, world.Shop.Position, 18) then notice(player, "Visit Lev to buy a fishing rod."); return end
    if sessions[player] then notice(player, "Finish fishing first."); return end
    if not Config.Rods[rodIndex] then return end
    if not data.TestMode and rodIndex ~= data.Rod + 1 then return end
    local rod = Config.Rods[rodIndex]
    if not data.TestMode and data.Coins < rod.Price then notice(player, "You need " .. (rod.Price - data.Coins) .. " more coins."); return end
    if not data.TestMode then data.Coins = data.Coins - rod.Price end
    data.Rod = rodIndex
    if player.Character then grantRod(player,player.Character) end
    sync(player); send(player, "Shop", {}); notice(player, "New rod: " .. rod.Name .. ". Equipped and ready!")
end
local function travel(player, toReef)
    if dodges:IsActive(player) then return end
    local origin = toReef and world.Ferry or world.ReturnFerry
    local data = Profiles.Get(player)
    if not data or not allow(player, "Travel", 1) or not nearby(player, origin.Position, 18) then return end
    if sessions[player] then notice(player, "Finish fishing first."); return end
    if toReef and not data.TestMode and Config.Level(data.XP) < 2 then notice(player, "Reach level 2 first. Catch fish to earn XP."); return end
    local root, humanoid = rootOf(player)
    if humanoid and humanoid.SeatPart then notice(player, "Leave the boat first."); return end
    if root then
        local dest = toReef and world.ReefSpawn or world.Spawn
        root.CFrame = CFrame.lookAt(dest, dest + Vector3.new(0, 0, -10))
        notice(player, toReef and "Welcome to Coral Reef. Head to the end of the pier." or "Welcome back to Quiet Cove!")
    end
end
world.Ferry.Travel.Triggered:Connect(function(p) travel(p, true) end)
world.ReturnFerry.Travel.Triggered:Connect(function(p) travel(p, false) end)
boats = BoatService.new(Config,world,Profiles,send,sync,function(p)return sessions[p] ~= nil or dodges:IsActive(p) end)
dialogues=NPCDialogueService.new({Config=Config,Quests=Quests,Profiles=Profiles,Send=send,Sync=sync,Allow=allow,
    Now=function()return workspace:GetServerTimeNow()end,Token=function()return HttpService:GenerateGUID(false)end,
    Busy=function(player)return sessions[player]~=nil or dodges:IsActive(player)
        or (sahur and sahur:IsActive(player)) or false end})
dialogues:Register("merchant","merchant",world.Merchant,"Sell my catch",sell)
dialogues:Register("rodsmith","rodsmith",world.Shop,"Browse fishing rods",function(player)send(player,"Shop",{})end)
for index,buyer in ipairs(world.Buyers) do
    if buyer~=world.Merchant then dialogues:Register("buyer_"..index,"merchant",buyer,"Sell my catch",sell) end
end
for id,dock in pairs(world.Docks or {}) do
    dialogues:Register("captain_"..id,"captain",dock.Captain,"Boats: buy or launch",function(player)
        send(player,"BoatShop",{Dock=id})
    end)
end
Action.OnServerEvent:Connect(function(player, kind, id, value)
    if type(kind) ~= "string" or not limitsPerSecond[kind] or not allow(player, kind, limitsPerSecond[kind]) then return end
    if kind == "Dodge" then dodges:Request(player, id, value, workspace:GetServerTimeNow()); return end
    if kind == "WeaponBuy" then weaponShop:Buy(player, value); return end
    if kind == "NPCChoice" then dialogues:Request(player,id,value); return end
    if kind == "Ready" then
        sync(player)
        -- Late joiners get current lines too, but never other players' rewards.
        for _, active in pairs(sessions) do
            if active.CastPayload then send(player, "CastVisual", active.CastPayload) end
            if active.CatchVisual then send(player,"CatchVisual",active.CatchVisual) end
        end
        return
    end
    if kind == "QuestClaim" then
        -- Old clients cannot bypass the NPC's proximity/session checks.
        syncQuests(player)
        notice(player,"Talk to the NPC who gave you the quest to collect your reward.")
        return
    end
    if kind == "Begin" then beginCast(player); return end
    if kind == "Buy" then buy(player, value); return end
    if kind == "BoatBuy" then boats:Buy(player,value); return end
    if kind == "BoatSpawn" then boats:Spawn(player,value); return end
    if kind == "BoatInput" then boats:Input(player,value); return end
    if kind == "BoatDock" then boats:Dock(player); return end
    local s = sessions[player]
    if not s or type(id) ~= "string" or id ~= s.Id then return end
    if kind == "Cancel" then
        if s.Stage=="Landing" then return end -- already won; finish the short presentation
        finish(player, "Cast cancelled."); return end
    if kind == "Release" then releaseCast(player, s); return end
    if kind == "Shake" and s.Stage == "Waiting" and os.clock() - s.LastShake >= 0.45 then
        s.LastShake = os.clock(); s.BiteAt = math.max(os.clock() + 0.45, s.CastAt + 1.5, s.BiteAt - 0.7)
        if s.Bobber then s.Bobber.Color = Color3.fromRGB(255, 213, 136) end
        send(player, "Shake", {}); return
    end
    if kind == "Hook" and s.Stage == "Bite" and os.clock() <= s.HookUntil then
        local fight=FightBalance.Resolve(Config,s.Fish,s.Rod)
        s.Reel=Reel.new(fight.Difficulty,fight.Width,fight.Resilience,rng:NextNumber(0,math.pi*2),
            fight.Pattern,fight.Tuning,rng:NextInteger(1,2147483646))
        s.Held=false;s.LastInput=os.clock();s.SendAt=0
        stage(player,s,"Reeling",{Width=fight.Width});return
    end
    if kind == "Input" and s.Stage == "Reeling" and type(value) == "boolean" then
        s.Held = value; s.LastInput = os.clock()
    end
end)
local accumulator, environment = 0, 0
RunService.Heartbeat:Connect(function(dt)
    waterHazard:Step(workspace:GetServerTimeNow())
    dodges:Step(workspace:GetServerTimeNow())
    dialogues:Step()
    if sahur then sahur:Step(workspace:GetServerTimeNow()) end
    environment = environment + dt
    Lighting.ClockTime = (VisualTheme.Lighting.ClockTime + environment / 30) % 24 -- 12-minute full day.
    accumulator = accumulator + math.min(dt, 0.25)
    while accumulator >= 1 / 60 do
        accumulator = accumulator - 1 / 60
        local now = os.clock()
        for player, s in pairs(sessions) do
            local root = rootOf(player)
            if not root or not Profiles.Get(player) or equipped(player) ~= s.Tool or (root.Position - s.Origin).Magnitude > 10 then
                finish(player, "Fishing interrupted.")
            elseif s.Humanoid:GetState() == Enum.HumanoidStateType.Swimming then
                finish(player, "Fishing interrupted: you are in the water. Press SPACE to jump out.")
            elseif s.Stage == "Landing" then
                if now>=s.LandingUntil then finish(player) end
            elseif s.Stage == "Charging" and now - s.Started >= 4 then
                releaseCast(player, s)
            elseif s.Stage == "Casting" and now >= s.LandAt then
                stage(player, s, "Waiting", {Power=s.Power, Zone=s.Zone.Name})
            elseif s.Stage == "Waiting" and now >= s.BiteAt then
                local hookWindow = s.Fish and s.Fish.HookWindow or Config.HookWindow
                s.HookUntil = now + hookWindow
                stage(player, s, "Bite", {Deadline = workspace:GetServerTimeNow() + hookWindow, Duration = hookWindow})
            elseif s.Stage == "Bite" and now > s.HookUntil then
                finish(player, "You missed the bite. Try again!")
            elseif s.Stage == "Reeling" then
                local held = s.Held and now - s.LastInput < 1
                local result = Reel.step(s.Reel, held, 1 / 60)
                if result == "caught" then catchFish(player, s)
                elseif result == "lost" then finish(player, "Progress reached 0% and the fish escaped. Keep the marker inside the blue bar.")
                elseif now >= s.SendAt then
                    s.SendAt = now + 0.08
                    send(player, "Reel", {Id = s.Id, Bar = s.Reel.bar, Fish = s.Reel.fish,
                        Progress = s.Reel.progress, Width = s.Reel.width, Inside = s.Reel.inside, Cue = s.Reel.cue or ""})
                end
            end
            if sessions[player] == s and s.Bobber then
                if s.Stage == "Casting" then
                    local t = CastMath.Progress(now, s.CastAt, s.Swing, s.Flight)
                    s.Bobber.Position = CastMath.Position(s.FlightOrigin, s.Target, t, s.Arc, s.LaunchDirection, s.LaunchVelocity, s.Flight)
                else
                    s.Bobber.Position = s.Target + Vector3.new(0, math.sin(now * (s.Stage == "Bite" and 18 or 3)) * 0.15, 0)
                end
            end
            -- Count only server-simulated fishing with a valid character/tool.
            -- Ordinary idle time, sailing, menus and disconnected clients do not count.
            if sessions[player] == s and root and equipped(player) == s.Tool
                and (root.Position - s.Origin).Magnitude <= 10
                and s.Humanoid:GetState() ~= Enum.HumanoidStateType.Swimming
                and (s.Stage == "Charging" or s.Stage == "Casting" or s.Stage == "Waiting" or s.Stage == "Bite"
                    or (s.Stage == "Reeling" and now - s.LastInput < 2)) then
                questActivity[player] = (questActivity[player] or 0) + 1 / 60
            end
        end
    end
end)
grantRod = function(player, character)
    local humanoid=character:WaitForChild("Humanoid",10)
    local backpack=player:WaitForChild("Backpack",10)
    local data=Profiles.Get(player)
    if not humanoid or humanoid.Health<=0 or not backpack or character~=player.Character or not data then return end
    local rod=Config.Rods[data.Rod]
    local current=equipped(player)
    if current and current:GetAttribute("RodStyle")==rod.Id then return end
    for _,parent in ipairs({character,backpack}) do
        for _,item in ipairs(parent:GetChildren()) do
            if item:IsA("Tool") and item:GetAttribute("QuietCoveRod") then item:Destroy() end
        end
    end
    local tool=Models.Rod(rod.Id,false)
    tool.Parent=backpack;humanoid:EquipTool(tool)
end
local function playerAdded(player)
    if loading[player] then return end
    loading[player] = true
    local stats = Instance.new("Folder"); stats.Name = "leaderstats"; stats.Parent = player
    for _, name in ipairs({"Coins", "Level", "Caught"}) do local v = Instance.new("IntValue"); v.Name = name; v.Parent = stats end
    connections[player] = player.CharacterAdded:Connect(function(character)
        waterHazard:Remove(player)
        if dialogues then dialogues:Close(player) end
        if sahur then sahur:Remove(player) end
        dodges:Remove(player)
        finish(player)
        task.spawn(function()
            local untilTime=os.clock()+20
            while not Profiles.Get(player) and player.Parent==Players and os.clock()<untilTime do task.wait(0.1) end
            if Profiles.Get(player) then grantRod(player,character);weaponShop:Grant(player,character) end
        end)
    end)
    if not Profiles.Load(player) then
        if player.Parent == Players then player:Kick("Your profile could not be loaded safely. Wait a moment, then rejoin.") end
        return
    end
    if player.Parent ~= Players then Profiles.Save(player, true); return end
    if player.Character then grantRod(player,player.Character);weaponShop:Grant(player,player.Character) end
    sync(player)
    local loaded = Profiles.Get(player)
    if loaded and loaded.TestMode then
        notice(player, "ASUL7664 · TESTER: unlimited coins and XP. All levels are unlocked. Purchases and catches in this test session do not affect your main profile.")
    end
end
Players.PlayerAdded:Connect(playerAdded)
Players.PlayerRemoving:Connect(function(player)
    waterHazard:Remove(player)
    if dialogues then dialogues:Close(player,true) end
    if sahur then sahur:Remove(player) end
    dodges:Remove(player)
    finish(player)
    if connections[player] then connections[player]:Disconnect(); connections[player] = nil end
    limits[player] = nil; cooldowns[player] = nil; loading[player] = nil
    local data = Profiles.Get(player)
    if data and (questActivity[player] or 0) > 0 then
        Quests.AddActivity(data, Config, questActivity[player], workspace:GetServerTimeNow(), player.UserId)
    end
    questActivity[player] = nil; questSentAt[player] = nil
    Profiles.Save(player, true)
end)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(playerAdded, player) end
-- Discovery never grants money: no farming exploits through respawn/teleport.
local discoveryAt=0
RunService.Heartbeat:Connect(function()
    if os.clock()<discoveryAt then return end
    discoveryAt=os.clock()+1
    for _,player in ipairs(Players:GetPlayers()) do
        local data=Profiles.Get(player);local root=rootOf(player)
        if data then
            local now = workspace:GetServerTimeNow()
            local _, reset = Quests.Ensure(data, Config, now, player.UserId)
            local seconds = questActivity[player] or 0
            questActivity[player] = nil
            local changed = seconds > 0 and Quests.AddActivity(data, Config, seconds, now, player.UserId)
            if reset or (changed and os.clock() - (questSentAt[player] or 0) >= 5) then syncQuests(player, data) end
        end
        if data and root then
            data.Visited=data.Visited or {Cove=true}
            for _,island in ipairs(Config.Islands) do
                local dx,dz=root.Position.X-island.X,root.Position.Z-island.Z
                if not data.Visited[island.Id] and dx*dx+dz*dz<(island.Radius+40)^2 and math.abs(root.Position.Y)<70 then
                    data.Visited[island.Id]=true;sync(player)
                    notice(player,"Island discovered: "..island.Name..". "..island.Target..". Fishing unlocks at level "..island.Level..".")
                end
            end
        end
    end
end)
Profiles.Start()
print("[QuietCove] v" .. Config.Version .. " ready. " .. (Profiles.MemoryOnly and "Studio: session-only progress." or "Persistent profiles enabled."))
