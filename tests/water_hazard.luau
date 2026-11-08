-- Actual water-hazard service and server damage; real Roblox CFrames and
-- service doubles. This does not simulate Studio terrain, swimming or rendering.
local Environment=require('./helpers/combat_environment')
local R=require('@lune/roblox')
local V,CF=R.Vector3,R.CFrame
local checks=0
local function check(ok,message)checks+=1;assert(ok,message)end
local SETTINGS={Enabled=true,Seconds=30,WarningSeconds=10,CheckInterval=.1,
    GroundTolerance=.65,EffectSeconds=1.3,SurfaceY=0}
local function fixture()
    local env=Environment.new();env.Services.Workspace=env.World
    local shared=env:Node('Folder','QuietCove',env.Replicated)
    local server=env:Node('Folder','QuietCove')
    env:Node('ModuleScript','SharkVisual',server)
    local oldScript=env.Globals.script
    env.Globals.script={Parent=server}
    local damage=env:Execute('src/combat/Damage.luau')
    local notices,visuals={},{}
    local visual={Create=function(parent,frame)
        if env.FailVisual then error('Simulated missing visual') end
        local model=env:Node('Model','Shark',parent);model.Frame=frame
        model.PivotTo=function(self,nextFrame)self.Frame=nextFrame end
        model.GetPivot=function(self)return self.Frame end
        table.insert(visuals,model);return model
    end}
    env.Globals.require=function(module)
        if module.Name=='Damage' then return damage end
        if module.Name=='SharkVisual' then return visual end
        error('Unexpected hazard dependency '..tostring(module.Name))
    end
    local Service=env:Execute('src/server/WaterHazardService.luau')
    env.Globals.script=oldScript
    local service=Service.new(table.clone(SETTINGS),function(player,message)
        table.insert(notices,{Player=player,Message=message})
    end)
    local player=env:AddPlayer(1,true)
    local function swim(p)
        local h=p.Character.Humanoid;h.State=env.Enum.HumanoidStateType.Swimming
        h.FloorMaterial=env.Enum.Material.Air;h.HipHeight=0;h.RigType=env.Enum.HumanoidRigType.R6
        local root=p.Character.HumanoidRootPart;root.Size=V.new(2,2,1);root.CFrame=CF.new(0,.5,0)
        p.Character['Left Leg'].Size=V.new(1,2,1);p.Character['Right Leg'].Size=V.new(1,2,1)
    end
    swim(player)
    local f={Env=env,Service=service,Player=player,Notices=notices,Visuals=visuals,Damage=damage,Swim=swim}
    function f:Step(at)self.Env.Time=100+at;self.Service:Step(self.Env.Time)end
    return f
end

do
    local f=fixture();local h=f.Player.Character.Humanoid
    f:Step(0);f:Step(19.9)
    check(h.Health==100 and #f.Visuals==0,'Swimming below threshold is safe')
    f:Step(20)
    check(#f.Notices==1,'Warn once with ten seconds left')
    f:Step(25);f:Step(29.9)
    check(#f.Notices==1 and h.Health==100,'Warning is not spammed and 29.9 seconds cannot kill')
    f.Player.Character:SetAttribute('IFrame',true)
    f.Player.Character:SetAttribute('Dodging',true)
    f.Env:Node('ForceField','ForceField',f.Player.Character)
    f:Step(30)
    check(h.Health==0,'Server shark instantly kills at thirty seconds despite PvP i-frame')
    check(#f.Visuals==1,'One shark appears for the fatal water episode')
    f:Step(30.2);f:Step(31);f:Step(32)
    check(#f.Visuals==1,'Dead character never spawns repeat sharks')
    check(f.Visuals[1].Destroyed,'Transient shark is cleaned up')
    f.Service:Destroy()
    check(next(f.Service.States)==nil,'Destroy clears timers')
end

do
    local f=fixture();f.Env.FailVisual=true
    f:Step(0);f:Step(30)
    check(f.Player.Character.Humanoid.Health==0,'Cosmetic shark creation failure cannot cancel server death')
end

do
    local f=fixture();f.Player.Character.Humanoid.Sit=true
    f:Step(0);f:Step(30)
    check(f.Player.Character.Humanoid.Health==0,'Sit flag alone cannot impersonate a real boat seat')
end

do
    local f=fixture();local h=f.Player.Character.Humanoid
    f:Step(0);f:Step(29)
    h.SeatPart=f.Env:Node('VehicleSeat','PilotSeat',f.Env.World)
    f:Step(29.2)
    check(f.Service.States[f.Player]==nil,'Actual boat seat resets the episode')
    h.SeatPart=nil;f:Step(30);f:Step(59.9)
    check(h.Health==100,'Leaving boat starts a fresh thirty seconds')
    f:Step(60);check(h.Health==0,'Fresh timer still expires after returning to water')
end

do
    local f=fixture();local h=f.Player.Character.Humanoid
    f:Step(0);f:Step(29)
    h.State=f.Env.Enum.HumanoidStateType.Running;h.FloorMaterial=f.Env.Enum.Material.WoodPlanks
    f:Step(29.2)
    check(f.Service.States[f.Player]==nil,'Standing on a dry boat deck or dock resets timer')
    f.Swim(f.Player);f:Step(30);f:Step(59.9)
    check(h.Health==100,'Dry support grants a fresh episode, not an old overdue attack')
end

do
    local f=fixture();local h=f.Player.Character.Humanoid
    f:Step(0);f:Step(29)
    h.State=f.Env.Enum.HumanoidStateType.Freefall;h.FloorMaterial=f.Env.Enum.Material.Air
    f.Player.Character.HumanoidRootPart.CFrame=CF.new(0,9,0)
    f:Step(29.2);f:Step(30.2)
    check(h.Health==100 and f.Service.States[f.Player]~=nil,'Water hop retains episode but does not bite airborne player')
    f.Swim(f.Player);f:Step(30.4)
    check(h.Health==0,'Water hop cannot evade timer; re-entry triggers overdue shark')
end

do
    local f=fixture();local h=f.Player.Character.Humanoid
    f:Step(0);f:Step(29)
    h.State=f.Env.Enum.HumanoidStateType.Freefall;f:Step(29.2)
    h.State=f.Env.Enum.HumanoidStateType.Running;h.FloorMaterial=f.Env.Enum.Material.Grass
    f:Step(30.2)
    check(h.Health==100 and f.Service.States[f.Player]==nil,'Reaching actual land before re-entry cancels an overdue water episode')
end

do
    local f=fixture();f:Step(0);f:Step(29)
    local old=f.Player.Character
    f.Player.Character=f.Env:Character('Respawn');f.Swim(f.Player);f:Step(30)
    check(old.Humanoid.Health==100 and f.Player.Character.Humanoid.Health==100,'Character identity prevents killing a respawn using old timer')
    f:Step(59.9);check(f.Player.Character.Humanoid.Health==100,'Respawn water episode has its own start time')
    f.Service:Remove(f.Player)
    check(f.Service.States[f.Player]==nil,'Player removal explicitly clears episode')
end

do
    local f=fixture();f:Step(0)
    local other=f.Env:AddPlayer(2,true);f.Swim(other);f:Step(10);f:Step(30)
    check(f.Player.Character.Humanoid.Health==0 and other.Character.Humanoid.Health==100,'Two players have independent water clocks')
    f:Step(39.9);check(other.Character.Humanoid.Health==100,'Later swimmer remains safe until their own threshold')
    f:Step(40);check(other.Character.Humanoid.Health==0 and #f.Visuals==2,'Each player receives exactly one own shark')
end

do
    local f=fixture();local h=f.Player.Character.Humanoid
    h.State=f.Env.Enum.HumanoidStateType.Freefall
    f.Env.RayResult={Material=f.Env.Enum.Material.Water,Position=V.new(0,0,0),Normal=V.yAxis,
        Instance=f.Env:Node('Terrain','Terrain',f.Env.World),Distance=.5}
    f:Step(0)
    check(f.Service.States[f.Player]~=nil,'Physical water probe detects immersion during state transition')
    for _,ray in f.Env.Rays do
        check(ray.Direction.Y<0 and ray.Params.IgnoreWater==false and ray.Params.RespectCanCollide==true,
            'Server contact probe sees water while ignoring noncollidable decoration')
    end
    local count=#f.Env.Rays
    f:Step(.01);f:Step(.02);f:Step(.03)
    check(#f.Env.Rays==count,'Water contact checks are throttled rather than every heartbeat')
end

do
    local f=fixture();f:Step(0);f:Step(29)
    f.Env.RayResult={Material=f.Env.Enum.Material.WoodPlanks,Position=V.new(0,-2.5,0),Normal=V.yAxis,
        Instance=f.Env:Node('Part','Deck',f.Env.World),Distance=3}
    f:Step(30)
    check(f.Player.Character.Humanoid.Health==100 and f.Service.States[f.Player]==nil,
        'Actual dry deck contact takes precedence over a stale Swimming state')
end

do
    local f=fixture();f:Step(0);f:Step(30)
    local shark=f.Visuals[1]
    local rays=#f.Env.Rays;local frame=shark.Frame
    f:Step(30.01)
    check(shark.Frame~=frame and #f.Env.Rays==rays,'Cosmetic shark animation advances between throttled contact checks')
    f.Service:Remove(f.Player)
    check(shark.Destroyed and next(f.Service.Effects)==nil,'Respawn/logout cleanup removes the player attack visual')
end

do
    local f=fixture();f:Step(0);f:Step(30)
    local shark=f.Visuals[1]
    f.Service:Destroy()
    check(shark.Destroyed and next(f.Service.States)==nil and next(f.Service.Effects)==nil,
        'Service teardown clears an active shark and all episode state')
end

do
    local f=fixture();local h=f.Player.Character.Humanoid
    f:Step(0);f:Step(29)
    h.Health=0;f:Step(29.2)
    check(f.Service.States[f.Player]==nil and #f.Visuals==0,'External death clears timer without creating another shark')
    f.Service.Settings.Enabled=false;h.Health=100;f:Step(60)
    check(h.Health==100 and f.Service.States[f.Player]==nil,'Feature toggle disables attacks')
end

print('PASS water hazard: '..checks..' checks (server timer, water hopping, boat safety and lifecycle; Studio physics still required)')
