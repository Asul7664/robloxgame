-- Shared server damage entry for purchased weapons and encounter attacks.
local Players = game:GetService('Players')
local Damage = {}
function Damage.Apply(attacker, victimHum, amount)
    local model = victimHum and victimHum.Parent
    if not model or victimHum.Health <= 0 or model == attacker or model:GetAttribute('IFrame')
        or model:GetAttribute('QCNPC') == true then return false end
    local ownerId = model:GetAttribute('QCSahurOwner')
    if ownerId then
        local owner = Players:GetPlayerByUserId(ownerId)
        if model:GetAttribute('SahurEmerging') or not owner or owner.Character ~= attacker then return false end
    end
    victimHum:TakeDamage(amount)
    model:SetAttribute('IFrame', true)
    task.delay(.28, function()
        if model.Parent and not model:GetAttribute('Dodging') then model:SetAttribute('IFrame', false) end
    end)
    return true
end
return Damage
