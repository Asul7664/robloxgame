-- Native ModuleScripts/Instances with a real require cache. Editor-only APIs
-- are doubles; Studio rendering, terrain water and physics are not simulated.
local fs=require('@lune/fs')
local luau=require('@lune/luau')
local R=require('@lune/roblox')
local checks=0
local function check(ok,message)checks+=1;assert(ok,message)end
local function child(parent,class,name)
    local object=R.Instance.new(class);object.Name=name;object.Parent=parent;return object
end
local workspace=R.Instance.new('Workspace')
local terrain=child(workspace,'Terrain','Terrain')
local replicated=R.Instance.new('ReplicatedStorage')
local shared=child(replicated,'Folder','QuietCove')
local server=R.Instance.new('Folder');server.Name='QuietCove'
local originals={}
local function module(parent,name,path)
    local object=child(parent,'ModuleScript',name);object.Source=fs.readFile(path)
    originals[object]=true;return object
end
module(shared,'Config','src/shared/Config.luau')
module(shared,'BrainrotExpansion','src/shared/BrainrotExpansion.luau')
module(shared,'VisualTheme','src/shared/VisualTheme.luau')
module(server,'ReefScenery','src/server/ReefScenery.luau')
module(server,'OceanFloor','src/server/OceanFloor.luau')
local studioSource=module(server,'OceanStudio','src/server/OceanStudio.luau')
local isStudio,isRunning=true,false
local services={Workspace=workspace,ReplicatedStorage=replicated,RunService={
    IsStudio=function()return isStudio end,IsRunning=function()return isRunning end,
}}
local cache,loaded={},{}
local execute
execute=function(source)
    if cache[source] then return cache[source] end
    table.insert(loaded,source)
    -- Lune omits WaitForChild. All native module children are already present;
    -- FindFirstChild is equivalent for this fully loaded deterministic scene.
    local text=source.Source:gsub(':WaitForChild%(',':FindFirstChild(')
    local result=luau.load(text,{environment={
        script=source,require=execute,Instance=R.Instance,Vector3=R.Vector3,CFrame=R.CFrame,
        Color3=R.Color3,Enum=R.Enum,game={GetService=function(_,name)return assert(services[name],name)end},
        print=function()end,
    }})()
    cache[source]=result;return result
end
local oldConfig=execute(shared.Config)
check(oldConfig.Seabed.Enabled,'Original configuration starts enabled')
-- Poison the original require result: fresh copies must read its Source, not
-- silently reuse state cached by an older editor command.
oldConfig.Seabed.Enabled=false
local Studio=execute(studioSource)
local floor=Studio.Build()
check(floor and floor.Parent==workspace and floor.Name=='QuietCoveSeabed','Editor builds the actual persistent scene outside Play')
check(floor.Sand and #floor.Sand:GetChildren()>1900,'Actual native sand surface is generated')
check(#floor:GetDescendants()>#floor.Sand:GetChildren()+100,'Real reef geometry is included')
check(shared:FindFirstChild('ConfigOceanFresh')==nil,'Temporary fresh Config module is cleaned after success')
local fresh=0
for _,source in loaded do
    if not originals[source] then
        fresh+=1;check(source.Parent==nil,'Fresh modules do not remain in the saved place')
    end
end
check(fresh>=4,'Config, theme, reef and floor are evaluated from fresh module copies')
local sourceCount=#server:GetChildren()+#shared:GetChildren()
local again=Studio.Build()
check(again==floor,'Repeated edit-mode command does not duplicate geometry')
check(#server:GetChildren()+#shared:GetChildren()==sourceCount,'Repeated command leaves module hierarchy unchanged')
local theme=execute(shared.VisualTheme)
check(math.abs(terrain.WaterTransparency-theme.Water.WaterTransparency)<1e-6,'Editor water preset matches current theme')
local originalReefSource=server.ReefScenery.Source
server.ReefScenery.Source="error('Simulated bad reef source')"
check(not pcall(Studio.Build),'A failed fresh reef source is reported instead of using a stale cached reef')
check(floor.Parent==workspace and workspace.QuietCoveSeabed==floor,'Build failure leaves previous working floor intact')
check(shared:FindFirstChild('ConfigOceanFresh')==nil,'Temporary Config is also released on error')
check(#server:GetChildren()+#shared:GetChildren()==sourceCount,'Failure leaves no temporary module containers')
server.ReefScenery.Source=originalReefSource
check(Studio.Build()==floor,'Restoring source uses the existing compatible floor')
isRunning=true
local partCount=#workspace:GetDescendants()
check(not pcall(Studio.Build) and #workspace:GetDescendants()==partCount,'Play guard prevents editor generation/mutation')
isRunning=false;isStudio=false
check(not pcall(Studio.Build) and #workspace:GetDescendants()==partCount,'Published-server guard prevents editor generation')
for _,source in loaded do
    if not originals[source] then check(source.Parent==nil,'All temporary module copies were destroyed') end
end
print('PASS ocean Studio build: '..checks..' checks (native modules, cache bypass, scene, guards and cleanup)')
