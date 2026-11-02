return {
	MaxHealth = 100,
	Saber = {
		Damage = 18,
		Range = 7.5,
		Cooldown = 0.42,
		Windup = 0.16,
		Active = 0.12,
		Recover = 0.22,
		Hitbox = Vector3.new(4.4, 3.6, 5.4),
	},
	Musket = {
		-- Upload assets/audio/MusketShot.wav to Roblox, then paste its Audio ID.
		ShotSoundId = "",
		-- Temporary built-in report until our uploaded file has an Audio asset ID.
		-- This is not the supplied recording; never leave the weapon silent.
		ShotFallbackSoundId = "rbxasset://sounds/impact_explosion_03.mp3",
		ShotFallbackVolume = 0.55,
		ShotVolume = 0.85,
		ShotPlaybackSpeed = 1,
		ShotSoundLifetime = 3,
		Damage = 28,
		Range = 140,
		Cooldown = 0.85,
		Reload = 1.7,
		Magazine = 1,
	},
}
