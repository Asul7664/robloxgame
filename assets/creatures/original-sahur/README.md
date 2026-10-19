# Original Sahur: shape and rig review

Open `OriginalSahur.blend` in Blender 4.3+. The PNGs are actual renders of this
model. It is original geometry following the user's references, not a modified
copy of the restricted imported Roblox mesh.

- A tall carved wooden body, expressive eyes, thin articulated limbs and toes.
- Separate tapered wooden club, attached to the anatomical right hand.
- 25-bone skeleton, finger/thumb bones and blended elbow/wrist/knee weights.
- 258,036 triangles for the high-resolution shape study.

Source generator and verification: `tools/sahur_original/README.md`.
The saved Blender file contains the full procedural wood shader. Rigged FBX
and GLB are generated alongside renders when rebuilding; their base colours
are exported, but procedural wood textures still need UV baking for Roblox.

This review asset is not mapped by Rojo. The installed boss and gameplay are
unchanged. Game-resolution topology, texture baking, animation clips and a
Roblox rig/controller adapter are the following stage after the shape review.
