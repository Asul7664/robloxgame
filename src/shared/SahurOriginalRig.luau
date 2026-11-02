-- Adapter for our own skinned FBX. Rest frames are captured from the actual
-- Studio import; no dependency on FBX axis conventions or the old auto-rigger.
local Rig = {}
local I=CFrame.new()
local function angle(x,y,z) return CFrame.Angles(math.rad(x or 0),math.rad(y or 0),math.rad(z or 0)) end
function Rig.Capture(model)
    local root=model:FindFirstChild('HumanoidRootPart')
    if not root then return nil end
    local rig={Root=root,Original=true,Bones={},Order={},Scale=model:GetAttribute('QCSahurUnit') or 1}
    for _,bone in model:GetDescendants() do
        if bone:IsA('Bone') then
            if rig.Bones[bone.Name] then return nil end
            rig.Bones[bone.Name]={Bone=bone,Base=bone.CFrame,
                Basis=root.CFrame:ToObjectSpace(bone.WorldCFrame).Rotation}
        end
    end
    for _,name in {'Root','Body','UpperArm.R','Forearm.R','Hand.R','Club','ClubTip',
        'UpperArm.L','Forearm.L','Thigh.R','Shin.R','Foot.R','Thigh.L','Shin.L','Foot.L'} do
        if not rig.Bones[name] then return nil end
    end
    local function append(bone)
        if bone.Done then return true end
        if bone.Visiting then return false end
        bone.Visiting=true
        local parent=rig.Bones[bone.Bone.Parent.Name]
        if parent and not append(parent) then return false end
        bone.Parent=parent
        if not parent then bone.Mesh=root.CFrame:ToObjectSpace(bone.Bone.Parent.CFrame) end
        bone.Done=true;table.insert(rig.Order,bone);return true
    end
    for _,bone in pairs(rig.Bones) do if not append(bone) then return nil end end
    return rig
end
-- Anatomical rotations are expressed in root axes, then converted into each
-- imported bone's rest axes. This also supports differently oriented FBX imports.
function Rig.Offset(rig,name,pose)
    local bone=rig.Bones[name]
    local offset=pose[name] or I
    return bone.Basis:Inverse()*offset*bone.Basis
end
function Rig.Segments(rig,rootFrame,pose)
    local frames={}
    for _,bone in rig.Order do
        frames[bone]= (bone.Parent and frames[bone.Parent] or rootFrame*bone.Mesh)
            *bone.Base*Rig.Offset(rig,bone.Bone.Name,pose)
    end
    local a=frames[rig.Bones.Club].Position
    local b=frames[rig.Bones.ClubTip].Position
    return {{A=a:Lerp(b,.12),B=a:Lerp(b,.65),Radius=.17*rig.Scale},
        {A=a:Lerp(b,.65),B=b,Radius=.27*rig.Scale}}
end
local KEYS={
    -- time fraction, shoulder pitch/yaw/roll, elbow, wrist, body pitch/yaw
    {0,0,0,5,8,0,0,0}, {.18,25,-8,14,30,-6,-3,-8},
    {.52,95,-20,20,72,-12,-6,-24}, {.82,140,-28,22,80,-15,-8,-35},
    {1,110,-12,10,46,-8,0,-12}, {1.45,48,12,-12,20,6,12,24},
    {2,8,25,-30,12,12,15,37}, {2.2,-5,32,-46,15,10,12,38},
    {2.65,0,10,-8,12,2,4,12}, {3,0,0,5,8,0,0,0},
}
function Rig.Attack(elapsed,settings)
    local times={}
    for index,key in KEYS do
        local t=key[1]
        times[index]=t<=1 and t*settings.Windup or (t<=2
            and settings.Windup+(t-1)*settings.Strike
            or settings.Windup+settings.Strike+(t-2)*settings.Recovery)
    end
    elapsed=math.clamp(elapsed,0,times[#times])
    local index=1
    while index<#KEYS-1 and elapsed>times[index+1] do index+=1 end
    local function tangent(i,axis)
        if i==1 or i==#KEYS then return 0 end
        local previous=(KEYS[i][axis]-KEYS[i-1][axis])/(times[i]-times[i-1])
        local next=(KEYS[i+1][axis]-KEYS[i][axis])/(times[i+1]-times[i])
        if previous*next<=0 then return 0 end
        return 2*previous*next/(previous+next)
    end
    local dt=times[index+1]-times[index]
    local t=(elapsed-times[index])/dt;local t2,t3=t*t,t*t*t
    local p={}
    for axis=2,8 do
        p[axis]=(2*t3-3*t2+1)*KEYS[index][axis]+(t3-2*t2+t)*dt*tangent(index,axis)
            +(-2*t3+3*t2)*KEYS[index+1][axis]+(t3-t2)*dt*tangent(index+1,axis)
    end
    return {Body=angle(p[7],p[8],0),['UpperArm.R']=angle(p[2],p[3],p[4]),
        ['Forearm.R']=angle(p[5]),['Hand.R']=angle(p[6]),
        ['UpperArm.L']=angle(-p[2]*.22,-p[3]*.35,-12),['Forearm.L']=angle(18+p[5]*.4)}
end
function Rig.Sample(now,attackAt,settings,motion)
    motion=motion or {}
    local elapsed=type(attackAt)=='number' and now-attackAt or -1
    if elapsed>=0 and elapsed<settings.Windup+settings.Strike+settings.Recovery then
        return Rig.Attack(elapsed,settings)
    end
    local w=math.clamp(motion.Weight or 0,0,1)
    local phase=motion.Phase or 0
    local stride=math.sin(phase)*26*w
    local out={Body=angle(3*w,math.sin(phase)*3*w,math.cos(phase)*1.5*w),
        ['Thigh.R']=angle(stride),['Thigh.L']=angle(-stride),
        ['Shin.R']=angle(-math.max(0,-math.sin(phase))*42*w),
        ['Shin.L']=angle(-math.max(0,math.sin(phase))*42*w),
        ['Foot.R']=angle(-stride*.3),['Foot.L']=angle(stride*.3),
        ['UpperArm.R']=angle(-stride*.25,0,5),['Forearm.R']=angle(8),
        ['UpperArm.L']=angle(stride*.55,0,-5),['Forearm.L']=angle(12)}
    if motion.Emerging then
        out['Thigh.R']=angle(30);out['Thigh.L']=angle(30)
        out['Shin.R']=angle(-55);out['Shin.L']=angle(-55)
    end
    return out
end
return Rig
