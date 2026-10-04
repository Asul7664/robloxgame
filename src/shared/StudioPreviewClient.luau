-- Client-only Studio presentation controls. Never award catches or send remotes.
local RunService = game:GetService("RunService")
local Preview = {}
local context
local serial = 0
local mutations = {normal = true, gold = true, glow = true}

local function client()
    assert(RunService:IsStudio(), "StudioPreview is available only in Roblox Studio.")
    assert(RunService:IsRunning() and RunService:IsClient(),
        "Start Play, select Client, then run the command in Command Bar.")
    assert(context and context.Alive(), "Quiet Cove client is still loading. Try again shortly.")
    return context
end

local function validate(species, mutation)
    local c = client()
    assert(type(species) == "string" and c.Config.ById[species], "Unknown species. Run :List() for IDs.")
    mutation = mutation or "normal"
    assert(mutations[mutation], "Mutation must be normal, gold, or glow.")
    return c, mutation
end

function Preview.Attach(value)
    if RunService:IsStudio() and RunService:IsClient() then context = value end
end

function Preview:List()
    local rows = {}
    local c = client()
    for _, fish in ipairs(c.Config.Fish) do
        rows[#rows + 1] = fish.Id
        print(fish.Id .. " — " .. fish.Name .. " — " .. c.Config.Rarities[fish.Rarity].Name)
    end
    return rows
end

function Preview:World(species, mutation)
    local c, variant = validate(species, mutation)
    assert(c.CanPreview(), "Finish fishing and close the bag/shop before previewing.")
    serial += 1
    c.HidePortrait()
    return c.World(species, variant)
end

function Preview:Portrait(species, mutation)
    local c, variant = validate(species, mutation)
    assert(c.CanPreview(), "Finish fishing and close the bag/shop before previewing.")
    serial += 1
    c.Portrait(species, variant)
    return true
end

local function catch(c, species, mutation, token)
    if not c.CanPreview() then return false end
    c.HidePortrait()
    if not c.World(species, mutation) then return false end
    assert(type(c.WorldPlaying)=="function", "Quiet Cove preview context is outdated. Restart Play after syncing.")
    local waiting={Done=false,Shown=false}
    local connection
    connection=RunService.RenderStepped:Connect(function()
        if serial~=token or context~=c or not c.Alive() then
            waiting.Done=true;connection:Disconnect();return
        end
        if c.WorldPlaying() then return end
        waiting.Done=true;connection:Disconnect()
        if c.CanPreview() then
            waiting.Shown=true;c.Portrait(species,mutation)
        end
    end)
    return true,waiting
end

function Preview:Catch(species, mutation)
    local c, variant = validate(species, mutation)
    assert(c.CanPreview(), "Finish fishing and close the bag/shop before previewing.")
    serial += 1
    return catch(c, species, variant, serial)
end

function Preview:All(mode, mutation)
    local c = client()
    mode = mode or "catch"
    mutation = mutation or "normal"
    assert(mode == "catch" or mode == "world" or mode == "portrait", "Mode must be catch, world, or portrait.")
    assert(mutations[mutation], "Mutation must be normal, gold, or glow.")
    assert(c.CanPreview(), "Finish fishing and close the bag/shop before previewing.")
    serial += 1
    local token = serial
    task.spawn(function()
        for _, fish in ipairs(c.Config.Fish) do
            if serial ~= token or not c.Alive() or not c.CanPreview() then return end
            print("[QuietCove preview] " .. fish.Id .. " — " .. fish.Name)
            local duration = c.Config.Landing.DurationByRarity[fish.Rarity]
            if mode == "catch" then
                local accepted,waiting=catch(c, fish.Id, mutation, token)
                if not accepted then return end
                while serial==token and c.Alive() and not waiting.Done do task.wait(.03) end
                if serial~=token or not c.Alive() or not waiting.Shown then return end
                task.wait(5.0)
            elseif mode == "world" then
                c.HidePortrait()
                if not c.World(fish.Id, mutation) then return end
                task.wait(duration + .25)
            else
                c.Portrait(fish.Id, mutation)
                task.wait(5.0)
            end
        end
    end)
    return true
end

function Preview:Stop()
    local c = client()
    serial += 1
    c.ClearPreviews()
    c.HidePortrait()
end

function Preview:Rod(stage,seconds)
    local c=client()
    assert(c.CanPreview(),"Finish fishing and close the bag/shop before previewing.")
    serial+=1
    return c.Rod(stage or "Waiting",seconds or 6)
end
return Preview
