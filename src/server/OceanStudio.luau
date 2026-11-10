-- Persistent edit-mode build using fresh module copies, even after an older
-- WorldVisuals/Config was required in Studio's Command Bar.
local RunService=game:GetService('RunService')
local Studio={}
function Studio.Build()
    assert(RunService:IsStudio() and not RunService:IsRunning(),'Stop Play before building the seabed in edit mode.')
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
        assert(model,'Could not build the seabed. Check Config.Seabed.Enabled and the QuietCoveSeabed name in Workspace.')
        print('Seabed and reefs ready: Workspace.QuietCoveSeabed. Press Ctrl+S to save the place.')
        return model
    end)
    configCopy:Destroy();copies:Destroy()
    if not ok then error(result,0) end
    return result
end
return Studio
