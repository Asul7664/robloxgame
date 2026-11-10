-- Canonical progression and combat stats. WeaponType remains the animation
-- family; WeaponId identifies the owned tier. Existing paid IDs are retained.
local Catalog = {
    List = {
        {Id='PracticeSaber',Kind='Saber',Tier=1,Level=1,Name='Тренировочная сабля',Price=0,Damage=10,ComboDamage=14,Range=7.5,Cooldown=.42,
            Description='Простая стартовая сабля. Выдаётся бесплатно.'},
        {Id="Saber",Kind='Saber',Tier=2,Level=2, Name="Сабля", Price=250, Damage=18, ComboDamage=26,Range=7.5,Cooldown=.42,
            Description="Три взмаха подряд. Третий удар шире и сильнее."},
        {Id='Cutlass',Kind='Saber',Tier=3,Level=4,Name='Абордажный тесак',Price=1800,Damage=25,ComboDamage=35,Range=7.5,Cooldown=.42,
            Description='Крепкий клинок для уверенных морских охотников.'},
        {Id='CorsairSaber',Kind='Saber',Tier=4,Level=7,Name='Сабля корсара',Price=6500,Damage=34,ComboDamage=48,Range=7.5,Cooldown=.42,
            Description='Усиленный клинок с тяжёлым завершающим ударом.'},
        {Id='Tideblade',Kind='Saber',Tier=5,Level=10,Name='Клинок прилива',Price=18000,Damage=46,ComboDamage=64,Range=7.5,Cooldown=.42,
            Description='Лучший меч: редкая сталь и морское золото.'},
        {Id='OldMusket',Kind='Musket',Tier=1,Level=1,Name='Старый мушкет',Price=0,Damage=16,Reload=2.2,Range=110,Cooldown=2.2,
            Description='Бесплатное первое ружьё. Невысокий урон и долгая перезарядка.'},
        {Id="Musket",Kind='Musket',Tier=2,Level=2, Name="Мушкет", Price=900, Damage=28, Reload=1.7, Range=140,Cooldown=1.7,
            Description="Один точный выстрел. Затем перезарядка."},
        {Id='NavalMusket',Kind='Musket',Tier=3,Level=4,Name='Флотский мушкет',Price=3500,Damage=40,Reload=1.6,Range=165,Cooldown=1.6,
            Description='Надёжное морское ружьё с улучшенным стволом.'},
        {Id='CaptainMusket',Kind='Musket',Tier=4,Level=7,Name='Ружьё капитана',Price=11000,Damage=56,Reload=1.5,Range=190,Cooldown=1.5,
            Description='Дальний бой с высоким уроном и быстрой перезарядкой.'},
        {Id='StormMusket',Kind='Musket',Tier=5,Level=10,Name='Грозовой мушкет',Price=28000,Damage=76,Reload=1.4,Range=220,Cooldown=1.4,
            Description='Лучшее ружьё: мощный выстрел и максимальная дальность.'},
    },
    ById = {},
    Starters={Saber='PracticeSaber',Musket='OldMusket'},
}
for _, weapon in ipairs(Catalog.List) do Catalog.ById[weapon.Id] = weapon end
function Catalog.Resolve(tool)
    if not tool or not tool:IsA('Tool') then return nil end
    local kind=tool:GetAttribute('WeaponType')
    local id=tool:GetAttribute('WeaponId') or kind -- paid legacy Tools predate WeaponId
    local weapon=Catalog.ById[id]
    return weapon and weapon.Kind==kind and weapon or nil
end
function Catalog.CleanOwned(raw)
    local owned={}
    if type(raw)=='table' then
        for id,value in pairs(raw) do if value==true and Catalog.ById[id] then owned[id]=true end end
    end
    for _,id in pairs(Catalog.Starters) do owned[id]=true end
    return owned
end
function Catalog.CleanEquipped(owned,raw)
    local chosen={}
    for kind in pairs(Catalog.Starters) do
        local id=type(raw)=='table' and raw[kind]
        local weapon=id and Catalog.ById[id]
        if weapon and weapon.Kind==kind and owned[id] then chosen[kind]=id
        else
            for _,candidate in ipairs(Catalog.List) do
                if candidate.Kind==kind and owned[candidate.Id]
                    and (not chosen[kind] or candidate.Tier>Catalog.ById[chosen[kind]].Tier) then chosen[kind]=candidate.Id end
            end
        end
    end
    return chosen
end
return Catalog
