-- Server-side original-rig FK and exact swept-club/body geometry. No physics
-- engine is simulated here; world wall checks are exercised by sahur_boss.
local fs=require('@lune/fs')
local luau=require('@lune/luau')
local r=require('@lune/roblox')
local Environment=require('./helpers/combat_environment')
local env=Environment.new()
local Club=env:Execute('src/shared/SahurClub.luau')
local Clip=env:Execute('src/shared/SahurAttackClip.luau')
local settings=luau.load(fs.readFile('src/shared/SahurBossSettings.luau'))()
local V,CF=r.Vector3,r.CFrame
local checks=0
local function check(value,message) checks+=1;assert(value,message) end
local function close(a,b,message) check((a-b).Magnitude<.0001,message) end
local model=r.deserializeModel(fs.readFile('assets/creatures/SahurBoss.rbxm'))[1]
local rig=Club.Capture(model)
check(rig~=nil,'Original imported skeleton is supported without mesh replacement')
local rest=Club.Segments(rig,model.HumanoidRootPart.CFrame,{})
check(#rest==2,'Only actual harmful shaft and club head are used')
local points={
    {Part='RightLowerArm',A=V.new(-.701247,1.321459,.710923),B=V.new(.556049,-1.162436,-.479218),Radius=.45676},
    {Part='RightHand',A=V.new(-.337078,.577097,.311359),B=V.new(.266139,-.614610,-.259639),Radius=.49267},
}
for index,spec in points do
    close(rest[index].A,model[spec.Part].CFrame:PointToWorldSpace(spec.A),'Rest FK agrees with native shaft/head A')
    close(rest[index].B,model[spec.Part].CFrame:PointToWorldSpace(spec.B),'Rest FK agrees with native shaft/head B')
    check(math.abs(rest[index].Radius-spec.Radius)<1e-6,'Physical fitted radius survives sampling')
end
local rootFrame=CF.new(20,15,-40)*CF.Angles(0,.8,0)
local transformed=Club.Segments(rig,rootFrame,{})
local mapping=rootFrame*model.HumanoidRootPart.CFrame:Inverse()
for index,segment in transformed do
    close(segment.A,mapping:PointToWorldSpace(rest[index].A),'World root translation and yaw transform shaft A')
    close(segment.B,mapping:PointToWorldSpace(rest[index].B),'World root translation and yaw transform shaft B')
end
local shoulder=model:FindFirstChild('RightShoulder',true)
local nativeC0=shoulder.C0
shoulder.C0=CF.new(999,999,999)
local stable=Club.Segments(rig,rootFrame,{})
close(stable[2].B,transformed[2].B,'Capture freezes native frames against client animation mutation')
shoulder.C0=nativeC0
local elbow=model:FindFirstChild('RightElbow',true)
local parent=elbow.Part0
elbow.Part0=r.Instance.new('Part')
check(Club.Capture(model)==nil,'Incomplete original club chain is rejected instead of broad damage fallback')
elbow.Part0=model.RightHand
check(Club.Capture(model)==nil,'Cyclic skeleton is rejected without recursive FK overflow')
elbow.Part0=parent
check(Club.Capture(env:Node('Model','Empty'))==nil,'Missing root is rejected')

local victim=env:Node('Model','Victim')
local torso=env:Node('Part','Torso',victim);torso.Size=V.new(1,1,1)
local function line(a,b,radius) return {{A=a,B=b,Radius=radius or .2}} end
local function contact(a,b) return Club.Contact(a,b or a,victim) end
local face=line(V.new(.65,-1,0),V.new(.65,1,0))
check(contact(face)~=nil,'Capsule side touches the actual body face')
local point=contact(face)
check(math.abs(point.X-.5)<1e-5,'Contact returns a body-surface point suitable for world LOS')
local cornerMiss=line(V.new(.65,-1,.65),V.new(.65,1,.65))
check(contact(cornerMiss)==nil,'Box corners are not overexpanded into invisible square damage')
local cornerTouch=line(V.new(.64,-1,.64),V.new(.64,1,.64))
check(contact(cornerTouch)~=nil,'True rounded capsule overlap at corner is retained')
local above=line(V.new(-1,1.2,0),V.new(1,1.2,0))
check(contact(above)==nil,'Club above body does not hit through vertical tolerance cone')
local crossingBefore=line(V.new(-2,-.2,0),V.new(-2,.2,0))
local crossingAfter=line(V.new(2,-.2,0),V.new(2,.2,0))
check(contact(crossingBefore)==nil and contact(crossingAfter)==nil,'Sweep endpoints both miss narrow target')
check(contact(crossingBefore,crossingAfter)~=nil,'Endpoint trajectories detect contact between server samples')
local diagonal=line(V.new(-3,-3,0),V.new(3,3,0))
check(contact(diagonal)~=nil,'Segment crossing body is detected even when both segment tips are outside')
torso.CFrame=CF.new(2,3,4)*CF.Angles(.2,.7,-.1)
local oriented=line(torso.CFrame:PointToWorldSpace(V.new(.65,-1,0)),torso.CFrame:PointToWorldSpace(V.new(.65,1,0)))
check(contact(oriented)~=nil,'Hit detection respects rotated body-part bounds')
local rotatedMiss=line(torso.CFrame:PointToWorldSpace(V.new(.65,-1,.65)),torso.CFrame:PointToWorldSpace(V.new(.65,1,.65)))
check(contact(rotatedMiss)==nil,'Oriented box keeps the same exact rounded-corner miss')
torso.CFrame=CF.new(100,0,0)
local root=env:Node('Part','HumanoidRootPart',victim);root.Size=V.new(80,80,80)
local accessory=env:Node('Accessory','Hat',victim)
local handle=env:Node('Part','Handle',accessory);handle.Size=V.new(20,20,20)
local tool=env:Node('Tool','Saber',victim)
env:Node('Part','Handle',tool).Size=V.new(20,20,20)
check(contact(diagonal)==nil,'Invisible root, accessories and equipped weapon do not extend body hitbox')

-- The active authored swing reaches a normal player's torso on the ground,
-- while another player outside the visible club path can sidestep safely.
root.Parent=nil;accessory.Parent=nil;tool.Parent=nil
local groundRoot=CF.new(0,14.65,0)
local leftArm=env:Node('Part','Left Arm',victim);leftArm.Size=V.new(1,2,1)
local rightArm=env:Node('Part','Right Arm',victim);rightArm.Size=V.new(1,2,1)
local function swingHits(target)
    torso.Size=V.new(2,2,1);torso.CFrame=CF.new(target)
    leftArm.CFrame=CF.new(target+V.new(-1.5,0,0));rightArm.CFrame=CF.new(target+V.new(1.5,0,0))
    local old=Club.Segments(rig,groundRoot,Clip.Sample(settings.Windup,settings))
    local hits=0
    local count=math.ceil(settings.Strike*120)
    for index=1,count do
        local elapsed=settings.Windup+settings.Strike*index/count
        local current=Club.Segments(rig,groundRoot,Clip.Sample(elapsed,settings))
        if Club.Contact(old,current,victim) then hits+=1 end
        old=current
    end
    return hits
end
check(swingHits(V.new(0,10.4,-5.8))>0,'Authored server club reaches grounded victim in front')
for _,side in {-1,1} do
    local angle=math.rad(settings.AttackFacingAngle)*side
    check(swingHits(V.new(math.sin(angle)*settings.AttackRange,10.4,-math.cos(angle)*settings.AttackRange))>0,
        'Stationary target at the allowed facing tolerance is reachable on both sides')
end
check(swingHits(V.new(8,10.4,-5.8))==0,'A successful lateral sidestep leaves the real club path')
check(swingHits(V.new(0,10.4,6))==0,'Victim behind locked swing is not hit')
check(swingHits(V.new(0,10.4,-14))==0,'Victim beyond club head is not hit')
check(swingHits(V.new(0,22,-5.8))==0,'Victim high above club is not hit')
print('PASS Sahur club: '..checks..' checks (native FK, capsule/OBB sweep, original-rig active window)')
