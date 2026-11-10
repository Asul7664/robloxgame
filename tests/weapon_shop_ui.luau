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
local marker='elseif kind == "WeaponShop" then'
local eventStart=assert(source:find(marker,1,true))
local eventEnd=assert(source:find('elseif kind == "Shake"',eventStart,true))
local eventBody=source:sub(eventStart+#marker,eventEnd-1)
local profileMarker='elseif kind == "Profile" then'
local profileStart=assert(source:find(profileMarker,1,true))
local profileEnd=assert(source:find('elseif kind == "Notice"',profileStart,true))
local profileBody=source:sub(profileStart+#profileMarker,profileEnd-1)
local fragment = 'local weaponShopFamily="Saber"\nlocal data=data\nlocal memoryOnly=memoryOnly\n' .. source:sub(first, last - 1)
    .. '\nlocal function openShop(payload)\n' .. eventBody .. '\nend'
    .. '\nlocal function profile(payload)\n' .. profileBody .. '\nend'
    .. '\nreturn {Render=renderModal,UpdateStats=updateStats,OpenShop=openShop,Profile=profile}'
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
local ui
env.openModal=function(mode)env.shownMode=mode;env.modal.Visible=true;ui.Render()end
ui = luau.load(fragment, {environment=env})()
local function buy(id)
    local r=assert(scroll:FindFirstChild('WeaponRow_'..id),'Weapon is not in this shop: '..id)
    return r:FindFirstChild('WeaponBuy_'..id)
end
-- Execute the real WeaponShop event branch, with only the existing modal opener
-- doubled. This exercises reopening and malformed server payloads as well as rows.
local openShop=ui.OpenShop
local function family(kind)
    local count=0
    for _,weapon in ipairs(Catalog.List) do
        local r=scroll:FindFirstChild('WeaponRow_'..weapon.Id)
        if weapon.Kind==kind then
            count+=1
            check(r and r:FindFirstChild('WeaponName').Text==weapon.Name,'weapon has its own name without a numbered prefix')
            check(r.Size.Y.Offset>=180 and r:FindFirstChild('WeaponRequirement').Text:find('Уровень '..weapon.Level,1,true),
                'rows reserve space for name, tier and level on narrow screens')
            local stats=r:FindFirstChild('WeaponStats').Text
            check(stats:find('Урон: '..weapon.Damage,1,true)~=nil,'each tier displays its real damage')
            check(kind=='Saber' and stats:find('комбо:',1,true)~=nil
                or kind=='Musket' and stats:find('Перезарядка:',1,true)~=nil,'stats follow the combat family')
        else check(r==nil,'physical shop never displays the other weapon family') end
    end
    check(count==5 and #scroll:GetChildren()==7,'each shop has exactly five entries, one heading and one note')
    check(scroll:FindFirstChild('WeaponFamily_'..kind)~=nil,'shop has the correct family heading')
    check(scroll:FindFirstChild('WeaponFamily_'..(kind=='Saber' and 'Musket' or 'Saber'))==nil,
        'there is no in-menu switch to the other physical shop')
    check(env.modalTitle.Text:find(kind=='Saber' and 'ЛАВКА МЕЧЕЙ' or 'ЛАВКА РУЖЕЙ',1,true)~=nil,
        'title identifies the currently visited shop')
end
openShop({Family='Saber'});family('Saber')
check(not env.bagTab.Visible and not env.bookTab.Visible,'shop hides collection tabs')
check(scroll.Position.Y.Offset==55 and scroll.Size.Y.Offset==-65,'shop preserves the existing scrolling layout')
check(buy('PracticeSaber').Active and buy('PracticeSaber').Text=='БЕСПЛАТНО\nВЗЯТЬ','free starter is available without legacy ownership fields')
check(not buy('Saber').Active and buy('Saber').Text=='С УРОВНЯ\n2','coins cannot bypass required level')
buy('Saber').Activated:Fire();check(#calls==0,'level-locked purchase sends no request')
buy('PracticeSaber').Activated:Fire()
check(#calls==1 and calls[1][1]=='WeaponBuy' and calls[1][2]=='' and calls[1][3]=='PracticeSaber','free tier uses existing server action')
env.data.XP=100;ui.UpdateStats()
check(buy('Saber').Active and buy('Saber').Text==Catalog.ById.Saber.Price..'\nКУПИТЬ','exact price and required level unlock purchase')
buy('Saber').Activated:Fire();check(#calls==2 and calls[2][3]=='Saber','sword sends the canonical item ID')
env.data.Coins=Catalog.ById.Saber.Price-1;ui.UpdateStats()
check(not buy('Saber').Active and buy('Saber').Text:find('НЕ ХВАТАЕТ',1,true),'wallet refresh clearly blocks insufficient coins')
env.data.Coins=Catalog.ById.Musket.Price
openShop({Family='Musket'});family('Musket')
check(buy('OldMusket').Active and buy('OldMusket').Text=='БЕСПЛАТНО\nВЗЯТЬ','gun shop offers its own free starter')
check(buy('Musket').Active,'gun unlocks at its exact price')
buy('Musket').Activated:Fire();check(#calls==3 and calls[3][3]=='Musket','gun sends its canonical item ID through the same server action')
env.data.Coins=0;env.data.XP=0;env.data.OwnedWeapons={Musket=true};env.data.EquippedWeapons={Musket='Musket'}
ui.UpdateStats();family('Musket')
check(buy('Musket').Active and buy('Musket').Text=='ВЗЯТЬ','legacy purchased gun remains recoverable below the new level')
check(scroll:FindFirstChild('WeaponRow_Musket'):FindFirstChild('WeaponRequirement').Text:find('В НАБОРЕ',1,true),
    'selected loadout is marked without claiming both weapons are in the hands')
buy('Musket').Activated:Fire();check(#calls==4 and calls[4][3]=='Musket','selected weapon remains recoverable')
-- A fresh Profile snapshot must not reset the visited family to the sword shop.
env.data={Coins=100000,XP=900,Rod=1,Bag={},OwnedWeapons={Saber=true},EquippedWeapons={Saber='Saber'}}
ui.Profile({Data=env.data,MemoryOnly=false});family('Musket')
check(env.modalTitle.Text:find('УР. 10',1,true)~=nil,'shop title updates the player level')
for _,weapon in ipairs(Catalog.List) do if weapon.Kind=='Musket' then check(buy(weapon.Id).Active,'high-level wallet permits every gun') end end
env.data.TestMode=true;env.data.Coins=0;env.data.XP=0;ui.UpdateStats()
for _,weapon in ipairs(Catalog.List) do if weapon.Kind=='Musket' then check(buy(weapon.Id).Active,'tester bypasses gun level and price') end end
openShop({Family='Saber'});family('Saber')
check(buy('PracticeSaber').Text=='ТЕСТЕР\nВЗЯТЬ','tester receives unowned items free')
for _,weapon in ipairs(Catalog.List) do if weapon.Kind=='Saber' then check(buy(weapon.Id).Active,'tester bypasses sword level and price') end end
check(buy('Saber').Text=='ВЗЯТЬ','tester retains ownership caption')
-- Malformed/missing family is safe and cannot expose a mixed catalog.
for _,payload in ipairs({{}, {Family='Bow'}, {Family=123}, 'Musket'}) do openShop(payload);family('Saber') end
openShop(nil);family('Saber')
local oldRow=scroll:FindFirstChild('WeaponRow_Saber')
env.modal.Visible=false;env.data.Coins=0;ui.UpdateStats()
check(scroll:FindFirstChild('WeaponRow_Saber')==oldRow,'closed modal avoids rebuilding unused rows')
print('PASS weapon shop UI: '..checks..' split-shop render/profile/action checks; complete client compiles')
