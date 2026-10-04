local parent=script.Parent
local art=parent:WaitForChild("CatchArtData")
local Catalog={}
function Catalog.Has(id)
    if type(id)~="string" then return false end
    local n=art:FindFirstChild(id)
    if not n and id=="sahur" then n=parent:FindFirstChild("SahurArtData") end
    return n~=nil and n:IsA("ModuleScript")
end
function Catalog.Get(id)
    assert(Catalog.Has(id),"Unknown catch portrait: "..tostring(id))
    local n=art:FindFirstChild(id)
    if not n and id=="sahur" then n=parent:FindFirstChild("SahurArtData") end
    return require(n)
end
return Catalog
