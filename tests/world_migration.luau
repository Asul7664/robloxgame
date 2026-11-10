-- Run from the repository root: lune run tests/world_migration.luau
-- Exercise partial Rojo hierarchy recovery and saved-world migration using real art/world modules.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local roblox=require("@lune/roblox")
local V,CF=roblox.Vector3,roblox.CFrame
local checks=0
local function check(ok,message)checks+=1;assert(ok,message)end
local function near(a,b,message)check((a-b).Magnitude<0.002,message)end
local parts={Part=true,WedgePart=true,MeshPart=true,SpawnLocation=true}
local Node={}
local function new(class)
    local properties={ClassName=class,Name=class,Children={},Attributes={},CFrame=CF.new(),Size=V.new(1,1,1),Pivot=CF.new(),
        Color=roblox.Color3.fromRGB(163,162,165),Transparency=0,CanCollide=true,CanQuery=true,CanTouch=true}
    if class=="ColorGradingEffect"then properties.Enabled=true;properties.TonemapperPreset=roblox.Enum.TonemapperPreset.Default end
    return setmetatable({_p=properties},{
        __index=function(self,key)
            if key=="Position"then return properties.CFrame.Position end
            if Node[key]then return Node[key]end
            if properties[key]~=nil then return properties[key]end
            return self:FindFirstChild(key)
        end,
        __newindex=function(self,key,value)
            if key=="Parent"then
                if properties.Parent then
                    for i,child in ipairs(properties.Parent.Children)do
                        if child==self then table.remove(properties.Parent.Children,i);break end
                    end
                end
                properties.Parent=value
                if value then table.insert(value.Children,self)end
            elseif key=="Position"then properties.CFrame=CF.new(value)*(properties.CFrame-properties.CFrame.Position)
            else properties[key]=value end
        end,
    })
end
function Node:IsA(class)return self.ClassName==class or(class=="BasePart"and parts[self.ClassName]==true)end
function Node:FindFirstChild(name)for _,child in ipairs(self.Children)do if child.Name==name then return child end end end
function Node:WaitForChild(name)return assert(self:FindFirstChild(name),"Missing child "..name)end
function Node:FindFirstChildOfClass(class)for _,child in ipairs(self.Children)do if child:IsA(class)then return child end end end
function Node:GetChildren()return table.clone(self.Children)end
function Node:GetAttribute(key)return self.Attributes[key]end
function Node:SetAttribute(key,value)self.Attributes[key]=value end
function Node:GetDescendants()
    local out={}
    local function visit(parent)for _,child in ipairs(parent.Children)do table.insert(out,child);visit(child)end end
    visit(self);return out
end
function Node:Destroy()for _,child in ipairs(self:GetChildren())do child:Destroy()end;self.Parent=nil end
function Node:GetPivot()return self.Pivot end
function Node:PivotTo(frame)
    local delta=frame*self.Pivot:Inverse()
    for _,child in ipairs(self:GetDescendants())do if child:IsA("BasePart")then child.CFrame=delta*child.CFrame end end
    self.Pivot=frame
end
function Node:FillBlock(frame,size,material)self.LastFill={Frame=frame,Size=size,Material=material}end
local function child(parent,class,name,position)
    local object=new(class);object.Name=name;object.Parent=parent
    if position then object.Position=position end
    return object
end
local function caption(parent)
    local gui=child(parent,"BillboardGui","Label")
    local text=child(gui,"TextLabel","TextLabel");text.Text="old target";return text
end

local function fixture()
local workspace=new("Workspace");child(workspace,"Terrain","Terrain")
local lighting=new("Lighting")
local loaded={}
local environment={
    game={GetService=function(_,name)return({Workspace=workspace,Lighting=lighting,ReplicatedStorage={
        WaitForChild=function()return{WaitForChild=function(_,module)return module end}end,
    }})[name]end},
    script={Parent={WaitForChild=function(_,name)return name end}},
    require=function(name)return assert(loaded[name],"Unloaded module "..tostring(name))end,
    Instance={new=new},Vector3=V,CFrame=CF,Color3=roblox.Color3,UDim2=roblox.UDim2,Enum=roblox.Enum,
}
local function load(name,path)
    local source=fs.readFile(path);luau.compile(source)
    loaded[name]=luau.load(source,{environment=environment})()
    return loaded[name]
end
load("BrainrotExpansion","src/shared/BrainrotExpansion.luau")
local config=load("Config","src/shared/Config.luau")
load("VisualTheme","src/shared/VisualTheme.luau")
load("SceneryVegetation","src/server/SceneryVegetation.luau")
load("SceneryLandmarks","src/server/SceneryLandmarks.luau")
load("WorldScenery","src/server/WorldScenery.luau")
load("NPCModels","src/server/NPCModels.luau")
load('ReefScenery','src/server/ReefScenery.luau')
load('OceanFloor','src/server/OceanFloor.luau')
load("WorldVisuals","src/server/WorldVisuals.luau")
local world=load("World","src/server/World.luau")
local archipelago=load("Archipelago","src/server/Archipelago.luau")

return {Workspace=workspace,Config=config,World=world,Archipelago=archipelago,Models=loaded.NPCModels}
end

local function count(parent,name)
    local total=0
    for _,object in ipairs(parent:GetChildren()) do if object.Name==name then total+=1 end end
    return total
end
local function skeletonNPC(parent,role,position)
    local model=child(parent,"Model",role)
    local body=child(model,"Part","Body",position or V.zero)
    local prompt=child(body,"ProximityPrompt",role.."Prompt")
    prompt.ActionText="Talk";prompt.ObjectText=role
    caption(body)
    return {Model=model,Body=body,Prompt=prompt,Role=role}
end
local function saveGeometry(parent)
    local out={}
    for _,object in ipairs(parent:GetDescendants()) do
        if object:IsA("BasePart") then out[object]=object.CFrame end
    end
    return out
end
local function assertSameGeometry(snapshot,label)
    for object,frame in pairs(snapshot) do
        check(object.Parent~=nil,label.." removed "..object.Name)
        near(object.Position,frame.Position,label.." moved "..object.Name)
        near(object.CFrame.LookVector,frame.LookVector,label.." rotated "..object.Name)
    end
end
local function supported(point,parent)
    for _,object in ipairs(parent:GetChildren()) do
        if object:IsA("BasePart") and object.CanCollide then
            local p=object.CFrame:PointToObjectSpace(point)
            if math.abs(p.X)<=object.Size.X/2+.02 and math.abs(p.Z)<=object.Size.Z/2+.02
                and math.abs(p.Y-object.Size.Y/2)<.04 then return true end
        end
    end
    return false
end
local function assertNPC(entry,position,surface,height)
    local model,body=entry.Model,entry.Body
    check(model.Body==body and body[entry.Role.."Prompt"]==entry.Prompt,"NPC interaction identity was replaced: "..entry.Role)
    near(body.Position,position,"NPC anchor is not at its canonical position: "..entry.Role)
    check(body.Anchored==true,"NPC body is not anchored: "..entry.Role)
    check(body.Position.Magnitude>15,"NPC remains at the origin: "..entry.Role)
    local rig=model:FindFirstChild("VisualRig")
    check(rig and rig:GetAttribute("QCNPC")==true,"NPC visual rig missing: "..entry.Role)
    for _,name in ipairs({"Left Leg","Right Leg"}) do
        local foot=rig[name].CFrame:PointToWorldSpace(V.new(0,-1,0))
        check(math.abs(foot.Y-height)<.04,"NPC feet float above or penetrate the surface: "..entry.Role)
        check(supported(foot,surface),"NPC foot has no land/deck underneath: "..entry.Role.."/"..name)
    end
end
local function npcRecords(env)
    local map,folder=env.Workspace.QuietCoveMap,env.Workspace.QuietCoveArchipelago
    local out={}
    local function add(model,role,position,surface,height)
        out[#out+1]={Model=model,Body=model.Body,Prompt=model.Body[role.."Prompt"],Role=role,
            Position=position,Surface=surface,Height=height}
    end
    add(map.Merchant,"Merchant",V.new(-20,9.2,-25),map,7)
    add(map.Rodsmith,"Rodsmith",V.new(20,9.2,-25),map,7)
    for _,d in ipairs(env.Config.Islands) do
        local dock=folder["Dock_"..d.Id]
        add(dock.Captain,"Captain",V.new(d.DockX-7,9.3,d.DockZ+2),dock,7.5)
        if dock:FindFirstChild("Buyer") then add(dock.Buyer,"Buyer",V.new(d.DockX+7,9.3,d.DockZ-13),dock,7.5) end
    end
    return out
end
local function assertRepeats(env,label)
    local workspace=env.Workspace
    local before=#workspace:GetDescendants()
    local snapshot=saveGeometry(workspace)
    env.Archipelago.Attach(env.World.Build())
    check(#workspace:GetDescendants()==before,label.." duplicates geometry or scenery on repeat")
    assertSameGeometry(snapshot,label.." repeat")
end

-- A pristine scene defines the native repeated geometry budget, independently
-- of how many names already happen to exist in a partial saved hierarchy.
local baseline=fixture()
baseline.Archipelago.Attach(baseline.World.Build())
local freshMap=baseline.Workspace.QuietCoveMap
local freshFolder=baseline.Workspace.QuietCoveArchipelago

do
    local env=fixture();local workspace,config=env.Workspace,env.Config
    local map=child(workspace,"Model","QuietCoveMap")
    local authoredSand=child(map,"MeshPart","IslandSand",V.new(0,5,0))
    authoredSand.Size=V.new(119,2,89);authoredSand.MeshId="rbxassetid://1234567890"
    local authoredSandFrame,authoredSandSize=authoredSand.CFrame,authoredSand.Size
    local merchant=skeletonNPC(map,"Merchant")
    local rodsmith=skeletonNPC(map,"Rodsmith")
    local ferry=child(map,"Part","Ferry",V.new(17,9,-78))
    local ferryPrompt=child(ferry,"ProximityPrompt","Travel");caption(ferry)
    local reef=config.IslandById.Reef
    local returning=child(map,"Part","ReturnFerry",V.new(reef.X+6,9,reef.Z-15))
    child(returning,"ProximityPrompt","Travel");caption(returning)
    caption(child(map,"Part","FishingSign",V.new(-10,9,-101)))
    caption(child(map,"Part","ReefSign",V.new(reef.X-7,9,reef.Z-37)))
    local authored=child(map,"Model","HandmadeDecor")
    local crate=child(authored,"Part","Crate",V.new(-36,9,13));crate.Size=V.new(3,4,3)
    crate.CFrame=crate.CFrame*CF.Angles(.15,.4,-.12);crate.Transparency=.35;crate.CanQuery=false
    local nested=child(merchant.Model,"Model","PlayerDecoration")
    local keepsake=child(nested,"Part","Head",V.new(-16,10,-25));keepsake.Transparency=.17
    local savedCrate,savedKeepsake=crate.CFrame,keepsake.CFrame
    -- Repeated names are real native parts, not proof that all palms exist.
    local native={}
    for _,object in ipairs(freshMap:GetChildren()) do
        if object.Name=="PalmTrunk" or object.Name=="PalmLeaf" then
            if #native<9 then
                local copy=child(map,object.ClassName,object.Name,object.Position)
                copy.CFrame=object.CFrame;copy.Size=object.Size;copy.CanCollide=object.CanCollide
                native[#native+1]=copy
            end
        end
    end
    local folder=child(workspace,"Model","QuietCoveArchipelago")
    local docks,islands={},{}
    for _,d in ipairs(config.Islands) do
        if d.Theme~="home" and d.Theme~="reef" then
            local model=child(folder,"Model",d.Id);islands[d.Id]=model
            caption(child(model,"Part","FishingMarker",V.new(d.X-10,9,d.Z-d.Radius-27)))
            caption(child(model,"Part","IslandBeacon",V.new(d.X,9,d.Z+18)))
            child(model,"Part","PersonalStatue",V.new(d.X+13,12,d.Z-2))
        end
        local dock=child(folder,"Model","Dock_"..d.Id);docks[d.Id]=dock
        skeletonNPC(dock,"Captain")
        if d.Theme~="home" and d.Theme~="reef" then skeletonNPC(dock,"Buyer") end
        caption(child(dock,"Part","DockSign",V.new(d.DockX+8,9,d.DockZ+1)))
    end
    local refs=env.Archipelago.Attach(env.World.Build())
    check(workspace.QuietCoveMap==map and workspace.QuietCoveArchipelago==folder,"Partial root models were replaced")
    check(refs.Merchant==merchant.Body and refs.Shop==rodsmith.Body,"Recovered world refs lost mapped body anchors")
    check(refs.Ferry==ferry and ferry.Travel==ferryPrompt,"Mapped ferry and prompt were replaced")
    check(map.IslandSand==authoredSand and count(map,"IslandSand")==1,"Recovery duplicated or replaced an authored MeshPart ground")
    check(authoredSand.MeshId=="rbxassetid://1234567890" and authoredSand.CFrame==authoredSandFrame
        and authoredSand.Size==authoredSandSize,"Recovery changed the authored ground mesh, frame or dimensions")
    for _,name in ipairs({"IslandRock","IslandSand","IslandGrass","CoveSpawn","Path","ReefRock","ReefSand","ReefPier"}) do
        check(map:FindFirstChild(name)~=nil,"Partial home map lacks "..name)
    end
    for _,name in ipairs({"PalmTrunk","PalmLeaf","PierPlank","PierSupport","Lighthouse"}) do
        check(count(map,name)==count(freshMap,name),"Partial recovery duplicates or drops native group "..name)
    end
    for _,object in ipairs(native) do check(object.Parent==map,"Native repeated geometry was replaced") end
    check(crate.Parent==authored and crate.CFrame==savedCrate and crate.Transparency==.35 and not crate.CanQuery,"Partial recovery overwrote authored decor")
    check(keepsake.Parent==nested and keepsake.CFrame==savedKeepsake and keepsake.Transparency==.17,"NPC recovery changed nested user decor")
    for _,d in ipairs(config.Islands) do
        local dock=docks[d.Id]
        check(folder["Dock_"..d.Id]==dock,"Partial dock model was replaced")
        check(dock:FindFirstChild("Boardwalk") and dock:FindFirstChild("Jetty"),"Recovered dock has no walkable geometry")
        near(dock.Boardwalk.Position,V.new(d.DockX,7,d.DockZ-9),"Recovered Boardwalk has wrong position")
        check(refs.Docks[d.Id].Captain==dock.Captain.Body,"Boat interaction refs use a duplicate captain")
        if islands[d.Id] then
            local model=islands[d.Id]
            check(folder[d.Id]==model and model.PersonalStatue.Parent==model,"Partial island or authored statue was replaced")
            for _,name in ipairs({"IslandStone","Shore","Plateau","FishingPier","FishingDeck"}) do
                check(model:FindFirstChild(name)~=nil,"Partial island lacks "..d.Id.."/"..name)
            end
            near(model.IslandStone.Position,V.new(d.X,-2,d.Z),"Recovered island has wrong position")
            for _,name in ipairs({"TreeTrunk","PalmLeaf","TempleTier","BasaltSpire"}) do
                check(count(model,name)==count(freshFolder[d.Id],name),"Partial island duplicates native group "..d.Id.."/"..name)
            end
        end
    end
    for _,entry in ipairs(npcRecords(env)) do assertNPC(entry,entry.Position,entry.Surface,entry.Height) end
    assertRepeats(env,"Partial recovery")
end

do
    -- Existing complete scenes may contain old geometry alongside NPC models
    -- baked by Rojo at the current coordinates. Only old geometry moves.
    local env=baseline;local workspace,config=env.Workspace,env.Config
    local map,folder=workspace.QuietCoveMap,workspace.QuietCoveArchipelago
    local originalMap,originalFolder=map,folder
    local statue=child(folder.Moss,"Model","HandmadeDecor")
    local sculpture=child(statue,"Part","Sculpture",V.new(config.IslandById.Moss.X+13,14,config.IslandById.Moss.Z+17))
    sculpture.CFrame=sculpture.CFrame*CF.Angles(.2,.35,.15);sculpture.Size=V.new(3,5,4)
    local sculptureFrame=sculpture.CFrame
    local oldOffset=V.new(-275,0,170)
    local baked=folder.Dock_Dunes.Captain
    baked:SetAttribute("QCWorldPositionPinned",true)
    local pinnedSign=folder.Dock_Dunes.DockSign;pinnedSign:SetAttribute("QCWorldPositionPinned",true)
    local bakedFrame=baked.Body.CFrame;local bakedRig=baked.VisualRig;local pinnedFrame=pinnedSign.CFrame
    local originalCaptains={}
    for _,d in ipairs(config.Islands) do
        local island=folder:FindFirstChild(d.Id)
        if island then
            for _,part in ipairs(island:GetDescendants()) do if part:IsA("BasePart") then part.CFrame=part.CFrame+oldOffset end end
        end
        local dock=folder["Dock_"..d.Id];originalCaptains[d.Id]=dock.Captain.Body
        for _,part in ipairs(dock:GetDescendants()) do
            if part:IsA("BasePart") then
                local parent=part;local pinned=false
                while parent and parent~=dock do
                    if parent:GetAttribute("QCWorldPositionPinned")==true then pinned=true;break end
                    parent=parent.Parent
                end
                if not pinned then part.CFrame=part.CFrame+oldOffset end
            end
        end
    end
    -- Custom humanoid/mesh replacements are not owned procedural NPCs.
    local merchant,rodsmith=map.Merchant,map.Rodsmith
    merchant.VisualRig:Destroy();child(merchant,"Humanoid","Humanoid")
    merchant.Body.CFrame=CF.new(-22,11,-22);local customMerchantFrame=merchant.Body.CFrame
    rodsmith.VisualRig:Destroy();local mesh=child(rodsmith,"MeshPart","Head",V.new(22,12,-22))
    rodsmith.Body.CFrame=CF.new(22,10,-22);local customRodFrame=rodsmith.Body.CFrame;local customMeshFrame=mesh.CFrame
    local countBefore=#workspace:GetDescendants()
    local refs=env.Archipelago.Attach(env.World.Build())
    check(workspace.QuietCoveMap==originalMap and workspace.QuietCoveArchipelago==originalFolder,"Full saved roots were replaced")
    check(#workspace:GetDescendants()==countBefore,"Full saved migration added duplicate baseline/scenery")
    near(sculpture.Position,sculptureFrame.Position,"Saved custom geometry did not follow its island")
    near(sculpture.CFrame.LookVector,sculptureFrame.LookVector,"Saved custom geometry was rotated")
    check(sculpture.Size==V.new(3,5,4),"Saved custom geometry was resized")
    check(baked.Body.CFrame==bakedFrame and baked.VisualRig==bakedRig,"Current baked NPC was translated twice or replaced")
    check(pinnedSign.CFrame==pinnedFrame,"Current mapped sign was translated with old dock")
    check(merchant.Body.CFrame==customMerchantFrame and not merchant:FindFirstChild("VisualRig"),"Authored humanoid was realigned or replaced")
    check(rodsmith.Body.CFrame==customRodFrame and mesh.CFrame==customMeshFrame and not rodsmith:FindFirstChild("VisualRig"),"Authored mesh NPC was realigned or replaced")
    check(refs.Merchant==merchant.Body and refs.Shop==rodsmith.Body,"Custom NPC refs were replaced")
    for _,d in ipairs(config.Islands) do
        local dock=folder["Dock_"..d.Id]
        check(dock.Captain.Body==originalCaptains[d.Id],"Full saved captain identity was replaced")
        near(dock.Boardwalk.Position,V.new(d.DockX,7,d.DockZ-9),"Old dock was not relocated")
        if folder:FindFirstChild(d.Id) then near(folder[d.Id].IslandStone.Position,V.new(d.X,-2,d.Z),"Old island was not relocated") end
    end
    for _,entry in ipairs(npcRecords(env)) do
        if entry.Role~="Merchant" and entry.Role~="Rodsmith" then assertNPC(entry,entry.Position,entry.Surface,entry.Height) end
    end
    assertRepeats(env,"Full saved migration")
end

print("PASS world migration: "..checks.." checks (partial skeletons, saved geometry, pinned NPCs, deck support and repeatability)")
