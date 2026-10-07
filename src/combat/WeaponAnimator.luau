local RunService = game:GetService("RunService")
local Animator = {}

local function curve(t)
	if t < 0.34 then
		local u = t / 0.34
		return 0.18 * (u * u)
	elseif t < 0.52 then
		local u = (t - 0.34) / 0.18
		return 0.18 + 0.72 * (1 - (1 - u) * (1 - u))
	else
		local u = (t - 0.52) / 0.48
		return 0.9 + 0.1 * (1 - (1 - u) * (1 - u) * (1 - u))
	end
end

local function motor(character, name)
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") and d.Name == name then
			return d
		end
	end
end

local POSES = {
	Saber = {
		{
			name = "Режущий слева",
			wind = { shoulder = Vector3.new(-40, 55, 18), elbow = 28, waist = 22, grip = CFrame.Angles(math.rad(-30), math.rad(70), math.rad(10)) },
			hit = { shoulder = Vector3.new(18, -70, -28), elbow = 8, waist = -26, grip = CFrame.Angles(math.rad(20), math.rad(-80), math.rad(-16)) },
			endPose = { shoulder = Vector3.new(6, -20, -8), elbow = 14, waist = -6, grip = CFrame.new() },
		},
		{
			name = "Восходящий",
			wind = { shoulder = Vector3.new(35, -20, 24), elbow = 40, waist = -14, grip = CFrame.Angles(math.rad(40), math.rad(-20), 0) },
			hit = { shoulder = Vector3.new(-55, 30, -10), elbow = 6, waist = 16, grip = CFrame.Angles(math.rad(-55), math.rad(35), math.rad(12)) },
			endPose = { shoulder = Vector3.new(-8, 8, 0), elbow = 16, waist = 4, grip = CFrame.new() },
		},
		{
			name = "Рубящий сверху",
			wind = { shoulder = Vector3.new(-78, 10, 8), elbow = 18, waist = 8, grip = CFrame.Angles(math.rad(-80), 0, 0) * CFrame.new(0, 0.2, 0) },
			hit = { shoulder = Vector3.new(28, -6, -6), elbow = 10, waist = -4, grip = CFrame.Angles(math.rad(35), math.rad(-8), 0) },
			endPose = { shoulder = Vector3.new(4, 0, 0), elbow = 12, waist = 0, grip = CFrame.new() },
		},
	},
	Musket = {
		idle = { shoulder = Vector3.new(18, -8, -6), elbow = 22, waist = 4, grip = CFrame.Angles(math.rad(-8), math.rad(6), 0) },
		aim = { shoulder = Vector3.new(-8, 6, -14), elbow = 8, waist = 10, grip = CFrame.Angles(math.rad(-4), 0, 0) },
		kick = { shoulder = Vector3.new(26, -18, 10), elbow = 30, waist = -8, grip = CFrame.Angles(math.rad(28), math.rad(-12), math.rad(6)) * CFrame.new(0, 0.15, 0.35) },
	},
}

local active = {}

local function apply(character, pose, alpha, baseGrip)
	local shoulder = motor(character, "RightShoulder") or motor(character, "Right Shoulder")
	local elbow = motor(character, "RightElbow") or motor(character, "Right Elbow")
	local waist = motor(character, "Waist") or motor(character, "RootJoint")
	local grip = motor(character, "RightGrip")
	if shoulder then
		shoulder.Transform = CFrame.Angles(math.rad(pose.shoulder.X * alpha), math.rad(pose.shoulder.Y * alpha), math.rad(pose.shoulder.Z * alpha))
	end
	if elbow then
		elbow.Transform = CFrame.Angles(math.rad(pose.elbow * alpha), 0, 0)
	end
	if waist then
		waist.Transform = waist.Transform * CFrame.Angles(0, math.rad(pose.waist * alpha * 0.65), 0)
	end
	if grip and baseGrip then
		grip.C0 = baseGrip * pose.grip:Lerp(CFrame.new(), 1 - alpha)
	end
end

local function blend(a, b, t)
	return {
		shoulder = a.shoulder:Lerp(b.shoulder, t),
		elbow = a.elbow + (b.elbow - a.elbow) * t,
		waist = a.waist + (b.waist - a.waist) * t,
		grip = a.grip:Lerp(b.grip, t),
	}
end

function Animator.playSaber(character, comboIndex, onActive)
	local set = POSES.Saber[((comboIndex - 1) % #POSES.Saber) + 1]
	local grip = motor(character, "RightGrip")
	local baseGrip = grip and grip.C0 or CFrame.new()
	local token = {}
	active[character] = token
	local started = os.clock()
	local length = 0.58
	local fired = false
	local hold = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if active[character] ~= token or not character.Parent then
			conn:Disconnect()
			return
		end
		if hold > 0 then
			hold -= dt
			return
		end
		local t = math.clamp((os.clock() - started) / length, 0, 1)
		local shaped = curve(t)
		local pose = shaped < 0.42 and blend(set.wind, set.hit, shaped / 0.42) or blend(set.hit, set.endPose, (shaped - 0.42) / 0.58)
		apply(character, pose, 1, baseGrip)
		if not fired and t >= 0.36 then
			fired = true
			if onActive then
				onActive(function(didHit)
					if didHit then
						hold = 0.055
					end
				end)
			end
		end
		if t >= 1 then
			conn:Disconnect()
			if active[character] == token then
				active[character] = nil
			end
			if grip then
				grip.C0 = baseGrip
			end
		end
	end)
	return set.name
end

function Animator.playMusket(character, phase)
	local pose = POSES.Musket[phase]
	if not pose then
		return
	end
	local grip = motor(character, "RightGrip")
	local baseGrip = grip and grip.C0 or CFrame.new()
	local token = {}
	active[character] = token
	local started = os.clock()
	local length = phase == "kick" and 0.28 or 0.18
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if active[character] ~= token or not character.Parent then
			conn:Disconnect()
			return
		end
		local t = math.clamp((os.clock() - started) / length, 0, 1)
		local alpha = phase == "kick" and (1 - t) * (1 - t) or t
		apply(character, pose, math.clamp(alpha + 0.35, 0, 1), baseGrip)
		if t >= 1 then
			conn:Disconnect()
			if active[character] == token then
				active[character] = nil
			end
			if grip and phase == "kick" then
				grip.C0 = baseGrip
			end
		end
	end)
end

return Animator
