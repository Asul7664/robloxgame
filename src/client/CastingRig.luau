-- Analytic two-bone IK after Animator, not approximate independent arm angles.
-- Both hand grip points are solved against ONE visible rod transform. R15 has elbows/knees;
-- R6 is a single-segment fallback (its rig physically has no elbow/knee joints).
-- Supports both Motor6D and upgraded R15 AnimationConstraint joints. Never edits rig attachments.
local RS=game:GetService('ReplicatedStorage')
local Models=require(RS:WaitForChild('QuietCove'):WaitForChild('EquipmentModels'))
local Cast=require(RS:WaitForChild('QuietCove'):WaitForChild('CastMath'))
local Clearance=require(RS:WaitForChild('QuietCove'):WaitForChild('RodClearance'))
local Rig={};Rig.__index=Rig
local function clamp(x,a,b)return math.max(a,math.min(b,x))end
local function rot(cf)return CFrame.new(cf.Position):Inverse()*cf end
local function deg(x,y,z)return CFrame.Angles(math.rad(x or 0),math.rad(y or 0),math.rad(z or 0))end
-- Bounded R15 fallback for wider avatars: height, forward clearance, yaw.
-- Every candidate still has to satisfy both wrist reaches and all body checks.
local broadCandidates={{0,0,24},{.25,0,0},{0,.15,16},{0,0,32},
    {.25,.15,0},{.40,0,0},{0,.30,16},{0,.15,32},
    {.40,0,8},{.25,.15,-8},{0,.30,24},{.25,.30,0}}
local function basis(axis,ref)
    axis=axis.Unit
    local x=axis:Cross(ref)
    if x.Magnitude<.001 then x=axis:Cross(Vector3.new(1,0,0))end
    if x.Magnitude<.001 then x=axis:Cross(Vector3.new(0,1,0))end
    x=x.Unit;return CFrame.fromMatrix(Vector3.new(),x,axis,x:Cross(axis).Unit)
end
local function segment(localA,localB,worldA,worldB,normal)
    local r=basis(worldB-worldA,normal)*basis(localB-localA,Vector3.new(0,0,1)):Inverse()
    return CFrame.new(worldA)*r*CFrame.new(-localA)
end
local function radialDirection(delta,fallback)
    return delta.Magnitude>.0001 and delta.Unit or fallback.Unit
end
local function circleDirection(delta,axis,fallback)
    local direction=delta-axis*delta:Dot(axis)
    if direction.Magnitude<.0001 then direction=fallback-axis*fallback:Dot(axis)end
    if direction.Magnitude<.0001 then direction=Vector3.yAxis-axis*axis.Y end
    if direction.Magnitude<.0001 then direction=Vector3.xAxis-axis*axis.X end
    return direction.Unit
end
local function reachablePosition(desired,centres,ranges,fallback)
    -- Fixed rod rotation gives two wrist reach shells. Their intersection,
    -- rather than alternating one-arm corrections, must satisfy BOTH hands.
    local tolerance=.0002
    local best,bestDistance
    local function consider(position)
        for i=1,2 do
            local distance=(position-centres[i]).Magnitude
            if distance<ranges[i][1]-tolerance or distance>ranges[i][2]+tolerance then return end
        end
        local distance=(position-desired).Magnitude
        if not bestDistance or distance<bestDistance then best=position;bestDistance=distance end
    end
    consider(desired)
    if best then return best end
    local delta=centres[2]-centres[1]
    local separation=delta.Magnitude
    if separation<.0001 then
        local minimum=math.max(ranges[1][1],ranges[2][1])
        local maximum=math.min(ranges[1][2],ranges[2][2])
        if minimum<=maximum then
            local radius=clamp((desired-centres[1]).Magnitude,minimum,maximum)
            consider(centres[1]+radialDirection(desired-centres[1],fallback)*radius)
        end
        return best
    end
    -- The closest feasible position is either on one boundary sphere or
    -- on a circle where two boundary spheres meet (inner/outer included).
    for i=1,2 do
        for _,radius in ipairs(ranges[i])do
            consider(centres[i]+radialDirection(desired-centres[i],fallback)*radius)
        end
    end
    local axis=delta/separation
    for _,a in ipairs(ranges[1])do for _,b in ipairs(ranges[2])do
        if separation<=a+b+tolerance and separation>=math.abs(a-b)-tolerance then
            local along=(a*a-b*b+separation*separation)/(2*separation)
            local radiusSquared=a*a-along*along
            if radiusSquared>=-tolerance then
                local centre=centres[1]+axis*along
                local radius=math.sqrt(math.max(0,radiusSquared))
                consider(centre+circleDirection(desired-centre,axis,fallback)*radius)
            end
        end
    end end
    return best
end
local function animationJoint(j)
    local a,b=j.Attachment0,j.Attachment1
    if not a or not b or not a.Parent or not b.Parent
        or not a.Parent:IsA('BasePart')or not b.Parent:IsA('BasePart')or j.Enabled==false then return nil end
    -- Read attachments directly instead of deprecated C0/C1 compatibility aliases.
    return setmetatable({Source=j,IsConstraint=true},{
        __index=function(_,key)
            if key=='Part0'then return a.Parent elseif key=='Part1'then return b.Parent
            elseif key=='C0'then return a.CFrame elseif key=='C1'then return b.CFrame end
            return j[key]
        end,
        __newindex=function(_,key,value)
            if key=='Transform'then j.Transform=value else error('Joint adapter writes only Transform')end
        end,
    })
end
local function jointName(part,fallback)
    local names={LowerTorso='Root',UpperTorso='Waist',Head='Neck',Torso='RootJoint'}
    if names[part.Name]then return names[part.Name]end
    for _,side in ipairs({'Right','Left'})do
        if part.Name==side..' Arm'then return side..' Shoulder'end
        if part.Name==side..' Leg'then return side..' Hip'end
        local types={UpperArm='Shoulder',LowerArm='Elbow',Hand='Wrist',UpperLeg='Hip',LowerLeg='Knee',Foot='Ankle'}
        for body,joint in pairs(types)do if part.Name==side..body then return side..joint end end
    end
    return fallback
end
function Rig.new(character,tool,parent)
    local root=character:FindFirstChild('HumanoidRootPart');if not root then return nil end
    local self=setmetatable({Character=character,Root=root,Tool=tool,ByPart={},Joints={},OriginalParts={},Saved={},Weight=0,Cache={},ConstraintStates={},KinematicsActive=false,ElbowDirections={}},Rig)
    -- Two passes make upgraded constraints win when a compatibility Motor6D also exists.
    for _,j in ipairs(character:GetDescendants())do
        if j:IsA('Motor6D')and j.Part0 and j.Part1 then
            self.ByPart[j.Part1]=j;self.Joints[jointName(j.Part1,j.Name)]=j
        end
    end
    for _,j in ipairs(character:GetDescendants())do
        if j:IsA('AnimationConstraint')then
            local view=animationJoint(j)
            if view then
                self.ByPart[view.Part1]=view;self.Joints[jointName(view.Part1,j.Name)]=view
                self.ConstraintStates[#self.ConstraintStates+1]={Joint=j,Original=j.IsKinematic}
            end
        end
    end
    for _,p in ipairs(tool:GetDescendants())do
        if p:IsA('BasePart')then self.OriginalParts[#self.OriginalParts+1]={Part=p,Alpha=p.LocalTransparencyModifier}end
    end
    local wrap=Instance.new('Model');wrap.Name='TwoHandRod';wrap.Parent=parent
    local clone=Models.Rod(tool:GetAttribute('RodStyle')or 'wood',true);clone.Parent=wrap
    local h=clone:FindFirstChild('Handle');wrap.PrimaryPart=h
    self.Visual=wrap;self.Handle=h;self.Tip=h:FindFirstChild('Tip');self.Clone=clone;self.VisibleParts={}
    for _,p in ipairs(clone:GetDescendants())do if p:IsA('BasePart')then
        self.VisibleParts[#self.VisibleParts+1]=p;p.LocalTransparencyModifier=1
    end end
    self.R15=character:FindFirstChild('RightUpperArm')~=nil
    self.RodShapes=Clearance.Describe(clone,h)
    self.BodyParts=Clearance.BodyParts(character)
    self.ArmBodies={}
    for _,part in ipairs(self.BodyParts)do
        if part.Name=='Torso'or part.Name=='UpperTorso'or part.Name=='LowerTorso'or part.Name=='Head'then
            self.ArmBodies[#self.ArmBodies+1]=part
        end
    end
    return self
end
function Rig:_kinematic(active)
    if active==self.KinematicsActive then return end
    self.KinematicsActive=active
    for _,entry in ipairs(self.ConstraintStates)do
        if entry.Joint.Parent then
            if active then entry.Original=entry.Joint.IsKinematic;entry.Joint.IsKinematic=true
            else entry.Joint.IsKinematic=entry.Original end
        end
    end
end
function Rig:Restore()
    for j,v in pairs(self.Saved)do if j.Parent then j.Transform=v end end
    self.Saved={};self.Cache={}
end
function Rig:_world(part)
    if part==self.Root then return self.Root.CFrame end
    if self.Cache[part]then return self.Cache[part]end
    local j=self.ByPart[part]
    local cf=j and self:_world(j.Part0)*j.C0*j.Transform*j.C1:Inverse()or part.CFrame
    self.Cache[part]=cf;return cf
end
function Rig:_set(j,transform,weight)
    if not j then return end
    if not self.Saved[j]then self.Saved[j]=j.Transform end
    j.Transform=self.Saved[j]:Lerp(transform,weight or self.Weight)
    self.Cache={}
end
function Rig:_place(j,cf,weight)
    if not j then return end
    local t=j.C0:Inverse()*self:_world(j.Part0):Inverse()*cf*j.C1
    -- Both arms follow the already blended rod exactly throughout entry.
    self:_set(j,t,weight)
end
function Rig:_clearArm(part,frame)
    for _,body in ipairs(self.ArmBodies)do
        if Clearance.Overlap(frame,part.Size*.5,self:_world(body),body.Size*.5,.02)then return false end
    end
    return true
end
function Rig:_armPenalty(part,frame)
    local penalty=0
    for _,body in ipairs(self.ArmBodies)do
        if Clearance.Overlap(frame,part.Size*.5,self:_world(body),body.Size*.5,.02)then
            local relative=self:_world(body):ToObjectSpace(frame)
            local half=part.Size*.5
            local extent=math.abs(relative.RightVector.Z)*half.X
                +math.abs(relative.UpVector.Z)*half.Y+math.abs(relative.LookVector.Z)*half.Z
            penalty+=math.max(.01,body.Size.Z*.5+extent+relative.Position.Z)
        end
    end
    return penalty
end
function Rig:_solveLimb(shoulder,elbow,wrist,handCF,pole,side,stage,recovery)
    if not shoulder or not elbow or not wrist then return end
    local S=(self:_world(shoulder.Part0)*shoulder.C0).Position
    local target=(handCF*wrist.C1).Position
    local a=(elbow.C0.Position-shoulder.C1.Position).Magnitude
    local b=(wrist.C0.Position-elbow.C1.Position).Magnitude
    if a<.01 or b<.01 then return end
    local delta=target-S;local dist=delta.Magnitude;if dist<.001 then return end
    local d=clamp(dist,math.abs(a-b)+.002,a+b-.002)
    local axis=delta.Unit;local T=S+axis*d
    local bend=pole-S-axis*(pole-S):Dot(axis)
    if bend.Magnitude<.001 then bend=self.Root.CFrame.LookVector-axis*self.Root.CFrame.LookVector:Dot(axis)end
    if bend.Magnitude<.001 then bend=Vector3.new(0,1,0):Cross(axis)end
    bend=bend.Unit
    local along=(a*a-b*b+d*d)/(2*d)
    local height=math.sqrt(math.max(0,a*a-along*along))
    local palm=CFrame.new(T)*rot(handCF)*CFrame.new(-wrist.C1.Position)
    if side and not recovery and not self:_clearArm(wrist.Part1,palm)then return nil end
    local previous=side and self.ElbowDirections[side]
    if previous then
        previous=self.Root.CFrame:VectorToWorldSpace(previous)
        previous=previous-axis*previous:Dot(axis)
        previous=previous.Magnitude>.0001 and previous.Unit or nil
    end
    local function solve(direction)
        local E=S+axis*along+direction*height
        local localElbow=self.Root.CFrame:PointToObjectSpace(E)
        local localShoulder=self.Root.CFrame:PointToObjectSpace(S)
        local ownSide=not side or localElbow.X*(side=='Right'and 1 or -1)>.02
        local low=not side or (stage~='Waiting'and stage~='Reeling')or localElbow.Y<localShoulder.Y-.02
        if ownSide and low then
            local normal=axis:Cross(direction).Unit
            local upper=segment(shoulder.C1.Position,elbow.C0.Position,S,E,normal)
            local lower=segment(elbow.C1.Position,wrist.C0.Position,E,T,normal)
            if not side or recovery or self:_clearArm(elbow.Part1,lower)then
                return {Shoulder=upper,Elbow=lower,Wrist=palm,Bend=self.Root.CFrame:VectorToObjectSpace(direction),
                    ContactPenalty=recovery and (self:_armPenalty(elbow.Part1,lower)+self:_armPenalty(wrist.Part1,palm))or 0}
            end
        end
    end
    -- Normally the preferred pole is already safe. After a correction, move
    -- gradually back toward it instead of switching elbow-circle branches.
    local preferred=previous and previous:Lerp(bend,self.ElbowAlpha or 1)or bend
    preferred=radialDirection(preferred,bend)
    if recovery then
        -- MeshPart boxes can overlap even when the visible mesh does not.
        -- Rank those boxes instead of dropping both hands and the cast.
        local best,bestCost
        local reference=previous or bend
        local limited=previous~=nil
        local function consider(direction)
            if limited and direction:Dot(previous)<math.cos(math.rad(20))then return end
            local pose=solve(direction)
            if pose then
                local cost=pose.ContactPenalty*8+(1-direction:Dot(reference))
                if not bestCost or cost<bestCost then best=pose;bestCost=cost end
            end
        end
        consider(preferred)
        if previous then consider(previous)end
        for _,angle in ipairs({0,15,-15,30,-30,45,-45,60,-60,90,-90,120,-120,150,-150,180})do
            local radians=math.rad(angle)
            consider(bend*math.cos(radians)+axis:Cross(bend)*math.sin(radians))
        end
        if not best and limited then
            -- Only the shoulder-side/height rules may require another arc;
            -- overlapping mesh boxes alone must not make the elbow jump.
            limited=false
            for _,angle in ipairs({0,15,-15,30,-30,45,-45,60,-60,90,-90,120,-120,150,-150,180})do
                local radians=math.rad(angle)
                consider(bend*math.cos(radians)+axis:Cross(bend)*math.sin(radians))
            end
        end
        return best
    end
    local pose=solve(preferred)
    if pose then return pose end
    if previous then pose=solve(previous);if pose then return pose end end
    if previous then
        -- A narrow safe arc next to the previous elbow can fall between the
        -- coarse authored samples. Search it before considering another arc.
        for _,angle in ipairs({2,-2,4,-4,6,-6,8,-8,10,-10,12,-12,15,-15,18,-18,20,-20})do
            local radians=math.rad(angle)
            local direction=previous*math.cos(radians)+axis:Cross(previous)*math.sin(radians)
            pose=solve(direction)
            if pose then return pose end
        end
    end
    local best,bestScore
    local reference=previous or bend
    for _,angle in ipairs({0,15,-15,30,-30,45,-45,60,-60,90,-90,120,-120,150,-150,180})do
        local radians=math.rad(angle)
        local direction=bend*math.cos(radians)+axis:Cross(bend)*math.sin(radians)
        local score=direction:Dot(reference)
        -- Reject a different elbow-circle branch before accepting the rod.
        -- A nearby rod position can keep both hands on the same safe branch.
        if (not previous or score>=math.cos(math.rad(20)))and (not bestScore or score>bestScore)then
            pose=solve(direction)
            if pose then best=pose;bestScore=score end
        end
    end
    return best
end
function Rig:_armPole(side,stage)
    local shoulder,elbow=self.Joints[side..'Shoulder'],self.Joints[side..'Elbow']
    local scale=(elbow.C0.Position-shoulder.C1.Position).Magnitude/1.2
    if side=='Right'then
        -- Start at the actual shoulder: multiplying a root-local X by arm
        -- length used to move the pole INSIDE a wide avatar's chest.
        local origin=(self:_world(shoulder.Part0)*shoulder.C0).Position
        return origin+self.Root.CFrame:VectorToWorldSpace(Vector3.new(.65,-.70,-1.85)*scale)
    end
    -- Stage-specific rod targets drive the cast. Keep both elbow preferences
    -- in front throughout instead of pulling a charging elbow behind the chest.
    local right,left=Vector3.new(1.55,.55,-1.60),Vector3.new(-1.25,.45,-1.50)
    return self.Root.CFrame*((side=='Right'and right or left)*scale)
end
function Rig:_grasp(side,rodCF)
    local name=side=='Right' and 'CastMainGrip' or 'CastSupportGrip'
    local target=self.Handle and self.Handle:FindFirstChild(name)
    local fallback=CFrame.new(0,side=='Right' and -0.25 or 0.25,0)*deg(0,0,side=='Right' and -65 or 65)
    -- Actual rod attachments are the single source of truth for BOTH hands.
    return rodCF*(target and target.CFrame or fallback)
end
function Rig:_grip(side,rodCF)
    local hand=self.Character:FindFirstChild(side..'Hand')
    local attach=hand and hand:FindFirstChild(side..'GripAttachment')
    local localGrip=attach and attach.CFrame or CFrame.new(0,-.18,0)
    return self:_grasp(side,rodCF)*localGrip:Inverse()
end
function Rig:_fitRod(rodCF)
    -- Reach-aware translation; no stretching bones on scaled avatars.
    local centres,ranges={},{}
    if not self.R15 then
        -- R6 has no elbow: fit both rigid arm endpoints to their rod grips.
        -- The handle centre lies on the intersection of two reach spheres.
        for _,side in ipairs({'Right','Left'})do
            local j=self.Joints[side..' Shoulder']
            if not j then return nil end
            local S=(self:_world(j.Part0)*j.C0).Position
            local localEnd=Vector3.new(0,-j.Part1.Size.Y*.46,0)
            local length=(localEnd-j.C1.Position).Magnitude
            ranges[#ranges+1]={length,length}
            centres[#centres+1]=S-(self:_grasp(side,rodCF).Position-rodCF.Position)
        end
    else
        for _,side in ipairs({'Right','Left'})do
            local a,b,c=self.Joints[side..'Shoulder'],self.Joints[side..'Elbow'],self.Joints[side..'Wrist']
            if not a or not b or not c then return nil end
            local S=(self:_world(a.Part0)*a.C0).Position
            local T=(self:_grip(side,rodCF)*c.C1).Position
            local upper=(b.C0.Position-a.C1.Position).Magnitude
            local lower=(c.C0.Position-b.C1.Position).Magnitude
            if upper<.01 or lower<.01 then return nil end
            -- Leave a bend at each elbow; the IK solver must never clamp a
            -- target away from the visible grip, including at entry Weight<1.
            local margin=math.min(.025,math.min(upper,lower)*.1)
            ranges[#ranges+1]={math.abs(upper-lower)+margin,upper+lower-margin}
            centres[#centres+1]=S-(T-rodCF.Position)
        end
    end
    local position=reachablePosition(rodCF.Position,centres,ranges,self.Root.CFrame.LookVector)
    return position and CFrame.new(position)*rot(rodCF)or nil
end

function Rig:_safeRod(desired,finalPose,stage)
    local root=self.Root.CFrame
    local desiredLocal=root:ToObjectSpace(desired)
    if self.RodCacheStage~=stage then
        self.RodCacheStage=stage;self.LastDesiredLocal=nil;self.RodCorrectionLocal=nil
    end
    local previousDesired,correction=self.LastDesiredLocal,self.RodCorrectionLocal
    local function accepted(candidate,poses,recovery)
        -- Record only the final jointly safe result, never a rejected trial.
        self.LastDesiredLocal=desiredLocal
        self.RodCorrectionLocal=root:ToObjectSpace(candidate)*desiredLocal:Inverse()
        self.ArmContactFallback=recovery==true
        self.Visual:SetAttribute('PoseStatus',recovery and 'TwoHandMeshFallback'or 'TwoHand')
        return candidate,poses
    end
    local function safe(candidate,recovery)
        candidate=self:_fitRod(candidate)
        if candidate and Clearance.Check(candidate,self.RodShapes,self.BodyParts,function(part)return self:_world(part)end,.06)then
            local poses={}
            if self.R15 then
                for _,side in ipairs({'Right','Left'})do
                    poses[side]=self:_solveLimb(self.Joints[side..'Shoulder'],self.Joints[side..'Elbow'],self.Joints[side..'Wrist'],
                        self:_grip(side,candidate),self:_armPole(side,stage),side,stage,recovery)
                    if not poses[side]then return nil end
                end
            end
            return candidate,poses
        end
    end
    local fitted,poses
    if self.ArmContactFallback then
        -- Once a mesh needs this path, do not repeat the failed box search
        -- every frame. Reach and complete rod/body clearance still run.
        local corrected=correction and correction:Lerp(CFrame.new(),self.ElbowAlpha or 1)or CFrame.new()
        fitted,poses=safe(root*corrected*desiredLocal,true)
        if fitted then return accepted(fitted,poses,true)end
    end
    if previousDesired and self.LastRodLocal
        and (desiredLocal.Position-previousDesired.Position).Magnitude<.00001
        and (desiredLocal.RightVector-previousDesired.RightVector).Magnitude<.00001
        and (desiredLocal.UpVector-previousDesired.UpVector).Magnitude<.00001 then
        -- A stationary target needs one full recheck, not the same search
        -- every frame. Body motion still goes through all existing guards.
        fitted,poses=safe(root*self.LastRodLocal)
        if fitted then return accepted(fitted,poses)end
    end
    if stage=='Charging'and previousDesired and correction
        and (desiredLocal.Position-previousDesired.Position).Magnitude<.15
        and (desiredLocal.RightVector-previousDesired.RightVector).Magnitude<.09
        and (desiredLocal.UpVector-previousDesired.UpVector).Magnitude<.09 then
        -- Reuse the preceding root-local clearance correction while charge
        -- changes slowly. Remove it gradually, so a newly feasible authored
        -- target cannot suddenly jump back from the corrected pose.
        local relaxed=correction:Lerp(CFrame.new(),self.ElbowAlpha or 1)
        fitted,poses=safe(root*relaxed*desiredLocal)
        if fitted then return accepted(fitted,poses)end
        fitted,poses=safe(root*correction*desiredLocal)
        if fitted then return accepted(fitted,poses)end
    end
    fitted,poses=safe(desired)
    if fitted then return accepted(fitted,poses)end
    if self.R15 and self.LastRod then
        -- Small clearance changes should not force the other side of an IK
        -- circle. Probe nearby positions before the larger fallback shifts.
        for _,offset in ipairs({Vector3.new(0,0,-.015),Vector3.new(0,0,-.03),Vector3.new(0,0,-.06),
            Vector3.new(0,0,-.12),Vector3.new(.015,0,0),Vector3.new(-.015,0,0),
            Vector3.new(0,.015,0),Vector3.new(0,-.015,0)})do
            fitted,poses=safe(root*CFrame.new(offset)*desiredLocal)
            if fitted then return accepted(fitted,poses)end
        end
    end
    if finalPose then
        fitted,poses=safe(finalPose)
        if fitted then return accepted(fitted,poses)end
        desired=finalPose
    end
    -- Clearance is evaluated AFTER reach fitting, including the reel and butt.
    local localFrame=root:ToObjectSpace(desired)
    for _,pitch in ipairs({8,16,-8})do
        for _,offset in ipairs({Vector3.new(0,0,-.15),Vector3.new(.22,0,-.15),
            Vector3.new(-.22,0,-.15),Vector3.new(0,.16,-.12),Vector3.new(0,-.16,-.12)})do
            fitted,poses=safe(root*CFrame.new(offset)*localFrame*deg(pitch,0,0))
            if fitted then return accepted(fitted,poses)end
        end
    end
    -- Large torsos also need room for the palm, which an elbow rotation
    -- cannot create. Keep the shift bounded and recheck BOTH reach shells.
    for _,forward in ipairs({.30,.45,.65})do
        for _,pitch in ipairs({0,8,-8})do
            fitted,poses=safe(root*CFrame.new(0,0,-forward)*localFrame*deg(pitch,0,0))
            if fitted then return accepted(fitted,poses)end
        end
    end
    if self.R15 then
        for _,candidate in ipairs(broadCandidates)do
            local position=localFrame.Position+Vector3.new(0,candidate[1],-candidate[2])
            fitted,poses=safe(root*CFrame.new(position)*deg(0,candidate[3],0)*rot(localFrame))
            if fitted then return accepted(fitted,poses)end
        end
    end
    if self.R15 and self.LastRodLocal then
        fitted,poses=safe(root*self.LastRodLocal)
        if fitted then return accepted(fitted,poses)end
    end
    if self.R15 then
        local best,bestPoses,bestCost
        for _,candidate in ipairs({desired,finalPose or desired,
            root*CFrame.new(0,.25,-.15)*root:ToObjectSpace(desired)})do
            local candidateFrame,candidatePoses=safe(candidate,true)
            if candidateFrame then
                local cost=candidatePoses.Right.ContactPenalty+candidatePoses.Left.ContactPenalty
                    +(candidateFrame.Position-desired.Position).Magnitude*.1
                if not bestCost or cost<bestCost then best=candidateFrame;bestPoses=candidatePoses;bestCost=cost end
            end
        end
        if best then return accepted(best,bestPoses,true)end
    end
    return nil
end

function Rig:_deactivate()
    self:Restore();self:_kinematic(false);self.Weight=0
    self.LegTargets=nil;self.LastFrame=nil;self.LastRod=nil;self.PreviousStage=nil;self.Transition=nil
    self.ElbowDirections={};self.EntryRod=nil;self.LastRodLocal=nil
    self.RodCacheStage=nil;self.LastDesiredLocal=nil;self.RodCorrectionLocal=nil
    self.ArmContactFallback=nil
    self.Visual:SetAttribute('PoseStatus','Native')
    for _,o in ipairs(self.OriginalParts)do if o.Part.Parent then o.Part.LocalTransparencyModifier=o.Alpha end end
    for _,part in ipairs(self.VisibleParts)do if part.Parent then part.LocalTransparencyModifier=1 end end
    -- Invisible clone tip follows the native Tool when fishing while moving.
    local actual=self.Tool:FindFirstChild('Handle')
    if actual then self.Visual:PivotTo(actual.CFrame)end
end
function Rig:Step(stage,t,power,config,dt)
    local humanoid=self.Character:FindFirstChildOfClass('Humanoid')
    local velocity=self.Root.AssemblyLinearVelocity or Vector3.zero
    local moving=humanoid and ((humanoid.WalkSpeed or 16)>0 and humanoid.MoveDirection.Magnitude>.05
        or Vector3.new(velocity.X,0,velocity.Z).Magnitude>1)
    local fishing={Charging=true,Casting=true,Waiting=true,Bite=true,Reeling=true,Landing=true}
    local active=self.Tool.Parent==self.Character and fishing[stage]==true and humanoid
        and humanoid.Health>0 and not humanoid.Sit and not moving
    if not active then self:_deactivate();return false end
    local alpha=1-math.exp(-7*dt)
    self.Weight=self.Weight+((active and 1 or 0)-self.Weight)*alpha
    local shown=self.Weight>.008
    self:_kinematic(shown)
    for _,o in ipairs(self.OriginalParts)do if o.Part.Parent then o.Part.LocalTransparencyModifier=shown and 1 or o.Alpha end end
    for _,p in ipairs(self.VisibleParts)do if p.Parent then p.LocalTransparencyModifier=shown and 0 or 1 end end
    if not shown then self.LegTargets=nil;self.LastFrame=nil;self.PreviousStage=nil;self.Transition=nil;return false end
    self.Cache={}
    self.ElbowAlpha=1-math.exp(-12*dt)
    local f=Cast.Frame(stage,t,power,config)
    if stage~=self.PreviousStage and (stage=='Charging'or stage=='Casting')then
        self.Transition=nil
    end
    if active and stage~=self.PreviousStage and self.LastFrame and stage~='Charging' and stage~='Casting' then
        self.Transition={From=self.LastFrame,Age=0}
    end
    if self.Transition then
        self.Transition.Age=self.Transition.Age+dt
        local u=Cast.Smooth(self.Transition.Age/.30)
        for k,v in pairs(f)do if type(v)=='number' and self.Transition.From[k]then f[k]=self.Transition.From[k]+(v-self.Transition.From[k])*u end end
        if u>=1 then self.Transition=nil end
    end
    self.PreviousStage=stage
    if not active and self.LastFrame then f=self.LastFrame else self.LastFrame=f end
    local root=self.Root.CFrame
    local actual=self.Tool:FindFirstChild('Handle')
    if not self.EntryRod and actual then self.EntryRod=root:ToObjectSpace(actual.CFrame)end
    local rigRoot=self.Joints.Root or self.Joints.RootJoint
    local waist=self.Joints.Waist
    local neck=self.Joints.Neck
    local plant=(stage=='Charging' or stage=='Casting') and humanoid and not humanoid.Sit and not moving
    if not plant then self.LegTargets=nil end
    if plant and not self.LegTargets then
        self.LegTargets={}
        for _,side in ipairs({'Left','Right'})do
            local names=self.R15 and {side..'UpperLeg',side..'LowerLeg',side..'Foot'}or {side..' Leg'}
            for _,name in ipairs(names)do
                local part=self.Character:FindFirstChild(name)
                local joint=part and self.ByPart[part]
                if joint then
                    self.LegTargets[#self.LegTargets+1]={Joint=joint,Frame=root:ToObjectSpace(self:_world(part))}
                end
            end
        end
    end
    if rigRoot then self:_set(rigRoot,CFrame.new(f.ShiftX,-f.Drop,f.ShiftZ)*deg(f.Lean*(waist and .22 or 1),f.Twist*(waist and .24 or 1),0))end
    if waist then self:_set(waist,deg(f.Lean*.78,f.Twist*.76,0))end
    if neck then self:_set(neck,deg(-f.Lean*.5,-f.Twist*.48,0))end
    -- Lock every leg segment, not only the feet. Foot IK let knees/hips swing
    -- while compensating for the torso lean. Restore current Animator values
    -- normally outside Charging/Casting, so walking resumes immediately.
    for _,target in ipairs(self.LegTargets or {})do
        self:_place(target.Joint,root*target.Frame,1)
    end
    -- Bring the shared grip forward and slightly up so the right elbow
    -- has room to leave the chest without either hand missing the rod.
    local finalPose=root*CFrame.new(0,.35,-.40)*Cast.RodFrame(f)
    local desired=finalPose
    -- The hidden native RightGrip follows our posed hand after the first
    -- simulation. Sampling it again would feed that rotation back into IK.
    if self.Weight<.999 and self.EntryRod then desired=(root*self.EntryRod):Lerp(finalPose,self.Weight)end
    local rodCF,armPoses=self:_safeRod(desired,finalPose,stage)
    if not rodCF then self:_deactivate();return false end
    if self.R15 then
        for _,side in ipairs({'Right','Left'})do
            local pose=armPoses[side]
            self:_place(self.Joints[side..'Shoulder'],pose.Shoulder,1)
            self:_place(self.Joints[side..'Elbow'],pose.Elbow,1)
            self:_place(self.Joints[side..'Wrist'],pose.Wrist,1)
            self.ElbowDirections[side]=pose.Bend
        end
    else
        -- R6 rigid arms point from their shoulders toward the two grip positions.
        for _,side in ipairs({'Right','Left'})do
            local j=self.Joints[side..' Shoulder']
            if j then
                local S=(self:_world(j.Part0)*j.C0).Position
                local target=self:_grasp(side,rodCF).Position
                local localEnd=Vector3.new(0,-j.Part1.Size.Y*.46,0)
                local length=(localEnd-j.C1.Position).Magnitude
                local endPoint=S+(target-S).Unit*length
                -- The R6 shoulder is on the upper inner corner of the block.
                -- Keep that corner above the arm centre, rather than rolling
                -- both blocks upward and crossing them high over the chest.
                self:_place(j,segment(j.C1.Position,localEnd,S,endPoint,-root.LookVector),1)
            end
        end
    end
    -- Never interpolate again here: that could reintroduce a body intersection.
    self.Visual:PivotTo(rodCF)
    self.LastRod=rodCF
    self.LastRodLocal=root:ToObjectSpace(rodCF)
    return f.Slash
end
function Rig:Destroy()
    self:Restore();self:_kinematic(false)
    self.ElbowDirections={}
    self.LegTargets=nil
    self.RodCacheStage=nil;self.LastDesiredLocal=nil;self.RodCorrectionLocal=nil
    for _,o in ipairs(self.OriginalParts)do if o.Part.Parent then o.Part.LocalTransparencyModifier=o.Alpha end end
    if self.Visual then self.Visual:Destroy()end
end
return Rig
