-- Short successful-catch presentation, never a fishing timeout.
local M={}
local function smooth(t)t=math.max(0,math.min(1,t));return t*t*t*(t*(t*6-15)+10)end
function M.Position(origin,destination,t,rarity)
    t=math.max(0,math.min(1,t))
    local rise=Vector3.new(origin.X,origin.Y+3.5+rarity*.12,origin.Z)
    if t<.20 then return origin+(rise-origin)*smooth(t/.20)end
    if t<.73 then
        local u=smooth((t-.20)/.53)
        return rise+(destination-rise)*u+Vector3.new(0,math.sin(math.pi*u)*(2.1+rarity*.18),0)
    end
    local age=(t-.73)/.27
    return destination+Vector3.new(0,math.sin(age*math.pi)*.12,0)
end
function M.Fade(t)return smooth((t-.94)/.06)end
return M
