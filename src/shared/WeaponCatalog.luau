-- Shop order and server-owned prices; combat timing stays in Combat.Config.
local Catalog = {
    List = {
        {Id="Saber", Name="Сабля", Price=250, Damage=18, ComboDamage=26,
            Description="Три взмаха подряд. Третий удар шире и сильнее."},
        {Id="Musket", Name="Мушкет", Price=900, Damage=28, Reload=1.7, Range=140,
            Description="Один точный выстрел. Затем перезарядка."},
    },
    ById = {},
}
for _, weapon in ipairs(Catalog.List) do Catalog.ById[weapon.Id] = weapon end
return Catalog
