-- Native pre-Play regression for the real Rojo DataModel, not a factory-only fixture.
-- lune run tests/npc_sync.luau [path/to/fresh-build.rbxlx]
-- Without a place argument, builds default.project.json using ROJO or rojo on PATH.
local fs=require('@lune/fs')
local luau=require('@lune/luau')
local R=require('@lune/roblox')
local serde=require('@lune/serde')
local process=require('@lune/process')
local V,CF=R.Vector3,R.CFrame
local checks=0
local function check(ok,message)checks+=1;assert(ok,message)end
local function near(a,b,message)check((a-b).Magnitude<.003,message..': '..tostring(a)..' / '..tostring(b))end
local function frameNear(a,b,message)
    near(a.Position,b.Position,message..' position')
    check(a.UpVector.Unit:Dot(b.UpVector.Unit)>.99999 and a.LookVector.Unit:Dot(b.LookVector.Unit)>.99999,message..' orientation')
end
local placePath=process.args[1]
local temporary=not placePath
if temporary then
    local directory=process.env.TEMP or process.env.TMPDIR or '/tmp'
    placePath=directory..'/quiet-cove-npc-sync-'..tostring(os.time())..'.rbxlx'
    local ok,result=pcall(process.exec,process.env.ROJO or 'rojo',{'build','default.project.json','--output',placePath})
    check(ok,'Rojo could not run; put rojo on PATH, set ROJO, or pass a freshly built .rbxlx: '..tostring(result))
    check(result.ok,'Actual Rojo build failed: '..result.stderr)
end
local bytes=fs.readFile(placePath):gsub('^<%?xml.-%?>%s*','')
if temporary then fs.removeFile(placePath)end
local place=R.deserializePlace(bytes)
local workspace=assert(place:FindFirstChild('Workspace'),'Rojo build lacks Workspace')
local shared=assert(place.ReplicatedStorage:FindFirstChild('QuietCove'))
local builtServer=assert(place.ServerScriptService:FindFirstChild('QuietCove'))
local config=luau.load(shared.Config.Source,{environment={
    script={Parent={WaitForChild=function(_,name)return name end}},
    require=function(name)
        assert(name=='BrainrotExpansion');return luau.load(shared.BrainrotExpansion.Source)()
    end,
}})()
local Models=luau.load(builtServer.NPCModels.Source,{environment={
    Instance=R.Instance,Vector3=V,CFrame=CF,Color3=R.Color3,UDim2=R.UDim2,Enum=R.Enum,
}})()
local project=serde.decode('json',fs.readFile('world-text.project.json')).tree
local defaultProject=serde.decode('json',fs.readFile('default.project.json')).tree
check(defaultProject.Workspace['$path']=='world-text.project.json','Default Rojo project must include the tested map subtree')
check(project['$ignoreUnknownInstances']==true and project.QuietCoveMap['$ignoreUnknownInstances']==true
    and project.QuietCoveArchipelago['$ignoreUnknownInstances']==true,'NPC cleanup must preserve unrelated authored map geometry')
local roles={
    Merchant={Name='Mara',Job='Catch Trader',Giver='merchant',Yaw=-110},
    Rodsmith={Name='Lev',Job='Rodsmith',Giver='rodsmith',Yaw=110},
    Captain={Name='Captain Miron',Job='Captain',Giver='captain',Yaw=-32.5},
    Buyer={Name='Fisher',Job='Catch Trader',Giver='merchant',Yaw=120},
}
local expectedNPCs={
    {Path={'QuietCoveMap','Merchant'},Role='Merchant',Position=V.new(-20,9.2,-25)},
    {Path={'QuietCoveMap','Rodsmith'},Role='Rodsmith',Position=V.new(20,9.2,-25)},
}
local expectedSigns={}
local function sign(path,position,size,text,height,width,material)
    table.insert(expectedSigns,{Path=path,Position=position,Size=size,Text=text,Height=height or 4,Width=width or 300,Material=material or R.Enum.Material.Wood})
end
local reef=config.IslandById.Reef
sign({'QuietCoveMap','Ferry'},V.new(17,9,-78),V.new(1,5,1),'REEF FERRY\nLevel 2 required')
sign({'QuietCoveMap','ReturnFerry'},V.new(reef.X+6,9,reef.Z-15),V.new(1,5,1),'QUIET COVE\nReturn to the traders')
sign({'QuietCoveMap','FishingSign'},V.new(-10,9,-101),V.new(1,4,1),'FISHING\nHold and release LMB',3)
sign({'QuietCoveMap','ReefSign'},V.new(reef.X-7,9,reef.Z-37),V.new(1,4,1),'CORAL REEF\n'..reef.Target,3.5)
sign({'QuietCoveArchipelago','HomeHarborSign'},V.new(11,9,-8),V.new(.6,4,.6),'BOATYARD → SOUTH\nM — island map',4.5)
for _,island in ipairs(config.Islands)do
    local dock='Dock_'..island.Id
    table.insert(expectedNPCs,{Path={'QuietCoveArchipelago',dock,'Captain'},Role='Captain',Position=V.new(island.DockX-7,9.3,island.DockZ+2)})
    check(project.QuietCoveArchipelago[dock]['$ignoreUnknownInstances']==true,'Dock scenery must survive NPC-only replacement')
    sign({'QuietCoveArchipelago',dock,'DockSign'},V.new(island.DockX+8,9,island.DockZ+1),V.new(.6,3,.6),island.Name..'\nM — map · E at the captain',5,320)
    if island.Id~='Cove' and island.Id~='Reef'then
        table.insert(expectedNPCs,{Path={'QuietCoveArchipelago',dock,'Buyer'},Role='Buyer',Position=V.new(island.DockX+7,9.3,island.DockZ-13)})
        sign({'QuietCoveArchipelago',island.Id,'FishingMarker'},V.new(island.X-10,9,island.Z-island.Radius-27),V.new(.7,4,.7),'FISHING · LEVEL '..island.Level..'\n'..island.Target,4.5,350)
        sign({'QuietCoveArchipelago',island.Id,'IslandBeacon'},V.new(island.X,9,island.Z+18),V.new(4,.3,4),island.Name..'\nLevel '..island.Level,18,320,R.Enum.Material.Neon)
    end
end
local function locate(parent,path,json)
    for _,name in ipairs(path)do parent=json and parent[name]or parent:FindFirstChild(name);check(parent~=nil,'Missing mapped path '..table.concat(path,'/'))end
    return parent
end
local npcPaths={}
for _,entry in ipairs(expectedNPCs)do
    local path=table.concat(entry.Path,'/')
    npcPaths[path]=true
    local spec=roles[entry.Role]
    local model=locate(workspace,entry.Path)
    local mapped=locate(project,entry.Path,true)
    check(mapped['$ignoreUnknownInstances']==false and type(mapped['$path'])=='string',path..': dedicated asset subtree must retire old block NPC pieces')
    local asset=R.deserializeModel(fs.readFile(mapped['$path']))
    check(#asset==1 and asset[1]:IsA('Model'),path..': source asset is one native model')
    check(model:IsA('Model') and model.Name==entry.Role,path..': mapped NPC identity')
    local body=assert(model:FindFirstChild('Body'),path..': Body missing before Play')
    local rig=assert(model:FindFirstChild('VisualRig'),path..': visible character missing before Play')
    local root=assert(rig:FindFirstChild('HumanoidRootPart'),path..': anchored root missing before Play')
    frameNear(body.CFrame,CF.new(entry.Position),path..': current Config anchor')
    check(body.Anchored and body.Transparency==1 and not body.CanCollide and not body.CanTouch and not body.CanQuery,path..': hidden interaction anchor cannot fall or block players')
    check(model.PrimaryPart==body and model:GetAttribute('QCWorldPositionPinned')==true,path..': canonical placement must survive saved-world relocation')
    check(model:GetAttribute('NPCName')==spec.Name and body:GetAttribute('NPCGiver')==spec.Giver,path..': server dialogue identity')
    check(rig:GetAttribute('QCNPCVersion')==4 and rig:GetAttribute('QCNPC')==true and rig:GetAttribute('NPCRole')==entry.Role,path..': current authored visual rig must be serialized')
    check(rig.PrimaryPart==root and root.Anchored and root.Transparency==1 and not root.Massless,path..': rig has one stable invisible root')
    local height=(entry.Role=='Merchant' or entry.Role=='Rodsmith')and .8 or 1.2
    frameNear(root.CFrame,CF.new(entry.Position)*CF.new(0,height,0)*CF.Angles(0,math.rad(spec.Yaw),0),path..': visual alignment')
    local humanoid=rig:FindFirstChildOfClass('Humanoid')
    check(humanoid and humanoid:FindFirstChildOfClass('Animator') and humanoid.RigType==R.Enum.HumanoidRigType.R6,path..': real animatable humanoid')
    check(not humanoid.AutomaticScalingEnabled and humanoid.WalkSpeed==0 and not humanoid.AutoRotate,path..': authored resting pose remains fixed')
    local floor=(entry.Role=='Merchant' or entry.Role=='Rodsmith')and 7 or 7.5
    for _,name in ipairs({'Left Leg','Right Leg'})do
        local leg=assert(rig:FindFirstChild(name),path..': leg missing')
        check(math.abs(leg.CFrame:PointToWorldSpace(V.new(0,-leg.Size.Y/2,0)).Y-floor)<.03,path..': feet stand on actual island/deck height')
    end
    local visible,motors,welds,anchored=0,0,0,0
    local frames={}
    for _,p in ipairs(model:GetDescendants())do
        check(not p:IsA('LuaSourceContainer')and not p:IsA('Tool'),path..': no imported executable/tool descendants')
        if p:IsA('BasePart')then frames[p]=p.CFrame end
    end
    for _,p in ipairs(rig:GetDescendants())do
        if p:IsA('BasePart')then
            if p.Transparency<1 then visible+=1 end
            if p.Anchored then anchored+=1 end
            check(p.Anchored==(p==root) and p.Massless==(p~=root),path..': only rig root is anchored, limbs remain poseable')
            check(not p.CanCollide and not p.CanQuery and not p.CanTouch,path..': character geometry cannot interfere with navigation or weapon rays')
        elseif p:IsA('Motor6D')then
            motors+=1
            check(p.Part0 and p.Part1 and p.Part0:IsDescendantOf(rig)and p.Part1:IsDescendantOf(rig),path..': motor endpoints survive actual Rojo build')
            frameNear(p.Part0.CFrame*p.C0*p.C1:Inverse(),p.Part1.CFrame,path..': physical joint rest pose')
        elseif p:IsA('WeldConstraint')then
            welds+=1
            check(p.Part0 and p.Part1 and p.Part0:IsDescendantOf(rig)and p.Part1:IsDescendantOf(rig),path..': outfit weld references survive actual Rojo build')
        end
    end
    check(anchored==1 and visible>=25 and motors==6 and welds>=20,path..': complete visible articulated NPC exists before any script runs')
    for _,p in ipairs(model:GetChildren())do
        check(not p:IsA('BasePart')or p==body,path..': old direct block body pieces must not remain')
    end
    local text=body.Label:FindFirstChildOfClass('TextLabel')
    check(text and text.Text==spec.Name..'\n'..spec.Job and text.AutoLocalize,path..': English display label with automatic localization')
    check(body.Label.Size.X.Offset>0 and body.Label.Size.Y.Offset>0,path..': edit-mode label has a visible size')
    local prompt=body:FindFirstChild(entry.Role..'Prompt')
    check(prompt and prompt.ActionText=='Talk'and prompt.ObjectText==spec.Name and prompt.KeyboardKeyCode==R.Enum.KeyCode.E,path..': correct English E interaction before Play')
    check(prompt.MaxActivationDistance==12 and not prompt.RequiresLineOfSight,path..': conversation remains reachable')
    -- The deployed source must reuse the serialized rig/prompt on startup.
    local count=#model:GetDescendants()
    Models.Upgrade(model,entry.Role)
    Models.Upgrade(model,entry.Role,nil,CF.new(entry.Position))
    check(model.Body==body and model.VisualRig==rig and rig.HumanoidRootPart==root and body:FindFirstChild(entry.Role..'Prompt')==prompt,path..': repeated upgrade preserves all live identities')
    check(#model:GetDescendants()==count,path..': repeated startup does not duplicate rig or outfit')
    for p,frame in pairs(frames)do frameNear(p.CFrame,frame,path..': idempotent startup '..p.Name)end
    -- Reproduce the old origin/unanchored Body symptom against a saved rig.
    body.CFrame=CF.new();body.Anchored=false
    Models.Upgrade(model,entry.Role,nil,CF.new(entry.Position))
    check(body.Anchored and model.VisualRig==rig and body:FindFirstChild(entry.Role..'Prompt')==prompt,path..': canonical repair keeps dialogue references')
    for p,frame in pairs(frames)do frameNear(p.CFrame,frame,path..': origin repair '..p.Name)end
end
local mappedParts,replacementRoots=0,0
local function mappedTree(node,path)
    if node['$className']=='Part'then mappedParts+=1 end
    if node['$ignoreUnknownInstances']==false then
        replacementRoots+=1;check(npcPaths[path]==true,'Strict replacement escaped dedicated NPC subtree: '..path)
    end
    for name,child in pairs(node)do
        if name:sub(1,1)~='$'and type(child)=='table'then mappedTree(child,path==''and name or path..'/'..name)end
    end
end
mappedTree(project,'')
check(#expectedNPCs==12 and replacementRoots==12 and mappedParts==19,'All former 31 anchors are covered by 12 baked NPCs and 19 explicit mapped Parts')
for _,entry in ipairs(expectedSigns)do
    local path=table.concat(entry.Path,'/')
    local p=locate(workspace,entry.Path)
    local mapped=locate(project,entry.Path,true)
    check(p:IsA('Part')and p.Anchored and p:GetAttribute('QCWorldPositionPinned')==true,path..': real built marker must be anchored and pinned')
    check(p.CFrame.Position.Magnitude>1 and not p.CanCollide and not p.CanTouch and not p.CanQuery,path..': no origin/default-physics regression')
    frameNear(p.CFrame,CF.new(entry.Position),path..': current Config marker placement')
    near(p.Size,entry.Size,path..': authored marker dimensions')
    check(p.Material==entry.Material,path..': marker material')
    check(mapped['$properties'].Anchored==true and mapped['$properties'].CFrame~=nil and mapped['$properties'].Size~=nil,path..': source explicitly defines canonical CFrame/physics instead of Rojo defaults or derived Position')
    local gui=p:FindFirstChild('Label')
    local text=gui and gui:FindFirstChildOfClass('TextLabel')
    check(text and text.Text==entry.Text and text.AutoLocalize,path..': current English marker text survives actual Rojo build')
    check(text.TextWrapped and text.BackgroundTransparency==1 and text.TextSize==19,path..': readable text rather than default GUI styling')
    check(gui.Size.X.Offset==entry.Width and gui.Size.Y.Offset==64 and math.abs(gui.StudsOffset.Y-entry.Height)<.001,path..': label dimensions and height')
    local travel=p:FindFirstChild('Travel')
    if travel then
        local returning=entry.Path[#entry.Path]=='ReturnFerry'
        check(travel.ActionText==(returning and 'Return to Quiet Cove'or 'Travel to Coral Reef')and travel.ObjectText==(returning and 'Return ferry'or 'Ferry · Level 2'),path..': ferry labels')
        check(travel.KeyboardKeyCode==R.Enum.KeyCode.E and travel.MaxActivationDistance==12
            and math.abs(travel.HoldDuration-.2)<.001 and not travel.RequiresLineOfSight,path..': ferry interaction properties')
    end
end
-- Canonical repair must not move or replace hand-authored vendor replacements.
for _,kind in ipairs({'MeshPart','Humanoid','UnknownRig'})do
    local custom=R.Instance.new('Model');custom.Name='Merchant'
    local body=R.Instance.new('Part');body.Name='Body';body.CFrame=CF.new(87,13,42)
    body.Transparency=.3;body.Anchored=false;body.Parent=custom
    local object=R.Instance.new(kind=='UnknownRig'and 'Model'or kind)
    object.Name=kind=='UnknownRig'and 'VisualRig'or kind;object.Parent=custom
    local frame=body.CFrame;local count=#custom:GetDescendants()
    check(Models.Upgrade(custom,'Merchant',nil,CF.new(-20,9.2,-25))==body,kind..': custom interaction anchor retained')
    check(body.CFrame==frame and not body.Anchored and math.abs(body.Transparency-.3)<.0001
        and #custom:GetDescendants()==count and object.Parent==custom,kind..': canonical placement must leave custom content untouched')
end
print(string.format('PASS NPC sync: %d native checks; actual Rojo build has 12 visible v4 NPCs before Play, 19 fixed markers, idempotent/custom-safe startup',checks))
