-- Actual Roblox geometry/serialization, independent of Studio rendering.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local R=require("@lune/roblox")
local Shark=luau.load(fs.readFile("src/server/SharkVisual.luau"),{environment={
    Instance=R.Instance, Vector3=R.Vector3, CFrame=R.CFrame, Color3=R.Color3, Enum=R.Enum,
}})()
local checks=0
local function check(ok,message) checks+=1;assert(ok,message) end
for _,frame in {R.CFrame.new(),R.CFrame.new(115,2,-130)*R.CFrame.Angles(.3,1.1,-.2)} do
    local parent=R.Instance.new("Folder")
    local shark=Shark.Create(parent,frame)
    check(shark.Parent==parent and shark.PrimaryPart==shark.Body,"Create returns a rooted model")
    check(shark:GetAttribute("QCSharkVisual")==true,"Owned model has a clear visual-only tag")
    check(shark:GetAttribute('QCSharkRevision')==2,'New model has an explicit remake revision')
    local count=0
    local names={}
    for _,p in shark:GetDescendants() do
        if p:IsA('SpecialMesh') then
            check(p.MeshType==R.Enum.MeshType.Sphere and p.Scale==R.Vector3.one,'Native sphere mesh follows all three parent Size axes')
            check(p.Parent:IsA('Part') and p.Parent.Shape==R.Enum.PartType.Block,'Ellipsoids never rely on native Ball aspect ratios')
            continue
        end
        check(p:IsA("BasePart"),"No scripts, remotes, forces or connections are installed")
        count+=1;names[p.Name]=true
        check(p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch,"Shark is visual-only physics")
        check(p.Size.X>0 and p.Size.Y>0 and p.Size.Z>0,"No degenerate fin wedges")
        for _,n in {p.CFrame:GetComponents()} do check(n==n and math.abs(n)<math.huge,"Finite native part frame") end
        local localFrame=shark.PrimaryPart.CFrame:ToObjectSpace(p.CFrame)
        check(math.abs(localFrame.RightVector:Dot(localFrame.UpVector))<.0001,"Fin basis is orthogonal")
        if p.Name=="Snout" then check(localFrame.Position.Z < -2,"Shark faces local -Z") end
        if p.Name=="TailStock" then check(localFrame.Position.Z > 3,"Tail remains behind the shark") end
    end
    check(count<=48,"Shark remains a small transient visual")
    check(shark.Body.Size.Z/shark.Body.Size.X>2.4,'Body is a streamlined spindle, not a sphere')
    check(shark.Eye.Size.X<.25,'Eyes sit close to the head rather than floating as large balls')
    check(shark.OpenMouth.Size.Z<.2,'Mouth is a thin opening, not a separate protruding sphere')
    local function inside(name,point)
        local p=shark:FindFirstChild(name)
        local v=p.CFrame:PointToObjectSpace(frame:PointToWorldSpace(point));local half=p.Size*.5
        return (v.X/half.X)^2+(v.Y/half.Y)^2+(v.Z/half.Z)^2<1
    end
    for _,join in {
        {'Snout','UpperJaw',R.Vector3.new(0,-.3,-3.55)},
        {'UpperJaw','OpenMouth',R.Vector3.new(0,-.65,-3.95)},
        {'OpenMouth','LowerJaw',R.Vector3.new(0,-.83,-3.95)},
        {'Snout','Eye',R.Vector3.new(-1.06,.22,-3.02)},
    } do
        -- Eye occurs twice; FindFirstChild selects anatomical left (first).
        check(inside(join[1],join[3]) and inside(join[2],join[3]),'Visible volumes overlap: '..join[1]..' / '..join[2])
    end
    for z=-4,5.3,.1 do
        local connected=false
        for _,name in {'Body','Snout','TailStock'} do
            local p=shark:FindFirstChild(name)
            local point=p.CFrame:PointToObjectSpace(frame:PointToWorldSpace(R.Vector3.new(0,0,z)))
            local half=p.Size*.5
            if (point.X/half.X)^2+(point.Y/half.Y)^2+(point.Z/half.Z)^2<=1 then connected=true end
        end
        check(connected,'Body/head/tail form an uninterrupted centreline at '..tostring(z))
    end
    for _,name in {"Body","Snout","UpperJaw","Belly","OpenMouth","Eye","DorsalFin","PectoralFin","UpperTail","LowerTail","UpperTooth"} do
        check(names[name],"Recognizable shark feature: "..name)
    end
    local restored=R.deserializeModel(R.serializeModel({shark},true))[1]
    check(restored.PrimaryPart==restored.Body and #restored:GetDescendants()==#shark:GetDescendants(),"Shark survives native Roblox serialization")
    parent:Destroy()
end
print("PASS shark visual: "..checks.." geometry, safety and serialization checks")
