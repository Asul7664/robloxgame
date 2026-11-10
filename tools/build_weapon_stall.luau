-- Two original tropical weapon shops, mapped by Rojo as one static Model.
-- lune run tools/build_weapon_stall.luau
-- Root Displays is the authoritative source of all ten equipped weapons.
local fs=require('@lune/fs')
local roblox=require('@lune/roblox')
local luau=require('@lune/luau')
local Instance,V,CF,C,Enum=roblox.Instance,roblox.Vector3,roblox.CFrame,roblox.Color3,roblox.Enum
local palette=luau.load(fs.readFile('src/shared/VisualTheme.luau'),{environment={Color3=C}})().Palette
local Models=luau.load(fs.readFile('src/server/WeaponModels.luau'),{environment={
    Instance=Instance,Vector3=V,CFrame=CF,Color3=C,Enum=Enum,
}})()
local root=Instance.new('Model');root.Name='WeaponStall'
root:SetAttribute('WeaponShop',true);root:SetAttribute('GeneratedVersion',3)
local displays=Instance.new('Folder');displays.Name='Displays';displays.Parent=root
local cream=palette.Cream
local wood=C.fromRGB(156,105,70)
local lightWood=C.fromRGB(206,162,110)
local darkWood=C.fromRGB(91,60,43)
local bronze=C.fromRGB(185,134,65)
local navy=C.fromRGB(39,66,86)
local swordGold=C.fromRGB(232,186,91)
local gunBlue=C.fromRGB(66,141,176)
local labels={}
local function part(parent,name,size,frame,color,collide,material,shape)
    local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=frame;p.Color=color
    p.Material=material or Enum.Material.WoodPlanks;p.Anchored=true
    p.CanCollide=collide==true;p.CanQuery=collide==true;p.CanTouch=false
    p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
    if shape then p.Shape=shape end
    p.Parent=parent;return p
end
local function label(parent,name,text,color,wrap)
    local gui=Instance.new('SurfaceGui');gui.Name=name;gui.Face=Enum.NormalId.Front
    gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;gui.PixelsPerStud=90
    gui.LightInfluence=0;gui.Parent=parent
    local item=Instance.new('TextLabel');item.Name='Text';item.BackgroundTransparency=1
    item.Size=roblox.UDim2.fromScale(1,1);item.Text=text;item.Font=Enum.Font.GothamBold
    item.TextColor3=color or cream;item.TextScaled=true;item.TextWrapped=wrap==true
    item.TextStrokeTransparency=1;item.Parent=gui
    local pad=Instance.new('UIPadding');pad.PaddingLeft=roblox.UDim.new(.045,0)
    pad.PaddingRight=roblox.UDim.new(.045,0);pad.PaddingTop=roblox.UDim.new(.1,0)
    pad.PaddingBottom=roblox.UDim.new(.1,0);pad.Parent=item
    labels[parent]=text;return gui
end
local function buildShop(kind,center,name,title,subtitle,accent)
    local shop=Instance.new('Model');shop.Name=name;shop:SetAttribute('WeaponKind',kind);shop.Parent=root
    -- Local -Z/front faces world -X, towards the central island road.
    local frame=CF.new(center)*CF.Angles(0,math.pi*.5,0)
    local function p(n,size,pos,color,collide,material,rotation,shape)
        return part(shop,n,size,frame*CF.new(pos)*(rotation or CF.new()),color,collide,material,shape)
    end
    local floor=p('Floor',V.new(14,.3,10),V.new(0,-.15,0),wood,true)
    shop.PrimaryPart=floor
    if kind=='Saber' then root.PrimaryPart=floor end
    for i=0,13 do
        p('DeckPlank',V.new(.94,.045,9.72),V.new(-6.5+i,.022,0),i%3==0 and lightWood or wood)
    end
    p('FrontDeckFascia',V.new(14,.38,.16),V.new(0,-.06,-4.95),darkWood)
    p('FrontStep',V.new(11.8,.16,.55),V.new(0,-.16,-5.15),lightWood,true)
    for _,x in ipairs({-6.5,6.5}) do for _,z in ipairs({-4.45,4.45}) do
        p('TimberPost',V.new(.4,7.65,.4),V.new(x,3.825,z),darkWood)
        p('PostBase',V.new(.64,.36,.64),V.new(x,.18,z),lightWood)
        p('PostCollar',V.new(.48,.1,.48),V.new(x,2.7,z),accent,false,Enum.Material.Metal)
        p('PostCapital',V.new(.7,.18,.64),V.new(x,7.5,z),lightWood)
    end end
    for _,z in ipairs({-4.45,4.45}) do
        p('CrossBeam',V.new(13.7,.25,.38),V.new(0,7.48,z),wood)
        for _,side in ipairs({-1,1}) do
            p('KneeBrace',V.new(1.32,.16,.22),V.new(side*5.95,7.05,z),lightWood,false,nil,CF.Angles(0,0,side*.65))
        end
    end
    for _,x in ipairs({-6.5,6.5}) do
        p('SideBeam',V.new(.25,.26,9.2),V.new(x,7.5,0),wood)
    end
    -- Light canvas pavilion with a shallow ridge, sewn ribs and a scalloped edge.
    local pitch=math.atan(.95/5.12)
    for i=0,13 do
        local color=i%3==0 and accent or cream
        for _,half in ipairs({-1,1}) do
            p('CanvasRoof',V.new(.995,.12,5.21),V.new(-6.5+i,8.005,half*2.56),color,false,
                Enum.Material.Fabric,CF.Angles(half*pitch,0,0))
        end
        p('CanvasValance',V.new(.995,.28,.12),V.new(-6.5+i,7.45,-5.12),color,false,Enum.Material.Fabric)
    end
    p('RoofRidge',V.new(14,.14,.18),V.new(0,8.52,0),accent,false,Enum.Material.Metal)
    local sign=p('ShopSign',V.new(10.8,1.04,.18),V.new(0,8.02,-5.24),navy)
    label(sign,'ShopName',title,cream)
    p('SignUpperBead',V.new(10.95,.07,.22),V.new(0,8.57,-5.25),accent,false,Enum.Material.Metal)
    p('SignLowerBead',V.new(10.95,.07,.22),V.new(0,7.47,-5.25),accent,false,Enum.Material.Metal)
    -- Solid carved emblem to distinguish each shop without luminous frames.
    local emblem=p('EmblemMedallion',V.new(.15,1.05,1.05),V.new(-6.05,8.02,-5.26),accent,false,
        Enum.Material.Metal,CF.Angles(0,math.pi*.5,0),Enum.PartType.Cylinder)
    if kind=='Saber' then
        p('EmblemBlade',V.new(.14,.65,.06),V.new(-6.05,8.12,-5.38),cream,false,Enum.Material.Metal,CF.Angles(0,0,-.4))
        p('EmblemGuard',V.new(.48,.075,.07),V.new(-5.94,7.84,-5.39),navy,false,Enum.Material.Metal,CF.Angles(0,0,-.4))
        p('EmblemGrip',V.new(.09,.2,.07),V.new(-5.9,7.74,-5.39),darkWood,false,Enum.Material.Wood)
    else
        p('EmblemBarrel',V.new(.12,.68,.06),V.new(-6.13,8.1,-5.38),cream,false,Enum.Material.Metal,CF.Angles(0,0,-.55))
        p('EmblemStock',V.new(.21,.32,.07),V.new(-5.9,7.8,-5.39),darkWood,false,Enum.Material.Wood,CF.Angles(0,0,-.55))
    end
    -- Five individual bays form one unobstructed presentation row.
    p('DisplayWall',V.new(12.45,4.8,.14),V.new(0,4.55,2.16),navy)
    p('DisplayHeader',V.new(12.7,.15,.26),V.new(0,7.02,2.16),lightWood)
    p('DisplayBase',V.new(12.7,.16,.52),V.new(0,2.1,1.96),lightWood)
    for i=1,5 do
        local x=-4.8+(i-1)*2.4
        p('DisplayLinen',V.new(2.17,4.5,.04),V.new(x,4.55,2.06),C.fromRGB(234,222,194),false,Enum.Material.Fabric)
        for _,y in ipairs({2.9,5.65}) do
            p('WeaponPeg',V.new(.095,.1,.35),V.new(x,y,1.88),bronze,false,Enum.Material.Metal)
        end
    end
    local counter=p('Counter',V.new(12.1,2.05,1.45),V.new(0,1.025,-3.6),wood,true)
    counter:SetAttribute('WeaponKind',kind)
    p('CounterTop',V.new(12.55,.18,1.8),V.new(0,2.14,-3.6),lightWood,true)
    for i=0,10 do
        p('CounterPanel',V.new(1.015,1.62,.065),V.new(-5.5+i*1.1,1.06,-4.365),i%2==0 and cream or C.fromRGB(229,215,180))
    end
    p('CounterFootRail',V.new(12.2,.13,.13),V.new(0,.24,-4.42),darkWood)
    p('CounterUpperRail',V.new(12.2,.12,.13),V.new(0,1.89,-4.42),accent)
    local sub=p('CounterSign',V.new(7.5,.74,.08),V.new(0,1.08,-4.45),navy)
    label(sub,'TradeName',subtitle,cream)
    local prompt=Instance.new('ProximityPrompt');prompt.Name='WeaponShopPrompt'
    prompt.ActionText='Посмотреть оружие';prompt.ObjectText=title
    prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.MaxActivationDistance=12
    prompt.HoldDuration=.2;prompt.RequiresLineOfSight=false;prompt:SetAttribute('WeaponKind',kind);prompt.Parent=counter
    -- A restrained pair of workshop details, kept beneath the display window.
    p('StorageChest',V.new(2.2,.9,1.1),V.new(-4.7,.5,3.75),wood)
    p('StorageChestLid',V.new(2.28,.12,1.18),V.new(-4.7,1.01,3.75),lightWood)
    for _,x in ipairs({-5.4,-4.0}) do
        p('ChestBand',V.new(.1,1.02,1.2),V.new(x,.55,3.75),bronze,false,Enum.Material.Metal)
    end
    p('WorkshopStool',V.new(1.18,.15,1.18),V.new(4.9,1.15,3.7),lightWood)
    for _,x in ipairs({4.48,5.32}) do for _,z in ipairs({3.28,4.12}) do
        p('StoolLeg',V.new(.15,1.12,.15),V.new(x,.56,z),darkWood)
    end end
    return shop
end
local shops={
    Saber=buildShop('Saber',V.new(24,7.3,-8),'SwordShop','ЛАВКА КЛИНКОВ','МЕЧИ · САБЛИ · ЯТАГАНЫ',swordGold),
    Musket=buildShop('Musket',V.new(24,7.3,8),'GunShop','ЛАВКА СТРЕЛКА','МУШКЕТЫ · КАРАБИНЫ · ШТУЦЕРЫ',gunBlue),
}
local originals={}
for _,kind in ipairs({'Saber','Musket'}) do
    local source=roblox.deserializeModel(fs.readFile('assets/weapons/'..kind..'.rbxmx'))
    assert(#source==1 and source[1]:IsA('Tool'),'Expected existing native weapon Tool')
    originals[kind]=source[1]
end
for _,entry in ipairs(Models.Tiers) do
    local shop=shops[entry.Kind]
    local model=Models.MakeDisplay(originals[entry.Kind],entry.Id,Models.DisplayFrame(entry.Id,shop.Floor.CFrame))
    model:SetAttribute('WeaponDisplayName',entry.Name);model.Parent=displays
    local offset=Models.DisplayOffset(entry.Id)
    local frame=shop.Floor.CFrame*CF.new(offset.X,2.55,1.29)
    local plaque=part(shop,entry.Id..'Plaque',V.new(2.22,.62,.1),frame,navy)
    plaque:SetAttribute('WeaponId',entry.Id);label(plaque,'WeaponName',entry.Name,cream,true)
end
local function bounds(model,frame)
    local lo=V.new(math.huge,math.huge,math.huge);local hi=-lo
    for _,p in ipairs(model:GetDescendants()) do if p:IsA('BasePart') then
        for _,x in ipairs({-1,1}) do for _,y in ipairs({-1,1}) do for _,z in ipairs({-1,1}) do
            local v=frame:PointToObjectSpace(p.CFrame:PointToWorldSpace(p.Size*V.new(x,y,z)*.5))
            lo=V.new(math.min(lo.X,v.X),math.min(lo.Y,v.Y),math.min(lo.Z,v.Z))
            hi=V.new(math.max(hi.X,v.X),math.max(hi.Y,v.Y),math.max(hi.Z,v.Z))
        end end end
    end end
    return lo,hi
end
local function verify(stall)
    assert(stall.Name=='WeaponStall' and stall:IsA('Model') and stall:GetAttribute('WeaponShop'),'One mapped shop root')
    local displayFolder=stall:FindFirstChild('Displays')
    assert(displayFolder and #displayFolder:GetChildren()==10,'Exactly ten displays, without duplicated hero weapons')
    local partCount=0
    for _,p in ipairs(stall:GetDescendants()) do
        assert(not p:IsA('Tool') and not p:IsA('LuaSourceContainer') and not p:IsA('Humanoid'),'No executable imported models')
        if p:IsA('BasePart') then
            partCount+=1;assert(p.Anchored and not p.CanTouch,'Static anchored scenery only')
            assert(not p.CanCollide or p.Name=='Floor' or p.Name=='FrontStep' or p.Name=='Counter' or p.Name=='CounterTop','Only useful floor and counter collision')
        end
    end
    for _,kind in ipairs({'Saber','Musket'}) do
        local name=kind=='Saber' and 'SwordShop' or 'GunShop'
        local shop=assert(stall:FindFirstChild(name),'Both separate shops must survive XML round trip')
        local floor=assert(shop:FindFirstChild('Floor'));assert(shop.PrimaryPart==floor,'Independent shop placement')
        assert((floor.CFrame.Position-V.new(24,7.15,kind=='Saber' and -8 or 8)).Magnitude<.001,'Shop stays clear of island props')
        assert(floor.CFrame.LookVector:Dot(-V.xAxis)>.999,'Shop opens towards central road')
        local lo,hi=bounds(shop,floor.CFrame)
        assert(lo.X>=-7.01 and hi.X<=7.01,'No canopy overhang into neighboring workshop')
        assert(lo.Z>=-5.5 and hi.Z<=5.3 and lo.Y>=-.16 and hi.Y<8.85,'Planned shop footprint and height '..tostring(lo)..' / '..tostring(hi))
        local prompt=shop.Counter:FindFirstChild('WeaponShopPrompt')
        assert(prompt and prompt.KeyboardKeyCode==Enum.KeyCode.E and prompt:GetAttribute('WeaponKind')==kind,'One family-specific counter prompt per shop')
        assert(prompt.MaxActivationDistance==12 and not prompt.RequiresLineOfSight,'Usable counter interaction')
        assert(shop.ShopSign.ShopName.Text.Text~='' and shop.CounterSign.TradeName.Text.Text~='','Readable family shop signs')
        local previousMin=math.huge
        for _,entry in ipairs(Models.Tiers) do if entry.Kind==kind then
            local display=assert(displayFolder:FindFirstChild(entry.Id..'Display'))
            assert(display.PrimaryPart==display.Handle and display:GetAttribute('WeaponId')==entry.Id,'Complete uniquely identified display')
            local min,max=bounds(display,floor.CFrame)
            assert(max.X<previousMin-.025,'Separated display silhouettes cannot overlap')
            assert(min.X> -6.2 and max.X<6.2 and min.Y>2.1 and max.Y<7.1,'Weapon remains fully above counter within its own shop')
            previousMin=min.X
            local plaque=assert(shop:FindFirstChild(entry.Id..'Plaque'))
            assert(plaque.WeaponName.Text.Text==entry.Name,'Full unique weapon names survive UTF-8 serialization')
            for _,p in ipairs(display:GetDescendants()) do if p:IsA('BasePart') then
                assert(not p.CanCollide and not p.CanQuery and not p.CanTouch,'Display physics cannot obstruct combat or movement')
            end end
            if entry.Id==kind then
                local count,expected=0,0
                for _,p in ipairs(display:GetDescendants()) do if p:IsA('BasePart') then count+=1 end end
                for _,p in ipairs(originals[kind]:GetDescendants()) do if p:IsA('BasePart') then expected+=1 end end
                assert(count==expected,'Native held model geometry preserved')
            end
        end end
    end
    return partCount
end
verify(root)
local path='assets/weapons/WeaponStall.rbxmx'
fs.writeFile(path,roblox.serializeModel({root},true))
local loaded=roblox.deserializeModel(fs.readFile(path));assert(#loaded==1,'One Rojo root')
local count=verify(loaded[1])
print(string.format('PASS %s: two separated shops, %d anchored parts, ten nonoverlapping displays, full UTF-8 names, two prompts, XML round-trip',path,count))
