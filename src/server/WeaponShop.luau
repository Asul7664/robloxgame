-- Uses the existing profile, wallet, Action/Update remotes and map interaction.
local Models = require(script.Parent:WaitForChild("WeaponModels"))
local Shop = {}
Shop.__index = Shop
function Shop.new(catalog, profiles, bank, counter, send, sync, busy, notice)
    local keys=Models.Sync(bank,counter.Parent:WaitForChild("Displays"))
    return setmetatable({Catalog=catalog, Profiles=profiles, Bank=bank, Counter=counter,
        ModelKeys=keys, Send=send, Sync=sync, Busy=busy, Notice=notice}, Shop)
end
function Shop:_can(player)
    local c=player.Character
    local h=c and c:FindFirstChildOfClass("Humanoid")
    local root=c and c:FindFirstChild("HumanoidRootPart")
    return h and h.Health>0 and root and not h.SeatPart and not h.Sit
        and not self.Busy(player) and (root.Position-self.Counter.Position).Magnitude<=18
end
function Shop:_source(id)
    local source=self.Bank:FindFirstChild(id)
    local handle=source and source:FindFirstChild("Handle")
    if source and source:IsA("Tool") and source:GetAttribute("WeaponType")==id
        and source:GetAttribute("WeaponModelKey")==self.ModelKeys[id]
        and source.Archivable~=false and handle and handle:IsA("BasePart") then return source end
end
function Shop:Open(player)
    if not self:_can(player) or not self.Profiles.Get(player) then return false end
    self.Send(player,"WeaponShop",{})
    return true
end
function Shop:Grant(player,character)
    if character~=player.Character then return end
    local data=self.Profiles.Get(player)
    local pack=player:FindFirstChild("Backpack")
    local h=character:FindFirstChildOfClass("Humanoid")
    if not data or not pack or not h or h.Health<=0 then return end
    local owned=data.OwnedWeapons or {}
    local found={}
    for _, parent in ipairs({character,pack}) do
        for _, tool in ipairs(parent:GetChildren()) do
            local id=tool:IsA("Tool") and tool:GetAttribute("WeaponType")
            if id and self.Catalog.ById[id] then
                -- Retire old unconditional gifts and duplicate Tools without
                -- touching the player's fishing rod or unrelated equipment.
                if not owned[id] or found[id] or tool:GetAttribute("WeaponModelKey")~=self.ModelKeys[id] then
                    tool:Destroy()
                else found[id]=tool end
            end
        end
    end
    for _, weapon in ipairs(self.Catalog.List) do
        if owned[weapon.Id] and not found[weapon.Id] then
            local source=self:_source(weapon.Id)
            if source then
                local tool=source:Clone();tool.Parent=pack;found[weapon.Id]=tool
            end
        end
    end
    return found
end
function Shop:Buy(player,id)
    if type(id)~="string" or not self.Catalog.ById[id] or not self:_can(player) then return false end
    local data=self.Profiles.Get(player)
    if not data then return false end
    local c=player.Character
    local h=c:FindFirstChildOfClass("Humanoid")
    local pack=player:FindFirstChild("Backpack")
    local source=self:_source(id)
    if not pack or not source then
        self.Notice(player,"Оружие пока недоступно. Монеты не списаны.")
        return false
    end
    local weapon=self.Catalog.ById[id]
    local owned=data.OwnedWeapons or {}
    local purchased=owned[id]~=true
    if purchased and not data.TestMode and data.Coins<weapon.Price then
        self.Notice(player,"Не хватает "..(weapon.Price-data.Coins).." монет.")
        return false
    end
    -- No yield between checking ownership, charging and setting ownership.
    if purchased then
        if not data.TestMode then data.Coins-=weapon.Price end
        owned[id]=true;data.OwnedWeapons=owned
    end
    local tools=self:Grant(player,c)
    if tools and tools[id] then h:EquipTool(tools[id]) end
    self.Sync(player)
    self.Notice(player,purchased and ("Куплено: "..weapon.Name..". ЛКМ — атака.")
        or (weapon.Name.." в руках. Повторно платить не нужно."))
    return true
end
return Shop
