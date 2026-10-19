"""Original, editable Sahur study. Blender 4.3: blender -b -t 6 --python tools/sahur_original/build.py
This is an original geometry/rig preview, not a replacement of the installed NPC.
"""
import bpy, math, json, argparse, sys
from pathlib import Path
from mathutils import Vector
parser=argparse.ArgumentParser();parser.add_argument('--out',default='/workspace/outputs/sahur-original')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT=Path(args.out);OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
ART=[]; BONES={}; OWN={}

def mat(name,color,rough=.38,wood=False):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough
 if wood:
  coord=n.new('ShaderNodeTexCoord');mapping=n.new('ShaderNodeVectorMath');mapping.operation='MULTIPLY';mapping.inputs[1].default_value=(3.2,3.2,.12)
  noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=7;noise.inputs['Detail'].default_value=3;noise.inputs['Roughness'].default_value=.65
  l.new(coord.outputs['Object'],mapping.inputs[0]);l.new(mapping.outputs[0],noise.inputs['Vector'])
  ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.12;ramp.color_ramp.elements[0].color=(*(c*.58 for c in color),1)
  ramp.color_ramp.elements[1].position=.88;ramp.color_ramp.elements[1].color=(*(min(1,c*1.30) for c in color),1)
  l.new(noise.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],p.inputs['Base Color'])
  bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.14;bump.inputs['Distance'].default_value=.014;l.new(noise.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal'])
 return m
WOOD=mat('Warm carved oak',(.37,.135,.035),.32,True)
END=mat('Golden end grain',(.49,.245,.075),.43,True)
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
 def mound(x,z,cx,cz,sx,sz,d):return d*math.exp(-((x-cx)/sx)**2-((z-cz)/sz)**2)
 for z,r in profile:
  for j in range(seg):
   a=math.tau*j/seg;x=r*math.cos(a);y=r*math.sin(a)
   if face:
    d=mound(x,z,0,6.66,.125,.48,.32)+mound(x,z,0,6.21,.19,.14,.28)
    d+=mound(x,z,0,5.72,.54,.23,.16)+mound(x,z,0,5.38,.40,.22,.08)
    for sign in (-1,1):
     d+=mound(x,z,sign*.57,6.15,.33,.28,.22)+mound(x,z,sign*.48,7.10,.37,.18,.13)
     d+=mound(x,z,sign*.49,6.66,.34,.40,-.16)
    y-=d*max(0,-math.sin(a))**10
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

# Tall, continuous carved body. Facial relief belongs to the actual surface.
profile=[]
for i in range(161):
 z=2.85+5.27*i/160;u=i/160
 radius=1.065+.025*math.sin(math.pi*u)-.075*math.exp(-u*50)-.075*math.exp(-(1-u)*50)
 profile.append((z,radius))
body=lathe('CarvedBody',profile,face=True,seg=192)
lathe('Crown',[(8.112,.01),(8.112,.98),(8.128,1.015),(8.155,.975),(8.163,.02)],END,seg=128)
# Subtle end-grain rings, not chunky bark strips or jewellery.
for i,r in enumerate((.22,.43,.66,.85)):
 pts=[]
 for j in range(65):
  a=math.tau*j/64;rr=r*(1+.018*math.sin(a*3+i))
  pts.append((rr*math.cos(a),rr*math.sin(a),8.164))
 path('EndgrainRing_%d'%i,pts,.0035,LID)

# Eye surfaces nest inside sculpted upper/lower lids; dark iris fills most of
# the eye to keep the reference's slightly uncanny, recognisable expression.
for sign,side in ((-1,'R'),(1,'L')):
 x=sign*.49
 sphere('Socket_'+side,(x,-.945,6.66),(.465,.20,.59),LID)
 sphere('Eye_'+side,(x,-1.095,6.65),(.368,.232,.43),WHITE)
 sphere('Iris_'+side,(x-sign*.025,-1.299,6.65),(.278,.060,.31),IRIS)
 sphere('Pupil_'+side,(x-sign*.025,-1.349,6.65),(.227,.027,.257),BLACK)
 sphere('Catchlight_'+side,(x-.072,-1.376,6.795),(.068,.014,.074),WHITE,segments=24,rings=16)
 # Sculpted lids follow orbital shape instead of encircling it with a torus.
 path('UpperLid_'+side,[(x-.365,-1.105,6.70),(x-.25,-1.23,6.99),(x,-1.27,7.075),(x+.25,-1.23,6.99),(x+.365,-1.105,6.70)],.048,LID)
 path('LowerLid_'+side,[(x-.35,-1.11,6.53),(x-.19,-1.25,6.30),(x+.08,-1.26,6.27),(x+.34,-1.12,6.48)],.041,WOOD)
 path('Brow_'+side,[(x-.35,-.99,7.14),(x-.15,-1.06,7.30),(x+.12,-1.065,7.32),(x+.36,-.96,7.18)],.082,LID)
# Broad nostrils and a long bridge are fused by the body relief, rather than a
# tiny separate round button nose. Small wing surfaces finish the silhouette.
sphere('NoseTip',(0,-1.43,6.18),(.195,.16,.12),WOOD)
for s in (-1,1):
 sphere('NoseWing_'+str(s),(s*.155,-1.28,6.18),(.13,.14,.095),WOOD)
 sphere('Nostril_'+str(s),(s*.115,-1.398,6.135),(.052,.025,.025),SHADOW,segments=24,rings=16)
def facial_surface(x,z):
 u=(z-2.85)/5.27;r=1.065+.025*math.sin(math.pi*u)-.075*math.exp(-u*50)-.075*math.exp(-(1-u)*50)
 def bump(cx,cz,sx,sz,d):return d*math.exp(-((x-cx)/sx)**2-((z-cz)/sz)**2)
 d=bump(0,6.66,.125,.48,.32)+bump(0,6.21,.19,.14,.28)+bump(0,5.72,.54,.23,.16)+bump(0,5.38,.40,.22,.08)
 for sign in (-1,1):
  d+=bump(sign*.57,6.15,.33,.28,.22)+bump(sign*.48,7.10,.37,.18,.13)+bump(sign*.49,6.66,.34,.40,-.16)
 radius=math.sqrt(r*r-x*x)
 return -radius-d*(radius/r)**10
smile=[(-.64,-.94,5.99),(-.46,-1.085,5.78),(-.16,-1.19,5.69),(.18,-1.19,5.70),(.48,-1.075,5.82),(.66,-.935,6.04)]
smile=[(x,facial_surface(x,z)-.023,z) for x,y,z in smile]
path('SmileCrease',smile,.031,SHADOW)
lip=[(-.49,5.67),(-.20,5.55),(.12,5.56),(.47,5.72)]
path('LowerLip',[(x,facial_surface(x,z)-.018,z) for x,z in lip],.045,WOOD)

# Anatomical chains; the club is NEVER included in an arm's mesh or weights.
BONES['Root']=((0,0,.18),(0,0,2.85),None)
BONES['Body']=((0,0,2.85),(0,0,8.12),'Root')
for side,sign in (('R',-1),('L',1)):
 shoulder=Vector((sign*1.04,0,5.40));elbow=Vector((sign*1.34,-.035,4.40));wrist=Vector((sign*1.21,-.24,3.48));palm=wrist+Vector((0,-.015,-.16))
 BONES['UpperArm.'+side]=(shoulder,elbow,'Body');BONES['Forearm.'+side]=(elbow,wrist,'UpperArm.'+side)
 BONES['Hand.'+side]=(wrist,palm+Vector((0,0,-.24)),'Forearm.'+side)
 arm=[]
 arm.append(limb('UpperArm_'+side,shoulder,elbow,.135,.112,'UpperArm.'+side))
 arm.append(limb('Forearm_'+side,elbow,wrist,.114,.080,'Forearm.'+side))
 arm.append(sphere('Elbow_'+side,elbow,(.12,.115,.13),WOOD,'Forearm.'+side,32,24))
 arm.append(sphere('Palm_'+side,palm,(.128,.09,.19),WOOD,'Hand.'+side,32,24))
 # Four long fingers and an opposed thumb; each has its own deform bone.
 for i in range(4):
  x=palm.x+(i-1.5)*.064;a=Vector((x,palm.y-.015,palm.z-.11))
  if side=='R':
   mid=a+Vector((0,-.115,-.085));end=a+Vector((0,-.13,.035))
  else:mid=a+Vector((0,-.018,-.13));end=a+Vector((0,-.07,-.23+.03*abs(i-1.5)))
  bone='Finger%d.%s'%(i,side);BONES[bone]=(a,end,'Hand.'+side)
  arm.append(path('Finger%d_%s'%(i,side),[a,mid,end],.032,WOOD,bone))
 a=palm+Vector((-sign*.115,-.015,.02));b=palm+Vector((-sign*.08,-.145,-.06))
 bone='Thumb.'+side;BONES[bone]=(a,b,'Hand.'+side);arm.append(limb('Thumb_'+side,a,b,.046,.035,bone))
 # Smooth continuous arm surface with blended elbow/wrist weights. Fingers
 # remain separate closed geometry so their gaps cannot be remeshed away.
 skin=arm[:4]
 bpy.ops.object.select_all(action='DESELECT')
 for o in skin:o.select_set(True)
 bpy.context.view_layer.objects.active=skin[0];bpy.ops.object.join();joined=bpy.context.object
 for o in skin[1:]: ART.remove(o);OWN.pop(o,None)
 joined.name='ContinuousArm_'+side
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 remesh=joined.modifiers.new('Sculpted continuous skin','REMESH');remesh.mode='VOXEL';remesh.voxel_size=.018
 bpy.ops.object.modifier_apply(modifier=remesh.name)
 sm=joined.modifiers.new('Relax joint transitions','SMOOTH');sm.factor=1.1;sm.iterations=5;bpy.ops.object.modifier_apply(modifier=sm.name)
 for f in joined.data.polygons:f.use_smooth=True
 OWN[joined]=('ARM',side,elbow.z,wrist.z)
 hip=Vector((sign*.43,.02,2.88));knee=Vector((sign*.48,-.025,1.57));ankle=Vector((sign*.49,.025,.42))
 BONES['Thigh.'+side]=(hip,knee,'Body');BONES['Shin.'+side]=(knee,ankle,'Thigh.'+side);BONES['Foot.'+side]=(ankle,ankle+Vector((0,-.58,-.20)),'Shin.'+side)
 leg=[limb('Thigh_'+side,hip,knee,.18,.135,'Thigh.'+side),limb('Shin_'+side,knee,ankle,.135,.10,'Shin.'+side),sphere('Knee_'+side,knee,(.14,.14,.15),WOOD,'Shin.'+side,32,24)]
 bpy.ops.object.select_all(action='DESELECT')
 for o in leg:o.select_set(True)
 bpy.context.view_layer.objects.active=leg[0];bpy.ops.object.join();joined=bpy.context.object
 for o in leg[1:]:ART.remove(o);OWN.pop(o,None)
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 rem=joined.modifiers.new('Continuous leg skin','REMESH');rem.mode='VOXEL';rem.voxel_size=.022;bpy.ops.object.modifier_apply(modifier=rem.name)
 sm=joined.modifiers.new('Relax knee','SMOOTH');sm.factor=1;sm.iterations=4;bpy.ops.object.modifier_apply(modifier=sm.name)
 OWN[joined]=('LEG',side,knee.z,ankle.z)
 for f in joined.data.polygons:f.use_smooth=True
 sphere('Foot_'+side,(ankle.x,-.28,.24),(.28,.59,.215),WOOD,'Foot.'+side)
 for i in range(5):
  # Big toe toward the body's centre, smaller toes toward the outer edge.
  x=ankle.x+sign*(i-1.8)*.105
  sphere('Toe%d_%s'%(i,side),(x,-.78+.025*i,.145),(.077-i*.005,.17-i*.015,.11-i*.008),WOOD,'Foot.'+side,24,16)

# Separate solid wooden bat: thin handle, long tapered barrel, rounded heavy end.
handle=Vector((-1.21,-.37,3.38));tip=Vector((-2.55,-.43,.20));direction=(tip-handle).normalized();length=(tip-handle).length
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
stats={'meshes':len(ART),'bones':len(BONES),'triangles':triangles,'separateClub':True,'stage':'geometry and rig study; not installed in game'}
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
light('Warm key',(-5,-7,11),1100,5,(1,.82,.62));light('Soft fill',(5,-4,7),750,5,(.70,.82,1));light('Rim',(1,4,10),1300,4,(1,.88,.66))
camdata=bpy.data.cameras.new('ReviewCamera');cam=bpy.data.objects.new('ReviewCamera',camdata);bpy.context.collection.objects.link(cam)
scene=bpy.context.scene;scene.camera=cam;camdata.type='ORTHO';camdata.ortho_scale=9.5
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=False
scene.render.resolution_x=1000;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.world.color=(.12,.12,.12);scene.view_settings.view_transform='AgX'
try:scene.view_settings.look='AgX - Medium High Contrast'
except TypeError:pass
views=[('Front',(-.5,-18,5.9)),('Side',(18,-.5,5.8)),('ThreeQuarter',(11,-19,8.8))]
for name,pos in views:
 cam.location=pos;cam.rotation_euler=(Vector((-.45,0,4.05))-cam.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str(OUT/(name+'.png'))
 if name=='ThreeQuarter':bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'OriginalSahur.blend'),compress=True)
 bpy.ops.render.render(write_still=True)
print('ORIGINAL_SAHUR',json.dumps(stats))
