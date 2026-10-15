-- Actual Main/Profiles/Ledger/Quests; only NPC physics/lifecycle is isolated here.
-- The real NPC lifecycle/attack implementation is exercised by sahur_boss.luau.
local Environment=require('./helpers/server_environment')
local r=require('@lune/roblox')
local env=Environment.new()
local checks=0
local function check(v,label) checks+=1;assert(v,label) end
local node=env.server.Profiles:Clone();node.Name='SahurService';node.Parent=env.server
local states,reward={},nil
env.modules.SahurService={new=function(callback)
    reward=callback
    return {
        IsActive=function(_,player) return states[player]~=nil end,
        Start=function(_,player,token,record) states[player]={Token=token,Record=record};return true end,
        Remove=function(_,player) states[player]=nil end,
        Step=function() end,
    }
end}
env.World.Spots={Dunes={Name='Пески Сахура',Center=r.Vector3.new(0,4,0),Radius=25,Level=3}}
env.Config.IslandById.Dunes.Weights={sahur=100}
env:Start()
local player=env:Player(505);env.Players.PlayerAdded:Fire(player)
local data=env.Profiles.Get(player);data.Rod=#env.Config.Rods;data.XP=env.Config.XPPerLevel*3
local function hook()
    env:Advance(1);env.reelResult=nil
    env:Fire(player,'Begin')
    local charging=env:Last(player,'Stage')
    check(charging.Stage=='Charging','Begin allowed before encounter')
    env:Advance(.4);env:Fire(player,'Release',charging.Id)
    for _=1,35 do
        env:Advance(.5)
        if env:Last(player,'Stage').Stage=='Bite' then break end
    end
    check(env:Last(player,'Stage').Stage=='Bite','Fish reaches bite')
    env:Fire(player,'Hook',charging.Id)
    check(env:Last(player,'Stage').Stage=='Reeling','Hook enters reel')
    env.reelResult='caught';env:Advance(.1)
end
hook()
check(states[player]~=nil and states[player].Record.Species=='sahur','Sahur catch starts encounter')
check(#data.Bag==0 and not data.PendingCatch and data.TotalCaught==0,'No fish/XP reservation before victory')
check(env:Last(player,'Stage').Stage=='Idle','Fishing releases controls for combat')
env:Fire(player,'Begin')
check(env:Last(player,'Rejected').Text~=nil,'Fishing cannot overlap an encounter')
local won=states[player];states[player]=nil
reward(player,won.Record,won.Token)
check(#data.Bag==1 and data.Bag[1].Species=='sahur' and data.TotalCaught==1,'Victory grants actual inventory record')
check(env:Last(player,'Caught').Token==won.Token,'Victory uses existing catch UI event')
reward(player,won.Record,won.Token)
check(#data.Bag==1 and data.TotalCaught==1,'Duplicate victory token cannot duplicate inventory')
local progress
for _,task in data.Quests.Daily.Tasks do if task.Id=='catch_total' then progress=task.Progress end end
check(progress==1,'Quest counts victory exactly once')
hook()
check(states[player]~=nil and not data.PendingCatch,'Second encounter remains unearned')
env:Leave(player)
check(states[player]==nil,'Disconnect clears encounter')
local rejoin=env:Player(505);env.Players.PlayerAdded:Fire(rejoin)
local restored=env.Profiles.Get(rejoin)
check(#restored.Bag==1 and restored.TotalCaught==1,'Save/rejoin retains win and never awards unfinished fight')
print('PASS Sahur reward integration: '..checks..' checks')
