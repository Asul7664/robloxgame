-- A presentation-only addition. This module never changes inventory or sends rewards.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Sprite = require(script.Parent:WaitForChild("SahurSprite"))
local Reveal = {}
Reveal.__index = Reveal
local GOLD = Color3.fromRGB(255, 207, 66)
local WHITE = Color3.fromRGB(255, 250, 232)
local function make(class, properties, parent)
    local object = Instance.new(class)
    for key, value in pairs(properties) do object[key] = value end
    object.Parent = parent; return object
end
local function label(parent, name, content, y, size, height, color, bold)
    return make("TextLabel", {Name = name, Text = content, Position = UDim2.fromOffset(12, y),
        Size = UDim2.new(1, -24, 0, height), BackgroundTransparency = 1,
        Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham, TextSize = size,
        TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true,
        ZIndex = 5}, parent)
end
function Reveal.new(gui, callbacks)
    local self = setmetatable({Visible = false, Closing = false, Token = 0, Tweens = {}, Callbacks = callbacks or {}}, Reveal)
    local host = make("Frame", {Name = "SahurCatchReveal", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(430, 398),
        BackgroundTransparency = 1, Visible = false, ZIndex = 40}, gui)
    self.Host = host
    self.FitScale = make("UIScale", {Scale = 1}, host)
    local card = make("CanvasGroup", {Name = "AnimatedCard", Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1, GroupTransparency = 0, ZIndex = 40}, host)
    self.Card = card; self.PopScale = make("UIScale", {Scale = 1}, card)
    self.Heading = label(card, "Rarity", "LEGENDARY CATCH", 10, 14, 24, GOLD, true)
    local glow = make("Frame", {Name = "TransparentGoldenHalo", BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(215, 159),
        Size = UDim2.fromOffset(226, 226), ZIndex = 1}, card)
    self.GlowScale = make("UIScale", {Scale = 1}, glow)
    local previousAlpha = 0
    for i = 1, 36 do
        local fraction = (37 - i) / 36
        local targetAlpha = 0.40 * (1 - fraction * fraction) ^ 1.3
        local layerAlpha = (targetAlpha - previousAlpha) / (1 - previousAlpha)
        previousAlpha = targetAlpha
        local disc = make("Frame", {Name = "HaloLayer", AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(fraction, fraction),
            BorderSizePixel = 0, BackgroundColor3 = GOLD, BackgroundTransparency = 1 - layerAlpha,
            ZIndex = 1}, glow)
        make("UICorner", {CornerRadius = UDim.new(0.5, 0)}, disc)
    end
    self.Sparks = {}
    for i = 1, 8 do
        local angle = (i - 1) * math.pi / 4 + 0.16
        local x, y = 215 + math.cos(angle) * 131, 159 + math.sin(angle) * 116
        local star = make("TextLabel", {Name = "GoldenSpark", Text = "✦", BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y),
            Size = UDim2.fromOffset(23, 23), TextSize = i % 2 == 0 and 12 or 18,
            Font = Enum.Font.GothamBold, TextColor3 = GOLD, ZIndex = 2}, card)
        self.Sparks[i] = {Object = star, X = x, Y = y}
    end
    self.Art = make("Frame", {Name = "SahurPortrait", BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(215, 159),
        Size = UDim2.fromOffset(258, 258), Rotation = -8, ZIndex = 3}, card)
    self.Loading = label(card, "Loading", "Loading portrait…", 146, 12, 26, WHITE, false)
    self.Sprite = Sprite.Mount(self.Art, gui:GetAttribute("SahurForcePortable") == true)
    self.Name = label(card, "CatchName", "Tung Tung Sahur", 287, 25, 36, WHITE, true)
    self.Info = label(card, "CatchInfo", "", 326, 13, 27, WHITE, false)
    self.Badge = label(card, "CatchBadge", "", 353, 12, 22, GOLD, true)
    label(card, "CloseHint", "LMB — close", 378, 10, 16, Color3.fromRGB(173, 191, 197), false)
    local dismiss = make("TextButton", {Name = "DismissPortrait", Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 6}, card)
    dismiss.Activated:Connect(function() if self:CanDismiss() then self:Hide(false) end end)
    self.Connection = RunService.RenderStepped:Connect(function()
        if not self.Visible then return end
        local camera = workspace.CurrentCamera
        if camera then
            local v = camera.ViewportSize
            self.FitScale.Scale = math.min(1, math.max(0.35, (v.X - 24) / 430), math.max(0.35, (v.Y - 36) / 398))
        end
        if self.Sprite.Ready and not self.ArtReadyAt then
            self.ArtReadyAt = os.clock()
            self.Until = self.ArtReadyAt + 4.2
        end
        self.Loading.Visible = not self.Sprite.Ready or self.Sprite.Mode == "error"
        if self.Sprite.Mode == "error" then self.Loading.Text = "Could not load this portrait." end
        local t = os.clock() - self.Started
        if not self.Closing then
            self.GlowScale.Scale = 1 + math.sin(t * 2.1) * 0.025
            if t > 0.6 then
                self.Art.Position = UDim2.fromOffset(215, 159 + math.sin((t - 0.6) * 2.6) * 3)
                self.Art.Rotation = math.sin((t - 0.6) * 1.6) * 1.5
            end
            for i, spark in ipairs(self.Sparks) do
                spark.Object.TextTransparency = 0.18 + (1 + math.sin(t * 2.6 + i)) * 0.22
                spark.Object.Rotation = math.sin(t * 1.8 + i) * 12
            end
            if os.clock() >= self.Until then self:Hide(false) end
        end
    end)
    host.Destroying:Connect(function()
        self.Visible = false; self.Sprite:Destroy()
        if self.Connection then self.Connection:Disconnect() end
        self:_cancelTweens()
    end)
    return self
end
function Reveal:_cancelTweens()
    for _, tween in ipairs(self.Tweens) do tween:Cancel() end
    self.Tweens = {}
end
function Reveal:_tween(object, seconds, style, direction, properties)
    local tween = TweenService:Create(object, TweenInfo.new(seconds, style, direction), properties)
    table.insert(self.Tweens, tween); tween:Play()
end
function Reveal:IsVisible() return self.Visible end
function Reveal:CanDismiss() return self.Visible and not self.Closing and os.clock() - self.Started > 0.65 end
function Reveal:Show(record, payload, displayName)
    self:_cancelTweens(); self.Token = self.Token + 1
    self.Visible = true; self.Closing = false; self.Host.Visible = true
    self.Started = os.clock(); self.Until = self.Started + 4.2
    self.ArtReadyAt = self.Sprite.Ready and self.Started or nil
    self.Card.GroupTransparency = 1; self.PopScale.Scale = 0.70
    self.Art.Position = UDim2.fromOffset(215, 176); self.Art.Rotation = -9
    self.Name.Text = displayName or "Tung Tung Sahur"
    self.Heading.Text = payload.Preview and "PREVIEW · LEGENDARY CATCH" or "LEGENDARY CATCH"
    self.Info.Text = string.format("%.2f kg  ·  %d coins  ·  +%d XP", record.Kg, record.Value, payload.XP or 0)
    self.Badge.Text = payload.Preview and "PREVIEW — NO REWARDS OR SAVES" or
        (payload.LevelUp and "LEVEL UP!" or (payload.New and "NEW DISCOVERY!" or "CATCH ADDED TO YOUR BAG"))
    if self.Callbacks.OnOpen then self.Callbacks.OnOpen() end
    self:_tween(self.Card, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {GroupTransparency = 0})
    self:_tween(self.PopScale, 0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out, {Scale = 1})
    self:_tween(self.Art, 0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out,
        {Position = UDim2.fromOffset(215, 159), Rotation = 0})
end
function Reveal:Hide(immediate)
    if not self.Visible then return end
    if self.Closing and not immediate then return end
    self:_cancelTweens(); self.Token = self.Token + 1
    local token = self.Token
    local function complete()
        if token ~= self.Token then return end
        self.Visible = false; self.Closing = false; self.Host.Visible = false
        if self.Callbacks.OnClose then self.Callbacks.OnClose() end
    end
    if immediate then complete(); return end
    self.Closing = true
    self:_tween(self.Card, 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In, {GroupTransparency = 1})
    self:_tween(self.PopScale, 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In, {Scale = 0.88})
    task.delay(0.22, complete)
end
return Reveal
