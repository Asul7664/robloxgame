-- Presentation-only mapping; every key matches an existing server species ID.
local parent = script.Parent
local art = parent:WaitForChild("CatchArtData")
local Catalog = {}
local known = {capybara=true, skibidi=true, sigma=true, ballerina=true, tralalero=true,
    patapim=true, ambalabu=true, bombardiro=true, sahur=true, gigachad=true}
function Catalog.Has(species)
    local supplied=type(species)=="string" and art:FindFirstChild(species)
    return known[species]==true or (supplied and supplied:IsA("ModuleScript"))==true
end
function Catalog.Get(species)
    assert(Catalog.Has(species), "Unknown catch portrait: " .. tostring(species))
    if species == "sahur" then return require(parent:WaitForChild("SahurArtData")) end
    return require(art:WaitForChild(species))
end
return Catalog
