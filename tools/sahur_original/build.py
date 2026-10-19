"""Original, editable Sahur study. Blender 4.3: blender -b -t 6 --python tools/sahur_original/build.py
This is an original geometry/rig preview, not a replacement of the installed NPC.
"""
import bpy, math, json, argparse, sys
from pathlib import Path
from mathutils import Vector
parser=argparse.ArgumentParser();parser.add_argument('--out',default='/workspace/outputs/sahur-original');parser.add_argument('--draft',action='store_true')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT=Path(args.out);OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
ART=[]; BONES={}; OWN={}
sys.path.insert(0,str(Path(__file__).resolve().parent))
from face import body_radius, relief, build_face
from limbs import build_limbs

def mat(name,color,rough=.38,wood=False):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough
 if wood:
  coord=n.new('ShaderNodeTexCoord');mapping=n.new('ShaderNodeVectorMath');mapping.operation='MULTIPLY';mapping.inputs[1].default_value=(2.0,2.0,.065)
  noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=7;noise.inputs['Detail'].default_value=3;noise.inputs['Roughness'].default_value=.65
  l.new(coord.outputs['Object'],mapping.inputs[0]);l.new(mapping.outputs[0],noise.inputs['Vector'])
  ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.12;ramp.color_ramp.elements[0].color=(*(c*.80 for c in color),1)
  ramp.color_ramp.elements[1].position=.88;ramp.color_ramp.elements[1].color=(*(min(1,c*1.12) for c in color),1)
  l.new(noise.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],p.inputs['Base Color'])
  if name=='Warm carved oak':
   # Smooth brown orbital paint is part of the wood, not a separate dark ring.
   masks=[]
   for sign in (-1,1):
    sub=n.new('ShaderNodeVectorMath');sub.operation='SUBTRACT';sub.inputs[1].default_value=(sign*.475,0,7.34);l.new(coord.outputs['Object'],sub.inputs[0])
    scale=n.new('ShaderNodeVectorMath');scale.operation='MULTIPLY';scale.inputs[1].default_value=(1/.42,0,1/.24);l.new(sub.outputs[0],scale.inputs[0])
    dot=n.new('ShaderNodeVectorMath');dot.operation='DOT_PRODUCT';l.new(scale.outputs[0],dot.inputs[0]);l.new(scale.outputs[0],dot.inputs[1])
    neg=n.new('ShaderNodeMath');neg.operation='MULTIPLY';neg.inputs[1].default_value=-1;l.new(dot.outputs['Value'],neg.inputs[0])
    exp=n.new('ShaderNodeMath');exp.operation='EXPONENT';l.new(neg.outputs[0],exp.inputs[0]);masks.append(exp)
   total=n.new('ShaderNodeMath');total.operation='MAXIMUM';l.new(masks[0].outputs[0],total.inputs[0]);l.new(masks[1].outputs[0],total.inputs[1])
   factor=n.new('ShaderNodeMapRange');factor.inputs['From Min'].default_value=0;factor.inputs['From Max'].default_value=1;factor.inputs['To Min'].default_value=1;factor.inputs['To Max'].default_value=.10;l.new(total.outputs[0],factor.inputs['Value'])
   colour=n.new('ShaderNodeMixRGB');colour.blend_type='MULTIPLY';colour.inputs[0].default_value=1;l.new(ramp.outputs[0],colour.inputs[1]);l.new(factor.outputs['Result'],colour.inputs[2]);l.new(colour.outputs[0],p.inputs['Base Color'])
  bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.04;bump.inputs['Distance'].default_value=.005;l.new(noise.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal'])
 return m
WOOD=mat('Warm carved oak',(.30,.105,.027),.37,True)
END=mat('Golden end grain',(.36,.17,.045),.43,True)
LID=mat('Sculpted eyelid',(.18,.050,.018),.36,True)
WHITE=mat('Warm sclera',(.87,.84,.74),.22)
IRIS=mat('Deep umber iris',(.055,.024,.012),.24)
BLACK=mat('Pupil',(.003,.002,.001),.14)
SHADOW=mat('Mouth crease',(.034,.007,.003),.50)

def add(o,name,material,bone='Body'):
 o.name=name;o.data.materials.clear();o.data.materials.append(material)
 for f in o.data.polygons:f.use_smooth=True
 ART.append(o);OWN[o]=bone;return o

def sphere(name,pos,scale,material=WOOD,bone='Body',segments=48,rings=32):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=pos)
 o=bpy.context.object;o.scale=scale;return add(o,name,material,bone)

def path(name,pts,r,material=WOOD,bone='Body'):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=12;c.bevel_depth=r;c.bevel_resolution=4
 s=c.splines.new('BEZIER');s.bezier_points.add(len(pts)-1)
 for p,v in zip(s.bezier_points,pts):p.co=v;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o)
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')
 return add(bpy.context.object,name,material,bone)

def lathe(name,profile,material=WOOD,bone='Body',origin=(0,0,0),direction=(0,0,1),seg=128,face=False):
 vs=[];fs=[]
 for z,r in profile:
  for j in range(seg):
   a=math.tau*j/seg;x=r*math.cos(a);y=r*math.sin(a)
   if face: y-=relief(x,z)*max(0,-math.sin(a))**3
   vs.append((x,y,z))
 for i in range(len(profile)-1):
  for j in range(seg):
   a=i*seg+j;b=i*seg+(j+1)%seg;fs.append((a,b,b+seg,a+seg))
 fs.extend((tuple(reversed(range(seg))),tuple((len(profile)-1)*seg+j for j in range(seg))))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],fs);mesh.update()
 o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.location=origin;o.rotation_euler=Vector((0,0,1)).rotation_difference(Vector(direction)).to_euler()
 return add(o,name,material,bone)

def limb(name,a,b,r1,r2,bone):
 a,b=Vector(a),Vector(b);d=(b-a).length
 prof=[(-r1*.4,.002),(-r1*.22,r1*.75),(0,r1)]
 prof += [(d*t,r1*(1-t)+r2*t) for t in (.15,.3,.45,.6,.75,.9)]
 prof += [(d,r2),(d+r2*.22,r2*.75),(d+r2*.4,.002)]
 return lathe(name,prof,WOOD,bone,a,b-a,48)

# Taller, subtly tapered trunk; continuous human facial planes.
profile=[(3.05+(8.12-3.05)*i/192,body_radius(3.05+(8.12-3.05)*i/192)) for i in range(193)]
body=lathe('CarvedBody',profile,face=True,seg=256)
lathe('Crown',[(8.112,.01),(8.112,.98),(8.13,1.005),(8.155,.975),(8.163,.02)],END,seg=128)
api=dict(bpy=bpy,body=body,Vector=Vector,sphere=sphere,path=path,lathe=lathe,limb=limb,add=add,
         WOOD=WOOD,END=END,WHITE=WHITE,IRIS=IRIS,BLACK=BLACK,SHADOW=SHADOW,
         ART=ART,OWN=OWN,BONES=BONES)
build_face(api)
handle,tip=build_limbs(api)

# Separate solid wooden bat: thin handle, long tapered barrel, rounded heavy end.
direction=(tip-handle).normalized();length=(tip-handle).length
prof=[(-.18,.001),(-.16,.078),(-.10,.094),(-.04,.090),(0,.058),(.25,.062),(.68,.074),(1.02,.105),(1.45,.145),(2.1,.205),(length-.30,.258),(length-.10,.260),(length,.220),(length+.075,.12),(length+.10,.001)]
bat=lathe('SeparateWoodenClub',prof,WOOD,'Club',handle,direction,96)
BONES['Club']=(handle,tip,'Hand.R')

# Apply geometry transforms before assigning real vertex weights.
for o in ART:
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
armdata=bpy.data.armatures.new('OriginalSahurSkeleton');rig=bpy.data.objects.new('OriginalSahurRig',armdata);bpy.context.collection.objects.link(rig)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT')
for name,(head,tail,parent) in BONES.items():
 b=armdata.edit_bones.new(name);b.head=head;b.tail=tail
 if parent:b.parent=armdata.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT');rig.show_in_front=True
for o in ART:
 spec=OWN[o]
 def group(name):return o.vertex_groups.get(name) or o.vertex_groups.new(name=name)
 if isinstance(spec,str):group(spec).add(list(range(len(o.data.vertices))),1,'REPLACE')
 else:
  typ,side,joint_z,wrist_z=spec
  names=('UpperArm.'+side,'Forearm.'+side,'Hand.'+side) if typ=='ARM' else ('Thigh.'+side,'Shin.'+side,'Foot.'+side)
  gs=[group(n) for n in names]
  for v in o.data.vertices:
   upper=max(0,min(1,(v.co.z-joint_z+.15)/.30))
   hand=0 if typ=='LEG' else max(0,min(1,(wrist_z+.075-v.co.z)/.15))
   weights=(upper,(1-upper)*(1-hand),(1-upper)*hand)
   for g,w in zip(gs,weights):
    if w>0:g.add([v.index],w,'REPLACE')
 mod=o.modifiers.new('DeformSkeleton','ARMATURE');mod.object=rig;o.parent=rig
# Grip is a separate bone parented to the anatomical palm, not part of forearm.
assert(len(bat.vertex_groups)==1 and bat.vertex_groups[0].name=='Club')
assert(len(armdata.bones)==25)
triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in ART)
stats={'meshes':len(ART),'bones':len(BONES),'triangles':triangles,'separateClub':True,'revision':2,'stage':'reference proportion and facial sculpt revision; not installed in game'}
(OUT/'stats.json').write_text(json.dumps(stats,indent=2))
# Export only character art, excluding lights/floor/cameras.
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for o in ART:o.select_set(True)
bpy.ops.export_scene.fbx(filepath=str(OUT/'OriginalSahur_Rigged.fbx'),use_selection=True,object_types={'MESH','ARMATURE'},add_leaf_bones=False,bake_anim=False,axis_forward='-Z',axis_up='Y',mesh_smooth_type='FACE')
# GLB carries procedural material base colours; Blender file holds full wood shader.
bpy.ops.export_scene.gltf(filepath=str(OUT/'OriginalSahur_Rigged.glb'),export_format='GLB',use_selection=True,export_animations=False)
# Neutral studio review. These images are renders of the actual exported geometry.
floormat=mat('Studio floor',(.025,.036,.041),.68)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,.020));floor=bpy.context.object;floor.name='REVIEW_FLOOR';floor.data.materials.append(floormat)
def light(name,pos,energy,size,color):
 d=bpy.data.lights.new(name,'AREA');d.energy=energy;d.shape='DISK';d.size=size;d.color=color;o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);o.location=pos;o.rotation_euler=(Vector((0,0,4))-o.location).to_track_quat('-Z','Y').to_euler()
light('Warm key',(-5,-7,11),1800,3.5,(1,.79,.50));light('Soft fill',(5,-4,7),170,5,(.70,.82,1));light('Rim',(-1,4,10),1000,4,(1,.78,.48))
camdata=bpy.data.cameras.new('ReviewCamera');cam=bpy.data.objects.new('ReviewCamera',camdata);bpy.context.collection.objects.link(cam)
scene=bpy.context.scene;scene.camera=cam;camdata.type='ORTHO';camdata.ortho_scale=9.5
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=False
scene.render.resolution_x=1000;scene.render.resolution_y=1200;scene.render.resolution_percentage=65 if args.draft else 100
if args.draft:scene.cycles.samples=16
scene.world.color=(.045,.045,.045);scene.view_settings.view_transform='AgX'
try:scene.view_settings.look='AgX - Medium High Contrast'
except TypeError:pass
views=[('Front',(-.5,-18,5.9)),('Side',(18,-.5,5.8)),('ThreeQuarter',(7,-24,7.6)),('Face',(4,-22,7.0))]
if args.draft:views=[view for view in views if view[0]=='ThreeQuarter']
for name,pos in views:
 cam.location=pos
 target=(0,-.2,6.85) if name=='Face' else (-.45,0,4.05)
 cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
 if name=='Face':
  camdata.ortho_scale=3.5;scene.render.resolution_x=900;scene.render.resolution_y=900
 scene.render.filepath=str(OUT/(name+'.png'))
 if name=='ThreeQuarter':bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'OriginalSahur.blend'),compress=True)
 bpy.ops.render.render(write_still=True)
print('ORIGINAL_SAHUR',json.dumps(stats))
