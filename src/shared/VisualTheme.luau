-- Quiet Cove art direction. World surfaces, atmosphere and UI share this palette.
-- Edit here, then run tools/build_visual_theme.luau to refresh the Studio preset.
local rgb = Color3.fromRGB
local P = {
    Grass = rgb(112, 191, 119), Leaves = rgb(60, 145, 112), LeafLight = rgb(152, 207, 117),
    Water = rgb(56, 157, 191), Shallows = rgb(106, 209, 213), Sand = rgb(246, 223, 173),
    Wood = rgb(164, 116, 80), WoodDark = rgb(109, 77, 57), WoodLight = rgb(210, 166, 115),
    Gold = rgb(255, 207, 112), Purple = rgb(178, 150, 226), Coral = rgb(241, 144, 160),
    Cream = rgb(255, 247, 223), Rock = rgb(126, 151, 161), Ink = rgb(27, 50, 78),
}
return {
    Version = 3,
    Palette = P,
    Biomes = {
        home = {Ground=P.Grass, Leaves=P.Leaves, Accent=P.Shallows, Rock=P.Rock},
        reef = {Ground=P.Sand, Leaves=P.Leaves, Accent=P.Coral, Rock=rgb(94, 171, 184)},
        moss = {Ground=rgb(101, 179, 125), Leaves=rgb(55, 135, 103), Accent=rgb(166, 210, 126), Rock=rgb(115, 145, 133)},
        sand = {Ground=rgb(235, 202, 143), Leaves=rgb(78, 158, 117), Accent=P.Gold, Rock=rgb(181, 147, 111)},
        bloom = {Ground=rgb(146, 199, 154), Leaves=rgb(226, 164, 197), Accent=rgb(232, 153, 184), Rock=rgb(165, 155, 178)},
        storm = {Ground=rgb(119, 143, 172), Leaves=rgb(125, 141, 188), Accent=P.Purple, Rock=rgb(96, 116, 146)},
    },
    Lighting = {
        ClockTime=13, Brightness=2, ExposureCompensation=0, GlobalShadows=true,
        ShadowSoftness=0.4, Ambient=rgb(100, 112, 132), OutdoorAmbient=rgb(139, 155, 172),
        -- ColorShift is additive sunlight. Near-white clips wood/leaf color to orange/lime.
        ColorShift_Top=rgb(12, 8, 3), ColorShift_Bottom=rgb(0, 0, 0),
        EnvironmentDiffuseScale=0.45, EnvironmentSpecularScale=0.2,
        FogColor=rgb(190, 224, 249), FogStart=1800, FogEnd=6500,
    },
    -- New unified lighting API; separate from properties for older Studio versions.
    LightingStyle = "Soft", PrioritizeLightingQuality = true,
    Effects = {
        QCColor = {Class="ColorCorrectionEffect", Properties={
            Enabled=true, Brightness=0, Contrast=0.03, Saturation=0.02, TintColor=rgb(255,255,255)}},
        QCBloom = {Class="BloomEffect", Properties={Enabled=true, Intensity=0.035, Size=18, Threshold=0.99}},
        -- Sparse haze keeps the separated islands visible from boats.
        QCAtmosphere = {Class="Atmosphere", Properties={Density=0.13, Offset=0.1, Haze=0.3,
            Glare=0, Color=rgb(190,222,255), Decay=rgb(128,162,205)}},
    },
    Water = {WaterColor=P.Water, WaterTransparency=0.3, WaterReflectance=0.22,
        WaterWaveSize=0.15, WaterWaveSpeed=7},
    UI = {Bg=rgb(26, 46, 66), Panel=rgb(40, 70, 89), Ink=rgb(255, 249, 232),
        Muted=rgb(187, 213, 232), Aqua=P.Shallows, Gold=P.Gold, Red=P.Coral},
}
