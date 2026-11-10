-- Pure Lua/Luau: server-authoritative reeling simulation, independently testable.
local Reel = {}
local function clamp(x, lo, hi) return math.max(lo, math.min(hi, x)) end

local Profiles = {
    lazy =     {Amp1 = 0.16, Amp2 = 0.04, Speed1 = 0.44, Speed2 = 1.00, Jitter = 0.01, Pull = 1.16, Slip = 0.84},
    wobble =   {Amp1 = 0.22, Amp2 = 0.08, Speed1 = 0.70, Speed2 = 1.55, Jitter = 0.02, Pull = 1.06, Slip = 0.96},
    drift =    {Amp1 = 0.24, Amp2 = 0.08, Speed1 = 0.72, Speed2 = 1.75, Jitter = 0.025, Pull = 1.00, Slip = 1.00},
    spiral =   {Amp1 = 0.26, Amp2 = 0.10, Speed1 = 0.90, Speed2 = 2.10, Jitter = 0.03, Pull = 0.98, Slip = 1.05},
    zigzag =   {Amp1 = 0.29, Amp2 = 0.10, Speed1 = 1.15, Speed2 = 2.50, Jitter = 0.04, Pull = 0.94, Slip = 1.12},
    pulse =    {Amp1 = 0.22, Amp2 = 0.13, Speed1 = 1.10, Speed2 = 2.80, Jitter = 0.03, Pull = 0.97, Slip = 1.08, Pulse = 0.08},
    phantom =  {Amp1 = 0.25, Amp2 = 0.12, Speed1 = 1.25, Speed2 = 2.90, Jitter = 0.035, Pull = 0.90, Slip = 1.16, Snap = 0.08},
    dart =     {Amp1 = 0.27, Amp2 = 0.12, Speed1 = 1.45, Speed2 = 3.35, Jitter = 0.04, Pull = 0.89, Slip = 1.20, Snap = 0.12},
    berserk =  {Amp1 = 0.31, Amp2 = 0.14, Speed1 = 1.75, Speed2 = 3.90, Jitter = 0.06, Pull = 0.82, Slip = 1.34, Pulse = 0.11, Snap = 0.12},
    ballet =   {Amp1=0.27,Amp2=0.10,Speed1=0.94,Speed2=2.20,Jitter=0.015,Pull=0.98,Slip=1.08},
    verity =   {Amp1=0.32,Amp2=0.13,Speed1=1.65,Speed2=3.6,Jitter=0.04,Pull=0.82,Slip=1.35,Pulse=0.09,Snap=0.10},
    boss =     {Amp1 = 0.33, Amp2 = 0.16, Speed1 = 1.95, Speed2 = 4.30, Jitter = 0.07, Pull = 0.78, Slip = 1.42, Pulse = 0.12, Snap = 0.16},
}

function Reel.new(difficulty, width, resilience, phase, pattern, tuning, seed)
    return {t = 0, bar = 0.5, velocity = 0, fish = 0.5, progress = 0.34,
        width = width, difficulty = difficulty, resilience = resilience,
        phase = phase, inside = true, pattern = Profiles[pattern] or Profiles.drift,
        tuning = tuning or {}, outsideSeconds = 0, patternName=pattern,
        randomState=(math.floor(seed or (phase*100003+1)) % 2147483646)+1,
        phraseStart=0,phraseEnd=pattern=='ballet' and 0.65 or (pattern=='verity' and 0.55 or 1.6),phraseFrom=0.5,phraseTo=0.5,mode="drift",cue=""}
end

-- A seed is chosen by the SERVER once per hook. Timing does not depend on input or framerate.
local function random(s)
    s.randomState=(s.randomState*16807)%2147483647
    return (s.randomState-1)/2147483646
end
local function smooth(x) x=clamp(x,0,1);return x*x*x*(x*(x*6-15)+10) end
local function phrase(s,clockTime)
    while clockTime>=s.phraseEnd do
        s.phraseStart=s.phraseEnd;s.phraseFrom=s.phraseTo
        local pick=random(s)
        if s.patternName=='ballet' then
            s.mode=pick<0.20 and 'feint' or (pick<0.34 and 'pause' or 'drift')
            s.phraseTo=s.mode=='pause' and clamp(s.phraseFrom+(random(s)-0.5)*0.08,0.16,0.84)
                or 0.18+random(s)*0.64
            s.phraseEnd=s.phraseStart+(s.mode=='feint' and (0.56+random(s)*0.18)
                or (s.mode=='pause' and (0.45+random(s)*0.35) or (1.35+random(s)*0.90)))
        else
            s.mode=pick<0.36 and 'feint' or 'drift'
            s.phraseTo=0.10+random(s)*0.80
            s.phraseEnd=s.phraseStart+(s.mode=='feint' and (0.58+random(s)*0.20)or (0.95+random(s)*0.8))
        end
    end
    local age=clockTime-s.phraseStart
    local duration=s.phraseEnd-s.phraseStart
    if s.mode=='feint' then
        -- Brief readable anticipation, then a short glide; never teleports.
        local anticipation=s.patternName=='ballet' and 0.18 or 0.14
        s.cue=age<anticipation and 'FEINT!' or 'DART'
        if age<anticipation then return s.phraseFrom+(s.phraseFrom-s.phraseTo)*0.07*smooth(age/anticipation) end
        local from=s.phraseFrom+(s.phraseFrom-s.phraseTo)*0.07
        return from+(s.phraseTo-from)*smooth((age-anticipation)/(duration-anticipation))
    end
    s.cue=s.mode=='pause' and 'PAUSE' or ''
    return s.phraseFrom+(s.phraseTo-s.phraseFrom)*smooth(age/duration)
end

function Reel.step(s, held, dt)
    dt = clamp(dt, 0, 1 / 20)
    s.t = s.t + dt
    local d = s.difficulty
    local p = s.pattern
    local tuning = s.tuning
    local motionTime = s.t * (tuning.MotionSpeed or 1)
    local jerkScale = tuning.JerkScale or 1
    local blend = math.min(s.t / 1.3, 1)
    local motion = p.Amp1 * math.sin(motionTime * (p.Speed1 + d * 0.85) + s.phase)
        + p.Amp2 * math.sin(motionTime * (p.Speed2 + d * 1.95) + s.phase * 1.7)
        + jerkScale * p.Jitter * math.sin(motionTime * (5.0 + d * 5.5) + s.phase * 2.3)
    if p.Pulse then
        motion = motion + jerkScale * p.Pulse * math.sin(motionTime * (2.4 + d * 2.8)) * math.sin(motionTime * (6.0 + d * 5.0) + s.phase)
    end
    if p.Snap then
        motion = motion + jerkScale * p.Snap * math.max(0, math.sin(motionTime * (1.4 + d * 3.4) + s.phase))^5 * math.sin(motionTime * (8.5 + d * 2.0))
    end
    local targetFish = clamp(0.5 + blend * motion, 0.07, 0.93)
    if s.patternName=='ballet' or s.patternName=='verity' then
        local choreo=phrase(s,motionTime)
        local blendWeight=s.patternName=='ballet' and 0.52 or 0.38
        targetFish=clamp(targetFish*(1-blendWeight)+(0.5+blend*(choreo-0.5))*blendWeight,0.07,0.93)
    end
    if tuning.SpeedLimitBase then
        local maxSpeed = tuning.SpeedLimit or (tuning.SpeedLimitBase + d * (tuning.SpeedLimitPerDifficulty or 0))
        s.fish = s.fish + clamp(targetFish - s.fish, -maxSpeed * dt, maxSpeed * dt)
    else
        s.fish = targetFish
    end

    local acceleration = held and 2.25 or -2.25
    s.velocity = clamp(s.velocity + (acceleration - s.velocity * 4.3) * dt, -0.6, 0.6)
    local edge = s.width / 2
    s.bar = s.bar + s.velocity * dt
    if s.bar < edge then s.bar = edge; s.velocity = math.abs(s.velocity) * 0.12 end
    if s.bar > 1 - edge then s.bar = 1 - edge; s.velocity = -math.abs(s.velocity) * 0.12 end

    s.inside = math.abs(s.bar - s.fish) <= edge
    local gain = (0.19 * p.Pull - d * 0.06) * (tuning.GainScale or 1)
    local loss = (0.11 * p.Slip + d * 0.07) / s.resilience * (tuning.LossScale or 1)
    -- A brief excursion is forgivable; time spent inside never causes decay.
    if s.inside then s.outsideSeconds = 0 else s.outsideSeconds = s.outsideSeconds + dt end
    local rate = s.inside and gain or 0
    if not s.inside and s.outsideSeconds > (tuning.GraceSeconds or 0) then rate = -loss end
    s.progress = clamp(s.progress + rate * dt, 0, 1)
    if s.progress >= 1 then return "caught" end
    if s.progress <= 0 then return "lost" end
    return "running"
end

return Reel
