-- Real Main lifecycle/Heartbeat + hazard service + generated shark. Geometry
-- probes and Humanoid physics are service doubles; verify those in Studio.
local Environment=require('./helpers/server_environment')
local env=Environment.new();env:Start()
local checks=0
local function check(ok,message)checks+=1;assert(ok,message)end
local player=env:Player(801);env.Players.PlayerAdded:Fire(player)
local data=env.Profiles.Get(player)
local coins,xp,caught=data.Coins,data.XP,#data.Bag
local function swim()
    local h=player.Character.Humanoid
    h.State='Swimming';h.FloorMaterial='Air';return h
end
local h=swim()
env:Advance(29.8)
check(h.Health==100,'Main leaves swimmer alive below thirty seconds')
local warning=env:Last(player,'Notice')
check(warning and warning.Text:find('До акулы')~=nil,'Existing Notice UI receives the warning')
env:Advance(.4)
check(h.Health==0 and player.Character:GetAttribute('QCDeathCause')=='Shark','Main runs the server hazard and instant death')
local folder=env.Workspace:FindFirstChild('QuietCoveWaterHazards')
local shark=folder and folder:FindFirstChild('OceanShark')
check(shark and shark.PrimaryPart and shark:GetAttribute('QCSharkRevision')==2,'Main spawns the updated asset-free shark')
check(data.Coins==coins and data.XP==xp and #data.Bag==caught,'Environmental death grants no catch, XP or money')
env:Reset(player)
check(shark.Destroyed,'CharacterAdded removes the previous life shark')
h=swim();env:Advance(15)
check(h.Health==100,'Respawn starts a new water episode')
env:Reset(player);h=swim();env:Advance(29.8)
check(h.Health==100,'A partial previous life water timer does not carry across respawn')
env:Advance(.4)
check(h.Health==0,'The new life still expires after a full thirty seconds')
shark=folder:FindFirstChild('OceanShark')
env:Leave(player)
check(shark.Destroyed,'PlayerRemoving immediately cleans the active shark')
env:Advance(5)
check(#folder:GetChildren()==0,'No shark remains after leaving')
print('PASS water hazard Main integration: '..checks..' checks (Heartbeat, notices, generated shark, respawn and logout)')
