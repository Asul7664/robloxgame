-- lune run tests/dodge_pose.luau
-- Real procedural poses on R6/R15 joint fixtures. Horizontal movement/gravity
-- belong to the separate side-dodge controller tests; these verify only visuals.
local Environment = require("./helpers/combat_environment")
local roblox = require("@lune/roblox")
local V, CF = roblox.Vector3, roblox.CFrame
local checks = 0
local function check(value, label) checks += 1; assert(value, label) end
local function near(actual, expected, tolerance, label)
    check(math.abs(actual - expected) <= tolerance, label .. " (actual " .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end
local function frameError(a, b)
    local aa, bb = {a:GetComponents()}, {b:GetComponents()}
    local error = 0
    for index = 1, #aa do error += math.abs(aa[index] - bb[index]) end
    return error
end
local function frameNear(a, b, label) check(frameError(a, b) < .002, label) end
local function jointData(joint)
    if joint:IsA("AnimationConstraint") then
        return joint.Attachment0.Parent, joint.Attachment1.Parent,
            joint.Attachment0.CFrame, joint.Attachment1.CFrame, joint.Transform
    end
    return joint.Part0, joint.Part1, joint.C0, joint.C1,
        joint:IsA("Motor6D") and joint.Transform or CF.new()
end
local function worldFrame(character, part)
    if part == character.HumanoidRootPart then return part.CFrame end
    for _, joint in ipairs(character:GetDescendants()) do
        if joint:IsA("Motor6D") or joint:IsA("Weld") or joint:IsA("AnimationConstraint") then
            local p0, p1, c0, c1, transform = jointData(joint)
            if p1 == part and p0 then return worldFrame(character, p0) * c0 * transform * c1:Inverse() end
        end
    end
    return part.CFrame
end
local function rotation(frame) return CF.new(frame.Position):Inverse() * frame end
local function turn(frame)
    local _, _, _, a, _, _, _, e, _, _, _, i = frame:GetComponents()
    return math.acos(math.clamp((a + e + i - 1) * .5, -1, 1))
end

local function r15(env, constraints)
    local c = env:Node("Model", constraints and "ConstraintAvatar" or "R15Avatar", env.World)
    local h = env:Node("Humanoid", "Humanoid", c); h.HipHeight = 2
    local parts = {}
    for _, name in ipairs({"HumanoidRootPart", "LowerTorso", "UpperTorso", "Head",
        "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand",
        "RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot"}) do
        parts[name] = env:Node("Part", name, c)
    end
    local joints = {}
    local function add(name, p0, p1, c0, c1)
        local joint = env:Node(constraints and "AnimationConstraint" or "Motor6D", name, parts[p0])
        if constraints then
            local a0 = env:Node("Attachment", name .. "A0", parts[p0]); a0.CFrame = c0 or CF.new()
            local a1 = env:Node("Attachment", name .. "A1", parts[p1]); a1.CFrame = c1 or CF.new()
            joint.Attachment0, joint.Attachment1 = a0, a1
            joint.Enabled = true; joint.IsKinematic = name == "Root"
        else
            joint.Part0, joint.Part1 = parts[p0], parts[p1]
            joint.C0, joint.C1 = c0 or CF.new(), c1 or CF.new()
        end
        joints[name] = joint
    end
    add("Root", "HumanoidRootPart", "LowerTorso", CF.new(0, -.15, 0))
    add("Waist", "LowerTorso", "UpperTorso", CF.new(0, .5, 0), CF.new(0, -.5, 0))
    add("Neck", "UpperTorso", "Head", CF.new(0, .75, 0), CF.new(0, -.5, 0))
    for _, side in ipairs({"Right", "Left"}) do
        local sign = side == "Right" and 1 or -1
        add(side .. "Shoulder", "UpperTorso", side .. "UpperArm", CF.new(sign * .8, .4, 0), CF.new(0, .5, 0))
        add(side .. "Elbow", side .. "UpperArm", side .. "LowerArm", CF.new(0, -.5, 0), CF.new(0, .5, 0))
        add(side .. "Wrist", side .. "LowerArm", side .. "Hand", CF.new(0, -.5, 0), CF.new(0, .15, 0))
        add(side .. "Hip", "LowerTorso", side .. "UpperLeg", CF.new(sign * .4, -.65, 0), CF.new(0, .5, 0))
        add(side .. "Knee", side .. "UpperLeg", side .. "LowerLeg", CF.new(0, -.5, 0), CF.new(0, .5, 0))
        add(side .. "Ankle", side .. "LowerLeg", side .. "Foot", CF.new(0, -.5, 0), CF.new(0, .2, 0))
    end
    return c, h, joints
end
local function fixture(kind, constraints)
    local env = Environment.new()
    local char, hum, joints
    if kind == "R15" then char, hum, joints = r15(env, constraints)
    else
        char, hum = env:Character("R6Avatar"); joints = {}
        for _, joint in ipairs(char:GetDescendants()) do
            if joint:IsA("Motor6D") or joint:IsA("Weld") then joints[joint.Name:gsub(" ", "")] = joint end
        end
    end
    local root = char.HumanoidRootPart
    local camera = env.World.CurrentCamera
    local geometry, bases, kinematic = {}, {}, {}
    for _, joint in pairs(joints) do
        local _, _, c0, c1 = jointData(joint)
        geometry[joint] = {c0, c1}
        bases[joint] = joint.Transform
        if joint:IsA("AnimationConstraint") then kinematic[joint] = joint.IsKinematic end
    end
    local animator = env:Execute("src/client/DodgeAnimator.luau").new()
    return {Env = env, Char = char, Hum = hum, Root = root, Camera = camera, Joints = joints,
        Geometry = geometry, Bases = bases, Kinematic = kinematic, Animator = animator}
end
local function checkGeometry(f)
    for joint, base in pairs(f.Geometry) do
        local _, _, c0, c1 = jointData(joint)
        frameNear(c0, base[1], "Dodge leaves joint/attachment C0 anchor unchanged")
        frameNear(c1, base[2], "Dodge leaves joint/attachment C1 anchor unchanged")
    end
end
local function clean(f, label)
    check(not f.Animator:IsPlaying() and not f.Char:GetAttribute("LocalDodgePoseActive"), label .. ": active state cleared")
    check(f.Env.Run.PreAnimation:Count() == 0 and f.Env.Run.PreSimulation:Count() == 0, label .. ": both pose phase listeners disconnected")
    for joint, baseline in pairs(f.Kinematic) do check(joint.IsKinematic == baseline, label .. ": original kinematic setting restored") end
end

-- R6 body weight shifts into the chosen side while the leading/trailing legs
-- differ. The mirror reverses torso lean without changing the real root/camera.
do
    local samples = {}
    for _, side in ipairs({"Left", "Right"}) do
        local f = fixture("R6"); local e, pose = f.Env, f.Animator
        local rootBefore, cameraBefore = f.Root.CFrame, f.Camera.CFrame
        local torsoBefore = worldFrame(f.Char, f.Char.Torso)
        check(pose:Play(f.Char, side, .22, .12), "Live R6 character can start visual " .. side .. " step")
        check(pose:IsPlaying() and f.Char:GetAttribute("LocalDodgePoseActive"), "Play publishes weapon-overlay ownership")
        e:Advance(.11)
        local torso = worldFrame(f.Char, f.Char.Torso)
        local relative = torsoBefore:ToObjectSpace(torso)
        check(relative.Position.Y < -.015, "Mid-step torso visibly dips using its joint rather than moving root")
        check(math.abs(torso.UpVector.X) > .02, "Mid-step torso leans visibly toward its lateral movement")
        local rightAxes, leftAxes = rotation(f.Joints.RightHip.C0), rotation(f.Joints.LeftHip.C0)
        local rightPose = rightAxes * f.Joints.RightHip.Transform * rightAxes:Inverse()
        local leftPose = leftAxes * f.Joints.LeftHip.Transform * leftAxes:Inverse()
        check(frameError(rightPose, leftPose) > .02, "Leading and trailing legs differ in the same torso axes")
        frameNear(f.Root.CFrame, rootBefore, "Pose never translates or rotates HumanoidRootPart")
        frameNear(f.Camera.CFrame, cameraBefore, "Pose never moves the camera")
        check(f.Hum.WalkSpeed == 16 and f.Hum.AutoRotate, "Visual overlay leaves movement locks to the existing physics controller")
        checkGeometry(f)
        samples[side] = {Up = torso.UpVector.X, Dip = relative.Position.Y}
        e:Advance(.12)
        check(pose:IsPlaying(), "Pose stays active for smooth recovery after physics ends")
        e:Advance(.25); clean(f, "R6 natural finish")
        frameNear(worldFrame(f.Char, f.Char.Torso), torsoBefore, "Completed pose returns torso to the ordinary base")
        pose:Destroy()
    end
    check(samples.Left.Up * samples.Right.Up < 0, "Left/right side steps mirror the torso lean")
    near(math.abs(samples.Left.Up), math.abs(samples.Right.Up), .015, "Mirrored body lean has equal strength")
    near(samples.Left.Dip, samples.Right.Dip, .01, "Both sides keep the same short body dip")
end

-- Physical completion can request recovery explicitly (for example at a wall).
-- Repeated Release calls must not restart recovery or snap the current pose.
do
    local f = fixture("R6"); local e, pose = f.Env, f.Animator
    pose:Play(f.Char, "Right", .22, .12); e:Advance(.1)
    local before = worldFrame(f.Char, f.Char.Torso)
    pose:Release()
    frameNear(worldFrame(f.Char, f.Char.Torso), before, "Release starts from the currently visible pose without snapping")
    e:Advance(.06)
    check(pose:IsPlaying() and f.Char:GetAttribute("LocalDodgePoseActive"), "Explicit release keeps visual ownership through its recovery")
    pose:Release(); e:Advance(.09)
    clean(f, "Idempotent explicit release")
    pose:Destroy()
end

-- R15 articulation bends knees, elbows and ankles without stretching anchors.
-- Constraint rigs claim only temporary kinematic ownership and restore it.
for _, constrained in ipairs({false, true}) do
    local f = fixture("R15", constrained); local e, pose = f.Env, f.Animator
    local rootBefore, cameraBefore = f.Root.CFrame, f.Camera.CFrame
    local lowerBefore = worldFrame(f.Char, f.Char.LowerTorso)
    check(pose:Play(f.Char, "Right", .22, .12), "R15 joint topology is accepted")
    e:Advance(.10)
    for _, name in ipairs({"RightKnee", "LeftKnee", "RightElbow", "LeftElbow", "RightAnkle", "LeftAnkle"}) do
        check(turn(rotation(f.Joints[name].Transform)) > math.rad(1), name .. " bends visibly during the body step")
        near(f.Joints[name].Transform.Position.Magnitude, 0, .001, name .. " bends without a joint translation")
    end
    check(worldFrame(f.Char, f.Char.LowerTorso).Position.Y < lowerBefore.Position.Y - .015, "R15 torso dip stays in the joint overlay")
    frameNear(f.Root.CFrame, rootBefore, "R15 root stays under physics control")
    frameNear(f.Camera.CFrame, cameraBefore, "R15 camera stays under its own controller")
    checkGeometry(f)
    if constrained then
        for joint in pairs(f.Kinematic) do check(joint.IsKinematic, "Playing constraint pose enables temporary kinematic joints") end
    end
    e:Advance(.4); clean(f, "R15 natural finish")
    checkGeometry(f)
    pose:Destroy()
end

-- Time-based envelope is independent of rendering speed. Deltas stay small and
-- all three common update rates return to a neutral pose without a final snap.
do
    local samples = {}
    for _, fps in ipairs({30, 60, 120}) do
        local f = fixture("R6"); local e, pose = f.Env, f.Animator
        local before = worldFrame(f.Char, f.Char.Torso)
        pose:Play(f.Char, "Right", .22, .12)
        local previous, largestTurn, largestDip = before, 0, 0
        for _ = 1, math.ceil(.45 * fps) do
            e:Advance(1 / fps, 1 / fps)
            local current = worldFrame(f.Char, f.Char.Torso)
            local delta = previous:ToObjectSpace(current)
            largestTurn = math.max(largestTurn, turn(rotation(delta)))
            largestDip = math.max(largestDip, delta.Position.Magnitude)
            previous = current
        end
        check(largestTurn < math.rad(35) and largestDip < .3, "Pose has bounded smooth frame transitions at " .. fps .. " FPS")
        clean(f, "FPS " .. fps .. " finish")
        frameNear(previous, before, "Pose returns completely at " .. fps .. " FPS")
        pose:Play(f.Char, "Right", .22, .12); e:Advance(.11, 1 / fps)
        table.insert(samples, worldFrame(f.Char, f.Char.Torso))
        pose:Cancel(); clean(f, "FPS cancel")
        pose:Destroy()
    end
    frameNear(samples[1], samples[2], "Same timeline sample agrees at 30/60 FPS")
    frameNear(samples[2], samples[3], "Same timeline sample agrees at 60/120 FPS")
end

-- Each PreAnimation removes the previous overlay before default walking writes
-- today's base. Cancel must restore that latest base rather than yesterday's.
do
    local f = fixture("R6"); local e, pose = f.Env, f.Animator
    local walkRoot = CF.Angles(.03, .05, -.02)
    local walkRight, walkLeft = CF.Angles(.17, 0, 0), CF.Angles(-.11, 0, 0)
    e.DefaultAnimation = function()
        f.Joints.RootJoint.Transform = walkRoot
        f.Joints.RightHip.Transform = walkRight; f.Joints.LeftHip.Transform = walkLeft
    end
    pose:Play(f.Char, "Left", .22, .12); e:Advance(.1)
    e.Run.PreAnimation:Fire()
    frameNear(f.Joints.RootJoint.Transform, walkRoot, "PreAnimation restores the sampled engine torso base")
    frameNear(f.Joints.RightHip.Transform, walkRight, "PreAnimation restores the engine walking leg base")
    e.Run.PreSimulation:Fire(0)
    pose:Cancel(); clean(f, "Walking cancel")
    frameNear(f.Joints.RootJoint.Transform, walkRoot, "Cancel restores latest walking torso transform")
    frameNear(f.Joints.LeftHip.Transform, walkLeft, "Cancel restores latest walking leg transform")
    e:Advance(.1)
    frameNear(f.Joints.RightHip.Transform, walkRight, "Ordinary walking remains active after visual cancellation")
    pose:Destroy()
end

-- Both armed hands and the native Weld grip remain together for the entire
-- recovery, even while default walking tries to write relaxed arm transforms.
for _, kind in ipairs({"Saber", "Musket"}) do
    local f = fixture("R6"); local e, pose = f.Env, f.Animator
    local weapon = e:Weapon(kind, f.Char)
    local shoulderR, shoulderL, grip = f.Joints.RightShoulder, f.Joints.LeftShoulder, f.Joints.RightGrip
    local heldR, heldL = CF.Angles(-.9, .2, .15), CF.Angles(-.8, -.2, -.15)
    shoulderR.Transform, shoulderL.Transform = heldR, heldL
    grip.C0 = grip.C0 * CF.Angles(.1, -.03, .05)
    local heldGrip, toolGrip = grip.C0, weapon.Grip
    e.DefaultAnimation = function()
        shoulderR.Transform = CF.Angles(.12, 0, 0); shoulderL.Transform = CF.Angles(-.12, 0, 0)
    end
    pose:Play(f.Char, "Right", .22, .12)
    for _, time in ipairs({.07, .10, .07, .07}) do
        e:Advance(time)
        check(pose:IsPlaying(), "Weapon carry remains active through late " .. kind .. " recovery")
        frameNear(shoulderR.Transform, heldR, kind .. " trigger hand keeps the captured carry")
        frameNear(shoulderL.Transform, heldL, kind .. " support hand never drops to relaxed walking")
        frameNear(grip.C0, heldGrip, kind .. " native right grip remains fixed throughout recovery")
        check(weapon.Grip == toolGrip, "Weapon carry never changes Tool.Grip")
    end
    e:Advance(.2); clean(f, kind .. " carry finish")
    frameNear(shoulderR.Transform, CF.Angles(.12, 0, 0), "Carry release returns to the current engine arm base")
    frameNear(shoulderL.Transform, CF.Angles(-.12, 0, 0), "Both arms resume normal walking after carry release")
    pose:Destroy()
end

-- Interrupted lives and explicit teardown leave no active flag, pose listener
-- or owned kinematic state on either old or replacement avatars.
for _, reason in ipairs({"death", "removed", "cancel", "destroy"}) do
    local f = fixture("R15", true); local e, pose = f.Env, f.Animator
    pose:Play(f.Char, "Left", .22, .12); e:Advance(.08)
    if reason == "death" then f.Hum.Health = 0; f.Hum.Died:Fire()
    elseif reason == "removed" then f.Char.Parent = nil; e:Advance(.02)
    elseif reason == "cancel" then pose:Cancel()
    else pose:Destroy() end
    clean(f, "Interrupted " .. reason)
    for joint, base in pairs(f.Bases) do frameNear(joint.Transform, base, "Interrupted pose restores its original engine transform") end
    if reason ~= "destroy" then
        local nextCharacter = e:Character("Respawn")
        check(pose:Play(nextCharacter, "Right", .22, .12), "A fresh character can play after " .. reason)
        check(not f.Char:GetAttribute("LocalDodgePoseActive"), "Replacement avatar cannot retain old active flag")
        pose:Cancel(); pose:Destroy()
        check(e.Run.PreSimulation:Count() == 0 and e.Run.PreAnimation:Count() == 0, "Replacement cleanup removes all phase listeners")
    end
end

-- The weapon's upper-body constraints already own IsKinematic at Play time.
-- Dodge must capture ownership only after that overlay yields; otherwise its
-- saved true value poisons the weapon's next capture and survives unequip.
-- Repeat with reversed PreSimulation callback order: different modules cannot
-- depend on Roblox scheduling those callbacks in registration order.
for _, reversed in ipairs({false, true}) do
    local f = fixture("R15", true); local e, pose = f.Env, f.Animator
    if reversed then
        function e.Run.PreSimulation:Fire(...)
            local entries = table.clone(self.Listeners)
            for index = #entries, 1, -1 do
                if entries[index].Connected then entries[index].Callback(...) end
            end
        end
    end
    local gun = e:Weapon("Musket", f.Char)
    local grip = e:Node("Motor6D", "RightGrip", f.Char.RightHand)
    grip.Part0, grip.Part1 = f.Char.RightHand, gun.Handle
    grip.C0, grip.C1 = CF.new(0, -.1, 0), gun.Grip
    local weapon = e:Execute("src/combat/WeaponAnimator.luau")
    weapon.setWeapon(f.Char, gun); e:Advance(.3)
    check(f.Joints.RightShoulder.IsKinematic and f.Joints.LeftShoulder.IsKinematic,
        "Real weapon overlay owns upper-body constraints before dodge")
    local heldRight, heldLeft = f.Joints.RightShoulder.Transform, f.Joints.LeftShoulder.Transform
    pose:Play(f.Char, "Left", .22, .12)
    -- Approval can arrive after this frame's PreAnimation signal already ran.
    -- Wait for the pose's own restore phase before claiming native constraints.
    e.Run.PreSimulation:Fire(0)
    check(f.Joints.RightKnee.IsKinematic == f.Kinematic[f.Joints.RightKnee]
        and f.Joints.LeftKnee.IsKinematic == f.Kinematic[f.Joints.LeftKnee],
        "A Play between phases does not claim leg constraints before its first PreAnimation")
    check(not f.Joints.RightShoulder.IsKinematic and not f.Joints.LeftShoulder.IsKinematic,
        "Weapon can yield ownership in an approval frame without dodge capturing a stale true value")
    check(pose:IsPlaying() and f.Char:GetAttribute("LocalDodgePoseActive"), "Between-phase approval retains visual state for the next complete frame")
    e:Advance(.1)
    check(pose:IsPlaying() and f.Joints.RightShoulder.IsKinematic and f.Joints.RightKnee.IsKinematic,
        "Dodge temporarily claims upper and lower joints after the weapon yields")
    frameNear(f.Joints.RightShoulder.Transform, heldRight, "Constraint dodge preserves captured trigger-arm carry")
    frameNear(f.Joints.LeftShoulder.Transform, heldLeft, "Constraint dodge preserves captured support-arm carry")
    e:Advance(.4)
    check(not pose:IsPlaying() and not f.Char:GetAttribute("LocalDodgePoseActive"), "Constraint recovery finishes before weapon resumes")
    check(f.Joints.RightShoulder.IsKinematic and f.Joints.LeftShoulder.IsKinematic,
        "Existing weapon owns its constraints again after visual handoff")
    frameNear(f.Joints.RightShoulder.Transform, heldRight, "Constraint handoff resumes the same complete trigger pose")
    frameNear(f.Joints.LeftShoulder.Transform, heldLeft, "Constraint handoff resumes the same complete support pose")
    check(f.Joints.RightKnee.IsKinematic == f.Kinematic[f.Joints.RightKnee]
        and f.Joints.LeftKnee.IsKinematic == f.Kinematic[f.Joints.LeftKnee], "Only the weapon's upper-body constraints remain owned after dodge")
    weapon.stop(f.Char)
    for joint, baseline in pairs(f.Kinematic) do check(joint.IsKinematic == baseline, "Weapon unequip after dodge restores the true original kinematic baseline") end
    pose:Destroy()
    check(e.Run.PreAnimation:Count() == 0 and e.Run.PreSimulation:Count() == 0, "Constraint handoff teardown disconnects both overlays")
end

-- Real input-approval controller uses the procedural fallback, then hands the
-- carried weapon back to its existing overlay after visual recovery.
do
    local env = Environment.new(); local player = env:AddPlayer(1, true)
    local char, hum = player.Character, player.Character.Humanoid
    local gun = env:Weapon("Musket", char)
    local weapon = env:Execute("src/combat/WeaponAnimator.luau")
    weapon.setWeapon(char, gun); env:Advance(.3)
    local right = char:FindFirstChild("Right Shoulder", true)
    local left = char:FindFirstChild("Left Shoulder", true)
    local carryRight, carryLeft = right.Transform, left.Transform
    local settings = env:Execute("src/shared/SideDodge.luau")
    local requests = {}
    local controller = env:Execute("src/client/SideDodgeController.luau").new(player, settings,
        function(side, id) table.insert(requests, {Side = side, Id = id}) end, function() return true end)
    check(controller:Request("Right"), "Integrated controller sends a valid right-side request")
    check(not char:GetAttribute("LocalDodgePoseActive") and not controller.Active, "No procedural pose or physics starts before approval")
    local req = requests[#requests]
    controller:Handle("DodgeResult", {Allowed = true, Id = req.Id, Side = req.Side, Character = char,
        EndsAt = env.Time + settings.DASH_TIME, CooldownUntil = env.Time + settings.COOLDOWN})
    check(controller.Active and char:GetAttribute("LocalDodgePoseActive") and hum.WalkSpeed == 0,
        "Server-approved fallback starts one physics lock and procedural overlay")
    env:Advance(.11)
    frameNear(right.Transform, carryRight, "Weapon trigger arm stays carried while dodge owns the overlay")
    frameNear(left.Transform, carryLeft, "Weapon support arm stays carried while dodge owns the overlay")
    env:Advance(.15)
    check(not controller.Active and controller:IsBusy() and char:GetAttribute("LocalDodgePoseActive"),
        "Physics ends before visual recovery releases its busy gate")
    check(hum.WalkSpeed == 16 and hum.AutoRotate, "Physics restores movement settings during the visual finish")
    frameNear(right.Transform, carryRight, "Trigger arm stays carried through controller recovery")
    frameNear(left.Transform, carryLeft, "Support arm stays carried through controller recovery")
    env:Advance(.18)
    check(not controller:IsBusy() and not char:GetAttribute("LocalDodgePoseActive"), "Recovery releases the visual coordination flag")
    frameNear(right.Transform, carryRight, "Weapon trigger arm resumes full guard without a relaxed-arm frame")
    frameNear(left.Transform, carryLeft, "Weapon support arm resumes full guard without dropping")
    controller:Destroy(); weapon.stop(char)
    check(env.Run.PreAnimation:Count() == 0 and env.Run.PreSimulation:Count() == 0 and env.Run.Heartbeat:Count() == 0,
        "Integrated controller teardown cleans procedural, weapon and physics listeners")
    check(player.CharacterAdded:Count() == 0 and player.CharacterRemoving:Count() == 0, "Integrated lifecycle listeners are removed")
end

-- Equipping for the first time during an unarmed physical dodge registers the
-- weapon's tool listener before the pose's cancellation listener. Its discovery
-- sees true owned constraints, but a paused weapon has not claimed them yet.
-- Pausing that new state must never restore its unowned discovery snapshot.
do
    local f = fixture("R15", true); local e, pose = f.Env, f.Animator
    local weapon = e:Execute("src/combat/WeaponAnimator.luau")
    local equipConnection = f.Char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then weapon.setWeapon(f.Char, child) end
    end)
    f.Char:SetAttribute("LocalDodgeActive", true) -- existing physics still owns the current step
    pose:Play(f.Char, "Right", .22, .12); e:Advance(.1)
    check(f.Joints.RightShoulder.IsKinematic and f.Joints.LeftShoulder.IsKinematic,
        "Unarmed dodge owns the shoulder constraints before native equip")
    local gun = e:Weapon("Musket")
    local grip = e:Node("Motor6D", "RightGrip", f.Char.RightHand)
    grip.Part0, grip.Part1 = f.Char.RightHand, gun.Handle
    grip.C0, grip.C1 = CF.new(0, -.1, 0), gun.Grip
    gun.Parent = f.Char
    check(not pose:IsPlaying() and f.Char:GetAttribute("LocalDodgeActive"),
        "Native equip cancels visual pose while the physical dodge still blocks weapon overlay")
    e:Advance(.02)
    check(not f.Joints.RightShoulder.IsKinematic and not f.Joints.LeftShoulder.IsKinematic,
        "New paused weapon leaves restored constraints untouched until it actually claims ownership")
    f.Char:SetAttribute("LocalDodgeActive", false); e:Advance(.3)
    check(f.Joints.RightShoulder.IsKinematic and f.Joints.LeftShoulder.IsKinematic,
        "Newly equipped weapon claims its restored upper-body constraints after physics releases")
    weapon.stop(f.Char)
    for joint, baseline in pairs(f.Kinematic) do
        check(joint.IsKinematic == baseline, "First equip during dodge restores every true original constraint baseline on unequip")
    end
    equipConnection:Disconnect(); pose:Destroy()
    check(e.Run.PreAnimation:Count() == 0 and e.Run.PreSimulation:Count() == 0,
        "First equip during dodge leaves no owned overlay callbacks after cleanup")
end

-- Native hotbar tool events are handled by the real CombatClient. Cancelling
-- the pose on tool change must restore today's engine base before the next
-- weapon captures it, both before the first pose frame and halfway through.
for _, immediate in ipairs({true, false}) do
    local f = fixture("R6"); local e, pose = f.Env, f.Animator
    local player = e:AddPlayer(1, true); player.Character = f.Char
    local walkingRoot = CF.Angles(.02, .04, -.01)
    local walkingRight, walkingLeft = CF.Angles(.13, 0, 0), CF.Angles(-.09, 0, 0)
    e.DefaultAnimation = function()
        f.Joints.RootJoint.Transform = walkingRoot
        f.Joints.RightShoulder.Transform = walkingRight
        f.Joints.LeftShoulder.Transform = walkingLeft
    end
    local musket = e:Weapon("Musket", f.Char)
    e:StartClient(); e:Advance(.3)
    check(pose:Play(f.Char, "Right", .22, .12), "Hotbar test starts the existing weapon carry pose")
    if not immediate then e:Advance(.1) end
    musket.Parent = player.Backpack
    check(not pose:IsPlaying() and not f.Char:GetAttribute("LocalDodgePoseActive"), "Native tool removal cancels dodge before the next weapon snapshot")
    frameNear(f.Joints.RightShoulder.Transform, walkingRight, "Hotbar cancellation restores current right engine arm even before the first pose frame")
    frameNear(f.Joints.LeftShoulder.Transform, walkingLeft, "Hotbar cancellation restores current left engine arm without stale weapon entry pose")
    frameNear(f.Joints.RootJoint.Transform, walkingRoot, "Hotbar cancellation restores latest engine torso")
    local saber = e:Weapon("Saber", f.Char); e:Advance(.3)
    check(not pose:IsPlaying() and not f.Char:GetAttribute("LocalDodgePoseActive"), "Replacement tool does not revive old visual ownership")
    check(frameError(f.Joints.RightShoulder.Transform, walkingRight) > .05, "Replacement weapon resumes its own equipped guard")
    saber.Parent = player.Backpack
    frameNear(f.Joints.RightShoulder.Transform, walkingRight, "Unequip after hotbar swap never restores a stale dodge arm snapshot")
    frameNear(f.Joints.LeftShoulder.Transform, walkingLeft, "Support arm returns to current ordinary walking after swap")
    frameNear(f.Joints.RootJoint.Transform, walkingRoot, "Unequip after swap never freezes a stale torso snapshot")
    pose:Destroy(); e.ClientScript:Destroy()
    check(e.Run.PreAnimation:Count() == 0 and e.Run.PreSimulation:Count() == 0, "Hotbar swap teardown leaves no weapon or dodge phase listeners")
    check(f.Char.ChildAdded:Count() == 0 and f.Char.ChildRemoved:Count() == 0, "Hotbar swap teardown removes both tool-change watchers")
end

print(string.format("Dodge poses: %d behavior checks passed (joint fixtures; visual Studio check still required).", checks))
