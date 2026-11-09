-- Short-lived, asset-free shark for the ocean hazard. Forward is local -Z.
-- The owning service moves/destroys the whole model; these parts never collide.
local Shark = {}
local V, CF = Vector3.new, CFrame.new
local BLUE = Color3.fromRGB(79, 124, 147)
local FIN = Color3.fromRGB(57, 95, 119)
local BELLY = Color3.fromRGB(223, 233, 226)
local INK = Color3.fromRGB(16, 29, 39)
local TOOTH = Color3.fromRGB(255, 247, 221)

local function part(model, origin, name, size, frame, color, wedge)
    local p = Instance.new(wedge and "WedgePart" or "Part")
    p.Name = name; p.Size = size; p.CFrame = origin * frame; p.Color = color
    p.Material = Enum.Material.SmoothPlastic
    p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false
    p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
    if not wedge then
        -- Native Ball parts do not freely stretch on all axes in Studio.
        -- Built-in Sphere meshes scale with the enclosing block's Size, so
        -- the actual editor silhouette matches these elongated proportions.
        p.Shape = Enum.PartType.Block
        local mesh=Instance.new('SpecialMesh');mesh.MeshType=Enum.MeshType.Sphere
        mesh.Scale=V(1,1,1);mesh.Parent=p
    end
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
    model:SetAttribute('QCSharkRevision',2)
    local body = part(model,frame,"Body",V(3.05,2.15,7.5),CF(),BLUE)
    model.PrimaryPart = body
    -- Broad overlapping volumes form one spindle, not a string of spheres.
    part(model,frame,"Snout",V(2.45,1.6,3.4),CF(0,-.08,-2.55),BLUE)
    part(model,frame,"UpperJaw",V(1.8,.62,1.3),CF(0,-.42,-3.55),BLUE)
    part(model,frame,"Belly",V(2.45,.9,6.5),CF(0,-.75,-.25),BELLY)
    part(model,frame,"OpenMouth",V(1.48,.34,.12),CF(0,-.69,-3.95),INK)
    part(model,frame,"LowerJaw",V(1.55,.27,1.15),CF(0,-.89,-3.5),BELLY)
    for _,side in {-1,1} do
        part(model,frame,"Eye",V(.19,.23,.17),CF(side*1.1,.22,-3.02),INK)
        part(model,frame,"EyeGlint",V(.042,.042,.042),CF(side*1.165,.26,-3.075),TOOTH)
        for i=0,3 do
            local z=-1.55+i*.25
            local x=1.525*math.sqrt(1-(z/3.75)^2-(.05/1.075)^2)+.012
            part(model,frame,"Gill",V(.055,.36,.085),
                CF(side*x,-.05,z)*CFrame.Angles(0,0,side*-.16),INK)
        end
        triangle(model,frame,"PectoralFin",V(side*1.15,-.4,-.65),V(side*3,-.65,1.55),
            V(side*.95,-.5,1.5),FIN,.14)
        triangle(model,frame,"PelvicFin",V(side*.7,-.45,2.1),V(side*1.4,-.6,3.15),
            V(side*.35,-.4,3.0),FIN,.11)
    end
    triangle(model,frame,"DorsalFin",V(0,.8,-.8),V(0,.8,1.5),V(0,2.25,.55),FIN,.16)
    triangle(model,frame,"RearDorsalFin",V(0,.3,2.9),V(0,.3,3.85),V(0,.95,3.45),FIN,.1)
    part(model,frame,"TailStock",V(1.1,.8,3.4),CF(0,-.03,3.9),BLUE)
    triangle(model,frame,"UpperTail",V(0,-.05,4.65),V(0,1.85,6.1),V(0,.18,5.22),FIN,.15)
    triangle(model,frame,"LowerTail",V(0,-.05,4.65),V(0,-1.35,5.9),V(0,-.2,5.22),FIN,.15)
    for _,x in {-.35,.35} do
        triangle(model,frame,"UpperTooth",V(x-.105,-.59,-4.025),V(x+.105,-.59,-4.025),
            V(x,-.74,-4.025),TOOTH,.04)
    end
    triangle(model,frame,"LowerTooth",V(-.105,-.82,-4.025),V(.105,-.82,-4.025),
        V(0,-.72,-4.025),TOOTH,.04)
    model.Parent = parent
    return model
end
return Shark
