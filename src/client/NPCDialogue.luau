-- A server-authored conversation. The client sends only a session/choice ID.
local UIS=game:GetService("UserInputService")
local C=require(game:GetService("ReplicatedStorage"):WaitForChild("QuietCove"):WaitForChild("VisualTheme")).UI
local Dialogue={}
Dialogue.__index=Dialogue
local function make(class,props,parent)
    local obj=Instance.new(class)
    for key,value in pairs(props) do obj[key]=value end
    obj.Parent=parent;return obj
end
local function rounded(parent,radius)
    make("UICorner",{CornerRadius=UDim.new(0,radius or 12)},parent)
end
local function text(parent,name,content,size,position,fontSize,color)
    return make("TextLabel",{Name=name,Text=content,Size=size,Position=position,
        BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=fontSize or 16,
        TextColor3=color or C.Ink,TextWrapped=true,RichText=false,
        TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,ZIndex=46},parent)
end
function Dialogue:IsOpen()return self.Host.Visible end
function Dialogue:Close(sendClose)
    if not self:IsOpen() then return end
    local id,session=self.Id,self.Session
    self.Host.Visible=false;self.Pending=false;self.Id=nil;self.Session=nil
    if self.Callbacks.OnClose then self.Callbacks.OnClose() end
    if sendClose~=false and id and session then self.Send(id,session,"close") end
end
function Dialogue:_choose(choice)
    if not self:IsOpen() or self.Pending or choice.Enabled==false then return end
    self.Pending=true;self.PendingAt=os.clock()
    self.Status.Text="Слушаем ответ…"
    for _,button in ipairs(self.Choices:GetChildren()) do
        if button:IsA("TextButton") then button.Active=false;button.AutoButtonColor=false end
    end
    self.Send(self.Id,self.Session,choice.Id)
end
function Dialogue:_renderChoices()
    for _,child in ipairs(self.Choices:GetChildren()) do
        if not child:IsA("UIListLayout") then child:Destroy() end
    end
    local previous
    for index,choice in ipairs(self.CurrentChoices) do
        local enabled=choice.Enabled~=false
        local button=make("TextButton",{Name="Choice_"..choice.Id,Text=choice.Text or "Продолжить",
            Size=UDim2.new(1,-4,0,44),BackgroundColor3=enabled and (index==1 and C.Gold or C.Panel) or C.Bg,
            TextColor3=enabled and (index==1 and C.Bg or C.Ink) or C.Muted,
            Font=Enum.Font.GothamBold,TextSize=14,TextWrapped=true,BorderSizePixel=0,
            LayoutOrder=index,Selectable=enabled,Active=enabled,AutoButtonColor=enabled,ZIndex=46},self.Choices)
        rounded(button,10)
        make("UIPadding",{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)},button)
        button.Activated:Connect(function()self:_choose(choice)end)
        if previous then previous.NextSelectionDown=button;button.NextSelectionUp=previous end
        previous=button
    end
end
function Dialogue:Handle(kind,payload)
    if kind=="DialogueClose" then self:Close(false);return end
    if kind=="Notice" and self:IsOpen() and type(payload)=="table" then
        self.Status.Text=tostring(payload.Text or "");return
    end
    if kind~="Dialogue" or type(payload)~="table" or type(payload.Id)~="string"
        or type(payload.Session)~="string" then return end
    local open=self:IsOpen()
    if not open and self.Callbacks.CanOpen and not self.Callbacks.CanOpen() then
        self.Send(payload.Id,payload.Session,"close");return
    end
    self.Id,self.Session=payload.Id,payload.Session
    self.Pending=false
    self.Name.Text=tostring(payload.Name or "Житель острова")
    self.Role.Text=tostring(payload.Role or "Разговор")
    self.Speech.Text=tostring(payload.Text or "Привет! Чем могу помочь?")
    self.CurrentChoices={}
    for index,choice in ipairs(type(payload.Choices)=="table" and payload.Choices or {}) do
        if index>8 then break end
        if type(choice)=="table" and type(choice.Id)=="string" then
            table.insert(self.CurrentChoices,{Id=choice.Id,Text=choice.Text,Enabled=choice.Enabled})
        end
    end
    self.Status.Text="Задания и награды выдаёт собеседник"
    self:_renderChoices()
    self.Scroller.CanvasPosition=Vector2.zero
    if not open and self.Callbacks.OnOpen then self.Callbacks.OnOpen() end
    self.Host.Visible=true
end
function Dialogue:Step()
    if self:IsOpen() and self.Pending and os.clock()-self.PendingAt>=6 then
        self.Pending=false;self.Status.Text="Ответ задержался. Можно повторить выбор."
        self:_renderChoices()
    end
end
function Dialogue:Destroy()
    self:Close()
    if self.Input then self.Input:Disconnect();self.Input=nil end
    self.Host:Destroy()
end
function Dialogue.new(gui,send,callbacks)
    local self=setmetatable({Send=send,Callbacks=callbacks or {},CurrentChoices={}},Dialogue)
    self.Host=make("Frame",{Name="NPCConversation",AnchorPoint=Vector2.new(0.5,1),
        Position=UDim2.new(0.5,0,1,-14),Size=UDim2.new(0.94,0,0.74,0),
        BackgroundColor3=C.Bg,BackgroundTransparency=0.02,BorderSizePixel=0,Active=true,Visible=false,ZIndex=45},gui)
    rounded(self.Host,18)
    make("UISizeConstraint",{MaxSize=Vector2.new(620,490)},self.Host)
    make("UIStroke",{Color=C.Aqua,Thickness=1.5,Transparency=0.45},self.Host)
    local icon=text(self.Host,"ConversationIcon","···",UDim2.fromOffset(42,42),UDim2.fromOffset(16,14),27,C.Bg)
    icon.BackgroundTransparency=0;icon.BackgroundColor3=C.Aqua;icon.TextXAlignment=Enum.TextXAlignment.Center
    rounded(icon,14)
    self.Name=text(self.Host,"SpeakerName","",UDim2.new(1,-126,0,25),UDim2.fromOffset(70,12),21)
    self.Name.Font=Enum.Font.GothamBold;self.Name.TextWrapped=false;self.Name.TextTruncate=Enum.TextTruncate.AtEnd
    self.Role=text(self.Host,"SpeakerRole","",UDim2.new(1,-126,0,22),UDim2.fromOffset(70,39),12,C.Aqua)
    local close=make("TextButton",{Name="Close",Text="×",Font=Enum.Font.GothamBold,TextSize=25,
        Size=UDim2.fromOffset(36,36),Position=UDim2.new(1,-50,0,15),BackgroundColor3=C.Panel,
        TextColor3=C.Ink,BorderSizePixel=0,Selectable=true,ZIndex=46},self.Host)
    rounded(close,10);close.Activated:Connect(function()self:Close()end)
    self.Scroller=make("ScrollingFrame",{Name="ConversationContent",Position=UDim2.fromOffset(16,76),
        Size=UDim2.new(1,-32,1,-113),BackgroundTransparency=1,BorderSizePixel=0,
        CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=4,
        ScrollBarImageColor3=C.Aqua,ScrollingDirection=Enum.ScrollingDirection.Y,ZIndex=46},self.Host)
    make("UIListLayout",{Padding=UDim.new(0,14),SortOrder=Enum.SortOrder.LayoutOrder},self.Scroller)
    self.Speech=text(self.Scroller,"Speech","",UDim2.new(1,-6,0,0),UDim2.new(),17)
    self.Speech.TextYAlignment=Enum.TextYAlignment.Top;self.Speech.AutomaticSize=Enum.AutomaticSize.Y;self.Speech.LayoutOrder=1
    self.Choices=make("Frame",{Name="Choices",Size=UDim2.new(1,-4,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1,LayoutOrder=2,ZIndex=46},self.Scroller)
    make("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},self.Choices)
    self.Status=text(self.Host,"ConversationStatus","",UDim2.new(1,-32,0,25),UDim2.new(0,16,1,-32),11,C.Muted)
    self.Input=UIS.InputBegan:Connect(function(input,processed)
        if not processed and input.KeyCode==Enum.KeyCode.Escape and self:IsOpen() then self:Close() end
    end)
    return self
end
return Dialogue
