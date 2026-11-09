-- Localized, deterministic underwater gardens. Everything is visual-only;
-- the collidable sand underneath belongs to OceanFloor.
local Reef = {}
Reef.Version = 'reef-scenery-1'
local V, CF = Vector3.new, CFrame.new

local function part(parent,name,size,frame,color,kind)
    local p=Instance.new(kind=='Wedge' and 'WedgePart' or 'Part')
    p.Name=name;p.Size=size;p.CFrame=frame;p.Color=color
    p.Material=Enum.Material.SmoothPlastic
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
    p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
    if kind=='Sphere' then
        p.Shape=Enum.PartType.Block
        local mesh=Instance.new('SpecialMesh');mesh.MeshType=Enum.MeshType.Sphere
        mesh.Scale=V(1,1,1);mesh.Parent=p
    elseif kind=='Cylinder' then p.Shape=Enum.PartType.Cylinder end
    p.Parent=parent
    return p
end

local function branch(parent,name,a,b,width,color)
    local right=(b-a).Unit
    local hint=math.abs(right:Dot(V(0,1,0)))<.95 and V(0,1,0) or V(0,0,1)
    local back=right:Cross(hint).Unit
    local up=back:Cross(right).Unit
    return part(parent,name,V((b-a).Magnitude,width,width),
        CFrame.fromMatrix((a+b)*.5,right,up,back),color,'Cylinder')
end

function Reef.Build(parent,config,theme,heightAt)
    local root=Instance.new('Model');root.Name='ReefGardens';root.Parent=parent
    root:SetAttribute('QCReefScenery',true)
    local P=theme.Palette
    local colors={P.Coral,Color3.fromRGB(231,157,91),P.Purple,P.Shallows}
    local patches=math.clamp(math.floor(config.Seabed.ReefPatchesPerIsland or 6),0,12)
    local surface=config.Ocean.SurfaceY
    for islandIndex,island in ipairs(config.Islands) do
        local biome=theme.Biomes[island.Theme] or theme.Biomes.home
        for index=1,patches do
            local angle=index*2.3999632297+islandIndex*.61
            local radius=island.Radius+58+math.sin(index*1.71+islandIndex)*20
            local x,z=island.X+math.sin(angle)*radius,island.Z+math.cos(angle)*radius
            local y=heightAt(x,z)
            -- A user-authored shallow patch must never project into a boat lane.
            if y>surface-10 then continue end
            local patch=Instance.new('Model');patch.Name='Reef_'..island.Id..'_'..index;patch.Parent=root
            patch:SetAttribute('IslandId',island.Id);patch:SetAttribute('GroundY',y)
            patch:SetAttribute('AnchorX',x);patch:SetAttribute('AnchorZ',z)
            local turn=angle*.73
            local scale=.83+(math.sin(index*2.13+islandIndex)+1)*.12
            local coral=colors[(index+islandIndex-2)%#colors+1]
            local tip=coral:Lerp(P.Cream,.28)
            local function at(lx,lz,up)
                local wx=x+(lx*math.cos(turn)+lz*math.sin(turn))*scale
                local wz=z+(-lx*math.sin(turn)+lz*math.cos(turn))*scale
                return V(wx,heightAt(wx,wz)+(up or 0)*scale,wz)
            end
            local function oval(name,lx,lz,up,size,color,rotation)
                return part(patch,name,size*scale,CF(at(lx,lz,up))*CFrame.Angles(0,turn,rotation or 0),color,'Sphere')
            end
            local stone=biome.Rock:Lerp(P.Sand,.38)
            oval('ReefFoundation',0,0,.48,V(4.9,1.25,4.2),stone)
            oval('ReefStone',-2.6,1.4,.4,V(2.6,1.05,2.2),stone:Lerp(P.Sand,.18),-.13)

            -- A forked, branching coral: connected cylinders with rounded tips.
            local a,b,c,d=at(-.8,-.5,.55),at(-.75,-.5,1.7),at(-.5,-.5,2.8),at(-.2,-.5,3.65)
            branch(patch,'CoralTrunk',a,b,.34*scale,coral)
            branch(patch,'CoralTrunk',b,c,.28*scale,coral)
            branch(patch,'CoralTrunk',c,d,.22*scale,coral)
            for side=-1,1,2 do
                local fork=at(-.75+side*.9,-.5,2.4)
                local endPoint=at(-.75+side*1.15,-.5,3.05+side*.15)
                branch(patch,'CoralFork',b,fork,.22*scale,coral)
                branch(patch,'CoralFork',fork,endPoint,.16*scale,tip)
                part(patch,'CoralTip',V(.24,.3,.24)*scale,CF(endPoint),tip,'Sphere')
            end
            oval('CoralTip',-.2,-.5,3.65,V(.25,.3,.25),tip)

            -- Broad sea-fan lobes and visible stems form a small upright fan.
            local fanBase=at(2.1,1.2,-.02)
            local fanCrown=at(2.1,1.2,1.35)
            branch(patch,'SeaFanStem',fanBase,fanCrown,.14*scale,coral:Lerp(P.Ink,.16))
            for lobe=-1,1 do
                oval('SeaFanLobe',2.1+lobe*.55,1.2,1.8-math.abs(lobe)*.2,
                    V(1.0,1.55,.16),coral:Lerp(P.Purple,.22),-lobe*.3)
            end
            branch(patch,'SeaFanVein',fanCrown,at(1.5,1.2,2.25),.065*scale,tip)
            branch(patch,'SeaFanVein',fanCrown,at(2.7,1.2,2.25),.065*scale,tip)

            -- Flat coral shelf and two hollow-looking sponges, not random balls.
            local shelfRoot=at(-2.1,-2.0,-.02)
            branch(patch,'TableCoralStem',shelfRoot,at(-2.1,-2.0,.75),.24*scale,coral)
            oval('TableCoral',-2.1,-2.0,.83,V(3.1,.25,2.15),coral:Lerp(P.Cream,.15))
            for sponge=1,2 do
                local lx,lz=1.3+sponge*.65,-1.8+sponge*.2
                local height=.85+sponge*.3
                local base=at(lx,lz,.02)
                branch(patch,'ReefSponge',base,at(lx,lz,height),.55*scale,P.Gold:Lerp(coral,.3))
                oval('SpongeOpening',lx,lz,height+.015,V(.36,.045,.36),P.Ink:Lerp(coral,.22))
            end
            local grass=P.Leaves:Lerp(P.Shallows,.27)
            for blade=1,6 do
                local clump=blade<=3 and 1 or -1
                local gx,gz=clump*3.2+(blade%3-1)*.25,1.6+(blade%2)*.45
                local height=1.25+(blade%3)*.3
                local base=at(gx,gz,.02)
                part(patch,'Seagrass',V(.12,height,.43)*scale,
                    CF(base+V(0,height*scale*.5,0))*CFrame.Angles(.1,turn+blade*.5,clump*.18),
                    grass:Lerp(P.LeafLight,(blade%3)*.08),'Wedge')
            end
        end
    end
    return root
end
return Reef
