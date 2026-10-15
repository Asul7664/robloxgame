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
local shared=env:Node('Folder','QuietCove',env.Replicated)
env:Node('ModuleScript','SahurBossSettings',shared)
env:Node('ModuleScript','Damage',env.Combat)
local tags={}
env.Services.CollectionService={AddTag=function(_,m) tags[m]=true end,RemoveTag=function(_,m) tags[m]=nil end}
env.Services.PathfindingService={CreatePath=function() error('Unexpected path request') end}
local priorRequire=g.require
g.require=function(module)
    if module.Name=='SahurBossSettings' then return settings end
    if module.Name=='Damage' then return damage end
    return priorRequire(module)
end
local player=env:AddPlayer(404,true)
env.Services.Players.GetPlayerByUserId=function(_,id) return id==player.UserId and player or nil end
local function model()
    local m,h=env:Character('SahurBoss')
    h.HipHeight=4.5;h.SetStateEnabled=function() end
    h.Move=function(self,v) self.LastMove=v end
    h.MoveTo=function(self,v) self.LastGoal=v end
    m.HumanoidRootPart.SetNetworkOwner=function(self,owner) self.NetworkOwner=owner end
    m.HumanoidRootPart.PivotOffset=r.CFrame.new(.355,-7.249,-.837)*r.CFrame.Angles(0,.12,0)
    m.PivotTo=function(self,cf)
        self.HumanoidRootPart.CFrame=cf*self.HumanoidRootPart.PivotOffset:Inverse()
    end
    return m,h
end
local template=model();template.Parent=env.Storage
-- Clone fresh signals; the generic fixture's Clone intentionally shares them.
template.Clone=function() local m=model();return m end
local wins=0
local Service=env:Execute('src/server/SahurService.luau')
local service=Service.new(function() wins+=1 end,function() end)
local zone={Center=r.Vector3.new(0,8,0)}
player.Character.HumanoidRootPart.CFrame=r.CFrame.new(0,10,0)
local function start()
    check(service:Start(player,'token',{Species='sahur'},zone,{}),'Start succeeds')
    return service.States[player]
end
local state=start()
check((state.Root.Position-state.Origin).Magnitude<.001,'Imported pivot does not offset root emergence position')
check(wins==0 and service:IsActive(player),'Spawn does not award fish')
check(not service:Start(player,'duplicate',{},zone,{}),'Second concurrent encounter rejected')
check(not damage.Apply(player.Character,state.Humanoid,18),'Emergence cannot be damaged')
service:Step(state.At+settings.RiseTime-.00001)
check((state.Root.Position-state.Destination).Magnitude<.001,'Imported pivot lands root at intended deck height')
service:Step(state.At+settings.RiseTime+.01)
check(not state.Root.Anchored and state.Root.NetworkOwner==nil,'Emergence hands physics to server')
state.Root.CFrame=r.CFrame.new(0,10,6)
state.NextAttack=0;state.ThinkAt=math.huge
service:Step(state.At+2)
check(state.AttackAt~=nil and state.Humanoid.WalkSpeed==0,'Attack commits and stops walking')
player.Character:SetAttribute('IFrame',true)
service:Step(state.AttackAt+settings.Windup+.01)
check(player.Character.Humanoid.Health==100,'Existing dodge immunity blocks boss strike')
player.Character:SetAttribute('IFrame',false)
state.AttackAt=nil;state.NextAttack=0
service:Step(state.At+5)
service:Step(state.AttackAt+settings.Windup+.01)
check(player.Character.Humanoid.Health==100-settings.Damage,'Committed strike applies existing damage')
local hp=player.Character.Humanoid.Health
service:Step(state.AttackAt+settings.Windup+.05)
check(player.Character.Humanoid.Health==hp,'One damage application per attack')
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
local asset=r.deserializeModel(fs.readFile('assets/creatures/SahurBoss.rbxm'))[1]
local parts,joints=0,0
for _,item in asset:GetDescendants() do
    check(not item:IsA('LuaSourceContainer'),'No imported executable source remains')
    if item:IsA('BasePart') then parts+=1 end
    if item:IsA('Motor6D') then joints+=1;check(item.Part0 and item.Part1,'Rig references survive serialization') end
end
check(parts==16 and joints==15,'Original geometry and complete skeleton retained')
check(asset:GetAttribute('QCSizeMultiplier')==2,'Asset is already doubled')
-- Run the actual client renderer, including tag removal and pose restoration.
local visual=model()
local joint=visual:FindFirstChild('Right Shoulder',true);joint.Name='RightShoulder'
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
