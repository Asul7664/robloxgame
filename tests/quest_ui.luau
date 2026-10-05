-- Run from the repository root: lune run tests/quest_ui.luau
-- Execute the production UI with GUI-event doubles; retain real Roblox layout types.
local fs = require('@lune/fs')
local luau = require('@lune/luau')
local R = require('@lune/roblox')
local source = fs.readFile('src/client/QuestUI.luau')
local now = 0
local checks = 0
local function check(ok, message) checks += 1; assert(ok, message) end
local function signal()
    local callbacks = {}
    return {Connect = function(_, callback)
        table.insert(callbacks, callback)
        return {Disconnect = function() table.clear(callbacks) end}
    end, Fire = function() for _, callback in ipairs(table.clone(callbacks)) do callback() end end}
end
local Methods = {}
local function new(class)
    local props = {ClassName = class, Name = class, Children = {}, Visible = true,
        Activated = signal(), CanvasPosition = R.Vector2.zero}
    return setmetatable({}, {
        __index = function(_, key) return Methods[key] or props[key] end,
        __newindex = function(self, key, value)
            if key == 'Parent' then
                if props.Parent then
                    for i, child in ipairs(props.Parent.Children) do
                        if child == self then table.remove(props.Parent.Children, i); break end
                    end
                end
                props.Parent = value
                if value then table.insert(value.Children, self) end
            else props[key] = value end
        end,
    })
end
function Methods:IsA(class) return self.ClassName == class end
function Methods:GetChildren() return table.clone(self.Children) end
function Methods:FindFirstChild(name) for _, child in ipairs(self.Children) do if child.Name == name then return child end end end
function Methods:Destroy() for _, child in ipairs(self:GetChildren()) do child:Destroy() end; self.Parent = nil end
local UI = luau.load(source, {environment = {
    Instance = {new = new}, Color3 = R.Color3, UDim = R.UDim, UDim2 = R.UDim2, Vector2 = R.Vector2,
    Enum = R.Enum, workspace = {GetServerTimeNow = function() return 1000 + now end}, os = {clock = function() return now end},
}})()
local gui = new('ScreenGui')
local header = new('Frame'); header.Name = 'Header'; header.Parent = gui
local calls, opens, closes, allowed = {}, 0, 0, true
local ui = UI.new(gui, {}, function(kind, id) table.insert(calls, {kind, id}) end, {
    CanOpen = function() return allowed end,
    OnOpen = function() opens += 1 end, OnClose = function() closes += 1 end,
})
local function snapshot(claimed)
    return {ServerNow = 1000 + now, Daily = {Key = 'd:1', ResetAt = 1060, Tasks = {
        {Id = 'd:1:a', Title = 'Поймай 10 Патапимов', Progress = 9, Target = 10, Reward = 600, Claimed = false},
        {Id = 'd:1:b', Title = 'Поймай 20 рыб', Progress = 20, Target = 20, Reward = 300, Claimed = claimed or false},
        {Id = 'd:1:fishing_time', Kind = 'activity', Unit = 'seconds', Title = 'Рыбачь активно 20 минут', Progress = 73, Target = 1200, Reward = 900, Claimed = false},
    }}, Weekly = {Key = 'w:1', ResetAt = 1000 + 604800, Tasks = {
        {Id = 'w:1:a', Title = 'Поймай 300 рыб', Progress = 300, Target = 300, Reward = 6000, Claimed = false},
    }}}
end
ui:Update(snapshot())
check(ui.Button.Text == 'ЗАДАНИЯ · 2', 'badge includes ready daily+weekly')
allowed = false; ui:Toggle(); check(not ui:IsOpen() and opens == 0, 'cannot open while fishing')
allowed = true; ui.Button.Activated:Fire(); check(ui:IsOpen() and opens == 1, 'button opens window')
local a = ui.List:FindFirstChild('Quest_d:1:a')
local b = ui.List:FindFirstChild('Quest_d:1:b')
check(a:FindFirstChild('Claim').Text == 'В ПРОЦЕССЕ', 'unfinished disabled')
a:FindFirstChild('Claim').Activated:Fire(); check(#calls == 0, 'unfinished cannot send claim')
b:FindFirstChild('Claim').Activated:Fire(); check(#calls == 1 and calls[1][1] == 'Daily' and calls[1][2] == 'd:1:b', 'claim sends full period scoped ID')
check(ui.List:FindFirstChild('Quest_d:1:b'):FindFirstChild('Claim').Text == 'ЖДЁМ…', 'server confirmation pending')
ui.List:FindFirstChild('Quest_d:1:b'):FindFirstChild('Claim').Activated:Fire(); check(#calls == 1, 'double click suppressed')
now += 9; ui:Step(); check(ui.List:FindFirstChild('Quest_d:1:b'):FindFirstChild('Claim').Text == 'ЗАБРАТЬ', 'timeout unlocks retry')
ui:Update(snapshot(true)); check(ui.List:FindFirstChild('Quest_d:1:b'):FindFirstChild('Claim').Text == 'ПОЛУЧЕНО', 'server acknowledges reward')
check(ui.Button.Text == 'ЗАДАНИЯ · 1', 'claimed leaves ready badge')
local times = ui.List:FindFirstChild('Quest_d:1:fishing_time')
local timeLabel
for _, child in ipairs(times:GetChildren()) do if child.ClassName == 'TextLabel' and child.Text == '1:13 / 20:00' then timeLabel = child end end
check(timeLabel ~= nil, 'seconds shown as minutes:seconds')
check(string.find(ui.Countdown.Text, '00:00 UTC', 1, true) ~= nil, 'actual reset clock visible')
ui.Tabs.Weekly.Activated:Fire(); check(ui.Period == 'Weekly' and ui.List:FindFirstChild('Quest_w:1:a'), 'weekly tab shows different list')
check(string.find(ui.Countdown.Text, 'понедельникам', 1, true) ~= nil, 'weekly Monday reset visible')
ui.List:FindFirstChild('Quest_w:1:a'):FindFirstChild('Claim').Activated:Fire(); check(calls[2][1] == 'Weekly', 'weekly claims correct period')
ui:Update(snapshot(true)); ui.Tabs.Daily.Activated:Fire()
now = 61; ui:Step()
check(string.find(ui.Countdown.Text, 'Обновление заданий', 1, true) ~= nil, 'zero boundary visible')
ui:_claim('Daily', {Id = 'd:1:b', Progress = 20, Target = 20, Claimed = false}); check(#calls == 2, 'expired period cannot claim stale completed task')
local fresh = snapshot(); fresh.Daily.Key = 'd:2'; fresh.Daily.ResetAt = 2000; fresh.Daily.Tasks = {{Id='d:2:a',Title='Новое задание',Target=30,Progress=0,Reward=900,Claimed=false}}
ui:Update(fresh); check(ui.List:FindFirstChild('Quest_d:2:a') ~= nil and ui.List:FindFirstChild('Quest_d:1:a') == nil, 'rollover replaces tasks')
local preserved = R.Vector2.new(0, 37); ui.List.CanvasPosition = preserved; ui:Update(fresh)
check(ui.List.CanvasPosition == preserved, 'incoming progress preserves scrolling')
ui:Close(); check(not ui:IsOpen() and closes == 1, 'close callback restores other HUD')
ui:Close(); check(closes == 1, 'closing already closed is quiet')
-- Execute the exact production header layout with GUI measurements at representative screens.
local client = fs.readFile('src/client/QuietCoveClient.client.luau')
luau.compile(client)
local first = assert(client:find('local headerWidth', 1, true))
local last = assert(client:find('bagButton.Activated:Connect', first, true))
local props = {header = {}, heading = {}, statsLabel = {}, timeLabel = {}, bagButton = {}, quests = {Button = {}}, voyage = {MapButton = {}, Nav = {}}, toast = {}}
local env = table.clone(props); env.UDim2 = R.UDim2
local layout = luau.load(client:sub(first, last - 1) .. '\nreturn layoutHeader', {environment = env})()
local function rect(obj, pw, ph, px, py)
    return {x=px+obj.Position.X.Scale*pw+obj.Position.X.Offset, y=py+obj.Position.Y.Scale*ph+obj.Position.Y.Offset,
        w=obj.Size.X.Scale*pw+obj.Size.X.Offset, h=obj.Size.Y.Scale*ph+obj.Size.Y.Offset}
end
local function overlaps(a,b) return a.x < b.x+b.w and b.x < a.x+a.w and a.y < b.y+b.h and b.y < a.y+a.h end
for _, width in ipairs({320,375,568,580,1280,1920}) do
    layout(width)
    local hw, hh = width - 24, props.header.Size.Y.Offset
    local map = rect(props.voyage.MapButton,width,720,0,0)
    local quest = rect(props.quests.Button,hw,hh,12,10)
    local bag = rect(props.bagButton,hw,hh,12,10)
    for _, r in ipairs({map,quest,bag}) do
        check(r.x>=12 and r.x+r.w <= width-12 and r.y>=10 and r.y+r.h<=10+hh,'all HUD buttons fit width '..width)
    end
    check(not overlaps(map,quest) and not overlaps(map,bag) and not overlaps(quest,bag),'HUD buttons never overlap at width '..width)
end
ui:Destroy(); check(ui.Host.Parent == nil and ui.Button.Parent == nil, 'UI cleans up both hosts')
print('PASS QuestUI '..checks..' functional/layout checks; production module and client compile')
