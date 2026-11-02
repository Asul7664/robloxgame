-- Studio Command Bar only. MeshPart geometry is cloned locally, never rebuilt
-- through Rojo's read-only MeshContent properties. Nothing runs automatically.
local RunService = game:GetService('RunService')
local Install = {}
function Install.Selected()
    assert(RunService:IsStudio() and not RunService:IsRunning(), 'Stop Play before installing Sahur')
    local selected=game:GetService('Selection'):Get()
    assert(#selected==1 and selected[1]:IsA('Model'), 'Select only the imported Sahur model in Explorer')
    local model=selected[1]
    if model:FindFirstChild('ClubTip',true) then return Install.OriginalSelected() end
    local root=assert(model:FindFirstChild('HumanoidRootPart'), 'Missing HumanoidRootPart')
    local humanoid=assert(model:FindFirstChildOfClass('Humanoid'), 'Missing Humanoid')
    local removed=0
    for _,item in model:GetDescendants() do
        if item:IsA('LuaSourceContainer') or item:IsA('PackageLink') then item:Destroy();removed+=1 end
    end
    if model:GetAttribute('QCSizeMultiplier')~=2 then
        local base=model:GetAttribute('QC_SahurBaseScale') or model:GetScale()
        model:ScaleTo(base*2)
        model:SetAttribute('QCSizeMultiplier',2)
    end
    model.PrimaryPart=root;model:PivotTo(CFrame.new())
    humanoid.AutomaticScalingEnabled=false
    humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
    local storage=game:GetService('ServerStorage')
    local old=storage:FindFirstChild('SahurBoss')
    if old and old~=model then old:Destroy() end
    model.Name='SahurBoss';model.Parent=storage
    local shared=game:GetService('ReplicatedStorage'):WaitForChild('QuietCove')
    local assets=shared:FindFirstChild('CreatureAssets')
    if not assets then assets=Instance.new('Folder');assets.Name='CreatureAssets';assets.Parent=shared end
    local oldCatch=assets:FindFirstChild('sahur')
    if oldCatch then oldCatch:Destroy() end
    local portraitModel=model:Clone();portraitModel.Name='sahur';portraitModel.Parent=assets
    print(('Sahur installed: %d scripts/package links removed, size x2. Save the place.'):format(removed))
    return model
end
-- The uploaded FBX is selected in EDIT mode. Prepare a clone first; the old
-- working boss and catch are only moved to backups after validation succeeds.
function Install.OriginalSelected()
    assert(RunService:IsStudio() and not RunService:IsRunning(), 'Stop Play before installing Sahur')
    local selected=game:GetService('Selection'):Get()
    assert(#selected==1 and selected[1]:IsA('Model'), 'Select the imported OriginalSahur model')
    local source=selected[1]
    local shared=game:GetService('ReplicatedStorage'):WaitForChild('QuietCove')
    local adapter=require(shared:WaitForChild('SahurOriginalRig'))
    local model=source:Clone()
    local ok,result=pcall(function()
        local skin
        for _,item in model:GetDescendants() do
            if item:IsA('LuaSourceContainer') or item:IsA('PackageLink') then item:Destroy()
            elseif item:IsA('MeshPart') then
                assert(not skin,'Expected one OriginalSahur skinned mesh');skin=item
            end
        end
        assert(skin,'OriginalSahurSkin is missing; import the FBX through 3D Importer')
        local base=assert(model:FindFirstChild('Root',true),'Skeleton Root is missing')
        local body=assert(model:FindFirstChild('Body',true),'Skeleton Body is missing')
        local facing=assert(model:FindFirstChild('Facing',true),'Facing marker missing; use the game FBX')
        assert(base:IsA('Bone') and body:IsA('Bone') and facing:IsA('Bone'),'Import with skinning enabled')
        assert(not model:FindFirstChild('HumanoidRootPart'),'Select a fresh FBX import, not the installed boss')
        -- Normalize to a 12-stud boss, independently of importer unit settings.
        model:ScaleTo(model:GetScale()*12/skin.Size.Y)
        local unit=(body.WorldCFrame.Position-base.WorldCFrame.Position).Magnitude/2.89
        local foot=base.WorldCFrame.Position-Vector3.new(0,.14*unit,0)
        local forward=facing.WorldCFrame.Position-base.WorldCFrame.Position
        forward=Vector3.new(forward.X,0,forward.Z)
        assert(forward.Magnitude>.01,'Invalid Facing marker')
        local root=Instance.new('Part');root.Name='HumanoidRootPart';root.Size=Vector3.new(2.2,3,2)*unit
        local center=foot+Vector3.new(0,4.5*unit,0)
        root.CFrame=CFrame.lookAt(center,center+forward.Unit);root.Transparency=1;root.Anchored=true;root.Parent=model
        for _,part in model:GetDescendants() do
            if part:IsA('BasePart') and part~=root then
                part.Anchored=false;part.CanCollide=false;part.CanTouch=false;part.Massless=true
                local weld=Instance.new('WeldConstraint');weld.Part0=root;weld.Part1=part;weld.Parent=root
            end
        end
        local humanoid=model:FindFirstChildOfClass('Humanoid') or Instance.new('Humanoid')
        humanoid.Parent=model;humanoid.HipHeight=3*unit;humanoid.AutomaticScalingEnabled=false
        humanoid.RigType=Enum.HumanoidRigType.R15
        humanoid.RequiresNeck=false;humanoid.BreakJointsOnDeath=false
        humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
        model.PrimaryPart=root;model:SetAttribute('QCSahurOriginal',true);model:SetAttribute('QCSahurUnit',unit)
        model:SetAttribute('QCSizeMultiplier',2)
        assert(adapter.Capture(model),'Incomplete OriginalSahur skeleton; old boss was kept')
        model:PivotTo(root.PivotOffset)
        return model
    end)
    if not ok then model:Destroy();error(result,0) end
    local storage=game:GetService('ServerStorage')
    local backups=storage:FindFirstChild('QCSahurBackups')
    if not backups then backups=Instance.new('Folder');backups.Name='QCSahurBackups';backups.Parent=storage end
    local assets=shared:FindFirstChild('CreatureAssets')
    if not assets then assets=Instance.new('Folder');assets.Name='CreatureAssets';assets.Parent=shared end
    local catch=model:Clone();catch.Name='sahur'
    -- Keep the import for rollback without leaving an extra static boss in play.
    source.Parent=backups
    local old=storage:FindFirstChild('SahurBoss');if old then old.Parent=backups end
    old=assets:FindFirstChild('sahur');if old then old.Parent=backups end
    model.Name='SahurBoss';model.Parent=storage;catch.Parent=assets
    print('Our OriginalSahur installed as boss and catch. Previous templates are in ServerStorage.QCSahurBackups. Save the place.')
    return model
end
return Install
