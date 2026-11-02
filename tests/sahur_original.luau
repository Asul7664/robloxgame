-- Real CFrames with explicit imported Bone rest frames. No Studio mesh/physics emulation.
local R=require('@lune/roblox')
local fs=require('@lune/fs')
local luau=require('@lune/luau')
local Environment=require('./helpers/combat_environment')
local env=Environment.new()
local Rig=env:Execute('src/shared/SahurOriginalRig.luau')
local settings=luau.load(fs.readFile('src/shared/SahurBossSettings.luau'))()
local CF,V=R.CFrame,R.Vector3
local checks=0
local function check(ok,message)checks+=1;assert(ok,message)end
local function close(a,b,message)check((a-b).Magnitude<.0001,message)end
local model=env:Node('Model','OriginalSahur',env.World)
model:SetAttribute('QCSahurOriginal',true);model:SetAttribute('QCSahurUnit',1)
local root=env:Node('Part','HumanoidRootPart',model);root.CFrame=CF.new(0,4.5,0)
local mesh=env:Node('MeshPart','OriginalSahurSkin',model);mesh.CFrame=CF.new()
local bones={}
local function bone(name,parent,position)
    local item=env:Node('Bone',name,parent and bones[parent] or mesh)
    local rotation=CF.Angles(.27,.19,-.13)
    item.WorldCFrame=CF.new(position)*rotation
    item.CFrame=item.Parent.CFrame:Inverse()*item.WorldCFrame
    if parent then item.CFrame=bones[parent].WorldCFrame:Inverse()*item.WorldCFrame end
    item.Transform=CF.new();bones[name]=item;return item
end
bone('Root',nil,V.new(0,.16,0));bone('Body','Root',V.new(0,3.05,0))
for _,side in {'R','L'} do
    local s=side=='R' and 1 or -1
    bone('UpperArm.'..side,'Body',V.new(s,5.15,.025))
    bone('Forearm.'..side,'UpperArm.'..side,V.new(s*1.26,4.3,-.01))
    bone('Hand.'..side,'Forearm.'..side,V.new(s*1.25,3.5,-.225))
    bone('Thigh.'..side,'Body',V.new(s*.43,3.08,.035))
    bone('Shin.'..side,'Thigh.'..side,V.new(s*.48,1.73,-.035))
    bone('Foot.'..side,'Shin.'..side,V.new(s*.49,.47,.025))
end
bone('Club','Hand.R',V.new(1.25,3.3,-.42))
bone('ClubTip','Club',V.new(2.5,.18,-.60))
local rig=Rig.Capture(model)
check(rig and rig.Original,'Own bone skeleton is captured')
local resting=Rig.Segments(rig,root.CFrame,{})
close(resting[2].B,bones.ClubTip.WorldCFrame.Position,'Rest club tip matches actual imported marker')
local function independentFrame(item,pose)
    if item==mesh then return mesh.CFrame end
    return independentFrame(item.Parent,pose)*item.CFrame*Rig.Offset(rig,item.Name,pose)
end
local total=settings.Windup+settings.Strike+settings.Recovery
local previous
for sample=0,240 do
    local t=total*sample/240
    local pose=Rig.Attack(t,settings)
    local visible=Rig.Sample(100+t,100,settings,{})
    if sample<240 then
        for name,offset in pairs(pose) do
            close(offset.Position,visible[name].Position,'Renderer and server use one translation curve')
            close(offset.LookVector,visible[name].LookVector,'Renderer and server use one rotation curve')
        end
    end
    local segments=Rig.Segments(rig,root.CFrame,pose)
    close(segments[2].B,independentFrame(bones.ClubTip,pose).Position,'Damage FK matches nested Bone transforms')
    local moved=CF.new(20,15,-30)*CF.Angles(0,.7,0)
    local world=Rig.Segments(rig,moved,pose)
    close(world[2].B,(moved*root.CFrame:Inverse()):PointToWorldSpace(segments[2].B),'Facing/moving the boss transforms its exact club')
    for _,segment in segments do
        check(segment.Radius>0 and segment.Radius<.5,'Only the actual narrow shaft/head inflict damage')
        for _,n in {segment.A.X,segment.A.Y,segment.A.Z,segment.B.X,segment.B.Y,segment.B.Z} do
            check(n==n and math.abs(n)<100,'Bone FK remains finite')
        end
    end
    if previous then check((segments[2].B-previous).Magnitude<1.5,'Strike has no large frame-to-frame teleport') end
    previous=segments[2].B
end
for _,t in {settings.Windup*.18,settings.Windup*.52,settings.Windup*.82,
    settings.Windup,settings.Windup+settings.Strike*.45,settings.Windup+settings.Strike,
    settings.Windup+settings.Strike+settings.Recovery*.2} do
    local before=Rig.Segments(rig,root.CFrame,Rig.Attack(t-1e-7,settings))
    local after=Rig.Segments(rig,root.CFrame,Rig.Attack(t+1e-7,settings))
    close(before[2].B,after[2].B,'Exact authored phase boundary is continuous')
end
local elbow=Rig.Attack(settings.Windup*.7,settings)['Forearm.R']
check(elbow.LookVector:Dot(V.new(0,0,-1))<.8,'Own independent club permits a real elbow bend')
local missing=bones.ClubTip;missing.Parent=nil
check(Rig.Capture(model)==nil,'Missing club marker rejects installation rather than using old hit volumes')
missing.Parent=bones.Club
local duplicate=bone('ClubTip','Club',V.new(1,1,1))
check(Rig.Capture(model)==nil,'Duplicate skeleton names are rejected')
duplicate:Destroy()
-- Execute the real installer with service doubles: keep the previous working
-- template on validation failure, replace both boss/catch only on success.
local shared=env:Node('Folder','QuietCove',env.Replicated)
env:Node('ModuleScript','SahurOriginalRig',shared)
env.Globals.require=function(module) assert(module.Name=='SahurOriginalRig');return Rig end
env.Run.IsStudio=function()return true end
env.Run.IsRunning=function()return false end
env.Services.Selection={Get=function()return {model}end}
env.Globals.print=function()end
local installer=env:Execute('src/server/SahurStudioInstall.luau')
local old=env:Node('Model','SahurBoss',env.Services.ServerStorage)
local assets=env:Node('Folder','CreatureAssets',shared)
local oldCatch=env:Node('Model','sahur',assets)
local verified,report=installer.Verify()
check(not verified and report:find('наша Blender%-модель не установлена')~=nil,
    'Old imported templates cannot pass the original model diagnostic')
root:Destroy();mesh.Size=V.new(5,12,2)
model.GetScale=function()return 1 end
model.ScaleTo=function(_,scale)check(scale==1,'Already normalized import is not scaled twice')end
model.PivotTo=function(self,frame)self.TestPivot=frame end
local tip=model:FindFirstChild('ClubTip',true);tip.Name='MissingTip'
local ok=pcall(installer.OriginalSelected)
check(not ok and old.Parent==env.Services.ServerStorage and oldCatch.Parent==assets,
    'Invalid replacement preserves both working templates')
tip.Name='ClubTip'
bone('Facing','Root',V.new(0,.16,-1))
local installed=installer.OriginalSelected()
check(installed.Parent==env.Services.ServerStorage and installed.Name=='SahurBoss','Own model becomes the active boss')
check(installed:GetAttribute('QCSahurOriginal')==true and assets.sahur:GetAttribute('QCSahurOriginal')==true,
    'Boss and inventory presentation use our own model')
check(old.Parent.Name=='QCSahurBackups' and oldCatch.Parent==old.Parent,'Previous templates are archived')
check(model.Parent==old.Parent,'Source import is archived rather than left as duplicate in Workspace')
check(installed:FindFirstChildOfClass('Humanoid').RequiresNeck==false,'Custom skin does not depend on an R15 neck motor')
check(Rig.Capture(installed)~=nil,'Installed model passes the actual adapter')
verified,report=installer.Verify()
check(verified and report:find('оба установленных шаблона')~=nil,'Verifier checks both active templates after installation')
check(installed:GetAttribute('QCSahurSource')=='OriginalSahur.blend'
    and assets.sahur:GetAttribute('QCSahurSource')=='OriginalSahur.blend','Both installed templates retain source provenance')
local installedTip=installed:FindFirstChild('ClubTip',true)
installedTip.Name='MissingClubTip'
verified,report=installer.Verify()
check(not verified and report:find('ServerStorage.SahurBoss')~=nil,'Original marker flag alone cannot hide a broken boss skeleton')
installedTip.Name='ClubTip'
local catch=assets.sahur
catch:SetAttribute('QCSahurOriginal',false)
verified,report=installer.Verify()
check(not verified and report:find('CreatureAssets.sahur')~=nil,'A correct boss cannot hide an old inventory model')
catch:SetAttribute('QCSahurOriginal',true)
local catchHand=catch:FindFirstChild('Hand.R',true)
local handParent=catchHand.Parent
catchHand.Parent=catch:FindFirstChild('Body',true)
verified,report=installer.Verify()
check(not verified and report:find('неверная цепочка костей')~=nil,'Verifier validates bone ancestry rather than names alone')
catchHand.Parent=handParent
check(installer.Verify(),'Restored templates pass read-only verification')
local before=installed
env.Services.Selection.Get=function()return {installed}end
check(not pcall(installer.OriginalSelected) and before.Parent==env.Services.ServerStorage,'Installing an installed model cannot replace itself')
installed.Parent=env.World
local added,removed=Environment.Signal(),Environment.Signal()
env.Services.CollectionService={GetTagged=function()return {installed}end,
    GetInstanceAddedSignal=function()return added end,GetInstanceRemovedSignal=function()return removed end}
env:Node('ModuleScript','SahurBossPose',shared);env:Node('ModuleScript','SahurBossSettings',shared)
env.Globals.require=function(module)
    if module.Name=='SahurOriginalRig' then return Rig end
    if module.Name=='SahurBossSettings' then return settings end
    if module.Name=='SahurBossPose' then return {Sample=function()return {}end} end
    error(module.Name)
end
installed.HumanoidRootPart.AssemblyLinearVelocity=V.new(0,0,-14)
env:Execute('src/client/SahurAnimator.client.luau')
env:Advance(.25)
local rightArm=installed:FindFirstChild('UpperArm.R',true)
check(rightArm.Transform.LookVector:Dot(V.new(0,0,-1))<.9999,'Existing animator drives our actual bones')
installed:SetAttribute('SahurAttackAt',env.Time-settings.Windup)
env:Advance(settings.Strike*.4)
local actualRig=Rig.Capture(installed)
local expected=Rig.Offset(actualRig,'Forearm.R',Rig.Attack(env.Time-installed:GetAttribute('SahurAttackAt'),settings))
close(installed:FindFirstChild('Forearm.R',true).Transform.LookVector,expected.LookVector,
    'Visible elbow follows the exact server contact pose without extra smoothing')
removed:Fire(installed)
for _,item in installed:GetDescendants() do
    if item:IsA('Bone') then close(item.Transform.LookVector,V.new(0,0,-1),'Tag removal resets every bone') end
end
env.ClientScript:Destroy()
check(env.Run.PreSimulation:Count()==0 and added:Count()==0 and removed:Count()==0,'Original rig leaves no render/tag listeners')
print('PASS original Sahur adapter: '..checks..' checks (Bone FK, shared attack timeline, rest axes and rejection)')
