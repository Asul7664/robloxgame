-- Local 3D catch cinematics from SERVER-approved CatchVisual packets.
-- Local previews never call remotes. No client confirmation is required to receive a won fish.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local shared=game:GetService('ReplicatedStorage'):WaitForChild('QuietCove')
local Models=require(shared:WaitForChild('CreatureModels'))
local Presentation=require(shared:WaitForChild('CatchPresentation'))
local Path=require(shared:WaitForChild('LandingMath'))
local FX={};FX.__index=FX
local function make(cl,props,parent)local o=Instance.new(cl);for k,v in pairs(props)do o[k]=v end;o.Parent=parent;return o end
local function particle(parent,color,size)
    return make('Part',{Shape=Enum.PartType.Ball,Size=Vector3.new(size,size,size),Anchored=true,
        CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false,Color=color,Material=Enum.Material.Neon},parent)
end
local function ring(parent,center,color)
    local root=particle(parent,color,.1);root.Transparency=1;local points,beams={},{}
    for i=1,24 do points[i]=make('Attachment',{Position=center},root)end
    for i=1,24 do beams[i]=make('Beam',{Attachment0=points[i],Attachment1=points[i%24+1],
        FaceCamera=true,Width0=.10,Width1=.10,Segments=1,LightEmission=.7,Color=ColorSequence.new(color),Transparency=NumberSequence.new(.4)},root)end
    return {Root=root,Points=points,Beams=beams,Center=center}
end
function FX.new(config)
    local self=setmetatable({Config=config,Active={},Seen={},PreviewIndex=0},FX)
    self.Folder=make('Folder',{Name='QuietCoveCatchWorld'},workspace)
    self.Connection=RunService.RenderStepped:Connect(function()self:Step()end)
    return self
end
function FX:OwnerPlaying()
    for _,v in pairs(self.Active)do if v.Data.UserId==Players.LocalPlayer.UserId then return true end end
    return false
end
function FX:_remove(id)
    local c=self.Active[id];if not c then return end
    c.Root:Destroy();self.Active[id]=nil
end
function FX:Handle(kind,p)
    if self.Dead then return end
    if kind=='CatchVisualEnd' then
        local c=self.Active[p.Id]
        -- Complete normally by the shared clock. Explicit end only removes stale visuals.
        if c and workspace:GetServerTimeNow()>=c.Data.Started+c.Data.Duration then self:_remove(p.Id)end
        return
    end
    if kind~='CatchVisual' or not Models.Has(p.Species)or self.Seen[p.Id]then return end
    local now=workspace:GetServerTimeNow();if now>p.Started+p.Duration then return end
    local char=Players.LocalPlayer.Character;local root=char and char:FindFirstChild('HumanoidRootPart')
    if root and p.UserId~=Players.LocalPlayer.UserId and (root.Position-p.Origin).Magnitude>self.Config.Landing.EffectDistance then return end
    local count=0;local oldest,oldId=math.huge,nil
    for id,v in pairs(self.Active)do count=count+1;if v.Data.UserId~=Players.LocalPlayer.UserId and v.Data.Started<oldest then oldest=v.Data.Started;oldId=id end end
    if count>=self.Config.Landing.MaxVisible then if oldId then self:_remove(oldId)else return end end
    self.Seen[p.Id]=now
    local host=make('Folder',{Name='Landing_'..p.Species},self.Folder)
    local model=Models.Create(p.Species,host,p.Mutation);if not model then host:Destroy();return end
    Presentation.ScaleLanding(model,p.Species,p.Rarity)
    local binding=Models.Bind(model)
    local rgb=self.Config.Rarities[p.Rarity].Color;local color=Color3.fromRGB(rgb[1],rgb[2],rgb[3])
    local outline=make('Highlight',{Adornee=model,FillTransparency=1,OutlineColor=color,
        OutlineTransparency=p.Rarity>=5 and .25 or .70,DepthMode=Enum.HighlightDepthMode.Occluded},model)
    local dots={};local drops=8+p.Rarity*3
    for i=1,drops do
        local a=i*2.39996
        dots[#dots+1]={Part=particle(host,i%3==0 and Color3.fromRGB(238,254,255)or color,.075+(i%3)*.025),
            Velocity=Vector3.new(math.cos(a)*(2+i%4),7+i%5,math.sin(a)*(2+i%4))}
    end
    local rings={};local center=Vector3.new(p.Origin.X,self.Config.Ocean.SurfaceY+.04,p.Origin.Z)
    for i=1,(p.Rarity>=5 and 4 or 2)do rings[i]=ring(host,center,color)end
    local stars={}
    if p.Rarity>=3 then
        for i=1,(p.Rarity==6 and 12 or 6)do stars[i]=particle(host,color,.07+(i%2)*.05)end
    end
    self.Active[p.Id]={Data=p,Root=host,Model=model,Binding=binding,Dots=dots,Rings=rings,Stars=stars,Outline=outline}
    self:Step() -- position the newly created parts immediately; no flash at the world origin
end
function FX:Step()
    if self.Dead then return end
    local now=workspace:GetServerTimeNow();local remove={}
    for id,c in pairs(self.Active)do
        local p=c.Data;local elapsed=now-p.Started;local t=elapsed/p.Duration
        if t>=1 then remove[#remove+1]=id
        else
            local position=Path.Position(p.Origin,p.Destination,t,p.Rarity)
            local facing=p.Facing
            if (facing-position).Magnitude<.1 then facing=position+Vector3.new(0,0,-1)end
            local frame=CFrame.lookAt(position,facing)*CFrame.Angles(0,0,math.sin(t*math.pi*2)*.12*(1-t))
            Models.Animate(c.Model,c.Binding,frame,elapsed,Path.Fade(t))
            c.Outline.OutlineTransparency=math.min(1,(p.Rarity>=5 and .25 or .7)+Path.Fade(t))
            for i,d in ipairs(c.Dots)do
                local at=math.max(0,elapsed-.15)
                d.Part.Position=Vector3.new(p.Origin.X,.07,p.Origin.Z)+d.Velocity*at-Vector3.new(0,12*at*at,0)
                d.Part.Transparency=elapsed<.15 and 1 or math.clamp(at/.9,0,1)
            end
            for i,r in ipairs(c.Rings)do
                local age=elapsed-(i-1)*.12;local u=math.clamp(age/1.4,0,1);local radius=.55+u*(3.6+p.Rarity*.45)
                for j,a in ipairs(r.Points)do local angle=(j-1)*math.pi/12
                    a.Position=r.Center+Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius)
                end
                for _,b in ipairs(r.Beams)do b.Transparency=NumberSequence.new(age<0 and 1 or .2+.8*u)end
            end
            for i,star in ipairs(c.Stars)do
                local angle=i*2*math.pi/#c.Stars+elapsed*1.8
                star.Position=position+Vector3.new(math.cos(angle)*(1.5+p.Rarity*.10),math.sin(angle*1.8)*.8,math.sin(angle)*(1.5+p.Rarity*.10))
                star.Transparency=t<.2 and 1 or .15+.85*Path.Fade(t)
            end
        end
    end
    for _,id in ipairs(remove)do self:_remove(id)end
    for id,t in pairs(self.Seen)do if now-t>15 then self.Seen[id]=nil end end
end
function FX:Preview(species,mutation)
    if not RunService:IsStudio()then return false end
    local char=Players.LocalPlayer.Character;local root=char and char:FindFirstChild('HumanoidRootPart')
    local fish=self.Config.ById[species]
    if not root or not fish or self:OwnerPlaying()then return false end
    mutation=mutation or 'normal'
    if mutation~='normal' and mutation~='gold' and mutation~='glow' then return false end
    local start=root.CFrame*Vector3.new(0,0,-20)
    local id='preview_'..tostring(os.clock())
    self:Handle('CatchVisual',{Id=id,UserId=Players.LocalPlayer.UserId,
        Species=species,Mutation=mutation,Preview=true,Kg=(fish.MinKg+fish.MaxKg)/2,Rarity=fish.Rarity,
        Origin=Vector3.new(start.X,-1.2,start.Z),Destination=(root.CFrame*CFrame.new(0,1.1,-4.2)).Position,
        Facing=root.Position,Started=workspace:GetServerTimeNow(),Duration=self.Config.Landing.DurationByRarity[fish.Rarity]})
    return self.Active[id]~=nil
end
function FX:ClearPreviews()
    local ids={};for id,c in pairs(self.Active)do if c.Data.Preview==true then ids[#ids+1]=id end end
    for _,id in ipairs(ids)do self:_remove(id)end
end
function FX:Clear()
    local ids={};for id in pairs(self.Active)do ids[#ids+1]=id end;for _,id in ipairs(ids)do self:_remove(id)end
end
function FX:Destroy()self.Dead=true;self.Connection:Disconnect();self:Clear();self.Folder:Destroy()end
return FX
