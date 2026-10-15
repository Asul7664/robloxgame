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
starts a personal encounter. Sahur first rises vertically out of the water,
then moves onto that island's fishing deck. He walks toward the fisher at
11 studs/s within 95 studs, uses line-of-sight/pathfinding, and stops at edges.
He has 280 HP and a visible health bar. Only the fisher's existing weapons can
damage this encounter; there is no new weapon or client damage remote.

A bat attack has a .52-second visible windup, .18-second swing and .58-second
recovery. The body, shoulders, elbow, free arm and legs animate together on each
client using server timestamps. Hit direction commits at windup; sidestepping
out of the strike or existing server IFrame immunity avoids its 24 damage.

The server uses the existing damage entry for both weapons and the boss. Fish,
XP, bestiary and quest progress are committed through the existing CatchLedger
ONLY after victory. Death, respawn, leaving the encounter/145-stud leash, or a
180-second timeout grants nothing and cleans up the encounter. Disconnecting
cannot convert an unfinished encounter into a saved catch. On other islands,
the existing ordinary Sahur catch behavior is unchanged.

Tune `src/shared/SahurBossSettings.luau` for health, speed, damage, ranges and
timing. Poses are in `src/shared/SahurBossPose.luau`; there are no animation IDs
to upload. No third-party model scripts are reused.

## Validation and limits

Run from the repository root:

```sh
lune run tests/sahur_boss.luau
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
foot placement, bat swing, health bar, both weapons, dodging, death/reset cleanup,
and a single inventory award after victory.
