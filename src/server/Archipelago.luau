-- Creates missing destinations and relocates saved islands/docks in place.
-- Build() is idempotent, including when run from Studio's Command Bar.
local Workspace=game:GetService("Workspace")
local Config=require(game:GetService("ReplicatedStorage"):WaitForChild("QuietCove"):WaitForChild("Config"))
local A={}
local function part(parent,name,x,y,z,sx,sy,sz,color,material,class)
    local p=Instance.new(class or "Part");p.Name=name;p.Size=Vector3.new(sx,sy,sz);p.CFrame=CFrame.new(x,y,z)
    p.Color=Color3.fromRGB(color[1],color[2],color[3]);p.Material=material or Enum.Material.SmoothPlastic
    p.Anchored=true;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent;return p
end
local function label(parent,caption,height,width)
    local g=Instance.new("BillboardGui");g.Name="Label";g.Size=UDim2.fromOffset(width or 290,64)
    g.StudsOffset=Vector3.new(0,height or 5,0);g.AlwaysOnTop=false;g.MaxDistance=130;g.Parent=parent
    local t=Instance.new("TextLabel");t.Size=UDim2.fromScale(1,1);t.BackgroundTransparency=1
    t.Text=caption;t.TextColor3=Color3.fromRGB(247,246,233);t.TextStrokeTransparency=0.25
    t.Font=Enum.Font.GothamBold;t.TextSize=16;t.TextWrapped=true;t.Parent=g
end
local function prompt(parent,name,text,object)
    local p=Instance.new("ProximityPrompt");p.Name=name;p.ActionText=text;p.ObjectText=object
    p.KeyboardKeyCode=Enum.KeyCode.E;p.HoldDuration=0.2;p.MaxActivationDistance=12
    p.RequiresLineOfSight=false;p.Parent=parent;return p
end
local function tree(parent,x,z,h,color,palm)
    local trunk=part(parent,"TreeTrunk",x,6+h/2,z,2.8,h,2.8,{111,80,49},Enum.Material.Wood)
    if palm then
        for i=0,5 do
            local a=i*math.pi/3
            local l=part(parent,"PalmLeaf",x+math.sin(a)*4,6+h,z+math.cos(a)*4,4,0.6,15,color,Enum.Material.Grass)
            l.CFrame=l.CFrame*CFrame.Angles(0,a,0.12);l.CanCollide=false
        end
    else
        for i=0,2 do
            local c=part(parent,"LeafCanopy",x+(i-1)*3,6+h-i*2,z,18-i*3,11,15,color,Enum.Material.Grass)
            c.Shape=Enum.PartType.Ball;c.CanCollide=false
        end
        for _,side in ipairs({-1,1})do
            local branch=part(parent,"Branch",x+side*4,6+h*0.63,z,2.2,h*0.5,2.2,{111,80,49},Enum.Material.Wood)
            branch.CFrame=branch.CFrame*CFrame.Angles(0,0,side*0.65);branch.CanCollide=false
        end
    end
end
local function cylinder(parent,name,x,y,z,height,diameter,color,material)
    local p=part(parent,name,x,y,z,height,diameter,diameter,color,material)
    p.Shape=Enum.PartType.Cylinder;p.CFrame=p.CFrame*CFrame.Angles(0,0,math.pi/2);return p
end
local function npc(parent,name,x,z,shirt,title,action)
    local model=Instance.new("Model");model.Name=name;model.Parent=parent
    local body=part(model,"Body",x,9.3,z,2.5,2.8,1.4,shirt)
    part(model,"Head",x,11.5,z,1.7,1.7,1.7,{224,181,139})
    part(model,"Hat",x,12.4,z,2.6,0.3,2.2,{236,233,209})
    part(model,"HatBand",x,12.5,z,1.8,0.35,1.5,shirt)
    for _,side in ipairs({-1,1})do
        part(model,"Arm",x+side*1.6,9.3,z,0.6,2.5,1,shirt)
        part(model,"Leg",x+side*0.65,7.2,z,0.9,1.6,1.2,{47,57,68})
        part(model,"Eye",x+side*0.36,11.65,z-0.88,0.17,0.17,0.1,{24,30,35})
    end
    label(body,title,5.1);prompt(body,name.."Prompt",action,title)
    return body
end
local function dock(folder,d)
    local x,z=d.DockX,d.DockZ
    local m=Instance.new("Model");m.Name="Dock_"..d.Id;m.Parent=folder
    -- 34-stud pier joins the island shore; wide end leaves the captain unobstructed.
    part(m,"Boardwalk",x,7,z-9,12,1,36,{142,106,72},Enum.Material.WoodPlanks)
    part(m,"Jetty",x,7,z+6,30,1,14,{164,122,78},Enum.Material.WoodPlanks)
    for _,dx in ipairs({-13,13})do
        part(m,"Pile",x+dx,1,z+9,1.3,15,1.3,{99,77,53},Enum.Material.Wood)
        part(m,"Bollard",x+dx,8.2,z+9,1.5,1.4,1.5,{68,78,83},Enum.Material.Metal)
    end
    local cap=npc(m,"Captain",x-7,z+2,{49,99,124},d.Id=="Cove" and "КАПИТАН МИРОН · ЛОДКИ" or "ПРИЧАЛ · ВЫЗОВ ЛОДКИ","Лодки / вызвать")
    local shop=part(m,"Canopy",x-7,15,z+2,11,0.4,8,d.Color)
    for _,dx in ipairs({-12,-2})do part(m,"ShopPole",x+dx,10.7,z+3,0.5,8.3,0.5,{105,85,58},Enum.Material.Wood)end
    local s=part(m,"DockSign",x+8,9,z+1,0.6,3,0.6,{123,98,61},Enum.Material.Wood)
    label(s,d.Name.."\nM — карта · E у капитана",5,320)
    -- Steps make manual swimming access possible even with a low dock approach.
    for i=0,5 do part(m,"WaterStep",x+12,0.25+i*1.2,z+23-i*2.4,7,1.2,3,{150,112,76},Enum.Material.WoodPlanks)end
    if d.Id~="Cove" and d.Id~="Reef" then
        npc(m,"Buyer",x+7,z-13,{186,131,70},"СКУПЩИК · ПРОДАЖА УЛОВА","Продать весь улов")
    end
end
local function island(folder,d)
    local m=Instance.new("Model");m.Name=d.Id;m.Parent=folder
    local sand=d.Theme=="sand";local moss=d.Theme=="moss";local storm=d.Theme=="storm"
    local ground=sand and {223,181,109} or (storm and {90,105,122} or {122,156,102})
    cylinder(m,"IslandStone",d.X,-2,d.Z,15,d.Radius*2+8,storm and {54,67,83} or {126,126,107},Enum.Material.Rock)
    cylinder(m,"Shore",d.X,5,d.Z,2.6,d.Radius*2,{228,207,163},Enum.Material.Sand)
    cylinder(m,"Plateau",d.X,6.5,d.Z,1.5,d.Radius*1.78,ground,sand and Enum.Material.Sand or (storm and Enum.Material.Slate or Enum.Material.Grass))
    part(m,"IslandPath",d.X,7.3,d.Z,10,0.2,d.Radius*2+10,{204,183,142},Enum.Material.Sand)
    part(m,"FishingPier",d.X,7,d.Z-d.Radius-12,14,1,32,{151,114,78},Enum.Material.WoodPlanks)
    part(m,"FishingDeck",d.X,7,d.Z-d.Radius-28,27,1,14,{164,124,86},Enum.Material.WoodPlanks)
    local marker=part(m,"FishingMarker",d.X-10,9,d.Z-d.Radius-27,0.7,4,0.7,{102,78,46},Enum.Material.Wood)
    label(marker,"РЫБАЛКА · УРОВЕНЬ "..d.Level.."\n"..d.Target,4.5,350)
    local beacon=part(m,"IslandBeacon",d.X,9,d.Z+18,4,0.3,4,d.Color,Enum.Material.Neon);beacon.CanCollide=false
    label(beacon,d.Name.."\nУровень "..d.Level,18,320)
    for i=1,8 do
        local a=i*2.37;local r=d.Radius*0.64
        local x,z=d.X+math.sin(a)*r,d.Z+math.cos(a)*r
        if math.abs(x-d.X)>12 then
            if not storm then tree(m,x,z,sand and 15 or 20+i%3*3,
                sand and {82,139,92} or (moss and {64,130,73} or {232,155,185}),sand)
            else
                local stone=part(m,"BasaltSpire",x,10+i,z,7+i%3,18+i*2,8,{65+i*3,78+i*3,98+i*3},Enum.Material.Slate,"WedgePart")
                stone.CFrame=stone.CFrame*CFrame.Angles(0,a,0)
            end
        end
    end
    if sand then
        -- Sandstone temple, obelisks, and oasis; no paid/external meshes.
        for i=0,4 do part(m,"TempleTier",d.X+27,8+i*3,d.Z-5,29-i*4,3,29-i*4,{204+i*6,162+i*6,95+i*6},Enum.Material.Sandstone)end
        for _,z in ipairs({-21,18})do
            local ob=part(m,"Obelisk",d.X-23,15,d.Z+z,3.5,16,3.5,{233,187,107},Enum.Material.Sandstone)
            part(m,"SunCap",d.X-23,24,d.Z+z,4,3,4,{255,205,85},Enum.Material.Neon,"WedgePart")
        end
        local oasis=cylinder(m,"Oasis",d.X-30,7.5,d.Z-4,0.18,20,{64,183,193},Enum.Material.Glass);oasis.CanCollide=false
    elseif moss then
        for i=1,11 do
            local a=i*2.1;local x,z=d.X+math.sin(a)*28,d.Z+math.cos(a)*31
            if math.abs(x-d.X)>7 then
                part(m,"MushroomStem",x,8.5,z,0.7,3,0.7,{208,198,151})
                local sh=part(m,"MushroomCap",x,10.1,z,3.7,1.2,3.7,{99,207,145},Enum.Material.Neon);sh.Shape=Enum.PartType.Ball;sh.CanCollide=false
            end
        end
        part(m,"GroveArchTop",d.X+24,18,d.Z-8,22,4,5,{95,112,87},Enum.Material.Rock)
        for _,dx in ipairs({15,33})do part(m,"GroveArch",d.X+dx,12,d.Z-8,4,14,5,{95,112,87},Enum.Material.Rock)end
    elseif d.Theme=="bloom" then
        cylinder(m,"CupPlinth",d.X+24,9,d.Z,4,23,{224,188,147},Enum.Material.Marble)
        cylinder(m,"CappuccinoCup",d.X+24,16,d.Z,12,17,{245,225,184},Enum.Material.Marble)
        cylinder(m,"CoffeeSurface",d.X+24,22.1,d.Z,0.3,15,{136,83,39})
        cylinder(m,"LatteFoam",d.X+24,22.3,d.Z,0.25,9,{239,208,150})
        part(m,"CupHandleTop",d.X+35,20,d.Z,7,2.2,2.2,{245,225,184})
        part(m,"CupHandleSide",d.X+38,16,d.Z,2.2,8,2.2,{245,225,184})
        part(m,"CupHandleBottom",d.X+35,12,d.Z,7,2.2,2.2,{245,225,184})
    else
        for i=0,4 do
            local a=i*math.pi*2/5;local x,z=d.X+math.sin(a)*17-24,d.Z+math.cos(a)*17
            local c=part(m,"StormCrystal",x,14+i%2*2,z,4,16,4,{137,157,234},Enum.Material.Neon,"WedgePart")
            c.CFrame=c.CFrame*CFrame.Angles(0,a,0.2)
        end
    end
end
local function caption(parent,text)
    local gui=parent and parent:FindFirstChild("Label")
    local label=gui and gui:FindFirstChildOfClass("TextLabel")
    if label then label.Text=text end
end
local function relocate(model,anchor,x,z)
    if not anchor then return end
    local delta=Vector3.new(x-anchor.Position.X,0,z-anchor.Position.Z)
    if delta.Magnitude>0.001 then
        -- PivotTo preserves every part's relative pose, including user additions.
        model:PivotTo(CFrame.new(delta)*model:GetPivot())
    end
end
function A.Build()
    local existing=Workspace:FindFirstChild("QuietCoveArchipelago")
    if existing then
        for _,d in ipairs(Config.Islands)do
            if d.Theme~="home" and d.Theme~="reef" then
                local m=existing:FindFirstChild(d.Id)
                if m then
                    relocate(m,m:FindFirstChild("IslandStone"),d.X,d.Z)
                    caption(m:FindFirstChild("FishingMarker"),"РЫБАЛКА · УРОВЕНЬ "..d.Level.."\n"..d.Target)
                    caption(m:FindFirstChild("IslandBeacon"),d.Name.."\nУровень "..d.Level)
                else island(existing,d)end
            end
            local berth=existing:FindFirstChild("Dock_"..d.Id)
            if berth then
                relocate(berth,berth:FindFirstChild("Boardwalk"),d.DockX,d.DockZ-9)
                caption(berth:FindFirstChild("DockSign"),d.Name.."\nM — карта · E у капитана")
            else dock(existing,d)end
        end
        return existing
    end
    local folder=Instance.new("Model");folder.Name="QuietCoveArchipelago";folder.Parent=Workspace
    for _,d in ipairs(Config.Islands)do
        if d.Theme~="home" and d.Theme~="reef" then island(folder,d)end
        dock(folder,d)
    end
    -- Connect home to the new south-facing harbour without altering original parts.
    part(folder,"HarborPath",0,7.25,38,11,0.15,56,{218,201,155},Enum.Material.Sand)
    local sign=part(folder,"HomeHarborSign",11,9,-8,0.6,4,0.6,{127,101,64},Enum.Material.Wood)
    label(sign,"ЛОДОЧНАЯ ВЕРФЬ → ЮГ\nM — карта островов",4.5,300)
    return folder
end
function A.Attach(world)
    local folder=A.Build();world.Docks={};world.Buyers={world.Merchant}
    for _,d in ipairs(Config.Islands)do
        local m=folder:FindFirstChild("Dock_"..d.Id)
        world.Docks[d.Id]={Id=d.Id,Name=d.Name,Captain=m.Captain.Body,
            Position=Vector3.new(d.DockX,10,d.DockZ+5),
            Berth=Vector3.new(d.DockX+30,Config.Ocean.BoatHeight,d.DockZ+15),Land=Vector3.new(d.DockX+2,11,d.DockZ+5)}
        if m:FindFirstChild("Buyer")then table.insert(world.Buyers,m.Buyer.Body)end
        if d.Theme~="home" and d.Theme~="reef" then
            world.Spots[d.Id]={Center=Vector3.new(d.X,8,d.Z-d.Radius-25),Name=d.Name,Radius=23,Level=d.Level}
        else world.Spots[d.Id].Level=d.Level end
    end
    return world
end
return A
