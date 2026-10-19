# Original Sahur — geometry review

An original mesh study following the user's wooden cylindrical character and
separate tapered club references. This does not use the restricted imported
Roblox meshes. It does not overwrite the installed NPC or its controller.

Build the actual editable Blender model and three review renders:

```sh
blender -b -t 6 --python tools/sahur_original/build.py
blender -b -t 6 --python tools/sahur_original/verify.py
```

`-- --out /absolute/path` overrides `/workspace/outputs/sahur-original`.
Outputs: `OriginalSahur.blend`, rigged FBX, self-contained GLB, front/side/three
quarter PNGs, geometry stats and verification report. Preview PNGs are actual
Blender renders, not generated concept images.

The 25-bone skeleton contains anatomical upper arm, forearm and hand chains,
finger/thumb bones, thighs/shins/feet, and a separate club bone parented to the
right hand. Smooth elbow/wrist and knee vertex weights let arms and legs bend.
Only the club's own bone influences the club, keeping it rigid while the hand
moves. The log itself remains rigid.

This is a high-resolution shape/rig study (~258k triangles), **not a drop-in
Roblox NPC**. Blender retains the procedural wood shader. FBX/GLB currently
export material base colours, not the procedural wood grain shown in the
renders. After the shape review: game-resolution topology, UV/texture baking,
authored locomotion/attack clips, Roblox import, and controller/hit-volume
integration are still required. The original installed Sahur remains active.

The verifier checks normalised weights, continuous joint weighting, actual
armature deformation, rigid club motion, unaffected torso, self-contained GLB,
and native FBX mesh/skeleton round-trip. It does not verify Studio import,
Roblox physics, or human quality of a future attack animation.
