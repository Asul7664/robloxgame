-- Six distinct underwater habitats. All pieces use the real sand sampler.
local Reef={Version='reef-habitats-2'}
local V,CF=Vector3.new,CFrame.new
local TYPES={'CoralGarden','RockRidge','SpongeColony','SeaFanGarden','KelpGrove','TableTerraces'}
local function part(parent,name,size,frame,color,kind)
    local p=Instance.new(kind=='Wedge' and 'WedgePart' or 'Part')
    p.Name=name;p.Size=size;p.CFrame=frame;p.Color=color;p.Material=Enum.Material.SmoothPlastic
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
    p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
    if kind=='Sphere' then
        p.Shape=Enum.PartType.Block
        local mesh=Instance.new('SpecialMesh');mesh.MeshType=Enum.MeshType.Sphere
        mesh.Scale=V(1,1,1);mesh.Parent=p
    elseif kind=='Cylinder' then p.Shape=Enum.PartType.Cylinder end
    p.Parent=parent;return p
end
local function branch(parent,name,a,b,width,color)
    local right=(b-a).Unit
    local hint=math.abs(right:Dot(V(0,1,0)))<.95 and V(0,1,0) or V(0,0,1)
    local back=right:Cross(hint).Unit;local up=back:Cross(right).Unit
    return part(parent,name,V((b-a).Magnitude,width,width),CFrame.fromMatrix((a+b)*.5,right,up,back),color,'Cylinder')
end
function Reef.Build(parent,config,theme,heightAt)
    local root=Instance.new('Model');root.Name='ReefGardens';root.Parent=parent
    root:SetAttribute('QCReefScenery',true)
    local P=theme.Palette
    local colors={P.Coral,Color3.fromRGB(231,157,91),P.Purple,P.Shallows}
    local patches=math.clamp(math.floor(config.Seabed.ReefPatchesPerIsland or 18),0,24)
    local surface=config.Ocean.SurfaceY
    for islandIndex,island in ipairs(config.Islands) do
        local biome=theme.Biomes[island.Theme] or theme.Biomes.home
        for index=1,patches do
            local slot=(index-1)%6;local ring=math.floor((index-1)/6)
            local angle=slot*math.pi/3+ring*.37+islandIndex*.31
            local radius=island.Radius+35+ring*49+math.sin(index*1.73+islandIndex)*7
            local x,z=island.X+math.sin(angle)*radius,island.Z+math.cos(angle)*radius
            -- All six habitats face the home fishing pier, in two dense rows.
            if island.Id=='Cove' and index<=6 then
                x=island.X+(slot-2.5)*27
                z=island.Z-island.Radius-42-(slot%2)*32
            end
            local y=heightAt(x,z)
            if y>surface-9 then continue end
            local kind=TYPES[(slot+ring*2)%6+1]
            local patch=Instance.new('Model');patch.Name=kind..'_'..island.Id..'_'..index;patch.Parent=root
            patch:SetAttribute('IslandId',island.Id);patch:SetAttribute('ReefType',kind)
            patch:SetAttribute('GroundY',y);patch:SetAttribute('AnchorX',x);patch:SetAttribute('AnchorZ',z)
            local turn=angle*.73+index*.19
            local horizontal=1.02+(math.sin(index*2.13+islandIndex)+1)*.13
            local shallow=y
            for _,dx in {-12,0,12} do for _,dz in {-12,0,12} do shallow=math.max(shallow,heightAt(x+dx,z+dz)) end end
            local vertical=math.min(horizontal,math.max(.25,(surface-5.6-shallow)/7.2))
            local coral=colors[(index+islandIndex-2)%#colors+1]
            local stone=biome.Rock:Lerp(P.Sand,.36)
            local grass=P.Leaves:Lerp(P.Shallows,.3)
            local function at(lx,lz,up)
                local wx=x+(lx*math.cos(turn)+lz*math.sin(turn))*horizontal
                local wz=z+(-lx*math.sin(turn)+lz*math.cos(turn))*horizontal
                return V(wx,heightAt(wx,wz)+(up or 0)*vertical,wz)
            end
            local function oval(name,lx,lz,up,size,color,rotation,yaw)
                return part(patch,name,V(size.X*horizontal,size.Y*vertical,size.Z*horizontal),
                    CF(at(lx,lz,up))*CFrame.Angles(0,turn+(yaw or 0),rotation or 0),color,'Sphere')
            end
            local function stem(name,lx,lz,low,high,width,color)
                return branch(patch,name,at(lx,lz,low),at(lx,lz,high),width*horizontal,color)
            end
            local function rock(lx,lz,width,height,length)
                return oval('ReefFoundation',lx,lz,height*.5-.12,V(width,height,length),stone)
            end
            local function blades(count)
                for blade=1,count do
                    local a=blade*2.4;local gx,gz=math.sin(a)*(5+blade%3),math.cos(a)*(4+blade%2)
                    local h=(1.5+blade%3*.45)*vertical
                    part(patch,'Seagrass',V(.14*horizontal,h,.65*horizontal),
                        CF(at(gx,gz,.02)+V(0,h*.5,0))*CFrame.Angles(.08,turn+a,.15),grass,'Wedge')
                end
            end
            if kind=='CoralGarden' then
                for cluster=1,3 do
                    local cx,cz=(cluster-2)*5,(cluster%2-.5)*6
                    rock(cx,cz,5.7,1.2,4.7)
                    local tint=colors[(cluster+islandIndex-1)%#colors+1]
                    local joint=at(cx,cz,2.1)
                    branch(patch,'CoralTrunk',at(cx,cz,.35),joint,.55*horizontal,tint)
                    branch(patch,'CoralTrunk',joint,at(cx+.5,cz,4.8),.37*horizontal,tint)
                    for arm=1,3 do
                        local a=arm*2.1;local endpoint=at(cx+math.sin(a)*2.4,cz+math.cos(a)*1.8,3.3+arm*.45)
                        branch(patch,'CoralFork',joint,endpoint,.3*horizontal,tint)
                        part(patch,'CoralTip',V(.43*horizontal,.48*vertical,.43*horizontal),CF(endpoint),tint:Lerp(P.Cream,.3),'Sphere')
                    end
                end
                blades(6)
            elseif kind=='RockRidge' then
                for i=0,6 do rock(-8+i*2.65,math.sin(i*1.15)*2.3,4.8+i%2,2.0+i%3*.65,4.8) end
                oval('ArchPillar',-3,-4.5,1.6,V(3.2,3.6,3.3),stone)
                oval('ArchPillar',3,-4.5,1.6,V(3.2,3.6,3.3),stone)
                oval('ArchCap',0,-4.5,3.5,V(8.2,1.9,3.6),stone:Lerp(P.Cream,.08))
                for shell=1,5 do
                    oval('ReefShell',-7+shell*2.6,4.2,.2,V(.9,.38,.65),P.Cream,(-1)^shell*.16)
                    oval('ShellGroove',-7+shell*2.6,4.2,.38,V(.07,.025,.5),P.WoodLight)
                end
                blades(6)
            elseif kind=='SpongeColony' then
                rock(-4,0,7,1.2,6.2);rock(4,-1,6,1,5.2)
                for sponge=1,9 do
                    local a=sponge*2.4;local r=3.8+sponge%3*2.4
                    local sx,sz=math.sin(a)*r,math.cos(a)*r
                    local height=2.3+sponge%4*.65;local width=1.1+sponge%3*.22
                    local color=P.Gold:Lerp(coral,(sponge%3)*.16)
                    stem('ReefSponge',sx,sz,.02,height,width,color)
                    oval('SpongeRim',sx,sz,height,V(width*1.13,.18,width*1.13),color:Lerp(P.Cream,.2))
                    oval('SpongeOpening',sx,sz,height+.11,V(width*.68,.045,width*.68),P.Ink)
                end
                blades(5)
            elseif kind=='SeaFanGarden' then
                rock(-4,0,7,1.1,5.5);rock(4,-2,6,1.1,5)
                for fan=1,4 do
                    local fx,fz=(fan-2.5)*4.2,fan%2*5-2.5
                    local yaw=.45+(fan-1)*.63
                    local tint=colors[(fan+islandIndex-1)%#colors+1]
                    local crown=at(fx,fz,2.4)
                    branch(patch,'SeaFanStem',at(fx,fz,-.05),crown,.25*horizontal,tint:Lerp(P.Ink,.18))
                    for lobe=-1,1 do
                        oval('SeaFanLobe',fx+math.cos(yaw)*lobe*1.05,fz-math.sin(yaw)*lobe*1.05,
                            3.8-math.abs(lobe)*.25,V(1.9,3.5,.24),tint,-lobe*.28,yaw)
                        branch(patch,'SeaFanVein',crown,at(fx+math.cos(yaw)*lobe*1.25,
                            fz-math.sin(yaw)*lobe*1.25,5-math.abs(lobe)*.2),.085*horizontal,tint:Lerp(P.Cream,.35))
                    end
                end
                blades(4)
            elseif kind=='KelpGrove' then
                rock(-5,-1,7,1.1,5);rock(5,2,6,1.1,5)
                for stalk=1,9 do
                    local a=stalk*2.4;local kx,kz=math.sin(a)*(3+stalk%3*2),math.cos(a)*(3+stalk%2*2)
                    local yaw=a*.4
                    stem('KelpStem',kx,kz,-.03,4.5+stalk%3*.6,.18,grass:Lerp(P.Ink,.14))
                    for side=-1,1,2 do
                        oval('KelpLeaf',kx+math.cos(yaw)*side*.75,kz-math.sin(yaw)*side*.75,
                            2.8+(side+1)*.72,V(1.25,3.4,.2),grass:Lerp(P.LeafLight,stalk%3*.1),-side*.45,yaw)
                    end
                end
                blades(5)
            elseif kind=='TableTerraces' then
                rock(-5,0,7,1.2,5);rock(5,1,7,1.1,5)
                for tower=1,7 do
                    local a=tower*2.4;local tx,tz=math.sin(a)*(3+tower%2*3),math.cos(a)*(3+tower%3)
                    local height=1.2+tower%4*.7;local tint=colors[(tower+islandIndex-1)%#colors+1]
                    stem('TableCoralStem',tx,tz,-.02,height,.45,tint:Lerp(P.Ink,.12))
                    oval('TableCoral',tx,tz,height,V(4.5,.38,3.6),tint)
                    oval('TableCoral',tx+.25,tz,height+.8,V(3.15,.28,2.5),tint:Lerp(P.Cream,.23))
                    stem('TableCoralStem',tx+.25,tz,height,height+.8,.27,tint)
                end
                blades(4)
            end
            -- Protect the full rendered bounds where a wide habitat crosses a hill.
            for _,p in patch:GetDescendants() do
                if p:IsA('BasePart') then
                    local top=p.CFrame.Position.Y+(math.abs(p.CFrame.RightVector.Y)*p.Size.X
                        +math.abs(p.CFrame.UpVector.Y)*p.Size.Y+math.abs(p.CFrame.LookVector.Y)*p.Size.Z)*.5
                    if top>surface-5.1 then p.CFrame=p.CFrame-V(0,top-(surface-5.1),0) end
                end
            end
        end
    end
    return root
end
return Reef
