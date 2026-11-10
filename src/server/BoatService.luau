-- Server-owned arcade boats, physical hulls with constrained float height.
-- Input arrives as axes only. Purchasing, spawn location, ownership, and speed
-- are always decided here. One active boat per player; recalling it is free.
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage"):WaitForChild("QuietCove")
local Models=require(RS:WaitForChild("EquipmentModels"))
local Rules=require(RS:WaitForChild("BoatRules"))
local BoatService={};BoatService.__index=BoatService
local function rootOf(player)
    local c=player.Character;local h=c and c:FindFirstChildOfClass("Humanoid")
    local root=c and c:FindFirstChild("HumanoidRootPart")
    if h and h.Health>0 and root then return root,h end
end
function BoatService:NearDock(player,maxDistance)
    local root=rootOf(player);if not root then return nil end
    local nearest,distance=nil,maxDistance or 19
    for _,dock in pairs(self.World.Docks)do
        local delta=(root.Position-dock.Captain.Position).Magnitude
        if delta<distance then distance=delta;nearest=dock end
    end
    return nearest
end
function BoatService:CanTrade(player)
    if self.Busy(player)then return nil,"Finish fishing first." end
    local data=self.Profiles.Get(player)
    if not data then return nil,"Your profile is still loading." end
    local dock=self:NearDock(player,20)
    if not dock then return nil,"Talk to the captain at the dock." end
    local _,humanoid=rootOf(player)
    if humanoid.SeatPart then return nil,"Step onto the dock first." end
    return data,dock
end
function BoatService:Buy(player,id)
    local data,dock=self:CanTrade(player)
    if not data then self:Notice(player,dock);return end
    local ok,reason=Rules.CanBuy(self.Config,data,id)
    if not ok then self:Notice(player,reason);return end
    -- No yields between checking funds and recording ownership.
    if not data.TestMode then data.Coins=data.Coins-self.Config.BoatById[id].Price end
    data.OwnedBoats=data.OwnedBoats or {};data.OwnedBoats[id]=true;data.BoatId=id
    self.Sync(player);self.Send(player,"BoatShop",{Dock=dock.Id})
    self:Notice(player,"Purchased: "..self.Config.BoatById[id].Name..". Select Launch to use it.")
end
function BoatService:Notice(player,message)self.Send(player,"Notice",{Text=message})end
function BoatService:Remove(player)
    local b=self.Active[player];if not b then return end
    self.Active[player]=nil
    if b.Connection then b.Connection:Disconnect()end
    if b.Seat and b.Seat.Occupant then b.Seat.Occupant.Sit=false end
    if b.Model then b.Model:Destroy()end
end
function BoatService:_freeBerth(dock,ignorePlayer)
    for i=0,4 do
        local pos=dock.Berth+Vector3.new(i*24,0,0)
        local occupied=false
        for owner,b in pairs(self.Active)do
            if owner~=ignorePlayer and b.Root and b.Root.Parent and (b.Root.Position-pos).Magnitude<23 then occupied=true;break end
        end
        if not occupied then return pos end
    end
    return nil
end
function BoatService:Spawn(player,id)
    local data,dock=self:CanTrade(player)
    if not data then self:Notice(player,dock);return end
    if type(id)~="string" or not self.Config.BoatById[id] or not (data.OwnedBoats or {})[id] then
        self:Notice(player,"Buy this boat first.");return
    end
    local pos=self:_freeBerth(dock,player)
    if not pos then self:Notice(player,"The dock is full. Wait for a berth to become available.");return end
    self:Remove(player)
    local def=self.Config.BoatById[id]
    local model=Models.Boat(def,false);local root=model.PrimaryPart;local seat=model.PilotSeat
    model:SetAttribute("QuietCoveBoat",true);model:SetAttribute("OwnerUserId",player.UserId)
    model:SetAttribute("BoatId",id);seat:SetAttribute("OwnerUserId",player.UserId)
    model:PivotTo(CFrame.new(pos)*CFrame.Angles(0,math.pi,0))
    local at=Instance.new("Attachment");at.Name="DriveAttachment";at.Parent=root
    local float=Instance.new("AlignPosition");float.Name="Waterline";float.Mode=Enum.PositionAlignmentMode.OneAttachment
    float.Attachment0=at;float.Position=Vector3.new(pos.X,self.Config.Ocean.BoatHeight,pos.Z);float.ApplyAtCenterOfMass=true
    float.ForceLimitMode=Enum.ForceLimitMode.PerAxis;float.ForceRelativeTo=Enum.ActuatorRelativeTo.World
    float.MaxAxesForce=Vector3.new(0,1000000,0);float.MaxVelocity=14;float.Responsiveness=12;float.Parent=root
    local velocity=Instance.new("LinearVelocity");velocity.Name="BoatDrive";velocity.Attachment0=at
    velocity.VelocityConstraintMode=Enum.VelocityConstraintMode.Plane;velocity.RelativeTo=Enum.ActuatorRelativeTo.World
    velocity.PrimaryTangentAxis=Vector3.new(1,0,0);velocity.SecondaryTangentAxis=Vector3.new(0,0,1)
    velocity.PlaneVelocity=Vector2.new(0,0);velocity.ForceLimitsEnabled=true
    velocity.ForceLimitMode=Enum.ForceLimitMode.PerAxis;velocity.MaxPlanarAxesForce=Vector2.new(100000,100000);velocity.Parent=root
    local facing=Instance.new("AlignOrientation");facing.Name="BoatHeading";facing.Mode=Enum.OrientationAlignmentMode.OneAttachment
    facing.Attachment0=at;facing.CFrame=CFrame.Angles(0,math.pi,0);facing.MaxTorque=1000000
    facing.MaxAngularVelocity=3;facing.Responsiveness=18;facing.Parent=root
    local b={Model=model,Root=root,Seat=seat,Float=float,Velocity=velocity,Facing=facing,Def=def,
        Speed=0,Yaw=math.pi,Throttle=0,Steer=0,LastInput=0,Dock=dock,Owner=player,LastSafe=pos,SyncAt=0}
    self.Active[player]=b;model.Parent=self.Folder
    pcall(function()root:SetNetworkOwner(nil)end)
    local board=Instance.new("ProximityPrompt");board.Name="PilotPrompt";board.ActionText="Take the helm"
    board.ObjectText=def.Name;board.KeyboardKeyCode=Enum.KeyCode.E;board.HoldDuration=0.2
    board.MaxActivationDistance=12;board.RequiresLineOfSight=false;board.Parent=seat
    board.Triggered:Connect(function(p)
        local r,h=rootOf(p)
        if p==player and r and not self.Busy(p) and not seat.Disabled and (r.Position-seat.Position).Magnitude<15 then seat:Sit(h)end
    end)
    b.Connection=seat:GetPropertyChangedSignal("Occupant"):Connect(function()
        local h=seat.Occupant
        local previous=b.Rider;b.Rider=h
        if previous and previous~=h and previous.Parent then
            local oldRoot=previous.Parent:FindFirstChild("HumanoidRootPart")
            local previousPlayer=Players:GetPlayerFromCharacter(previous.Parent)
            task.delay(0.12,function()
                if oldRoot and oldRoot.Parent and not previous.SeatPart then
                    pcall(function()
                        if previousPlayer then oldRoot:SetNetworkOwner(previousPlayer)else oldRoot:SetNetworkOwnershipAuto()end
                    end)
                end
            end)
        end
        if h and Players:GetPlayerFromCharacter(h.Parent)~=player then h.Sit=false;h.Jump=true end
        b.Throttle=0;b.Steer=0;b.LastInput=0
        pcall(function()root:SetNetworkOwner(nil)end)
    end)
    data.BoatId=id;self.Sync(player)
    self.Send(player,"BoatLaunched",{Id=id,Dock=dock.Id})
    self:Notice(player,"W/S: move. A/D: steer. M: map. E near a dock: disembark.")
    -- Server positions only its owner, after the assembly exists; no client target CFrame.
    local character=player.Character
    task.delay(0.15,function()
        local r,h=rootOf(player)
        if self.Active[player]~=b or player.Character~=character or not r then return end
        if (r.Position-dock.Captain.Position).Magnitude>35 or self.Busy(player)then return end
        r.CFrame=seat.CFrame*CFrame.new(0,2.5,0);seat:Sit(h)
    end)
end
function BoatService:Input(player,value)
    local b=self.Active[player];if not b then return end
    local _,h=rootOf(player)
    if not h or b.Seat.Occupant~=h then return end
    local throttle,steer=Rules.Input(value);if throttle==nil then return end
    b.Throttle=throttle;b.Steer=steer;b.LastInput=os.clock()
end
function BoatService:Dock(player)
    local b=self.Active[player];local r,h=rootOf(player)
    if not b or not r or b.Seat.Occupant~=h then return end
    local dock,best=nil,58
    for _,d in pairs(self.World.Docks)do
        local dist=(b.Root.Position-d.Berth).Magnitude
        if dist<best then dock=d;best=dist end
    end
    if not dock then self:Notice(player,"Sail closer to the wooden dock on the island.");return end
    b.Speed=0;b.Throttle=0;b.Steer=0;b.Velocity.PlaneVelocity=Vector2.new(0,0)
    b.Root.AssemblyLinearVelocity=Vector3.new(0,0,0);b.Root.AssemblyAngularVelocity=Vector3.new(0,0,0)
    b.Seat.Disabled=true;h.Sit=false
    local joint=b.Seat:FindFirstChild("SeatWeld");if joint then joint:Destroy()end
    local character=player.Character
    task.delay(0.05,function()
        if player.Character==character and character.Parent and r.Parent and h.Health>0 then
            r.CFrame=CFrame.new(dock.Land);r.AssemblyLinearVelocity=Vector3.new(0,0,0)
            pcall(function()r:SetNetworkOwner(player)end)
        end
    end)
    task.delay(1,function()if self.Active[player]==b and b.Seat.Parent then b.Seat.Disabled=false end end)
    self:Notice(player,"Docked at "..dock.Name..". The fishing pier is on the north side of the island.")
end
function BoatService:_step(dt)
    local now=os.clock()
    for player,b in pairs(self.Active)do
        if not b.Root.Parent or player.Parent~=Players then self:Remove(player)
        else
            local _,h=rootOf(player)
            local driving=h and b.Seat.Occupant==h
            local throttle,steer=0,0
            if driving and now-b.LastInput<0.55 then throttle=b.Throttle;steer=b.Steer end
            b.Speed,b.Yaw=Rules.Step(b.Speed,b.Yaw,throttle,steer,dt,b.Def)
            local pos=b.Root.Position
            local bound=self.Config.Ocean.HalfExtent
            if math.abs(pos.X)>bound or math.abs(pos.Z)>bound or pos.Y<-15 or pos.Y>30 then
                b.Model:PivotTo(CFrame.new(b.LastSafe)*CFrame.Angles(0,b.Yaw,0))
                b.Root.AssemblyLinearVelocity=Vector3.new(0,0,0);b.Speed=0
                if driving then self:Notice(player,"You have reached the edge of the archipelago. Turn back toward the islands.")end
            else b.LastSafe=pos end
            local mass=b.Root.AssemblyMass
            if mass>0 and mass<1000000 then
                b.Float.MaxAxesForce=Vector3.new(0,mass*workspace.Gravity*5,0)
                b.Velocity.MaxPlanarAxesForce=Vector2.new(mass*b.Def.Acceleration*2,mass*b.Def.Acceleration*2)
                b.Facing.MaxTorque=mass*18000
            end
            -- Gentle tide remains cosmetic and does not throw the passenger.
            b.Float.Position=Vector3.new(pos.X,self.Config.Ocean.BoatHeight+math.sin(now*1.4)*0.06,pos.Z)
            b.Facing.CFrame=CFrame.Angles(0,b.Yaw,0)
            b.Velocity.PlaneVelocity=Vector2.new(-math.sin(b.Yaw)*b.Speed,-math.cos(b.Yaw)*b.Speed)
            if now>=b.SyncAt then
                b.SyncAt=now+0.3
                b.Model:SetAttribute("Speed",math.floor(math.abs(b.Speed)))
            end
        end
    end
end
function BoatService.new(config,world,profiles,send,sync,busy)
    local folder=Instance.new("Folder");folder.Name="QuietCoveBoats";folder.Parent=workspace
    local self=setmetatable({Config=config,World=world,Profiles=profiles,Send=send,Sync=sync,Busy=busy,Folder=folder,Active={},OpenedAt={}},BoatService)
    for _,dock in pairs(world.Docks)do
        dock.Captain.CaptainPrompt.Triggered:Connect(function(player)
            local now=os.clock()
            if now-(self.OpenedAt[player] or -10)<0.5 then return end
            self.OpenedAt[player]=now
            local data,reason=self:CanTrade(player)
            if not data then self:Notice(player,reason);return end
            self.Send(player,"BoatShop",{Dock=dock.Id})
        end)
    end
    self.Connection=RunService.Heartbeat:Connect(function(dt)self:_step(dt)end)
    Players.PlayerRemoving:Connect(function(p)self:Remove(p);self.OpenedAt[p]=nil end)
    return self
end
return BoatService
