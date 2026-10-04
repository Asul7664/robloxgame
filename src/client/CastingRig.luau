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
        local types={UpperArm='Shoulder',LowerArm='Elbow',Hand='Wrist',UpperLeg='Hip',LowerLeg='Knee',Foot='Ankle'}
        for body,joint in pairs(types)do if part.Name==side..body then return side..joint end end
    end
    return fallback
end
function Rig.new(character,tool,parent)
    local root=character:FindFirstChild('HumanoidRootPart');if not root then return nil end
    local self=setmetatable({Character=character,Root=root,Tool=tool,ByPart={},Joints={},OriginalParts={},Saved={},Weight=0,Cache={},ConstraintStates={},KinematicsActive=false},Rig)
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
    -- The main hand follows the already blended rod exactly throughout entry.
    self:_set(j,t,weight)
end
function Rig:_limb(shoulder,elbow,wrist,handCF,pole,weight)
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
    local E=S+axis*along+bend*height
    local normal=axis:Cross(bend).Unit
    local upper=segment(shoulder.C1.Position,elbow.C0.Position,S,E,normal)
    local lower=segment(elbow.C1.Position,wrist.C0.Position,E,T,normal)
    local palm=CFrame.new(T)*rot(handCF)*CFrame.new(-wrist.C1.Position)
    self:_place(shoulder,upper,weight);self:_place(elbow,lower,weight);self:_place(wrist,palm,weight)
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
    if not self.R15 then
        -- R6 has no elbow: fit both rigid arm endpoints to their rod grips.
        -- The handle centre lies on the intersection of two reach spheres.
        local centres,lengths={},{}
        for _,side in ipairs({'Right','Left'})do
            local j=self.Joints[side..' Shoulder']
            if not j then return rodCF end
            local S=(self:_world(j.Part0)*j.C0).Position
            local localEnd=Vector3.new(0,-j.Part1.Size.Y*.46,0)
            lengths[#lengths+1]=(localEnd-j.C1.Position).Magnitude
            centres[#centres+1]=S-(self:_grasp(side,rodCF).Position-rodCF.Position)
        end
        local delta=centres[2]-centres[1];local d=delta.Magnitude
        if d>.001 and d<lengths[1]+lengths[2] and d>math.abs(lengths[1]-lengths[2])then
            local axis=delta.Unit
            local along=(lengths[1]^2-lengths[2]^2+d*d)/(2*d)
            local radius=math.sqrt(math.max(0,lengths[1]^2-along*along))
            local centre=centres[1]+axis*along
            local projected=rodCF.Position-centre
            projected=projected-axis*projected:Dot(axis)
            if projected.Magnitude<.001 then projected=self.Root.CFrame.LookVector end
            return CFrame.new(centre+projected.Unit*radius)*rot(rodCF)
        end
        return rodCF
    end
    for _=1,3 do
        for _,side in ipairs({'Left','Right'})do
            local a,b,c=self.Joints[side..'Shoulder'],self.Joints[side..'Elbow'],self.Joints[side..'Wrist']
            if a and b and c then
                local S=(self:_world(a.Part0)*a.C0).Position
                local T=(self:_grip(side,rodCF)*c.C1).Position
                local reach=(b.C0.Position-a.C1.Position).Magnitude+(c.C0.Position-b.C1.Position).Magnitude-.025
                local delta=T-S
                if delta.Magnitude>reach then
                    local correction=-delta.Unit*(delta.Magnitude-reach)
                    rodCF=CFrame.new(correction)*rodCF
                end
            end
        end
    end
    return rodCF
end

function Rig:_safeRod(desired,finalPose)
    local function safe(candidate)
        candidate=self:_fitRod(candidate)
        if Clearance.Check(candidate,self.RodShapes,self.BodyParts,function(part)return self:_world(part)end,.06)then
            return candidate
        end
    end
    local fitted=safe(desired)
    if fitted then return fitted end
    if finalPose then
        fitted=safe(finalPose)
        if fitted then return fitted end
        desired=finalPose
    end
    -- Clearance is evaluated AFTER reach fitting, including the reel and butt.
    local root=self.Root.CFrame
    local localFrame=root:ToObjectSpace(desired)
    for _,pitch in ipairs({8,16,-8})do
        for _,offset in ipairs({Vector3.new(0,0,-.15),Vector3.new(.22,0,-.15),
            Vector3.new(-.22,0,-.15),Vector3.new(0,.16,-.12),Vector3.new(0,-.16,-.12)})do
            fitted=safe(root*CFrame.new(offset)*localFrame*deg(pitch,0,0))
            if fitted then return fitted end
        end
    end
    return nil
end

function Rig:_deactivate()
    self:Restore();self:_kinematic(false);self.Weight=0
    self.FootTargets=nil;self.LastFrame=nil;self.LastRod=nil;self.PreviousStage=nil;self.Transition=nil
    for _,o in ipairs(self.OriginalParts)do if o.Part.Parent then o.Part.LocalTransparencyModifier=o.Alpha end end
    for _,part in ipairs(self.VisibleParts)do if part.Parent then part.LocalTransparencyModifier=1 end end
    -- Invisible clone tip follows the native Tool when fishing while moving.
    local actual=self.Tool:FindFirstChild('Handle')
    if actual then self.Visual:PivotTo(actual.CFrame)end
end
function Rig:Step(stage,t,power,config,dt)
    local humanoid=self.Character:FindFirstChildOfClass('Humanoid')
    local velocity=self.Root.AssemblyLinearVelocity or Vector3.zero
    local moving=humanoid and (humanoid.MoveDirection.Magnitude>.05
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
    if not shown then self.FootTargets=nil;self.LastFrame=nil;self.PreviousStage=nil;self.Transition=nil;return false end
    self.Cache={}
    local f=Cast.Frame(stage,t,power,config)
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
    local rigRoot=self.Joints.Root or self.Joints.RootJoint
    local waist=self.Joints.Waist
    local neck=self.Joints.Neck
    local plant=(stage=='Charging' or stage=='Casting') and humanoid and not humanoid.Sit and humanoid.MoveDirection.Magnitude<.05
    if not plant then self.FootTargets=nil end
    if plant and not self.FootTargets then
        self.FootTargets={}
        for _,side in ipairs({'Left','Right'})do local foot=self.Character:FindFirstChild(side..'Foot')
            if foot then self.FootTargets[side]=root:Inverse()*self:_world(foot) end
        end
    end
    if rigRoot then self:_set(rigRoot,CFrame.new(f.ShiftX,-f.Drop,f.ShiftZ)*deg(f.Lean*(waist and .22 or 1),f.Twist*(waist and .24 or 1),0))end
    if waist then self:_set(waist,deg(f.Lean*.78,f.Twist*.76,0))end
    if neck then self:_set(neck,deg(-f.Lean*.5,-f.Twist*.48,0))end
    local finalPose=root*Cast.RodFrame(f)
    local desired=finalPose
    local actual=self.Tool:FindFirstChild('Handle')
    if self.Weight<.999 and actual then desired=actual.CFrame:Lerp(finalPose,self.Weight)end
    local rodCF=self:_safeRod(desired,finalPose)
    if not rodCF then self:_deactivate();return false end
    if self.R15 then
        for _,side in ipairs({'Right','Left'})do
            local sign=side=='Right' and 1 or -1
            -- Roblox forward is -Z.  Keep elbows in front of the torso instead of folding them into the chest.
            local rightHint,leftHint
            if stage=='Charging' then
                rightHint=Vector3.new(1.38,-0.18,-0.12)
                leftHint=Vector3.new(-1.02,-0.50,-0.30)
            elseif stage=='Casting' then
                rightHint=Vector3.new(1.48,-0.24,-0.72)
                leftHint=Vector3.new(-1.08,-0.56,-0.92)
            else
                rightHint=Vector3.new(1.10,-0.55,-0.55)
                leftHint=Vector3.new(-1.10,-0.55,-0.55)
            end
            local elbowHint=root*(side=='Right' and rightHint or leftHint)
            self:_limb(self.Joints[side..'Shoulder'],self.Joints[side..'Elbow'],self.Joints[side..'Wrist'],
                self:_grip(side,rodCF),elbowHint,side=='Right' and 1 or nil)
            local planted=self.FootTargets and self.FootTargets[side]
            if planted then
                self:_limb(self.Joints[side..'Hip'],self.Joints[side..'Knee'],self.Joints[side..'Ankle'],
                    root*planted,root*Vector3.new(sign*.70,-1.0,-2.5))
            end
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
                self:_place(j,segment(j.C1.Position,localEnd,S,endPoint,-root.LookVector),side=='Right' and 1 or nil)
            end
        end
    end
    -- Never interpolate again here: that could reintroduce a body intersection.
    self.Visual:PivotTo(rodCF)
    self.LastRod=rodCF
    return f.Slash
end
function Rig:Destroy()
    self:Restore();self:_kinematic(false)
    for _,o in ipairs(self.OriginalParts)do if o.Part.Parent then o.Part.LocalTransparencyModifier=o.Alpha end end
    if self.Visual then self.Visual:Destroy()end
end
return Rig
