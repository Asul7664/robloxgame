-- Real Main/Profiles/Quests/NPCDialogueService, with transport/world engine doubles.
local Environment=require("./helpers/server_environment")
local R=require("@lune/roblox")
local checks=0
local function check(value,message)checks+=1;assert(value,message)end
local function task(data,kind,id)
    for _,entry in ipairs(data.Quests[kind].Tasks)do if entry.Id==id then return entry end end
    error("Missing objective "..id)
end
local function make(id)
    local env=Environment.new();env:Start()
    local player=env:Player(id);env.Players.PlayerAdded:Fire(player)
    return env,player,env.Profiles.Get(player)
end
local function messages(env,player,kind)
    local count=0
    for _,entry in ipairs(env.messages)do if entry.Player==player and entry.Kind==kind then count+=1 end end
    return count
end
local function request(env,player,dialogue,choice,id,nonce)
    env:Advance(.25)
    env:Fire(player,"NPCChoice",id or dialogue.Id,{Session=nonce or dialogue.Session,Choice=choice})
end

do
    local env,p,data=make(701)
    check(not task(data,"Daily","catch_total").Accepted,"Joining alone does not accept NPC work")
    check(env.World.Merchant.MerchantPrompt.Enabled==false,"Old sell action is replaced by conversation")
    check(env.World.Shop.RodsmithPrompt.Enabled==false,"Old rod shop action is replaced by conversation")
    check(env.World.Docks.Cove.Captain.CaptainPrompt.Enabled==false,"Old captain action is replaced by conversation")
    check(env.World.Merchant.NPCDialoguePrompt.ActionText=="Поговорить","Prompt clearly offers a conversation")
    data.Bag={{Species="capybara",Kg=1,Mutation="normal",Value=42}}
    local dialogue=env:Talk(p,env.World.Merchant)
    check(dialogue.Name=="Мара" and dialogue.Giver=="merchant","Merchant identity is supplied by the server")
    check(type(dialogue.Session)=="string" and #dialogue.Session>0,"Conversation has a server-created nonce")
    request(env,p,dialogue,"trade")
    check(data.Coins==42 and #data.Bag==0,"Merchant trade runs the existing sell function")
    check(env:Last(p,"DialogueClose")~=nil,"Trade closes dialogue before opening its destination")
    data.Bag={{Species="capybara",Kg=1,Mutation="normal",Value=42}}
    request(env,p,dialogue,"trade")
    check(data.Coins==42 and #data.Bag==1,"Closed conversation cannot replay a sale")
    env:Advance(1)
    env:Talk(p,env.World.Shop,"trade")
    check(env:Last(p,"Shop")~=nil,"Rodsmith conversation opens the existing rod shop")
    env:Advance(1)
    env:Talk(p,env.World.Docks.Cove.Captain,"trade")
    check(env:Last(p,"BoatShop").Dock=="Cove","Captain conversation opens the correct existing boat shop")
end

do
    local env,p,data=make(702)
    local dialogue=env:Talk(p,env.World.Merchant,"quests")
    check(dialogue.Text:find("На день",1,true) and dialogue.Text:find("На неделю",1,true),"Quest conversation explains both periods")
    request(env,p,dialogue,"accept")
    check(task(data,"Daily","catch_total").Accepted and task(data,"Weekly","species_1").Accepted,"Merchant accepts both periods of her work")
    check(not task(data,"Daily","fishing_time").Accepted,"Merchant cannot accept the rodsmith's work")
    check(not task(data,"Daily","island_catch").Accepted,"Merchant cannot accept the captain's work")
    local done=task(data,"Daily","catch_total");done.Progress=done.Target
    local expected=done.Reward
    local id=data.Quests.Daily.Key..":catch_total"
    env:Fire(p,"QuestClaim","Daily",id)
    check(data.Coins==0,"Legacy reward remote cannot bypass conversation requirements")
    request(env,p,dialogue,"claim",nil,"forged-nonce")
    check(data.Coins==0,"Forged conversation nonce cannot pay")
    request(env,p,dialogue,"claim","rodsmith")
    check(data.Coins==0,"Nonce from another NPC cannot authorize a reward")
    request(env,p,dialogue,"claim")
    check(data.Coins==expected and task(data,"Daily","catch_total").Claimed,"Correct nearby owner pays exactly the authoritative reward")
    request(env,p,dialogue,"claim")
    check(data.Coins==expected,"Repeated reward clicks cannot pay twice")
    local dailyKey=data.Quests.Daily.Key
    request(env,p,dialogue,"accept")
    check(data.Quests.Daily.Key==dailyKey and task(data,"Daily","catch_total").Claimed,"Finishing tasks does not reroll another same-day set")
    env:Leave(p)
    local rejoin=env:Player(702);env.Players.PlayerAdded:Fire(rejoin)
    local restored=env.Profiles.Get(rejoin)
    request(env,rejoin,dialogue,"claim")
    check(restored.Coins==expected,"Old player's conversation cannot be reused after rejoin")
    env:Talk(rejoin,env.World.Merchant,"quests");env:Choose(rejoin,"claim")
    check(restored.Coins==expected and task(restored,"Daily","catch_total").Claimed,"Saved paid marker survives real profile reload")
end

do
    local env,p,data=make(703)
    env:Talk(p,env.World.Merchant,"quests");env:Choose(p,"accept")
    local done=task(data,"Daily","catch_total");done.Progress=done.Target
    local expected=done.Reward
    env.clock+=86400;env.RunService.Heartbeat:Fire(1/60)
    check(not task(data,"Daily","catch_total").Accepted,"UTC rollover produces unaccepted work")
    check(data.Quests.PendingRewards.merchant==expected,"Completed unpaid work survives server-side rollover")
    local dialogue=env:Talk(p,env.World.Merchant,"quests")
    request(env,p,dialogue,"claim")
    check(data.Coins==expected and data.Quests.PendingRewards.merchant==0,"NPC pays retained expired rewards once")
    request(env,p,dialogue,"claim")
    check(data.Coins==expected,"Expired reward cannot be replayed")
end

do
    local env,p,data=make(704)
    local root=p.Character.HumanoidRootPart
    local function cannotOpen(change,restore,label)
        env:Advance(1.1);change()
        local before=messages(env,p,"Dialogue")
        env.World.Merchant.NPCDialoguePrompt.Triggered:Fire(p)
        check(messages(env,p,"Dialogue")==before,label)
        restore()
    end
    cannotOpen(function()root.Position=R.Vector3.new(100,4,0)end,function()root.Position=R.Vector3.new(0,4,0)end,"Far player cannot open NPC dialogue")
    cannotOpen(function()p.Character.Humanoid.Health=0 end,function()p.Character.Humanoid.Health=100 end,"Dead player cannot open NPC dialogue")
    cannotOpen(function()p.Character.Humanoid.SeatPart={} end,function()p.Character.Humanoid.SeatPart=nil end,"Seated player cannot open NPC dialogue")
    local dialogue=env:Talk(p,env.World.Merchant,"quests")
    root.Position=R.Vector3.new(100,4,0)
    request(env,p,dialogue,"accept")
    check(not task(data,"Daily","catch_total").Accepted,"Walking away prevents acceptance using a retained nonce")
    check(env:Last(p,"DialogueClose")~=nil,"Invalid proximity closes the conversation")
    root.Position=R.Vector3.new(0,4,0);env:Advance(1)
    dialogue=env:Talk(p,env.World.Merchant,"quests")
    env.clock+=61
    env:Fire(p,"NPCChoice",dialogue.Id,{Session=dialogue.Session,Choice="accept"})
    check(not task(data,"Daily","catch_total").Accepted,"Expired nonce cannot accept assignments")
    env:Advance(1)
    dialogue=env:Talk(p,env.World.Merchant,"quests")
    env:Reset(p)
    request(env,p,dialogue,"accept")
    check(not task(data,"Daily","catch_total").Accepted,"Respawn invalidates an earlier NPC conversation")
end

do
    local env,p,data=make(705)
    local dialogue=env:Talk(p,env.World.Merchant,"quests")
    env:Fire(p,"Begin");env:Advance(.2)
    check(env:Last(p,"Stage").Stage=="Charging","Fishing starts through the real server entrypoint")
    local before=messages(env,p,"Dialogue")
    env.World.Merchant.NPCDialoguePrompt.Triggered:Fire(p)
    check(messages(env,p,"Dialogue")==before,"Busy fishing player cannot open NPC dialogue")
    request(env,p,dialogue,"accept")
    check(not task(data,"Daily","catch_total").Accepted,"Busy player cannot reuse an earlier nonce")
    check(task(data,"Daily","fishing_time").Progress==0,"Unaccepted active fishing never counts toward a task")
end

do
    local env=Environment.new();local dodging=false
    env.modules.DodgeService={new=function()return{IsActive=function()return dodging end,Step=function()end,
        Remove=function()end,Request=function()end}end}
    env:Start();local p=env:Player(706);env.Players.PlayerAdded:Fire(p)
    local dialogue=env:Talk(p,env.World.Merchant,"quests")
    dodging=true
    request(env,p,dialogue,"accept")
    check(not task(env.Profiles.Get(p),"Daily","catch_total").Accepted,"Dodge busy state is enforced by the server conversation")
end

do
    local env,p,data=make(707)
    local dialogue=env:Talk(p,env.World.Merchant,"quests")
    for _,payload in ipairs({false,123,"claim",{}, {Session=dialogue.Session,Choice=123},
        {Session=string.rep("x",81),Choice="claim"}, {Session=dialogue.Session,Choice=string.rep("x",21)}})do
        env:Advance(.25)
        local ok=pcall(function()env:Fire(p,"NPCChoice",dialogue.Id,payload)end)
        check(ok and data.Coins==0,"Malformed dialogue payload cannot throw or pay")
    end
    env:Advance(.25)
    env:Fire(p,"NPCChoice",{}, {Session=dialogue.Session,Choice="claim"})
    check(data.Coins==0,"Malformed NPC identity cannot authorize payout")
    request(env,p,dialogue,"accept")
    check(task(data,"Daily","catch_total").Accepted,"Valid session remains usable after malformed traffic")
end

print("PASS NPC dialogue server: "..checks.." checks (real Main/Profiles/Quests/DialogueService)")
