-- A short procedural sidestep over the ordinary character Animator.
-- Only visual joint Transforms change: movement, camera and physics are owned
-- by SideDodgeController. No animation assets, body-joint anchor edits, or
-- rig attachment edits. A Tool's native Weld grip uses its removable C0 view.
local RunService = game:GetService("RunService")
local DodgeAnimator = {}
DodgeAnimator.__index = DodgeAnimator

local DEFAULT_DURATION, DEFAULT_RECOVERY = .22, .12
local CONTROLLED = {
	"Root", "RootJoint", "Waist", "Neck", "RightHip", "LeftHip",
	"RightKnee", "LeftKnee", "RightAnkle", "LeftAnkle",
	"RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow",
	"RightWrist", "LeftWrist", "RightGrip",
}
local CARRY = {
	Root = true, RootJoint = true, Waist = true, Neck = true,
	RightShoulder = true, LeftShoulder = true, RightElbow = true, LeftElbow = true,
	RightWrist = true, LeftWrist = true, RightGrip = true,
}
local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
local function rotation(frame)
	return CFrame.new(frame.Position):Inverse() * frame
end
local function angles(value)
	return CFrame.Angles(0, math.rad(value.Y), 0)
		* CFrame.Angles(math.rad(value.X), 0, math.rad(value.Z))
end
local function vector(x, y, z) return Vector3.new(x, y, z) end
-- Load the outside foot, push once, then bring the trailing foot back under
-- the body as the physical sidestep slows. R6 moves whole legs at the hips;
-- its nonexistent knees are never approximated by bending a solid block.
local KEYS = {
	{Time = 0, Dip = 0, Lean = 0, Pitch = 0,
		Lead = vector(0, 0, 0), Trail = vector(0, 0, 0), Knee = 0, TrailKnee = 0, Ankle = 0, TrailAnkle = 0},
	{Time = .18, Dip = -.065, Lean = 7, Pitch = -3,
		Lead = vector(10, -3, 15), Trail = vector(-5, 3, 2), Knee = -15, TrailKnee = -9, Ankle = 8, TrailAnkle = 14},
	{Time = .43, Dip = -.13, Lean = 14, Pitch = -5,
		Lead = vector(22, -7, 28), Trail = vector(-12, 5, 4), Knee = -32, TrailKnee = -20, Ankle = 15, TrailAnkle = 28},
	{Time = .74, Dip = -.075, Lean = 9, Pitch = -3,
		Lead = vector(12, -4, 19), Trail = vector(2, 2, 9), Knee = -18, TrailKnee = -11, Ankle = 9, TrailAnkle = 13},
	{Time = 1, Dip = -.025, Lean = 4, Pitch = -1,
		Lead = vector(5, -1, 9), Trail = vector(0, 1, 4), Knee = -7, TrailKnee = -4, Ankle = 4, TrailAnkle = 5},
}
local VALUES = {"Dip", "Lean", "Pitch", "Lead", "Trail", "Knee", "TrailKnee", "Ankle", "TrailAnkle"}
local function interpolate(a, b, t)
	local result = {}
	for _, key in ipairs(VALUES) do
		local first, second = a[key], b[key]
		result[key] = type(first) == "number" and first + (second - first) * t or first:Lerp(second, t)
	end
	return result
end
-- Shared, monotone cubic tangents keep velocity continuous through the load,
-- push and braking waypoints. Only the entry/exit have zero tangents; applying
-- a separate smoothstep to every segment would briefly stop every 40-60 ms.
local TANGENTS = {}
local function tangent(index, key)
	local value = KEYS[index][key]
	if index == 1 or index == #KEYS then return value * 0 end
	local previous, following = KEYS[index - 1], KEYS[index + 1]
	local before, after = KEYS[index].Time - previous.Time, following.Time - KEYS[index].Time
	local function component(a, b, c)
		local first, second = (b - a) / before, (c - b) / after
		if first * second <= 0 then return 0 end
		local w1, w2 = 2 * after + before, after + 2 * before
		return (w1 + w2) / (w1 / first + w2 / second)
	end
	if type(value) == "number" then return component(previous[key], value, following[key]) end
	return vector(component(previous[key].X, value.X, following[key].X),
		component(previous[key].Y, value.Y, following[key].Y),
		component(previous[key].Z, value.Z, following[key].Z))
end
for index = 1, #KEYS do
	TANGENTS[index] = {}
	for _, key in ipairs(VALUES) do TANGENTS[index][key] = tangent(index, key) end
end
local function sample(phase)
	phase = math.clamp(phase, 0, 1)
	for index = 2, #KEYS do
		local first, second = KEYS[index - 1], KEYS[index]
		if phase <= second.Time then
			local length = second.Time - first.Time
			local t = (phase - first.Time) / length
			local t2, t3 = t * t, t * t * t
			local result = {}
			for _, key in ipairs(VALUES) do
				result[key] = first[key] * (2 * t3 - 3 * t2 + 1)
					+ TANGENTS[index - 1][key] * length * (t3 - 2 * t2 + t)
					+ second[key] * (-2 * t3 + 3 * t2)
					+ TANGENTS[index][key] * length * (t3 - t2)
			end
			return result
		end
	end
	return interpolate(KEYS[#KEYS], KEYS[#KEYS], 0)
end
local function mirrored(value, sign)
	return vector(value.X, value.Y * sign, value.Z * sign)
end
local function jointName(part, fallback)
	local names = {LowerTorso = "Root", UpperTorso = "Waist", Torso = "RootJoint", Head = "Neck"}
	if names[part.Name] then return names[part.Name] end
	for _, side in ipairs({"Right", "Left"}) do
		if part.Name == side .. " Arm" then return side .. "Shoulder" end
		if part.Name == side .. " Leg" then return side .. "Hip" end
		for body, name in pairs({UpperArm = "Shoulder", LowerArm = "Elbow", Hand = "Wrist",
			UpperLeg = "Hip", LowerLeg = "Knee", Foot = "Ankle"}) do
			if part.Name == side .. body then return side .. name end
		end
	end
	return fallback
end
local function constraintView(joint)
	local a, b = joint.Attachment0, joint.Attachment1
	if not a or not b or not a.Parent or not b.Parent or joint.Enabled == false
		or not a.Parent:IsA("BasePart") or not b.Parent:IsA("BasePart") then return nil end
	return setmetatable({Source = joint, IsConstraint = true}, {
		__index = function(_, key)
			if key == "Part0" then return a.Parent elseif key == "Part1" then return b.Parent
			elseif key == "C0" then return a.CFrame elseif key == "C1" then return b.CFrame end
			return joint[key]
		end,
		__newindex = function(_, key, value)
			if key == "Transform" then joint.Transform = value else error("Dodge adapter writes only Transform") end
		end,
	})
end
local function gripView(joint)
	if not joint:IsA("Weld") then return joint end
	-- A Weld has no Transform. This base is the currently visible weapon grip,
	-- captured before WeaponAnimator removes its own overlay at PreAnimation.
	local seed = joint.C0
	return setmetatable({Source = joint, IsWeld = true}, {
		__index = function(_, key)
			if key == "Transform" then return seed:Inverse() * joint.C0 elseif key == "C0" then return seed end
			return joint[key]
		end,
		__newindex = function(_, key, value)
			if key == "Transform" then joint.C0 = seed * value else error("Dodge grip adapter writes only Transform") end
		end,
	})
end
local function alive(joint) return joint and joint.Parent ~= nil end
local function restore(state)
	for joint, base in pairs(state.Applied) do
		if alive(joint) then joint.Transform = base end
	end
	state.Applied = {}
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
local function converted(state, joint, frame)
	-- Parent/attachment axes differ between native R6 motors and R15 rigs.
	-- Convert from the fixed character axes so left/right do not change with
	-- the camera, a weapon's sideways stance, or a rotated attachment.
	local parent = worldFrame(state, joint.Part0, {})
	local axes = state.FixedRotation:Inverse() * rotation(parent) * rotation(joint.C0)
	return axes:Inverse() * frame * axes
end
local function carried(state)
	return state.Tool and state.Tool.Parent == state.Character
end
local function deltas(state, current)
	local sign = state.Sign
	local lead = sign > 0 and "Right" or "Left"
	local trail = sign > 0 and "Left" or "Right"
	local rootShare = state.R15 and .65 or 1
	local result = {}
	result[state.R15 and "Root" or "RootJoint"] = CFrame.new(0, current.Dip * (state.R15 and 1.20 or 1), 0)
		* angles(vector(current.Pitch * rootShare, 0, -current.Lean * sign * rootShare))
	if state.R15 then
		result.Waist = angles(vector(current.Pitch * .35, 0, -current.Lean * sign * .35))
	end
	result.Neck = angles(vector(-current.Pitch * .35, 0, current.Lean * sign * .65))
	result[lead .. "Hip"] = angles(mirrored(current.Lead, sign))
	result[trail .. "Hip"] = angles(mirrored(current.Trail, sign))
	result[lead .. "Knee"] = angles(vector(current.Knee, 0, 0))
	result[trail .. "Knee"] = angles(vector(current.TrailKnee, 0, 0))
	result[lead .. "Ankle"] = angles(vector(current.Ankle, 0, 0))
	result[trail .. "Ankle"] = angles(vector(current.TrailAnkle, 0, 0))
	if not carried(state) then
		local load = current.Lean / 14
		result[lead .. "Shoulder"] = angles(vector(18 * load, 0, sign * 22 * load))
		result[trail .. "Shoulder"] = angles(vector(-7 * load, 0, sign * 4 * load))
		result[lead .. "Elbow"] = angles(vector(18 * load, 0, 0))
		result[trail .. "Elbow"] = angles(vector(26 * load, 0, 0))
	else
		-- Both carried arms/wrists and the actual grip retain their complete
		-- visible pose. The shared torso lean deflects the weapon modestly while
		-- keeping a musket's support hand in contact with its forestock.
		for _, name in ipairs({"RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow",
			"RightWrist", "LeftWrist", "RightGrip"}) do result[name] = CFrame.new() end
	end
	return result
end

function DodgeAnimator.new()
	return setmetatable({}, DodgeAnimator)
end
function DodgeAnimator:IsPlaying() return self.State ~= nil end
function DodgeAnimator:Cancel()
	local state = self.State
	if not state then return end
	self.State = nil
	for _, connection in ipairs(state.Connections) do connection:Disconnect() end
	-- Always restore the latest unoverlaid walking/idle frame. An entry-time
	-- snapshot would freeze a stale walk pose after death, interruption or stop.
	restore(state)
	for _, entry in ipairs(state.Constraints) do
		if entry.Owned and entry.Joint.Parent then entry.Joint.IsKinematic = entry.Previous end
	end
	state.Character:SetAttribute("LocalDodgePoseActive", false)
end
function DodgeAnimator:Release()
	local state = self.State
	if not state then return false end
	if state.ReleasedAt then return true end
	state.ReleasedAt = os.clock()
	state.ReleasePose = state.LastPose or sample((state.ReleasedAt - state.Started) / state.Duration)
	state.ReleaseFrames = table.clone(state.Outputs)
	return true
end
function DodgeAnimator:_step(state)
	if self.State ~= state then return end
	if not state.Character.Parent or not state.Root.Parent or (state.Humanoid and state.Humanoid.Health <= 0) then
		self:Cancel(); return
	end
	if not state.SawPreAnimation then return end
	if not state.Claimed then
		state.Claimed = true
		-- WeaponAnimator releases ownership in PreAnimation while the pose flag
		-- is true, before any PreSimulation callback can claim it. Capture only
		-- now, never during Play, regardless of callback registration order.
		for _, entry in ipairs(state.Constraints) do
			if entry.Joint.Parent then
				entry.Previous = entry.Joint.IsKinematic
				entry.Joint.IsKinematic = true
				entry.Owned = true
			end
		end
	end
	local elapsed = math.max(0, os.clock() - state.Started)
	if not state.ReleasedAt and elapsed >= state.Duration then self:Release() end
	local recovery = state.ReleasedAt and smooth((os.clock() - state.ReleasedAt) / state.Recovery) or 0
	local current = state.ReleasedAt and interpolate(state.ReleasePose, KEYS[1], recovery)
		or sample(elapsed / state.Duration)
	state.LastPose = current
	local pose = deltas(state, current)
	for _, name in ipairs(CONTROLLED) do
		local joint = state.Joints[name]
		if alive(joint) then
			local base = joint.Transform
			state.Applied[joint] = base
			local seed = state.Entry[joint]
			local delta = converted(state, joint, pose[name] or CFrame.new())
			local target
			if carried(state) and CARRY[name] then
				target = delta * seed
			elseif state.ReleasedAt then
				target = (state.ReleaseFrames[joint] or seed):Lerp(base, recovery)
			elseif name:find("Hip") or name:find("Knee") or name:find("Ankle") then
				-- Take leg motion over from the captured stride in the first 40 ms.
				target = seed:Lerp(delta, smooth(elapsed / (state.Duration * .18)))
			else
				target = delta * seed
			end
			joint.Transform = target
			state.Outputs[joint] = target
		end
	end
	if state.ReleasedAt and os.clock() - state.ReleasedAt >= state.Recovery then
		-- On the following PreAnimation, restore and clear the flag BEFORE the
		-- normal Animator/weapon overlay run. There is no one-frame dropped gun.
		state.Finishing = true
	end
end
function DodgeAnimator:Play(character, side, duration, recovery)
	if self.State or (side ~= "Left" and side ~= "Right") or not character or not character.Parent then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or (humanoid and humanoid.Health <= 0) then return false end
	local tool = character:FindFirstChildOfClass("Tool")
	local kind = tool and tool:GetAttribute("WeaponType")
	if kind ~= "Saber" and kind ~= "Musket" then tool = nil end
	local state = {
		Character = character, Root = root, Humanoid = humanoid, Tool = tool,
		Sign = side == "Right" and 1 or -1, R15 = character:FindFirstChild("RightUpperArm") ~= nil,
		Duration = math.clamp(type(duration) == "number" and duration or DEFAULT_DURATION, .08, .5),
		Recovery = math.clamp(type(recovery) == "number" and recovery or DEFAULT_RECOVERY, .04, .25),
		Started = os.clock(), FixedRotation = rotation(root.CFrame), Joints = {}, ByPart = {},
		Entry = {}, Applied = {}, Outputs = {}, Constraints = {}, Connections = {},
	}
	local descendants = character:GetDescendants()
	for _, joint in ipairs(descendants) do
		if (joint:IsA("Motor6D") or joint.Name == "RightGrip" and joint:IsA("Weld")) and joint.Part0 and joint.Part1 then
			local name = joint.Name == "RightGrip" and "RightGrip" or jointName(joint.Part1, joint.Name:gsub(" ", ""))
			local view = name == "RightGrip" and gripView(joint) or joint
			state.Joints[name], state.ByPart[joint.Part1] = view, view
		end
	end
	for _, joint in ipairs(descendants) do
		if joint:IsA("AnimationConstraint") then
			local view = constraintView(joint)
			if view then
				local name = jointName(view.Part1, joint.Name:gsub(" ", ""))
				state.Joints[name], state.ByPart[view.Part1] = view, view
			end
		end
	end
	local count = 0
	for _, name in ipairs(CONTROLLED) do
		local joint = state.Joints[name]
		if joint then
			count += 1
			state.Entry[joint] = joint.Transform
			if type(joint) == "table" and rawget(joint, "IsConstraint") then
				table.insert(state.Constraints, {Joint = rawget(joint, "Source")})
			end
		end
	end
	if count == 0 then return false end
	self.State = state
	character:SetAttribute("LocalDodgePoseActive", true)
	table.insert(state.Connections, RunService.PreAnimation:Connect(function()
		if self.State ~= state then return end
		state.SawPreAnimation = true
		restore(state)
		if state.Finishing then self:Cancel() end
	end))
	table.insert(state.Connections, RunService.PreSimulation:Connect(function() self:_step(state) end))
	if humanoid then
		table.insert(state.Connections, humanoid.Died:Connect(function() self:Cancel() end))
	end
	table.insert(state.Connections, character.AncestryChanged:Connect(function()
		if not character.Parent then self:Cancel() end
	end))
	-- Roblox removes the old equipped Tool before parenting its replacement.
	-- End the visual overlay on either change so a new weapon never inherits
	-- the old weapon's carry seed or an interrupted crouch/stride.
	local function toolChanged(child)
		if child:IsA("Tool") then self:Cancel() end
	end
	table.insert(state.Connections, character.ChildRemoved:Connect(toolChanged))
	table.insert(state.Connections, character.ChildAdded:Connect(toolChanged))
	return true
end
function DodgeAnimator:Destroy() self:Cancel() end

return DodgeAnimator
