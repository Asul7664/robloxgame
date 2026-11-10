-- Bake the same production NPCs into Rojo so edit mode and Play agree.
-- Run from the repository root: lune run tools/build_npcs.luau
local fs=require('@lune/fs')
local luau=require('@lune/luau')
local roblox=require('@lune/roblox')
local serde=require('@lune/serde')
local V,CF=roblox.Vector3,roblox.CFrame
local environment={Instance=roblox.Instance,Vector3=V,CFrame=CF,Color3=roblox.Color3,
    UDim2=roblox.UDim2,Enum=roblox.Enum}
local expansion=luau.load(fs.readFile('src/shared/BrainrotExpansion.luau'))()
local configEnvironment=table.clone(environment)
configEnvironment.script={Parent={WaitForChild=function(_,name)return name end}}
configEnvironment.require=function(name)assert(name=='BrainrotExpansion');return expansion end
local config=luau.load(fs.readFile('src/shared/Config.luau'),{environment=configEnvironment})()
local models=luau.load(fs.readFile('src/server/NPCModels.luau'),{environment=environment})()
local project=serde.decode('json',fs.readFile('world-text.project.json'))
local map,arch=project.tree.QuietCoveMap,project.tree.QuietCoveArchipelago
local destination='assets/npcs'
if not fs.isDir(destination) then fs.writeDir(destination) end
local count=0
local function bake(parent,role,key,x,z)
    local holder=roblox.Instance.new('Folder')
    local body=models.Create(holder,role,x,z,{120,170,160},'','Talk')
    local model=body.Parent
    model.PrimaryPart=body
    model:SetAttribute('QCWorldPositionPinned',true)
    assert(body.Anchored and body.Transparency==1,'Interaction anchor must be fixed and hidden')
    assert(model.VisualRig and model.VisualRig.HumanoidRootPart.Anchored,'Visible character needs a fixed root')
    local y=(role=='Merchant' or role=='Rodsmith') and 9.2 or 9.3
    assert((body.CFrame.Position-V.new(x,y,z)).Magnitude<.01,'Unexpected NPC anchor')
    local path=destination..'/'..key..'.rbxmx'
    fs.writeFile(path,roblox.serializeModel({model},true))
    local restored=roblox.deserializeModel(fs.readFile(path))[1]
    assert(restored.Body.Anchored and restored.VisualRig:GetAttribute('QCNPC')==true,'NPC XML lost its character')
    -- Only the dedicated NPC subtree is replaced; authored map scenery stays.
    parent[role]={['$path']=path,['$ignoreUnknownInstances']=false}
    holder:Destroy();count+=1
end
local function physical(node,position,size,height,width,material)
    assert(node and node['$className']=='Part','Expected an existing mapped sign/interaction Part')
    node['$attributes']={QCWorldPositionPinned=true}
    node['$properties']={CFrame={position[1],position[2],position[3],1,0,0,0,1,0,0,0,1},Size=size,Anchored=true,
        CanCollide=false,CanTouch=false,CanQuery=false,Material=material or 'Wood',
        Color={109/255,77/255,57/255},TopSurface='Smooth',BottomSurface='Smooth'}
    if node.Label then
        node.Label['$properties']={Size={UDim2={{0,width or 300},{0,64}}},StudsOffset={0,height or 4,0},
            MaxDistance=120,AlwaysOnTop=false}
        local text=node.Label.TextLabel['$properties']
        text.Size={UDim2={{1,0},{1,0}}};text.BackgroundTransparency=1;text.Font='GothamBold';text.TextSize=19
        text.TextColor3={1,247/255,223/255};text.TextStrokeTransparency=.25;text.TextWrapped=true;text.AutoLocalize=true
    end
    if node.Travel then
        local p=node.Travel['$properties']
        p.KeyboardKeyCode='E';p.HoldDuration=.2;p.MaxActivationDistance=12;p.RequiresLineOfSight=false
    end
end
bake(map,'Merchant','Mara',-20,-25)
bake(map,'Rodsmith','Lev',20,-25)
local reef=config.IslandById.Reef
physical(map.Ferry,{17,9,-78},{1,5,1},4)
physical(map.ReturnFerry,{reef.X+6,9,reef.Z-15},{1,5,1},4)
map.Ferry['$properties'].Color={27/255,50/255,78/255}
map.ReturnFerry['$properties'].Color={27/255,50/255,78/255}
physical(map.FishingSign,{-10,9,-101},{1,4,1},3)
physical(map.ReefSign,{reef.X-7,9,reef.Z-37},{1,4,1},3.5)
physical(arch.HomeHarborSign,{11,9,-8},{.6,4,.6},4.5)
for _,island in ipairs(config.Islands) do
    local dock=assert(arch['Dock_'..island.Id])
    bake(dock,'Captain','Captain'..island.Id,island.DockX-7,island.DockZ+2)
    physical(dock.DockSign,{island.DockX+8,9,island.DockZ+1},{.6,3,.6},5,320)
    if island.Id~='Cove' and island.Id~='Reef' then
        bake(dock,'Buyer','Buyer'..island.Id,island.DockX+7,island.DockZ-13)
        physical(arch[island.Id].FishingMarker,{island.X-10,9,island.Z-island.Radius-27},{.7,4,.7},4.5,350)
        physical(arch[island.Id].IslandBeacon,{island.X,9,island.Z+18},{4,.3,4},18,320,'Neon')
        arch[island.Id].IslandBeacon['$properties'].Color={island.Color[1]/255,island.Color[2]/255,island.Color[3]/255}
    end
end
fs.writeFile('world-text.project.json',serde.encode('json',project,true)..'\n')
print(string.format('PASS baked %d anchored NPCs with edit-mode rigs and explicit mapped sign physics.',count))
