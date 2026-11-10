-- Boat shop, archipelago map and input. Sends axes/IDs only; never coins or CFrames.
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local Preview=require(script.Parent:WaitForChild("ModelPreview"))
local Voyage={};Voyage.__index=Voyage
local C={Bg=Color3.fromRGB(14,32,43),Panel=Color3.fromRGB(23,47,60),Text=Color3.fromRGB(237,242,230),
    Muted=Color3.fromRGB(169,194,198),Aqua=Color3.fromRGB(95,211,200),Gold=Color3.fromRGB(250,199,111)}
local function make(class,props,parent)
    local o=Instance.new(class);for k,v in pairs(props)do o[k]=v end;o.Parent=parent;return o
end
local function corner(o,r)make("UICorner",{CornerRadius=UDim.new(0,r or 12)},o)end
local function label(p,txt,size,pos,fs,color)
    return make("TextLabel",{Text=txt,Size=size,Position=pos,BackgroundTransparency=1,Font=Enum.Font.Gotham,
        TextSize=fs or 14,TextColor3=color or C.Text,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left},p)
end
local function button(p,txt,size,pos,color)
    local o=make("TextButton",{Text=txt,Size=size,Position=pos,BackgroundColor3=color or C.Aqua,
        TextColor3=C.Bg,Font=Enum.Font.GothamBold,TextSize=13,TextWrapped=true,BorderSizePixel=0},p);corner(o,8);return o
end
local function rgb(t)return Color3.fromRGB(t[1],t[2],t[3])end
function Voyage:IsOpen()return self.Host.Visible end
function Voyage:Seat()
    local c=self.Player.Character;local h=c and c:FindFirstChildOfClass("Humanoid")
    local seat=h and h.SeatPart
    if seat and seat:IsA("VehicleSeat") and seat:GetAttribute("QuietCoveBoatSeat")
        and seat:GetAttribute("OwnerUserId")==self.Player.UserId then return seat end
end
function Voyage:IsDriving()return self:Seat()~=nil end
function Voyage:Close()
    self.Host.Visible=false
    if self.Callbacks.OnClose then self.Callbacks.OnClose()end
end
function Voyage:Open(mode)
    if not self.Callbacks.CanOpen()then return end
    if self.Callbacks.OnOpen then self.Callbacks.OnOpen()end
    self.Mode=mode;self.Host.Visible=true;self:Render()
end
function Voyage:Render()
    for _,o in ipairs(self.Content:GetChildren())do o:Destroy()end
    if self.Mode=="boats" then self:_boats()else self:_map()end
end
function Voyage:_boats()
    local d=self.Data or {Coins=0,XP=0,OwnedBoats={}}
    local island=self.Config.IslandById[self.DockId or "Cove"]
    self.Title.Text="SHIPYARD · "..(d.TestMode and "∞ coins · TESTER" or d.Coins.." coins")
    self.Subtitle.Text=(island and island.Name or "Dock").." · own it forever, launch again for free"
    local scroll=make("ScrollingFrame",{Size=UDim2.fromScale(1,1),CanvasSize=UDim2.fromOffset(0,0),
        AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=4,BackgroundTransparency=1,BorderSizePixel=0},self.Content)
    make("UIListLayout",{Padding=UDim.new(0,10)},scroll)
    for _,def in ipairs(self.Config.Boats)do
        local row=make("Frame",{Size=UDim2.new(1,-8,0,112),BackgroundColor3=C.Panel,BorderSizePixel=0},scroll);corner(row)
        Preview.Create(row,"boat",def,UDim2.fromOffset(155,105),UDim2.fromOffset(2,4))
        local title=label(row,def.Name,UDim2.new(1,-286,0,25),UDim2.fromOffset(155,6),17);title.Font=Enum.Font.GothamBold
        label(row,def.Description.."\nSpeed "..def.Speed.." · level "..def.Level,
            UDim2.new(1,-286,0,65),UDim2.fromOffset(155,34),12,C.Muted)
        local owned=(d.OwnedBoats or {})[def.Id]
        local unlocked=d.TestMode or self.Config.Level(d.XP)>=def.Level
        local affordable=d.TestMode or d.Coins>=def.Price
        local caption=owned and "LAUNCH\nFREE" or (not unlocked and "LEVEL "..def.Level or (d.TestMode and "TESTER\nGET" or def.Price.." COINS\nBUY"))
        local b=button(row,caption,UDim2.fromOffset(112,65),UDim2.new(1,-124,0,23),owned and C.Aqua or C.Gold)
        if not owned and (not unlocked or not affordable)then b.BackgroundColor3=C.Panel;b.TextColor3=C.Muted end
        b.Activated:Connect(function()
            if owned then self.Action:FireServer("BoatSpawn","",def.Id)
            elseif unlocked and affordable then self.Action:FireServer("BoatBuy","",def.Id)end
        end)
    end
end
function Voyage:_map()
    self.Title.Text="ARCHIPELAGO · 6 ISLANDS"
    self.Subtitle.Text="Choose a destination, then sail there. N — north."
    local map=make("Frame",{Size=UDim2.new(0.47,-8,1,0),BackgroundColor3=Color3.fromRGB(25,79,94),BorderSizePixel=0},self.Content);corner(map)
    for i=1,4 do
        make("Frame",{Size=UDim2.new(0,1,1,0),Position=UDim2.fromScale(i/5,0),BackgroundTransparency=0.87,BorderSizePixel=0},map)
        make("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.fromScale(0,i/5),BackgroundTransparency=0.87,BorderSizePixel=0},map)
    end
    label(map,"N ↑",UDim2.fromOffset(70,25),UDim2.fromOffset(12,8),14,C.Aqua)
    for i,island in ipairs(self.Config.Islands)do
        local dot=button(map,tostring(i),UDim2.fromOffset(island.Theme=="home" and 26 or 32,32),
            UDim2.fromScale(0.5+island.X/(self.Config.Ocean.MapSpan or 2800),0.5+island.Z/(self.Config.Ocean.MapSpan or 2800)),rgb(island.Color))
        dot.AnchorPoint=Vector2.new(0.5,0.5);corner(dot,50)
        dot.Activated:Connect(function()self.Target=island.Id;self:Close()end)
    end
    self.PlayerDot=label(map,"▲",UDim2.fromOffset(20,20),UDim2.fromScale(0.5,0.5),20,C.Text)
    self.PlayerDot.AnchorPoint=Vector2.new(0.5,0.5);self.PlayerDot.ZIndex=5
    local list=make("Frame",{Size=UDim2.new(0.53,-6,1,0),Position=UDim2.new(0.47,6,0,0),BackgroundTransparency=1},self.Content)
    make("UIListLayout",{Padding=UDim.new(0,6)},list)
    for i,island in ipairs(self.Config.Islands)do
        local unlocked=not self.Data or self.Config.Level(self.Data.XP)>=island.Level
        local b=button(list,"",UDim2.new(1,0,1/6,-5),UDim2.new(),C.Panel)
        local state=unlocked and "Lv. "..island.Level or "fishing from Lv. "..island.Level
        label(b,i..". "..island.Name.." · "..state,UDim2.new(1,-16,0,23),UDim2.fromOffset(8,2),13,rgb(island.Color))
        label(b,island.Target,UDim2.new(1,-16,1,-25),UDim2.fromOffset(8,23),11,C.Muted)
        b.Activated:Connect(function()self.Target=island.Id;self:Close()end)
    end
end
function Voyage:Handle(kind,payload)
    if kind=="Profile"then
        self.Data=payload.Data
        if self:IsOpen()then self:Render()end
    elseif kind=="BoatShop"then self.DockId=payload.Dock;self:Open("boats")
    elseif kind=="BoatLaunched"then self:Close()end
end
function Voyage.new(gui,config,action,callbacks)
    local self=setmetatable({Config=config,Action=action,Callbacks=callbacks,Player=Players.LocalPlayer,Mode="map",SentAt=0,Target="Dunes",Focused=true},Voyage)
    self.MapButton=button(gui,"M · MAP",UDim2.fromOffset(106,40),UDim2.new(1,-244,0,20),C.Panel)
    self.MapButton.TextColor3=C.Aqua;self.MapButton.ZIndex=12
    self.Host=make("Frame",{Name="VoyageWindow",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
        Size=UDim2.fromOffset(760,530),BackgroundColor3=C.Bg,BorderSizePixel=0,Visible=false,ZIndex=25},gui);corner(self.Host,16)
    self.Scale=make("UIScale",{Scale=1},self.Host)
    self.Title=label(self.Host,"",UDim2.new(1,-70,0,32),UDim2.fromOffset(18,10),21);self.Title.Font=Enum.Font.GothamBold
    self.Subtitle=label(self.Host,"",UDim2.new(1,-38,0,28),UDim2.fromOffset(18,46),12,C.Muted)
    button(self.Host,"×",UDim2.fromOffset(36,32),UDim2.new(1,-47,0,12),C.Gold).Activated:Connect(function()self:Close()end)
    self.Content=make("Frame",{Size=UDim2.new(1,-36,1,-98),Position=UDim2.fromOffset(18,81),BackgroundTransparency=1},self.Host)
    self.Nav=label(gui,"",UDim2.fromOffset(350,48),UDim2.fromOffset(18,102),12,C.Text)
    self.Nav.TextStrokeTransparency=0.25;self.Nav.ZIndex=5
    self.Sail=make("Frame",{Name="SailingHUD",AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-18),
        Size=UDim2.new(0.94,0,0,78),BackgroundColor3=C.Bg,BorderSizePixel=0,Visible=false},gui);corner(self.Sail)
    make("UISizeConstraint",{MaxSize=Vector2.new(650,78)},self.Sail)
    self.Speed=label(self.Sail,"",UDim2.new(1,-140,0,27),UDim2.fromOffset(14,5),16,C.Aqua)
    label(self.Sail,"W/S — throttle · A/D — steer · M — map\nE near a dock — disembark · SPACE — stand up",UDim2.new(1,-140,0,40),UDim2.fromOffset(14,32),11,C.Muted)
    button(self.Sail,"E · DISEMBARK",UDim2.fromOffset(118,46),UDim2.new(1,-128,0,15),C.Gold).Activated:Connect(function()self.Action:FireServer("BoatDock")end)
    local function toggle()if self:IsOpen()then self:Close()else self:Open("map")end end
    self.MapButton.Activated:Connect(toggle)
    self.Input=UIS.InputBegan:Connect(function(input,processed)
        if processed or UIS:GetFocusedTextBox()then return end
        if input.KeyCode==Enum.KeyCode.M then toggle()
        elseif input.KeyCode==Enum.KeyCode.E and self:IsDriving() and not self:IsOpen()then self.Action:FireServer("BoatDock")end
    end)
    self.Blur=UIS.WindowFocusReleased:Connect(function()self.Focused=false end)
    self.Focus=UIS.WindowFocused:Connect(function()self.Focused=true end)
    self.Connection=RunService.RenderStepped:Connect(function()
        local camera=workspace.CurrentCamera
        if camera then self.Scale.Scale=math.min(1,(camera.ViewportSize.X-22)/760,(camera.ViewportSize.Y-50)/530)end
        local quiet=self.Callbacks.Quiet and self.Callbacks.Quiet()
        self.MapButton.Visible=not quiet
        local seat=self:Seat();self.Sail.Visible=seat~=nil and not self:IsOpen() and not quiet
        local character=self.Player.Character;local root=character and character:FindFirstChild("HumanoidRootPart")
        self.Nav.Visible=root~=nil and not quiet and not self:IsOpen() and not (self.Callbacks.Notice and self.Callbacks.Notice())
        if root then
            if self.PlayerDot and self.PlayerDot.Parent then
                self.PlayerDot.Position=UDim2.fromScale(math.clamp(0.5+root.Position.X/(self.Config.Ocean.MapSpan or 2800),0.02,0.98),math.clamp(0.5+root.Position.Z/(self.Config.Ocean.MapSpan or 2800),0.02,0.98))
            end
            local target=config.IslandById[self.Target]
            if target then
                local dx,dz=target.DockX-root.Position.X,target.DockZ-root.Position.Z
                local direction=(dz<0 and "NORTH" or "SOUTH")..(math.abs(dx)>60 and (dx<0 and "WEST" or "EAST") or "")
                self.Nav.Text="COURSE: "..target.Name.."\n"..math.floor(math.sqrt(dx*dx+dz*dz)).." studs · "..direction.." · M — choose island"
            end
        end
        if seat then
            local model=seat.Parent;self.Speed.Text=model.Name.." · "..tostring(model:GetAttribute("Speed") or 0).." studs/s"
            if os.clock()>=self.SentAt then
                self.SentAt=os.clock()+0.10
                local throttle,steer=0,0
                if self.Focused and not self:IsOpen() and not UIS:GetFocusedTextBox()then
                    throttle=(UIS:IsKeyDown(Enum.KeyCode.W) and 1 or 0)-(UIS:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
                    steer=(UIS:IsKeyDown(Enum.KeyCode.D) and 1 or 0)-(UIS:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
                    if throttle==0 then throttle=seat.ThrottleFloat end
                    if steer==0 then steer=seat.SteerFloat end
                end
                self.Action:FireServer("BoatInput","",{Throttle=throttle,Steer=steer})
            end
        end
    end)
    gui.Destroying:Connect(function()self.Input:Disconnect();self.Connection:Disconnect();self.Blur:Disconnect();self.Focus:Disconnect()end)
    return self
end
return Voyage
