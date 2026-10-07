-- lune run tests/weapon_camera.luau
-- Execute the actual camera module with deterministic Roblox service doubles.
-- These checks cover ownership and cleanup; visual camera feel needs Studio.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local V, CF = roblox.Vector3, roblox.CFrame
-- Lune 0.10.5's native lookAt reflects Z. Match Roblox's orthonormal basis
-- explicitly so the same bug cannot cancel itself between camera and root.
local frames = setmetatable({lookAt = function(position, target, up)
    local forward = target - position
    if forward.Magnitude < 1e-7 then return CF.new(position) end
    forward = forward.Unit; up = up or V.yAxis
    local right = forward:Cross(up)
    if right.Magnitude < 1e-7 then right = forward:Cross(V.zAxis) end
    right = right.Unit
    return CF.fromMatrix(position, right, right:Cross(forward).Unit, -forward)
end}, {__index = CF})
local checks = 0
local function check(ok, msg) checks += 1; assert(ok, msg) end
local function signal()
    local s = {Entries = {}}
    function s:Connect(fn)
        local e = {fn = fn, active = true}; table.insert(self.Entries, e)
        return {Disconnect = function() e.active = false end}
    end
    function s:Fire(...)
        for _, e in ipairs(self.Entries) do if e.active then e.fn(...) end end
    end
    function s:Count()
        local n = 0
        for _, e in ipairs(self.Entries) do if e.active then n += 1 end end
        return n
    end
    return s
end
local function node(class, name, parent)
    local n = {ClassName = class, Name = name or class, Parent = parent, Children = {}, Attrs = {}}
    if parent then table.insert(parent.Children, n) end
    function n:FindFirstChild(name)
        for _, c in ipairs(self.Children) do if c.Name == name and c.Parent == self then return c end end
    end
    function n:FindFirstChildOfClass(class)
        for _, c in ipairs(self.Children) do if c.ClassName == class and c.Parent == self then return c end end
    end
    function n:GetAttribute(key) return self.Attrs[key] end
    return n
end
local world = {CurrentCamera = {CFrame = CF.new(), CameraType = "Custom"}}
local run = {Bindings = {}}
function run:BindToRenderStep(name, priority, fn) self.Bindings[name] = {priority = priority, fn = fn} end
function run:UnbindFromRenderStep(name) self.Bindings[name] = nil end
function run:Step(dt)
    local bindings = {}
    for _, b in pairs(self.Bindings) do table.insert(bindings, b) end
    table.sort(bindings, function(a, b) return a.priority < b.priority end)
    for _, b in ipairs(bindings) do b.fn(dt) end
end
local input = {MouseEnabled = true, MouseBehavior = "Default"}
function input:GetFocusedTextBox() return self.Focused end
local guiService = {MenuIsOpen = false}
local services = {RunService = run, UserInputService = input, GuiService = guiService}
local enum = {
    RenderPriority = {Camera = {Value = 200}},
    MouseBehavior = {LockCenter = "LockCenter"},
    CameraType = {Scriptable = "Scriptable"},
    HumanoidStateType = {Swimming = "Swimming", PlatformStanding = "PlatformStanding"},
}
local cameraClass = luau.load(fs.readFile("src/client/WeaponCamera.luau"), {
    environment = {game = {GetService = function(_, name) return services[name] end},
        workspace = world, Enum = enum, Vector3 = V, CFrame = frames},
})()
local player = node("Player"); player.CharacterAdded = signal(); player.CharacterRemoving = signal()
local playerGui = node("PlayerGui", nil, player)
local quiet = node("ScreenGui", "QuietCoveUI", playerGui); quiet.Enabled = true
local inventory = node("Frame", "InventoryAndShop", quiet); inventory.Visible = false
local function character()
    local c = node("Model", "Character", {Children = {}})
    local h = node("Humanoid", nil, c)
    h.Health = 100; h.AutoRotate = true; h.State = "Running"; h.Died = signal()
    function h:GetState() return self.State end
    local r = node("Part", "HumanoidRootPart", c)
    r.CFrame = CF.new(3, 7, 9); r.Position = V.new(3, 7, 9)
    return c, h, r
end
local c, h, r = character(); player.Character = c
local tool = node("Tool", "Musket", c); tool.Attrs.WeaponType = "Musket"
local uiAllows = true; local pitchRecords = {}
local control = cameraClass.new(player, function() return uiAllows end, function(char, pitch)
    table.insert(pitchRecords, {char, pitch})
end)
control:SetTool(tool)
check(control:IsAiming(), "Musket immediately starts normal-camera aiming")
check(input.MouseBehavior == "LockCenter" and h.AutoRotate == false, "Captures mouse and normal humanoid rotation")
check(world.CurrentCamera.CameraType == "Custom", "Does not replace default camera")
world.CurrentCamera.CFrame = frames.lookAt(V.zero, V.new(1, .5, 0))
for _ = 1, 15 do run:Step(1 / 60) end
check(r.CFrame.LookVector:Dot(V.xAxis) > .999, "Character smoothly faces current camera yaw")
check((r.CFrame.Position - V.new(3, 7, 9)).Magnitude < 1e-5, "Facing update never changes root position")
check(math.abs(pitchRecords[#pitchRecords][2] - math.asin(world.CurrentCamera.CFrame.LookVector.Y)) < 1e-6,
    "Aim pitch supplied for musket pose")
for _, yaw in ipairs({.7, -.7, math.pi - .7, -math.pi + .7}) do
    for _, pitch in ipairs({.35, -.35}) do
        local direction = V.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch))
        world.CurrentCamera.CFrame = frames.lookAt(V.zero, direction)
        check(world.CurrentCamera.CFrame.LookVector:Dot(direction) > .99999, "Camera basis matches requested arbitrary yaw/pitch")
        for _ = 1, 20 do run:Step(1 / 60) end
        local actualLook = world.CurrentCamera.CFrame.LookVector
        local horizontal = V.new(actualLook.X, 0, actualLook.Z).Unit
        check(r.CFrame.LookVector:Dot(horizontal) > .9999, "Root faces actual camera yaw for both Z hemispheres")
        check(math.abs(r.CFrame.LookVector.Y) < 1e-5, "Camera pitch does not tilt humanoid root")
        check(math.abs(pitchRecords[#pitchRecords][2] - pitch) < 1e-5, "Both positive and negative camera pitch reach weapon pose")
    end
end

local sampledMouse
run:BindToRenderStep("DefaultCameraDouble", 200, function()
    sampledMouse = input.MouseBehavior
    input.MouseBehavior = "Default"
end)
run:Step(1 / 60)
check(sampledMouse == "LockCenter" and input.MouseBehavior == "LockCenter",
    "Locks before mouse sampling and after the default camera changes mouse behavior")
run:UnbindFromRenderStep("DefaultCameraDouble")

local angle = r.CFrame; local pitchCount = #pitchRecords
c.Attrs.LocalDodgeActive = true
world.CurrentCamera.CFrame = frames.lookAt(V.zero, V.new(-1, 0, 0)); run:Step(1 / 60)
check(r.CFrame == angle and #pitchRecords == pitchCount, "Local dodge retains facing and weapon pose")
control:SetTool(nil)
check(input.MouseBehavior == "Default" and h.AutoRotate == false,
    "Unequip releases mouse while dodge keeps movement rotation lock")
check(pitchRecords[#pitchRecords][1] == c and pitchRecords[#pitchRecords][2] == nil, "Release clears weapon aim pitch")
-- Dodge first restores the false value it captured while the musket was held.
h.AutoRotate = false; c.Attrs.LocalDodgeActive = false; run:Step(1 / 60)
check(h.AutoRotate == true, "Original rotation restored after dodge releases its saved false value")
control:SetTool(tool)
c.Attrs.Dodging = true; angle = r.CFrame; run:Step(1 / 60)
check(r.CFrame == angle, "Server dodge flag also suspends facing writes")
c.Attrs.Dodging = false

input.Focused = {}; run:Step(1 / 60)
check(not control:IsAiming() and input.MouseBehavior == "Default" and h.AutoRotate, "Chat releases camera and rotation")
input.Focused = nil; run:Step(1 / 60)
check(control:IsAiming(), "Closing chat restores musket aiming")
inventory.Visible = true; run:Step(1 / 60)
check(not control:IsAiming() and input.MouseBehavior == "Default", "Existing inventory window gets usable cursor")
inventory.Visible = false; run:Step(1 / 60)
for _, name in ipairs({"QuestWindow", "VoyageWindow", "CatchReveal"}) do
    local window = node("Frame", name, quiet); window.Visible = true; run:Step(1 / 60)
    check(not control:IsAiming(), name .. " releases cursor")
    window.Visible = false; run:Step(1 / 60)
end
guiService.MenuIsOpen = true; run:Step(1 / 60)
check(not control:IsAiming(), "Roblox Escape menu releases cursor")
guiService.MenuIsOpen = false; run:Step(1 / 60)
world.CurrentCamera = {CFrame = frames.lookAt(V.zero, V.new(0, 0, 1)), CameraType = "Custom"}
for _ = 1, 15 do run:Step(1 / 60) end
check(world.CurrentCamera.CFrame.LookVector:Dot(V.zAxis) > .99999, "Replacement camera points toward actual positive Z")
local actualLook = world.CurrentCamera.CFrame.LookVector
check(r.CFrame.LookVector:Dot(V.new(actualLook.X, 0, actualLook.Z).Unit) > .999, "Camera replacement is read dynamically")
world.CurrentCamera.CameraType = "Scriptable"; run:Step(1 / 60)
check(not control:IsAiming(), "Scripted catch camera keeps control")
world.CurrentCamera.CameraType = "Custom"; run:Step(1 / 60)
h.AutoRotate = false -- Other movement systems can own rotation before equipping.
control:SetTool(nil); h.AutoRotate = false; input.MouseBehavior = "LockCurrentPosition"
control:SetTool(tool); control:SetTool(nil)
check(h.AutoRotate == false and input.MouseBehavior == "LockCurrentPosition", "Restores exact nondefault pre-equipped settings")
h.AutoRotate = true; input.MouseBehavior = "Default"; control:SetTool(tool)
for _, state in ipairs({"Swimming", "PlatformStanding"}) do
    h.State = state; run:Step(1 / 60)
    check(not control:IsAiming(), state .. " keeps the standard character controller")
    h.State = "Running"; run:Step(1 / 60)
end
h.Sit = true; run:Step(1 / 60)
check(not control:IsAiming(), "Seated character keeps vehicle controls")
h.Sit = false; run:Step(1 / 60)
c.Attrs.CombatUIBlocked = true; run:Step(1 / 60)
check(not control:IsAiming(), "Published combat UI flag blocks camera")
c.Attrs.CombatUIBlocked = false; run:Step(1 / 60)
h.Health = 0; h.Died:Fire()
check(not control:IsAiming() and input.MouseBehavior == "Default" and h.AutoRotate, "Death immediately releases mouse and rotation")
local oldh = h
player.CharacterRemoving:Fire(c)
c, h, r = character(); player.Character = c; player.CharacterAdded:Fire(c); run:Step(1 / 60)
check(not control:IsAiming() and oldh.Died:Count() == 0, "Respawn clears old tool and death listener")
tool = node("Tool", "Musket", c); tool.Attrs.WeaponType = "Musket"; control:SetTool(tool)
input.MouseEnabled = false; run:Step(1 / 60)
check(not control:IsAiming(), "Touch-only clients keep normal camera controls")
input.MouseEnabled = true; uiAllows = false; run:Step(1 / 60)
check(not control:IsAiming(), "Game modal predicate prevents aiming")
uiAllows = true; run:Step(1 / 60)
check(control:IsAiming(), "Resumes when permitted")
control:Destroy(); control:Destroy()
check(next(run.Bindings) == nil, "Both ordered render callbacks unbound")
check(player.CharacterAdded:Count() == 0 and player.CharacterRemoving:Count() == 0 and h.Died:Count() == 0,
    "All lifecycle/death listeners disconnected")
check(h.AutoRotate and input.MouseBehavior == "Default", "Destroy restores settings")
print("WeaponCamera checks:", checks)
