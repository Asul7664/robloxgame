-- Actual factory/editor modules with real CFrame math; Studio selection and
-- Model:PivotTo/Clone are supplied by doubles because Lune omits PivotTo.
local Environment=require('./helpers/combat_environment')
local R=require('@lune/roblox')
local env=Environment.new()
local CF,V=R.CFrame,R.Vector3
local checks=0
local function check(ok,message)checks+=1;assert(ok,message)end
local function frameNear(a,b,message)
    local aa,bb={a:GetComponents()},{b:GetComponents()}
    local difference=0
    for i=1,#aa do difference+=math.abs(aa[i]-bb[i]) end
    check(difference<.001,message)
end
local rawNode=env.Node
local function node(self,class,name,parent)
    local object=rawNode(self,class,name,parent)
    local meta=getmetatable(object)
    local priorIndex=meta.__index
    meta.__index=function(n,key)
        if key=='Clone' or key=='IsA' then return n._properties[key] end
        return priorIndex(n,key)
    end
    object.IsA=function(n,wanted)
        return n.ClassName==wanted or (wanted=='BasePart' and
            (n.ClassName=='Part' or n.ClassName=='WedgePart' or n.ClassName=='MeshPart'))
            or (wanted=='LuaSourceContainer' and (n.ClassName=='Script' or n.ClassName=='LocalScript' or n.ClassName=='ModuleScript'))
    end
    object.GetPivot=function(n)return n.PrimaryPart and n.PrimaryPart.CFrame or n.CFrame end
    object.PivotTo=function(n,frame)
        local delta=frame*n:GetPivot():Inverse()
        for _,part in n:GetDescendants() do if part:IsA('BasePart') then part.CFrame=delta*part.CFrame end end
        n.CFrame=frame
    end
    object.Clone=function(n)
        if n.Archivable==false then return nil end
        local map={}
        local function allocate(original)
            local clone=node(self,original.ClassName,original.Name);map[original]=clone
            for _,child in original:GetChildren() do
                if child.Archivable~=false then allocate(child).Parent=clone end
            end
            return clone
        end
        local clone=allocate(n)
        for original,copy in pairs(map) do
            for key,value in pairs(original._properties) do
                if key=='Attributes' then copy.Attributes=table.clone(value)
                elseif key~='Parent' and key~='Children' and key~='Owner' and type(value)~='function'
                    and key~='Destroying' and key~='AncestryChanged' and key~='ChildAdded' and key~='ChildRemoved'
                    and key~='AttributeSignals' and key~='PropertySignals' then copy[key]=map[value] or value end
            end
        end
        return clone
    end
    return object
end
env.Node=node
env.Globals.Instance.new=function(class,parent)return env:Node(class,nil,parent)end
env.Services.Workspace=env.World
env.Run.IsStudio=function()return true end
env.Run.IsRunning=function()return false end
local selected={}
env.Services.Selection={Get=function()return selected end,Set=function(_,items)selected=items end}
env.Services.ChangeHistoryService={SetWaypoint=function()end}
env.Globals.print=function()end
local server=env:Node('Folder','QuietCove')
local factoryModule=env:Node('ModuleScript','SharkVisual',server)
env.Globals.script={Parent=server}
local Shark=env:Execute('src/server/SharkVisual.luau')
local factoryLoads={}
env.Globals.require=function(module)
    assert(module.Name=='SharkVisual');table.insert(factoryLoads,module);return Shark
end
local Edit=env:Execute('src/server/SharkStudioEdit.luau')

local preview=Edit.Edit()
check(preview.Parent==env.World and preview.Name=='SharkPreview','Edit exposes a real scene model outside Play')
check(preview:GetAttribute('QCSharkEditorPreview')==true and selected[1]==preview,'Edit marks and selects the preview')
local originalCount=#env.World:GetChildren()
check(Edit.Edit()==preview and #env.World:GetChildren()==originalCount,'Repeated Edit preserves work without duplicate previews')
local body=preview.PrimaryPart
body.Color=R.Color3.fromRGB(201,70,44)
body.Size=V.new(4,3,8)
local fin=preview:FindFirstChild('DorsalFin')
fin.CFrame=body.CFrame*CF.new(.2,2,.5)*CF.Angles(.15,.2,.1)
fin.Anchored=false;fin.CanCollide=true;fin.CanQuery=true;fin.CanTouch=true
local relative=body.CFrame:ToObjectSpace(fin.CFrame)
-- Editing a fin often leaves that fin selected; Save must still save the model.
selected={fin}
env:Node('Script','UnexpectedScript',preview)
local template=Edit.Save()
check(template and template.Name=='OceanSharkTemplate' and template.Parent==env.Storage,'Save persists the runtime template in ServerStorage')
check(preview.Parent==env.World and not preview.Destroyed,'Save keeps editor work available for further changes')
check(template~=preview and template.PrimaryPart~=body,'Saving creates an independent template, never reparents the preview')
check(template.PrimaryPart.Color==body.Color and template.PrimaryPart.Size==body.Size,'Edited colour and size survive saving')
frameNear(template.PrimaryPart.CFrame:ToObjectSpace(template:FindFirstChild('DorsalFin').CFrame),relative,'Edited relative fin placement survives saving')
check(template:FindFirstChild('UnexpectedScript')==nil and preview:FindFirstChild('UnexpectedScript')~=nil,
    'Template is sanitized without mutating the editor original')
check(fin.CanCollide and not fin.Anchored,'Sanitizing the clone leaves source editing flags intact')
for _,part in template:GetDescendants() do
    if part:IsA('BasePart') then check(part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch,'Saved visual cannot interfere with gameplay') end
end

local frame=CF.new(100,3,-50)*CF.Angles(.1,.8,-.2)
local attack=Shark.Create(env.World,frame,template)
frameNear(attack.PrimaryPart.CFrame,frame,'Runtime custom model is positioned at the requested attack frame')
frameNear(attack.PrimaryPart.CFrame:ToObjectSpace(attack:FindFirstChild('DorsalFin').CFrame),relative,'Runtime attack uses edited fin geometry')
check(attack.PrimaryPart.Color==body.Color and attack.PrimaryPart.Size==body.Size,'Actual runtime factory uses saved colour and dimensions')
check(template.Parent==env.Storage,'Runtime cloning leaves saved template intact')

preview.PrimaryPart=nil
check(not pcall(Edit.Save) and template.Parent==env.Storage and not template.Destroyed,'Invalid preview cannot replace the saved working template')
preview.PrimaryPart=body
preview.Archivable=false
check(not pcall(Edit.Save) and template.Parent==env.Storage,'Uncloneable preview cannot erase the working template')
preview.Archivable=true
local nextTemplate=Edit.Save()
check(nextTemplate~=template and template.Destroyed,'A successful later save replaces the old template')

env.Run.IsRunning=function()return true end
check(not pcall(Edit.Edit) and not pcall(Edit.Save),'Play mode cannot overwrite the saved editor template')
env.Run.IsRunning=function()return false end
env.Run.IsStudio=function()return false end
check(not pcall(Edit.Edit) and not pcall(Edit.Save),'Editor operations are unavailable in published servers')
env.Run.IsStudio=function()return true end

preview:Destroy()
local loaded=Edit.Edit()
check(loaded.PrimaryPart.Color==body.Color and loaded.PrimaryPart.Size==body.Size,'Opening the editor again starts from the saved edited template')
check(loaded~=preview and loaded.Parent==env.World,'Reopened template has an editable Workspace copy')
check(#factoryLoads>=3,'Editor reloads the factory for independent edit/save operations')
for _,module in factoryLoads do
    check(module~=factoryModule and module.Destroyed,'Fresh factory copies bypass stale require cache and are released')
end

-- Exercise the actual hazard wiring, rather than only calling the factory:
-- attacks must receive the editor's saved template as their third argument.
local Damage=env:Execute('src/combat/Damage.luau')
env.Globals.require=function(module)
    if module.Name=='Damage' then return Damage end
    if module.Name=='SharkVisual' then return Shark end
    error('Unexpected dependency '..module.Name)
end
local Hazard=env:Execute('src/server/WaterHazardService.luau')
local settings={Enabled=true,Seconds=30,WarningSeconds=10,CheckInterval=.1,
    GroundTolerance=.65,EffectSeconds=1.3,SurfaceY=0}
env.Run.IsRunning=function()return true end
local service=Hazard.new(settings,function()end)
check(loaded.Destroyed and not env.World:FindFirstChild('SharkPreview'),'Runtime startup removes the tagged editor preview copy')
check(nextTemplate.Parent==env.Storage and not nextTemplate.Destroyed,'Hiding the runtime preview preserves the saved template')
local foreign=env:Node('Model','SharkPreview',env.World)
local other=Hazard.new(settings,function()end)
check(not foreign.Destroyed,'Runtime startup never deletes an untagged same-name model')
other:Destroy();foreign:Destroy()
local player=env:AddPlayer(501,true)
local h=player.Character.Humanoid
h.State=env.Enum.HumanoidStateType.Swimming;h.FloorMaterial=env.Enum.Material.Air
player.Character.HumanoidRootPart.Size=V.new(2,2,1)
player.Character.HumanoidRootPart.CFrame=CF.new(0,.5,0)
player.Character['Left Leg'].Size=V.new(1,2,1)
service:Step(0);service:Step(30)
check(h.Health==0,'Actual water hazard retains instant death while using custom visuals')
local folder=env.World:FindFirstChild('QuietCoveWaterHazards')
local realAttack=folder and folder:FindFirstChild('OceanShark')
check(realAttack and realAttack~=nextTemplate,'Water hazard creates a separate attack model from the saved template')
check(realAttack.PrimaryPart.Color==body.Color and realAttack.PrimaryPart.Size==body.Size,
    'Actual shark attack uses the edited colour and size')
frameNear(realAttack.PrimaryPart.CFrame:ToObjectSpace(realAttack:FindFirstChild('DorsalFin').CFrame),relative,
    'Actual attack preserves the edited fin placement')
service:Destroy()
check(realAttack.Destroyed and nextTemplate.Parent==env.Storage and not nextTemplate.Destroyed,
    'Attack teardown removes only the transient shark, preserving the editor template')

print('PASS shark editing: '..checks..' checks (saved geometry, runtime template, sanitization and edit guards)')
