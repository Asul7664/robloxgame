-- Edit-time authoring only. The custom template is deliberately not mapped by
-- Rojo, so local Studio edits remain in the saved place across source syncs.
local RunService=game:GetService('RunService')
local Workspace=game:GetService('Workspace')
local Storage=game:GetService('ServerStorage')
local Editor={}
local function factory()
    -- The old preview command may have cached an earlier two-argument factory
    -- in edit mode. Require a fresh copy so Save cannot discard the user's edits.
    local copy=script.Parent:WaitForChild('SharkVisual'):Clone()
    local ok,value=pcall(require,copy)
    copy:Destroy()
    assert(ok,value)
    return value
end
local function guard()
    assert(RunService:IsStudio() and not RunService:IsRunning(),'Stop Play before editing the shark in edit mode.')
end
function Editor.Edit()
    guard()
    local preview=Workspace:FindFirstChild('SharkPreview')
    if preview then
        assert(preview:IsA('Model') and preview:GetAttribute('QCSharkVisual')==true,
            'Another model is named SharkPreview. Rename it before opening the shark.')
    else
        preview=factory().Create(Workspace,CFrame.new(0,12,-10),Storage:FindFirstChild('OceanSharkTemplate'))
        preview.Name='SharkPreview'
    end
    preview:SetAttribute('QCSharkEditorPreview',true)
    game:GetService('Selection'):Set({preview})
    print('Shark opened: Workspace.SharkPreview. Edit its parts, run SharkStudioEdit.Save(), then save the place.')
    return preview
end
function Editor.Save()
    guard()
    local preview=Workspace:FindFirstChild('SharkPreview')
    assert(preview and preview:IsA('Model') and preview:GetAttribute('QCSharkEditorPreview')==true,
        'Open the shark with SharkStudioEdit.Edit() first.')
    -- Stage/validate the clone before replacing the previous working template.
    local model=factory().Create(nil,CFrame.new(),preview)
    model.Name='OceanSharkTemplate'
    local old=Storage:FindFirstChild('OceanSharkTemplate')
    if old then old:Destroy() end
    model.Parent=Storage
    print('Saved to ServerStorage.OceanSharkTemplate. Attacks use this model. Press Ctrl+S to save the place.')
    return model
end
function Editor.Rebuild()
    guard()
    local oldPreview=Workspace:FindFirstChild('SharkPreview')
    assert(not oldPreview or (oldPreview:IsA('Model') and oldPreview:GetAttribute('QCSharkVisual')==true),
        'Another model is named SharkPreview. Rename it before rebuilding the shark.')
    local oldTemplate=Storage:FindFirstChild('OceanSharkTemplate')
    local backups=Storage:FindFirstChild('OceanSharkBackups')
    assert(not backups or backups:IsA('Folder'),'Another object is named OceanSharkBackups.')
    local frame=oldPreview and oldPreview:GetPivot() or CFrame.new(0,12,-10)
    local preview,template
    -- Do not replace either working model until both new copies exist.
    local ok,reason=pcall(function()
        local Shark=factory()
        preview=Shark.Create(nil,frame)
        template=Shark.Create(nil,CFrame.new(),preview)
    end)
    if not ok then
        if preview then preview:Destroy() end
        if template then template:Destroy() end
        error(reason,0)
    end
    if oldPreview or oldTemplate then
        if not backups then backups=Instance.new('Folder');backups.Name='OceanSharkBackups';backups.Parent=Storage end
        local index=1
        while backups:FindFirstChild('Version'..index) do index+=1 end
        local archive=Instance.new('Folder');archive.Name='Version'..index;archive.Parent=backups
        if oldPreview then oldPreview.Parent=archive end
        if oldTemplate then oldTemplate.Parent=archive end
    end
    preview.Name='SharkPreview';preview:SetAttribute('QCSharkEditorPreview',true);preview.Parent=Workspace
    template.Name='OceanSharkTemplate';template.Parent=Storage
    game:GetService('Selection'):Set({preview})
    print('Shark rebuilt and saved as the attack template. Previous models are in ServerStorage.OceanSharkBackups. Press Ctrl+S to save.')
    return preview,template
end
return Editor
