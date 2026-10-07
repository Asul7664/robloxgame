-- Engine/service doubles for exercising the actual server entrypoint and lease
-- profile module in Lune. Fishing motion, world building, boat physics and tester
-- identity resolution are isolated; quest, weapon ownership and catch transactions
-- run through the real Main, Profiles and shop modules.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Environment = {}
local CF, V = roblox.CFrame, roblox.Vector3
local function copy(value)
    if type(value) ~= "table" then return value end
    -- Roblox remotes transmit Instance identity rather than serializing parents.
    if rawget(value, "_properties") then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end
local function signal()
    local self = {listeners = {}}
    function self:Connect(callback)
        local entry = {callback = callback, connected = true}
        table.insert(self.listeners, entry)
        return {Disconnect = function() entry.connected = false end}
    end
    function self:Fire(...)
        for _, entry in ipairs(self.listeners) do
            if entry.connected then entry.callback(...) end
        end
    end
    return self
end
local methods = {}
local function node(class, name)
    local properties = {ClassName = class, Name = name or class, Children = {}, Attributes = {}, CFrame = CF.new()}
    return setmetatable({_properties = properties}, {
        __index = function(self, key)
            if key == "Position" then return properties.CFrame.Position end
            if methods[key] then return methods[key] end
            if properties[key] ~= nil then return properties[key] end
            for _, child in ipairs(properties.Children) do if child.Name == key then return child end end
        end,
        __newindex = function(self, key, value)
            if key == "Parent" then
                if properties.Parent then
                    local children = properties.Parent.Children
                    local index = table.find(children, self)
                    if index then table.remove(children, index) end
                end
                properties.Parent = value
                if value then table.insert(value.Children, self) end
            elseif key == "Position" then properties.CFrame = CF.new(value)
            else properties[key] = value end
        end,
    })
end
function methods:FindFirstChild(name)
    for _, child in ipairs(self.Children) do if child.Name == name then return child end end
    return nil
end
function methods:WaitForChild(name) return self:FindFirstChild(name) end
function methods:FindFirstChildOfClass(class)
    for _, child in ipairs(self.Children) do if child.ClassName == class then return child end end
    return nil
end
function methods:GetChildren() return table.clone(self.Children) end
function methods:GetDescendants()
    local descendants = {}
    for _, object in ipairs(self.Children) do
        table.insert(descendants, object)
        for _, nested in ipairs(object:GetDescendants()) do table.insert(descendants, nested) end
    end
    return descendants
end
function methods:IsA(class) return self.ClassName == class or (class == "BasePart" and self.ClassName == "Part") end
function methods:GetAttribute(key) return self.Attributes[key] end
function methods:SetAttribute(key, value) self.Attributes[key] = value end
function methods:Destroy() self.Parent = nil; self.Destroyed = true end
function methods:Clone()
    if self.Archivable == false then return nil end
    local cloned = node(self.ClassName, self.Name)
    for key, value in pairs(self._properties) do
        if key ~= "Parent" and key ~= "Children" and key ~= "Destroyed" then cloned[key] = copy(value) end
    end
    for _, object in ipairs(self.Children) do
        local nested = object:Clone()
        if nested then nested.Parent = cloned end
    end
    return cloned
end
function methods:GetState() return self.State or "Running" end
function methods:EquipTool(tool)
    local character = self.Parent
    local player = character.PlayerOwner
    local backpack = player and player:FindFirstChild("Backpack")
    if backpack then
        for _, current in ipairs(character:GetChildren()) do
            if current:IsA("Tool") and current ~= tool then current.Parent = backpack end
        end
    end
    tool.Parent = character
end
function methods:Kick(message) self.Kicked = message end
local function child(parent, class, name)
    local result = node(class, name); result.Parent = parent; return result
end
local function prompt(parent, name)
    local result = child(parent, "ProximityPrompt", name)
    result.Triggered = signal()
    return result
end
function Environment.new()
    local self = {clock = 100, epoch = 1760313600, messages = {}, broadcasts = {}, documents = {}, modules = {}}
    local players = node("Players", "Players")
    players.PlayerAdded, players.PlayerRemoving = signal(), signal()
    function players:GetPlayers()
        local list = {}
        for _, value in ipairs(self.Children) do if value:IsA("Player") then table.insert(list, value) end end
        return list
    end
    local run = {Heartbeat = signal(), IsStudio = function() return false end}
    local guids = 0
    local http = {GenerateGUID = function() guids += 1; return "integration-" .. guids end}
    local datastore = {}
    function datastore:UpdateAsync(key, transform)
        local nextValue = transform(copy(self.owner.documents[key]))
        if nextValue == nil then return nil end
        self.owner.documents[key] = copy(nextValue)
        return copy(nextValue)
    end
    datastore.owner = self
    local dataService = {GetDataStore = function() return datastore end}
    local replicated = node("ReplicatedStorage")
    local shared = child(replicated, "Folder", "QuietCove")
    local server = node("Folder", "QuietCove")
    for _, name in ipairs({"Config", "BrainrotExpansion", "Quests", "CatchLedger", "CastMath", "Reel", "FightBalance", "EquipmentModels", "SideDodge", "WeaponCatalog"}) do child(shared, "ModuleScript", name) end
    for _, name in ipairs({"Profiles", "TesterAccess", "World", "Archipelago", "BoatService", "DodgeService", "WeaponShop", "WeaponModels"}) do child(server, "ModuleScript", name) end
    local mainScript = child(server, "Script", "Main")
    local action, update = child(shared, "RemoteEvent", "Action"), child(shared, "RemoteEvent", "Update")
    action.OnServerEvent = signal()
    function update:FireClient(player, kind, payload)
        table.insert(self.owner.messages, {Player = player, Kind = kind, Payload = copy(payload)})
    end
    function update:FireAllClients(kind, payload)
        table.insert(self.owner.broadcasts, {Kind = kind, Payload = copy(payload)})
    end
    update.owner = self
    local lighting = {ClockTime = 11}
    local storage = node("ServerStorage", "ServerStorage")
    local weapons = child(storage, "Folder", "Weapons")
    for _, id in ipairs({"Saber", "Musket"}) do
        local tool = child(weapons, "Tool", id)
        tool:SetAttribute("WeaponType", id)
        child(tool, "Part", "Handle")
    end
    local services = {Players = players, RunService = run, HttpService = http,
        DataStoreService = dataService, ReplicatedStorage = replicated, Lighting = lighting,
        ServerStorage = storage}
    local game = {GetService = function(_, name) return assert(services[name], name) end,
        BindToClose = function(_, callback) self.close = callback end}
    local workspace = node("Workspace", "Workspace")
    workspace.GetServerTimeNow = function() return self.epoch + self.clock end
    local stall = child(workspace, "Model", "WeaponStall")
    child(stall, "Folder", "Displays")
    local counter = child(stall, "Part", "Counter")
    counter.Position = V.new(24, 9, 3)
    prompt(counter, "WeaponShopPrompt")
    local fakeOs = table.clone(os)
    fakeOs.clock = function() return self.clock end
    fakeOs.time = function() return self.epoch + math.floor(self.clock) end
    local fakeTask = {spawn = function(callback, ...) return callback(...) end, wait = function() return nil end}
    local fakeEnum = {PartType = {Ball = "Ball"}, HumanoidStateType = {Swimming = "Swimming", PlatformStanding = "PlatformStanding"}}
    local world = {Model = node("Model"), Spots = {Cove = {Name = "Тихая бухта", Center = V.new(0, 4, 0), Radius = 25, Level = 1}},
        Spawn = V.new(0, 4, 0), ReefSpawn = V.new(450, 4, -650)}
    world.Merchant, world.Shop, world.Ferry, world.ReturnFerry = node("Part"), node("Part"), node("Part"), node("Part")
    prompt(world.Merchant, "MerchantPrompt"); prompt(world.Shop, "RodsmithPrompt")
    prompt(world.Ferry, "Travel"); prompt(world.ReturnFerry, "Travel")
    world.Buyers = {world.Merchant}
    local access = {Resolve = function() end}
    function access.Sandbox(player, saved)
        if not player.Tester then return nil end
        local data = copy(saved); data.TestMode = true; data.Coins = 1000000000; data.XP = 99999900
        return data
    end
    function access.Refresh(data) data.Coins = 1000000000; data.XP = 99999900; return data end
    local reel = {}
    function reel.new() return {bar=.5, fish=.5, progress=.5, width=.3, inside=true} end
    function reel.step() return self.reelResult end
    local balance = {Resolve = function(_, fish, rod)
        return {Difficulty = fish.Difficulty, Width = rod.Width, Resilience = rod.Resilience, Pattern = fish.Pattern}
    end}
    local models = {}
    function models.Rod(style)
        local tool = node("Tool", "Rod")
        tool:SetAttribute("QuietCoveRod", true); tool:SetAttribute("RodStyle", style)
        local handle = child(tool, "Part", "Handle")
        local tip = child(handle, "Attachment", "Tip"); tip.Position = V.new(0, 3, 0)
        return tool
    end
    local boats = {}
    function boats.new()
        return {Buy = function() end, Spawn = function() end, Input = function() end, Dock = function() end}
    end
    self.modules.TesterAccess, self.modules.Reel, self.modules.FightBalance = access, reel, balance
    self.modules.World = {Build = function() return world end}
    self.modules.Archipelago = {Attach = function(value) return value end}
    self.modules.BoatService, self.modules.EquipmentModels = boats, models
    -- Geometry is covered separately by tests/weapon_models. Here the factory
    -- supplies its canonical version keys so actual shop migration is exercised.
    local weaponModels = {}
    function weaponModels.Key(id) return "test-" .. id end
    function weaponModels.Sync(bank, displays)
        local keys = {}
        for _, id in ipairs({"Saber", "Musket"}) do
            local key = weaponModels.Key(id)
            keys[id] = key
            local stock = bank:FindFirstChild(id)
            if stock then stock:SetAttribute("WeaponModelKey", key) end
        end
        return keys
    end
    self.modules.WeaponModels = weaponModels
    local paths = {Config = "src/shared/Config.luau", BrainrotExpansion = "src/shared/BrainrotExpansion.luau",
        Quests = "src/shared/Quests.luau", CatchLedger = "src/shared/CatchLedger.luau",
        CastMath = "src/shared/CastMath.luau", Profiles = "src/server/Profiles.luau",
        SideDodge = "src/shared/SideDodge.luau", DodgeService = "src/server/DodgeService.luau",
        WeaponCatalog = "src/shared/WeaponCatalog.luau", WeaponShop = "src/server/WeaponShop.luau"}
    local function environment(scriptNode)
        return {game = game, workspace = workspace, script = scriptNode, os = fakeOs, task = fakeTask,
            Enum = fakeEnum, Vector3 = V, CFrame = CF, Color3 = roblox.Color3,
            Instance = {new = node}, Random = {new = function()
                return {NextNumber = function(_, lo, hi) return lo and lo + (hi - lo) * .1 or 0 end,
                    NextInteger = function(_, lo) return lo end}
            end}, require = function(module)
                if self.modules[module.Name] == nil then
                    local source = fs.readFile(assert(paths[module.Name], "Unexpected require: " .. module.Name))
                    self.modules[module.Name] = luau.load(source, {environment = environment(module)})()
                end
                return self.modules[module.Name]
            end, warn = function() end, print = function() end}
    end
    self.environment = environment
    self.Players, self.RunService, self.Action, self.Update, self.World = players, run, action, update, world
    self.Workspace, self.ServerStorage, self.Weapons, self.WeaponCounter = workspace, storage, weapons, counter
    self.shared, self.server, self.mainScript = shared, server, mainScript
    self.Config = environment(mainScript).require(shared.Config)
    self.Quests = environment(mainScript).require(shared.Quests)
    self.Profiles = environment(mainScript).require(server.Profiles)
    self.Ledger = environment(mainScript).require(shared.CatchLedger)
    return setmetatable(self, {__index = Environment})
end
function Environment:Start()
    luau.load(fs.readFile("src/server/Main.server.luau"), {environment = self.environment(self.mainScript)})()
end
function Environment:Player(id, tester)
    local player = node("Player", "IntegrationPlayer" .. id)
    player.UserId, player.DisplayName, player.Tester = id, "Integration player", tester
    player.CharacterAdded = signal()
    child(player, "Backpack", "Backpack")
    player.Character = self:Character()
    player.Character.PlayerOwner = player
    player.Parent = self.Players
    return player
end
function Environment:Character()
    local character = node("Model", "Character")
    character.Parent = self.World.Model
    local humanoid = child(character, "Humanoid", "Humanoid")
    humanoid.Died = signal()
    humanoid.Health, humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight, humanoid.AutoRotate = 100, 16, 50, 7.2, true
    local root = child(character, "Part", "HumanoidRootPart"); root.Position = V.new(0, 4, 0)
    return character
end
function Environment:Advance(seconds)
    for _ = 1, math.floor(seconds * 60 + .5) do
        self.clock += 1 / 60
        self.RunService.Heartbeat:Fire(1 / 60)
    end
end
function Environment:Fire(player, kind, id, value) self.Action.OnServerEvent:Fire(player, kind, id, value) end
function Environment:Last(player, kind)
    for index = #self.messages, 1, -1 do
        local message = self.messages[index]
        if message.Player == player and message.Kind == kind then return message.Payload end
    end
end
function Environment:Now() return self.epoch + math.floor(self.clock) end
function Environment:Reset(player)
    player.Character = self:Character()
    player.Character.PlayerOwner = player
    player.CharacterAdded:Fire(player.Character)
end
function Environment:Leave(player)
    self.Players.PlayerRemoving:Fire(player)
    player.Parent = nil
end
Environment.Copy = copy
return Environment
