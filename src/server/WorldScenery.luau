-- Authored static environment pass. Original walkable/AI geometry remains in place.
local Vegetation=require(script.Parent:WaitForChild("SceneryVegetation"))
local Landmarks=require(script.Parent:WaitForChild("SceneryLandmarks"))
local Scenery={}
local VERSION="tropical-scenery-2"

local function visual(parent,name,size,frame,color,shape,material)
    local p=Instance.new(shape=="Wedge" and "WedgePart" or "Part")
    p.Name=name; p.Size=size; p.CFrame=frame; p.Color=color
    p.Material=material or Enum.Material.SmoothPlastic
    p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false
    p.CastShadow=true; p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
    if shape=="Ball" then p.Shape=Enum.PartType.Ball end
    p.Parent=parent; return p
end
local function group(parent,name)
    local folder=Instance.new("Folder"); folder.Name=name; folder.Parent=parent; return folder
end
local function fresh(parent,name,anchor,theme)
    local version=VERSION..":"..tostring(theme.Version)
    local old=parent:FindFirstChild(name)
    if old and old:GetAttribute("SceneryVersion")==version
        and old:GetAttribute("AnchorX")==anchor.X and old:GetAttribute("AnchorY")==anchor.Y
        and old:GetAttribute("AnchorZ")==anchor.Z then return nil end
    if old and old:GetAttribute("SceneryVersion") then old:Destroy()
    elseif old then return nil end
    local folder=group(parent,name)
    folder:SetAttribute("SceneryVersion",version)
    folder:SetAttribute("AnchorX",anchor.X); folder:SetAttribute("AnchorY",anchor.Y); folder:SetAttribute("AnchorZ",anchor.Z)
    return folder
end
local function owned(parent,name)
    local folder=parent:FindFirstChild(name)
    return folder and folder:GetAttribute("SceneryVersion")~=nil
end
local function retire(p,query)
    if p:GetAttribute("QCOriginalTransparency")==nil then p:SetAttribute("QCOriginalTransparency",p.Transparency) end
    p.Transparency=1
    if query then
        if p:GetAttribute("QCOriginalCanQuery")==nil then p:SetAttribute("QCOriginalCanQuery",p.CanQuery) end
        if p:GetAttribute("QCOriginalCanTouch")==nil then p:SetAttribute("QCOriginalCanTouch",p.CanTouch) end
        p.CanQuery=false; p.CanTouch=false
    end
end
local function trees(parent,folder,center,radius,biome,theme,palm)
    for _,p in ipairs(parent:GetChildren()) do
        if p:IsA("BasePart") then
            local distance=Vector3.new(p.Position.X-center.X,0,p.Position.Z-center.Z).Magnitude
            if distance<=radius then
                if p.Name=="PalmTrunk" or p.Name=="TreeTrunk" then
                    local tree=group(folder,palm and "Palm" or "IslandTree")
                    if palm then Vegetation.Palm(tree,p,biome,theme.Palette)
                    else Vegetation.Broadleaf(tree,p,biome,theme.Palette) end
                elseif p.Name=="PalmLeaf" or (not palm and (p.Name=="LeafCanopy" or p.Name=="Branch")) then
                    retire(p,true)
                end
            end
        end
    end
end
local function shoreline(parent,center,rx,rz,biome,palette,rectangular)
    local folder=group(parent,"Coastline")
    local count=rectangular and 28 or 22
    for i=1,count do
        local a=i*math.pi*2/count
        local nx,nz=math.sin(a),math.cos(a)
        local x,z
        if rectangular then
            local reach=1/math.max(math.abs(nx),math.abs(nz))
            x,z=nx*reach*rx,nz*reach*rz
        else x,z=nx*rx,nz*rz end
        local pierGap=math.abs(x)<16 and math.abs(z)>rz*0.7
        local stairGap=rectangular and x>rx*0.8 and math.abs(z-7)<11
        if not pierGap and not stairGap then
            local variation=math.sin(i*2.73)*0.5+0.5
            local tangent=CFrame.Angles(0,a,0)
            local rockColor=biome.Rock:Lerp(palette.WoodDark,0.08+variation*0.12)
            visual(folder,"WeatheredCliff",Vector3.new(10+variation*5,8+variation*3,6+variation*2),
                CFrame.new(center.X+x,1.3+variation,center.Z+z)*tangent*CFrame.Angles(0.08,0,0.1),
                rockColor,"Ball",Enum.Material.Rock)
            visual(folder,"SandBank",Vector3.new(11+variation*4,1.9,4.3),
                CFrame.new(center.X+x*0.98,5.45+variation*0.2,center.Z+z*0.98)*tangent,
                palette.Sand:Lerp(palette.WoodLight,variation*0.10),"Ball",Enum.Material.Sand)
            if i%3==0 then
                visual(folder,"CoastalBoulder",Vector3.new(4.1,2.9,3.8),
                    CFrame.new(center.X+x*1.04,0.5,center.Z+z*1.04)*tangent*CFrame.Angles(0.12,0,0.2),
                    rockColor:Lerp(palette.Cream,0.12),"Wedge",Enum.Material.Rock)
            end
        end
    end
end
local function steppingPath(parent,center,first,last,theme)
    local folder=group(parent,"PathDetails")
    local i=0
    for z=first,last,7 do
        i+=1
        visual(folder,"PathStone",Vector3.new(3.4+i%2*0.6,0.09,2.1),
            CFrame.new(center.X+math.sin(i*2.4)*1.8,center.Y+0.05,center.Z+z)*CFrame.Angles(0,i%2*0.18-0.09,0),
            theme.Palette.Sand:Lerp(theme.Palette.Cream,0.3),nil,Enum.Material.Sandstone)
        for _,side in ipairs({-1,1}) do
            visual(folder,"PathEdgeStone",Vector3.new(1.1,0.32,1.6),
                CFrame.new(center.X+side*5.35,center.Y-0.03,center.Z+z+side*1.1)*CFrame.Angles(0,i*0.73,0.08),
                theme.Palette.Rock:Lerp(theme.Palette.Sand,0.45),"Ball",Enum.Material.Rock)
        end
    end
end
local function plants(folder,center,points,biome,theme)
    local parent=group(folder,"Understory")
    for i,p in ipairs(points) do
        local position=center+Vector3.new(p[1],0,p[2])
        if biome==theme.Biomes.home or biome==theme.Biomes.moss or biome==theme.Biomes.bloom then
            local cover=visual(parent,"GroundCover",Vector3.new(6.2,0.08,4.4),
                CFrame.new(position+Vector3.new(0,0.02,0))*CFrame.Angles(0,i*1.7,0),
                biome.Ground:Lerp(biome.Leaves,0.16),"Ball",Enum.Material.Grass)
            cover.CastShadow=false
        end
        Vegetation.Understory(parent,position,biome,theme.Palette,i)
    end
end
local function coralGarden(folder,center,theme)
    local garden=group(folder,"CoralGarden")
    for i=1,6 do
        local x,z=center.X+math.sin(i*2.4)*25,center.Z+math.cos(i*2.4)*21
        local color=i%2==0 and theme.Palette.Coral or theme.Palette.Purple
        for branch=-1,1 do
            local base=Vector3.new(x+branch*0.7,-0.7,z)
            visual(garden,"CoralStalk",Vector3.new(0.85,3.6-math.abs(branch)*0.8,0.85),
                CFrame.new(base)*CFrame.Angles(0,i,-branch*0.35),color,"Ball")
            visual(garden,"CoralFinger",Vector3.new(0.65,2,0.65),
                CFrame.new(base+Vector3.new(branch*0.5,0.7,0.7))*CFrame.Angles(0.3,0,branch*0.5),color,"Ball")
        end
    end
end
local function styleMap(map,config,theme)
    local root=map:FindFirstChild("QCScenery") or group(map,"QCScenery")
    local sand=map:FindFirstChild("IslandSand")
    if sand then
        local folder=fresh(root,"Cove",sand.Position,theme)
        if folder then
            local ground=map:FindFirstChild("IslandGrass") or sand
            local center=Vector3.new(sand.Position.X,ground.Position.Y+ground.Size.Y/2,sand.Position.Z)
            trees(map,folder,center,120,theme.Biomes.home,theme,true)
            shoreline(folder,center,sand.Size.X/2,sand.Size.Z/2,theme.Biomes.home,theme.Palette,true)
            plants(folder,center,{{-43,-17},{-32,29},{46,17},{-16,25},{42,-5},
                {-27,9},{-23,16},{-19,9},{-38,-8}},theme.Biomes.home,theme)
            local path=map:FindFirstChild("Path")
            if path then steppingPath(folder,Vector3.new(center.X,path.Position.Y+path.Size.Y/2,center.Z),-24,26,theme) end
            Landmarks.Cove(folder,center,theme)
        end
        if owned(root,"Cove") then
            for _,p in ipairs(map:GetChildren()) do
                if p:IsA("BasePart") and (p.Name=="PalmLeaf" or p.Name=="PalmTrunk")
                    and Vector3.new(p.Position.X-sand.Position.X,0,p.Position.Z-sand.Position.Z).Magnitude<=120 then
                    retire(p,p.Name=="PalmLeaf")
                end
            end
        end
    end
    local reef=map:FindFirstChild("ReefSand")
    if reef then
        local folder=fresh(root,"Reef",reef.Position,theme)
        if folder then
            local center=Vector3.new(reef.Position.X,reef.Position.Y+reef.Size.Y/2,reef.Position.Z)
            trees(map,folder,center,60,theme.Biomes.reef,theme,true)
            shoreline(folder,center,reef.Size.X/2,reef.Size.Z/2,theme.Biomes.reef,theme.Palette,true)
            plants(folder,center,{{-14,6},{13,11}},theme.Biomes.reef,theme)
            coralGarden(folder,center,theme)
        end
    end
end
local function styleIsland(model,d,theme)
    local plateau=model:FindFirstChild("Plateau")
    if not plateau then return end
    local biome=theme.Biomes[d.Theme]
    local folder=fresh(model,"QCScenery",plateau.Position,theme)
    if not folder then return end
    local center=Vector3.new(plateau.Position.X,plateau.Position.Y+plateau.Size.X/2,plateau.Position.Z)
    if d.Theme~="storm" then trees(model,folder,center,d.Radius,biome,theme,d.Theme=="sand") end
    shoreline(folder,center,d.Radius+1,d.Radius+1,biome,theme.Palette,false)
    local points=d.Theme=="sand" and {{-45,-30},{-47,20},{39,39}}
        or (d.Theme=="bloom" and {{-41,-30},{-43,15},{39,30},{20,43},{-27,35},{-30,-10}}
        or (d.Theme=="moss" and {{-40,-24},{-42,22},{36,35},{-25,35},{-28,-9}} or {}))
    plants(folder,center,points,biome,theme)
    Landmarks.Island(folder,d,center.Y,theme)
    local path=model:FindFirstChild("IslandPath")
    if path then steppingPath(folder,Vector3.new(center.X,path.Position.Y+path.Size.Y/2,center.Z),-d.Radius+8,d.Radius-8,theme) end
end
local function styleDock(model,d,theme)
    local deck=model:FindFirstChild("Boardwalk")
    if not deck then return end
    local folder=fresh(model,"QCScenery",deck.Position,theme)
    if folder then Landmarks.Dock(folder,d,deck.Position.Y+deck.Size.Y/2,theme) end
end
function Scenery.Apply(map,archipelago,config,theme)
    if map then styleMap(map,config,theme) end
    if archipelago then
        for _,d in ipairs(config.Islands) do
            local island=archipelago:FindFirstChild(d.Id)
            if island and d.Theme~="home" and d.Theme~="reef" then styleIsland(island,d,theme) end
            local dock=archipelago:FindFirstChild("Dock_"..d.Id)
            if dock then styleDock(dock,d,theme) end
        end
    end
end
return Scenery
