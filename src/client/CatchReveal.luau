-- Shared, presentation-only catch reveal for all ten supplied portraits.
-- Only confirmed server Caught events (or local Studio previews) open this UI.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Sprite = require(script.Parent:WaitForChild("CatchSprite"))
local ModelView = require(script.Parent:WaitForChild("CreatureViewport"))
local Reveal = {}; Reveal.__index = Reveal
local WHITE = Color3.fromRGB(247,248,242)
local RARITY_NAMES = {"COMMON · ОБЫЧНЫЙ УЛОВ", "UNCOMMON · НЕОБЫЧНЫЙ УЛОВ", "RARE · РЕДКИЙ УЛОВ",
    "EPIC · ЭПИЧЕСКИЙ УЛОВ", "LEGENDARY · ЛЕГЕНДАРНЫЙ УЛОВ", "MYTHICAL · МИФИЧЕСКИЙ УЛОВ"}
local function make(class, properties, parent)
    local obj = Instance.new(class)
    for k,v in pairs(properties) do obj[k]=v end
    obj.Parent=parent; return obj
end
local function label(parent, name, y, size, height, color, bold)
    return make("TextLabel", {Name=name, Text="", Position=UDim2.fromOffset(12,y),
        Size=UDim2.new(1,-24,0,height), BackgroundTransparency=1,
        Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham, TextSize=size,
        TextColor3=color, TextXAlignment=Enum.TextXAlignment.Center, TextWrapped=true, ZIndex=5},parent)
end
function Reveal.new(gui, config, callbacks)
    local self = setmetatable({Visible=false, Closing=false, Token=0, Tweens={},
        Config=config, Callbacks=callbacks or {}, Cache={}, UseSerial=0, Dead=false,
        ForcePortable=gui:GetAttribute("CatchForcePortable")==true or gui:GetAttribute("SahurForcePortable")==true},Reveal)
    local host = make("Frame", {Name="CatchPortraitReveal", AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.fromScale(0.5,0.48), Size=UDim2.fromOffset(440,445),
        BackgroundTransparency=1, Visible=false, ZIndex=40},gui)
    self.Host=host; self.FitScale=make("UIScale",{Scale=1},host)
    local card=make("CanvasGroup",{Name="AnimatedCard",Size=UDim2.fromScale(1,1),
        Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),
        BackgroundTransparency=1,GroupTransparency=0,ZIndex=40},host)
    self.Card=card;self.PopScale=make("UIScale",{Scale=1},card)
    self.Heading=label(card,"Rarity",8,14,24,WHITE,true)
    local halo=make("Frame",{Name="RarityHalo",BackgroundTransparency=1,AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.fromOffset(220,185),Size=UDim2.fromOffset((config.CatchVisuals or {}).HaloSize or 338,(config.CatchVisuals or {}).HaloSize or 338),ZIndex=1},card)
    self.Halo=halo;self.GlowScale=make("UIScale",{Scale=1},halo);self.Discs={}
    local previousAlpha=0
    for i=1,36 do
        local fraction=(37-i)/36
        local targetAlpha=((config.CatchVisuals or {}).HaloOpacity or 0.70)*(1-fraction^4)^0.85
        local layerAlpha=(targetAlpha-previousAlpha)/(1-previousAlpha);previousAlpha=targetAlpha
        local disc=make("Frame",{Name="HaloLayer",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
            Size=UDim2.fromScale(fraction,fraction),BorderSizePixel=0,BackgroundColor3=WHITE,
            BackgroundTransparency=1-layerAlpha,ZIndex=1},halo)
        make("UICorner",{CornerRadius=UDim.new(0.5,0)},disc);self.Discs[i]=disc
    end
    self.Rim=make("Frame",{Name="RarityRim",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
        Size=UDim2.fromScale(0.89,0.89),BackgroundTransparency=1,ZIndex=1},halo)
    make("UICorner",{CornerRadius=UDim.new(0.5,0)},self.Rim)
    self.RimStroke=make("UIStroke",{Thickness=1.5,Transparency=0.42,Color=WHITE},self.Rim)
    self.Sparks={}
    for i=1,8 do
        local angle=(i-1)*math.pi/4+0.16
        local star=make("TextLabel",{Name="RaritySpark",Text="✦",BackgroundTransparency=1,
            AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset(220+math.cos(angle)*151,185+math.sin(angle)*137),
            Size=UDim2.fromOffset(23,23),TextSize=i%2==0 and 12 or 18,Font=Enum.Font.GothamBold,
            TextColor3=WHITE,ZIndex=2},card)
        self.Sparks[i]=star
    end
    self.Art=make("Frame",{Name="CatchPortrait",BackgroundTransparency=1,AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.fromOffset(220,185),Size=UDim2.fromOffset(302,302),Rotation=0,ZIndex=3},card)
    self.Loading=label(card,"Loading",174,12,26,WHITE,false)
    self.Loading.Text="Готовим изображение…";self.Loading.Visible=false
    self.Name=label(card,"CatchName",337,24,38,WHITE,true)
    self.Info=label(card,"CatchInfo",378,13,27,WHITE,false)
    self.Badge=label(card,"CatchBadge",405,11,20,WHITE,true)
    self.Hint=label(card,"CloseHint",428,10,14,Color3.fromRGB(173,191,197),false)
    self.Hint.Text="ЛКМ — закрыть"
    local dismiss=make("TextButton",{Name="DismissPortrait",Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1,Text="",AutoButtonColor=false,ZIndex=6},card)
    dismiss.Activated:Connect(function() if self:CanDismiss() then self:Hide(false) end end)
    self.Connection=RunService.RenderStepped:Connect(function()
        if not self.Visible or self.Dead then return end
        local camera=workspace.CurrentCamera
        if camera then
            local v=camera.ViewportSize
            self.FitScale.Scale=math.min(1,math.max(0.2,(v.X-24)/440),math.max(0.2,(v.Y-36)/445))
        end
        local now=os.clock()
        if self.Sprite and self.Sprite.Ready and not self.ArtReadyAt then
            self.ArtReadyAt=now;self.Until=now+4.2
        end
        self.Loading.Visible=not self.Sprite or not self.Sprite.Ready or self.Sprite.Mode=="error"
        self.Loading.Text=self.Sprite and self.Sprite.Mode=="error"
            and "Не удалось показать изображение. Проверь Output." or "Готовим изображение…"
        -- Never trap the player in a failed/slow portrait load.
        if not self.ArtReadyAt and now-self.Started>8 then
            self.ArtReadyAt=now;self.Until=now+4.2
        end
        local t=now-self.Started
        if not self.Closing then
            self.GlowScale.Scale=1+math.sin(t*2.1)*0.025
            if t>0.6 then
                self.Art.Position=UDim2.fromOffset(220,185+math.sin((t-0.6)*2.6)*3)
                self.Art.Rotation=math.sin((t-0.6)*1.6)*1.5
            end
            for i,star in ipairs(self.Sparks) do
                star.TextTransparency=0.18+(1+math.sin(t*2.6+i))*0.22
                star.Rotation=math.sin(t*1.8+i)*12
            end
            if now>=self.Until then self:Hide(false) end
        end
    end)
    host.Destroying:Connect(function()
        self.Dead=true;self.Visible=false;self.Token=self.Token+1
        if self.Connection then self.Connection:Disconnect() end
        self:_cancelTweens()
        for _,entry in pairs(self.Cache) do entry.Sprite:Destroy() end
        self.Cache={}
    end)
    return self
end
function Reveal:HasPortrait(species)
    local fish=self.Config.ById[species]
    return species=="verity" or (fish and fish.UseModelPortrait==true) or Sprite.Has(species)
end
function Reveal:_select(species)
    self.UseSerial=self.UseSerial+1
    for _,entry in pairs(self.Cache) do entry.Sprite:SetVisible(false) end
    local entry=self.Cache[species]
    if not entry then
        -- Keep at most two sprites. Evict before mounting to free native image memory.
        local count,oldest,key=0,math.huge,nil
        for id,value in pairs(self.Cache) do
            count=count+1
            if value.Used<oldest then oldest=value.Used;key=id end
        end
        if count>=2 and key then self.Cache[key].Sprite:Destroy();self.Cache[key]=nil end
        local useModel=(species=="verity" or self.Config.ById[species].UseModelPortrait==true) and not Sprite.Has(species)
        entry={Sprite=useModel and ModelView.Mount(self.Art,species,true,true)or Sprite.Mount(self.Art,species,self.ForcePortable),Used=self.UseSerial}
        self.Cache[species]=entry
    end
    entry.Used=self.UseSerial;entry.Sprite:SetVisible(true);self.Sprite=entry.Sprite
end
function Reveal:_cancelTweens()
    for _,tween in ipairs(self.Tweens) do tween:Cancel() end
    self.Tweens={}
end
function Reveal:_tween(obj,seconds,style,direction,properties)
    local tween=TweenService:Create(obj,TweenInfo.new(seconds,style,direction),properties)
    table.insert(self.Tweens,tween);tween:Play()
end
function Reveal:IsVisible() return self.Visible end
function Reveal:CanDismiss() return self.Visible and not self.Closing and os.clock()-self.Started>0.65 end
function Reveal:Show(record,payload,displayName)
    if self.Dead or not self:HasPortrait(record.Species) then return false end
    local fish=self.Config.ById[record.Species]
    if not fish then return false end
    self:_cancelTweens();self.Token=self.Token+1
    self:_select(record.Species)
    local rgb=self.Config.Rarities[fish.Rarity].Color
    local color=Color3.fromRGB(rgb[1],rgb[2],rgb[3]);self.RarityColor=color
    for _,disc in ipairs(self.Discs) do disc.BackgroundColor3=color end
    for _,star in ipairs(self.Sparks) do star.TextColor3=color end
    self.Heading.TextColor3=color;self.Badge.TextColor3=color;self.RimStroke.Color=color
    local sizes=(self.Config.CatchVisuals or {}).PortraitSizes or {}
    local portraitSize=sizes[fish.Id] or 292
    self.Art.Size=UDim2.fromOffset(portraitSize,portraitSize)
    self.Host:SetAttribute("Preview",payload.Preview==true)
    self.Halo:SetAttribute("Rarity",fish.Rarity);self.Art:SetAttribute("Species",fish.Id)
    self.Visible=true;self.Closing=false;self.Host.Visible=true
    self.Started=os.clock();self.Until=self.Sprite.Ready and self.Started+4.2 or math.huge
    self.ArtReadyAt=self.Sprite.Ready and self.Started or nil
    self.Card.GroupTransparency=1;self.PopScale.Scale=0.70
    self.Art.Position=UDim2.fromOffset(220,203);self.Art.Rotation=-8
    self.Name.Text=displayName or fish.Name
    self.Heading.Text=(payload.Preview and "ПРЕВЬЮ · " or "")..RARITY_NAMES[fish.Rarity]
    self.Info.Text=string.format("%.2f кг  ·  %d монет  ·  +%d опыта",record.Kg,record.Value,payload.XP or 0)
    self.Badge.Text=payload.Preview and "ПРОСМОТР БЕЗ НАГРАД И СОХРАНЕНИЙ" or
        (payload.LevelUp and "НОВЫЙ УРОВЕНЬ!" or (payload.New and "НОВЫЙ В КОЛЛЕКЦИИ!" or "УЛОВ ДОБАВЛЕН В РЮКЗАК"))
    self.Hint.Text=payload.Preview and "P — следующий персонаж  ·  ЛКМ — закрыть" or "ЛКМ — закрыть"
    self.Loading.Visible=not self.Sprite.Ready
    if self.Callbacks.OnOpen then self.Callbacks.OnOpen() end
    self:_tween(self.Card,0.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,{GroupTransparency=0})
    self:_tween(self.PopScale,0.45,Enum.EasingStyle.Back,Enum.EasingDirection.Out,{Scale=1})
    self:_tween(self.Art,0.5,Enum.EasingStyle.Quart,Enum.EasingDirection.Out,{Position=UDim2.fromOffset(220,185),Rotation=0})
    return true
end
function Reveal:Hide(immediate)
    if not self.Visible or (self.Closing and not immediate) then return end
    self:_cancelTweens();self.Token=self.Token+1
    local token=self.Token
    local function complete()
        if self.Dead or token~=self.Token then return end
        self.Visible=false;self.Closing=false;self.Host.Visible=false
        if self.Callbacks.OnClose then self.Callbacks.OnClose() end
    end
    if immediate then complete();return end
    self.Closing=true
    self:_tween(self.Card,0.22,Enum.EasingStyle.Quad,Enum.EasingDirection.In,{GroupTransparency=1})
    self:_tween(self.PopScale,0.22,Enum.EasingStyle.Quad,Enum.EasingDirection.In,{Scale=0.88})
    task.delay(0.22,complete)
end
return Reveal
