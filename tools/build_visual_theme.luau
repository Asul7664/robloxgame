-- Run from the repository root: lune run tools/build_visual_theme.luau
-- Same preset for edit-time Rojo lighting and runtime WorldVisuals.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local roblox=require("@lune/roblox")
local theme=luau.load(fs.readFile("src/shared/VisualTheme.luau"),{
    environment={Color3=roblox.Color3},
})()
local lighting=roblox.Instance.new("Lighting")
lighting.Name="Lighting"
for key,value in pairs(theme.Lighting) do lighting[key]=value end
lighting.LightingStyle=roblox.Enum.LightingStyle[theme.LightingStyle]
lighting.PrioritizeLightingQuality=theme.PrioritizeLightingQuality
for name,settings in pairs(theme.Effects) do
    local effect=roblox.Instance.new(settings.Class)
    effect.Name=name
    for key,value in pairs(settings.Properties) do effect[key]=value end
    effect.Parent=lighting
end
fs.writeDir("assets/environment")
fs.writeFile("assets/environment/Lighting.rbxmx",roblox.serializeModel({lighting},true))
print("Built shared Soft lighting preset for Rojo and runtime")
