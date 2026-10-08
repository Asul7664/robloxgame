"""Build the actual Sahur meshes, Blender rig, FBX and review render.

Run: blender --background --python tools/sahur/build_sahur.py
Blender uses Z-up/-Y-front; exported Roblox geometry uses Y-up/-Z-front.
"""
import bpy
import argparse
import json
import math
import sys
from mathutils import Vector
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--output-dir', type=Path, default=ROOT.parent / 'outputs' / 'sahur')
options = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT = options.output_dir.resolve()
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

ART = []
JOINTS = {
    'Root': ((0, 0, .25), (0, 0, 2.4), None),
    'Body': ((0, 0, 2.4), (0, 0, 6.9), 'Root'),
    'RightUpperArm': ((-1.18, 0, 5.0), (-1.92, -.05, 4.12), 'Body'),
    'RightLowerArm': ((-1.92, -.05, 4.12), (-2.0, -.75, 3.68), 'RightUpperArm'),
    'RightHand': ((-2.0, -.75, 3.68), (-2.04, -.86, 3.35), 'RightLowerArm'),
    'LeftUpperArm': ((1.18, 0, 5.0), (1.86, .02, 4.2), 'Body'),
    'LeftLowerArm': ((1.86, .02, 4.2), (1.98, -.25, 3.3), 'LeftUpperArm'),
    'LeftHand': ((1.98, -.25, 3.3), (1.99, -.38, 2.95), 'LeftLowerArm'),
    'RightUpperLeg': ((-.65, 0, 2.45), (-.98, -.05, 1.45), 'Body'),
    'RightLowerLeg': ((-.98, -.05, 1.45), (-1.02, .12, .52), 'RightUpperLeg'),
    'RightFoot': ((-1.02, .12, .52), (-1.05, -.58, .24), 'RightLowerLeg'),
    'LeftUpperLeg': ((.65, 0, 2.45), (1.0, -.15, 1.46), 'Body'),
    'LeftLowerLeg': ((1.0, -.15, 1.46), (1.12, .08, .52), 'LeftUpperLeg'),
    'LeftFoot': ((1.12, .08, .52), (1.15, -.6, .24), 'LeftLowerLeg'),
}

def material(name, rgb, roughness=.4, wood=False):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    shader = nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*rgb, 1)
    shader.inputs['Roughness'].default_value = roughness
    if wood:
        tex = nodes.new('ShaderNodeTexNoise')
        tex.inputs['Scale'].default_value = 5.3
        tex.inputs['Detail'].default_value = 3.4
        mapping = nodes.new('ShaderNodeVectorMath'); mapping.operation = 'MULTIPLY'
        mapping.inputs[1].default_value = (4.0, 4.0, .28)
        coordinates = nodes.new('ShaderNodeTexCoord')
        links.new(coordinates.outputs['Object'], mapping.inputs[0])
        links.new(mapping.outputs[0], tex.inputs['Vector'])
        ramp = nodes.new('ShaderNodeValToRGB')
        ramp.color_ramp.elements[0].position = .18
        ramp.color_ramp.elements[0].color = (*(v*.53 for v in rgb), 1)
        ramp.color_ramp.elements[1].position = .84
        ramp.color_ramp.elements[1].color = (*(min(1,v*1.30+.018) for v in rgb), 1)
        links.new(tex.outputs['Fac'], ramp.inputs[0]); links.new(ramp.outputs[0], shader.inputs['Base Color'])
        bump = nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = .19
        bump.inputs['Distance'].default_value = .04
        links.new(tex.outputs['Fac'], bump.inputs['Height']); links.new(bump.outputs[0], shader.inputs['Normal'])
    return mat

WOOD = material('Honey_Oak', (.50, .17, .030), .37, True)
GOLD = material('Golden_Endgrain', (.72, .30, .075), .4, True)
DARKWOOD = material('Bark_Sculpt', (.23, .055, .010), .43, True)
GRAIN = material('Wood_Grain_Inlay', (.28, .102, .032), .55)
LIGHTGRAIN = material('Wood_Highlights', (.80, .42, .12), .48)
WHITE = material('Warm_Eye_White', (.98, .91, .76), .22)
IRIS = material('Amber_Iris', (.25, .088, .018), .23)
PUPIL = material('Pupil', (.011, .014, .009), .16)
TEAL = material('Ocean_Rope', (.018, .40, .36), .48)
TEAL_DARK = material('Rope_Twist', (.012, .22, .19), .49)
MOUTH = material('Smile_Shadow', (.083, .025, .007), .56)

def finish(obj, name, mat, bone='Body'):
    obj.name = name
    obj.data.materials.clear(); obj.data.materials.append(mat)
    obj['Bone'] = bone
    for p in obj.data.polygons: p.use_smooth = True
    ART.append(obj)
    return obj

def ellipsoid(name, center, scale, mat=WOOD, bone='Body', segments=32, rings=20, rot=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=center)
    obj = bpy.context.object; obj.scale = scale
    if rot: obj.rotation_euler = rot
    return finish(obj, name, mat, bone)

def lathe(name, profile, mat=WOOD, bone='Body', segments=64, center=(0,0,0), direction=(0,0,1), grain=False):
    verts=[]; faces=[]
    for k,(height,radius) in enumerate(profile):
        for j in range(segments):
            a=j*math.tau/segments
            variation = (1+.012*math.sin(a*9+height*.65)+.009*math.sin(a*17-height*.26)) if grain else 1
            r=radius*variation
            verts.append((r*math.cos(a),r*math.sin(a),height))
    for k in range(len(profile)-1):
        for j in range(segments):
            n=(j+1)%segments; a=k*segments+j; b=k*segments+n
            faces.append((a,b,b+segments,a+segments))
    faces.append(tuple(reversed(range(segments))))
    faces.append(tuple((len(profile)-1)*segments+j for j in range(segments)))
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.update()
    obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj)
    obj.location=center; obj.rotation_euler=Vector(direction).to_track_quat('Z','Y').to_euler()
    return finish(obj,name,mat,bone)

def capsule(name,a,b,r1,r2=None,mat=WOOD,bone='Body'):
    a,b=Vector(a),Vector(b); length=(b-a).length; r2=r1 if r2 is None else r2
    # Rounded ends and a subtly tapered shaft, rather than intersecting cubes.
    profile=[(-r1*.45,.001),(-r1*.34,r1*.65),(0,r1*.94),
             (length*.18,r1),(length*.45,(r1+r2)*.51),(length*.82,r2),
             (length,r2*.93),(length+r2*.28,r2*.62),(length+r2*.4,.001)]
    return lathe(name,profile,mat,bone,32,a,b-a)

def tube(name,points,radius,mat=WOOD,bone='Body',resolution=10):
    curve=bpy.data.curves.new(name,'CURVE'); curve.dimensions='3D'
    curve.resolution_u=4; curve.bevel_depth=radius; curve.bevel_resolution=2
    spline=curve.splines.new('BEZIER'); spline.bezier_points.add(len(points)-1)
    for p,xyz in zip(spline.bezier_points,points):
        p.co=xyz; p.handle_left_type='AUTO'; p.handle_right_type='AUTO'
    obj=bpy.data.objects.new(name,curve); bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active=obj; obj.select_set(True)
    bpy.ops.object.convert(target='MESH'); obj=bpy.context.object
    obj.select_set(False)
    return finish(obj,name,mat,bone)

def ring(name,center,radius,minor,mat,bone='Body',tilt=None,segments=64):
    bpy.ops.mesh.primitive_torus_add(major_segments=segments,minor_segments=10,
        location=center,major_radius=radius,minor_radius=minor)
    obj=bpy.context.object
    if tilt: obj.rotation_euler=tilt
    return finish(obj,name,mat,bone)

# One continuous barrel/log body with softened rims and a broad readable face.
body_profile=[]
for i in range(41):
    h=2.35+i*4.55/40
    edge=min(i,40-i)
    r=1.08-.14*max(0,1-edge/3)**2+.025*math.sin((h-2.35)*.8)
    body_profile.append((h,r))
lathe('Carved_Log',body_profile,WOOD,segments=96,grain=True)
lathe('Endgrain_Crown',[(6.875,.01),(6.875,.94),(6.89,1.04),(6.925,1.015),(6.945,.95)],GOLD,segments=96)
for i,r in enumerate([.16,.30,.47,.65,.83]):
    points=[]
    for j in range(33):
        a=j*math.tau/32; rr=r*(1+.028*math.sin(3*a+i)+.013*math.sin(7*a))
        points.append((rr*math.cos(a),rr*math.sin(a),6.946+.003*i))
    tube('Crown_AgeRing_%02d'%i,points,.009,GRAIN)

# Modest sculpted grain; face area is clear, fine texture remains in material.
for i in range(24):
    a=i*math.tau/24
    front=abs(math.atan2(math.sin(a+math.pi/2),math.cos(a+math.pi/2)))<.9
    bottom=2.6+(i%3)*.12; top=4.4 if front else 6.66-(i%4)*.10
    points=[]
    for j in range(10):
        h=bottom+(top-bottom)*j/9
        aa=a+.012*math.sin(h*2.7+i)*math.sin(math.pi*j/9)
        radius=1.09+.025*math.sin((h-2.35)*.8)
        points.append((radius*math.cos(aa),radius*math.sin(aa),h))
    tube('Bark_Grain_%02d'%i,points,.0065,GRAIN if i%3 else LIGHTGRAIN)

# Brown irises and catchlights; a carved cheek/bridge gives the face depth.
for sign in [-1,1]:
    x=sign*.46
    ellipsoid('EyeSocket_'+str(sign),(x,-1.00,5.78),(.48,.20,.61),DARKWOOD)
    ellipsoid('EyeWhite_'+str(sign),(x,-1.15,5.76),(.345,.23,.45),WHITE)
    ellipsoid('Iris_'+str(sign),(x+sign*.025,-1.353,5.77),(.21,.047,.255),IRIS)
    ellipsoid('Pupil_'+str(sign),(x+sign*.025,-1.386,5.77),(.122,.025,.17),PUPIL)
    ellipsoid('EyeShine_'+str(sign),(x-.055,-1.413,5.90),(.060,.020,.075),WHITE,segments=20,rings=12)
    ellipsoid('EyeShineSmall_'+str(sign),(x+.064,-1.411,5.67),(.023,.010,.029),WHITE,segments=16,rings=10)
    brow=[(sign*.13,-1.17,6.19),(sign*.40,-1.18,6.38),(sign*.68,-1.08,6.39),(sign*.88,-.90,6.24)]
    tube('Carved_Brow_'+str(sign),brow,.105,DARKWOOD)
    ellipsoid('Smile_Cheek_'+str(sign),(sign*.61,-.87,5.08),(.42,.31,.34),WOOD)
ellipsoid('NoseBridge',(0,-1.11,5.49),(.155,.20,.35),WOOD)
ellipsoid('Carved_Nose',(0,-1.31,5.30),(.29,.24,.145),GOLD)
smile=[(-.70,-.91,5.12),(-.50,-1.00,4.94),(0,-1.12,4.85),(.45,-1.02,4.97),(.72,-.91,5.20)]
tube('Smile_Carving',smile,.044,MOUTH)
tube('LowerLip',[(-.58,-.96,4.88),(0,-1.075,4.73),(.53,-.97,4.91)],.058,WOOD)

# Articulated wooden limbs. Each art piece carries a single named bone.
for side,sign in [('Right',-1),('Left',1)]:
    shoulder=JOINTS[side+'UpperArm'][0]; elbow=JOINTS[side+'UpperArm'][1]; wrist=JOINTS[side+'LowerArm'][1]
    ellipsoid(side+'_ShoulderCap',shoulder,(.46,.43,.47),WOOD,side+'UpperArm')
    capsule(side+'_UpperArm',shoulder,elbow,.34,.29,WOOD,side+'UpperArm')
    ellipsoid(side+'_Elbow',elbow,(.29,.285,.29),DARKWOOD,side+'LowerArm')
    capsule(side+'_Forearm',elbow,wrist,.30,.25,WOOD,side+'LowerArm')
    handcenter=Vector(wrist)+Vector((0,-.09,-.22))
    ellipsoid(side+'_Palm',handcenter,(.32,.27,.34),WOOD,side+'Hand')
    for i in range(4):
        cx=handcenter.x+(i-1.5)*.135
        if side=='Right':
            a=(cx,handcenter.y-.21,handcenter.z+.10); b=(cx,handcenter.y-.30,handcenter.z-.14)
        else:
            a=(cx,handcenter.y-.16,handcenter.z-.07); b=(cx,handcenter.y-.23,handcenter.z-.36+(abs(i-1.5)*.035))
        capsule(side+'_Finger_%d'%i,a,b,.10,.093,WOOD,side+'Hand')
    capsule(side+'_Thumb',(handcenter.x-sign*.23,handcenter.y-.02,handcenter.z+.07),
            (handcenter.x-sign*.19,handcenter.y-.31,handcenter.z-.05),.115,.105,GOLD,side+'Hand')
    # Two intertwined rope strands following the wrist, not a broad bracelet.
    wrist_axis=(Vector(wrist)-Vector(elbow)).normalized()
    u=wrist_axis.cross(Vector((0,0,1))).normalized(); v=wrist_axis.cross(u).normalized()
    for strand in range(2):
        points=[]
        for j in range(65):
            a=j*math.tau/64; rr=.26+.012*math.cos(a*10+strand*math.pi)
            p=Vector(wrist)+u*rr*math.cos(a)+v*rr*math.sin(a)+wrist_axis*(.045*math.sin(a*10+strand*math.pi))
            points.append(p)
        tube(side+'_WristRope_%d'%strand,points,.032,TEAL if strand else TEAL_DARK,side+'LowerArm')
    hip=JOINTS[side+'UpperLeg'][0]; knee=JOINTS[side+'UpperLeg'][1]; ankle=JOINTS[side+'LowerLeg'][1]
    capsule(side+'_Thigh',hip,knee,.38,.31,WOOD,side+'UpperLeg')
    ellipsoid(side+'_Kneecap',Vector(knee)+Vector((0,-.12,0)),(.29,.26,.30),GOLD,side+'LowerLeg')
    capsule(side+'_Shin',knee,ankle,.30,.24,WOOD,side+'LowerLeg')
    footcenter=Vector(ankle)+Vector((0,-.20,-.22))
    ellipsoid(side+'_Foot',footcenter,(.42,.65,.28),WOOD,side+'Foot')
    for i in range(4):
        toe=footcenter+Vector(((i-1.5)*.18,-.50,.002))
        ellipsoid(side+'_Toe_%d'%i,toe,(.13,.21,.16),WOOD,side+'Foot',segments=20,rings=12)

# Belt stays low so the silhouette still reads as a wooden log.
for strand in range(3):
    points=[]
    for j in range(97):
        a=j*math.tau/96; rr=1.11+.018*math.sin(a*18+strand*math.tau/3)
        points.append((rr*math.cos(a),rr*math.sin(a),2.55+.046*math.cos(a*18+strand*math.tau/3)))
    tube('Braided_Belt_%d'%strand,points,.044,TEAL if strand else TEAL_DARK)
for sign in [-1,1]:
    tube('Belt_Knot_'+str(sign),[(0,-1.17,2.58),(sign*.23,-1.26,2.70),(sign*.29,-1.27,2.49),(0,-1.21,2.48)],.066,TEAL)
    tube('Belt_Tail_'+str(sign),[(sign*.1,-1.23,2.5),(sign*.16,-1.26,2.25),(sign*.13,-1.25,2.00)],.052,TEAL)

# The bat's grip intersects the closed palm, its blade clears the entire body.
bat_origin=Vector((-2.03,-1.04,3.02)); bat_direction=Vector((-.22,-.045,.974)).normalized()
bat_profile=[(0,.18),(.04,.23),(.12,.23),(.18,.16),(.78,.15),(1.08,.20),(1.48,.28),(2.2,.38),(3.14,.43),(3.45,.42),(3.61,.35),(3.68,.20),(3.70,.001)]
lathe('Oak_Bat',bat_profile,GOLD,'RightHand',segments=64,center=bat_origin,direction=bat_direction,grain=True)
for i in range(7):
    c=bat_origin+bat_direction*(.20+i*.075)
    ring('Bat_GripWrap_%d'%i,c,.158,.018,DARKWOOD,'RightHand',bat_direction.to_track_quat('Z','Y').to_euler(),segments=32)

# Freeze all object transforms for round-trip exports and rigid skinning.
for obj in ART:
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)

# A real Blender armature, with rigid per-piece weights for wooden articulation.
arm_data=bpy.data.armatures.new('Sahur_Skeleton')
arm=bpy.data.objects.new('Sahur_Rig',arm_data); bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active=arm; arm.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for name,(head,tail,parent) in JOINTS.items():
    bone=arm_data.edit_bones.new(name); bone.head=head; bone.tail=tail
    if parent: bone.parent=arm_data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT'); arm.show_in_front=True
for obj in ART:
    group=obj.vertex_groups.new(name=obj['Bone']); group.add(range(len(obj.data.vertices)),1,'REPLACE')
    modifier=obj.modifiers.new('Rigid_Wood_Rig','ARMATURE'); modifier.object=arm
    obj.parent=arm

# Export explicit world-space triangles/normals for the embedded Roblox mesh.
geometries=[]; total_triangles=0
for obj in ART:
    mesh=obj.data; mesh.calc_loop_triangles()
    # This proper rotation preserves anatomical right and triangle winding.
    # Blender's -Y-facing character has its right hand on -X; Roblox's
    # -Z-facing character has its right hand on +X.
    verts=[(round(-v.co.x,6),round(v.co.z-3.45,6),round(v.co.y,6)) for v in mesh.vertices]
    normals=[(round(-v.normal.x,6),round(v.normal.z,6),round(v.normal.y,6)) for v in mesh.vertices]
    triangles=[tuple(t.vertices) for t in mesh.loop_triangles]
    mat=mesh.materials[0]
    def srgb(c): return 12.92*c if c<=.0031308 else 1.055*c**(1/2.4)-.055
    color=[round(srgb(c)*255) for c in mat.diffuse_color[:3]]
    geometries.append({'name':obj.name,'bone':obj['Bone'],'material':mat.name,'color':color,
                       'vertices':verts,'normals':normals,'triangles':triangles})
    total_triangles+=len(triangles)
rig={name:{'head':[-head[0],head[2]-3.45,head[1]],'tail':[-tail[0],tail[2]-3.45,tail[1]],'parent':parent}
     for name,(head,tail,parent) in JOINTS.items()}
(OUT/'geometry.json').write_text(json.dumps({'objects':geometries,'rig':rig,'triangles':total_triangles},separators=(',',':')))
(OUT/'stats.json').write_text(json.dumps({'objects':len(ART),'triangles':total_triangles,
    'vertices':sum(len(o.data.vertices) for o in ART),'bones':len(JOINTS)},indent=2))

# FBX includes the real mesh and skeleton. Preview-only scene objects excluded.
bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True)
for obj in ART: obj.select_set(True)
bpy.ops.export_scene.fbx(filepath=str(OUT/'Sahur_HighPoly_Rigged.fbx'),use_selection=True,
    object_types={'MESH','ARMATURE'},add_leaf_bones=False,bake_anim=False,axis_forward='-Z',axis_up='Y',
    mesh_smooth_type='FACE',apply_scale_options='FBX_SCALE_ALL')

# Studio review scene: warm key, cool fill, uncluttered teal backdrop.
ground_mat=material('Preview_Ground',(.013,.065,.073),.59)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.03))
ground=bpy.context.object; ground.name='Preview_Ground'; ground.data.materials.append(ground_mat)
def light(name,pos,power,size,color):
    data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size; data.color=color
    obj=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(obj); obj.location=pos
    obj.rotation_euler=(Vector((0,0,3.5))-obj.location).to_track_quat('-Z','Y').to_euler()
light('Golden_Key',(-5,-7,11),1250,6,(1,.76,.48))
light('Cool_Fill',(5,-4,6),800,5,(.48,.81,1))
light('Rim',(-1,4,9),1500,5,(.65,.88,1))
cam_data=bpy.data.cameras.new('Review_Camera'); cam=bpy.data.objects.new('Review_Camera',cam_data)
bpy.context.collection.objects.link(cam); cam.location=(9,-17,9.5)
cam.rotation_euler=(Vector((-.20,-.1,3.5))-cam.location).to_track_quat('-Z','Y').to_euler()
cam_data.type='ORTHO'; cam_data.ortho_scale=9.1
scene=bpy.context.scene; scene.camera=cam
scene.render.engine='CYCLES'; scene.cycles.samples=48
scene.cycles.use_denoising=False # This bundled Blender has no OpenImageDenoise.
scene.render.resolution_x=1000; scene.render.resolution_y=1300; scene.render.resolution_percentage=100
scene.world.color=(.07,.07,.07)
scene.view_settings.view_transform='AgX'
try: scene.view_settings.look='AgX - Medium High Contrast'
except TypeError: pass
scene.view_settings.exposure=-.20
scene.render.filepath=str(OUT/'Sahur_Actual_Model.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Sahur_HighPoly.blend'))
print('SAHUR_MODEL_STATS',json.dumps({'objects':len(ART),'triangles':total_triangles,'bones':len(JOINTS)}))
bpy.ops.render.render(write_still=True)
