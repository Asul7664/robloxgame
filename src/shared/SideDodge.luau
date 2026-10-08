-- Shared tuning. Motion is client-side; grants and IFrame are server-owned.
local Dodge = {
    DASH_SPEED = 72,
    DASH_TIME = 0.22,
    COOLDOWN = 0.55,
    IFRAME_TIME = 0.16,
    MAX_FORCE = 60000,
    EASE_POWER = 2, -- Quad; 4 uses Quart for a softer final tail.
    BRAKE_START = 0.5,
    LEFT_KEY = "Z", -- Q cancels fishing.
    RIGHT_KEY = "X", -- E interacts with NPCs and boats.
    WALL_CHECK = 2,
    FADE_IN = 0.035,
    FADE_OUT = 0.12,
    POSE_RECOVERY = 0.12, -- Smooth return after the built-in sidestep animation.
    WEIGHT_FADE_START = 0.65,
    REQUEST_TIMEOUT = 0.8,
    Animations = {
        Left = "rbxassetid://0", -- Built-in pose; optionally replace with your published sidestep.
        Right = "rbxassetid://0", -- Built-in pose; optionally replace with your published sidestep.
    },
}
function Dodge.EaseOut(t)
    -- Brief fast first half, then 1 - easeOut(Quad) during braking.
    -- The final velocity AND its slope reach zero. This keeps a short step
    -- at speed 72: integral .5 + .5/3 gives 10.56 studs at the defaults.
    local braking = math.clamp((t - Dodge.BRAKE_START) / (1 - Dodge.BRAKE_START), 0, 1)
    return (1 - braking) ^ Dodge.EASE_POWER
end
function Dodge.Direction(frame, side)
    if side ~= "Left" and side ~= "Right" then return nil end
    local v = frame.RightVector * (side == "Left" and -1 or 1)
    v = Vector3.new(v.X, 0, v.Z)
    return v.Magnitude > .001 and v.Unit or nil
end
function Dodge.Stunned(character, humanoid, now)
    for _, object in ipairs({character, humanoid}) do
        if object:GetAttribute("Stunned") == true or object:GetAttribute("Stun") == true then return true end
        local untilTime = object:GetAttribute("StunUntil")
        if type(untilTime) == "number" and untilTime > now then return true end
    end
    return false
end
return Dodge
