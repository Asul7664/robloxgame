-- Short-lived, asset-free shark for the ocean hazard. Forward is local -Z.
-- The owning service moves/destroys the whole model; these parts never collide.
local Shark = {}
local V, CF = Vector3.new, CFrame.new
local BLUE = Color3.fromRGB(65, 100, 121)
local FIN = Color3.fromRGB(48, 77, 97)
local BELLY = Color3.fromRGB(223, 235, 228)
local INK = Color3.fromRGB(16, 29, 39)
local TOOTH = Color3.fromRGB(255, 247, 221)

local function part(model, origin, name, size, frame, color, wedge)
    local p = Instance.new(wedge and "WedgePart" or "Part")
    p.Name = name; p.Size = size; p.CFrame = origin * frame; p.Color = color
    p.Material = Enum.Material.SmoothPlastic
    p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false
    p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
    if not wedge then p.Shape = Enum.PartType.Ball end
    p.Parent = model
    return p
end

-- Two right-triangle wedges produce a filled, pointed fin from either side.
local function triangle(model, origin, name, a, b, c, color, thickness)
    local ab, ac, bc = b-a, c-a, c-b
    if ab:Dot(ab) > ac:Dot(ac) and ab:Dot(ab) > bc:Dot(bc) then c,a = a,c
    elseif ac:Dot(ac) > bc:Dot(bc) and ac:Dot(ac) > ab:Dot(ab) then a,b = b,a end
    ab, ac, bc = b-a, c-a, c-b
    local right = ac:Cross(ab).Unit
    local back = bc.Unit
    local up = back:Cross(right).Unit
    local height = math.abs(ab:Dot(up))
    local first, second = math.abs(ab:Dot(back)), math.abs(ac:Dot(back))
    if first > .002 then
        part(model, origin, name, V(thickness,height,first),
            CFrame.fromMatrix((a+b)*.5,right,up,back),color,true)
    end
    if second > .002 then
        part(model, origin, name, V(thickness,height,second),
            CFrame.fromMatrix((a+c)*.5,-right,up,-back),color,true)
    end
end

function Shark.Create(parent, frame, template)
    if template then
        assert(template:IsA('Model') and template.PrimaryPart
            and template.PrimaryPart:IsA('BasePart') and template.PrimaryPart:IsDescendantOf(template),
            'Shark template needs a PrimaryPart inside its Model')
        local model=assert(template:Clone(),'Shark template must be Archivable')
        for _,item in model:GetDescendants() do
            if item:IsA('LuaSourceContainer') or item:IsA('PackageLink') then item:Destroy()
            elseif item:IsA('BasePart') then
                item.Anchored=true;item.CanCollide=false;item.CanTouch=false;item.CanQuery=false
            end
        end
        model.Name='OceanShark';model:SetAttribute('QCSharkVisual',true)
        model:SetAttribute('QCSharkEditorPreview',nil)
        model:PivotTo(frame)
        model.Parent=parent
        return model
    end
    local model = Instance.new("Model"); model.Name = "OceanShark"
    model:SetAttribute("QCSharkVisual",true)
    local body = part(model,frame,"Body",V(3.1,2.35,6.25),CF(),BLUE)
    model.PrimaryPart = body
    part(model,frame,"Snout",V(2.5,1.7,3.1),CF(0,.02,-2.6),BLUE)
    part(model,frame,"Belly",V(2.55,1.05,5.8),CF(0,-.78,-.35),BELLY)
    part(model,frame,"OpenMouth",V(1.82,.82,.38),CF(0,-.36,-4.08),INK)
    part(model,frame,"LowerJaw",V(1.92,.4,1.28),CF(0,-.83,-3.66),BELLY)
    for _,side in {-1,1} do
        part(model,frame,"Eye",V(.4,.43,.42),CF(side*1.04,.38,-3.44),INK)
        part(model,frame,"EyeGlint",V(.095,.095,.095),CF(side*1.09,.49,-3.62),TOOTH)
        for i=0,1 do
            part(model,frame,"Gill",V(.075,.46,.12),
                CF(side*1.49,-.03,-1.18+i*.36)*CFrame.Angles(0,0,side*-.2),INK)
        end
        triangle(model,frame,"PectoralFin",V(side*1.2,-.4,-.9),V(side*3.6,-.7,1.25),
            V(side*1.2,-.4,1.25),FIN,.18)
    end
    triangle(model,frame,"DorsalFin",V(0,.95,-.8),V(0,.95,1.65),V(0,3.05,1.2),FIN,.22)
    part(model,frame,"TailStock",V(1.15,.95,2.8),CF(0,-.02,3.35),BLUE)
    triangle(model,frame,"UpperTail",V(0,0,4.15),V(0,2.05,5.9),V(0,.35,5.05),FIN,.2)
    triangle(model,frame,"LowerTail",V(0,0,4.15),V(0,-1.45,5.55),V(0,-.25,5.05),FIN,.2)
    -- A few broad ivory teeth read at player distance without noisy tiny parts.
    for _,x in {-.5,.5} do
        triangle(model,frame,"UpperTooth",V(x-.18,-.12,-4.29),V(x+.18,-.12,-4.29),
            V(x,-.43,-4.29),TOOTH,.08)
    end
    triangle(model,frame,"LowerTooth",V(-.19,-.67,-4.25),V(.19,-.67,-4.25),
        V(0,-.43,-4.25),TOOTH,.08)
    model.Parent = parent
    return model
end
return Shark
