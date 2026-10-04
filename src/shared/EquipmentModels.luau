-- Original, asset-free models. Used by server tools/boats and client shop previews.
local Models={}
local function rgb(t)return Color3.fromRGB(t[1],t[2],t[3])end
local function part(parent,name,size,cf,color,material,class)
    local p=Instance.new(class or "Part");p.Name=name;p.Size=size;p.CFrame=cf
    p.Color=rgb(color);p.Material=material or Enum.Material.SmoothPlastic
    p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Massless=true
    p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent
    return p
end
local function weld(root,p)
    local w=Instance.new("WeldConstraint");w.Part0=root;w.Part1=p;w.Parent=p
end
local function finish(root,parent,preview)
    for _,p in ipairs(parent:GetDescendants())do
        if p:IsA("BasePart")then
            p.Anchored=preview==true
            if p~=root then weld(root,p)end
        end
    end
end
function Models.Rod(id,preview)
    local tool=Instance.new("Tool");tool.Name="Удочка";tool.CanBeDropped=false
    tool.ToolTip="ЛКМ — рыбалка · ПРОБЕЛ — прыжок"
    tool:SetAttribute("QuietCoveRod",true);tool:SetAttribute("RodStyle",id)
    local wood=id=="wood";local carbon=id=="carbon";local astral=id=="astral"
    local base=wood and {111,82,55} or (carbon and {76,81,91} or {29,69,102})
    local trim=wood and {194,159,92} or (carbon and {185,190,198} or {108,240,222})
    if astral then base={206,212,231};trim={214,112,246} end
    -- The grip is near the butt, never in the middle of a 5.4-stud shaft.
    local h=part(tool,"Handle",Vector3.new(wood and 0.24 or 0.27,0.50,wood and 0.24 or 0.27),CFrame.new(),base,
        wood and Enum.Material.Wood or Enum.Material.SmoothPlastic)
    local top=3.95
    if wood then
        part(tool,"WoodBlank",Vector3.new(0.17,3.70,0.17),CFrame.new(0,2.10,0),base,Enum.Material.Wood)
    else
        for i=1,4 do
            local width=0.21-i*0.032
            local y=0.26+(i-0.5)*0.84
            part(tool,"TaperedBlank"..i,Vector3.new(width,0.86,width),CFrame.new(0,y,0),base,Enum.Material.Metal)
            part(tool,"BlankBand"..i,Vector3.new(width+0.03,0.07,width+0.03),CFrame.new(0,y-0.3,0),trim,Enum.Material.Metal)
        end
        local tip=part(tool,"PointedTip",Vector3.new(0.12,0.45,0.10),CFrame.new(0,3.85,0)*CFrame.Angles(0,0,math.pi),trim,
            carbon and Enum.Material.Metal or Enum.Material.Neon,"WedgePart")
        if not carbon then
            for _,side in ipairs({-1,1})do
                part(tool,"TideFork",Vector3.new(0.14,1.1,0.16),CFrame.new(side*0.23,3.15,0)*CFrame.Angles(0,0,-side*0.23),trim,Enum.Material.Neon,"WedgePart")
            end
            local gem=part(tool,"TideCrystal",Vector3.new(0.32,0.38,0.32),CFrame.new(0,0.12,0)*CFrame.Angles(0,math.pi/4,0),trim,Enum.Material.Neon,"WedgePart")
            local light=Instance.new("PointLight");light.Color=rgb(trim);light.Brightness=0.6;light.Range=4;light.Parent=gem
        end
        for i=0,5 do
            part(tool,"GripWrap",Vector3.new(0.30,0.055,0.30),CFrame.new(0,-0.20+i*0.10,0),{37,42,47})
        end
    end
    if astral then
        for _,side in ipairs({-1,1})do
            part(tool,"AstralStar",Vector3.new(0.16,0.9,0.2),CFrame.new(side*0.2,3.25,0)*CFrame.Angles(0,0,side*0.6),trim,Enum.Material.Neon,"WedgePart")
        end
    end
    local seat=part(tool,"ReelSeat",Vector3.new(0.30,0.30,0.30),CFrame.new(0,0.15,0),trim,Enum.Material.Metal)
    seat.Shape=Enum.PartType.Cylinder
    local reel=part(tool,"ReelBody",Vector3.new(0.44,0.52,0.52),CFrame.new(0.28,0.15,0),wood and {53,69,86} or base,Enum.Material.Metal)
    reel.Shape=Enum.PartType.Cylinder
    local spool=part(tool,"Spool",Vector3.new(0.47,0.32,0.32),CFrame.new(0.28,0.15,0),trim,Enum.Material.Metal)
    spool.Shape=Enum.PartType.Cylinder
    part(tool,"ReelCrank",Vector3.new(0.10,0.32,0.10),CFrame.new(0.56,0.16,0),trim,Enum.Material.Metal)
    local knob=part(tool,"HandleKnob",Vector3.new(0.18,0.18,0.18),CFrame.new(0.56,0,0),base);knob.Shape=Enum.PartType.Ball
    if wood then local orb=part(tool,"TipOrb",Vector3.new(0.19,0.19,0.19),CFrame.new(0,top-0.05,0),{111,240,227},Enum.Material.Neon);orb.Shape=Enum.PartType.Ball end
    local tip=Instance.new("Attachment");tip.Name="Tip";tip.Position=Vector3.new(0,top,0);tip.Parent=h
    local right=Instance.new("Attachment");right.Name="CastMainGrip"
    right.CFrame=CFrame.new(0,-0.25,0)*CFrame.Angles(0,0,math.rad(-65));right.Parent=h
    local left=Instance.new("Attachment");left.Name="CastSupportGrip"
    -- The left support hand is ahead of the right main/reel hand.
    left.CFrame=CFrame.new(0,0.25,0)*CFrame.Angles(0,0,math.rad(65));left.Parent=h
    -- Native one-hand carry: a small outward offset keeps the reel/crystal
    -- outside the thigh even with a small avatar's arm hanging down.
    tool.Grip=CFrame.new(-0.14,-0.25,0)
    finish(h,tool,preview)
    return tool
end
function Models.Boat(def,preview)
    local model=Instance.new("Model");model.Name=def.Name
    local cat=def.Id=="catamaran";local skiff=def.Id=="skiff"
    local length=cat and 23 or (skiff and 14 or (def.Id=="motor" and 17 or 21))
    local width=cat and 15 or (skiff and 7 or 9)
    local root=part(model,"Hull",Vector3.new(width,1.8,length),CFrame.new(),def.Color,skiff and Enum.Material.WoodPlanks or Enum.Material.Metal)
    root.Massless=false;root.CanCollide=true;root.CanTouch=true;root.CanQuery=true
    -- The hull is low-density; a Y-only constraint stabilises its waterline.
    root.CustomPhysicalProperties=PhysicalProperties.new(0.45,0.3,0.05,1,1)
    model.PrimaryPart=root
    local function add(name,size,x,y,z,color,material,class)
        return part(model,name,size,CFrame.new(x,y,z),color,material,class)
    end
    add("TeakDeck",Vector3.new(width-0.7,0.22,length-1),0,1,0,skiff and {178,132,83} or {209,193,155},Enum.Material.WoodPlanks)
    if cat then
        root.Transparency=1
        for _,side in ipairs({-1,1})do
            add("Pontoon",Vector3.new(3.3,2.6,length),side*5.8,-0.1,0,def.Color,Enum.Material.Metal)
            add("PontoonBow",Vector3.new(3.3,2.6,4),side*5.8,-0.1,-length/2-2,def.Color,Enum.Material.Metal,"WedgePart")
        end
    else
        add("PointedBow",Vector3.new(width,1.8,3.5),0,0,-length/2-1.7,def.Color,root.Material,"WedgePart")
    end
    for _,side in ipairs({-1,1})do
        add("Gunwale",Vector3.new(0.40,1.1,length),side*(width/2-0.15),1.35,0,def.Color,root.Material)
        add("AccentRail",Vector3.new(0.44,0.15,length-0.4),side*(width/2-0.12),1.94,0,def.Accent,
            cat and Enum.Material.Neon or Enum.Material.SmoothPlastic)
        if skiff then
            local oar=add("OarShaft",Vector3.new(0.2,0.2,10),side*4.5,1.6,1,{164,118,63},Enum.Material.Wood)
            oar.CFrame=oar.CFrame*CFrame.Angles(0,side*0.68,0)
            add("OarBlade",Vector3.new(1,0.2,2.1),side*7.1,1.6,4.2,{177,132,77},Enum.Material.Wood)
        end
    end
    local seat=part(model,"PilotSeat",Vector3.new(2.4,0.65,2.2),CFrame.new(0,1.5,skiff and 1.8 or -0.1),{38,45,53},nil,"VehicleSeat")
    seat.HeadsUpDisplay=false;seat.CanTouch=true;seat.CanCollide=true;seat.CanQuery=true
    seat.MaxSpeed=0;seat.Torque=0;seat.TurnSpeed=0 -- Controller uses modern constraints, not wheel hinges.
    seat:SetAttribute("QuietCoveBoatSeat",true)
    add("SeatBack",Vector3.new(2.4,1.9,0.3),0,2.3,skiff and 2.9 or 1,{38,45,53})
    if skiff then
        add("FrontBench",Vector3.new(6,0.42,1.8),0,1.55,-3,def.Accent,Enum.Material.Wood)
    else
        add("Console",Vector3.new(3.8,1.6,1.2),0,1.9,-2.1,def.Color,Enum.Material.Metal)
        local screen=add("Windshield",Vector3.new(6,1.7,0.22),0,3.1,-2.5,{144,219,235},Enum.Material.Glass)
        screen.Transparency=0.45;screen.CFrame=screen.CFrame*CFrame.Angles(-0.2,0,0)
        for _,side in ipairs({-1,1})do
            add("Outboard",Vector3.new(1.5,2.4,1.8),side*(cat and 4.7 or 2.2),0.2,length/2+0.3,{42,48,56},Enum.Material.Metal)
            add("NavigationLight",Vector3.new(0.33,0.22,1.2),side*(width/2-0.2),2,-length/2+1,def.Accent,Enum.Material.Neon)
        end
        if cat or def.Id=="cutter" then
            for _,side in ipairs({-1,1})do add("CanopyPole",Vector3.new(0.15,3.4,0.15),side*3,3,2.2,def.Accent,Enum.Material.Metal)end
            add("Canopy",Vector3.new(7.5,0.25,5.7),0,4.75,0.8,def.Color)
            add("Antenna",Vector3.new(0.10,2.4,0.10),2,6,1,def.Accent,Enum.Material.Metal)
        end
    end
    finish(root,model,preview)
    return model
end
return Models
