-- Export the production shark, including native Sphere SpecialMesh scaling.
-- lune run tools/preview_shark.luau [/workspace/outputs/shark-v2.json]
local fs=require('@lune/fs')
local luau=require('@lune/luau')
local R=require('@lune/roblox')
local serde=require('@lune/serde')
local process=require('@lune/process')
local factory=luau.load(fs.readFile('src/server/SharkVisual.luau'),{environment={
    Instance=R.Instance,Vector3=R.Vector3,CFrame=R.CFrame,Color3=R.Color3,Enum=R.Enum,
}})()
local shark=factory.Create(nil,R.CFrame.new())
local out={Parts={},RendererNote='Production geometry; approximate Blender lighting, not a Roblox Studio screenshot.'}
for _,part in shark:GetDescendants() do
    if part:IsA('BasePart') then
        local mesh=part:FindFirstChildOfClass('SpecialMesh')
        local color=part.Color
        local row={Name=part.Name,Class=part.ClassName,Frame={part.CFrame:GetComponents()},
            Size={part.Size.X,part.Size.Y,part.Size.Z},Color={color.R,color.G,color.B},
            Transparency=part.Transparency,Shape=part:IsA('Part') and part.Shape.Name or 'Wedge'}
        if mesh then row.MeshType=mesh.MeshType.Name;row.MeshScale={mesh.Scale.X,mesh.Scale.Y,mesh.Scale.Z} end
        table.insert(out.Parts,row)
    end
end
local path=process.args[1] or '/workspace/outputs/shark-v2.json'
fs.writeFile(path,serde.encode('json',out,true))
print('Exported '..#out.Parts..' production shark parts to '..path)
