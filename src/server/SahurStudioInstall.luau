-- Studio Command Bar only. MeshPart geometry is cloned locally, never rebuilt
-- through Rojo's read-only MeshContent properties. Nothing runs automatically.
local RunService = game:GetService('RunService')
local Install = {}
function Install.Selected()
    assert(RunService:IsStudio() and not RunService:IsRunning(), 'Stop Play before installing Sahur')
    local selected=game:GetService('Selection'):Get()
    assert(#selected==1 and selected[1]:IsA('Model'), 'Select only the imported Sahur model in Explorer')
    local model=selected[1]
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
return Install
