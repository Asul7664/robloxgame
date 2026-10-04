-- One shared 480x192 atlas, cropped into 96px icons. Only visible rows are mounted.
-- Existing approved art, native EditableImage or bounded portable gradient fallback.
local AssetService=game:GetService("AssetService")
local Sprite=require(script.Parent:WaitForChild("CatchSprite"))
local Data=require(script.Parent:WaitForChild("ThumbnailArt"))
local ModelView=require(script.Parent:WaitForChild("CreatureViewport"))
local Thumbs={};Thumbs.__index=Thumbs
local function make(cl,props,parent)
    local o=Instance.new(cl);for k,v in pairs(props)do o[k]=v end;o.Parent=parent;return o
end
local function circle(o)make("UICorner",{CornerRadius=UDim.new(1,0)},o)end
local function sample(pixels,index,x,y,res)
    local xx=(index%5)*Data.Cell+math.min(Data.Cell-1,math.floor((x+0.5)*Data.Cell/res))
    local yy=math.floor(index/5)*Data.Cell+math.min(Data.Cell-1,math.floor((y+0.5)*Data.Cell/res))
    local p=(yy*Data.Width+xx)*4
    return Color3.fromRGB(buffer.readu8(pixels,p),buffer.readu8(pixels,p+1),buffer.readu8(pixels,p+2)),
        1-buffer.readu8(pixels,p+3)/255
end
function Thumbs:_load()
    if self.Loading or self.Ready or self.Dead or self.Failed then return end
    self.Loading=true
    task.spawn(function()
        local ok,pixels=pcall(Sprite.Decode,Data)
        if self.Dead then return end
        if not ok then self.Loading=false;self.Failed=true;warn("[QuietCove] Thumbnail decode: "..tostring(pixels));return end
        self.Pixels=pixels
        local image
        local native=pcall(function()
            image=AssetService:CreateEditableImage({Size=Vector2.new(Data.Width,Data.Height)})
            assert(image,"No native thumbnail budget")
            image:WritePixelsBuffer(Vector2.zero,Vector2.new(Data.Width,Data.Height),pixels)
            -- Test Content construction inside the guard as well.
            self.Content=Content.fromObject(image)
        end)
        if self.Dead then if image then image:Destroy()end;return end
        if native then self.Image=image else if image then image:Destroy()end;self.Content=nil end
        self.Ready=true;self.Loading=false
    end)
end
function Thumbs:Add(row,fish,known)
    local c=self.Config.Rarities[fish.Rarity].Color
    local color=Color3.fromRGB(c[1],c[2],c[3])
    local root=make("Frame",{Name="Thumbnail_"..fish.Id,Size=UDim2.fromOffset(78,78),
        Position=UDim2.new(0,10,0.5,-39),BackgroundTransparency=1},row)
    local glow=make("Frame",{Name="RarityDisc",Size=UDim2.fromOffset(72,72),Position=UDim2.fromOffset(3,3),
        BackgroundColor3=color,BackgroundTransparency=known and 0.74 or 0.9,BorderSizePixel=0,ZIndex=1},root);circle(glow)
    make("UIStroke",{Color=color,Transparency=known and 0.42 or 0.78,Thickness=1},glow)
    local canvas=make("Frame",{Name="PortraitCrop",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=2},root)
    if not known then
        make("TextLabel",{Name="UnknownBadge",Text="?",Font=Enum.Font.GothamBold,TextSize=20,
            TextColor3=Color3.fromRGB(203,218,222),Size=UDim2.fromOffset(22,25),Position=UDim2.new(1,-22,1,-25),
            BackgroundTransparency=1,ZIndex=4},root)
    end
    local entry={Row=row,Root=root,Canvas=canvas,Species=fish.Id,Known=known==true,Token=0}
    self.Entries[#self.Entries+1]=entry
    return root
end
function Thumbs:_unmount(e)
    e.Token=e.Token+1;e.Active=false;e.Building=false
    if e.Portrait then e.Portrait:Destroy();e.Portrait=nil end
    if e.ModelView then e.ModelView:Destroy();e.ModelView=nil end
    for _,o in ipairs(e.Canvas:GetChildren())do o:Destroy()end
end
function Thumbs:_mount(e)
    if e.Active or e.Building then return end
    if Sprite.Has(e.Species) and Data.Slots[e.Species]==nil then
        e.Portrait=Sprite.Mount(e.Canvas,e.Species,false,e.Known)
        e.Active=e.Portrait~=nil;e.Root:SetAttribute("ThumbnailReady",e.Portrait and e.Portrait.Ready==true);return
    end
    if e.Species=="verity" or self.Config.ById[e.Species].UseModelPortrait==true then
        e.ModelView=ModelView.Mount(e.Canvas,e.Species,false,e.Known)
        e.Active=e.ModelView~=nil;e.Root:SetAttribute("ThumbnailReady",e.Active);return
    end
    local index=Data.Slots[e.Species]
    if index==nil or not self.Ready then return end
    e.Token=e.Token+1;local token=e.Token;e.Building=true
    local function alive()return not self.Dead and e.Token==token and e.Root.Parent~=nil end
    task.spawn(function()
        if not alive()then return end
        local label
        local ok=false
        if self.Image and self.Content then
            ok=pcall(function()
                label=make("ImageLabel",{Name="FishThumbnail",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,
                    ImageContent=self.Content,ImageRectOffset=Vector2.new((index%5)*Data.Cell,math.floor(index/5)*Data.Cell),
                    ImageRectSize=Vector2.new(Data.Cell,Data.Cell),ScaleType=Enum.ScaleType.Fit,
                    ImageColor3=e.Known and Color3.new(1,1,1) or Color3.fromRGB(37,54,65),ZIndex=2},e.Canvas)
            end)
        end
        if not ok then
            if label then label:Destroy()end
            local res,step=64,16
            local root=make("Frame",{Name="PortableThumbnail",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=2},e.Canvas)
            local count=0
            for x=0,res-1 do
                for y=0,res-1,step do
                    if not alive()then root:Destroy();return end
                    local height=math.min(step,res-y);local colors,alphas={},{};local visible=false
                    for j=0,height-1 do
                        local c,a=sample(self.Pixels,index,x,y+j,res)
                        colors[j+1]=e.Known and c or Color3.fromRGB(37,54,65);alphas[j+1]=a
                        if a<0.995 then visible=true end
                    end
                    if visible then
                        local ck={ColorSequenceKeypoint.new(0,colors[1])}
                        local ak={NumberSequenceKeypoint.new(0,alphas[1])}
                        for j=1,height do
                            ck[#ck+1]=ColorSequenceKeypoint.new((j-0.5)/height,colors[j])
                            ak[#ak+1]=NumberSequenceKeypoint.new((j-0.5)/height,alphas[j])
                        end
                        ck[#ck+1]=ColorSequenceKeypoint.new(1,colors[height]);ak[#ak+1]=NumberSequenceKeypoint.new(1,alphas[height])
                        local strip=make("Frame",{Size=UDim2.fromScale(1/res,height/res),Position=UDim2.fromScale(x/res,y/res),
                            BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=2},root)
                        make("UIGradient",{Rotation=90,Color=ColorSequence.new(ck),Transparency=NumberSequence.new(ak)},strip)
                        count=count+1
                    end
                end
                if x%12==11 then task.wait()end
            end
            root:SetAttribute("StripCount",count)
        end
        if alive()then e.Active=true;e.Building=false;e.Root:SetAttribute("ThumbnailReady",true)end
    end)
end
function Thumbs:Update()
    if self.Dead then return end
    local visible=self.IsVisible()
    if not visible then
        for _,e in ipairs(self.Entries)do if e.Active or e.Building then self:_unmount(e)end end
        return
    end
    self:_load()
    local top=self.Scroll.AbsolutePosition.Y-80
    local bottom=top+self.Scroll.AbsoluteSize.Y+160
    local mounted=0
    for _,e in ipairs(self.Entries)do
        local pos=e.Row.AbsolutePosition.Y;local h=e.Row.AbsoluteSize.Y
        local show=e.Row.Parent~=nil and pos+h>top and pos<bottom and mounted<8
        if show then mounted=mounted+1;self:_mount(e)
            if e.Portrait then e.Root:SetAttribute("ThumbnailReady",e.Portrait.Ready==true)end
        elseif e.Active or e.Building then self:_unmount(e)end
    end
end
function Thumbs:Clear()
    for _,e in ipairs(self.Entries)do self:_unmount(e);e.Root:Destroy()end
    self.Entries={}
end
function Thumbs:Destroy()
    if self.Dead then return end
    self.Dead=true;self:Clear()
    if self.Image then self.Image:Destroy();self.Image=nil end
    self.Pixels=nil;self.Content=nil
end
function Thumbs.new(scroll,config,isVisible)
    return setmetatable({Scroll=scroll,Config=config,IsVisible=isVisible,Entries={},Ready=false,Loading=false},Thumbs)
end
return Thumbs
