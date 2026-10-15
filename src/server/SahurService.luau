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
    humanoid.WalkSpeed=0;humanoid.BreakJointsOnDeath=false
    humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming,false)
    root.Anchored=true
    -- Travel out of water to the island's own fishing deck, not a remote island.
    local footHeight=humanoid.HipHeight+root.Size.Y/2
    local destination=zone.Center+Vector3.new(0,footHeight-.5,-6)
    local origin=Vector3.new(zone.Center.X,-footHeight-3,zone.Center.Z-17)
    local folder=workspace:FindFirstChild('SahurEncounters')
    if not folder then folder=Instance.new('Folder');folder.Name='SahurEncounters';folder.Parent=workspace end
    placeRoot(model,root,CFrame.lookAt(origin,Vector3.new(target.Position.X,origin.Y,target.Position.Z)))
    model.Parent=folder
    CollectionService:AddTag(model,'QCSahurBoss')
    local s={Model=model,Root=root,Humanoid=humanoid,Character=player.Character,Token=token,Record=record,
        At=workspace:GetServerTimeNow(),Origin=origin,Destination=destination,Home=destination,
        NextAttack=0,ThinkAt=0,NextPath=0,PathIndex=1,Path={},UpdatingPath=false,Won=false}
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
        local path=PathfindingService:CreatePath({AgentRadius=2.6,AgentHeight=12,AgentCanJump=true,WaypointSpacing=5})
        local ok=pcall(function() path:ComputeAsync(s.Root.Position,target) end)
        if self.States[player]~=s then return end
        s.UpdatingPath=false
        if ok and path.Status==Enum.PathStatus.Success then
            s.Path=path:GetWaypoints();s.PathIndex=math.min(2,#s.Path)
        else s.Path={} end
    end)
end
function Service:Step(now)
    for player,s in pairs(self.States) do
        local target, victim=living(player)
        if player.Parent~=Players or player.Character~=s.Character or not target or not s.Model.Parent
            or now-s.At>settings.Lifetime or (target.Position-s.Home).Magnitude>settings.LeashRange then
            self:Remove(player,'Бой с Сахуром прерван. Улов не получен.')
        elseif now-s.At<settings.RiseTime then
            local t=math.clamp((now-s.At)/settings.RiseTime,0,1)
            local crest=Vector3.new(s.Origin.X,s.Destination.Y+1,s.Origin.Z)
            local u=t<.68 and t/.68 or (t-.68)/.32;u=u*u*(3-2*u)
            local position=t<.68 and s.Origin:Lerp(crest,u) or crest:Lerp(s.Destination,u)
            placeRoot(s.Model,s.Root,CFrame.lookAt(position,Vector3.new(target.Position.X,position.Y,target.Position.Z)))
        else
            if s.Root.Anchored then
                s.Root.Anchored=false;s.Root:SetNetworkOwner(nil)
                s.Model:SetAttribute('SahurEmerging',false)
            end
            s.UpdateBar()
            local delta=target.Position-s.Root.Position
            local flat=Vector3.new(delta.X,0,delta.Z)
            if s.AttackAt then
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
                end
            elseif flat.Magnitude<=settings.AttackRange and now>=s.NextAttack then
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
                local moving=flat.Magnitude>settings.AttackRange*.8 and flat.Magnitude<=settings.DetectionRange
                s.Humanoid.WalkSpeed=moving and settings.WalkSpeed or 0
                s.Model:SetAttribute('SahurMoving',moving)
                if moving then
                    local goal=target.Position
                    if not visible then
                        self:_path(player,s,goal,now)
                        local waypoint=s.Path[s.PathIndex]
                        if waypoint and (waypoint.Position-s.Root.Position).Magnitude<5 then
                            s.PathIndex+=1;waypoint=s.Path[s.PathIndex]
                        end
                        if waypoint then
                            goal=waypoint.Position
                            if waypoint.Action==Enum.PathWaypointAction.Jump then s.Humanoid.Jump=true end
                        else goal=s.Root.Position end
                    end
                    -- Do not chase over a pier edge into deep water.
                    local travel=goal-s.Root.Position
                    local ahead=travel.Magnitude>.01 and s.Root.Position+travel.Unit*4 or s.Root.Position
                    local ground=workspace:Raycast(ahead+Vector3.new(0,4,0),Vector3.new(0,-20,0),params)
                    if travel.Magnitude>.01 and ground and ground.Material~=Enum.Material.Water then s.Humanoid:MoveTo(goal)
                    else s.Humanoid:Move(Vector3.zero) end
                else s.Humanoid:Move(Vector3.zero) end
            end
        end
    end
end
return Service
