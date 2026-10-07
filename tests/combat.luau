-- lune run tests/combat.luau
-- Exercise real server handlers, client UI/input and procedural animation.
local Environment = require("./helpers/combat_environment")
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local V, CF = roblox.Vector3, roblox.CFrame
local checks = 0
local function check(value, label) checks += 1; assert(value, label) end
local function near(actual, expected, label) check(math.abs(actual - expected) < 1e-4, label .. " (actual " .. tostring(actual) .. ", expected " .. tostring(expected) .. ")") end
local function frameNear(actual, expected, label)
    local a, b = {actual:GetComponents()}, {expected:GetComponents()}
    local error = 0
    for index = 1, #a do error += math.abs(a[index] - b[index]) end
    check(error < 1e-3, label)
end
-- Forward kinematics through actual R6 C0/C1 axes. A Weld encodes its overlay
-- directly in C0; a Motor6D adds Transform between C0 and inverse C1.
local function worldFrame(character, part)
    local root = character.HumanoidRootPart
    if part == root then return root.CFrame end
    for _, joint in ipairs(character:GetDescendants()) do
        if (joint:IsA("Motor6D") or joint:IsA("Weld")) and joint.Part1 == part then
            local transform = joint:IsA("Motor6D") and joint.Transform or CF.new()
            return worldFrame(character, joint.Part0) * joint.C0 * transform * joint.C1:Inverse()
        end
    end
    return part.CFrame
end
local function setup(kind)
    local env = Environment.new()
    local bank = env:Node("Folder", "Weapons", env.Storage)
    env:Weapon("Saber", bank); env:Weapon("Musket", bank)
    local player = env:AddPlayer(1, true)
    local victim, hum = env:Character("Victim")
    env:StartServer()
    -- The shop owns issuance now. Equip a purchased-model fixture explicitly;
    -- isolated CombatServer tests must not depend on its old free weapon grant.
    local tool = bank[kind or "Saber"]:Clone(); tool.Parent = player.Character
    return env, player, victim, hum, tool
end

-- CombatServer owns health/remotes, while the profile-backed shop owns weapons.
-- Loading it for existing or newly joining players must never grant free tools.
do
    local env = Environment.new()
    local bank = env:Node("Folder", "Weapons", env.Storage)
    env:Weapon("Saber", bank); env:Weapon("Musket", bank)
    local player = env:AddPlayer(1, true)
    env:StartServer()
    check(player.Character.Humanoid.Health == 100 and player.Character.Humanoid.MaxHealth == 100, "Existing player starts at 100 health")
    check(not player.Backpack.Saber and not player.Character.Saber, "CombatServer does not grant a free saber")
    check(not player.Backpack.Musket and not player.Character.Musket, "CombatServer does not grant a free musket")
    local newcomer = env:AddPlayer(2); env:Flush()
    check(not newcomer.Backpack.Saber and not newcomer.Backpack.Musket, "Joining player receives no weapons outside the shop")
    local char, hum = env:Character("Respawn")
    hum.MaxHealth = 250; hum.Health = 5
    newcomer.Character = char; newcomer.CharacterAdded:Fire(char)
    check(hum.MaxHealth == 100 and hum.Health == 100, "New player's respawn gets configured health")
    check(env.Combat.Swing:IsA("RemoteEvent") and env.Combat.Shot:IsA("RemoteEvent") and env.Combat.ConfirmHit:IsA("RemoteEvent"), "Server creates required remotes")
end

-- One humanoid may contribute several body parts to an overlap; damage must
-- happen once, and the attacker's own body can never take its own damage.
for combo = 1, 3 do
    local env, player, victim, hum = setup()
    env.BoxParts = {victim.HumanoidRootPart, victim.Torso, player.Character.Torso}
    env.Combat.Swing.OnServerEvent:Fire(player, combo)
    check(#hum.DamageCalls == 1, "Overlap deduplicates humanoid for combo " .. combo)
    check(hum.DamageCalls[1] == (combo == 3 and 26 or 18), "Server applies configured combo damage")
    check(#player.Character.Humanoid.DamageCalls == 0, "Own character is never damaged")
    check(env.Queries[1].Params.FilterDescendantsInstances[1] == player.Character, "Overlap query excludes attacker")
    check(env.Queries[1].Params.FilterType == env.Enum.RaycastFilterType.Exclude, "Overlap exclusion filter is used")
    local size = env.Queries[1].Size
    check(combo ~= 3 or size.X > 4.4 and size.Z > 5.4, "Third slash has a larger hitbox")
    check(env.Messages[#env.Messages].Args[1] == true, "Successful server hit is confirmed")
    check(victim:GetAttribute("IFrame"), "Successful hit sets server immunity")
    env:Advance(.27); check(victim:GetAttribute("IFrame"), "Hit immunity survives for 0.27 seconds")
    env:Advance(.02); check(not victim:GetAttribute("IFrame"), "Hit immunity expires after 0.28 seconds")
end

do
    local env, player, victim, hum, tool = setup()
    env.BoxParts = {victim.Torso}; victim:SetAttribute("IFrame", true)
    env.Combat.Swing.OnServerEvent:Fire(player, 1)
    check(#hum.DamageCalls == 0 and env.Messages[#env.Messages].Args[1] == false, "Existing dodge immunity prevents saber damage")
    victim:SetAttribute("IFrame", false)
    env.Combat.Swing.OnServerEvent:Fire(player, 1)
    check(#env.Queries == 1, "Immediate repeated slash is server limited")
    env:Advance(.43); env.Combat.Swing.OnServerEvent:Fire(player, 2)
    check(#hum.DamageCalls == 1, "Slash is allowed after cooldown")
    env:Advance(.43); tool.Parent = player.Backpack
    local before = #env.Queries; env.Combat.Swing.OnServerEvent:Fire(player, 1)
    check(#env.Queries == before, "Unequipped saber cannot attack")
    env:Weapon("Musket", player.Character); env.Combat.Swing.OnServerEvent:Fire(player, 1)
    check(#env.Queries == before, "Wrong weapon cannot use saber remote")
end

-- The client sends no hit target. Actual server raycasting chooses the victim,
-- caps travel length and corrects an out-of-bounds ray origin.
do
    local env, player, victim, hum = setup("Musket")
    env.RayResult = {Instance = victim.Torso}
    env.Combat.Shot.OnServerEvent:Fire(player, V.new(0, 1, 0), V.new(10, 0, 0))
    check(#hum.DamageCalls == 1 and hum.DamageCalls[1] == 28, "Server raycast musket deals 28")
    near(env.Rays[1].Direction.Magnitude, 140, "Musket ray range is normalized to 140")
    check(env.Rays[1].Params.FilterDescendantsInstances[1] == player.Character, "Shot excludes own character")
    check(env.Messages[#env.Messages].Args[1] == true, "Server confirms musket hit")
    env.Combat.Shot.OnServerEvent:Fire(player, V.zero, V.xAxis)
    check(#env.Rays == 1, "Immediate repeated shot is server limited")
    env:Advance(1.8); env.Combat.Shot.OnServerEvent:Fire(player, V.new(1000, 0, 0), V.xAxis)
    check(env.Rays[2].Origin == player.Character.HumanoidRootPart.Position + V.new(0, 1.4, 0), "Origin beyond eight studs is corrected by server")
    env:Advance(1.8); env.RayResult = nil
    env.Combat.Shot.OnServerEvent:Fire(player, V.zero, V.xAxis)
    check(env.Messages[#env.Messages].Args[1] == false, "A missed ray confirms no hit")
    env:Advance(1.8); local before = #env.Rays
    env.Combat.Shot.OnServerEvent:Fire(player, "spoofed", V.xAxis)
    env.Combat.Shot.OnServerEvent:Fire(player, V.zero, "spoofed")
    env.Combat.Shot.OnServerEvent:Fire(player, V.zero, V.zero)
    check(#env.Rays == before, "Malformed vector values and zero directions are rejected")
end
do
    local env, player, victim, hum = setup("Musket")
    env.RayResult = {Instance = victim.Torso}; victim:SetAttribute("IFrame", true)
    env.Combat.Shot.OnServerEvent:Fire(player, V.zero, V.xAxis)
    check(#hum.DamageCalls == 0 and env.Messages[#env.Messages].Args[1] == false, "Dodge immunity prevents musket damage")
    env:Advance(1.8); victim:SetAttribute("IFrame", false); hum.Health = 0
    env.Combat.Shot.OnServerEvent:Fire(player, V.zero, V.xAxis)
    check(#hum.DamageCalls == 0, "Dead targets do not receive further damage")
end

-- WeaponPlaceholders now bootstraps WeaponModels rather than constructing
-- plain tools. Compile its real source here; native tests/weapon_models cover
-- model geometry, shared construction and migration of old fallback tools.
luau.load(fs.readFile("src/combat/WeaponPlaceholders.server.luau"))

-- Real R6 joints use rotated C0 axes and a Weld RightGrip. Guard remains active
-- while equipped; the action callback owns its complete recovery and hitstop.
for combo = 1, 3 do
    local env = Environment.new()
    local char, hum, root = env:Character()
    local tool = env:Weapon("Saber", char)
    local grip = char:FindFirstChild("RightGrip", true)
    local original = CF.new(.1, .2, .3); grip.C0 = original
    local originalGrip = tool.Grip
    local originalC1 = grip.C1
    local shoulder = char:FindFirstChild("Right Shoulder", true)
    local hip = char:FindFirstChild("Right Hip", true)
    local baseShoulder, baseHip = shoulder.Transform, hip.Transform
    local animator = env:Execute("src/combat/WeaponAnimator.luau")
    animator.setWeapon(char, tool)
    local calls, finishes, completed = 0, 0, nil
    local name = animator.playSaber(char, combo, function(reply) calls += 1; reply(true) end,
        function(success) finishes += 1; completed = success end)
    check(type(name) == "string" and #name > 0, "Animator identifies each saber pose")
    env:Advance(.1); check(calls == 0, "Saber hit callback waits through windup")
    check(shoulder.Transform ~= baseShoulder, "Actual shoulder joint receives the saber arc")
    env:Advance(.16); check(calls == 1, "Saber activation callback fires once at active phase")
    local held = shoulder.Transform
    env:Advance(.035); frameNear(shoulder.Transform, held, "Hitstop freezes the action pose briefly")
    env:Advance(.32)
    check(finishes == 0 and animator.IsBusy(char), "Recovery remains busy beyond the old 0.5 second timer")
    env:Advance(.2)
    check(calls == 1 and finishes == 1 and completed == true and not animator.IsBusy(char), "Complete recovery reports success once")
    check(env.Run.PreSimulation:Count() == 1 and env.Run.PreAnimation:Count() == 1, "Equipped guard retains its two overlay phases")
    check(tool.Grip == originalGrip and grip.C1 == originalC1, "Saber does not rewrite Tool Grip or joint C1")
    check(hip.Transform == baseHip and hum.WalkSpeed == 16 and hum.AutoRotate and root.CFrame == CF.new(), "Weapon animation leaves legs and locomotion unchanged")
    animator.stop(char)
    check(env.Run.PreSimulation:Count() == 0 and env.Run.PreAnimation:Count() == 0, "Stop disconnects both animation phases")
    check(grip.C0 == original and shoulder.Transform == baseShoulder, "Stop restores Weld grip and arm pose")
    local cancelled = nil
    animator.setWeapon(char, tool); animator.playSaber(char, 1, nil, function(success) cancelled = success end)
    tool.Parent = env.Storage
    check(cancelled == false and env.Run.PreSimulation:Count() == 0, "Unequip cancels action and releases overlay immediately")
end

-- The previous torso overlay is removed before the ordinary Animator writes its
-- next walking pose. Overlay twist is frame-rate independent and never grows.
do
    local samples = {}
    for _, fps in ipairs({30, 120}) do
        local env = Environment.new(); local char = env:Character()
        local saber = env:Weapon("Saber", char)
        local torso = char:FindFirstChild("RootJoint", true)
        local hip = char:FindFirstChild("Right Hip", true)
        local walkTorso, walkHip = CF.Angles(.03, .07, -.02), CF.Angles(.2, 0, 0)
        env.DefaultAnimation = function()
            torso.Transform = walkTorso; hip.Transform = walkHip
        end
        local animator = env:Execute("src/combat/WeaponAnimator.luau")
        animator.setWeapon(char, saber); env:Advance(.4, 1 / fps)
        table.insert(samples, torso.Transform)
        frameNear(hip.Transform, walkHip, "Ordinary walk continues to own leg joints")
        env.Run.PreAnimation:Fire()
        frameNear(torso.Transform, walkTorso, "PreAnimation removes only the previous torso overlay")
        animator.stop(char); env:Advance(.05, 1 / fps)
        frameNear(torso.Transform, walkTorso, "After unequip normal walking owns the entire pose")
    end
    frameNear(samples[1], samples[2], "Guard torso twist is identical at 30 and 120 FPS")
end
do
    local env = Environment.new(); local char, hum = env:Character()
    local saber = env:Weapon("Saber", char)
    local animator = env:Execute("src/combat/WeaponAnimator.luau")
    animator.setWeapon(char, saber); env:Advance(.2)
    char:SetAttribute("LocalDodgeActive", true); env:Advance(.02)
    frameNear(char:FindFirstChild("Right Shoulder", true).Transform, CF.new(), "Local dodge suspends weapon arm overlay")
    local outcome
    local name = animator.playSaber(char, 1, nil, function(done) outcome = done end)
    check(name == nil and outcome == false, "A dodge blocks a new saber action")
    char:SetAttribute("LocalDodgeActive", false)
    animator.playSaber(char, 1, nil, function(done) outcome = done end)
    char:SetAttribute("CombatUIBlocked", true); env:Advance(.02)
    check(outcome == false and not animator.IsBusy(char), "Opening UI cancels the current animation")
    char:SetAttribute("CombatUIBlocked", false); env:Advance(.2)
    hum.Health = 0; hum.Died:Fire()
    check(env.Run.PreSimulation:Count() == 0 and env.Run.PreAnimation:Count() == 0, "Death releases the equipped animation state")
end
do
    local env = Environment.new(); local char = env:Character()
    local saber = env:Weapon("Saber", char)
    local animator = env:Execute("src/combat/WeaponAnimator.luau")
    animator.setWeapon(char, saber); env:Advance(.25)
    local blade = worldFrame(char, saber.Handle)
    check(blade.UpVector:Dot(V.yAxis) > .5, "Actual R6 guard keeps saber blade raised above the hand")
    check(blade.UpVector:Dot(char.HumanoidRootPart.CFrame.LookVector) > .3, "Actual R6 guard points saber blade forward")
    local startTip = blade:PointToWorldSpace(V.new(0, 3.9, 0))
    animator.playSaber(char, 1)
    local sweep = 0
    for _ = 1, 35 do
        env:Advance(.02)
        local tip = worldFrame(char, saber.Handle):PointToWorldSpace(V.new(0, 3.9, 0))
        sweep = math.max(sweep, (tip - startTip).Magnitude)
    end
    check(sweep > .6, "Saber tip crosses a visible spatial arc through real R6 joints")
    animator.stop(char); saber.Parent = env.Storage
    local musket = env:Weapon("Musket", char)
    animator.setWeapon(char, musket); env:Advance(.25)
    local barrel = worldFrame(char, musket.Handle).UpVector
    near(barrel:Dot(char.HumanoidRootPart.CFrame.LookVector), 1, "Musket barrel follows horizontal root aim through the whole R6 joint chain")
    animator.setAimPitch(char, math.rad(25)); env:Advance(.05)
    barrel = worldFrame(char, musket.Handle).UpVector
    near(barrel.Y, math.sin(math.rad(25)), "Musket barrel follows vertical camera pitch through the real grip")
    local desired = char.HumanoidRootPart.CFrame.LookVector * math.cos(math.rad(25)) + V.yAxis * math.sin(math.rad(25))
    near(barrel:Dot(desired), 1, "Full barrel aim matches horizontal direction plus pitch")
    animator.stop(char)
end

-- Musket integrates into the standard camera: cursor lock, horizontal facing,
-- bounded aim pitch, and rotation ownership yield during dodge/UI/unequip.
do
    local env = Environment.new(); local player = env:AddPlayer(1, true)
    local char, hum, root = player.Character, player.Character.Humanoid, player.Character.HumanoidRootPart
    root.Position = V.new(3, 4, -2)
    local originalPosition = root.Position
    local musket = env:Weapon("Musket", char)
    local aim = {}
    local cameraModule = env:Execute("src/client/WeaponCamera.luau")
    local controller = cameraModule.new(player, function() return true end, function(c, pitch) table.insert(aim, {c, pitch}) end)
    env.World.CurrentCamera.CFrame = CF.Angles(.2, .7, 0)
    controller:SetTool(musket); env:Advance(.4)
    check(controller:IsAiming() and env.UIS.MouseBehavior == env.Enum.MouseBehavior.LockCenter, "Musket locks cursor through standard render steps")
    check(not hum.AutoRotate and hum.WalkSpeed == 16, "Musket owns facing while preserving normal movement")
    near((root.Position - originalPosition).Magnitude, 0, "Camera integration preserves root position")
    check(env.World.CurrentCamera.CameraType == env.Enum.CameraType.Custom, "Camera integration keeps the standard CameraType")
    local look = env.World.CurrentCamera.CFrame.LookVector
    local expected = V.new(look.X, 0, look.Z).Unit
    near(root.CFrame.LookVector:Dot(expected), 1, "Player turns to camera's horizontal aim: " .. tostring(root.CFrame.LookVector) .. " vs " .. tostring(expected))
    near(aim[#aim][2], math.asin(look.Y), "Camera passes current vertical aim pitch")
    char:SetAttribute("Dodging", true)
    local facing = root.CFrame
    env.World.CurrentCamera.CFrame = CF.Angles(0, -1, 0); env:Advance(.1)
    frameNear(root.CFrame, facing, "Dodge retains its fixed facing despite camera motion")
    controller:SetTool(nil)
    check(not controller:IsAiming() and not hum.AutoRotate, "Unequip defers rotation restore while dodge owns its lock")
    char:SetAttribute("Dodging", false); env:Advance(.02)
    check(hum.AutoRotate and env.UIS.MouseBehavior == env.Enum.MouseBehavior.Default, "Rotation and cursor return when dodge releases")
    controller:SetTool(musket); env:Advance(.03)
    env.Gui.MenuIsOpen = true; env:Advance(.02)
    check(not controller:IsAiming() and hum.AutoRotate, "Escape menu releases aiming controls")
    env.Gui.MenuIsOpen = false; env:Advance(.03)
    env.FocusedTextBox = {}; env:Advance(.02)
    check(not controller:IsAiming(), "Typing releases musket cursor lock")
    env.FocusedTextBox = nil
    local quiet = env:Node("ScreenGui", "QuietCoveUI", player.PlayerGui)
    local window = env:Node("Frame", "InventoryAndShop", quiet); window.Visible = true
    env:Advance(.02); check(not controller:IsAiming(), "Existing game menu blocks aiming")
    window.Visible = false
    local replacement = env:Node("Camera"); replacement.CameraType = env.Enum.CameraType.Custom
    replacement.CFrame = CF.Angles(.1, -.4, 0); replacement.FieldOfView = 83
    env.World.CurrentCamera = replacement; env:Advance(.3)
    check(controller:IsAiming() and replacement.FieldOfView == 83, "Aiming follows a replaced CurrentCamera without resetting its FOV")
    replacement.CameraType = env.Enum.CameraType.Scriptable; env:Advance(.02)
    check(not controller:IsAiming(), "Scripted scenes keep camera ownership")
    controller:Destroy()
    check(next(env.Run.Bindings) == nil and player.CharacterAdded:Count() == 0 and player.CharacterRemoving:Count() == 0, "Camera teardown removes render bindings and lifecycle listeners")
    check(hum.AutoRotate and env.UIS.MouseBehavior == env.Enum.MouseBehavior.Default, "Camera teardown restores captured settings")
end

-- Client health is read-only: it changes UI, not Humanoid damage. Red responds
-- at once; the delayed yellow tween begins at the specified 0.45 second mark.
do
    local env = Environment.new(); local player = env:AddPlayer(1, true)
    env:StartClient(); env:Advance(.5)
    local gui = player.PlayerGui.HealthBar
    check(gui and gui.ResetOnSpawn, "Client mounts health bar")
    local frame = gui:FindFirstChildOfClass("Frame")
    local label = frame:FindFirstChildOfClass("TextLabel")
    local fill, ghost
    for _, child in ipairs(frame:GetChildren()) do
        if child:IsA("Frame") then
            if child.ZIndex == 2 then fill = child else ghost = child end
        end
    end
    local hum = player.Character.Humanoid
    hum.Health = 63.2; hum.HealthChanged:Fire(hum.Health)
    check(label.Text == "64 / 100", "Health label follows current and maximum health")
    near(fill.Size.X.Scale, .632, "Red bar target follows damage immediately")
    near(ghost.Size.X.Scale, 1, "Yellow health initially remains behind")
    env:Advance(.44); near(ghost.Size.X.Scale, 1, "Yellow bar waits for delay")
    env:Advance(.02); near(ghost.Size.X.Scale, .632, "Yellow bar updates after 0.45 seconds")
    check(#hum.DamageCalls == 0, "Client UI never applies damage")
end

-- Input exercises the actual local entrypoint, persistent animator and camera.
-- The hit callback sends requests; onFinish owns busy across the full recovery.
do
    local env = Environment.new(); local player = env:AddPlayer(1, true)
    local saber = env:Weapon("Saber", player.Character); env:StartClient()
    env:Click(true); env:Advance(.3); check(#env.Requests == 0, "Processed UI/chat click is ignored")
    env:Click(); check(#env.Requests == 0, "Saber request waits for animation windup")
    local trail = saber.Blade.SwingTrail
    check(trail and not trail.Enabled and trail.Attachment0 and trail.Attachment1, "Saber trail waits until the active cut")
    env:Click(); env:Advance(.26)
    check(#env.Requests == 1 and env.Requests[1].Remote == "Swing" and env.Requests[1].Args[1] == 1, "First swing requests combo one exactly once")
    check(trail.Enabled and player.Character:GetAttribute("CombatAttacking"), "Active slash exposes its short trail and movement gate")
    env.Combat.ConfirmHit.OnClientEvent:Fire(true)
    env:Advance(.27); env:Click()
    check(#env.Requests == 1 and player.Character:GetAttribute("CombatAttacking"), "No new slash starts at the old early 0.5 second release")
    check(not trail.Enabled, "Blade trail disables after its short active interval")
    env:Advance(.23)
    check(not player.Character:GetAttribute("CombatAttacking"), "Finish callback releases action after recovery and hitstop")
    env:Click(); env:Advance(.26); check(env.Requests[2].Args[1] == 2, "Next quick slash requests combo two")
    env:Advance(.43); env:Click(); env:Advance(.26); check(env.Requests[3].Args[1] == 3, "Next quick slash requests combo three")
    env:Advance(1); env:Click(); env:Advance(.26); check(env.Requests[4].Args[1] == 1, "Combo restarts after a pause")
    check(#player.Character.Humanoid.DamageCalls == 0, "Saber client never applies damage")
    env:Advance(.43); saber.Parent = player.Backpack
    local musket = env:Weapon("Musket", player.Character)
    env:Click(); local shots = #env.Requests
    check(env.Requests[shots].Remote == "Shot", "Musket sends a shot request")
    check(env.Requests[shots].Args[1] == musket:FindFirstChild("Muzzle", true).WorldPosition, "Musket fires from its muzzle")
    check(env.Requests[shots].Args[2] == env.World.CurrentCamera.CFrame.LookVector, "Musket requests camera aim direction")
    env:Advance(.4); env:Click(); check(#env.Requests == shots, "Empty magazine prevents fire during reload")
    env:Advance(1.2); env:Click(); check(#env.Requests == shots, "Reload still blocks fire at 1.6 seconds")
    env:Advance(.11); env:Click(); check(#env.Requests == shots + 1, "Musket fires again after 1.7 seconds")
    local emissions = 0
    for _, object in ipairs(env.Objects) do if object:IsA("ParticleEmitter") then emissions += object.Emitted or 0 end end
    check(emissions >= 36, "Both musket shots emit smoke")
    check(#player.Character.Humanoid.DamageCalls == 0, "Musket client never applies damage")
end

do
    local env = Environment.new(); local player = env:AddPlayer(1, true)
    local saber = env:Weapon("Saber", player.Character); env:StartClient()
    local c = player.Character
    for _, attribute in ipairs({"Dodging", "LocalDodgeActive", "CombatUIBlocked", "Stunned"}) do
        c:SetAttribute(attribute, true); env:Click(); env:Advance(.3)
        check(#env.Requests == 0 and not c:GetAttribute("CombatAttacking"), attribute .. " blocks new combat input")
        c:SetAttribute(attribute, false)
    end
    env.Gui.MenuIsOpen = true; env:Click(); env:Advance(.3)
    check(#env.Requests == 0, "Escape menu blocks attack input")
    env.Gui.MenuIsOpen = false; env.FocusedTextBox = {}; env:Click(); env:Advance(.3)
    check(#env.Requests == 0, "Focused text field blocks attack input")
    env.FocusedTextBox = nil; env:Click(); env:Advance(.1)
    saber.Parent = player.Backpack; env:Advance(.3)
    check(#env.Requests == 0 and not c:GetAttribute("CombatAttacking"), "Unequip during windup never sends a late swing")
    check(env.Run.PreAnimation:Count() == 0 and env.Run.PreSimulation:Count() == 0, "Empty hands release weapon overlay")
    frameNear(c:FindFirstChild("Right Shoulder", true).Transform, CF.new(), "Unequip restores a normal arm for walking")
end
do
    local env = Environment.new(); local player = env:AddPlayer(1, true)
    env:Weapon("Saber", player.Character); env:StartClient()
    local c = player.Character
    c:SetAttribute("LocalDodgePendingUntil", env.Time + .8)
    env:Click(); check(not c:GetAttribute("CombatAttacking"), "Pending server dodge request blocks combat before approval")
    env:Advance(.81); env:Click()
    check(c:GetAttribute("CombatAttacking"), "An expired pending dodge timeout releases combat")
    env:Advance(.1)
    local tool = c:FindFirstChildOfClass("Tool"); tool.Parent = player.Backpack; tool.Parent = c
    local quiet = env:Node("ScreenGui", "QuietCoveUI", player.PlayerGui)
    for _, name in ipairs({"InventoryAndShop", "QuestWindow", "VoyageWindow", "CatchReveal"}) do
        local window = env:Node("Frame", name, quiet); window.Visible = true
        env:Click()
        check(not c:GetAttribute("CombatAttacking"), name .. " blocks input immediately before the next render update")
        window:Destroy()
    end
    env.ClientScript:Destroy()
end

-- A gun magazine belongs to the character life, not the equipped slot: putting
-- the tool away and taking it back must not skip the 1.7 second reload.
do
    local env = Environment.new(); local player = env:AddPlayer(1, true)
    local musket = env:Weapon("Musket", player.Character)
    local camera = env.World.CurrentCamera; camera.FieldOfView = 82
    local hum = player.Character.Humanoid; hum.CameraOffset = V.new(.2, .1, -.1)
    local offset = hum.CameraOffset
    env:StartClient(); env:Click()
    check(#env.Requests == 1, "First magazine shot is sent")
    env:Advance(.1); musket.Parent = player.Backpack
    check(camera.FieldOfView == 82 and hum.CameraOffset == offset, "Unequip cancels recoil and restores captured FOV and offset")
    check(hum.AutoRotate and env.UIS.MouseBehavior == env.Enum.MouseBehavior.Default, "Unequip restores normal camera and facing settings")
    musket.Parent = player.Character; env:Click(); env:Advance(.6)
    check(#env.Requests == 1, "Switching back cannot reset the empty magazine")
    env:Advance(.9); env:Click()
    check(#env.Requests == 1, "Re-equipped musket remains empty at 1.6 seconds")
    env:Advance(.11); env:Click()
    check(#env.Requests == 2, "The original reload timer completes after 1.7 seconds")
    env:Advance(.4)
    check(camera.FieldOfView == 82 and hum.CameraOffset == offset, "Completed recoil restores custom camera settings")
    env:Click(); env:Advance(.1)
    local nextChar, previous = env:Respawn(player)
    check(not previous:GetAttribute("CombatAttacking") and previous.ChildAdded:Count() == 0 and previous.ChildRemoved:Count() == 0, "Respawn removes old character action and tool listeners")
    check(hum.HealthChanged:Count() == 0, "Respawn destroys old health UI and its health signal")
    local replacement = env:Weapon("Musket", nextChar); env:Click()
    check(#env.Requests == 3, "Respawn begins with a fresh magazine")
    env:Advance(1.3); env:Click()
    check(#env.Requests == 3, "Old life reload callbacks cannot refill the new magazine")
    nextChar.Humanoid.Health = 0; nextChar.Humanoid.Died:Fire()
    check(not nextChar:GetAttribute("CombatAttacking") and env.Run.PreSimulation:Count() == 0, "Death cancels animation and combat state")
    check(nextChar.Humanoid.AutoRotate and env.UIS.MouseBehavior == env.Enum.MouseBehavior.Default, "Death releases aiming controls")
    env:Click(); check(#env.Requests == 3, "Dead local player cannot fire")
    env.ClientScript:Destroy()
    check(next(env.Run.Bindings) == nil and env.Run.PreAnimation:Count() == 0, "Script teardown releases camera bindings and overlays")
    check(env.UIS.InputBegan:Count() == 0 and env.Combat.ConfirmHit.OnClientEvent:Count() == 0, "Script teardown disconnects input and hit-confirm handlers")
    check(player.CharacterAdded:Count() == 0 and player.CharacterRemoving:Count() == 0, "Script teardown disconnects character lifecycle handlers")
    check(nextChar.Humanoid.HealthChanged:Count() == 0 and not player.PlayerGui.HealthBar, "Script teardown removes health UI and its health listener")
    check(replacement.Parent == nextChar, "Cleanup preserves equipped tool ownership")
end

print(string.format("Combat: %d behavior checks passed (engine doubles; visual Studio test still required).", checks))
