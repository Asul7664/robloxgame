-- Uses the existing profile, wallet, Action/Update remotes and map interaction.
local Models = require(script.Parent:WaitForChild("WeaponModels"))
local Shop = {}
Shop.__index = Shop
function Shop.new(catalog, profiles, bank, root, send, sync, busy, notice, levelFromXP)
    local keys=Models.Sync(bank,root:WaitForChild("Displays"))
    local counters={Saber=root:WaitForChild('SwordShop'):WaitForChild('Counter'),
        Musket=root:WaitForChild('GunShop'):WaitForChild('Counter')}
    return setmetatable({Catalog=catalog, Profiles=profiles, Bank=bank, Counters=counters,Counter=counters.Saber,
        ModelKeys=keys, Send=send, Sync=sync, Busy=busy, Notice=notice,Level=levelFromXP or function()return 1 end}, Shop)
end
function Shop:_can(player,family)
    local counter=self.Counters[family]
    if not counter then return false end
    local c=player.Character
    local h=c and c:FindFirstChildOfClass("Humanoid")
    local root=c and c:FindFirstChild("HumanoidRootPart")
    if not h or h.Health<=0 or not root or h.SeatPart or h.Sit or self.Busy(player) then return false end
    local distance=(root.Position-counter.Position).Magnitude
    if distance>18 then return false end
    -- The two stalls are close enough for activation ranges to overlap. The
    -- nearest counter decides the family; at the exact midpoint either prompt
    -- is valid, so there is no dead interaction strip between the shops.
    for otherFamily,other in pairs(self.Counters) do
        if otherFamily~=family and (root.Position-other.Position).Magnitude<distance-.0001 then return false end
    end
    return true
end
function Shop:_source(id)
    local source=self.Bank:FindFirstChild(id)
    local handle=source and source:FindFirstChild("Handle")
    local weapon=self.Catalog.ById[id]
    if source and source:IsA("Tool") and self.Catalog.Resolve(source)==weapon
        and source:GetAttribute("WeaponModelKey")==self.ModelKeys[id]
        and source.Archivable~=false and handle and handle:IsA("BasePart") and handle.Archivable~=false then return source end
end
function Shop:Open(player,family)
    if not self:_can(player,family) or not self.Profiles.Get(player) then return false end
    self.Send(player,"WeaponShop",{Family=family})
    return true
end
function Shop:Grant(player,character)
    if character~=player.Character then return end
    local data=self.Profiles.Get(player)
    local pack=player:FindFirstChild("Backpack")
    local h=character:FindFirstChildOfClass("Humanoid")
    if not data or not pack or not h or h.Health<=0 then return end
    local owned=self.Catalog.CleanOwned(data.OwnedWeapons)
    data.OwnedWeapons=owned
    data.EquippedWeapons=self.Catalog.CleanEquipped(owned,data.EquippedWeapons)
    local found={}
    for _, parent in ipairs({character,pack}) do
        for _, tool in ipairs(parent:GetChildren()) do
            local kind=tool:IsA('Tool') and tool:GetAttribute('WeaponType')
            if self.Catalog.Starters[kind] then
                local entry=self.Catalog.Resolve(tool)
                local id=entry and entry.Id
                -- Retire old unconditional gifts and duplicate Tools without
                -- touching the player's fishing rod or unrelated equipment.
                if not id or data.EquippedWeapons[kind]~=id or not owned[id] or found[id]
                    or tool:GetAttribute("WeaponModelKey")~=self.ModelKeys[id] then
                    tool:Destroy()
                else found[id]=tool end
            end
        end
    end
    for _, weapon in ipairs(self.Catalog.List) do
        if owned[weapon.Id] and data.EquippedWeapons[weapon.Kind]==weapon.Id and not found[weapon.Id] then
            local source=self:_source(weapon.Id)
            if source then
                local tool=source:Clone();tool.Parent=pack;found[weapon.Id]=tool
            end
        end
    end
    for id,tool in pairs(found) do
        tool.Name=self.Catalog.ById[id].Name
        tool.ToolTip=self.Catalog.ById[id].Name..' · Left click to attack'
    end
    return found
end
function Shop:Buy(player,id)
    if type(id)~="string" then return false end
    local weapon=self.Catalog.ById[id]
    if not weapon or not self:_can(player,weapon.Kind) then return false end
    local data=self.Profiles.Get(player)
    if not data then return false end
    local c=player.Character
    local h=c:FindFirstChildOfClass("Humanoid")
    local pack=player:FindFirstChild("Backpack")
    local source=self:_source(id)
    if not pack or not source then
        self.Notice(player,"This weapon is unavailable right now. You have not been charged.")
        return false
    end
    local owned=data.OwnedWeapons or {}
    local purchased=owned[id]~=true
    if purchased and not data.TestMode and self.Level(data.XP)<weapon.Level then
        self.Notice(player,'Reach level '..weapon.Level..' to buy '..weapon.Name..'.')
        return false
    end
    if purchased and not data.TestMode and data.Coins<weapon.Price then
        self.Notice(player,"You need "..(weapon.Price-data.Coins).." more coins.")
        return false
    end
    -- No yield between checking ownership, charging and setting ownership.
    if purchased then
        if not data.TestMode then data.Coins-=weapon.Price end
        owned[id]=true;data.OwnedWeapons=owned
    end
    data.EquippedWeapons=data.EquippedWeapons or {}
    data.EquippedWeapons[weapon.Kind]=id
    local tools=self:Grant(player,c)
    if tools and tools[id] then h:EquipTool(tools[id]) end
    self.Sync(player)
    self.Notice(player,purchased and ("Purchased: "..weapon.Name..". Left click to attack.")
        or (weapon.Name.." equipped. You already own it, so there is no charge."))
    return true
end
return Shop
