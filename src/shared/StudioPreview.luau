-- Explicit Command Bar endpoints work across require caches/VMs.
-- Server Studio commands only send presentation requests to a selected client.
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local shared=script.Parent
local Preview={}
local actions={Catch=true,World=true,Portrait=true,All=true,Stop=true,Rod=true}
local mutations={normal=true,gold=true,glow=true}

local function studio()
    assert(RunService:IsStudio(),"Просмотр доступен только в Roblox Studio.")
end
local function config()return require(shared:WaitForChild("Config"))end

function Preview.Attach(context)
    studio()
    assert(RunService:IsClient(),"Preview.Attach must run on the game client")
    local core=require(shared:WaitForChild("StudioPreviewClient"))
    core.Attach(context)
    local scripts=Players.LocalPlayer:WaitForChild("PlayerScripts")
    local old=scripts:FindFirstChild("QuietCoveStudioPreview")
    if old then old:Destroy()end
    local endpoint=Instance.new("BindableFunction")
    endpoint.Name="QuietCoveStudioPreview"
    endpoint.OnInvoke=function(action,...)
        assert(actions[action],"Unknown Studio preview command")
        return core[action](core,...)
    end
    endpoint.Parent=scripts
    local connection=shared:WaitForChild("StudioPreviewCommand").OnClientEvent:Connect(function(action,...)
        if not actions[action]then return end
        local ok,result=pcall(endpoint.Invoke,endpoint,action,...)
        if not ok then warn("[QuietCove preview] "..tostring(result))end
    end)
    context.Gui.Destroying:Connect(function()connection:Disconnect();endpoint:Destroy()end)
end

local function dispatch(action,args,playerName)
    studio()
    assert(RunService:IsRunning(),"Сначала нажми Play. Команды показывают анимацию в запущенной игре.")
    if RunService:IsClient()then
        local localPlayer=assert(Players.LocalPlayer,"Клиент ещё загружается")
        local scripts=localPlayer:WaitForChild("PlayerScripts")
        local endpoint=scripts:WaitForChild("QuietCoveStudioPreview",10)
        assert(endpoint,"Клиент Quiet Cove не загрузился. Проверь ошибки в Output и повтори Play.")
        return endpoint:Invoke(action,table.unpack(args,1,args.n))
    end
    local list=Players:GetPlayers()
    local target
    if playerName then target=Players:FindFirstChild(playerName)
    elseif #list==1 then target=list[1]
    else error("Укажи имя игрока последним аргументом команды; в тесте несколько игроков.")end
    assert(target,"В тесте ещё нет игрока. Нажми Play и дождись появления персонажа.")
    shared:WaitForChild("StudioPreviewCommand"):FireClient(target,action,table.unpack(args,1,args.n))
    return true
end

local function species(id,mutation)
    studio()
    assert(type(id)=="string" and config().ById[id],"Неизвестный ID рыбы. Список: :List()")
    mutation=mutation or "normal"
    assert(mutations[mutation],"Мутация: normal, gold или glow")
    return mutation
end
function Preview:List()
    studio()
    local c=config();local ids={}
    for _,fish in ipairs(c.Fish)do
        ids[#ids+1]=fish.Id
        print(fish.Id.." — "..fish.Name.." — "..c.Rarities[fish.Rarity].Name)
    end
    return ids
end
function Preview:Catch(id,mutation,playerName)
    return dispatch("Catch",table.pack(id,species(id,mutation)),playerName)
end
function Preview:World(id,mutation,playerName)
    return dispatch("World",table.pack(id,species(id,mutation)),playerName)
end
function Preview:Portrait(id,mutation,playerName)
    return dispatch("Portrait",table.pack(id,species(id,mutation)),playerName)
end
function Preview:All(mode,mutation,playerName)
    mode=mode or "catch";mutation=mutation or "normal"
    assert(mode=="catch" or mode=="world" or mode=="portrait","Режим: catch, world или portrait")
    assert(mutations[mutation],"Мутация: normal, gold или glow")
    return dispatch("All",table.pack(mode,mutation),playerName)
end
function Preview:Rod(stage,seconds,playerName)
    return dispatch("Rod",table.pack(stage or "Waiting",seconds or 6),playerName)
end
function Preview:Stop(playerName)return dispatch("Stop",table.pack(),playerName)end
return Preview
