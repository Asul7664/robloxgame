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
    assert(RunService:IsStudio() and not RunService:IsRunning(),'Останови Play: акулу нужно редактировать в режиме редактора.')
end
function Editor.Edit()
    guard()
    local preview=Workspace:FindFirstChild('SharkPreview')
    if preview then
        assert(preview:IsA('Model') and preview:GetAttribute('QCSharkVisual')==true,
            'Имя SharkPreview уже занято другой моделью. Переименуй её перед открытием акулы.')
    else
        preview=factory().Create(Workspace,CFrame.new(0,12,-10),Storage:FindFirstChild('OceanSharkTemplate'))
        preview.Name='SharkPreview'
    end
    preview:SetAttribute('QCSharkEditorPreview',true)
    game:GetService('Selection'):Set({preview})
    print('Акула открыта: Workspace.SharkPreview. Редактируй детали; затем выполни SharkStudioEdit.Save() и сохрани место.')
    return preview
end
function Editor.Save()
    guard()
    local preview=Workspace:FindFirstChild('SharkPreview')
    assert(preview and preview:IsA('Model') and preview:GetAttribute('QCSharkEditorPreview')==true,
        'Сначала открой акулу командой SharkStudioEdit.Edit().')
    -- Stage/validate the clone before replacing the previous working template.
    local model=factory().Create(nil,CFrame.new(),preview)
    model.Name='OceanSharkTemplate'
    local old=Storage:FindFirstChild('OceanSharkTemplate')
    if old then old:Destroy() end
    model.Parent=Storage
    print('Сохранено в ServerStorage.OceanSharkTemplate. Атаки используют эту модель. Нажми Ctrl+S для сохранения места.')
    return model
end
return Editor
