-- Cross-device interface. The client only sends button states, never rewards.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local shared = RS:WaitForChild("QuietCove")
local Config = require(shared:WaitForChild("Config"))
local CatchReveal = require(script.Parent:WaitForChild("CatchReveal"))
local WaterJump = require(script.Parent:WaitForChild("WaterJump"))
local VoyageUI = require(script.Parent:WaitForChild("VoyageUI"))
local ModelPreview = require(script.Parent:WaitForChild("ModelPreview"))
local CatchThumbnails = require(script.Parent:WaitForChild("CatchThumbnails"))
local CastEffects = require(script.Parent:WaitForChild("CastEffects"))
local castEffects = CastEffects.new(Config)
local LandingEffects = require(script.Parent:WaitForChild("LandingEffects"))
local landingEffects = LandingEffects.new(Config, castEffects)
local pendingCaught = nil
local landingEndsAt = 0
local function landingPlaying()
    -- The server's presentation clock remains a barrier even if a model could
    -- not be mounted. An active local visual must also finish before the card.
    return workspace:GetServerTimeNow() < landingEndsAt or landingEffects:OwnerPlaying()
end
local voyage
local Action, Update = shared:WaitForChild("Action"), shared:WaitForChild("Update")
local C = {Bg = Color3.fromRGB(14, 32, 43), Panel = Color3.fromRGB(23, 47, 60),
    Ink = Color3.fromRGB(237, 242, 230), Muted = Color3.fromRGB(169, 194, 198),
    Aqua = Color3.fromRGB(95, 211, 200), Gold = Color3.fromRGB(250, 199, 111),
    Red = Color3.fromRGB(233, 127, 116)}
local function create(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props) do obj[k] = v end
    obj.Parent = parent; return obj
end
local function rounded(obj, radius)
    create("UICorner", {CornerRadius = UDim.new(0, radius or 12)}, obj)
end
local function text(parent, content, size, position, fontSize, color)
    return create("TextLabel", {Text = content, Size = size, Position = position,
        BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = fontSize or 16,
        TextColor3 = color or C.Ink, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center, TextWrapped = true}, parent)
end
local function button(parent, content, size, position, bg)
    local b = create("TextButton", {Text = content, Size = size, Position = position,
        BackgroundColor3 = bg or C.Aqua, TextColor3 = C.Bg, BorderSizePixel = 0,
        Font = Enum.Font.GothamBold, TextSize = 15, TextWrapped = true, AutoButtonColor = true}, parent)
    rounded(b, 10); return b
end
local gui = create("ScreenGui", {Name = "QuietCoveUI", ResetOnSpawn = false, IgnoreGuiInset = false,
    DisplayOrder = 10, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, player:WaitForChild("PlayerGui"))
local header = create("Frame", {Name = "Header", Size = UDim2.new(1, -24, 0, 84), Position = UDim2.fromOffset(12, 10),
    BackgroundColor3 = C.Bg, BackgroundTransparency = 0.08, BorderSizePixel = 0}, gui)
rounded(header)
local heading = text(header, Config.Title, UDim2.new(1, -115, 0, 28), UDim2.fromOffset(14, 5), 22)
heading.Font = Enum.Font.GothamBold
heading.Size = UDim2.new(1,-245,0,28);heading.TextSize=20;heading.TextWrapped=false
heading.TextTruncate=Enum.TextTruncate.AtEnd
local statsLabel = text(header, "Загрузка профиля…", UDim2.new(1, -118, 0, 43), UDim2.fromOffset(14, 35), 12, C.Muted)
local bagButton = button(header, "УЛОВ / КОЛЛЕКЦИЯ", UDim2.fromOffset(116, 40), UDim2.new(1, -126, 0, 10), C.Gold)
bagButton.TextSize = 12
local timeLabel = text(header, "", UDim2.fromOffset(112, 24), UDim2.new(1, -120, 0, 53), 11, C.Muted)
timeLabel.TextXAlignment = Enum.TextXAlignment.Center
local toast = create("Frame", {Name = "Notice", AnchorPoint = Vector2.new(0.5, 0),
    Size = UDim2.new(0.90, 0, 0, 76), Position = UDim2.new(0.5, 0, 0, 106),
    BackgroundColor3 = C.Panel, BorderSizePixel = 0, Visible = false}, gui)
rounded(toast)
create("UISizeConstraint", {MaxSize = Vector2.new(680, 90)}, toast)
local toastText = text(toast, "", UDim2.new(1, -28, 1, -14), UDim2.fromOffset(14, 7), 14)
local toastUntil = 0
local function notify(message, color, duration)
    toastText.Text = message; toastText.TextColor3 = color or C.Ink
    toast.Visible = true; toastUntil = os.clock() + (duration or 4.5)
end
local function blend(a, b, alpha)
    return Color3.new(a.R + (b.R - a.R) * alpha, a.G + (b.G - a.G) * alpha, a.B + (b.B - a.B) * alpha)
end
local reveal = create("Frame", {Name = "CatchReveal", AnchorPoint = Vector2.new(0.5, 0.5),
    Size = UDim2.new(0, 430, 0, 300), Position = UDim2.fromScale(0.5, 0.42),
    BackgroundTransparency = 1, Visible = false, ZIndex = 31}, gui)
create("UISizeConstraint", {MaxSize = Vector2.new(430, 300)}, reveal)
local revealScale = create("UIScale", {Scale = 0.84}, reveal)
local revealCircleOuter = create("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(188, 188), Position = UDim2.fromScale(0.5, 0.42), BackgroundColor3 = C.Gold, BackgroundTransparency = 0.16, BorderSizePixel = 0, ZIndex = 31}, reveal)
rounded(revealCircleOuter, 999)
local revealCircleMid = create("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(142, 142), Position = UDim2.fromScale(0.5, 0.42), BackgroundColor3 = C.Gold, BackgroundTransparency = 0.28, BorderSizePixel = 0, ZIndex = 32}, reveal)
rounded(revealCircleMid, 999)
local revealCircleInner = create("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(96, 96), Position = UDim2.fromScale(0.5, 0.42), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.36, BorderSizePixel = 0, ZIndex = 33}, reveal)
rounded(revealCircleInner, 999)
local revealSparkleLeft = text(reveal, "✦", UDim2.fromOffset(40, 40), UDim2.new(0.5, -118, 0.5, -102), 28, C.Ink)
revealSparkleLeft.ZIndex = 34; revealSparkleLeft.TextXAlignment = Enum.TextXAlignment.Center
local revealSparkleRight = text(reveal, "✦", UDim2.fromOffset(40, 40), UDim2.new(0.5, 80, 0.5, -80), 22, C.Ink)
revealSparkleRight.ZIndex = 34; revealSparkleRight.TextXAlignment = Enum.TextXAlignment.Center
local revealTitle = text(reveal, "ПОЙМАНО", UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 162), 15, C.Muted)
revealTitle.TextXAlignment = Enum.TextXAlignment.Center; revealTitle.ZIndex = 34; revealTitle.Font = Enum.Font.GothamBold
local revealName = text(reveal, "", UDim2.new(1, -28, 0, 62), UDim2.fromOffset(14, 184), 28, C.Ink)
revealName.TextXAlignment = Enum.TextXAlignment.Center; revealName.ZIndex = 34; revealName.Font = Enum.Font.GothamBold
local revealNick = text(reveal, "", UDim2.new(1, -28, 0, 28), UDim2.fromOffset(14, 236), 13, C.Muted)
revealNick.TextXAlignment = Enum.TextXAlignment.Center; revealNick.ZIndex = 34
local revealMeta = text(reveal, "", UDim2.new(1, -28, 0, 22), UDim2.fromOffset(14, 258), 12, C.Ink)
revealMeta.TextXAlignment = Enum.TextXAlignment.Center; revealMeta.ZIndex = 34
local revealBadge = text(reveal, "", UDim2.new(1, -28, 0, 22), UDim2.fromOffset(14, 144), 12, C.Ink)
revealBadge.TextXAlignment = Enum.TextXAlignment.Center; revealBadge.ZIndex = 34
local revealUntil, revealToken = 0, 0
local fishColor, fishName
local catchReveal -- initialized after the original HUD widgets exist
local function hideReveal(immediate)
    revealToken = revealToken + 1
    if immediate then reveal.Visible = false; revealScale.Scale = 0.84; return end
    local token = revealToken
    local tween = TweenService:Create(revealScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.76})
    tween:Play()
    task.delay(0.22, function()
        if revealToken == token then reveal.Visible = false end
    end)
end
local function showCatchReveal(record, payload)
    if catchReveal and catchReveal:HasPortrait(record.Species) then
        hideReveal(true)
        catchReveal:Show(record, payload, fishName(record))
        return true
    end
    if catchReveal then catchReveal:Hide(true) end
    local fish = Config.ById[record.Species]
    if not fish then return end
    local rarity = Config.Rarities[fish.Rarity]
    local base = fishColor(fish)
    revealCircleOuter.BackgroundColor3 = base
    revealCircleMid.BackgroundColor3 = blend(base, Color3.fromRGB(255, 255, 255), 0.26)
    revealCircleInner.BackgroundColor3 = blend(base, Color3.fromRGB(255, 255, 255), 0.72)
    revealSparkleLeft.TextColor3 = base
    revealSparkleRight.TextColor3 = blend(base, Color3.fromRGB(255, 255, 255), 0.18)
    revealTitle.Text = payload.New and "НОВАЯ ДОБЫЧА" or "ПОЙМАНО"
    revealName.Text = fishName(record)
    revealNick.Text = fish.Nick or rarity.Name
    revealMeta.Text = string.format("%s · %.2f кг · %d монет · +%d опыта", rarity.Name, record.Kg, record.Value, payload.XP)
    revealBadge.Text = payload.LevelUp and "УРОВЕНЬ ПОВЫШЕН!" or (payload.New and "ДОБАВЛЕНО В КОЛЛЕКЦИЮ" or "УДАЧНЫЙ УЛОВ")
    revealBadge.TextColor3 = base
    revealScale.Scale = 0.76
    reveal.Visible = true
    revealUntil = os.clock() + 3.2
    revealToken = revealToken + 1
    TweenService:Create(revealScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
end
local panel = create("Frame", {Name = "FishingPanel", AnchorPoint = Vector2.new(0.5, 1),
    Size = UDim2.new(0.93, 0, 0, 222), Position = UDim2.new(0.5, 0, 1, -16),
    BackgroundColor3 = C.Bg, BackgroundTransparency = 0.04, BorderSizePixel = 0}, gui)
rounded(panel, 16)
create("UISizeConstraint", {MaxSize = Vector2.new(680, 222)}, panel)
local panelScale = create("UIScale", {Scale = 1}, panel)
local title = text(panel, "ПЕРВЫЙ ЗАБРОС", UDim2.new(1, -28, 0, 27), UDim2.fromOffset(14, 9), 18)
title.Font = Enum.Font.GothamBold
local help = text(panel, "Подойди к концу пирса. Зажми и отпусти ЛКМ.", UDim2.new(1, -28, 0, 37), UDim2.fromOffset(14, 39), 12, C.Muted)
local track = create("Frame", {Name = "ReelTrack", Size = UDim2.new(1, -28, 0, 31),
    Position = UDim2.fromOffset(14, 82), BackgroundColor3 = C.Panel, BorderSizePixel = 0, ClipsDescendants = true}, panel)
rounded(track, 6)
local charge = create("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Gold, BorderSizePixel = 0, Visible = false}, track)
rounded(charge, 6)
local bar = create("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0),
    Size = UDim2.fromScale(0.30, 1), BackgroundColor3 = C.Aqua, BackgroundTransparency = 0.12,
    BorderSizePixel = 0, Visible = false}, track)
rounded(bar, 5)
local fishMarker = create("Frame", {AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 6, 1, 0),
    Position = UDim2.fromScale(0.5, 0), BackgroundColor3 = C.Gold, BorderSizePixel = 0, Visible = false, ZIndex = 3}, track)
local trackText = text(track, "Хорошая снасть — начало большой истории", UDim2.fromScale(1, 1), UDim2.new(), 12, C.Muted)
trackText.TextXAlignment = Enum.TextXAlignment.Center; trackText.ZIndex = 4
local progressBg = create("Frame", {Size = UDim2.new(1, -28, 0, 8), Position = UDim2.fromOffset(14, 122),
    BackgroundColor3 = C.Panel, BorderSizePixel = 0}, panel)
rounded(progressBg, 4)
local progress = create("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Aqua, BorderSizePixel = 0}, progressBg)
rounded(progress, 4)
local actionButton = button(panel, "ЗАЖМИ ДЛЯ ЗАБРОСА", UDim2.new(0.74, -16, 0, 53), UDim2.fromOffset(14, 143))
local cancelButton = button(panel, "ОТМЕНА", UDim2.new(0.26, -12, 0, 53), UDim2.new(0.74, 3, 0, 143), C.Panel)
cancelButton.TextColor3 = C.Muted; cancelButton.TextSize = 11
local footer = text(panel, "ЛКМ — рыбалка · ПРОБЕЛ — прыжок · Q — отмена · E — торговцы", UDim2.new(1, -20, 0, 17), UDim2.fromOffset(10, 199), 10, C.Muted)
footer.TextXAlignment = Enum.TextXAlignment.Center
local modal = create("Frame", {Name = "InventoryAndShop", AnchorPoint = Vector2.new(0.5, 0.5),
    Size = UDim2.new(0.94, 0, 0.65, 0), Position = UDim2.fromScale(0.5, 0.46),
    BackgroundColor3 = C.Bg, BorderSizePixel = 0, Visible = false, ZIndex = 20}, gui)
rounded(modal, 16)
create("UISizeConstraint", {MaxSize = Vector2.new(660, 510)}, modal)
local modalTitle = text(modal, "УЛОВ", UDim2.new(1, -80, 0, 42), UDim2.fromOffset(14, 5), 20)
modalTitle.Font = Enum.Font.GothamBold
local closeButton = button(modal, "×", UDim2.fromOffset(40, 34), UDim2.new(1, -50, 0, 10), C.Panel)
closeButton.TextColor3 = C.Ink; closeButton.TextSize = 25
local bagTab = button(modal, "УЛОВ", UDim2.new(0.5, -17, 0, 30), UDim2.fromOffset(12, 51), C.Aqua)
local bookTab = button(modal, "КОЛЛЕКЦИЯ", UDim2.new(0.5, -17, 0, 30), UDim2.new(0.5, 5, 0, 51), C.Panel)
bookTab.TextColor3 = C.Ink
local scroll = create("ScrollingFrame", {Size = UDim2.new(1, -24, 1, -101), Position = UDim2.fromOffset(12, 91),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
    CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y}, modal)
create("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)
local data = nil
local stageName, sessionId, chargeStarted, hookDeadline, hookWindow = "Idle", nil, 0, 0, Config.HookWindow
local activeInput, holding, pendingRelease = nil, false, false
local requestAt, resendAt = 0, 0
local shownMode, memoryOnly = "bag", true
local latest = {Bar = 0.5, Fish = 0.5, Width = 0.30, Progress = 0.34, Inside = true}
local displayBar, displayFish = 0.5, 0.5
fishColor = function(fish)
    local rgb = Config.Rarities[fish.Rarity].Color; return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end
fishName = function(record)
    local fish = Config.ById[record.Species]
    local prefix = record.Mutation == "gold" and "Золотая · " or (record.Mutation == "glow" and "Сияющая · " or "")
    return prefix .. fish.Name
end
catchReveal = CatchReveal.new(gui, Config, {
    OnOpen = function()
        if voyage then voyage:Close() end
        panel.Visible = false; header.Visible = false; toast.Visible = false
    end,
    OnClose = function()
        header.Visible = true; panel.Visible = not modal.Visible
    end,
})
local thumbnails = CatchThumbnails.new(scroll, Config, function() return modal.Visible end)
local function renderModal()
    thumbnails:Clear()
    for _, child in ipairs(scroll:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
    if not data then return end
    bagTab.Visible = shownMode ~= "shop"; bookTab.Visible = shownMode ~= "shop"
    scroll.Position = UDim2.fromOffset(12, shownMode == "shop" and 55 or 91)
    scroll.Size = UDim2.new(1, -24, 1, shownMode == "shop" and -65 or -101)
    local function row(content, color, height)
        local r = create("Frame", {Size = UDim2.new(1, -8, 0, height or 62), BackgroundColor3 = C.Panel, BorderSizePixel = 0}, scroll)
        rounded(r, 8)
        text(r, content, UDim2.new(1, -24, 1, -10), UDim2.fromOffset(12, 5), 13, color)
        return r
    end
    local function fishRow(fish, record, known)
        local color = fishColor(fish)
        local height = record and 96 or 108
        local r = create("Frame", {Name="FishRow_"..fish.Id, Size=UDim2.new(1,-8,0,height),
            BackgroundColor3=C.Panel, BorderSizePixel=0}, scroll)
        rounded(r,10)
        thumbnails:Add(r,fish,known)
        local nameLabel=text(r, known and (record and fishName(record) or fish.Name) or "??? · ещё не поймано",
            UDim2.new(1,-112,0,24),UDim2.fromOffset(100,10),15,known and C.Ink or C.Muted)
        nameLabel.Name="FishName";nameLabel.Font=Enum.Font.GothamBold
        nameLabel.TextWrapped=false;nameLabel.TextTruncate=Enum.TextTruncate.AtEnd
        text(r, Config.Rarities[fish.Rarity].Name .. (fish.Night and " · только ночью" or ""),
            UDim2.new(1,-112,0,20),UDim2.fromOffset(100,34),12,color)
        if record then
            text(r,string.format("%.2f кг   ·   %d монет",record.Kg,record.Value),
                UDim2.new(1,-112,0,23),UDim2.fromOffset(100,60),13,C.Ink)
        else
            text(r,Config.HabitatText(fish),UDim2.new(1,-112,0,42),UDim2.fromOffset(100,56),12,C.Muted)
        end
        return r
    end
    if shownMode == "bag" then
        local sum = 0; for _, record in ipairs(data.Bag) do sum = sum + record.Value end
        modalTitle.Text = string.format("УЛОВ %d/%d · %d монет", #data.Bag, Config.BagCapacity, sum)
        if #data.Bag == 0 then row("Рюкзак пуст. Поймай первый мем-улов у конца пирса!", C.Muted, 80) end
        for i = #data.Bag, 1, -1 do
            local record = data.Bag[i]; local fish = Config.ById[record.Species]
            if fish then
                fishRow(fish,record,true)
            else
                -- Historical bag values remain sellable; a retired species
                -- no longer has an active definition or a fish thumbnail.
                row(string.format("Улов из прошлой версии\n%.2f кг · %d монет",record.Kg,record.Value),C.Muted,80)
            end
        end
        row("Продажа: подойди к Маре у начала пирса и нажми E. Продаётся весь улов; записи в коллекции остаются.", C.Muted, 78)
    elseif shownMode == "book" then
        local count = 0
        for id,known in pairs(data.Bestiary) do
            if known==true and Config.ById[id] then count=count+1 end
        end
        modalTitle.Text = string.format("КОЛЛЕКЦИЯ МЕМРЫБ · %d/%d", count, #Config.Fish)
        for _, fish in ipairs(Config.Fish) do
            local known = data.Bestiary[fish.Id]
            fishRow(fish,nil,known==true)
        end
    else
        modalTitle.Text = "МАСТЕР УДОЧЕК · " .. (data.TestMode and "∞ монет · ТЕСТЕР" or data.Coins .. " монет")
        for index, rod in ipairs(Config.Rods) do
            local r = create("Frame", {Size = UDim2.new(1, -8, 0, 105), BackgroundColor3 = C.Panel, BorderSizePixel = 0}, scroll)
            rounded(r, 8)
            ModelPreview.Create(r,"rod",rod,UDim2.fromOffset(83,96),UDim2.fromOffset(0,3))
            text(r, rod.Name .. "\nКонтроль: " .. math.floor(rod.Width * 100) .. "% · удача ×" .. rod.Luck .. "\nМакс. вес: " .. rod.MaxKg .. " кг\n" .. Config.RodLooks[rod.Id], UDim2.new(1, -209, 1, -12), UDim2.fromOffset(90, 6), 12)
            local owned = index <= data.Rod
            local caption = index == data.Rod and "В РУКАХ" or (owned and "КУПЛЕНО" or (index == data.Rod + 1 and rod.Price .. "\nКУПИТЬ" or "СНАЧАЛА\nПРЕДЫДУЩУЮ"))
            local b = button(r, caption, UDim2.fromOffset(92, 62), UDim2.new(1, -102, 0.5, -31), owned and C.Panel or C.Gold)
            b.TextSize = 12; if owned then b.TextColor3 = C.Muted end
            if data.TestMode and index ~= data.Rod then
                b.Text="ТЕСТЕР\nВЗЯТЬ";b.BackgroundColor3=C.Gold;b.TextColor3=C.Bg
            end
            if (data.TestMode and index ~= data.Rod) or index == data.Rod + 1 then
                b.Activated:Connect(function() Action:FireServer("Buy", "", index) end)
            end
        end
        row("Каждая следующая удочка быстрее привлекает улов и облегчает вываживание. Монеты зарабатываются продажей улова.", C.Muted, 85)
    end
end
local function updateStats()
    if not data then return end
    statsLabel.Text = string.format("%d монет · Уровень %d · Улов %d/%d\n%s · %s", data.Coins, Config.Level(data.XP), #data.Bag, Config.BagCapacity,
        Config.Rods[data.Rod].Name, memoryOnly and "ТЕСТ: без сохранений" or "Сохранения включены")
    if data.TestMode then
        statsLabel.Text="∞ монет · ∞ опыта · ВСЕ УРОВНИ\n"..Config.Rods[data.Rod].Name.." · ТЕСТЕР ASUL7664"
    end
    if modal.Visible then renderModal() end
end
local function updateStage()
    charge.Visible = stageName == "Charging" or stageName == "Bite"
    bar.Visible = stageName == "Reeling"; fishMarker.Visible = stageName == "Reeling"
    trackText.Visible = stageName ~= "Reeling"
    cancelButton.Visible = stageName ~= "Idle" and stageName ~= "Request" and stageName ~= "Landing"
    progress.Size = UDim2.fromScale(stageName == "Reeling" and latest.Progress or 0, 1)
    actionButton.BackgroundColor3 = stageName == "Bite" and C.Gold or C.Aqua
    if stageName == "Idle" then
        title.Text = "ВРЕМЯ РЫБАЛКИ"
        help.Text = "Встань в конце пирса. Зажми и отпусти ЛКМ. ПРОБЕЛ — прыжок."
        actionButton.Text = "ЗАЖМИ ДЛЯ ЗАБРОСА"; trackText.Text = "Чем полнее шкала, тем сильнее заброс"
    elseif stageName == "Request" then
        title.Text = "ГОТОВЛЮ ЗАБРОС…"; actionButton.Text = "ДЕРЖИ КНОПКУ"; trackText.Text = "Проверяем место для рыбалки"
    elseif stageName == "Charging" then
        title.Text = "ЗАМАХ"; help.Text = "Дождись заполнения шкалы и отпусти кнопку."
        actionButton.Text = "ОТПУСТИ ДЛЯ ЗАБРОСА"; charge.BackgroundColor3 = C.Gold
    elseif stageName == "Casting" then
        title.Text="ЗАБРОС!";help.Text="Поплавок летит к воде. Поклёвка начнётся после всплеска."
        actionButton.Text="ЛЕСКА В ПОЛЁТЕ…";trackText.Text="Замах → полёт → всплеск"
    elseif stageName == "Landing" then
        title.Text="УЛОВ НА КРЮЧКЕ!";help.Text="Вытаскиваем существо из воды…"
        actionButton.Text="ВЫТАСКИВАЕМ…";trackText.Text=""
    elseif stageName == "Waiting" then
        title.Text = "ЖДЁМ ПОКЛЁВКУ"; help.Text = "Нажимай кнопку, чтобы подманить рыбу. Или просто подожди."
        actionButton.Text = "ПОДМАНИТЬ РЫБУ"; trackText.Text = "Поплавок на воде…"
    elseif stageName == "Bite" then
        title.Text = "КЛЮЁТ!"; help.Text = "Нажми ЛКМ, пока не закончилась шкала подсечки!"
        actionButton.Text = "ПОДСЕЧЬ!"; charge.BackgroundColor3 = C.Red
    elseif stageName == "Reeling" then
        title.Text = "ВЫВАЖИВАНИЕ"; help.Text = "Удерживай метку в голубой полоске. ЛКМ →, отпустить ←. Время не ограничено."
        actionButton.Text = "ДЕРЖИ: →   ОТПУСТИ: ←"
    end
end
local function openModal(mode)
    if stageName ~= "Idle" then notify("Сначала закончи или отмени рыбалку."); return end
    catchReveal:Hide(true)
    if voyage then voyage:Close() end
    shownMode = mode; modal.Visible = true; panel.Visible = false; renderModal()
end
local function closeModal() modal.Visible = false; panel.Visible = true end
voyage = VoyageUI.new(gui,Config,Action,{
    CanOpen=function()return stageName=="Idle" and not catchReveal:IsVisible()end,
    OnOpen=function()modal.Visible=false;panel.Visible=false end,
    OnClose=function()panel.Visible=not modal.Visible and not catchReveal:IsVisible()end,
    Quiet=function()return catchReveal:IsVisible()end,
    Notice=function()return toast.Visible end,
})
bagButton.Activated:Connect(function() if modal.Visible then closeModal() else openModal("bag") end end)
closeButton.Activated:Connect(closeModal)
bagTab.Activated:Connect(function() shownMode = "bag"; renderModal() end)
bookTab.Activated:Connect(function() shownMode = "book"; renderModal() end)
cancelButton.Activated:Connect(function() if sessionId then Action:FireServer("Cancel", sessionId) end end)
local function press(input)
    if not input or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    if stageName=="Landing" or landingPlaying() then return end
    if catchReveal:IsVisible() then
        if catchReveal:CanDismiss() then catchReveal:Hide(false) end
        return -- closing a portrait never begins another cast
    end
    if modal.Visible or (voyage and (voyage:IsOpen() or voyage:IsDriving())) or activeInput or UIS:GetFocusedTextBox() then return end
    activeInput = input; holding = true
    if stageName == "Idle" then
        if not data then notify("Профиль ещё загружается."); return end
        pendingRelease = false; stageName = "Request"; requestAt = os.clock(); updateStage()
        Action:FireServer("Begin")
    elseif stageName == "Waiting" then Action:FireServer("Shake", sessionId)
    elseif stageName == "Bite" then Action:FireServer("Hook", sessionId)
    elseif stageName == "Reeling" then Action:FireServer("Input", sessionId, true) end
end
local function release(input, force)
    if not force and input ~= activeInput then return end
    activeInput = nil; holding = false
    if stageName == "Request" then pendingRelease = true
    elseif stageName == "Charging" then Action:FireServer("Release", sessionId)
    elseif stageName == "Reeling" then Action:FireServer("Input", sessionId, false) end
end
actionButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then press(input) end
end)
-- Command Bar API uses the live presentation objects, with no reward remotes.
local studioPreview
if RunService:IsStudio() then
    local StudioPreview=require(shared:WaitForChild("StudioPreview"))
    studioPreview=StudioPreview
    StudioPreview.Attach({Config=Config,Gui=gui,
        Alive=function()return gui.Parent~=nil end,
        CanPreview=function()
            return stageName=="Idle" and not modal.Visible and not landingPlaying()
                and (not catchReveal:IsVisible() or catchReveal.Host:GetAttribute("Preview")==true)
                and not (voyage and (voyage:IsOpen() or voyage:IsDriving()))
        end,
        HidePortrait=function()
            if catchReveal.Host:GetAttribute("Preview")==true then catchReveal:Hide(true);hideReveal(true)end
        end,
        ClearPreviews=function()landingEffects:ClearPreviews();castEffects:ClearPreviewPoses()end,
        Rod=function(stage,seconds)return castEffects:PreviewPose(stage,seconds)end,
        World=function(id,mutation)return landingEffects:Preview(id,mutation)end,
        WorldPlaying=function()return landingEffects:OwnerPlaying()end,
        Portrait=function(id,mutation)
            local fish=Config.ById[id]
            local kg=math.floor((fish.MinKg+fish.MaxKg)*50)/100
            showCatchReveal({Species=id,Kg=kg,Mutation=mutation,Value=Config.Value(fish,kg,mutation)},
                {XP=fish.XP,Preview=true,New=false,LevelUp=false})
        end,
    })
end
local previewIndex = 0 -- Studio only, presentation without reward remotes
local worldPreviewIndex = 0
UIS.InputBegan:Connect(function(input, processed)
    if processed or UIS:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.P and RunService:IsStudio() then
        if stageName == "Idle" and not modal.Visible and not landingPlaying() then
            previewIndex = previewIndex % #Config.Fish + 1
            local fish = Config.Fish[previewIndex]
            local kg = math.floor((fish.MinKg + fish.MaxKg) * 50) / 100
            local record = {Species = fish.Id, Kg = kg, Mutation = "normal",
                Value = Config.Value(fish, kg, "normal")}
            showCatchReveal(record, {XP = fish.XP, Preview = true, New = false, LevelUp = false})
        end
    elseif input.KeyCode==Enum.KeyCode.O and RunService:IsStudio() then
        if stageName=="Idle" and not modal.Visible and not landingPlaying() then
            catchReveal:Hide(true)
            worldPreviewIndex=worldPreviewIndex % #Config.Fish+1
            local f=Config.Fish[worldPreviewIndex]
            if landingEffects:Preview(f.Id) then notify("3D-превью: "..f.Name.." · без награды",C.Gold,2)end
        end
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 then press(input)
    elseif input.KeyCode == Enum.KeyCode.B then if modal.Visible then closeModal() else openModal("bag") end
    elseif input.KeyCode == Enum.KeyCode.Q and sessionId then Action:FireServer("Cancel", sessionId) end
end)
UIS.InputEnded:Connect(function(input) release(input, false) end)
UIS.WindowFocusReleased:Connect(function() release(nil, true) end)
-- Space is never bound to fishing. Normal Roblox movement keeps its jump input.
local waterJump = WaterJump.new(player, Config.WaterJump, function()
    return stageName == "Idle" and not modal.Visible and not UIS:GetFocusedTextBox()
end)
gui.Destroying:Connect(function() waterJump:Destroy();thumbnails:Destroy();castEffects:Destroy();landingEffects:Destroy() end)
player.CharacterRemoving:Connect(function()
    if studioPreview then pcall(studioPreview.Stop,studioPreview) end
    landingEffects:Clear();pendingCaught=nil;landingEndsAt=0
    catchReveal:Hide(true)
    if sessionId then Action:FireServer("Cancel", sessionId) end
    activeInput = nil; holding = false; stageName = "Idle"; sessionId = nil; closeModal(); updateStage()
end)
Update.OnClientEvent:Connect(function(kind, payload)
    castEffects:Handle(kind,payload)
    landingEffects:Handle(kind,payload)
    if voyage then voyage:Handle(kind,payload) end
    if kind == "Profile" then data = payload.Data; memoryOnly = payload.MemoryOnly; updateStats()
    elseif kind == "Notice" then notify(payload.Text)
    elseif kind == "Rejected" then
        stageName = "Idle"; sessionId = nil; pendingRelease = false; updateStage(); notify(payload.Text, C.Gold)
    elseif kind == "Shop" then openModal("shop")
    elseif kind == "Shake" then trackText.Text = "Рыба подплывает ближе…"
    elseif kind == "Stage" then
        stageName = payload.Stage; sessionId = stageName ~= "Idle" and payload.Id or nil
        if stageName == "Charging" then
            catchReveal:Hide(true)
            chargeStarted = payload.Started
            if pendingRelease or not holding then Action:FireServer("Release", sessionId) end
        elseif stageName == "Bite" then hookDeadline = payload.Deadline; hookWindow = payload.Duration or Config.HookWindow
        elseif stageName == "Reeling" then
            latest = {Bar = 0.5, Fish = 0.5, Width = payload.Width, Progress = 0.34, Inside = true}
            displayBar = 0.5; displayFish = 0.5; Action:FireServer("Input", sessionId, holding)
        elseif stageName == "Landing" then
            holding=false;activeInput=nil;catchReveal:Hide(true)
            landingEndsAt=payload.Started+payload.Duration
        elseif stageName == "Idle" then pendingRelease = false; holding = false end
        updateStage()
    elseif kind == "Reel" then
        if stageName == "Reeling" and payload.Id == sessionId then latest = payload end
    elseif kind == "Caught" then
        if not payload.Record or not Config.ById[payload.Record.Species] then return end
        if landingPlaying()then pendingCaught=payload;return end
        local r = payload.Record; local fish = Config.ById[r.Species]
        local suffix = payload.LevelUp and " · НОВЫЙ УРОВЕНЬ!" or (payload.New and " · Новая запись в коллекции!" or "")
        local hasPortrait = showCatchReveal(r, payload)
        if not hasPortrait then
            notify(string.format("ПОЙМАНО: %s\n%.2f кг · %d монет · +%d опыта%s", fishName(r), r.Kg, r.Value, payload.XP, suffix), fishColor(fish), 5)
        end
    end
end)
RunService.RenderStepped:Connect(function(dt)
    if pendingCaught and not landingPlaying()then
        local p=pendingCaught;pendingCaught=nil;showCatchReveal(p.Record,p)
    end
    panel.Visible=stageName~="Landing" and not landingPlaying() and not modal.Visible and not catchReveal:IsVisible() and not voyage:IsOpen() and not voyage:IsDriving()
    if toast.Visible and os.clock() > toastUntil then toast.Visible = false end
    local camera = workspace.CurrentCamera
    if camera then panelScale.Scale = camera.ViewportSize.Y < 500 and 0.78 or 1 end
    if reveal.Visible and os.clock() > revealUntil then revealUntil = math.huge; hideReveal(false) end
    thumbnails:Update()
    local hour = Lighting.ClockTime
    timeLabel.Text = string.format("%02d:%02d · %s", math.floor(hour), math.floor(hour % 1 * 60), (hour >= 18 or hour < 6) and "НОЧЬ" or "ДЕНЬ")
    if stageName == "Request" and os.clock() - requestAt > 5 then
        stageName = "Idle"; pendingRelease = false; updateStage(); notify("Нет ответа от сервера. Попробуй ещё раз.")
    elseif stageName == "Charging" then
        local power = math.clamp((workspace:GetServerTimeNow() - chargeStarted) / Config.ChargeSeconds, 0, 1)
        charge.Size = UDim2.fromScale(power, 1); trackText.Text = "СИЛА ЗАБРОСА · " .. math.floor(power * 100) .. "%"
    elseif stageName == "Bite" then
        local left = math.max(0, hookDeadline - workspace:GetServerTimeNow())
        charge.Size = UDim2.fromScale(left / hookWindow, 1); trackText.Text = string.format("ПОДСЕКАЙ! %.1f с", left)
    elseif stageName == "Reeling" then
        local alpha = 1 - math.exp(-22 * dt)
        displayBar = displayBar + (latest.Bar - displayBar) * alpha
        displayFish = displayFish + (latest.Fish - displayFish) * alpha
        bar.Position = UDim2.fromScale(displayBar, 0); bar.Size = UDim2.fromScale(latest.Width, 1)
        bar.BackgroundColor3 = latest.Inside and C.Aqua or C.Red
        fishMarker.Position = UDim2.fromScale(displayFish, 0)
        progress.Size = UDim2.fromScale(latest.Progress, 1)
        title.Text = "ВЫВАЖИВАНИЕ · " .. math.floor(latest.Progress * 100) .. "%" .. ((latest.Cue and latest.Cue~="")and " · "..latest.Cue or "")
        if os.clock() >= resendAt then resendAt = os.clock() + 0.18; Action:FireServer("Input", sessionId, holding) end
    end
end)
updateStage()
Action:FireServer("Ready")
task.spawn(function()
    while not data and gui.Parent do task.wait(2); Action:FireServer("Ready") end
end)
notify("Добро пожаловать! Рыбалка — на северном пирсе. Лодочная верфь — на юге. M — карта.", C.Gold, 8)
