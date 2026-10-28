-- Authoritative nearby NPC conversations; no client reward/progress values are trusted.
local Service={};Service.__index=Service
local names={merchant="Мара",rodsmith="Лев",captain="Капитан Мирон"}
local roles={merchant="Рыбачка и скупщица",rodsmith="Мастер удочек",captain="Капитан лодочной верфи"}
local greetings={merchant="Привет! Море сегодня щедрое. Покажешь улов? А ещё у меня есть поручения для хорошего рыбака.",
    rodsmith="Рад тебя видеть! Хорошая удочка — половина дела. Поможешь с испытаниями снастей?",
    captain="Попутного ветра! Подберём лодку или отправимся исследовать острова? За морские поручения я плачу монетами."}
local function rootOf(player)
    local c=player.Character;local h=c and c:FindFirstChildOfClass("Humanoid")
    local r=c and c:FindFirstChild("HumanoidRootPart")
    if r and h and h.Health>0 and not h.SeatPart then return r end
end
function Service.new(options)
    return setmetatable({Options=options,Entries={},Sessions={},Connections={},NextStep=0},Service)
end
function Service:_valid(player,entry)
    if not entry or not entry.Body or not entry.Body.Parent then return false end
    local root=rootOf(player)
    return root~=nil and (root.Position-entry.Body.Position).Magnitude<=18
        and self.Options.Profiles.Get(player)~=nil and not self.Options.Busy(player)
end
function Service:Register(id,giver,body,tradeLabel,trade)
    self.Entries[id]={Id=id,Giver=giver,Name=body:GetAttribute("NPCName") or names[giver],Body=body,TradeLabel=tradeLabel,Trade=trade}
    for _,child in ipairs(body:GetChildren()) do
        if child:IsA("ProximityPrompt") and child.Name~="NPCDialoguePrompt" then child.Enabled=false end
    end
    local prompt=body:FindFirstChild("NPCDialoguePrompt")
    if not prompt then prompt=Instance.new("ProximityPrompt");prompt.Name="NPCDialoguePrompt";prompt.Parent=body end
    prompt.ActionText="Поговорить";prompt.ObjectText=self.Entries[id].Name;prompt.KeyboardKeyCode=Enum.KeyCode.E
    prompt.HoldDuration=0.15;prompt.MaxActivationDistance=12;prompt.RequiresLineOfSight=false;prompt.Enabled=true
    table.insert(self.Connections,prompt.Triggered:Connect(function(player)
        if self.Options.Allow(player,"NPCOpen",2) then self:Open(player,id) end
    end))
end
function Service:Close(player,silent)
    if not self.Sessions[player] then return end
    self.Sessions[player]=nil
    if not silent then self.Options.Send(player,"DialogueClose",{}) end
end
local function choice(id,text,enabled)return{Id=id,Text=text,Enabled=enabled~=false}end
function Service:_render(player,session,message)
    local entry=self.Entries[session.Id];local options=self.Options
    local data=options.Profiles.Get(player)
    if not self:_valid(player,entry) or not data then self:Close(player);return false end
    local snapshot=options.Quests.Snapshot(data,options.Config,options.Now(),player.UserId)
    local choices,text={},message or greetings[entry.Giver]
    if session.Page=="quests" then
        local available,ready,reward=0,0,0
        local lines={message or "Вот наши поручения. Подробности и прогресс — в журнале «Задания»."}
        for _,kind in ipairs({"Daily","Weekly"}) do
            local accepted,finished,total=0,0,0
            for _,q in ipairs(snapshot[kind].Tasks) do
                if q.Giver==entry.Giver then
                    total+=1;if not q.Accepted then available+=1 else accepted+=1 end
                    if q.Claimed then finished+=1
                    elseif q.Accepted and q.Progress>=q.Target then ready+=1;reward+=q.Reward end
                end
            end
            table.insert(lines,(kind=="Daily" and "На день" or "На неделю")..": взято "..accepted.."/"..total..", сдано "..finished..".")
        end
        reward+=(snapshot.PendingRewards and snapshot.PendingRewards[entry.Giver]) or 0
        table.insert(lines,"Новые дневные поручения — после 00:00 UTC; недельные — в понедельник.")
        if reward>0 then table.insert(lines,"К выдаче: "..reward.." монет.") end
        text=table.concat(lines,"\n")
        choices={choice("accept","Взять новые поручения",available>0),
            choice("claim","Сдать выполненное · +"..reward.." монет",reward>0 or ready>0),
            choice("back","О другом"),choice("close","До встречи!")}
    else choices={choice("trade",entry.TradeLabel),choice("quests","Поручения и награды"),choice("close","До встречи!")} end
    session.Expires=options.Now()+60
    options.Send(player,"Dialogue",{Id=entry.Id,Session=session.Nonce,Name=entry.Name,Role=roles[entry.Giver],
        Text=text,Choices=choices,Giver=entry.Giver})
    return true
end
function Service:Open(player,id)
    if not self:_valid(player,self.Entries[id]) then return false end
    local session={Id=id,Nonce=self.Options.Token(),Page="hello"};self.Sessions[player]=session
    return self:_render(player,session)
end
function Service:Request(player,id,payload)
    if type(id)~="string" or #id>64 or type(payload)~="table" or type(payload.Session)~="string"
        or #payload.Session>80 or type(payload.Choice)~="string" or #payload.Choice>20 then return false end
    local session=self.Sessions[player]
    if not session or session.Id~=id or session.Nonce~=payload.Session then return false end
    local entry=self.Entries[id];local options=self.Options
    if not self:_valid(player,entry) or options.Now()>session.Expires then self:Close(player);return false end
    local action=payload.Choice
    if action=="close" then self:Close(player);return true end
    if action=="back" then session.Page="hello";return self:_render(player,session) end
    if action=="quests" then session.Page="quests";return self:_render(player,session) end
    if action=="trade" and session.Page=="hello" then self:Close(player);entry.Trade(player,entry);return true end
    if session.Page~="quests" then return false end
    local data=options.Profiles.Get(player);local message
    if action=="accept" then
        local count=options.Quests.AcceptFrom(data,options.Config,entry.Giver,options.Now(),player.UserId)
        message=count>0 and "Договорились! Поручения записаны в журнал. Возвращайся с результатами."
            or "На этот период ты уже получил все мои поручения. Продолжай начатое!"
    elseif action=="claim" then
        local ok,reason,reward=options.Quests.ClaimFrom(data,options.Config,entry.Giver,options.Now(),player.UserId)
        message=ok and "Отличная работа! Держи "..reward.." монет. Награда уже в кошельке."
            or (reason=="balance_full" and "В кошельке нет места. Награда сохранена, заберёшь позже."
            or "Пока нечего сдавать. Возвращайся, когда выполнишь поручение.")
    else return false end
    options.Sync(player);return self:_render(player,session,message)
end
function Service:Step()
    local now=self.Options.Now();if now<self.NextStep then return end;self.NextStep=now+0.5
    for player,s in pairs(self.Sessions) do
        if now>s.Expires or not self:_valid(player,self.Entries[s.Id]) then self:Close(player) end
    end
end
function Service:Destroy()
    for _,c in ipairs(self.Connections) do c:Disconnect() end
    for player in pairs(self.Sessions) do self:Close(player) end
    table.clear(self.Connections)
end
return Service
