-- Real pose module and client renderer, native imported R15 joint baselines.
-- These verify continuity/timing/lifecycle, not Studio physics or visual polish.
local fs=require('@lune/fs')
local roblox=require('@lune/roblox')
local Environment=require('./helpers/combat_environment')
local V,CF=roblox.Vector3,roblox.CFrame
local checks=0
local function check(value,message) checks+=1;assert(value,message) end
local function difference(a,b)
    local x,y={a:GetComponents()},{b:GetComponents()}
    local sum=0
    for i=1,12 do sum+=math.abs(x[i]-y[i]) end
    return sum
end
local function xAngle(frame) return math.deg(math.atan2(frame.LookVector.Y,-frame.LookVector.Z)) end
local env=Environment.new()
local settings=env:Execute('src/shared/SahurBossSettings.luau')
local pose=env:Execute('src/shared/SahurBossPose.luau')
local function sample(phase,weight)
    return pose.Sample(10,nil,true,settings,{Phase=phase,Weight=weight or 1})
end
local function nearPoses(a,b,limit,label)
    for name,frame in pairs(a) do check(difference(frame,b[name] or CF.new())<limit,label..' / '..name) end
end
-- Ankle rollover, knee flexion and the supporting leg must stay continuous at
-- toe-off, at heel contact, and while the left/right support legs exchange.
for _,phase in {0,math.pi,.62*2*math.pi,(.62+.5)*2*math.pi,2*math.pi} do
    nearPoses(sample(phase-.000001),sample(phase+.000001),.001,'Continuous walking contact')
end
local minimumKnee,maximumKnee=0,-90
local minRoot,maxRoot=math.huge,-math.huge
local maxSupportFlex,maxSwingFlex=0,0
for index=0,24 do
    local phase=index/24*math.pi*2
    local current=sample(phase)
    local valid=true
    for _,frame in pairs(current) do
        for _,component in {frame:GetComponents()} do
            valid=valid and component==component and math.abs(component)<2
        end
    end
    check(valid,'Sampled walking transforms remain finite and bounded')
    local knee=xAngle(current.RightKnee)
    minimumKnee=math.min(minimumKnee,knee);maximumKnee=math.max(maximumKnee,knee)
    local cycle=index/24
    if cycle<.62 then maxSupportFlex=math.max(maxSupportFlex,-knee)
    else maxSwingFlex=math.max(maxSwingFlex,-knee) end
    minRoot=math.min(minRoot,current.Root.Position.Y);maxRoot=math.max(maxRoot,current.Root.Position.Y)
    check(math.abs(xAngle(current.RightHip)-xAngle(sample(phase+math.pi).LeftHip))<.001,
        'Opposite leg repeats the same complete support/swing cycle')
end
check(minimumKnee< -50 and maximumKnee<0,'Knees bend backwards during the return instead of rigid marching')
check(maxSwingFlex>maxSupportFlex*2,'Support knee carries weight while the returning knee folds')
check(maxRoot-minRoot>.09 and maxRoot-minRoot<.2,'Body weight transfers vertically without an excessive bounce')
local one=sample(.7,1)
local zero=sample(.7,0)
check(difference(one.LeftShoulder,zero.LeftShoulder)>difference(one.RightShoulder,zero.RightShoulder),
    'Free arm counterbalances the bat rather than swinging both arms identically')
nearPoses(zero,pose.Sample(10,nil,false,settings),.0001,'Zero measured motion blends to breathing idle')
local duration=settings.Windup+settings.Strike+settings.Recovery
for _,boundary in {0,settings.Windup*.73,settings.Windup,settings.Windup+settings.Strike,duration} do
    nearPoses(pose.Sample(boundary-.000001,0,false,settings),pose.Sample(boundary+.000001,0,false,settings),
        .001,'Continuous attack transition '..boundary)
end
local wind=pose.Sample(settings.Windup*.73,0,false,settings)
local contact=pose.Sample(settings.Windup,0,false,settings)
check(difference(wind.RightShoulder,contact.RightShoulder)>3,'Bat arm has a broad deliberate windup and strike')
check(xAngle(contact.RightShoulder)>20,'Downswing has reached its forward contact pose at authoritative damage time')
check(difference(wind.Waist,contact.Waist)>1,'Torso rotates through the strike instead of an isolated swinging arm')
check(contact.Root.Position.Z<wind.Root.Position.Z-.1,'Planted strike transfers body weight toward the opponent')
for _,phase in {.1,.4,.7,1.0} do
    local current=pose.Sample(phase,0,false,settings)
    check(xAngle(current.RightKnee)<0 and xAngle(current.LeftKnee)<0,'Attack keeps both knees loaded')
end
-- The arrival pose is controlled only by the server's one-shot attributes.
local spawn=200
local land=spawn+settings.RiseTime
local recovery=settings.LandingRecovery or .24
local function arrival(time,emerging)
    return pose.Sample(time,nil,false,settings,{Emerging=emerging,SpawnAt=spawn,LandingAt=land})
end
nearPoses(arrival(land-.000001,true),arrival(land+.000001,false),.001,'Leap braces continuously into first landing frame')
nearPoses(arrival(land+recovery*.3-.000001,false),arrival(land+recovery*.3+.000001,false),
    .001,'Landing compression blends into recovery')
nearPoses(arrival(land+recovery-.000001,false),arrival(land+recovery+.000001,false),
    .001,'Landing recovery settles into idle')
check(xAngle(arrival(spawn+settings.RiseTime*.38,true).RightKnee)<-60,'High arrival leap tucks the knees')
check(arrival(land+recovery*.3,false).Root.Position.Y<-.5,'Ground contact compresses knees and body before rising')
for _,later in {3,10,90} do
    nearPoses(arrival(land+later,false),pose.Sample(land+later,nil,false,settings),.0001,
        'Old spawn timestamp never repeats the leap')
end
-- Drive the actual client script on the native asset's existing joint bases.
local asset=roblox.deserializeModel(fs.readFile('assets/creatures/SahurBoss.rbxm'))[1]
local motorByPart={}
for _,joint in asset:GetDescendants() do
    if joint:IsA('Motor6D') then motorByPart[joint.Part1]=joint end
end
local function nativeFrame(part,current)
    if part==asset.HumanoidRootPart then return CF.new() end
    local joint=motorByPart[part]
    return nativeFrame(joint.Part0,current)*joint.C0*(current[joint.Name] or CF.new())*joint.C1:Inverse()
end
local function lowestSole(foot,current)
    local frame=nativeFrame(foot,current)
    local lowest=math.huge
    for _,x in {-1,1} do
        for _,z in {-1,1} do
            lowest=math.min(lowest,frame:PointToWorldSpace(V.new(x*foot.Size.X/2,-foot.Size.Y/2,z*foot.Size.Z/2)).Y)
        end
    end
    return lowest
end
for _,side in {'Right','Left'} do
    local foot=asset:FindFirstChild(side..'Foot')
    local offset=side=='Left' and .5 or 0
    local minContact,maxContact,minHeight,maxHeight=math.huge,-math.huge,math.huge,-math.huge
    for index=0,12 do
        local cycle=index/12*.62
        local current=sample((cycle+offset)*math.pi*2)
        local height=lowestSole(foot,current)
        minHeight=math.min(minHeight,height);maxHeight=math.max(maxHeight,height)
        if cycle>=.1 and cycle<=.5 then
            local sole=nativeFrame(foot,current):PointToWorldSpace(V.new(0,-foot.Size.Y/2,0))
            local contact=sole.Z-(cycle+offset)*(settings.StrideLength or 6.2)
            minContact=math.min(minContact,contact);maxContact=math.max(maxContact,contact)
        end
    end
    check(maxContact-minContact<.5,side..' native support foot follows measured root transport without broad sliding')
    check(maxHeight-minHeight<.22,side..' native heel/toe envelope stays near the ground through the supporting phase')
    check(math.abs(maxHeight-lowestSole(foot,{}))<.22,side..' support foot does not hover noticeably over its native standing ground')
end
check(nativeFrame(asset.RightHand,wind).Position.Z>1 and nativeFrame(asset.RightHand,contact).Position.Z< -3,
    'Native bat hand travels from behind the shoulder into the committed forward strike')
local model=env:Node('Model','RenderedSahur',env.World)
model.DescendantAdded=Environment.Signal()
local byOriginal={}
for _,item in asset:GetDescendants() do
    if item:IsA('BasePart') then
        local part=env:Node('Part',item.Name,model)
        part.CFrame,part.Size=item.CFrame,item.Size
        byOriginal[item]=part
    end
end
local joints,bases={},{ }
for _,item in asset:GetDescendants() do
    if item:IsA('Motor6D') then
        local joint=env:Node('Motor6D',item.Name,byOriginal[item.Part0])
        joint.C0,joint.C1=item.C0,item.C1
        joint.Part0,joint.Part1=byOriginal[item.Part0],byOriginal[item.Part1]
        joints[item.Name]=joint;bases[joint]=joint.C0
    end
end
local root=model.HumanoidRootPart
root.AssemblyLinearVelocity=V.zero
local shared=env:Node('Folder','QuietCove',env.Replicated)
env:Node('ModuleScript','SahurBossSettings',shared)
env:Node('ModuleScript','SahurBossPose',shared)
local added,removed=Environment.Signal(),Environment.Signal()
env.Services.CollectionService={GetTagged=function() return {model} end,
    GetInstanceAddedSignal=function() return added end,GetInstanceRemovedSignal=function() return removed end}
local prior=env.Globals.require
env.Globals.require=function(module)
    if module.Name=='SahurBossPose' then return pose end
    if module.Name=='SahurBossSettings' then return settings end
    return prior(module)
end
model:SetAttribute('SahurMoving',true)
env:Execute('src/client/SahurAnimator.client.luau')
check(env.Run.PreSimulation:Count()==1 and added:Count()==1 and removed:Count()==1,'One render loop services tagged rigs')
env:Advance(.8)
check(difference(joints.RightHip.C0,bases[joints.RightHip])<.001,'Movement intent alone cannot make a blocked boss march')
root.AssemblyLinearVelocity=V.new(0,0,-settings.WalkSpeed)
local high,low=-math.huge,math.huge
for _=1,60 do
    env:Advance(1/60)
    local current=xAngle(bases[joints.RightHip]:Inverse()*joints.RightHip.C0)
    high=math.max(high,current);low=math.min(low,current)
end
check(high-low>30,'Measured planar motion advances the actual native rig through a full stride')
root.AssemblyLinearVelocity=V.zero
env:Advance(1.5)
check(difference(joints.RightHip.C0,bases[joints.RightHip])<.001,'Stopping against geometry smoothly settles the actual leg pose')
model:SetAttribute('SahurAttackAt',env.Time-.2)
env:Advance(.05)
check(difference(joints.RightShoulder.C0,bases[joints.RightShoulder])>.2,'Existing tagged skeleton performs the actual strike')
local late=env:Node('Motor6D','LeftWrist',root)
local lateBase=CF.new(1,2,3);late.C0=lateBase
model.DescendantAdded:Fire(late)
env:Advance(.05)
check(difference(late.C0,lateBase)>.01,'Joint streamed after tag discovery receives the same pose')
late.Parent=nil;env:Advance(.01)
check(difference(late.C0,lateBase)<.0001,'Streamed-out joint is restored before its next discovery')
late.Parent=root;model.DescendantAdded:Fire(late);env:Advance(.01)
removed:Fire(model)
for joint,base in pairs(bases) do check(difference(joint.C0,base)<.0001,'Tag removal restores native attachment '..joint.Name) end
check(difference(late.C0,lateBase)<.0001 and model.DescendantAdded:Count()==0,'Tag removal restores streamed joint and releases its listener')
env:Advance(.1)
check(difference(joints.RightShoulder.C0,bases[joints.RightShoulder])<.0001,'Untagged rig cannot keep animating')
added:Fire(model);added:Fire(model)
check(model.DescendantAdded:Count()==1,'Repeated add signal never duplicates the rig watcher')
env:Advance(.05)
env.ClientScript:Destroy()
check(env.Run.PreSimulation:Count()==0 and added:Count()==0 and removed:Count()==0,
    'Renderer destruction disconnects global render and tag listeners')
check(model.DescendantAdded:Count()==0,'Renderer destruction releases each tracked streaming listener')
for joint,base in pairs(bases) do check(difference(joint.C0,base)<.0001,'Renderer destruction restores '..joint.Name) end
print('PASS Sahur animation: '..checks..' checks (native R15 offsets, scripted renderer; Studio visual check required)')
