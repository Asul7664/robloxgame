-- Pure logic, separately testable. No reward or motion values are trusted from clients.
local Rules={}
local function finite(x)return type(x)=="number" and x==x and x>-math.huge and x<math.huge end
function Rules.Input(value)
    if type(value)~="table" or not finite(value.Throttle) or not finite(value.Steer) then return nil end
    return math.max(-1,math.min(1,value.Throttle)),math.max(-1,math.min(1,value.Steer))
end
function Rules.CanBuy(config,data,id)
    if type(id)~="string" or #id>32 then return false,"Unknown boat." end
    local def=config.BoatById[id]
    if not data or not def then return false,"This boat is unavailable." end
    if data.OwnedBoats and data.OwnedBoats[id]then return false,"You already own this boat." end
    if not data.TestMode and config.Level(data.XP)<def.Level then return false,"Requires level "..def.Level.."." end
    if not data.TestMode and data.Coins<def.Price then return false,"You need "..(def.Price-data.Coins).." more coins." end
    return true
end
function Rules.Step(speed,yaw,throttle,steer,dt,def)
    dt=math.max(0,math.min(0.1,dt))
    local target=throttle*def.Speed*(throttle<0 and 0.4 or 1)
    local delta=math.max(-def.Acceleration*dt,math.min(def.Acceleration*dt,target-speed))
    speed=speed+delta
    local response=math.max(0.22,math.min(1,math.abs(speed)/def.Speed))
    yaw=yaw-steer*def.Turn*response*dt*(speed<-0.5 and -1 or 1)
    yaw=(yaw+math.pi)%(math.pi*2)-math.pi
    return speed,yaw
end
return Rules
