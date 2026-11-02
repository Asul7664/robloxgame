"""Native FBX round-trip check; not Roblox Studio import validation."""
import bpy, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/creatures/original-sahur/game'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=str(OUT/'OriginalSahur.fbx'))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
rigs=[o for o in bpy.context.scene.objects if o.type=='ARMATURE']
assert len(meshes)==1 and len(rigs)==1
skin,rig=meshes[0],rigs[0]
assert len(rig.data.bones)==27
assert rig.data.bones['Club'].parent.name=='Hand.R'
assert rig.data.bones['ClubTip'].parent.name=='Club'
assert rig.data.bones['Forearm.R'].parent.name=='UpperArm.R'
assert rig.data.bones['Facing'].parent.name=='Root'
triangles=sum(len(p.vertices)-2 for p in skin.data.polygons)
assert triangles<=20000
for vertex in skin.data.vertices:
    assert vertex.groups and len(vertex.groups)<=4
    assert abs(sum(g.weight for g in vertex.groups)-1)<.002
assert skin.data.uv_layers and len(skin.data.materials)==1
textures=[n.image for n in skin.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
assert textures and tuple(textures[0].size)==(2048,2048)
report=dict(nativeFBXRoundTrip=True,meshCount=1,bones=27,triangles=triangles,
    normalizedWeights=True,bakedColorAtlas=True,studioImportVerified=False)
(OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS original game FBX:',json.dumps(report))
