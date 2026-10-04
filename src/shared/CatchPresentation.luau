-- Presentation sizes in studs. ScaleTo takes an absolute Model scale.
local Presentation = {LandingSizes = {capybara = 2.0}}

function Presentation.LandingSize(species, rarity)
    return Presentation.LandingSizes[species] or (rarity >= 5 and 5.0 or 3.3 + rarity * .16)
end

function Presentation.ScaleLanding(model, species, rarity)
    local _, size = model:GetBoundingBox()
    local extent = math.max(size.X, size.Y, size.Z)
    assert(extent > 0, "Catch model has no size: " .. tostring(species))
    local desired = Presentation.LandingSize(species, rarity)
    model:ScaleTo(model:GetScale() * desired / extent)
    return desired
end

return Presentation
