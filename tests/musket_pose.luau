-- lune run tests/musket_pose.luau
-- Actual production overlay and native R6/R15 joint axes, plus the real
-- 43-part musket geometry. This is a geometric test, not a Studio screenshot.
local Environment = require("./helpers/combat_environment")
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local V, CF = roblox.Vector3, roblox.CFrame
local checks = 0
local function check(value, label) checks += 1; assert(value, label) end
local function near(actual, expected, label)
    check(math.abs(actual - expected) < 1e-4, label .. ": " .. tostring(actual))
end
local function frameNear(a, b, label)
    local first, second = {a:GetComponents()}, {b:GetComponents()}
    for index = 1, 12 do near(first[index], second[index], label .. " / " .. index) end
end
local model = roblox.deserializeModel(fs.readFile("assets/weapons/Musket.rbxmx"))[1]
local modelHandle, modelForestock = model:FindFirstChild("Handle"), model:FindFirstChild("Forestock")
local modelBarrel = model:FindFirstChild("Barrel")
local modelMuzzle = modelBarrel:FindFirstChild("Muzzle")
local stockLocal = modelHandle.CFrame:ToObjectSpace(modelForestock.CFrame)
local muzzleLocal = modelHandle.CFrame:ToObjectSpace(modelBarrel.CFrame * modelMuzzle.CFrame)

local function world(character, part)
    if part == character.HumanoidRootPart then return part.CFrame end
    for _, joint in character:GetDescendants() do
        if (joint:IsA("Motor6D") or joint:IsA("Weld")) and joint.Part1 == part then
            return world(character, joint.Part0) * joint.C0
                * (joint:IsA("Weld") and CF.new() or joint.Transform) * joint.C1:Inverse()
        end
    end
    return part.CFrame
end
local function addJoint(env, name, first, second, c0, c1, class)
    local joint = env:Node(class or "Motor6D", name, first)
    joint.Part0, joint.Part1, joint.C0, joint.C1 = first, second, c0, c1
    return joint
end
local function setup(r15)
    local env = Environment.new()
    local character, humanoid, root = env:Character()
    character.Torso.Size = V.new(2, 2, 1)
    character["Right Arm"].Size, character["Left Arm"].Size = V.new(1, 2, 1), V.new(1, 2, 1)
    character.Head.Size = V.new(2, 1, 1)
    if r15 then
        character:FindFirstChild("Right Shoulder", true):Destroy()
        character:FindFirstChild("Left Shoulder", true):Destroy()
        character["Right Arm"]:Destroy(); character["Left Arm"]:Destroy()
        local upper = character.Torso
        upper.Name = "UpperTorso"
        local lower = env:Node("Part", "LowerTorso", character)
        lower.Size = V.new(2, 1, 1)
        character:FindFirstChild("RootJoint", true).Part1 = lower
        addJoint(env, "Waist", lower, upper, CF.new(0, .3, 0), CF.new(0, -.3, 0))
        for _, side in {"Left", "Right"} do
            local first = env:Node("Part", side .. "UpperArm", character)
            local second = env:Node("Part", side .. "LowerArm", character)
            local hand = env:Node("Part", side .. "Hand", character)
            first.Size, second.Size, hand.Size = V.new(.5, 1, .5), V.new(.45, 1, .45), V.new(.55, .45, .55)
            addJoint(env, side .. "Shoulder", upper, first, CF.new(side == "Right" and 1 or -1, .45, 0), CF.new(0, .5, 0))
            addJoint(env, side .. "Elbow", first, second, CF.new(0, -.5, 0), CF.new(0, .5, 0))
            addJoint(env, side .. "Wrist", second, hand, CF.new(0, -.5, 0), CF.new(0, .20, 0))
            if side == "Right" then
                addJoint(env, "RightGrip", hand, nil, CF.new(0, -.125, 0) * CF.Angles(-math.pi / 2, 0, 0), CF.new(), "Weld")
            end
        end
    end
    local tool = env:Node("Tool", "Musket")
    tool.Grip = model.Grip
    tool:SetAttribute("WeaponType", "Musket")
    for _, original in model:GetChildren() do
        if original:IsA("BasePart") then
            local part = env:Node("Part", original.Name, tool)
            part.Size, part.CFrame = original.Size, original.CFrame
            for _, child in original:GetChildren() do
                if child:IsA("Attachment") then
                    local attachment = env:Node("Attachment", child.Name, part)
                    attachment.CFrame, attachment.Position = child.CFrame, child.CFrame.Position
                end
            end
        end
    end
    tool.Parent = character
    local animator = env:Execute("src/combat/WeaponAnimator.luau")
    return env, character, humanoid, root, tool, animator
end
local function supportGap(character, tool, r15)
    local hand = character:FindFirstChild(r15 and "LeftHand" or "Left Arm")
    local handle = world(character, tool.Handle)
    local target = handle * stockLocal * CF.new(-modelForestock.Size.X * .20, -modelForestock.Size.Y * .44, -modelForestock.Size.Z * .12)
    local localTarget = world(character, hand):PointToObjectSpace(target.Position)
    local size = hand.Size
    local closest = V.new(math.clamp(localTarget.X, -size.X * .5, size.X * .5),
        math.clamp(localTarget.Y, -size.Y * .5, r15 and size.Y * .5 or -size.Y * .20),
        math.clamp(localTarget.Z, -size.Z * .5, size.Z * .5))
    return (localTarget - closest).Magnitude, localTarget
end

for _, r15 in {false, true} do
    local env, character, humanoid, root, tool, animator = setup(r15)
    local label = r15 and "R15" or "R6"
    local originals = {}
    for _, joint in character:GetDescendants() do
        if joint:IsA("Motor6D") or joint:IsA("Weld") then
            originals[joint] = {C0 = joint.C0, C1 = joint.C1, Transform = joint.Transform}
        end
    end
    local originalGrip = tool.Grip
    animator.setWeapon(character, tool)
    env:Advance(.2)
    local grip = character:FindFirstChild("RightGrip", true)
    local held = world(character, grip.Part0) * grip.C0
    local gap = supportGap(character, tool, r15)
    print(label .. " neutral trigger=" .. tostring(held.Position) .. ", support gap=" .. tostring(gap))
    check(held.Position.X >= .8 and held.Position.X <= 1.10, label .. " trigger hand clears the character on the right")
    if not r15 then
        check(held.Position.Y >= .2 and held.Position.Y <= .7 and held.Position.Z >= -1.35 and held.Position.Z <= -.85,
            "R6 trigger hand remains comfortably in front of the chest")
    end
    local worstContact = 0
    for _, yaw in {-1.2, 0, .8} do
        for _, pitch in {-45, -25, 0, 25, 45} do
            local frame = CF.new(3, 4, -2) * CF.Angles(0, yaw, 0)
            root.CFrame = frame
            animator.setAimPitch(character, math.rad(pitch)); env:Advance(.05)
            local handle = world(character, tool.Handle)
            local direction = frame.LookVector * math.cos(math.rad(pitch)) + V.yAxis * math.sin(math.rad(pitch))
            near(handle.UpVector:Dot(direction), 1, label .. " actual barrel follows yaw/pitch " .. pitch)
            local muzzle = handle * muzzleLocal
            check((muzzle.Position - handle.Position):Dot(direction) > 2,
                label .. " actual 43-part model muzzle remains in front of the trigger grip")
            local contact = supportGap(character, tool, r15)
            worstContact = math.max(worstContact, contact)
            check(contact < .16, label .. " support palm stays at the near forestock across camera pitch")
            for joint, saved in originals do
                if joint.Name ~= "RightGrip" then
                    frameNear(joint.C0, saved.C0, label .. " original attachment stays connected: " .. joint.Name)
                    frameNear(joint.C1, saved.C1, label .. " original child attachment stays connected: " .. joint.Name)
                    near(joint.Transform.Position.Magnitude, 0, label .. " pose contains no detached/translated joint: " .. joint.Name)
                end
            end
            frameNear(root.CFrame, frame, label .. " aiming pose never moves or rotates the root")
            frameNear(tool.Grip, originalGrip, label .. " overlay preserves Tool Grip")
            check(humanoid.WalkSpeed == 16 and humanoid.AutoRotate, label .. " overlay preserves ordinary movement settings")
        end
    end
    print(label .. " support maximum gap=" .. worstContact .. " across yaw/pitch ±45°")
    root.CFrame = CF.new()
    animator.setAimPitch(character, 0); env:Advance(.05)
    local rested = world(character, tool.Handle)
    -- Project the real muzzle against the torso/head silhouette from the
    -- actual shoulder-camera offset, rather than mistaking correct barrel
    -- direction alone for visible third-person weapon placement.
    for _, distance in {5, 8, 12} do
        local camera = CF.new(2.2, .5, distance)
        local muzzle = camera:PointToObjectSpace((rested * muzzleLocal).Position)
        local rightEdge = -math.huge
        for _, body in {character:FindFirstChild(r15 and "UpperTorso" or "Torso"), character.Head} do
            local bodyFrame = world(character, body)
            for _, x in {-1, 1} do
                for _, y in {-1, 1} do
                    for _, z in {-1, 1} do
                        local corner = camera:PointToObjectSpace(bodyFrame:PointToWorldSpace(V.new(x * body.Size.X * .5,
                            y * body.Size.Y * .5, z * body.Size.Z * .5)))
                        rightEdge = math.max(rightEdge, corner.X / -corner.Z)
                    end
                end
            end
        end
        check(muzzle.X / -muzzle.Z > rightEdge + .002,
            label .. " real muzzle clears head/torso silhouette from shoulder-camera distance " .. distance)
    end
    animator.playMusket(character, "kick")
    env:Advance(.02)
    check(animator.IsBusy(character), label .. " recoil begins its ordinary short action")
    check(world(character, tool.Handle).UpVector:Dot(root.CFrame.LookVector) > .99,
        label .. " recoil stays aligned with camera yaw instead of swinging sideways")
    check(supportGap(character, tool, r15) < .2, label .. " support hand follows the firearm during recoil")
    env:Advance(.3)
    check(not animator.IsBusy(character), label .. " recoil settles without an extra controller")
    frameNear(world(character, tool.Handle), rested, label .. " recoil returns to the same two-hand hold")
    animator.stop(character)
    for joint, saved in originals do
        frameNear(joint.C0, saved.C0, label .. " unequip restores native attachment " .. joint.Name)
        frameNear(joint.Transform, saved.Transform, label .. " unequip restores native motion " .. joint.Name)
    end
    check(env.Run.PreSimulation:Count() == 0 and env.Run.PreAnimation:Count() == 0,
        label .. " overlay cleanup releases both animation connections")
end
print("PASS musket pose: " .. checks .. " checks (actual R6/R15 FK and 43-part muzzle/forestock geometry)")
