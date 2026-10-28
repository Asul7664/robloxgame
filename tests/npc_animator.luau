-- Production NPC rig + animator, real CFrame math and deterministic engine events.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local R=require("@lune/roblox")
local V,CF=R.Vector3,R.CFrame
local checks=0
local function check(value,message)checks+=1;assert(value,message)end
local function signal()
    local out={Entries={}}
    function out:Connect(fn)
        local entry={Fn=fn,Active=true};table.insert(self.Entries,entry)
        return{Disconnect=function()entry.Active=false end}
    end
    function out:Fire(...)
        for _,entry in ipairs(table.clone(self.Entries))do if entry.Active then entry.Fn(...)end end
    end
    function out:Count()local n=0;for _,entry in ipairs(self.Entries)do if entry.Active then n+=1 end end;return n end
    return out
end
local methods={}
local function node(class)
    local p={ClassName=class,Name=class,Children={},Attributes={},CFrame=CF.new(),Transparency=0,CanCollide=true,CanQuery=true,CanTouch=true}
    return setmetatable({}, {
        __index=function(self,key)
            if key=="Position"then return p.CFrame.Position end
            if methods[key]then return methods[key]end
            if p[key]~=nil then return p[key]end
            return self:FindFirstChild(key)
        end,
        __newindex=function(self,key,value)
            if key=="Parent"then
                if p.Parent then local index=table.find(p.Parent.Children,self);if index then table.remove(p.Parent.Children,index)end end
                p.Parent=value;if value then table.insert(value.Children,self)end
            elseif key=="Position"then p.CFrame=CF.new(value)else p[key]=value end
        end,
    })
end
function methods:GetChildren()return table.clone(self.Children)end
function methods:FindFirstChild(name)for _,c in ipairs(self.Children)do if c.Name==name then return c end end end
function methods:FindFirstChildOfClass(class)for _,c in ipairs(self.Children)do if c:IsA(class)then return c end end end
function methods:IsA(class)return self.ClassName==class or(class=="BasePart"and self.ClassName=="Part")end
function methods:IsDescendantOf(parent)local current=self.Parent;while current do if current==parent then return true end;current=current.Parent end;return false end
function methods:SetAttribute(name,value)self.Attributes[name]=value end
function methods:GetAttribute(name)return self.Attributes[name]end
function methods:GetDescendants()
    local out={};for _,c in ipairs(self.Children)do table.insert(out,c);for _,d in ipairs(c:GetDescendants())do table.insert(out,d)end end;return out
end
function methods:Destroy()for _,c in ipairs(self:GetChildren())do c:Destroy()end;self.Parent=nil end
local function child(parent,class,name)
    local c=node(class);c.Name=name;c.Parent=parent;return c
end
local world=node("Workspace");world.DescendantAdded=signal();world.DescendantRemoving=signal()
local common={Instance={new=node},Vector3=V,CFrame=CF,Color3=R.Color3,UDim2=R.UDim2,Enum=R.Enum}
local models=luau.load(fs.readFile("src/server/NPCModels.luau"),{environment=common})()
local body=models.Create(world,"Merchant",0,0,{120,170,160},"Mara","Talk")
local rig=body.Parent.VisualRig
local root,torso=rig.HumanoidRootPart,rig.Torso
local rootJoint,neck=root.RootJoint,torso.Neck
local joints={rootJoint,neck,torso["Left Shoulder"],torso["Right Shoulder"]}
local baseline={};for _,j in ipairs(joints)do baseline[j]=j.C0 end
local rootFrame,bodyFrame=root.CFrame,body.CFrame
local customBody=models.Create(world,"Buyer",12,0,{120,170,160},"Custom","Talk")
local custom=customBody.Parent.VisualRig;custom:SetAttribute("QCNPC",false)
local customBaseline=custom.HumanoidRootPart.RootJoint.C0
local character=node("Model");local head=child(character,"Part","Head")
head.Position=root.Position-root.CFrame.LookVector*10+V.new(0,1.8,0)
world.CurrentCamera={CFrame=CF.new(root.Position+V.new(0,3,12))}
local render=signal();local destroyed=signal()
local env=table.clone(common)
env.game={GetService=function(_,name)return({Players={LocalPlayer={Character=character}},Workspace=world,RunService={RenderStepped=render}})[name]end}
env.script={Destroying=destroyed}
luau.load(fs.readFile("src/client/NPCAnimator.client.luau"),{environment=env})()
local function advance(seconds)for _=1,math.ceil(seconds*30)do render:Fire(1/30)end end
local function boneFrame(joint,parentFrame)return parentFrame*joint.C0*joint.C1:Inverse()end
local function flat(v)return V.new(v.X,0,v.Z).Unit end
advance(2)
local torsoFrame=boneFrame(rootJoint,root.CFrame)
local headFrame=boneFrame(neck,torsoFrame)
check(flat(headFrame.LookVector):Dot(flat(head.Position-headFrame.Position))>.99,"NPC approached from behind still presents its back")
check(root.CFrame==rootFrame and body.CFrame==bodyFrame,"Friendly attention moved gameplay root or interaction anchor")
check(custom.HumanoidRootPart.RootJoint.C0==customBaseline,"Animator modified an unowned/custom rig")
for _,name in ipairs({"Left Shoulder","Right Shoulder"})do
    local armFrame=boneFrame(torso[name],torsoFrame)
    check(armFrame.UpVector.Y>.98,"Canonical R6 joint animation raised an arm into a T-pose")
end
-- An abrupt high/side target exercises constrained neck look while the torso catches up.
head.Position=root.Position+root.CFrame.RightVector*10+V.new(0,11,0)
advance(.25)
local neckPose=CF.new(baseline[neck].Position):Inverse()*neck.C0*(baseline[neck]-baseline[neck].Position):Inverse()
local pitch,yaw,roll=neckPose:ToEulerAnglesXYZ()
check(math.abs(pitch)<=math.rad(8)+.001 and math.abs(yaw)<=math.rad(25)+.001,"Neck exceeds its human look limits")
check(math.abs(pitch)>math.rad(4) and math.abs(yaw)>math.rad(10),"Attention never follows a nearby raised target")
check(math.abs(roll)<.001,"Canonical neck basis turns look into head roll")
world.CurrentCamera.CFrame=CF.new(1000,1000,1000);advance(.1)
for _,joint in ipairs(joints)do check(joint.C0==baseline[joint],"Distant NPC did not restore its authored pose")end
world.CurrentCamera.CFrame=CF.new(root.Position+V.new(0,3,12));advance(.5)
check(rootJoint.C0~=baseline[rootJoint],"NPC did not resume idle motion when returning nearby")
world.DescendantRemoving:Fire(rig);rig.Parent=nil
for _,joint in ipairs(joints)do check(joint.C0==baseline[joint],"Removed NPC retained a locally modified pose")end
local lateBody=models.Create(world,"Rodsmith",2,1,{120,170,160},"Lev","Talk")
local late=lateBody.Parent.VisualRig;local lateJoint=late.HumanoidRootPart.RootJoint
local lateBase=lateJoint.C0
world.DescendantAdded:Fire(late);advance(.5)
check(lateJoint.C0~=lateBase,"NPC replicated after startup was never registered")
destroyed:Fire()
check(lateJoint.C0==lateBase,"Script destruction did not restore active NPC pose")
check(render:Count()==0 and world.DescendantAdded:Count()==0 and world.DescendantRemoving:Count()==0 and destroyed:Count()==0,
    "Animator destruction leaked event connections")
check(root.CFrame==rootFrame and body.CFrame==bodyFrame,"Cleanup moved gameplay geometry")
print(string.format("PASS NPC animator: %d runtime behavior checks",checks))
