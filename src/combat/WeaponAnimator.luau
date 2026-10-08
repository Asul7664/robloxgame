-- Local upper-body overlays, applied AFTER the ordinary character Animator.
-- Legs, movement speed, root position and the camera remain under their existing controllers.
-- R6 uses whole-arm poses; R15 adds elbow/wrist articulation. Upgraded
-- AnimationConstraint rigs use their real attachments without editing them.
local RunService = game:GetService("RunService")
local Animator = { SaberDuration = 0.66, SaberActiveTime = 0.25 }
local states = {}

local function angles(value)
	-- Yaw is outside pitch so a broad cut really travels across the body.
	return CFrame.Angles(0, math.rad(value.Y), 0)
		* CFrame.Angles(math.rad(value.X), 0, math.rad(value.Z))
end
local function rotation(frame)
	return CFrame.new(frame.Position):Inverse() * frame
end
local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
local function pose(right, left, torso, rightElbow, leftElbow, wrist)
	return {
		Right = Vector3.new(table.unpack(right)), Left = Vector3.new(table.unpack(left)),
		Torso = Vector3.new(table.unpack(torso)), RightElbow = rightElbow,
		LeftElbow = leftElbow, Wrist = Vector3.new(table.unpack(wrist or { -7, 0, -6 })),
	}
end
local GUARD = pose({ 52, -14, 10 }, { 16, 12, -18 }, { 2, -7, 0 }, 24, 32)
-- A slight side-on stance leaves the trigger hand in front of the right
-- shoulder. The muzzle therefore clears the body in the shoulder camera.
local AIM = pose({ 88, 40, -8 }, { 74, -65, 5 }, { 0, -30, 0 }, 34, 38, { 0, 0, 0 })
local CUTS = {
	{
		Name = "Диагональный удар",
		Wind = pose({ 108, -68, 32 }, { 26, 22, -24 }, { 1, -24, -4 }, 44, 40, { -6, 0, 8 }),
		Hit = pose({ 58, 58, -12 }, { 34, -25, -25 }, { 6, 20, 3 }, 8, 24, { 4, 0, -9 }),
		Follow = pose({ 28, 82, -22 }, { 32, -35, -24 }, { 9, 27, 7 }, 18, 30, { 2, 0, -12 }),
	},
	{
		Name = "Восходящий удар",
		Wind = pose({ 24, 58, -19 }, { 22, -20, -26 }, { 7, 20, 4 }, 30, 34, { -4, 0, -10 }),
		Hit = pose({ 106, -46, 23 }, { 34, 18, -27 }, { -2, -15, -3 }, 8, 28, { 8, 0, 8 }),
		Follow = pose({ 130, -62, 28 }, { 24, 26, -18 }, { -3, -22, -4 }, 32, 35, { 4, 0, 10 }),
	},
	{
		Name = "Рубящий удар сверху",
		Wind = pose({ 152, -12, 10 }, { 40, 8, -27 }, { -7, -8, -2 }, 54, 42, { -5, 0, 3 }),
		Hit = pose({ 44, 8, 2 }, { 28, -10, -28 }, { 10, 5, 0 }, 8, 28, { 9, 0, -4 }),
		Follow = pose({ 12, 18, 8 }, { 32, -14, -25 }, { 13, 7, 1 }, 22, 34, { 6, 0, -4 }),
	},
}
local function blend(a, b, weight)
	return {
		Right = a.Right:Lerp(b.Right, weight), Left = a.Left:Lerp(b.Left, weight),
		Torso = a.Torso:Lerp(b.Torso, weight), Wrist = a.Wrist:Lerp(b.Wrist, weight),
		RightElbow = a.RightElbow + (b.RightElbow - a.RightElbow) * weight,
		LeftElbow = a.LeftElbow + (b.LeftElbow - a.LeftElbow) * weight,
	}
end
local function jointName(part, fallback)
	local names = { LowerTorso = "Root", UpperTorso = "Waist", Head = "Neck", Torso = "RootJoint" }
	if names[part.Name] then return names[part.Name] end
	for _, side in ipairs({ "Right", "Left" }) do
		if part.Name == side .. " Arm" then return side .. "Shoulder" end
		if part.Name == side .. " Leg" then return side .. "Hip" end
		for body, joint in pairs({ UpperArm = "Shoulder", LowerArm = "Elbow", Hand = "Wrist" }) do
			if part.Name == side .. body then return side .. joint end
		end
	end
	return fallback
end
local function constraintView(joint)
	local a, b = joint.Attachment0, joint.Attachment1
	if not a or not b or not a.Parent or not b.Parent or joint.Enabled == false
		or not a.Parent:IsA("BasePart") or not b.Parent:IsA("BasePart") then return nil end
	return setmetatable({ Source = joint, IsConstraint = true }, {
		__index = function(_, key)
			if key == "Part0" then return a.Parent elseif key == "Part1" then return b.Parent
			elseif key == "C0" then return a.CFrame elseif key == "C1" then return b.CFrame end
			return joint[key]
		end,
		__newindex = function(_, key, value)
			if key == "Transform" then joint.Transform = value else error("Only joint Transform is writable") end
		end,
	})
end
local function gripView(joint)
	if not joint:IsA("Weld") then return joint end
	-- A Tool's R6 RightGrip can be a Weld, which has no Transform property.
	-- Keep its initial C0 immutable in this view; animation is the same overlay
	-- as for a Motor6D and can be removed without changing the Tool's own Grip.
	local base = joint.C0
	return setmetatable({ Source = joint, IsWeld = true }, {
		__index = function(_, key)
			if key == "Transform" then return base:Inverse() * joint.C0
			elseif key == "C0" then return base end
			return joint[key]
		end,
		__newindex = function(_, key, value)
			if key == "Transform" then joint.C0 = base * value else error("Only grip Transform is writable") end
		end,
	})
end
local function refreshGrip(state)
	local current = state.Joints.RightGrip
	if current and current.Parent then return end
	-- Equipped can fire before Roblox inserts RightGrip. Discover it once it
	-- arrives rather than keeping the no-grip snapshot for the whole equip.
	for _, joint in ipairs(state.Character:GetDescendants()) do
		if joint.Name == "RightGrip" and (joint:IsA("Motor6D") or joint:IsA("Weld"))
			and joint.Part0 and joint.Part1 and joint.Part1.Parent == state.Tool then
			local view = gripView(joint)
			state.Joints.RightGrip = view
			state.ByPart[joint.Part1] = view
			state.Original[view] = view.Transform
			return
		end
	end
end
local function alive(joint)
	return joint and joint.Parent ~= nil
end
local function restore(state)
	for joint, base in pairs(state.Applied) do
		if alive(joint) then joint.Transform = base end
	end
	state.Applied = {}
end
local function kinematic(state, enabled)
	if state.Kinematic == enabled then return end
	-- A newly equipped weapon can begin while dodge owns the rig. It must
	-- not restore an equip-time snapshot before ever claiming those joints.
	if not enabled and state.Kinematic ~= true then
		state.Kinematic = false
		return
	end
	state.Kinematic = enabled
	for _, entry in ipairs(state.Constraints) do
		if entry.Joint.Parent then
			if enabled then
				entry.Previous = entry.Joint.IsKinematic
				entry.Joint.IsKinematic = true
			else
				entry.Joint.IsKinematic = entry.Previous
			end
		end
	end
end
local function finish(state, completed)
	local action = state.Action
	if not action then return end
	state.Action = nil
	if action.OnFinish then action.OnFinish(completed) end
end
local function overlay(state, name, degrees, weight, absolute)
	local joint = state.Joints[name]
	if not alive(joint) then return end
	-- Conjugate around the parent axes: R6 shoulder C0 is rotated 90 degrees,
	-- so assigning the same raw Euler Transform as R15 gives the wrong movement.
	local axes = rotation(joint.C0)
	local target = axes:Inverse() * angles(degrees) * axes
	local base = joint.Transform
	state.Applied[joint] = base
	joint.Transform = base:Lerp(absolute and target or base * target, weight)
end
local function paused(state)
	return state.Character:GetAttribute("Dodging") == true
		or state.Character:GetAttribute("LocalDodgeActive") == true
		or state.Character:GetAttribute("LocalDodgePoseActive") == true
		or state.Character:GetAttribute("CombatUIBlocked") == true
end
local function worldFrame(state, part, cache)
	if part == state.Root then return part.CFrame end
	if cache[part] then return cache[part] end
	local joint = state.ByPart[part]
	local frame = joint and worldFrame(state, joint.Part0, cache) * joint.C0 * joint.Transform * joint.C1:Inverse()
		or part.CFrame
	cache[part] = frame
	return frame
end
local function aimGrip(state, current, weight)
	local joint = state.Joints.RightGrip
	if not alive(joint) or not state.Root then return end
	local parent = worldFrame(state, joint.Part0, {})
	local pivot = (parent * joint.C0).Position
	local recoil = math.max(0, AIM.Right.X - current.Right.X) * .4
	-- The model's barrel is local +Y. Keep its muzzle facing the same horizontal
	-- direction as the camera-controlled root. The arm controls the hold point;
	-- this world-space rotation keeps shoulder posing from turning it sideways.
	local desired = CFrame.new(pivot) * rotation(state.Root.CFrame)
		* CFrame.Angles(-math.pi / 2 + state.AimPitch + math.rad(recoil), 0, 0)
		* CFrame.new(-joint.C1.Position)
	local base = joint.Transform
	state.Applied[joint] = base
	joint.Transform = base:Lerp(joint.C0:Inverse() * parent:Inverse() * desired * joint.C1, weight)
end
local function supportGrip(state, weight)
	local shoulder = state.Joints.LeftShoulder
	local handle = state.Tool:FindFirstChild("Handle")
	local hand = state.Character:FindFirstChild(state.R15 and "LeftHand" or "Left Arm")
	if not alive(shoulder) or not handle or not hand then return end
	local parent = worldFrame(state, shoulder.Part0, {})
	local pivotFrame = parent * shoulder.C0
	local pivot = pivotFrame.Position
	local target = worldFrame(state, handle, {}):PointToWorldSpace(state.SupportLocal)
	-- R6's square palm is the end of the whole arm. R15 has a separate hand.
	local size = hand.Size
	local palm = state.R15 and Vector3.new(-size.X * .08, -size.Y * .28, -size.Z * .18)
		or Vector3.new(-size.X * .43, -size.Y * .475, -size.Z * .40)
	local elbow = state.R15 and state.Joints.LeftElbow
	if alive(elbow) then
		local elbowFrame = worldFrame(state, elbow.Part0, {}) * elbow.C0
		local first = (elbowFrame.Position - pivot).Magnitude
		local second = (worldFrame(state, hand, {}):PointToWorldSpace(palm) - elbowFrame.Position).Magnitude
		if first > .01 and second > .01 then
			local distance = math.clamp((target - pivot).Magnitude, math.abs(first - second) + .01, first + second - .01)
			local bend = math.acos(math.clamp((distance * distance - first * first - second * second) / (2 * first * second), -1, 1))
			local axes = rotation(elbow.C0)
			elbow.Transform = elbow.Transform:Lerp(axes:Inverse() * CFrame.Angles(bend, 0, 0) * axes, weight)
		end
	end
	local from = worldFrame(state, hand, {}):PointToWorldSpace(palm) - pivot
	local to = target - pivot
	if from.Magnitude < .01 or to.Magnitude < .01 then return end
	local cross = from.Unit:Cross(to.Unit)
	local cosine = math.clamp(from.Unit:Dot(to.Unit), -1, 1)
	if cross.Magnitude < 1e-5 then return end
	local correction = CFrame.fromAxisAngle(cross.Unit, math.acos(cosine))
	local desired = rotation(pivotFrame):Inverse() * correction * rotation(pivotFrame * shoulder.Transform)
	-- Rotate around the original shoulder attachment only; no translated C0,
	-- floating shoulder, root correction, or extra movement controller.
	shoulder.Transform = shoulder.Transform:Lerp(desired, weight)
end
local function bodyPose(state, current, weight)
	refreshGrip(state)
	local right, left = current.Right, current.Left
	if state.R15 then
		-- The articulated R15 arm reaches farther than R6's single block, so
		-- use less inward shoulder yaw to keep the trigger beside the body.
		right = Vector3.new(right.X * .64, state.Kind == "Musket" and right.Y * .55 or right.Y, right.Z)
		left = Vector3.new(left.X * .64, left.Y, left.Z)
	end
	local pitch = state.Kind == "Musket" and math.deg(state.AimPitch) or 0
	if pitch ~= 0 then
		-- Wrist/grip alignment supplies the remaining camera pitch. Lifting the
		-- entire arm by 45 degrees would pull the stock away from the support hand.
		right += Vector3.new(pitch * .35, 0, 0)
		left += Vector3.new(pitch * .35, 0, 0)
	end
	overlay(state, "RightShoulder", right, weight, true)
	overlay(state, "LeftShoulder", left, weight, true)
	overlay(state, "RightElbow", Vector3.new(current.RightElbow, 0, 0), weight, true)
	overlay(state, "LeftElbow", Vector3.new(current.LeftElbow, 0, 0), weight, true)
	overlay(state, state.R15 and "Waist" or "RootJoint", current.Torso, weight, false)
	-- Head counter-turns gently while the shoulders lead the cut.
	overlay(state, "Neck", Vector3.new(-current.Torso.X * .35, -current.Torso.Y * .45, -current.Torso.Z * .3), weight, false)
	if state.Kind == "Musket" then
		aimGrip(state, current, weight)
		supportGrip(state, weight)
	elseif state.R15 then
		overlay(state, "RightWrist", current.Wrist, weight, true)
	else
		overlay(state, "RightGrip", current.Wrist, weight, false)
	end
end
local function attackPose(action)
	local t, cut = action.Elapsed, action.Cut
	if t < .16 then return blend(action.StartPose, cut.Wind, smooth(t / .16)) end
	if t < .29 then
		-- Fast acceleration through a broad arc, without snapping between key poses.
		return blend(cut.Wind, cut.Hit, smooth((t - .16) / .13))
	end
	if t < .39 then return blend(cut.Hit, cut.Follow, smooth((t - .29) / .10)) end
	return blend(cut.Follow, GUARD, smooth((t - .39) / (Animator.SaberDuration - .39)))
end
local function update(state, dt)
	if states[state.Character] ~= state then return end
	if not state.Character.Parent or not state.Tool.Parent or state.Tool.Parent ~= state.Character
		or (state.Humanoid and state.Humanoid.Health <= 0) then
		Animator.stop(state.Character)
		return
	end
	if paused(state) then
		finish(state, false)
		kinematic(state, false)
		-- Dodge captures and returns the carried pose. Keep its weight so the
		-- handoff cannot drop the supporting arm before aim resumes.
		if state.Character:GetAttribute("CombatUIBlocked") == true then state.Weight = 0 end
		return
	end
	kinematic(state, true)
	state.Weight = math.min(1, state.Weight + dt / .14)
	local action = state.Action
	local current = state.Kind == "Saber" and GUARD or AIM
	if action then
		local held = math.min(action.Hold, dt)
		action.Hold -= held
		action.Elapsed += dt - held
		if action.Kind == "Saber" then
			current = attackPose(action)
			if not action.Fired and action.Elapsed >= Animator.SaberActiveTime then
				action.Fired = true
				if action.OnActive then
					action.OnActive(function(didHit)
						if didHit and states[state.Character] == state and state.Action == action then
							action.Hold = .055
						end
					end)
				end
			end
			if action.Elapsed >= Animator.SaberDuration then finish(state, true) end
		else
			-- The stock and both hands give together, then settle back into aim.
			local kick = (1 - math.clamp(action.Elapsed / .28, 0, 1)) ^ 2
			current = blend(AIM, pose({ 76, 40, -8 }, { 66, -65, 5 }, { -3, -30, 0 }, 44, 46, { 0, 0, 0 }), kick)
			if action.Elapsed >= .28 then finish(state, true) end
		end
	end
	state.LastPose = current
	bodyPose(state, current, smooth(state.Weight))
end

function Animator.stop(character)
	local state = states[character]
	if not state then return end
	states[character] = nil
	for _, connection in ipairs(state.Connections) do connection:Disconnect() end
	restore(state)
	kinematic(state, false)
	-- restore() removes only our last overlay. An equip-time snapshot can
	-- contain a walking or dodge pose owned by another animator, so writing it
	-- again here would leave that old pose behind after a hotbar change.
	finish(state, false)
end

function Animator.setWeapon(character, tool)
	local state = states[character]
	if state and state.Tool == tool then return end
	Animator.stop(character)
	if not character or not tool then return end
	local kind = tool:GetAttribute("WeaponType")
	if kind ~= "Saber" and kind ~= "Musket" then return end
	state = {
		Character = character, Tool = tool, Kind = kind, Joints = {}, Constraints = {}, ByPart = {},
		Original = {}, Applied = {}, Connections = {}, Weight = 0, AimPitch = 0,
		Humanoid = character:FindFirstChildOfClass("Humanoid"),
		Root = character:FindFirstChild("HumanoidRootPart"),
		R15 = character:FindFirstChild("RightUpperArm") ~= nil,
		LastPose = kind == "Saber" and GUARD or AIM,
	}
	if kind == "Musket" then
		local handle, forestock = tool:FindFirstChild("Handle"), tool:FindFirstChild("Forestock")
		-- Hold the nearby rear section: a short musket should not require a
		-- blocky R6 arm to stretch across the chest to the middle of the barrel.
		state.SupportLocal = handle and forestock and handle.CFrame:ToObjectSpace(forestock.CFrame)
			:PointToWorldSpace(Vector3.new(-forestock.Size.X * .20, -forestock.Size.Y * .44, -forestock.Size.Z * .12))
			or Vector3.new(-.046, .2212, -.0074)
	end
	local descendants = character:GetDescendants()
	for _, joint in ipairs(descendants) do
		if (joint:IsA("Motor6D") or joint.Name == "RightGrip" and joint:IsA("Weld")) and joint.Part0 and joint.Part1 then
			local name = joint.Name == "RightGrip" and "RightGrip" or jointName(joint.Part1, joint.Name:gsub(" ", ""))
			state.Joints[name] = name == "RightGrip" and gripView(joint) or joint
			state.ByPart[joint.Part1] = state.Joints[name]
		end
	end
	for _, joint in ipairs(descendants) do
		if joint:IsA("AnimationConstraint") then
			local view = constraintView(joint)
			if view then
				local name = jointName(view.Part1, joint.Name:gsub(" ", ""))
				state.Joints[name] = view
				state.ByPart[view.Part1] = view
			end
		end
	end
	local controlled = { "RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow",
		"RightWrist", "RightGrip", "Waist", "RootJoint", "Neck" }
	for _, name in ipairs(controlled) do
		local joint = state.Joints[name]
		if joint then
			state.Original[joint] = joint.Transform
			if type(joint) == "table" and rawget(joint, "IsConstraint") then
				table.insert(state.Constraints, { Joint = joint.Source, Previous = joint.Source.IsKinematic })
			end
		end
	end
	states[character] = state
	-- Remove yesterday's overlay BEFORE Animator runs, then sample today's
	-- walking/idle pose afterwards. In particular, torso twist never accumulates.
	table.insert(state.Connections, RunService.PreAnimation:Connect(function()
		restore(state)
		-- Yield constraint ownership in the earlier phase, before any dodge
		-- PreSimulation callback can claim it; listener order does not matter.
		if paused(state) then kinematic(state, false) end
	end))
	table.insert(state.Connections, RunService.PreSimulation:Connect(function(dt) update(state, dt) end))
	if state.Humanoid then
		table.insert(state.Connections, state.Humanoid.Died:Connect(function() Animator.stop(character) end))
	end
	table.insert(state.Connections, tool.AncestryChanged:Connect(function()
		if tool.Parent ~= character then Animator.stop(character) end
	end))
end

function Animator.IsBusy(character)
	return states[character] ~= nil and states[character].Action ~= nil
end
function Animator.setAimPitch(character, radians)
	local state = states[character]
	if state and type(radians) == "number" then
		state.AimPitch = math.clamp(radians, -math.pi / 4, math.pi / 4)
	end
end
function Animator.playSaber(character, comboIndex, onActive, onFinish)
	local state = states[character]
	if not state then
		Animator.setWeapon(character, character and character:FindFirstChildOfClass("Tool"))
		state = states[character]
	end
	if not state or state.Kind ~= "Saber" or paused(state) then
		if onFinish then onFinish(false) end
		return nil
	end
	finish(state, false)
	local cut = CUTS[((comboIndex - 1) % #CUTS) + 1]
	state.Action = { Kind = "Saber", Cut = cut, Elapsed = 0, Hold = 0, Fired = false,
		StartPose = state.LastPose, OnActive = onActive, OnFinish = onFinish }
	return cut.Name
end
function Animator.playMusket(character, phase)
	local state = states[character]
	if not state then
		Animator.setWeapon(character, character and character:FindFirstChildOfClass("Tool"))
		state = states[character]
	end
	if not state or state.Kind ~= "Musket" or paused(state) then return end
	finish(state, false)
	if phase == "kick" then
		state.Action = { Kind = "Musket", Elapsed = 0, Hold = 0 }
	end
end

return Animator
