-- Run from the repository root: lune run tests/weapon_shop_ui.luau
-- Execute the existing modal renderer and profile-refresh hook with GUI doubles.
local fs = require('@lune/fs')
local luau = require('@lune/luau')
local R = require('@lune/roblox')
local Catalog = luau.load(fs.readFile('src/shared/WeaponCatalog.luau'))()
local source = fs.readFile('src/client/QuietCoveClient.client.luau')
luau.compile(source)
local first = assert(source:find('local function renderModal()', 1, true))
local last = assert(source:find('local function updateStage()', first, true))
local fragment = source:sub(first, last - 1)
    .. '\nreturn {Render=renderModal,UpdateStats=updateStats}'
local checks, calls = 0, {}
local function check(value, reason) checks += 1; assert(value, reason) end
local Methods = {}
local function create(class, props, parent)
    local node = setmetatable({ClassName=class,Children={},Parent=parent}, {__index=Methods})
    for key, value in pairs(props) do node[key] = value end
    if parent then table.insert(parent.Children, node) end
    if class == 'TextButton' then
        local listeners = {}
        node.Activated = {
            Connect = function(_, callback) table.insert(listeners, callback) end,
            Fire = function() for _, callback in ipairs(listeners) do callback() end end,
        }
    end
    return node
end
function Methods:IsA(class) return class == self.ClassName or class == 'GuiObject' end
function Methods:GetChildren()
    local children = {}
    for _, child in ipairs(self.Children) do
        if not child.Destroyed then table.insert(children, child) end
    end
    return children
end
function Methods:Destroy() self.Destroyed = true end
function Methods:FindFirstChild(name)
    for _, child in ipairs(self:GetChildren()) do if child.Name == name then return child end end
end
local scroll = create('ScrollingFrame', {})
local env = {
    thumbnails={Clear=function() end}, scroll=scroll, bagTab={}, bookTab={}, modalTitle={},
    modal={Visible=true}, statsLabel={}, memoryOnly=false,
    data={Coins=Catalog.ById.Saber.Price,XP=0,Rod=1,Bag={}}, shownMode='weapons',
    Enum=R.Enum, UDim2=R.UDim2, C={Panel=1,Bg=2,Ink=3,Muted=4,Gold=5,Aqua=6},
    create=create, rounded=function() end, WeaponCatalog=Catalog,
    Config={Level=function(xp) return 1+math.floor(xp/100) end,BagCapacity=30,Rods={{Name='Удочка'}}},
    Action={FireServer=function(_, ...) table.insert(calls, {...}) end},
}
env.text = function(parent, content, size, position, fontSize, color)
    return create('TextLabel', {Text=content,Size=size,Position=position,TextSize=fontSize,TextColor3=color}, parent)
end
env.button = function(parent, content, size, position, bg)
    return create('TextButton', {Text=content,Size=size,Position=position,BackgroundColor3=bg}, parent)
end
local ui = luau.load(fragment, {environment=env})()
local function buy(id)
    return scroll:FindFirstChild('WeaponRow_'..id):FindFirstChild('WeaponBuy_'..id)
end
ui.Render()
check(not env.bagTab.Visible and not env.bookTab.Visible, 'shop hides collection tabs')
check(scroll.Position.Y.Offset == 55 and scroll.Size.Y.Offset == -65, 'shop uses existing shop layout')
check(#Catalog.List==10, 'catalog offers five swords and five guns')
local swords,guns=0,0
for _,weapon in ipairs(Catalog.List) do
    if weapon.Kind=='Saber' then swords+=1 else guns+=1 end
    local r=scroll:FindFirstChild('WeaponRow_'..weapon.Id)
    check(r and r:FindFirstChild('WeaponName').Text:find(weapon.Name,1,true), 'all catalog names are visible')
    check(r.Size.Y.Offset>=180 and r:FindFirstChild('WeaponRequirement').Text:find('Уровень '..weapon.Level,1,true),
        'rows reserve space for name, tier and required level on narrow screens')
    local stats=r:FindFirstChild('WeaponStats').Text
    check(stats:find('Урон: '..weapon.Damage,1,true)~=nil, 'every tier displays its own damage')
    check(weapon.Kind=='Saber' and stats:find('комбо:',1,true)~=nil
        or weapon.Kind=='Musket' and stats:find('Перезарядка:',1,true)~=nil,
        'stats follow combat family rather than one legacy ID')
end
check(swords==5 and guns==5, 'both progression families have five tiers')
check(scroll:FindFirstChild('WeaponFamily_Saber').LayoutOrder < scroll:FindFirstChild('WeaponRow_PracticeSaber').LayoutOrder,
    'swords have a readable family heading')
check(scroll:FindFirstChild('WeaponFamily_Musket').LayoutOrder > scroll:FindFirstChild('WeaponRow_Tideblade').LayoutOrder,
    'gun heading starts after the five swords')
check(buy('PracticeSaber').Active and buy('PracticeSaber').Text=='БЕСПЛАТНО\nВЗЯТЬ',
    'starter sword remains available when an old payload lacks ownership')
check(buy('OldMusket').Active and buy('OldMusket').Text=='БЕСПЛАТНО\nВЗЯТЬ', 'starter gun has no coin barrier')
check(not buy('Saber').Active and buy('Saber').Text=='С УРОВНЯ\n2', 'coins cannot bypass the next sword level requirement')
check(not buy('Musket').Active and not buy('Musket').AutoButtonColor, 'locked gun purchase is disabled')
buy('Musket').Activated:Fire()
check(#calls == 0, 'disabled purchase has no remote callback')
buy('PracticeSaber').Activated:Fire()
check(#calls==1 and calls[1][1]=='WeaponBuy' and calls[1][3]=='PracticeSaber', 'free tier uses existing server purchase action')
env.data.XP=100;ui.UpdateStats()
check(buy('Saber').Active and buy('Saber').Text==Catalog.ById.Saber.Price..'\nКУПИТЬ',
    'sufficient level and exact coins unlock the catalog sword')
buy('Saber').Activated:Fire()
check(#calls == 2 and calls[2][1] == 'WeaponBuy' and calls[2][2] == '' and calls[2][3] == 'Saber',
    'purchase sends catalog ID through existing Action')
env.data.Coins = Catalog.ById.Saber.Price - 1; ui.UpdateStats()
check(not buy('Saber').Active, 'profile refresh disables purchase one coin below price')
env.data.Coins = Catalog.ById.Musket.Price; ui.UpdateStats()
check(buy('Musket').Active, 'profile refresh permits musket at its exact price')
env.data.Coins = 0; env.data.OwnedWeapons = {Musket=true}; ui.UpdateStats()
check(not buy('Saber').Active, 'wallet update refreshes affordability')
check(buy('Musket').Active and buy('Musket').Text == 'ВЗЯТЬ', 'owned weapon remains available without money')
buy('Musket').Activated:Fire()
check(#calls == 3 and calls[3][3] == 'Musket', 'owned weapon requests restore via same action')
env.data.XP=0;env.data.EquippedWeapons={Musket='Musket'};ui.UpdateStats()
check(buy('Musket').Active and buy('Musket').Text=='ВЗЯТЬ', 'legacy purchased gun can be recovered below its new level requirement')
check(scroll:FindFirstChild('WeaponRow_Musket'):FindFirstChild('WeaponRequirement').Text:find('В НАБОРЕ',1,true),
    'selected loadout is identified without claiming both weapons are in the hands')
buy('Musket').Activated:Fire()
check(#calls==4 and calls[4][3]=='Musket', 'selected gun remains recoverable from the shop')
env.data.TestMode = true; ui.UpdateStats()
check(buy('Saber').Active and buy('Saber').Text == 'ТЕСТЕР\nВЗЯТЬ', 'tester can take unowned weapon free')
check(buy('Musket').Text == 'ВЗЯТЬ', 'tester keeps owned caption')
for _,weapon in ipairs(Catalog.List) do check(buy(weapon.Id).Active,'tester bypasses both price and level for every tier') end
buy('Saber').Activated:Fire()
check(#calls == 5 and calls[5][1] == 'WeaponBuy' and calls[5][3] == 'Saber', 'tester uses the same server-owned issuance action')
env.data.TestMode=false;env.data.XP=900;env.data.Coins=100000;ui.UpdateStats()
for _,weapon in ipairs(Catalog.List) do check(buy(weapon.Id).Active,'level-ten player with money can choose every tier') end
check(env.modalTitle.Text:find('УР. 10',1,true)~=nil,'shop title displays current progression level')
check(#scroll:GetChildren() == #Catalog.List + 3, 'profile refresh clears old rows and family headings without stacking')
local oldRow = scroll:FindFirstChild('WeaponRow_Saber')
env.modal.Visible = false; env.data.Coins = Catalog.ById.Saber.Price; ui.UpdateStats()
check(scroll:FindFirstChild('WeaponRow_Saber') == oldRow, 'closed modal avoids rebuilding unused rows')
print('PASS weapon shop UI: '..checks..' production render/profile/action checks; complete client compiles')
