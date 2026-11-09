-- Persistent edit-mode build using fresh module copies, even after an older
-- WorldVisuals/Config was required in Studio's Command Bar.
local RunService=game:GetService('RunService')
local Studio={}
function Studio.Build()
    assert(RunService:IsStudio() and not RunService:IsRunning(),'Останови Play перед созданием дна в редакторе.')
    local shared=game:GetService('ReplicatedStorage'):WaitForChild('QuietCove')
    local copies=Instance.new('Folder');copies.Name='OceanEditorModules'
    local configCopy=shared:WaitForChild('Config'):Clone()
    configCopy.Name='ConfigOceanFresh';configCopy.Parent=shared
    local ok,result=pcall(function()
        for _,name in {'ReefScenery','OceanFloor'} do
            local copy=script.Parent:WaitForChild(name):Clone();copy.Parent=copies
        end
        local theme=shared:WaitForChild('VisualTheme'):Clone();theme.Parent=copies
        local config=require(configCopy)
        local visualTheme=require(theme)
        local workspace=game:GetService('Workspace')
        for key,value in pairs(visualTheme.Water) do workspace.Terrain[key]=value end
        local model=require(copies.OceanFloor).Apply(workspace,config,visualTheme)
        assert(model,'Не удалось создать дно: проверь Config.Seabed.Enabled и имя QuietCoveSeabed в Workspace.')
        print('Дно и рифы готовы: Workspace.QuietCoveSeabed. Нажми Ctrl+S для сохранения места.')
        return model
    end)
    configCopy:Destroy();copies:Destroy()
    if not ok then error(result,0) end
    return result
end
return Studio
