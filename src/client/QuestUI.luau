-- Quest progress and rewards are supplied by the server; this UI only claims IDs.
local QuestUI = {}
QuestUI.__index = QuestUI

local C = {Bg = Color3.fromRGB(14, 32, 43), Panel = Color3.fromRGB(23, 47, 60),
    Ink = Color3.fromRGB(237, 242, 230), Muted = Color3.fromRGB(169, 194, 198),
    Aqua = Color3.fromRGB(95, 211, 200), Gold = Color3.fromRGB(250, 199, 111)}
local function make(class, props, parent)
    local obj = Instance.new(class)
    for key, value in pairs(props) do obj[key] = value end
    obj.Parent = parent
    return obj
end
local function corner(obj, radius)
    make("UICorner", {CornerRadius = UDim.new(0, radius or 10)}, obj)
end
local function label(parent, content, size, position, fontSize, color)
    return make("TextLabel", {Text = content, Size = size, Position = position,
        BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = fontSize or 14,
        TextColor3 = color or C.Ink, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center, TextWrapped = true}, parent)
end
local function button(parent, content, size, position, color)
    local obj = make("TextButton", {Text = content, Size = size, Position = position,
        BackgroundColor3 = color or C.Aqua, TextColor3 = C.Bg, BorderSizePixel = 0,
        Font = Enum.Font.GothamBold, TextSize = 12, TextWrapped = true,
        AutoButtonColor = true}, parent)
    corner(obj)
    return obj
end
local function countdown(seconds)
    if seconds <= 0 then return "Обновление заданий…" end
    local minutes = math.ceil(seconds / 60)
    local days = math.floor(minutes / 1440)
    local hours = math.floor(minutes / 60) % 24
    local rest = minutes % 60
    if days > 0 then return string.format("Обновление через %d д. %d ч. %d мин.", days, hours, rest) end
    if hours > 0 then return string.format("Обновление через %d ч. %d мин.", hours, rest) end
    return string.format("Обновление через %d мин.", rest)
end
local function resetText(periodKind, seconds)
    return countdown(seconds) .. (periodKind == "Daily" and "\nСброс каждый день в 00:00 UTC" or
        "\nСброс по понедельникам в 00:00 UTC")
end
local function amount(value, quest)
    if quest.Unit == "seconds" or quest.Kind == "activity" then
        return string.format("%d:%02d", math.floor(value / 60), math.floor(value) % 60)
    end
    return tostring(math.floor(value))
end

function QuestUI:IsOpen()
    return self.Host.Visible
end
function QuestUI:Close()
    local wasOpen = self.Host.Visible
    self.Host.Visible = false
    if wasOpen and self.Callbacks.OnClose then self.Callbacks.OnClose() end
end
function QuestUI:Toggle()
    if self:IsOpen() then self:Close(); return end
    if self.Callbacks.CanOpen and not self.Callbacks.CanOpen() then return end
    if self.Callbacks.OnOpen then self.Callbacks.OnOpen() end
    self.Host.Visible = true
    self:_render()
end
function QuestUI:_claim(periodKind, quest)
    local period = self.Data and self.Data[periodKind]
    local key = periodKind .. ":" .. tostring(quest.Id)
    if not period or quest.Claimed or self.Pending[key] or
        (quest.Progress or 0) < (quest.Target or 1) or self:_serverNow() >= period.ResetAt then return end
    self.Pending[key] = os.clock()
    self:_render()
    self.Claim(periodKind, quest.Id)
end
function QuestUI:_serverNow()
    return self.ServerAt + (os.clock() - self.ReceivedAt)
end
function QuestUI:_badge()
    local ready = 0
    if self.Data then
        for _, periodKind in ipairs({"Daily", "Weekly"}) do
            local period = self.Data[periodKind]
            if period and self:_serverNow() < period.ResetAt then
                for _, quest in ipairs(period.Tasks or {}) do
                    if not quest.Claimed and (quest.Progress or 0) >= (quest.Target or 1) then ready += 1 end
                end
            end
        end
    end
    self.Button.Text = ready > 0 and ("ЗАДАНИЯ · " .. ready) or "ЗАДАНИЯ"
    self.Button.BackgroundColor3 = ready > 0 and C.Gold or C.Panel
    self.Button.TextColor3 = ready > 0 and C.Bg or C.Aqua
end
function QuestUI:_render()
    local scrollPosition = self.List.CanvasPosition
    for _, child in ipairs(self.List:GetChildren()) do
        if not child:IsA("UIListLayout") then child:Destroy() end
    end
    for name, tab in pairs(self.Tabs) do
        tab.BackgroundColor3 = name == self.Period and C.Aqua or C.Panel
        tab.TextColor3 = name == self.Period and C.Bg or C.Muted
    end
    local period = self.Data and self.Data[self.Period]
    if not period then
        label(self.List, "Загружаем задания…", UDim2.new(1, -8, 0, 66), UDim2.new(), 15, C.Muted)
        self.Countdown.Text = "Прогресс сохраняется между входами в игру"
        return
    end
    self.Countdown.Text = resetText(self.Period, period.ResetAt - self:_serverNow())
    if #(period.Tasks or {}) == 0 then
        label(self.List, "Задания появятся после загрузки профиля.", UDim2.new(1, -8, 0, 66), UDim2.new(), 14, C.Muted)
    end
    for index, quest in ipairs(period.Tasks or {}) do
        local row = make("Frame", {Name = "Quest_" .. tostring(quest.Id), LayoutOrder = index,
            Size = UDim2.new(1, -8, 0, 136), BackgroundColor3 = C.Panel, BorderSizePixel = 0}, self.List)
        corner(row)
        local title = label(row, quest.Title or "Рыболовное задание", UDim2.new(1, -24, 0, 48),
            UDim2.fromOffset(12, 5), 15)
        title.Font = Enum.Font.GothamBold
        local target = math.max(1, quest.Target or 1)
        local progress = math.clamp(quest.Progress or 0, 0, target)
        label(row, amount(progress, quest) .. " / " .. amount(target, quest), UDim2.new(0.42, 0, 0, 24),
            UDim2.fromOffset(12, 59), 14, quest.Claimed and C.Muted or C.Aqua)
        local reward = label(row, string.format("+%d монет", quest.Reward or 0), UDim2.new(0.58, -24, 0, 24),
            UDim2.new(0.42, 0, 0, 59), 14, C.Gold)
        reward.TextXAlignment = Enum.TextXAlignment.Right
        local track = make("Frame", {Size = UDim2.new(1, -136, 0, 10), Position = UDim2.fromOffset(12, 104),
            BackgroundColor3 = C.Bg, BorderSizePixel = 0, ClipsDescendants = true}, row)
        corner(track, 5)
        local fill = make("Frame", {Size = UDim2.fromScale(progress / target, 1),
            BackgroundColor3 = quest.Claimed and C.Muted or C.Aqua, BorderSizePixel = 0}, track)
        corner(fill, 5)
        local pending = self.Pending[self.Period .. ":" .. tostring(quest.Id)] ~= nil
        local expired = self:_serverNow() >= period.ResetAt
        local enabled = progress >= target and not quest.Claimed and not pending and not expired
        local caption = quest.Claimed and "ПОЛУЧЕНО" or (pending and "ЖДЁМ…" or
            (expired and "ОБНОВЛЕНИЕ" or (enabled and "ЗАБРАТЬ" or "В ПРОЦЕССЕ")))
        local claim = button(row, caption, UDim2.fromOffset(100, 38), UDim2.new(1, -112, 0, 91),
            enabled and C.Gold or C.Bg)
        claim.Name = "Claim"
        claim.Active = enabled
        claim.AutoButtonColor = enabled
        if not enabled then claim.TextColor3 = C.Muted end
        local periodKind = self.Period
        claim.Activated:Connect(function() if enabled then self:_claim(periodKind, quest) end end)
    end
    self.List.CanvasPosition = scrollPosition
end
function QuestUI:Update(payload)
    if type(payload) ~= "table" then return end
    self.Data = payload
    self.ServerAt = payload.ServerNow or workspace:GetServerTimeNow()
    self.ReceivedAt = os.clock()
    self.Pending = {}
    self:_badge()
    if self:IsOpen() then self:_render() end
end
function QuestUI:Step()
    local now = os.clock()
    if now < self.NextTick then return end
    self.NextTick = now + 1
    local dirty = false
    for key, started in pairs(self.Pending) do
        if now - started > 8 then self.Pending[key] = nil; dirty = true end
    end
    self:_badge()
    if not self:IsOpen() then return end
    local period = self.Data and self.Data[self.Period]
    if period then
        self.Countdown.Text = resetText(self.Period, period.ResetAt - self:_serverNow())
        local expired = self:_serverNow() >= period.ResetAt
        if expired ~= self.Expired then self.Expired = expired; dirty = true end
    end
    if dirty then self:_render() end
end
function QuestUI:Destroy()
    self:Close()
    self.Button:Destroy()
    self.Host:Destroy()
end
function QuestUI.new(gui, config, claimCallback, callbacks)
    local self = setmetatable({Config = config, Claim = claimCallback, Callbacks = callbacks or {},
        Period = "Daily", Pending = {}, NextTick = 0, ServerAt = 0, ReceivedAt = os.clock()}, QuestUI)
    local header = gui:FindFirstChild("Header")
    self.Button = button(header or gui, "ЗАДАНИЯ", UDim2.fromOffset(106, 26),
        header and UDim2.new(1, -232, 0, 52) or UDim2.new(1, -126, 0, 64), C.Panel)
    self.Button.Name = "QuestButton"
    self.Button.TextColor3 = C.Aqua
    self.Button.ZIndex = 13
    self.Host = make("Frame", {Name = "QuestWindow", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.94, 0.84),
        BackgroundColor3 = C.Bg, BorderSizePixel = 0, Visible = false, ZIndex = 26}, gui)
    corner(self.Host, 14)
    make("UISizeConstraint", {MaxSize = Vector2.new(560, 620)}, self.Host)
    local title = label(self.Host, "ЗАДАНИЯ", UDim2.new(1, -76, 0, 34), UDim2.fromOffset(16, 8), 21)
    title.Font = Enum.Font.GothamBold
    button(self.Host, "×", UDim2.fromOffset(36, 32), UDim2.new(1, -48, 0, 11), C.Gold).Activated:Connect(function() self:Close() end)
    self.Tabs = {}
    for index, entry in ipairs({{"Daily", "ЕЖЕДНЕВНЫЕ"}, {"Weekly", "ЕЖЕНЕДЕЛЬНЫЕ"}}) do
        local name = entry[1]
        local tab = button(self.Host, entry[2], UDim2.new(0.5, -21, 0, 34),
            UDim2.new((index - 1) * 0.5, index == 1 and 16 or 5, 0, 51), C.Panel)
        self.Tabs[name] = tab
        tab.Activated:Connect(function()
            self.Period = name
            self.Expired = nil
            self.List.CanvasPosition = Vector2.zero
            self:_render()
        end)
    end
    self.Countdown = label(self.Host, "Прогресс сохраняется между входами в игру", UDim2.new(1, -32, 0, 32),
        UDim2.fromOffset(16, 91), 12, C.Muted)
    self.List = make("ScrollingFrame", {Name = "QuestList", Size = UDim2.new(1, -32, 1, -164),
        Position = UDim2.fromOffset(16, 126), BackgroundTransparency = 1, BorderSizePixel = 0,
        CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4, ScrollBarImageColor3 = C.Aqua, ScrollingDirection = Enum.ScrollingDirection.Y}, self.Host)
    make("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, self.List)
    label(self.Host, "Поймай улов, затем забери награду. Продажа рыбы не сбрасывает прогресс.",
        UDim2.new(1, -32, 0, 30), UDim2.new(0, 16, 1, -34), 11, C.Muted)
    self.Button.Activated:Connect(function() self:Toggle() end)
    return self
end
return QuestUI
