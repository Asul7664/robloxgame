-- One server-authoritative encounter per fisher. No imported code runs.
local Players = game:GetService('Players')
local ServerStorage = game:GetService('ServerStorage')
local RS = game:GetService('ReplicatedStorage')
local CollectionService = game:GetService('CollectionService')
local PathfindingService = game:GetService('PathfindingService')
local settings = require(RS:WaitForChild('QuietCove'):WaitForChild('SahurBossSettings'))
local Damage = require(RS:WaitForChild('Combat'):WaitForChild('Damage'))
local Service = {}
Service.__index = Service
local function placeRoot(model,root,frame)
    -- Imported rigs can have a foot-level PrimaryPart pivot. PivotTo expects
    -- that pivot frame, while emergence coordinates describe the root center.
    model:PivotTo(frame*root.PivotOffset)
end
local function living(player)
    local character = player.Character
    local root = character and character:FindFirstChild('HumanoidRootPart')
    local humanoid = character and character:FindFirstChildOfClass('Humanoid')
    if root and humanoid and humanoid.Health > 0 then return root, humanoid end
end
local function horizontal(vector)
    return Vector3.new(vector.X,0,vector.Z)
end
local function facing(position,target,fallback)
    local direction=horizontal(target-position)
    return CFrame.lookAt(position,position+(direction.Magnitude>.01 and direction.Unit or fallback))
end
local function landingPoint(island,footHeight)
    local archipelago=workspace:FindFirstChild('QuietCoveArchipelago')
    local model=archipelago and archipelago:FindFirstChild(island.Id)
    if not model then return nil end
    local floors={}
    for _,name in {'Shore','Plateau','IslandPath'} do
        local part=model:FindFirstChild(name)
        if part and part:IsA('BasePart') and part.CanCollide then table.insert(floors,part) end
    end
    if #floors==0 then return nil end
    local x,z=island.X,island.Z-island.Radius*settings.LandingInset
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances=floors;params.RespectCanCollide=true
    local ground=workspace:Raycast(Vector3.new(x,80,z),Vector3.new(0,-120,0),params)
    if not ground or ground.Material==Enum.Material.Water or ground.Normal.Y<.65 then return nil end
    return ground.Position+Vector3.new(0,footHeight+.05,0)
end
local function groundParams(s)
    local ignored={s.Model}
    local encounters=workspace:FindFirstChild('SahurEncounters')
    if encounters then table.insert(ignored,encounters) end
    for _,player in Players:GetPlayers() do
        if player.Character then table.insert(ignored,player.Character) end
    end
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances=ignored;params.RespectCanCollide=true
    return params
end
local function walkable(s,goal,params)
    local travel=horizontal(goal-s.Root.Position)
    if travel.Magnitude<.01 then return false end
    local ahead=s.Root.Position+travel.Unit*math.min(4,travel.Magnitude)
    local ground=workspace:Raycast(ahead+Vector3.new(0,4,0),
        Vector3.new(0,-(s.FootHeight+4+settings.MaxDropHeight+1),0),params)
    if not ground or ground.Material==Enum.Material.Water or ground.Normal.Y<.6 then return false end
    local feet=s.Root.Position.Y-s.FootHeight
    return ground.Position.Y-feet<=settings.MaxStepHeight
        and feet-ground.Position.Y<=settings.MaxDropHeight
end
function Service.new(reward, notice)
    return setmetatable({States={}, Reward=reward, Notice=notice}, Service)
end
function Service:IsActive(player) return self.States[player] ~= nil end
function Service:Remove(player, reason)
    local s = self.States[player]
    if not s then return end
    self.States[player] = nil
    if s.Died then s.Died:Disconnect() end
    CollectionService:RemoveTag(s.Model, 'QCSahurBoss')
    s.Model:Destroy()
    if reason then self.Notice(player, reason) end
end
local function healthBar(model, humanoid)
    local gui = Instance.new('BillboardGui')
    gui.Name='SahurHealth'; gui.Size=UDim2.fromOffset(240,45)
    gui.StudsOffset=Vector3.new(0,2.5,0); gui.MaxDistance=130
    gui.Adornee=model:FindFirstChild('Head') or model.PrimaryPart; gui.Parent=model
    local label=Instance.new('TextLabel');label.Size=UDim2.fromScale(1,.55)
    label.BackgroundTransparency=1;label.TextColor3=Color3.fromRGB(255,226,165)
    label.TextStrokeTransparency=.3;label.Font=Enum.Font.GothamBold;label.TextSize=15;label.Parent=gui
    local back=Instance.new('Frame');back.Position=UDim2.fromScale(.05,.65)
    back.Size=UDim2.fromScale(.9,.2);back.BackgroundColor3=Color3.fromRGB(45,28,24);back.BorderSizePixel=0;back.Parent=gui
    local fill=Instance.new('Frame');fill.Size=UDim2.fromScale(1,1)
    fill.BackgroundColor3=Color3.fromRGB(224,81,52);fill.BorderSizePixel=0;fill.Parent=back
    return function()
        fill.Size=UDim2.fromScale(math.clamp(humanoid.Health/humanoid.MaxHealth,0,1),1)
        label.Text=('ТУН ТУН САХУР · %d / %d'):format(math.ceil(humanoid.Health),humanoid.MaxHealth)
    end
end
function Service:Start(player, token, record, zone, island)
    if self:IsActive(player) then return false,'Бой с Сахуром уже идёт.' end
    local template=ServerStorage:FindFirstChild('SahurBoss')
    local target=living(player)
    if not template then return false,'Не установлена модель ServerStorage.SahurBoss.' end
    if not template:IsA('Model') then return false,'ServerStorage.SahurBoss должен быть моделью.' end
    if not target then return false,'Персонаж не готов или погиб.' end
    if not island then return false,'Не найдены Пески Сахура.' end
    local model=template:Clone()
    local root=model:FindFirstChild('HumanoidRootPart')
    local humanoid=model:FindFirstChildOfClass('Humanoid')
    if not root or not root:IsA('BasePart') or not humanoid then
        model:Destroy();return false,'В модели Сахура не найдены HumanoidRootPart и Humanoid.'
    end
    -- Defense in depth for a template accidentally replaced with an unclean copy.
    for _,item in model:GetDescendants() do
        if item:IsA('LuaSourceContainer') then item:Destroy()
        elseif item:IsA('BasePart') then
            item.Anchored=false;item.CanTouch=false;item.Massless=item~=root
            item.CanCollide=item==root;item.CanQuery=true
        end
    end
    model.Name='Sahur_'..player.UserId;model.PrimaryPart=root
    model:SetAttribute('QCSahurOwner',player.UserId)
    model:SetAttribute('SahurEmerging',true)
    humanoid.MaxHealth=settings.Health;humanoid.Health=settings.Health
    humanoid.WalkSpeed=0;humanoid.BreakJointsOnDeath=false;humanoid.AutoRotate=true
    humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming,false)
    -- The sole leap is the scripted spawn arc. Ground AI cannot jump or climb.
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing,false)
    humanoid.AutoJumpEnabled=false;humanoid.JumpPower=0;humanoid.JumpHeight=0;humanoid.Jump=false
    humanoid.MaxSlopeAngle=50
    root.Anchored=true
    local footHeight=humanoid.HipHeight+root.Size.Y/2
    -- Land on the island's central ground lane, clear of temple/trees/pier.
    local destination=landingPoint(island,footHeight)
    if not destination then model:Destroy();return false,'Не найдено безопасное место на суше Песков Сахура.' end
    local origin=Vector3.new(zone.Center.X,-footHeight-3,zone.Center.Z-17)
    local folder=workspace:FindFirstChild('SahurEncounters')
    if not folder then folder=Instance.new('Folder');folder.Name='SahurEncounters';folder.Parent=workspace end
    local started=workspace:GetServerTimeNow()
    model:SetAttribute('SahurSpawnAt',started)
    placeRoot(model,root,facing(origin,destination,Vector3.new(0,0,1)))
    model.Parent=folder
    CollectionService:AddTag(model,'QCSahurBoss')
    local s={Model=model,Root=root,Humanoid=humanoid,Character=player.Character,Token=token,Record=record,
        At=started,Origin=origin,Destination=destination,Home=destination,FootHeight=footHeight,Landed=false,
        NextAttack=0,ThinkAt=0,NextPath=0,PathIndex=1,Path={},UpdatingPath=false,Won=false,
        LastProgressAt=started,LastProgressPosition=destination,FollowPath=false}
    s.UpdateBar=healthBar(model,humanoid);s.UpdateBar()
    self.States[player]=s
    s.Died=humanoid.Died:Connect(function()
        if self.States[player]~=s or s.Won then return end
        local current=living(player)
        if not current or player.Character~=s.Character then self:Remove(player);return end
        s.Won=true
        -- Remove first: duplicate death/late callbacks can never award twice.
        self.States[player]=nil;s.Died:Disconnect()
        CollectionService:RemoveTag(model,'QCSahurBoss')
        self.Reward(player,record,token)
        task.delay(2,function() model:Destroy() end)
    end)
    self.Notice(player,'Сахур выходит из воды! Возьми саблю или мушкет. Уклоняйся от замаха.')
    return true
end
function Service:_path(player,s,target,now)
    if s.UpdatingPath or now<s.NextPath then return end
    s.NextPath=now+1.1;s.UpdatingPath=true
    task.spawn(function()
        local radius=math.max(s.Root.Size.X,s.Root.Size.Z)/2+.3
        local path=PathfindingService:CreatePath({AgentRadius=radius,AgentHeight=13,
            AgentCanJump=false,AgentCanClimb=false,WaypointSpacing=5})
        local origin=s.Root.Position-Vector3.new(0,s.FootHeight-.25,0)
        local ok=pcall(function() path:ComputeAsync(origin,target) end)
        if self.States[player]~=s then return end
        s.UpdatingPath=false
        if ok and path.Status==Enum.PathStatus.Success then
            local waypoints=path:GetWaypoints()
            for _,point in waypoints do
                if point.Action==Enum.PathWaypointAction.Jump then s.Path={};return end
            end
            s.Path=waypoints;s.PathIndex=math.min(2,#s.Path)
        else s.Path={} end
    end)
end
function Service:_chase(player,s,target,visible,now)
    local flat=horizontal(target.Position-s.Root.Position)
    local moving=flat.Magnitude>settings.AttackRange*.8
    s.Humanoid.WalkSpeed=moving and settings.WalkSpeed or 0
    s.Model:SetAttribute('SahurMoving',moving)
    if not moving then
        s.Humanoid:Move(Vector3.zero);s.LastProgressAt=now;s.LastProgressPosition=s.Root.Position
        return
    end
    if horizontal(s.Root.Position-s.LastProgressPosition).Magnitude>.8 then
        s.LastProgressAt=now;s.LastProgressPosition=s.Root.Position
    end
    local stalled=now-s.LastProgressAt>1.1
    local params=groundParams(s)
    local directSafe=walkable(s,target.Position,params)
    local goal=target.Position
    if s.FollowPath or not visible or not directSafe or stalled then
        s.FollowPath=true
        local floor=workspace:Raycast(target.Position+Vector3.new(0,4,0),Vector3.new(0,-24,0),params)
        self:_path(player,s,floor and floor.Position+Vector3.new(0,.25,0) or goal,now)
        local point=s.Path[s.PathIndex]
        while point and horizontal(point.Position-s.Root.Position).Magnitude<settings.WaypointTolerance do
            s.PathIndex+=1;point=s.Path[s.PathIndex]
        end
        if point then goal=point.Position
        elseif visible and directSafe and not stalled then s.FollowPath=false
        else goal=s.Root.Position end
    end
    if walkable(s,goal,params) then s.Humanoid:MoveTo(goal)
    else s.Humanoid:Move(Vector3.zero);s.Model:SetAttribute('SahurMoving',false) end
end
function Service:Step(now)
    for player,s in pairs(self.States) do
        local target, victim=living(player)
        if player.Parent~=Players or player.Character~=s.Character or not target or not s.Model.Parent
            or now-s.At>settings.Lifetime or (target.Position-s.Home).Magnitude>settings.LeashRange then
            self:Remove(player,'Бой с Сахуром прерван. Улов не получен.')
        elseif now-s.At<settings.RiseTime then
            local t=math.clamp((now-s.At)/settings.RiseTime,0,1)
            -- Exactly one continuous arc; no second jump is used to clear shore.
            local position=s.Origin:Lerp(s.Destination,t)+Vector3.new(0,4*settings.SpawnArcHeight*t*(1-t),0)
            local travelFrame=facing(position,s.Destination,Vector3.new(0,0,1))
            local targetFrame=facing(position,target.Position,travelFrame.LookVector)
            local turn=math.clamp((t-.65)/.35,0,1);turn=turn*turn*(3-2*turn)
            placeRoot(s.Model,s.Root,travelFrame:Lerp(targetFrame,turn))
        else
            s.Humanoid.Jump=false
            if not s.Landed then
                s.Landed=true;s.RecoveryUntil=now+settings.LandingRecovery
                placeRoot(s.Model,s.Root,facing(s.Destination,target.Position,Vector3.new(0,0,-1)))
                s.Root.Anchored=false;s.Root:SetNetworkOwner(nil)
                s.Root.AssemblyLinearVelocity=Vector3.zero;s.Root.AssemblyAngularVelocity=Vector3.zero
                s.Model:SetAttribute('SahurEmerging',false)
                s.Model:SetAttribute('SahurLandingAt',now)
                s.Model:SetAttribute('SahurMoving',false)
                s.LastProgressAt=now;s.LastProgressPosition=s.Destination
            end
            s.UpdateBar()
            local delta=target.Position-s.Root.Position
            local flat=Vector3.new(delta.X,0,delta.Z)
            if now<s.RecoveryUntil then
                s.Humanoid.WalkSpeed=0;s.Humanoid:Move(Vector3.zero)
            elseif s.AttackAt then
                s.Humanoid.WalkSpeed=0;s.Humanoid:Move(Vector3.zero)
                if not s.Hit and now>=s.AttackAt+settings.Windup then
                    s.Hit=true
                    -- Deliberately commit to the telegraphed facing; a sidestep can evade.
                    local forward=s.Facing
                    local side=Vector3.new(-forward.Z,0,forward.X)
                    local distance=flat:Dot(forward)
                    if distance>=-1 and distance<=settings.AttackRange+2 and math.abs(flat:Dot(side))<=3.6
                        and math.abs(delta.Y)<=9 then
                        local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
                        params.FilterDescendantsInstances={s.Model}
                        local ray=workspace:Raycast(s.Root.Position,target.Position-s.Root.Position,params)
                        if not ray or ray.Instance:IsDescendantOf(player.Character) then Damage.Apply(s.Model,victim,settings.Damage) end
                    end
                end
                if now>=s.AttackAt+settings.Windup+settings.Strike+settings.Recovery then
                    s.AttackAt=nil;s.Humanoid.AutoRotate=true
                    s.LastProgressAt=now;s.LastProgressPosition=s.Root.Position
                end
            elseif flat.Magnitude<=settings.AttackRange and math.abs(delta.Y)<=9 and now>=s.NextAttack then
                s.AttackAt=now;s.Hit=false;s.NextAttack=now+settings.AttackCooldown
                s.Humanoid.WalkSpeed=0;s.Humanoid:Move(Vector3.zero)
                s.Facing=flat.Magnitude>.01 and flat.Unit or s.Root.CFrame.LookVector
                s.Root.CFrame=CFrame.lookAt(s.Root.Position,s.Root.Position+s.Facing)
                s.Humanoid.AutoRotate=false;s.Model:SetAttribute('SahurAttackAt',now)
                s.Model:SetAttribute('SahurMoving',false)
            elseif now>=s.ThinkAt then
                s.ThinkAt=now+.15
                local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances={s.Model}
                local sight=workspace:Raycast(s.Root.Position,delta,params)
                local visible=not sight or sight.Instance:IsDescendantOf(player.Character)
                self:_chase(player,s,target,visible,now)
            end
        end
    end
end
return Service
