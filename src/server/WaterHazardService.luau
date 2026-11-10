-- Main owns the Heartbeat and player lifecycle. No client reports decide water
-- time, immunity or death. A water episode survives airborne WaterJump hops.
local Players = game:GetService('Players')
local Workspace = game:GetService('Workspace')
local Storage = game:GetService('ServerStorage')
local Damage = require(game:GetService('ReplicatedStorage'):WaitForChild('Combat'):WaitForChild('Damage'))
local Visual = require(script.Parent:WaitForChild('SharkVisual'))
local Service = {}
Service.__index = Service

function Service.new(settings, notice)
    -- Studio preserves the editor's copy after Stop; only the runtime copy is
    -- hidden here, so it cannot sit as a second static shark during gameplay.
    local preview=Workspace:FindFirstChild('SharkPreview')
    if preview and preview:GetAttribute('QCSharkEditorPreview')==true then preview:Destroy() end
    return setmetatable({Settings=settings, Notice=notice, States={}, Effects={}, NextCheck=0}, Service)
end

function Service:Remove(player)
    self.States[player]=nil
    for index=#self.Effects,1,-1 do
        local effect=self.Effects[index]
        if effect.Player==player then effect.Model:Destroy();table.remove(self.Effects,index) end
    end
end

local function medium(character, humanoid, root, settings)
    if humanoid.SeatPart then return 'safe' end
    local state=humanoid:GetState()
    local airborne=state==Enum.HumanoidStateType.Jumping or state==Enum.HumanoidStateType.Freefall
    local leg=character:FindFirstChild('Left Leg')
    local feet=root.Size.Y*.5+math.max(0,humanoid.HipHeight or 0)+(leg and leg.Size.Y or 0)
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={character}
    params.IgnoreWater=false;params.RespectCanCollide=true
    local hit=Workspace:Raycast(root.Position,Vector3.new(0,-(feet+settings.GroundTolerance),0),params)
    if hit and hit.Material==Enum.Material.Water then return 'water' end
    -- A solid seafloor is still underwater. Walking on sand at depth must not
    -- grant the same safety as standing on a dry dock or boat deck.
    if root.Position.Y<settings.SurfaceY and hit and hit.Position.Y<settings.SurfaceY-1 then return 'water' end
    if hit and hit.Normal.Y>=.5 and not airborne then return 'safe' end
    if state==Enum.HumanoidStateType.Swimming or humanoid.FloorMaterial==Enum.Material.Water then return 'water' end
    local floor=humanoid.FloorMaterial
    if not airborne and floor and floor~=Enum.Material.Air and floor~=Enum.Material.Water then
        return root.Position.Y<settings.SurfaceY-1 and 'water' or 'safe'
    end
    return 'air'
end

function Service:_visual(player, root, now)
    local folder=Workspace:FindFirstChild('QuietCoveWaterHazards')
    if not folder then folder=Instance.new('Folder');folder.Name='QuietCoveWaterHazards';folder.Parent=Workspace end
    local direction=root.CFrame.RightVector
    direction=Vector3.new(direction.X,0,direction.Z)
    direction=direction.Magnitude>.01 and direction.Unit or Vector3.new(1,0,0)
    -- The mouth is already beside the swimmer when the shark appears. Only
    -- this anchored cosmetic model moves; no force is applied to the victim.
    local center=root.Position-direction*3.5
    center=Vector3.new(center.X,math.min(center.Y,self.Settings.SurfaceY)-.5,center.Z)
    local frame=CFrame.lookAt(center,center+direction)
    local model=Visual.Create(folder,frame,Storage:FindFirstChild('OceanSharkTemplate'))
    table.insert(self.Effects,{Player=player,Model=model,Frame=frame,At=now,Direction=direction})
end

function Service:_effects(now)
    for index=#self.Effects,1,-1 do
        local effect=self.Effects[index]
        local t=math.clamp((now-effect.At)/self.Settings.EffectSeconds,0,1)
        if t>=1 or not effect.Model.Parent then
            effect.Model:Destroy();table.remove(self.Effects,index)
        else
            local offset=effect.Direction*(t*5)+Vector3.new(0,math.sin(t*math.pi)*1.8-t*t*4,0)
            effect.Model:PivotTo(effect.Frame+offset)
        end
    end
end

function Service:Step(now)
    if not self.Settings.Enabled then self:Destroy();return end
    self:_effects(now)
    if now<self.NextCheck then return end
    self.NextCheck=now+self.Settings.CheckInterval
    local seen={}
    for _,player in Players:GetPlayers() do
        seen[player]=true
        local character=player.Character
        local humanoid=character and character:FindFirstChildOfClass('Humanoid')
        local root=character and character:FindFirstChild('HumanoidRootPart')
        local state=self.States[player]
        if state and state.Character~=character then self:Remove(player);state=nil end
        if not character or not character.Parent or not humanoid or humanoid.Health<=0
            or not root or not root:IsA('BasePart') then
            -- Keep the brief attack visual visible after the victim dies.
            self.States[player]=nil
        else
            local where=medium(character,humanoid,root,self.Settings)
            if where=='safe' then self.States[player]=nil
            else
                if not state and where=='water' then
                    state={Character=character,StartedAt=now};self.States[player]=state
                end
                if state and not state.Tripped then
                    local elapsed=now-state.StartedAt
                    if where=='water' and elapsed>=self.Settings.Seconds then
                        state.Tripped=true
                        Damage.KillFromHazard(humanoid,'Shark')
                        self.Notice(player,('Shark! Use a boat instead of staying in the water for more than %d seconds.'):format(self.Settings.Seconds))
                        -- A cosmetic asset failure must never disable the rule.
                        local ok,reason=pcall(self._visual,self,player,root,now)
                        if not ok then warn('[QuietCove] Shark visual: '..tostring(reason)) end
                    elseif not state.Warned and elapsed>=self.Settings.Seconds-self.Settings.WarningSeconds then
                        state.Warned=true
                        local left=math.max(1,math.ceil(self.Settings.Seconds-elapsed))
                        self.Notice(player,'Watch out! A shark arrives in '..left..'s. Get onto land or into a boat.')
                    end
                end
            end
        end
    end
    for player in pairs(self.States) do if not seen[player] then self:Remove(player) end end
end

function Service:Destroy()
    table.clear(self.States)
    for _,effect in self.Effects do effect.Model:Destroy() end
    table.clear(self.Effects)
end
return Service
