"""Read-only Blender geometry/skin/export checks; not an animation visual test."""
import bpy, sys, argparse, json, math, struct
from pathlib import Path
from mathutils import Vector
p=argparse.ArgumentParser();p.add_argument('--out',default='/workspace/outputs/sahur-original')
a=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []);out=Path(a.out)
bpy.ops.wm.open_mainfile(filepath=str(out/'OriginalSahur.blend'))
rig=bpy.data.objects['OriginalSahurRig'];art=[o for o in bpy.data.objects if o.type=='MESH' and o.parent==rig]
assert len(art)>=40 and len(rig.data.bones)==25
weighted=0;blended=0
for o in art:
 assert all(math.isfinite(c) for v in o.data.vertices for c in v.co)
 for v in o.data.vertices:
  assert abs(sum(g.weight for g in v.groups)-1)<1e-5,(o.name,v.index,'unnormalised weights')
  assert all(o.vertex_groups[g.group].name in rig.data.bones for g in v.groups)
  weighted+=1
  if len(v.groups)>1:blended+=1
assert blended>100,'Anatomical joints need smooth transitions, not rigid segmented pieces'
assert sum('Finger' in b.name or 'Thumb' in b.name for b in rig.data.bones)==10
bat=bpy.data.objects['SeparateWoodenClub']
assert len(bat.vertex_groups)==1 and bat.vertex_groups[0].name=='Club'
assert rig.data.bones['Club'].parent.name=='Hand.R'
# A real armature deformation must move the club and forearm, leave torso
# stationary, and preserve the rigid bat's distances during elbow flexion.
def evaluated(obj):
 bpy.context.view_layer.update();mesh=obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
 points=[v.co.copy() for v in mesh.vertices];obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh_clear()
 return points
before=evaluated(bat);body_before=evaluated(bpy.data.objects['CarvedBody']);arm_before=evaluated(bpy.data.objects['ContinuousArm_R'])
bone=rig.pose.bones['Forearm.R'];bone.rotation_mode='XYZ';bone.rotation_euler.x=math.radians(65)
after=evaluated(bat);body_after=evaluated(bpy.data.objects['CarvedBody']);arm_after=evaluated(bpy.data.objects['ContinuousArm_R'])
assert max((x-y).length for x,y in zip(before,after))>.4,'Bat must follow anatomical forearm and palm'
assert max((x-y).length for x,y in zip(arm_before,arm_after))>.2,'Skin must respond to elbow flexion'
assert max((x-y).length for x,y in zip(body_before,body_after))<1e-6,'Moving arm cannot drag the rigid torso'
error=max(abs((before[i]-before[0]).length-(after[i]-after[0]).length) for i in range(0,len(before),17))
assert error<1e-4,'Club must stay rigid while elbow bends'
body=bpy.data.objects['CarvedBody'];assert max(v.co.y for v in body.data.vertices)<1.11,'Face relief must not protrude out of the back'
# GLB is self-contained and contains both mesh data and skinning data.
raw=(out/'OriginalSahur_Rigged.glb').read_bytes();magic,version,total=struct.unpack_from('<III',raw)
assert magic==0x46546c67 and version==2 and total==len(raw)
length,kind=struct.unpack_from('<II',raw,12);assert kind==0x4e4f534a
gltf=json.loads(raw[20:20+length]);assert gltf.get('skins') and len(gltf['meshes'])==len(art)
assert all('uri' not in b for b in gltf['buffers'])
# Check native FBX round trip actually includes geometry AND a usable skeleton.
bpy.ops.object.mode_set(mode='OBJECT') if bpy.context.object and bpy.context.object.mode!='OBJECT' else None
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=str(out/'OriginalSahur_Rigged.fbx'))
assert any(o.type=='ARMATURE' and len(o.data.bones)==25 for o in bpy.data.objects)
assert len([o for o in bpy.data.objects if o.type=='MESH'])==len(art)
assert bpy.data.objects.get('SeparateWoodenClub') is not None
result={'weightedVertices':weighted,'blendedJointVertices':blended,'bones':25,'clubRigidError':error,'fbxRoundTrip':True,'glbSelfContained':True,'note':'Static model/skin verification; not a finished game asset or animation visual test.'}
(out/'validation.json').write_text(json.dumps(result,indent=2));print('PASS original Sahur:',json.dumps(result))
