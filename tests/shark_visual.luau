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
    local count=0
    local names={}
    for _,p in shark:GetDescendants() do
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
    check(count<=32,"Shark remains a small transient visual")
    for _,name in {"Body","Snout","Belly","OpenMouth","Eye","DorsalFin","PectoralFin","UpperTail","LowerTail","UpperTooth"} do
        check(names[name],"Recognizable shark feature: "..name)
    end
    local restored=R.deserializeModel(R.serializeModel({shark},true))[1]
    check(restored.PrimaryPart==restored.Body and #restored:GetDescendants()==count,"Shark survives native Roblox serialization")
    parent:Destroy()
end
print("PASS shark visual: "..checks.." geometry, safety and serialization checks")
