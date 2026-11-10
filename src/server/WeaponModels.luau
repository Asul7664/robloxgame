-- The visible shop displays are the authoritative geometry for equipped Tools.
-- Rebuild around the handle instead of carrying the display's world position
-- or its anchored physics into the player's character.
local Models = {}
-- Only visual identity lives here; prices, levels and damage live in Catalog.
Models.Tiers={
    {Id='PracticeSaber',Kind='Saber',Tier=1,Name='Тренировочная сабля'},
    {Id='Saber',Kind='Saber',Tier=2,Name='Сабля'},
    {Id='Cutlass',Kind='Saber',Tier=3,Name='Абордажный тесак'},
    {Id='CorsairSaber',Kind='Saber',Tier=4,Name='Сабля корсара'},
    {Id='Tideblade',Kind='Saber',Tier=5,Name='Клинок прилива'},
    {Id='OldMusket',Kind='Musket',Tier=1,Name='Старый мушкет'},
    {Id='Musket',Kind='Musket',Tier=2,Name='Мушкет'},
    {Id='NavalMusket',Kind='Musket',Tier=3,Name='Флотский мушкет'},
    {Id='CaptainMusket',Kind='Musket',Tier=4,Name='Ружьё капитана'},
    {Id='StormMusket',Kind='Musket',Tier=5,Name='Грозовой мушкет'},
}
local specs={}
for _,entry in ipairs(Models.Tiers) do specs[entry.Id]=entry end
function Models.Kind(id)return assert(specs[id],'Unknown weapon visual '..tostring(id)).Kind end
function Models.DisplayOffset(id)
    local spec=assert(specs[id],'Unknown weapon display')
    if spec.Kind=='Saber' then return Vector3.new(-3.4+(spec.Tier-1)*2,3.6,1.5) end
    return Vector3.new(-4.3+(spec.Tier-1)*2.5,4.4,3.45)
end
function Models.Grip(id)
    -- The saber's +Y blade already follows the native hand grip. Adding
    -- the firearm's quarter-turn would point its blade back at the arm.
    local neutral=CFrame.new(0,.02,0)
    return Models.Kind(id)=="Saber" and neutral or neutral*CFrame.Angles(math.pi*.5,0,0)
end
local function parts(display)
    local result={}
    for _, object in ipairs(display:GetChildren()) do
        if object:IsA("BasePart") then table.insert(result,object) end
    end
    local handle=display:FindFirstChild("Handle")
    table.sort(result,function(a,b)
        if a.Name~=b.Name then return a.Name<b.Name end
        -- The musket has two StockInlay parts with the same name.
        local ap=handle.CFrame:ToObjectSpace(a.CFrame).Position
        local bp=handle.CFrame:ToObjectSpace(b.CFrame).Position
        if ap.X~=bp.X then return ap.X<bp.X end
        if ap.Y~=bp.Y then return ap.Y<bp.Y end
        return ap.Z<bp.Z
    end)
    return result
end
function Models.Key(display,id)
    local handle=assert(display:FindFirstChild("Handle"),"Weapon display needs Handle")
    local tokens={"display-weapon-v3",id}
    local function numbers(...)
        for _,n in ipairs({...}) do
            -- Normalize tiny world-to-local floating point differences.
            local value=math.floor(n*10000+.5)
            table.insert(tokens,tostring(value==0 and 0 or value))
        end
    end
    -- Grip changes must migrate previously purchased inventory for free,
    -- even when every displayed part and attachment remains unchanged.
    numbers(Models.Grip(id):GetComponents())
    for _,part in ipairs(parts(display)) do
        table.insert(tokens,part.ClassName);table.insert(tokens,part.Name)
        table.insert(tokens,tostring(part.Material))
        table.insert(tokens,part:IsA("Part") and tostring(part.Shape) or "")
        numbers(part.Size.X,part.Size.Y,part.Size.Z,part.Color.R,part.Color.G,part.Color.B,
            part.Transparency,part.Reflectance,handle.CFrame:ToObjectSpace(part.CFrame):GetComponents())
        local attachments={}
        for _, child in ipairs(part:GetChildren()) do
            if child:IsA("Attachment") then table.insert(attachments,child) end
        end
        table.sort(attachments,function(a,b)return a.Name<b.Name end)
        for _,attachment in ipairs(attachments) do
            table.insert(tokens,attachment.Name);numbers(attachment.CFrame:GetComponents())
        end
    end
    -- Bounded integer arithmetic remains exact in Lua numbers; this is a
    -- model revision tag, not a security or cryptographic hash.
    local hash=5381
    for _,token in ipairs(tokens) do
        for index=1,#token do hash=(hash*33+string.byte(token,index))%4294967296 end
        hash=(hash*33+124)%4294967296
    end
    return string.format("display-%08x",hash)
end
function Models.Build(display,id)
    local displayHandle=assert(display:FindFirstChild("Handle"),"Weapon display needs Handle")
    assert(displayHandle:IsA("BasePart"),"Weapon display Handle must be a BasePart")
    local tool=Instance.new("Tool")
    tool.Name=id;tool.RequiresHandle=true;tool.CanBeDropped=false
    tool:SetAttribute("WeaponType",Models.Kind(id))
    tool:SetAttribute("WeaponId",id)
    tool:SetAttribute("WeaponModelKey",Models.Key(display,id))
    tool.Grip=Models.Grip(id)
    tool.ToolTip=specs[id].Name.." · ЛКМ — атака"
    for _,part in ipairs(parts(display)) do
        local copy=assert(part:Clone(),"Weapon display part must be archivable")
        for _,child in ipairs(copy:GetDescendants()) do
            if child:IsA("JointInstance") or child:IsA("WeldConstraint")
                or child:IsA("Constraint") or child:IsA("LuaSourceContainer") then child:Destroy() end
        end
        copy.CFrame=displayHandle.CFrame:ToObjectSpace(part.CFrame)
        copy.Anchored=false;copy.Massless=true
        copy.CanCollide=false;copy.CanTouch=false;copy.CanQuery=false
        copy.Parent=tool
    end
    local handle=assert(tool:FindFirstChild("Handle"))
    for _,part in ipairs(tool:GetChildren()) do
        if part:IsA("BasePart") and part~=handle then
            local weld=Instance.new("WeldConstraint")
            weld.Name="HandleWeld";weld.Part0=handle;weld.Part1=part;weld.Parent=part
        end
    end
    return tool
end
local C={steel=Color3.fromRGB(174,187,194),edge=Color3.fromRGB(224,233,234),
    iron=Color3.fromRGB(104,112,117),rust=Color3.fromRGB(135,89,62),
    gold=Color3.fromRGB(226,184,88),wood=Color3.fromRGB(92,58,37),
    blue=Color3.fromRGB(47,104,137),navy=Color3.fromRGB(32,58,81),cyan=Color3.fromRGB(97,224,220)}
local function detail(model,name,size,frame,color,shape,material)
    local p=Instance.new(shape=='Wedge' and 'WedgePart' or 'Part')
    p.Name=name;p.Size=size;p.CFrame=frame;p.Color=color;p.Material=material or Enum.Material.Metal
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
    p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
    if shape=='Cylinder' then p.Shape=Enum.PartType.Cylinder end
    p.Parent=model;return p
end
local function stretchFront(model,factor)
    for _,p in ipairs(parts(model)) do
        if p.CFrame.Position.Y>.48 then
            local pos=p.CFrame.Position
            p.CFrame=CFrame.new(pos.X,.48+(pos.Y-.48)*factor,pos.Z)*(p.CFrame-p.CFrame.Position)
            if p.Name=='Barrel' or p.Name=='Ramrod' then
                p.Size=Vector3.new(p.Size.X*factor,p.Size.Y,p.Size.Z)
                for _,a in ipairs(p:GetChildren()) do
                    if a:IsA('Attachment') then
                        local ap=a.CFrame.Position
                        a.CFrame=CFrame.new(ap.X*factor,ap.Y,ap.Z)*(a.CFrame-a.CFrame.Position)
                    end
                end
            elseif p.Name=='Forestock' or p.Name=='ForestockRidge' or p.Name=='Blade'
                or p.Name:match('^CurvedSteel') or p.Name:match('^SharpenedEdge') or p.Name:match('^Fuller') or p.Name=='Point' then
                p.Size=Vector3.new(p.Size.X,p.Size.Y*factor,p.Size.Z)
            end
        end
    end
end
function Models.MakeDisplay(base,id,frame)
    local spec=assert(specs[id],'Unknown weapon display')
    local reference=assert(base:FindFirstChild('Handle'),'Base display needs Handle')
    local model=Instance.new('Model');model.Name=id..'Display'
    model:SetAttribute('WeaponType',spec.Kind);model:SetAttribute('WeaponId',id)
    model:SetAttribute('WeaponTier',spec.Tier);model:SetAttribute('QCTierDisplayVersion',1)
    for _,p in ipairs(parts(base)) do
        local copy=p:Clone()
        for _,child in ipairs(copy:GetDescendants()) do
            if child:IsA('LuaSourceContainer') or child:IsA('JointInstance') or child:IsA('WeldConstraint') then child:Destroy() end
        end
        copy.CFrame=reference.CFrame:ToObjectSpace(p.CFrame)
        copy.Anchored=true;copy.CanCollide=false;copy.CanTouch=false;copy.CanQuery=false;copy.Parent=model
    end
    model.PrimaryPart=model.Handle
    if id=='PracticeSaber' then
        for _,p in ipairs(parts(model)) do
            if p.Name:match('^CurvedSteel') or p.Name:match('^SharpenedEdge') or p.Name:match('^Fuller')
                or p.Name:match('^KnuckleGuard') or p.Name=='Point' or p.Name=='QuillonTip' then p:Destroy()
            elseif p.Name=='Blade' then p.CFrame=CFrame.new(0,1.76,0);p.Size=Vector3.new(.06,2.65,.28)
            elseif p.Name=='Crossguard' or p.Name=='Pommel' or p.Name=='HiltCollar' then p.Color=C.iron end
        end
        detail(model,'PracticeSteel',Vector3.new(.075,2.18,.27),CFrame.new(0,1.65,0),C.iron)
        detail(model,'PracticePoint',Vector3.new(.075,.45,.27),CFrame.new(0,2.96,0),C.steel,'Wedge')
        for index=1,3 do detail(model,'BladeScratch'..index,Vector3.new(.008,.15,.016),
            CFrame.new(.041,1.1+index*.43,.035)*CFrame.Angles(.5,0,0),C.rust) end
    elseif spec.Kind=='Saber' and spec.Tier>=3 then
        stretchFront(model,({[3]=1.04,[4]=1.1,[5]=1.16})[spec.Tier])
        for _,p in ipairs(parts(model)) do
            if p.Name:match('^CurvedSteel') or p.Name=='Point' then
                p.Size=Vector3.new(p.Size.X*(spec.Tier==5 and 1.3 or 1),p.Size.Y,p.Size.Z*(spec.Tier==3 and 1.45 or 1.2))
                p.Color=spec.Tier==5 and C.blue or C.steel
            elseif p.Name:match('^KnuckleGuard') or p.Name=='Crossguard' or p.Name=='Pommel' then
                p.Color=spec.Tier>=4 and C.gold or C.iron
            elseif p.Name:match('^Fuller') then p.Color=spec.Tier==5 and C.cyan or C.gold end
        end
        detail(model,'GuardPlate',Vector3.new(.15,.24,.95),CFrame.new(0,.43,.08),spec.Tier>=4 and C.gold or C.iron)
        if spec.Tier>=4 then
            for side=-1,1,2 do
                detail(model,'GuardWing',Vector3.new(.12,.36,.36),CFrame.new(0,.46,side*.52)*CFrame.Angles(side*.35,0,0),C.gold,'Wedge')
            end
            detail(model,'HiltMedallion',Vector3.new(.04,.22,.22),CFrame.new(.15,.02,0),spec.Tier==5 and C.cyan or C.gold)
        end
        if spec.Tier==5 then
            for i=1,3 do for side=-1,1,2 do
                detail(model,'TideRune',Vector3.new(.012,.16,.13),CFrame.new(side*.047,1.2+i*.48,.04+i*.037)*CFrame.Angles(.55,0,0),C.cyan,nil,Enum.Material.Neon)
            end end
        end
    elseif spec.Kind=='Musket' and id~='Musket' then
        stretchFront(model,({[1]=.82,[3]=1.08,[4]=1.17,[5]=1.24})[spec.Tier])
        for _,p in ipairs(parts(model)) do
            if p.Name=='Stock' or p.Name=='StockNeck' or p.Name=='Forestock' then
                p.Color=spec.Tier==1 and C.wood or (spec.Tier==5 and C.navy or C.wood:Lerp(C.navy,.25))
            elseif p.Name=='Barrel' then
                p.Color=spec.Tier==1 and C.iron or (spec.Tier==5 and C.blue or C.steel)
                if spec.Tier==5 then p.Size=Vector3.new(p.Size.X,p.Size.Y*1.22,p.Size.Z*1.22) end
            elseif p.Name:match('^BarrelBand') or p.Name:match('^BandTop') or p.Name=='ButtPlate' then p.Color=spec.Tier>=3 and C.gold or C.rust end
            if spec.Tier==1 and (p.Name=='StockInlay' or p.Name:match('^LockScrew')) then p:Destroy() end
        end
        if spec.Tier==1 then
            detail(model,'StockRepairBand',Vector3.new(.365,.12,.57),CFrame.new(0,-1.08,-.07),C.iron)
        elseif spec.Tier>=3 then
            detail(model,'NavalCrest',Vector3.new(.035,.29,.21),CFrame.new(.188,-.85,.01),C.gold)
            detail(model,'StockCheekRest',Vector3.new(.36,.45,.19),CFrame.new(0,-.85,.2),C.wood)
        end
        if spec.Tier>=4 then
            local scope=CFrame.new(0,.7,.58)*CFrame.Angles(0,0,math.pi*.5)
            detail(model,'ScopeTube',Vector3.new(.76,.19,.19),scope,C.navy,'Cylinder')
            for _,y in ipairs({.35,1.05}) do
                detail(model,'ScopeLens',Vector3.new(.035,.2,.2),CFrame.new(0,y,.58)*CFrame.Angles(0,0,math.pi*.5),C.cyan,'Cylinder',Enum.Material.Glass)
            end
            for _,y in ipairs({.47,.9}) do detail(model,'ScopeMount',Vector3.new(.14,.1,.31),CFrame.new(0,y,.44),C.gold) end
        end
        if spec.Tier==5 then
            for _,y in ipairs({.55,1.08,1.61}) do
                detail(model,'StormBarrelBrace',Vector3.new(.34,.095,.4),CFrame.new(0,y,.12),C.gold)
                detail(model,'StormCore',Vector3.new(.025,.27,.065),CFrame.new(.185,y,.12),C.cyan,nil,Enum.Material.Neon)
            end
        end
    end
    frame=frame or CFrame.new()
    for _,p in ipairs(parts(model)) do p.CFrame=frame*p.CFrame end
    return model
end
function Models.Sync(bank,displays)
    local keys={}
    for _,spec in ipairs(Models.Tiers) do
        local id=spec.Id
        if not displays:FindFirstChild(id..'Display') then
            local base=assert(displays:FindFirstChild(spec.Kind..'Display'),'Missing legacy weapon display: '..spec.Kind)
            -- Rear vertical racks: all ten silhouettes fit the original stall.
            local origin=displays.Parent:FindFirstChild('Floor')
            local position=origin and origin.CFrame.Position or base.Handle.CFrame.Position
            local target=CFrame.new(position+Models.DisplayOffset(id))
                *CFrame.Angles(0,math.pi*.5,0)*CFrame.Angles(spec.Kind=='Saber' and -1 or -.65,0,0)
            local variant=Models.MakeDisplay(base,id,target);variant.Parent=displays
        end
        local display=assert(displays:FindFirstChild(id.."Display"),"Missing weapon display: "..id)
        local key=Models.Key(display,id);keys[id]=key
        local current=bank:FindFirstChild(id)
        if not current or not current:IsA("Tool") or current:GetAttribute('WeaponId')~=id or current:GetAttribute("WeaponModelKey")~=key then
            local replacement=Models.Build(display,id)
            if current then current:Destroy() end
            replacement.Parent=bank
        end
    end
    return keys
end
return Models
