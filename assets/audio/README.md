# Musket shot

`MusketShot-source.mp3` is the file supplied by the user.
`MusketShot.wav` is the Roblox upload version: original audio from 0.44 to
1.45 seconds, preserving sample rate, stereo, pitch and playback speed.
This removes the ~0.46-second leading silence without cutting the onset.
No gain, compression or pitch processing has been applied.

Upload `MusketShot.wav` through Creator Dashboard → Creations / Development
Items → Audio (or Studio Asset Manager audio import). Grant the experience
permission to use it, wait for processing, and copy the Audio asset ID.
Set `Musket.ShotSoundId` in `src/combat/Config.luau` to `rbxassetid://<ID>`.
Pull and sync Rojo, then start a fresh Play session.

Roblox cannot play a repository WAV/MP3 or a YouTube URL directly. Until an
uploaded ID is configured, the shot is silent; the old rocket whoosh was removed.
The shot remains local to the firing player, as before. Damage and reload
timing do not depend on audio playback.
