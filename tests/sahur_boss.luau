-- Real service lifecycle/attacks, pose module, damage module, imported asset.
-- Service doubles cannot validate Studio physics/rendering or asset permissions.
local fs=require('@lune/fs')
local luau=require('@lune/luau')
local r=require('@lune/roblox')
local Environment=require('./helpers/combat_environment')
local checks=0
local function check(value,message) checks+=1;assert(value,message) end
local env=Environment.new()
local g=env.Globals
local settings=luau.load(fs.readFile('src/shared/SahurBossSettings.luau'))()
local damage=env:Execute('src/combat/Damage.luau')
local nativeAsset=r.deserializeModel(fs.readFile('assets/creatures/SahurBoss.rbxm'))[1]
local attackClip=env:Execute('src/shared/SahurAttackClip.luau')
local club=env:Execute('src/shared/SahurClub.luau')
local shared=env:Node('Folder','QuietCove',env.Replicated)
for _,name in {'SahurBossSettings','SahurAttackClip','SahurClub'} do env:Node('ModuleScript',name,shared) end
env:Node('ModuleScript','Damage',env.Combat)
local tags={}
env.Services.CollectionService={AddTag=function(_,m) tags[m]=true end,RemoveTag=function(_,m) tags[m]=nil end}
local paths={}
env.Services.PathfindingService={CreatePath=function(_,options)
    table.insert(paths,options)
    return {
        Status=g.Enum.PathStatus.Success,
        ComputeAsync=function() end,
        GetWaypoints=function() return env.TestWaypoints or {} end,
    }
end}
local priorRequire=g.require
g.require=function(module)
    if module.Name=='SahurBossSettings' then return settings end
    if module.Name=='SahurAttackClip' then return attackClip end
    if module.Name=='SahurClub' then return club end
    if module.Name=='Damage' then return damage end
    return priorRequire(module)
end
local player=env:AddPlayer(404,true)
env.Services.Players.GetPlayerByUserId=function(_,id) return id==player.UserId and player or nil end
-- Use the imported rig's real hierarchy and native Motor6D frames. A generic
-- R6 double cannot verify a strike drawn through this unusual segmented club.
local function model()
    local m=env:Node('Model','SahurBoss')
    local copied={[nativeAsset]=m}
    local function copy(parent,source)
        for _,child in source:GetChildren() do
            if child:IsA('BasePart') or child:IsA('Motor6D') or child:IsA('Humanoid') then
                local node=env:Node(child.ClassName,child.Name,parent)
                copied[child]=node
                if child:IsA('BasePart') then
                    node.Size=child.Size;node.CFrame=child.CFrame;node.PivotOffset=child.PivotOffset
                    node.AssemblyLinearVelocity=r.Vector3.zero;node.AssemblyAngularVelocity=r.Vector3.zero
                elseif child:IsA('Motor6D') then
                    node.C0=child.C0;node.C1=child.C1
                elseif child:IsA('Humanoid') then node.HipHeight=child.HipHeight end
                copy(node,child)
            end
        end
    end
    copy(m,nativeAsset)
    for source,node in copied do
        if source:IsA('Motor6D') then node.Part0=copied[source.Part0];node.Part1=copied[source.Part1] end
    end
    local h=m.Humanoid
    h.StateEnabled={}
    h.SetStateEnabled=function(self,state,enabled) self.StateEnabled[state]=enabled end
    h.Move=function(self,v) self.LastMove=v end
    h.MoveTo=function(self,v) self.LastGoal=v end
    m.HumanoidRootPart.SetNetworkOwner=function(self,owner) self.NetworkOwner=owner end
    m.PivotTo=function(self,cf)
        self.PivotCalls=(self.PivotCalls or 0)+1
        local frame=cf*self.HumanoidRootPart.PivotOffset:Inverse()
        local transform=frame*self.HumanoidRootPart.CFrame:Inverse()
        for _,part in self:GetDescendants() do
            if part:IsA('BasePart') then part.CFrame=transform*part.CFrame end
        end
    end
    return m,h
end
-- Give the victim actual body volumes; env's lightweight default parts all
-- start at the origin and are intentionally unsuitable for geometric hits.
local function targetAt(frame)
    local character=player.Character
    for name,spec in {
        HumanoidRootPart={r.Vector3.new(2,2,1),r.Vector3.zero},
        Torso={r.Vector3.new(2,2,1),r.Vector3.zero},
        Head={r.Vector3.new(2,1,1),r.Vector3.new(0,1.5,0)},
        ['Right Arm']={r.Vector3.new(1,2,1),r.Vector3.new(1.5,0,0)},
        ['Left Arm']={r.Vector3.new(1,2,1),r.Vector3.new(-1.5,0,0)},
        ['Right Leg']={r.Vector3.new(1,2,1),r.Vector3.new(.5,-2,0)},
        ['Left Leg']={r.Vector3.new(1,2,1),r.Vector3.new(-.5,-2,0)},
    } do
        local part=character:FindFirstChild(name)
        if part then part.Size=spec[1];part.CFrame=frame*r.CFrame.new(spec[2]) end
    end
end
local template=model();template.Parent=env.Storage
-- Clone fresh signals; the generic fixture's Clone intentionally shares them.
rawset(template,'Clone',function() local m=model();return m end)
local wins=0
local Service=env:Execute('src/server/SahurService.luau')
local service=Service.new(function() wins+=1 end,function() end)
local island={Id='Dunes',X=0,Z=0,Radius=70}
local archipelago=env:Node('Folder','QuietCoveArchipelago',env.World)
local islandModel=env:Node('Model','Dunes',archipelago)
local floor=env:Node('Part','IslandPath',islandModel);floor.CanCollide=true
local zone={Center=r.Vector3.new(0,8,-95)}
env.RayHandler=function(origin,direction,params)
    if direction.X==0 and direction.Z==0 and direction.Y<-10 then
        if env.NoGround then return nil end
        return {Position=r.Vector3.new(origin.X,env.GroundY or 7.4,origin.Z),
            Normal=r.Vector3.yAxis,Material=g.Enum.Material.Sand,Instance=floor}
    end
    return env.RayResult
end
targetAt(r.CFrame.new(0,10,0))
local function start()
    local ok,reason=service:Start(player,'token',{Species='sahur'},zone,island)
    check(ok,'Start succeeds: '..tostring(reason))
    return service.States[player]
end
local state=start()
check((state.Root.Position-state.Origin).Magnitude<.001,'Imported pivot does not offset root emergence position')
check(math.abs(state.Destination.Z-island.Z)<island.Radius*.6,'Landing is actual island land, not distant fishing deck')
check(math.abs(state.Destination.Y-(7.4+state.FootHeight+.05))<.001,'Landing uses real island ground surface')
check(not state.Humanoid.AutoJumpEnabled and state.Humanoid.JumpPower==0 and state.Humanoid.JumpHeight==0,'Automatic/physical jumping is disabled')
check(state.Humanoid.StateEnabled[g.Enum.HumanoidStateType.Jumping]==false,'Jumping state is disabled')
check(wins==0 and service:IsActive(player),'Spawn does not award fish')
check(not service:Start(player,'duplicate',{},zone,{}),'Second concurrent encounter rejected')
check(not damage.Apply(player.Character,state.Humanoid,18),'Emergence cannot be damaged')
service:Step(state.At+settings.RiseTime*.5)
check(state.Root.Position.Y>(state.Origin.Y+state.Destination.Y)/2+settings.SpawnArcHeight-.01,'Single spawn arc clears the island cliffs high above ground')
service:Step(state.At+settings.RiseTime-.00001)
check((state.Root.Position-state.Destination).Magnitude<.001,'Imported pivot lands root at intended deck height')
service:Step(state.At+settings.RiseTime+.01)
check(not state.Root.Anchored and state.Root.NetworkOwner==nil,'Emergence hands physics to server')
local pivotCalls=state.Model.PivotCalls
check(state.Model:GetAttribute('SahurLandingAt')~=nil,'Landing animation has authoritative timestamp')
local rootFrame=r.CFrame.new(0,14.65,0)
local targetPosition=r.Vector3.new(0,10.4,-5.8)
state.Root.CFrame=rootFrame;targetAt(r.CFrame.new(targetPosition))
state.NextAttack=0;state.ThinkAt=math.huge
local tick=state.At+2
service:Step(tick)
check(state.AttackAt~=nil and state.Humanoid.WalkSpeed==0,'Attack commits and stops walking')
check(not state.Humanoid.AutoRotate,'Strike disables automatic tracking rotation')
player.Character:SetAttribute('IFrame',true)
service:Step(state.AttackAt+settings.Windup+settings.Strike+.001)
check(player.Character.Humanoid.Health==100 and not state.Hit,'Existing dodge immunity blocks entire active club sweep')
player.Character:SetAttribute('IFrame',false)
service:Step(state.AttackAt+settings.Windup+settings.Strike+.02)
check(player.Character.Humanoid.Health==100,'Expired immunity cannot revive a finished active window')
local finished=state.AttackAt+settings.Windup+settings.Strike+settings.Recovery+.01
service:Step(finished)
check(not state.AttackAt and state.Humanoid.AutoRotate and state.Model:GetAttribute('SahurAttackAt')==nil,
    'Recovery clears attack state and restores normal turning')
service:Step(finished+.02)
check(not state.AttackAt,'Cooldown prevents a new attack immediately after recovery')
local function nextAttack()
    tick=math.max(tick+2,state.NextAttack+.01)
    state.Root.CFrame=rootFrame;targetAt(r.CFrame.new(targetPosition))
    player.Character:SetAttribute('IFrame',false)
    service:Step(tick)
    check(state.AttackAt~=nil,'Next attack begins only after cooldown')
    return state.AttackAt
end
local function finishAttack(at)
    service:Step(at+settings.Windup+settings.Strike+settings.Recovery+.01)
end
local attackAt=nextAttack()
service:Step(attackAt+settings.Windup-.001)
check(player.Character.Humanoid.Health==100,'Visible windup cannot damage before active club motion')
service:Step(attackAt+settings.Windup+settings.Strike+.001)
check(player.Character.Humanoid.Health==100-settings.Damage,'Catch-up sweep applies existing damage along the actual club')
local hp=player.Character.Humanoid.Health
service:Step(attackAt+settings.Windup+settings.Strike+.05)
check(player.Character.Humanoid.Health==hp,'One successful damage application per attack')
finishAttack(attackAt)
-- A missed swing cannot turn mid-flight to follow a dodge, hit someone behind
-- it, or reach beyond the visible shaft/head. These targets were all in the
-- old broad cone's generous horizontal/vertical tolerances.
for _,case in {
    {Name='Lateral sidestep',Position=r.Vector3.new(8,10.4,-5.8)},
    {Name='Behind committed swing',Position=r.Vector3.new(0,10.4,6)},
    {Name='Beyond actual club head',Position=r.Vector3.new(0,10.4,-14)},
    {Name='Above actual club',Position=r.Vector3.new(0,22,-5.8)},
} do
    attackAt=nextAttack()
    targetAt(r.CFrame.new(case.Position))
    local facing=state.Facing
    service:Step(attackAt+settings.Windup+settings.Strike+.001)
    check(player.Character.Humanoid.Health==hp,case.Name..' misses')
    check((state.Root.CFrame.LookVector-facing).Magnitude<.0001,'Active strike facing remains committed after '..case.Name)
    finishAttack(attackAt)
end
attackAt=nextAttack()
env.RayResult={Instance=floor}
service:Step(attackAt+settings.Windup+settings.Strike+.001)
check(player.Character.Humanoid.Health==hp,'World geometry between boss and actual contact blocks strike')
env.RayResult=nil;finishAttack(attackAt)
attackAt=nextAttack()
player.Character:SetAttribute('IFrame',true)
service:Step(attackAt+settings.Windup+.12)
check(player.Character.Humanoid.Health==hp and not state.Hit,'IFrame contact is not recorded as a successful hit')
player.Character:SetAttribute('IFrame',false)
service:Step(attackAt+settings.Windup+settings.Strike)
check(player.Character.Humanoid.Health==hp-settings.Damage,'Immunity ending during active sweep permits a later real contact')
hp=player.Character.Humanoid.Health
finishAttack(attackAt)
-- A server stall may skip the whole strike and recovery in one Step. Its
-- bounded substeps still evaluate the legitimate original active timeline.
attackAt=nextAttack()
service:Step(attackAt+settings.Windup+settings.Strike+settings.Recovery+.03)
check(player.Character.Humanoid.Health==hp-settings.Damage,'Low frame rate cannot skip the active damage interval')
check(not state.AttackAt,'Catch-up also finishes recovery in the same update')
check(state.Model.PivotCalls==pivotCalls and not state.Humanoid.Jump,'Spawn arc cannot replay during combat')
local stranger=env:Character('Stranger')
check(not damage.Apply(stranger,state.Humanoid,999),'Another player cannot steal encounter')
check(damage.Apply(player.Character,state.Humanoid,999),'Owner weapons can defeat boss')
check(wins==1 and not service:IsActive(player),'Death awards once and removes active encounter')
state.Humanoid.Died:Fire()
check(wins==1,'Repeated death callback cannot award twice')
state=start();player.Character.Humanoid.Health=0
service:Step(state.At+1)
check(not service:IsActive(player) and state.Model.Destroyed and wins==1,'Player death cleans encounter without reward')
player.Character.Humanoid.Health=100
state=start();service:Remove(player)
state.Humanoid.Died:Fire()
check(wins==1 and not tags[state.Model],'Disconnect/reset cleanup detaches callback and tag')
state=start();service:Step(state.At+settings.Lifetime+1)
check(not service:IsActive(player) and wins==1,'Expired encounter gives no reward')
-- Chase the fisher across ground; reaching a floor waypoint must compare XZ,
-- because this enlarged rig's root is more than seven studs above the floor.
state=start();service:Step(state.At+settings.RiseTime+.01)
check((state.Root.Position-state.Destination).Magnitude<.001,'A skipped flight frame still ends exactly on island ground')
check(state.Humanoid.WalkSpeed==0 and not state.AttackAt,'Landing absorbs impact before chase or attack')
local chaseAt=state.At+settings.RiseTime+settings.LandingRecovery+.1
targetAt(r.CFrame.new(40,10,-29.4))
service:Step(chaseAt)
check(state.Humanoid.LastGoal==player.Character.HumanoidRootPart.Position,'Landed Sahur follows moving player')
check(not state.Humanoid.Jump and state.Humanoid.WalkSpeed==settings.WalkSpeed,'Chase uses walking only')
targetAt(r.CFrame.new(state.Root.Position+r.Vector3.new(settings.AttackRange+settings.ApproachDistance*.5,-4.2,0)))
service:Step(chaseAt+.06)
check(math.abs(state.Humanoid.WalkSpeed-(settings.ApproachSpeed+settings.WalkSpeed)*.5)<.001,
    'Visible approach eases speed before committing to melee')
targetAt(r.CFrame.new(40,10,-29.4));service:Step(chaseAt+.12)
check(state.Humanoid.WalkSpeed==settings.WalkSpeed,'Distance pursuit resumes full speed after approach')
env.RayResult={Instance=floor}
env.TestWaypoints={
    {Position=r.Vector3.new(0,7.4,-29.4),Action=g.Enum.PathWaypointAction.Walk},
    {Position=r.Vector3.new(.2,7.4,-29.4),Action=g.Enum.PathWaypointAction.Walk},
    {Position=r.Vector3.new(12,7.4,-29.4),Action=g.Enum.PathWaypointAction.Walk},
}
state.ThinkAt=0
service:Step(chaseAt+.2)
check(#paths>0 and paths[#paths].AgentCanJump==false and paths[#paths].AgentCanClimb==false,'Pathfinding cannot request jumps or climbing')
check(paths[#paths].AgentRadius>=2.99 and paths[#paths].AgentHeight>=13,'Navigation fits doubled rig collider and height')
check(state.Humanoid.LastGoal==env.TestWaypoints[3].Position,'Ground waypoint beneath root advances without getting stuck on height')
env.TestWaypoints={{Position=r.Vector3.new(20,7.4,-29.4),Action=g.Enum.PathWaypointAction.Jump}}
state.NextPath=0;state.ThinkAt=0
service:Step(chaseAt+.4)
check(#state.Path==0 and not state.Humanoid.Jump,'Unexpected jump waypoint is rejected')
env.NoGround=true;state.ThinkAt=0
service:Step(chaseAt+.6)
check(state.Humanoid.LastMove==r.Vector3.zero,'No ground ahead stops chase instead of walking into water')
service:Remove(player);env.NoGround=nil;env.RayResult=nil
targetAt(r.CFrame.new(0,10,0))
-- Turn into the opponent before winding up; a wall cannot trigger an attack
-- merely because the player's center is within the distance threshold.
state=start();service:Step(state.At+settings.RiseTime+.01)
local readyAt=state.At+settings.RiseTime+settings.LandingRecovery+.1
service:Step(readyAt)
state.Root.CFrame=rootFrame;targetAt(r.CFrame.new(targetPosition))
env.RayResult={Instance=floor}
env.TestWaypoints={
    {Position=r.Vector3.new(0,7.4,0),Action=g.Enum.PathWaypointAction.Walk},
    {Position=r.Vector3.new(5,7.4,0),Action=g.Enum.PathWaypointAction.Walk},
    {Position=r.Vector3.new(0,7.4,-5.8),Action=g.Enum.PathWaypointAction.Walk},
}
service:Step(readyAt+.1)
check(not state.AttackAt,'An occluded player cannot trigger a windup through a wall')
check(state.Humanoid.WalkSpeed==settings.WalkSpeed and state.Humanoid.LastGoal==env.TestWaypoints[2].Position,
    'Nearby player behind a wall triggers a walking detour instead of permanent melee idle')
env.RayResult=nil
state.Root.CFrame=rootFrame*r.CFrame.Angles(0,math.pi,0)
local originalLook=state.Root.CFrame.LookVector
local turnAt=readyAt+.2
service:Step(turnAt)
check(not state.AttackAt,'Boss facing away must turn before committing strike')
check((state.Root.CFrame.LookVector-originalLook).Magnitude>.1
    and (state.Root.CFrame.LookVector-r.Vector3.new(0,0,-1)).Magnitude>.1,'Initial turn is smooth instead of a full yaw snap')
for index=1,12 do
    if state.AttackAt then break end
    service:Step(turnAt+index*.05)
end
check(state.AttackAt~=nil,'Smooth turning converges into attack without getting stuck')
check(state.Facing:Dot(r.Vector3.new(0,0,-1))>=math.cos(math.rad(settings.AttackFacingAngle))-.001,
    'Windup only begins within configured facing angle')
service:Remove(player)
targetAt(r.CFrame.new(0,10,0))
local pose=env:Execute('src/shared/SahurBossPose.luau')
local function errorBetween(a,b)
    local x,y={a:GetComponents()},{b:GetComponents()};local sum=0
    for i=1,#x do sum+=math.abs(x[i]-y[i]) end
    return sum
end
local finish=settings.Windup+settings.Strike+settings.Recovery
for _,boundary in {settings.Windup,settings.Windup+settings.Strike,finish} do
    local a=pose.Sample(boundary-.00001,0,false,settings)
    local b=pose.Sample(boundary+.00001,0,false,settings)
    for name in pairs(a) do
        check(errorBetween(a[name],b[name] or r.CFrame.new())<.06,'Smooth pose boundary '..name)
    end
end
local asset=nativeAsset
local parts,joints=0,0
for _,item in asset:GetDescendants() do
    check(not item:IsA('LuaSourceContainer'),'No imported executable source remains')
    if item:IsA('BasePart') then parts+=1 end
    if item:IsA('Motor6D') then joints+=1;check(item.Part0 and item.Part1,'Rig references survive serialization') end
end
check(parts==16 and joints==15,'Original geometry and complete skeleton retained')
check(asset:GetAttribute('QCSizeMultiplier')==2,'Asset is already doubled')
-- Run the actual client renderer, including tag removal and pose restoration.
local visual=model();visual.Parent=env.World
local joint=visual:FindFirstChild('RightShoulder',true)
local base=joint.C0
local added=env:Node('RemoteEvent').OnClientEvent
local removed=env:Node('RemoteEvent').OnClientEvent
env.Services.CollectionService.GetTagged=function() return {visual} end
env.Services.CollectionService.GetInstanceAddedSignal=function() return added end
env.Services.CollectionService.GetInstanceRemovedSignal=function() return removed end
env:Node('ModuleScript','SahurBossPose',shared)
local requireBefore=g.require
g.require=function(module)
    if module.Name=='SahurBossPose' then return pose end
    return requireBefore(module)
end
visual:SetAttribute('SahurAttackAt',env.Time-.2)
env:Execute('src/client/SahurAnimator.client.luau')
env:Advance(.1)
check(errorBetween(joint.C0,base)>.1,'Actual client animates existing tagged rig')
removed:Fire(visual)
check(errorBetween(joint.C0,base)<.0001,'Tag removal restores original joint offsets')
env:Advance(.1)
check(errorBetween(joint.C0,base)<.0001,'Removed rig is not animated on later frames')
added:Fire(visual);env:Advance(.1)
check(errorBetween(joint.C0,base)>.1,'Newly tagged rig starts animating without another loop')
print('PASS Sahur: '..checks..' checks (service doubles; Studio visual/physics check required)')
