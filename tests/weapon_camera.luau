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
local function cameraFrame(direction, distance)
    -- Camera.Focus stays at the subject; normal third-person distance is 12.
    return frames.lookAt(-direction.Unit * (distance or 12), V.zero)
end
local baseOffset = V.new(.35, .18, -.2)
local shoulder = V.new(2.2, .5, 0)
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
local world = {CurrentCamera = {CFrame = cameraFrame(V.new(0, 0, -1)), Focus = CF.new(),
    CameraType = "Custom", FieldOfView = 74, CameraSubject = "OriginalHumanoid"}}
local run = {Bindings = {}}
function run:BindToRenderStep(name, priority, fn) self.Bindings[name] = {priority = priority, fn = fn} end
function run:UnbindFromRenderStep(name) self.Bindings[name] = nil end
function run:Step(dt)
    local bindings = {}
    for _, b in pairs(self.Bindings) do table.insert(bindings, b) end
    table.sort(bindings, function(a, b) return a.priority < b.priority end)
    for _, b in ipairs(bindings) do b.fn(dt) end
end
local input = {MouseEnabled = true, MouseBehavior = "Default", MouseIconEnabled = true}
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
player.CameraMinZoomDistance = .5; player.CameraMaxZoomDistance = 128
local playerGui = node("PlayerGui", nil, player)
local quiet = node("ScreenGui", "QuietCoveUI", playerGui); quiet.Enabled = true
local inventory = node("Frame", "InventoryAndShop", quiet); inventory.Visible = false
local function character()
    local c = node("Model", "Character", {Children = {}})
    local h = node("Humanoid", nil, c)
    h.Health = 100; h.AutoRotate = true; h.State = "Running"; h.Died = signal()
    h.CameraOffset = baseOffset
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
check(input.MouseIconEnabled == false, "Musket hides the standard mouse pointer immediately")
check(h.CameraOffset == baseOffset, "Equipping begins from exact previous camera offset")
check(world.CurrentCamera.CameraType == "Custom", "Does not replace default camera")
run:Step(1 / 60)
local firstOffset = h.CameraOffset - baseOffset
check(firstOffset.X > 0 and firstOffset.X < shoulder.X and firstOffset.Y > 0,
    "Right shoulder rises smoothly instead of jumping to its final position")
world.CurrentCamera.CFrame = cameraFrame(V.new(1, .5, 0))
for _ = 1, 15 do run:Step(1 / 60) end
check(r.CFrame.LookVector:Dot(V.xAxis) > .999, "Character smoothly faces current camera yaw")
check((r.CFrame.Position - V.new(3, 7, 9)).Magnitude < 1e-5, "Facing update never changes root position")
check(math.abs(pitchRecords[#pitchRecords][2] - math.asin(world.CurrentCamera.CFrame.LookVector.Y)) < 1e-6,
    "Aim pitch supplied for musket pose")
check((h.CameraOffset - baseOffset - shoulder).Magnitude < .02, "Third person approaches right-shoulder framing")
check(world.CurrentCamera.FieldOfView == 74 and world.CurrentCamera.CameraSubject == "OriginalHumanoid"
    and player.CameraMinZoomDistance == .5 and player.CameraMaxZoomDistance == 128,
    "Shoulder framing preserves native FOV, subject and zoom settings")
for _, yaw in ipairs({.7, -.7, math.pi - .7, -math.pi + .7}) do
    for _, pitch in ipairs({.35, -.35}) do
        local direction = V.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch))
        world.CurrentCamera.CFrame = cameraFrame(direction)
        check(world.CurrentCamera.CFrame.LookVector:Dot(direction) > .99999, "Camera basis matches requested arbitrary yaw/pitch")
        for _ = 1, 20 do run:Step(1 / 60) end
        local actualLook = world.CurrentCamera.CFrame.LookVector
        local horizontal = V.new(actualLook.X, 0, actualLook.Z).Unit
        check(r.CFrame.LookVector:Dot(horizontal) > .9999, "Root faces actual camera yaw for both Z hemispheres")
        check(math.abs(r.CFrame.LookVector.Y) < 1e-5, "Camera pitch does not tilt humanoid root")
        check(math.abs(pitchRecords[#pitchRecords][2] - pitch) < 1e-5, "Both positive and negative camera pitch reach weapon pose")
    end
end

local sampledMouse, sampledIcon, sampledOffset
run:BindToRenderStep("DefaultCameraDouble", 200, function()
    sampledMouse = input.MouseBehavior
    sampledIcon = input.MouseIconEnabled
    sampledOffset = h.CameraOffset
    input.MouseBehavior = "Default"
    input.MouseIconEnabled = true
end)
run:Step(1 / 60)
check(sampledMouse == "LockCenter" and input.MouseBehavior == "LockCenter",
    "Locks before mouse sampling and after the default camera changes mouse behavior")
check(sampledIcon == false and input.MouseIconEnabled == false, "Hides mouse icon before and after the default camera")
check((sampledOffset - baseOffset - shoulder).Magnitude < .001, "Default camera receives the shoulder offset before updating occlusion")
run:UnbindFromRenderStep("DefaultCameraDouble")

local angle = r.CFrame; local pitchCount = #pitchRecords
c.Attrs.LocalDodgeActive = true
world.CurrentCamera.CFrame = cameraFrame(V.new(-1, 0, 0)); run:Step(1 / 60)
check(r.CFrame == angle and #pitchRecords == pitchCount, "Local dodge retains facing and weapon pose")
check(input.MouseIconEnabled == false, "Sidestep keeps musket cursor hidden")
local equippedOffset = h.CameraOffset
control:SetTool(nil)
check(input.MouseBehavior == "Default" and h.AutoRotate == false,
    "Unequip releases mouse while dodge keeps movement rotation lock")
check(pitchRecords[#pitchRecords][1] == c and pitchRecords[#pitchRecords][2] == nil, "Release clears weapon aim pitch")
check(input.MouseIconEnabled == true, "Unequip restores prior mouse-icon visibility immediately")
-- Dodge first restores the false value it captured while the musket was held.
h.AutoRotate = false; c.Attrs.LocalDodgeActive = false; run:Step(1 / 60)
check(h.AutoRotate == true, "Original rotation restored after dodge releases its saved false value")
check(h.CameraOffset.X < equippedOffset.X and h.CameraOffset.X > baseOffset.X, "Unequip eases shoulder framing back toward baseline")
control:SetTool(tool)
for _ = 1, 45 do run:Step(1 / 60) end
check((h.CameraOffset - baseOffset - shoulder).Magnitude < .0001, "Rapid re-equip reuses original baseline without offset drift")
c.Attrs.Dodging = true; angle = r.CFrame; run:Step(1 / 60)
check(r.CFrame == angle, "Server dodge flag also suspends facing writes")
c.Attrs.Dodging = false

input.Focused = {}; run:Step(1 / 60)
check(not control:IsAiming() and input.MouseBehavior == "Default" and h.AutoRotate, "Chat releases camera and rotation")
check(input.MouseIconEnabled == true, "Chat restores the cursor")
for _ = 1, 45 do run:Step(1 / 60) end
check(h.CameraOffset == baseOffset, "Chat restores the exact custom camera offset after fading out")
input.Focused = nil; run:Step(1 / 60)
check(control:IsAiming(), "Closing chat restores musket aiming")
inventory.Visible = true; run:Step(1 / 60)
check(not control:IsAiming() and input.MouseBehavior == "Default", "Existing inventory window gets usable cursor")
check(input.MouseIconEnabled == true, "Inventory shows the normal cursor")
inventory.Visible = false; run:Step(1 / 60)
for _, name in ipairs({"QuestWindow", "VoyageWindow", "CatchReveal"}) do
    local window = node("Frame", name, quiet); window.Visible = true; run:Step(1 / 60)
    check(not control:IsAiming(), name .. " releases cursor")
    check(input.MouseIconEnabled == true, name .. " restores mouse icon visibility")
    window.Visible = false; run:Step(1 / 60)
end
guiService.MenuIsOpen = true; run:Step(1 / 60)
check(not control:IsAiming(), "Roblox Escape menu releases cursor")
check(input.MouseIconEnabled == true, "Roblox Escape menu restores pointer")
guiService.MenuIsOpen = false; run:Step(1 / 60)
world.CurrentCamera = {CFrame = cameraFrame(V.new(0, 0, 1)), Focus = CF.new(), CameraType = "Custom", FieldOfView = 82}
for _ = 1, 15 do run:Step(1 / 60) end
check(world.CurrentCamera.CFrame.LookVector:Dot(V.zAxis) > .99999, "Replacement camera points toward actual positive Z")
local actualLook = world.CurrentCamera.CFrame.LookVector
check(r.CFrame.LookVector:Dot(V.new(actualLook.X, 0, actualLook.Z).Unit) > .999, "Camera replacement is read dynamically")
check((h.CameraOffset - baseOffset - shoulder).Magnitude < .02 and world.CurrentCamera.FieldOfView == 82,
    "Replacing camera preserves shoulder framing and its own FOV")
world.CurrentCamera.CFrame = cameraFrame(V.zAxis, .5)
for _ = 1, 45 do run:Step(1 / 60) end
check(h.CameraOffset == baseOffset and control:IsAiming() and input.MouseIconEnabled == false,
    "Normal first-person zoom suppresses shoulder displacement while retaining musket aim")
world.CurrentCamera.CFrame = cameraFrame(V.zAxis, 12)
for _ = 1, 45 do run:Step(1 / 60) end
check((h.CameraOffset - baseOffset - shoulder).Magnitude < .0001, "Zooming back out returns to right shoulder")
world.CurrentCamera.CameraType = "Scriptable"; run:Step(1 / 60)
check(not control:IsAiming(), "Scripted catch camera keeps control")
world.CurrentCamera.CameraType = "Custom"; run:Step(1 / 60)
h.AutoRotate = false -- Other movement systems can own rotation before equipping.
control:SetTool(nil); h.AutoRotate = false; input.MouseBehavior = "LockCurrentPosition"
for _ = 1, 45 do run:Step(1 / 60) end
input.MouseIconEnabled = false
control:SetTool(tool); control:SetTool(nil)
check(h.AutoRotate == false and input.MouseBehavior == "LockCurrentPosition", "Restores exact nondefault pre-equipped settings")
check(input.MouseIconEnabled == false, "Preserves a mouse icon already hidden before equipping")
h.AutoRotate = true; input.MouseBehavior = "Default"; input.MouseIconEnabled = true; control:SetTool(tool)
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
check(input.MouseIconEnabled == true and h.CameraOffset == baseOffset, "Death immediately restores cursor and exact camera offset")
local oldh = h
player.CharacterRemoving:Fire(c)
c, h, r = character(); player.Character = c; player.CharacterAdded:Fire(c); run:Step(1 / 60)
check(not control:IsAiming() and oldh.Died:Count() == 0, "Respawn clears old tool and death listener")
check(oldh.CameraOffset == baseOffset and h.CameraOffset == baseOffset, "Respawn carries no offset from the old character")
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
check(input.MouseIconEnabled == true and h.CameraOffset == baseOffset, "Destroy restores exact cursor and offset even during blend-in")
print("WeaponCamera checks:", checks)
