-- The visible shop displays are the authoritative geometry for equipped Tools.
-- Rebuild around the handle instead of carrying the display's world position
-- or its anchored physics into the player's character.
local Models = {}
local function parts(display)
    local result={}
    for _, object in ipairs(display:GetChildren()) do
        if object:IsA("BasePart") then table.insert(result,object) end
    end
    local handle=display:FindFirstChild("Handle")
    table.sort(result,function(a,b)
        if a.Name~=b.Name then return a.Name<b.Name end
        -- The musket has two StockInlay parts with the same name.
        local ap=handle.CFrame:ToObjectSpace(a.CFrame).Position
        local bp=handle.CFrame:ToObjectSpace(b.CFrame).Position
        if ap.X~=bp.X then return ap.X<bp.X end
        if ap.Y~=bp.Y then return ap.Y<bp.Y end
        return ap.Z<bp.Z
    end)
    return result
end
function Models.Key(display,id)
    local handle=assert(display:FindFirstChild("Handle"),"Weapon display needs Handle")
    local tokens={"display-weapon-v1",id}
    local function numbers(...)
        for _,n in ipairs({...}) do
            -- Normalize tiny world-to-local floating point differences.
            local value=math.floor(n*10000+.5)
            table.insert(tokens,tostring(value==0 and 0 or value))
        end
    end
    for _,part in ipairs(parts(display)) do
        table.insert(tokens,part.ClassName);table.insert(tokens,part.Name)
        table.insert(tokens,tostring(part.Material))
        table.insert(tokens,part:IsA("Part") and tostring(part.Shape) or "")
        numbers(part.Size.X,part.Size.Y,part.Size.Z,part.Color.R,part.Color.G,part.Color.B,
            part.Transparency,part.Reflectance,handle.CFrame:ToObjectSpace(part.CFrame):GetComponents())
        local attachments={}
        for _, child in ipairs(part:GetChildren()) do
            if child:IsA("Attachment") then table.insert(attachments,child) end
        end
        table.sort(attachments,function(a,b)return a.Name<b.Name end)
        for _,attachment in ipairs(attachments) do
            table.insert(tokens,attachment.Name);numbers(attachment.CFrame:GetComponents())
        end
    end
    -- Bounded integer arithmetic remains exact in Lua numbers; this is a
    -- model revision tag, not a security or cryptographic hash.
    local hash=5381
    for _,token in ipairs(tokens) do
        for index=1,#token do hash=(hash*33+string.byte(token,index))%4294967296 end
        hash=(hash*33+124)%4294967296
    end
    return string.format("display-%08x",hash)
end
function Models.Build(display,id)
    local displayHandle=assert(display:FindFirstChild("Handle"),"Weapon display needs Handle")
    assert(displayHandle:IsA("BasePart"),"Weapon display Handle must be a BasePart")
    local tool=Instance.new("Tool")
    tool.Name=id;tool.RequiresHandle=true;tool.CanBeDropped=false
    tool:SetAttribute("WeaponType",id)
    tool:SetAttribute("WeaponModelKey",Models.Key(display,id))
    tool.Grip=CFrame.new(0,.02,0)*CFrame.Angles(math.pi*.5,0,0)
    tool.ToolTip=(id=="Saber" and "Сабля" or "Мушкет").." · ЛКМ — атака"
    for _,part in ipairs(parts(display)) do
        local copy=assert(part:Clone(),"Weapon display part must be archivable")
        for _,child in ipairs(copy:GetDescendants()) do
            if child:IsA("JointInstance") or child:IsA("WeldConstraint")
                or child:IsA("Constraint") or child:IsA("LuaSourceContainer") then child:Destroy() end
        end
        copy.CFrame=displayHandle.CFrame:ToObjectSpace(part.CFrame)
        copy.Anchored=false;copy.Massless=true
        copy.CanCollide=false;copy.CanTouch=false;copy.CanQuery=false
        copy.Parent=tool
    end
    local handle=assert(tool:FindFirstChild("Handle"))
    for _,part in ipairs(tool:GetChildren()) do
        if part:IsA("BasePart") and part~=handle then
            local weld=Instance.new("WeldConstraint")
            weld.Name="HandleWeld";weld.Part0=handle;weld.Part1=part;weld.Parent=part
        end
    end
    return tool
end
function Models.Sync(bank,displays)
    local keys={}
    for _,id in ipairs({"Saber","Musket"}) do
        local display=assert(displays:FindFirstChild(id.."Display"),"Missing weapon display: "..id)
        local key=Models.Key(display,id);keys[id]=key
        local current=bank:FindFirstChild(id)
        if not current or not current:IsA("Tool") or current:GetAttribute("WeaponModelKey")~=key then
            local replacement=Models.Build(display,id)
            if current then current:Destroy() end
            replacement.Parent=bank
        end
    end
    return keys
end
return Models
