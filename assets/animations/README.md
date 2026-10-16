# Sahur heavy club strike

`SahurHeavyStrike.rbxm` and `.rbxmx` contain the same native, editable
`KeyframeSequence` for `assets/creatures/SahurBoss.rbxm`. The sequence uses
Action priority and does not loop. It contains no scripts or uploaded IDs.

The authored runtime source is `src/shared/SahurAttackClip.luau`. The export
bakes its continuous Hermite motion and planted-foot IK at 120 Hz, also
retaining each named author pose. Every exported CFrame is sampled from that
source. Linear native easing connects the baked samples; between samples this
approximates the continuous runtime curve rather than introducing a second
independent animation. The game runs the source module directly, so publishing
this sequence is optional and no animation ID is needed.

The imported asset includes its club across `RightUpperArm`, `RightLowerArm`
and `RightHand`. Its elbow and wrist remain neutral to keep the club rigid.
The apparent `RightHand` and `RightGripAttachment` are near the club tip, not
the real palm. Do not bend these two joints unless the model is re-rigged with
a separate club first.

After editing the source or phase lengths, regenerate both files from the
repository root:

```sh
lune run tools/sahur/export_attack.luau
```

An optional first argument changes the bake rate between 30 and 240 Hz. The
exporter validates every time, Pose name/hierarchy, easing value and CFrame
after both binary and XML round-trips. Importing a sequence into Studio makes
it available as animation data; editing that copy does not rewrite the runtime
source automatically.

Rojo also maps the sequence to `ReplicatedStorage.QuietCove.SahurHeavyStrike`.
To edit a local copy, copy it into an `AnimSaves` Folder under a preview copy
of the original rig, then load it through Animation Editor. The runtime uses
`SahurAttackClip`; editor changes do not automatically modify that module.
