-- Run with Lune. Native imported joint baselines and real CFrames validate the
-- authored clip's club direction, rigid imported mesh and grounded stance.
-- These checks do not replace visual evaluation in Roblox Studio.
local fs=require('@lune/fs')
local roblox=require('@lune/roblox')
local Environment=require('./helpers/combat_environment')
local V,CF=roblox.Vector3,roblox.CFrame
local checks=0
local function check(value,message) checks+=1;assert(value,message) end
local env=Environment.new()
local clip=env:Execute('src/shared/SahurAttackClip.luau')
local settings=env:Execute('src/shared/SahurBossSettings.luau')
local asset=roblox.deserializeModel(fs.readFile('assets/creatures/SahurBoss.rbxm'))[1]
local motors={}
for _,item in asset:GetDescendants() do if item:IsA('Motor6D') then motors[item.Part1]=item end end
local function frame(part,pose)
    if part==asset.HumanoidRootPart then return CF.new() end
    local joint=assert(motors[part])
    return frame(joint.Part0,pose)*joint.C0*(pose[joint.Name] or CF.new())*joint.C1:Inverse()
end
local function distance(a,b)
    local aa,bb={a:GetComponents()},{b:GetComponents()}
    local total=0
    for index=1,12 do total+=math.abs(aa[index]-bb[index]) end
    return total
end
local identity=CF.new()
local start,finish=clip.ContactWindow(settings)
local duration=clip.Duration(settings)
check(start==settings.Windup and finish==settings.Windup+settings.Strike,
    'Contact window exactly matches the authoritative strike phase')
check(duration==settings.Windup+settings.Strike+settings.Recovery,'Server timing scales the entire authored clip')
local baseArm=frame(asset.RightUpperArm,{})
-- Physical contact endpoints decoded from the actual native collision hulls.
local clubA=V.new(1.33724,-3.50476,-1.02899)
local clubB=V.new(3.04527,-6.87912,-2.64579)
local function club(pose)
    local transform=frame(asset.RightUpperArm,pose)*baseArm:Inverse()
    return transform:PointToWorldSpace(clubA),transform:PointToWorldSpace(clubB)
end
local poses=clip.Keyframes(settings)
local maxFootDrift,maxFootTilt,maxCompoundDrift=0,0,0
local finite,complete,locked=true,true,true
local baseRelative={}
for _,part in {asset.RightLowerArm,asset.RightHand} do
    baseRelative[part]=baseArm:ToObjectSpace(frame(part,{}))
end
local lowestTip=math.huge
for index=0,80 do
    local current=clip.Sample(duration*index/80,settings)
    local count=0
    for _,joint in clip.Joints do
        local value=current[joint];complete=complete and typeof(value)=='CFrame'
        if value then
            count+=1
            for _,component in {value:GetComponents()} do
                finite=finite and component==component and math.abs(component)<20
            end
        end
    end
    complete=complete and count==15
    locked=locked and distance(current.RightElbow,identity)<1e-6 and distance(current.RightWrist,identity)<1e-6
    for _,foot in {asset.RightFoot,asset.LeftFoot} do
        local actual=frame(foot,current)
        local base=frame(foot,{})
        maxFootDrift=math.max(maxFootDrift,(actual.Position-base.Position).Magnitude)
        maxFootTilt=math.max(maxFootTilt,distance(actual.Rotation,base.Rotation))
    end
    local arm=frame(asset.RightUpperArm,current)
    for part,relative in pairs(baseRelative) do
        maxCompoundDrift=math.max(maxCompoundDrift,distance(arm:ToObjectSpace(frame(part,current)),relative))
    end
    local _,tip=club(current);lowestTip=math.min(lowestTip,tip.Y)
end
check(finite and complete,'Every sample contains all fifteen finite, bounded native joint offsets')
check(locked and maxCompoundDrift<.0001,
    'Club remains an intact rigid compound despite the imported split across shoulder, forearm and hand')
check(maxFootDrift<.0001 and maxFootTilt<.0001,
    'Native ankle positions and horizontal soles stay planted throughout authored weight transfer')
local rear=clip.Sample(settings.Windup*.82,settings)
local _,drawTip=club(rear)
check(drawTip.Y>2 and drawTip.Z>0,'Loaded club is visibly raised behind the shoulder before commitment')
local firstTip,previousY
local descending=true
local nearestTorso=math.huge
local maxForward=0
for index=0,20 do
    local _,tip=club(clip.Sample(start+(finish-start)*index/20,settings))
    if firstTip==nil then firstTip=tip end
    if previousY then descending=descending and tip.Y<previousY+.001 end
    previousY=tip.Y
    maxForward=math.max(maxForward,-tip.Z)
    local target=V.new(0,-4.2,-5.8)
    nearestTorso=math.min(nearestTorso,(tip-target).Magnitude)
end
check(descending and firstTip.Y-previousY>7,
    'Active club head swings downward from raised windup instead of the former low-to-high uppercut')
check(maxForward>6 and nearestTorso<2.4,
    'Actual heavy end crosses the opponent torso height in front of Sahur within melee reach')
local _,restTip=club(clip.Sample(0,settings))
check(lowestTip>restTip.Y-.15,'Follow-through does not drive the bat significantly below its original ground clearance')
check(rear.Root.Position.Z>.05 and clip.Sample(start+settings.Strike*.5,settings).Root.Position.Z<-.1,
    'Body loads backward and transfers forward through contact while both feet retain their support')
local headLooks=true
for _,time in {settings.Windup*.82,start,start+settings.Strike*.5,finish} do
    local head=frame(asset.Head,clip.Sample(time,settings))
    headLooks=headLooks and head.LookVector:Dot(-V.zAxis)>.98
end
check(headLooks,'Free neck counter-rotation keeps the face tracking the committed opponent')
local continuous=true
for _,key in poses do
    local before=clip.Sample(key.Time-1e-6,settings)
    local after=clip.Sample(key.Time+1e-6,settings)
    for _,joint in clip.Joints do continuous=continuous and distance(before[joint],after[joint])<.002 end
end
check(continuous,'Authored key poses and phase boundaries have no positional or rotational snaps')
local function tipAt(time)
    local _,tip=club(clip.Sample(time,settings));return tip
end
local function velocity(time,offset)
    local h=.0001
    return (tipAt(time+offset+h)-tipAt(time+offset-h))/(2*h)
end
check(velocity(start,0).Magnitude>35 and velocity(finish,0).Magnitude>12,
    'Club retains momentum through both edges of the hit window rather than stopping at each key pose')
local continuousVelocity=true
for _,time in {start,start+settings.Strike*.45,finish} do
    continuousVelocity=continuousVelocity and (velocity(time,-.0002)-velocity(time,.0002)).Magnitude<2
end
check(continuousVelocity,'Contact key interpolation carries continuous club velocity across authored joins')
check(distance(clip.Sample(0,settings).Root,clip.Sample(duration,settings).Root)<1e-6,
    'Recovery finishes at the same stance as the authored ready pose')
local deterministic=true
local original=clip.Sample(.31,settings)
clip.Sample(500,settings);clip.Sample(-20,settings)
for _,joint in clip.Joints do deterministic=deterministic and distance(original[joint],clip.Sample(.31,settings)[joint])<1e-6 end
check(deterministic,'Clip does not depend on time of day, previous samples or breathing phase')
local names={};local exactExport=true
local maxBakeFootDrift,maxBakeTipError=0,0
for index,key in poses do
    names[key.Name]=true
    local exact=clip.Sample(key.Time,settings)
    for _,joint in clip.Joints do exactExport=exactExport and distance(key.Pose[joint],exact[joint])<1e-6 end
    exactExport=exactExport and key.EasingStyle=='Linear' and key.EasingDirection=='InOut'
    if index<#poses then
        local next=poses[index+1]
        local middle=(key.Time+next.Time)*.5
        local interpolated={}
        for _,joint in clip.Joints do interpolated[joint]=key.Pose[joint]:Lerp(next.Pose[joint],.5) end
        local _,bakedTip=club(interpolated)
        maxBakeTipError=math.max(maxBakeTipError,(bakedTip-tipAt(middle)).Magnitude)
        for _,foot in {asset.RightFoot,asset.LeftFoot} do
            maxBakeFootDrift=math.max(maxBakeFootDrift,(frame(foot,interpolated).Position-frame(foot,{}).Position).Magnitude)
        end
    end
end
check(exactExport and names.ClubBehindShoulder and names.ContactStarts and names.ContactEnds,
    'Editable keyframes contain the same sampled runtime poses and named contact markers')
check(maxBakeTipError<.03 and maxBakeFootDrift<.015,
    ('120 Hz editable bake follows runtime: tip error %.4f studs, foot drift %.4f studs')
        :format(maxBakeTipError,maxBakeFootDrift))
local faster={Windup=.40,Strike=.16,Recovery=.45}
local first,last=clip.ContactWindow(faster)
check(first==.40 and last==.56 and math.abs(clip.Duration(faster)-1.01)<1e-8,
    'Tuning the three phase durations preserves the clip contact contract')
print(('PASS Sahur authored attack: %d checks; native foot drift %.6f; bake tip error %.4f studs, foot drift %.4f studs')
    :format(checks,maxFootDrift,maxBakeTipError,maxBakeFootDrift))
