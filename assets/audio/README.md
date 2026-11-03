# Musket shot

`MusketShot-source.mp3` is the file supplied by the user.
`MusketShot.wav` is the Roblox upload version: original audio from 0.44 to
1.45 seconds, preserving sample rate, stereo, pitch and playback speed.
This removes the ~0.46-second leading silence without cutting the onset.
No gain, compression or pitch processing has been applied.

In-game playback is quieter: volume 0.45 for the uploaded recording and 0.28
for the temporary built-in sound. Playback keeps the original pitch and lasts
at most 0.45 seconds, including a soft 0.18-second fade-out. This envelope is
applied after loading, so a cold asset load cannot consume the playback window.
The stored WAV is unchanged; re-uploading audio is not needed for this adjustment.

Upload `MusketShot.wav` through Creator Dashboard → Creations / Development
Items → Audio (or Studio Asset Manager audio import). Grant the experience
permission to use it, wait for processing, and copy the Audio asset ID.
Set `Musket.ShotSoundId` in `src/combat/Config.luau` to `rbxassetid://<ID>`.
Pull and sync Rojo, then start a fresh Play session.

Alternatively, after uploading, stop Play and connect the Audio ID locally
in Studio Command Bar, then save the place (replace 123456789 with your ID):

```lua
game.ReplicatedStorage.Combat:SetAttribute("MusketShotSoundId", "rbxassetid://123456789")
```

Or select the uploaded **Sound** in Explorer and copy its SoundId directly:

```lua
local selected = game:GetService("Selection"):Get()[1]
assert(selected and selected:IsA("Sound") and selected.SoundId:match("^rbxassetid://%d+$"), "Select the uploaded musket Sound")
game.ReplicatedStorage.Combat:SetAttribute("MusketShotSoundId", selected.SoundId)
```

The saved attribute takes priority over the configuration and is read for
every shot. It must be set outside Play to persist. Granting the experience
audio permission is still required; a valid numeric ID alone cannot grant access.

Roblox cannot play a repository WAV/MP3 or a YouTube URL directly. Until an
uploaded ID is configured, the shot uses the built-in
`rbxasset://sounds/impact_explosion_03.mp3` as a temporary report, not the user's
recording. The rocket whoosh is not restored. Missing or malformed configuration
must not disable firing audio. A correctly formatted but unapproved/inaccessible
Roblox asset will still need its owner to fix permissions/moderation.
The shot remains local to the firing player, as before. Damage and reload
timing do not depend on audio playback.
