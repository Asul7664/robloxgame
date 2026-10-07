-- Deterministic engine/service doubles for the real combat entrypoints.
-- Geometry query results are supplied by the test; animation CFrames are real
-- Lune Roblox datatypes. This is not a Studio physics or visual test.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Environment = {}
local V, CF = roblox.Vector3, roblox.CFrame

local function signal()
    local self = {Listeners = {}}
    function self:Connect(callback)
        local entry = {Callback = callback, Connected = true}
        table.insert(self.Listeners, entry)
        return {Disconnect = function() entry.Connected = false end}
    end
    function self:Fire(...)
        for _, entry in ipairs(table.clone(self.Listeners)) do
            if entry.Connected then entry.Callback(...) end
        end
    end
    function self:Count()
        local count = 0
        for _, entry in ipairs(self.Listeners) do if entry.Connected then count += 1 end end
        return count
    end
    return self
end

local methods = {}
function methods:IsA(class)
    return self.ClassName == class or (class == "BasePart" and (self.ClassName == "Part" or self.ClassName == "MeshPart"))
end
function methods:FindFirstChild(name, recursive)
    for _, child in ipairs(self.Children) do if child.Name == name then return child end end
    if recursive then
        for _, child in ipairs(self.Children) do
            local found = child:FindFirstChild(name, true)
            if found then return found end
        end
    end
end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name), "Missing test node " .. name) end
function methods:FindFirstChildOfClass(class)
    for _, child in ipairs(self.Children) do if child:IsA(class) then return child end end
end
function methods:FindFirstAncestorOfClass(class)
    local parent = self.Parent
    while parent do if parent:IsA(class) then return parent end; parent = parent.Parent end
end
function methods:GetChildren() return table.clone(self.Children) end
function methods:GetDescendants()
    local result = {}
    local function visit(parent)
        for _, child in ipairs(parent.Children) do table.insert(result, child); visit(child) end
    end
    visit(self)
    return result
end
function methods:GetAttribute(name) return self.Attributes[name] end
function methods:SetAttribute(name, value)
    self.Attributes[name] = value
    if self.AttributeSignals[name] then self.AttributeSignals[name]:Fire() end
end
function methods:GetAttributeChangedSignal(name)
    self.AttributeSignals[name] = self.AttributeSignals[name] or signal()
    return self.AttributeSignals[name]
end
function methods:GetPropertyChangedSignal(name)
    self.PropertySignals[name] = self.PropertySignals[name] or signal()
    return self.PropertySignals[name]
end
function methods:Destroy()
    self.Destroying:Fire()
    for _, child in ipairs(table.clone(self.Children)) do child:Destroy() end
    self.Parent = nil; self.Destroyed = true
end
function methods:TakeDamage(amount)
    table.insert(self.DamageCalls, amount)
    self.Health = math.max(0, self.Health - amount)
    self.HealthChanged:Fire(self.Health)
    if self.Health <= 0 then self.Died:Fire() end
end
function methods:GetState() return self.State or "Running" end
function methods:Play() self.Played = true end
function methods:Emit(count) self.Emitted = (self.Emitted or 0) + count end
function methods:Clone()
    local copy = self.Owner:Node(self.ClassName, self.Name)
    for key, value in pairs(self._properties) do
        if key ~= "Children" and key ~= "Parent" and key ~= "Owner" and key ~= "Destroying"
            and key ~= "Attributes" and key ~= "AttributeSignals" and key ~= "PropertySignals"
            and key ~= "OnServerEvent" and key ~= "OnClientEvent" then
            copy[key] = value
        end
    end
    copy.Attributes = table.clone(self.Attributes)
    for _, child in ipairs(self.Children) do child:Clone().Parent = copy end
    return copy
end
function methods:FireClient(player, ...)
    local args = table.pack(...)
    table.insert(self.Owner.Messages, {Remote = self.Name, Player = player, Args = args})
    if self.Owner.ClientStarted and player == self.Owner.Player then self.OnClientEvent:Fire(...) end
end
function methods:FireServer(...)
    local args = table.pack(...)
    table.insert(self.Owner.Requests, {Remote = self.Name, Args = args})
    if self.Owner.ServerStarted then self.OnServerEvent:Fire(self.Owner.Player, ...) end
end

function Environment:Node(class, name, parent)
    local properties = {ClassName = class, Name = name or class, Owner = self,
        Children = {}, Attributes = {}, AttributeSignals = {}, PropertySignals = {},
        CFrame = CF.new(), Transform = CF.new(), C0 = CF.new(),
        Destroying = signal(), AncestryChanged = signal()}
    if class == "Humanoid" then
        properties.Health, properties.MaxHealth = 100, 100
        properties.HealthChanged, properties.Died = signal(), signal()
        properties.DamageCalls = {}; properties.CameraOffset = V.zero
    elseif class == "RemoteEvent" then
        properties.OnServerEvent, properties.OnClientEvent = signal(), signal()
    elseif class == "Part" then
        properties.Size = V.new(1, 1, 1)
    end
    local object
    object = setmetatable({_properties = properties}, {
        __index = function(_, key)
            if key == "Position" and (class == "Part" or class == "MeshPart") then return properties.CFrame.Position end
            if key == "WorldPosition" and class == "Attachment" then
                return properties.Parent.CFrame:PointToWorldSpace(properties.Position or V.zero)
            end
            if methods[key] then return methods[key] end
            if properties[key] ~= nil then return properties[key] end
            for _, child in ipairs(properties.Children) do if child.Name == key then return child end end
        end,
        __newindex = function(_, key, value)
            if key == "Parent" then
                if properties.Parent then
                    local index = table.find(properties.Parent.Children, object)
                    if index then table.remove(properties.Parent.Children, index) end
                end
                properties.Parent = value
                if value then table.insert(value.Children, object) end
                properties.AncestryChanged:Fire(object, value)
            elseif key == "Position" and (class == "Part" or class == "MeshPart") then properties.CFrame = CF.new(value)
            else
                properties[key] = value
                if properties.PropertySignals[key] then properties.PropertySignals[key]:Fire() end
            end
        end,
    })
    table.insert(self.Objects, object)
    if parent then object.Parent = parent end
    return object
end

function Environment.new()
    local self = setmetatable({Time = 100, Objects = {}, Queue = {}, Messages = {}, Requests = {},
        Queries = {}, Rays = {}, Tweens = {}, DebrisItems = {}, Modules = {}}, {__index = Environment})
    self.Players = self:Node("Players")
    self.Players.PlayerAdded, self.Players.PlayerRemoving = signal(), signal()
    function self.Players:GetPlayers() return self:GetChildren() end
    self.Run = {RenderStepped = signal(), Heartbeat = signal(), PostSimulation = signal()}
    self.UIS = {InputBegan = signal(), GetFocusedTextBox = function() return nil end}
    self.Replicated = self:Node("ReplicatedStorage")
    self.Storage = self:Node("ServerStorage")
    self.World = self:Node("Workspace")
    self.World.CurrentCamera = self:Node("Camera"); self.World.CurrentCamera.FieldOfView = 70
    function self.World:GetServerTimeNow() return self.Owner.Time end
    function self.World:GetPartBoundsInBox(box, size, params)
        table.insert(self.Owner.Queries, {Box = box, Size = size, Params = params})
        return self.Owner.BoxParts or {}
    end
    function self.World:Raycast(origin, direction, params)
        table.insert(self.Owner.Rays, {Origin = origin, Direction = direction, Params = params})
        return self.Owner.RayResult
    end
    local combat = self:Node("Folder", "Combat", self.Replicated)
    self:Node("ModuleScript", "Config", combat)
    self:Node("ModuleScript", "WeaponAnimator", combat)
    self.Combat = combat
    local tweenService = {}
    function tweenService:Create(target, info, goals)
        local record = {Target = target, Info = info, Goals = goals, At = self.Owner.Time}
        table.insert(self.Owner.Tweens, record)
        return {Play = function()
            record.Played = true
            for key, value in pairs(goals) do target[key] = value end
        end, Cancel = function() record.Cancelled = true end}
    end
    tweenService.Owner = self
    local debris = {AddItem = function(_, object, lifetime)
        table.insert(self.DebrisItems, {Object = object, Lifetime = lifetime})
        table.insert(self.Queue, {At = self.Time + lifetime, Callback = function() object:Destroy() end, Args = {}})
    end}
    self.Services = {Players = self.Players, ReplicatedStorage = self.Replicated,
        ServerStorage = self.Storage, RunService = self.Run, TweenService = tweenService,
        UserInputService = self.UIS, Debris = debris}
    local enum = setmetatable({}, {__index = function(t, group)
        local values = setmetatable({}, {__index = function(inner, key) rawset(inner, key, group .. "." .. key); return inner[key] end})
        rawset(t, group, values); return values
    end})
    self.Enum = enum
    local clock = table.clone(os); clock.clock = function() return self.Time end
    self.Globals = {game = {GetService = function(_, name) return assert(self.Services[name], name) end},
        workspace = self.World, Enum = enum, os = clock,
        Instance = {new = function(class, parent) return self:Node(class, nil, parent) end},
        Vector3 = V, Vector2 = roblox.Vector2, CFrame = CF, Color3 = roblox.Color3,
        UDim2 = roblox.UDim2, UDim = roblox.UDim,
        ColorSequence = roblox.ColorSequence, NumberSequence = roblox.NumberSequence,
        NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, NumberRange = roblox.NumberRange,
        OverlapParams = {new = function() return {} end}, RaycastParams = {new = function() return {} end},
        TweenInfo = {new = function(time, style, direction) return {Time = time, Style = style, Direction = direction} end},
        task = {delay = function(delay, callback, ...)
            table.insert(self.Queue, {At = self.Time + delay, Callback = callback, Args = table.pack(...)})
        end, defer = function(callback, ...)
            table.insert(self.Queue, {At = self.Time, Callback = callback, Args = table.pack(...)})
        end},
        typeof = function(value)
            if type(value) == "userdata" then return typeof(value) end
            return type(value)
        end,
        require = function(module)
            if not self.Modules[module.Name] then
                local paths = {Config = "src/combat/Config.luau", WeaponAnimator = "src/combat/WeaponAnimator.luau"}
                self.Modules[module.Name] = self:Execute(assert(paths[module.Name], module.Name))
            end
            return self.Modules[module.Name]
        end, warn = function() end}
    return self
end

function Environment:Execute(path)
    return luau.load(fs.readFile(path), {environment = self.Globals})()
end
function Environment:Flush()
    local ran = true
    while ran do
        ran = false
        for index, item in ipairs(self.Queue) do
            if item.At <= self.Time + 1e-8 then
                table.remove(self.Queue, index); item.Callback(table.unpack(item.Args)); ran = true; break
            end
        end
    end
end
function Environment:Advance(seconds, dt)
    dt = dt or 1 / 120
    local target = self.Time + seconds
    self:Flush()
    while self.Time < target - 1e-9 do
        local step = math.min(dt, target - self.Time)
        self.Time += step; self:Flush()
        self.Run.RenderStepped:Fire(step)
        self.Run.Heartbeat:Fire(step)
        self.Run.PostSimulation:Fire(step)
    end
end
function Environment:Character(name)
    local character = self:Node("Model", name or "Character", self.World)
    local humanoid = self:Node("Humanoid", "Humanoid", character)
    local root = self:Node("Part", "HumanoidRootPart", character)
    local torso = self:Node("Part", "Torso", character)
    for _, name in ipairs({"Right Shoulder", "Right Elbow", "RootJoint", "RightGrip"}) do
        self:Node("Motor6D", name, torso)
    end
    return character, humanoid, root
end
function Environment:AddPlayer(id, initial)
    local player = self:Node("Player", "Player" .. id, self.Players)
    player.UserId = id; player.CharacterAdded = signal(); player.CharacterRemoving = signal()
    self:Node("Backpack", "Backpack", player); self:Node("PlayerGui", "PlayerGui", player)
    player.Character = self:Character("Character" .. id)
    if not self.Player then self.Player = player; self.Players.LocalPlayer = player end
    if not initial then self.Players.PlayerAdded:Fire(player) end
    return player
end
function Environment:Weapon(kind, parent)
    local tool = self:Node("Tool", kind, parent)
    tool:SetAttribute("WeaponType", kind)
    self:Node("Part", "Handle", tool)
    if kind == "Saber" then
        local blade = self:Node("Part", "Blade", tool); blade.Size = V.new(.08, 3.4, .28)
    else
        local barrel = self:Node("Part", "Barrel", tool)
        local muzzle = self:Node("Attachment", "Muzzle", barrel); muzzle.Position = V.new(0, 2, 0)
    end
    return tool
end
function Environment:StartServer()
    self:Execute("src/combat/CombatServer.server.luau"); self.ServerStarted = true; self:Flush()
end
function Environment:StartClient()
    for _, name in ipairs({"Swing", "Shot", "ConfirmHit"}) do
        if not self.Combat:FindFirstChild(name) then self:Node("RemoteEvent", name, self.Combat) end
    end
    self:Execute("src/client/CombatClient.client.luau"); self.ClientStarted = true
end
function Environment:Click(processed)
    self.UIS.InputBegan:Fire({UserInputType = self.Enum.UserInputType.MouseButton1}, processed == true)
end
Environment.Signal = signal
return Environment
