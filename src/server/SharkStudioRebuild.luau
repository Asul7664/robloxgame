-- This entrypoint is new even in editors which cached the previous editing
-- module. Every invocation loads the current source, then releases its copy.
return function()
    local source=script.Parent:WaitForChild('SharkStudioEdit')
    local copy=assert(source:Clone(),'SharkStudioEdit must be Archivable')
    copy.Name='SharkStudioEditFresh';copy.Parent=source.Parent
    local ok,preview,template=pcall(function() return require(copy).Rebuild() end)
    copy:Destroy()
    if not ok then error(preview,0) end
    return preview,template
end
