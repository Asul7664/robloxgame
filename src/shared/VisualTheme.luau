-- Quiet Cove art direction. World surfaces, atmosphere and UI share this palette.
-- Edit here, then run tools/build_visual_theme.luau to refresh the Studio preset.
local rgb = Color3.fromRGB
local P = {
    Grass = rgb(100, 204, 88), Leaves = rgb(44, 165, 104), LeafLight = rgb(139, 225, 93),
    Water = rgb(36, 134, 199), Shallows = rgb(67, 205, 224), Sand = rgb(255, 226, 161),
    Wood = rgb(183, 120, 70), WoodDark = rgb(113, 73, 51), WoodLight = rgb(222, 165, 100),
    Gold = rgb(255, 202, 88), Purple = rgb(176, 131, 255), Coral = rgb(255, 128, 145),
    Cream = rgb(255, 247, 223), Rock = rgb(126, 151, 161), Ink = rgb(27, 50, 78),
}
return {
    Version = 1,
    Palette = P,
    Biomes = {
        home = {Ground=P.Grass, Leaves=P.Leaves, Accent=P.Shallows, Rock=P.Rock},
        reef = {Ground=P.Sand, Leaves=P.Leaves, Accent=P.Coral, Rock=rgb(94, 171, 184)},
        moss = {Ground=rgb(83, 190, 111), Leaves=rgb(36, 146, 100), Accent=rgb(158, 236, 109), Rock=rgb(107, 147, 131)},
        sand = {Ground=rgb(249, 204, 119), Leaves=rgb(58, 177, 116), Accent=P.Gold, Rock=rgb(192, 143, 92)},
        bloom = {Ground=rgb(125, 210, 143), Leaves=rgb(255, 158, 202), Accent=rgb(255, 137, 188), Rock=rgb(168, 153, 186)},
        storm = {Ground=rgb(115, 137, 177), Leaves=rgb(107, 126, 202), Accent=P.Purple, Rock=rgb(83, 104, 148)},
    },
    Lighting = {
        ClockTime=13, Brightness=2.6, ExposureCompensation=0, GlobalShadows=true,
        ShadowSoftness=0.4, Ambient=rgb(112, 125, 151), OutdoorAmbient=rgb(151, 167, 187),
        ColorShift_Top=rgb(255, 240, 216), ColorShift_Bottom=rgb(0, 0, 0),
        EnvironmentDiffuseScale=0.65, EnvironmentSpecularScale=0.45,
        FogColor=rgb(190, 224, 249), FogStart=1800, FogEnd=6500,
    },
    -- New unified lighting API; separate from properties for older Studio versions.
    LightingStyle = "Soft", PrioritizeLightingQuality = true,
    Effects = {
        QCColor = {Class="ColorCorrectionEffect", Properties={
            Enabled=true, Brightness=0, Contrast=0.06, Saturation=0.12, TintColor=rgb(255,255,255)}},
        QCBloom = {Class="BloomEffect", Properties={Enabled=true, Intensity=0.12, Size=20, Threshold=0.95}},
        -- Sparse haze keeps the separated islands visible from boats.
        QCAtmosphere = {Class="Atmosphere", Properties={Density=0.16, Offset=0.1, Haze=0.45,
            Glare=0.08, Color=rgb(190,222,255), Decay=rgb(128,162,205)}},
    },
    Water = {WaterColor=P.Water, WaterTransparency=0.3, WaterReflectance=0.22,
        WaterWaveSize=0.15, WaterWaveSpeed=7},
    UI = {Bg=rgb(20, 40, 69), Panel=rgb(33, 62, 94), Ink=rgb(255, 249, 232),
        Muted=rgb(187, 213, 232), Aqua=P.Shallows, Gold=P.Gold, Red=P.Coral},
}
