-- Real frames/instances: repair only the saved static ferry prop, not moving boats.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local R=require("@lune/roblox")
local checks=0
local function check(ok,message)checks+=1;assert(ok,message)end
local theme=luau.load(fs.readFile("src/shared/VisualTheme.luau"),{environment={Color3=R.Color3}})()
local scenery=luau.load(fs.readFile("src/server/WorldScenery.luau"),{environment={
    script={Parent={WaitForChild=function(_,name)return name end}},require=function()return{}end,
    Instance=R.Instance,Vector3=R.Vector3,CFrame=R.CFrame,Color3=R.Color3,Enum=R.Enum,
}})()
local map=R.Instance.new("Model")
local hull=R.Instance.new("Part");hull.Name="BoatHull";hull.Size=R.Vector3.new(9,2,17);hull.Anchored=true;hull.Parent=map
local deck=R.Instance.new("Part");deck.Name="BoatDeck";deck.Size=R.Vector3.new(7,.5,14);deck.Anchored=true;deck.Parent=map
local originalHullSize,originalDeckSize=hull.Size,deck.Size
local function apply()scenery.Apply(map,nil,{Islands={}},theme)end
local function verify(frame)
    check(hull.CFrame==frame,"Ferry repair moved the hull")
    local localDeck=hull.CFrame:ToObjectSpace(deck.CFrame)
    check((localDeck.Position-R.Vector3.new(0,1.2,0)).Magnitude<.0001,"Deck is offset from the hull")
    check(localDeck.LookVector:Dot(R.Vector3.new(0,0,-1))>.9999 and localDeck.UpVector.Y>.9999,"Deck is rotated relative to the hull")
    check(hull.Size==originalHullSize and deck.Size==originalDeckSize,"Alignment resized gameplay geometry")
    check(hull.Anchored and deck.Anchored and hull.CanCollide and deck.CanCollide,"Alignment changed original physics")
    local planks=0
    for _,p in ipairs(map.QCScenery.Ferry:GetChildren()) do
        check(p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch,"Detail interferes with gameplay")
        if p.Name=="DeckPlank" then
            planks+=1
            local relative=deck.CFrame:ToObjectSpace(p.CFrame)
            check(math.abs(relative.Position.X)<.0001 and relative.UpVector.Y>.9999,"Plank is skewed")
            check(math.abs(relative.Position.Y-p.Size.Y/2-deck.Size.Y/2)<.0001,"Plank floats above the deck")
            check(math.abs(relative.Position.Z)+p.Size.Z/2<=deck.Size.Z/2+.0001,"Plank extends past the deck")
            check(p.Size.X<=deck.Size.X,"Plank exceeds deck width")
        end
    end
    check(planks==10,"Expected ten aligned deck planks")
end
for _,frame in ipairs({R.CFrame.new(24,1,-78),R.CFrame.new(-12,3,41)*R.CFrame.Angles(.05,.7,-.03)}) do
    hull.CFrame=frame;deck.CFrame=frame*R.CFrame.new(.8,2,-.7)*R.CFrame.Angles(.1,.2,.05)
    local storedHullFrame=hull.CFrame
    apply();verify(storedHullFrame)
    local folder=map.QCScenery.Ferry;local count=#map:GetDescendants()
    apply();check(map.QCScenery.Ferry==folder and #map:GetDescendants()==count,"Repeated alignment duplicates planks")
end
-- The freshly generated correct pose keeps exactly its original frame.
hull.CFrame=R.CFrame.new(24,1,-78);deck.CFrame=R.CFrame.new(24,2.2,-78)
local original=deck.CFrame;apply();check((original.Position-deck.CFrame.Position).Magnitude<.00001,"Correct saved placement drifts")
-- An unanchored pair is not this static prop and must not be controlled by the art pass.
hull.Anchored=false;deck.CFrame=R.CFrame.new(5,6,7);local movingFrame=deck.CFrame
apply();check(deck.CFrame==movingFrame,"Art pass interfered with an unanchored boat")
print("PASS ferry visuals: "..checks.." alignment, contact, migration and safety checks")
