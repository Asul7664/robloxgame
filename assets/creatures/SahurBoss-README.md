# Imported Sahur encounter

The user's imported model is retained, not replaced by the earlier procedural Sahur.
`SahurBoss.rbxm` / `.rbxmx` contain its 16 original parts, 15 Motor6D joints,
materials, textures, wrap data and attachments. The two original Scripts have
been removed without executing them; geometry, joint offsets and attachments
are doubled and the root is normalized to the origin. A clean template contains
no Script, LocalScript or ModuleScript. Source preparation is reproducible with:

```sh
/workspace/robloxgame-tools/bin/lune run tools/sahur/prepare_import.luau original.rbxm
```

## One-time Studio installation

1. Pull `codex/quiet-cove-download`, connect Rojo, and wait for scripts to sync.
2. Stop Play. Select ONLY the user's imported Sahur model in Explorer. It may
   be in Workspace; alternatively import the cleaned `SahurBoss.rbxm` first.
3. Run in Studio Command Bar:

```lua
require(game.ServerScriptService.QuietCove.SahurStudioInstall).Selected()
```

4. Save the place. The installer removes scripts/package links, scales a fresh
   model x2 (idempotently), and moves it to `ServerStorage.SahurBoss`. It also
   installs a clone as `ReplicatedStorage.QuietCove.CreatureAssets.sahur`, so the
   same geometry appears in the existing catch presentation. The old Sahur
   catch template is replaced. An already doubled cleaned asset is not doubled
   again, and the earlier Command Bar `QC_SahurBaseScale` marker is respected.

For an immediate test, restart Play after pulling updates, switch Studio to
**Server**, and run in Command Bar:

```lua
local ok, reason = game.ServerStorage.StudioSahur:Invoke(game.Players:GetPlayers()[1])
assert(ok, reason)
```

This teleports the first test player to Dunes and starts the same encounter
immediately. The fish still requires victory. The BindableFunction exists only
in Studio, never in a published server.

The one-time local clone preserves native MeshPart mesh data and texture
references. Neither template is mapped to Rojo, avoiding unsupported mesh
property changes; existing unknown models are preserved by the project config.
Source code continues to sync normally. Do not run the original imported scripts.

## Gameplay

Reeling in `sahur` at **Пески Сахура / Dunes** releases fishing controls and
starts a personal encounter. Sahur makes exactly one high, continuous leap
from the water onto the island's central ground lane (north of its center,
clear of the temple and trees). An include-filtered raycast finds the actual
ground surface, and the imported rig's root/pivot offsets are respected.
He turns toward the fisher before landing, absorbs impact for .24 seconds,
then walks at 14 studs/s. He remains engaged within the 145-stud encounter
leash, follows walking routes around obstacles, and stops before unsafe edges.
All subsequent jumping and climbing are disabled in Humanoid and pathfinding;
an unexpected jump waypoint is rejected. Waypoint progress uses horizontal
distance so the enlarged rig's elevated root cannot stall a floor-level route.
He has 280 HP and a visible health bar. Only the fisher's existing weapons can
damage this encounter; there is no new weapon or client damage remote.

A bat attack has a .52-second visible windup, .18-second active swing and
.58-second recovery. `SahurAttackClip.luau` authors a rear-foot load, raised
backswing, fast diagonal **downward** strike, follow-through and recovery.
Native two-bone leg IK keeps both ankle positions and sole orientations fixed
through the weight transfer. The free arm balances the body and the neck
counter-rotates toward the committed opponent. The renderer fades the first
.10 seconds from its preceding movement pose, then follows the exact server
curve without extra contact smoothing lag.

The imported auto-rigger split the SAME bat across RightUpperArm,
RightLowerArm and RightHand. Its R15 elbow/wrist/grip are inside the bat,
not the anatomical elbow/palm. Both right elbow and wrist therefore stay
neutral in **every** walk, leap, landing and attack pose. The shoulder and
thorax move the intact right-arm/bat assembly; no original mesh is replaced.
A future separately rigged club would allow independent elbow articulation.

`SahurClub.luau` computes server-side forward kinematics from original Motor6D
baselines and the same clip. Two capsules fitted to the embedded physical
hulls follow the real shaft and thick end. During the active window the server
samples at most 1/120 second apart and sweeps them against actual body boxes,
excluding root parts/accessories/tools. Contact must have clear line of sight;
a successful hit uses the existing Damage entrypoint exactly once per swing.
There is no broad frontal damage cone or client hit report. Existing server
IFrame immunity blocks damage. A sidestep outside the actual trajectory misses.

He approaches within 7.3 studs, smoothly turns before committing and keeps
his strike direction fixed. Think/path refreshes take .075/.65 seconds. Walking
cadence follows measured planar velocity, with loaded knees, ankle rollover,
pelvis weight transfer and free-arm balance; blocked feet settle rather than
marching in place. The one arrival leap remains the only permitted jump.

An editable native KeyframeSequence is in
`ReplicatedStorage.QuietCove.SahurHeavyStrike` via Rojo and in
`assets/animations/SahurHeavyStrike.rbxm/.rbxmx`. It is a 120 Hz sampled export
of the same authored curve (Action, non-looping), not a second runtime track.
Regenerate it after editing the source or phase lengths:

```sh
lune run tools/sahur/export_attack.luau
```

No animation upload/ID or model reinstall is needed for these code updates.
See `assets/animations/README.md` for editor use and export details.

The server uses the existing damage entry for both weapons and the boss. Fish,
XP, bestiary and quest progress are committed through the existing CatchLedger
ONLY after victory. Death, respawn, leaving the encounter/145-stud leash, or a
180-second timeout grants nothing and cleans up the encounter. Disconnecting
cannot convert an unfinished encounter into a saved catch. On other islands,
the existing ordinary Sahur catch behavior is unchanged.

Tune `src/shared/SahurBossSettings.luau` for health, speed, damage, ranges and
timing. `SpawnArcHeight` controls the one-time leap, `RiseTime` its duration,
and `StrideLength` walking cadence relative to actual movement. Poses are in
`src/shared/SahurBossPose.luau`; there are no animation IDs
to upload. No third-party model scripts are reused.

## Validation and limits

Run from the repository root:

```sh
lune run tests/sahur_boss.luau
lune run tests/sahur_animation.luau
lune run tests/sahur_attack_clip.luau
lune run tests/sahur_club.luau
lune run tests/sahur_reward.luau
lune run tests/combat.luau
lune run tests/quest_server.luau
lune run tests/side_dodge.luau
rojo build default.project.json -o /tmp/quiet-cove-scripts.rbxlx
```

These checks exercise asset serialization, actual service lifecycle, attacks,
IFrames, reward transactions, persistence, and pose continuity through engine
doubles. They do not run Studio rendering, physics, pathfinding or verify access
to the original externally hosted meshes/textures. The build is a script/model
overlay, not an exported complete user place. In Studio, verify the water exit,
single high leap onto actual land, no later jumps, foot placement, bat swing,
health bar, both weapons, dodging, death/reset cleanup,
and a single inventory award after victory.
