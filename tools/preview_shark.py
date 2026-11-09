"""Render production shark geometry exported by preview_shark.luau.

blender -b --python-exit-code 1 --python tools/preview_shark.py -- scene.json output_dir
python tools/preview_shark.py --compose output_dir target.png
Lighting is approximate; this is not a Roblox Studio screenshot.
"""
import json, math, sys
from pathlib import Path

if '--compose' in sys.argv:
    from PIL import Image, ImageDraw, ImageFont
    i=sys.argv.index('--compose'); source=Path(sys.argv[i+1]);target=Path(sys.argv[i+2])
    canvas=Image.new('RGB',(1600,865),'#20384D');draw=ImageDraw.Draw(canvas)
    font='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
    draw.text((24,15),'АКУЛА / ОБНОВЛЁННАЯ ИГРОВАЯ ГЕОМЕТРИЯ',font=ImageFont.truetype(font,24),fill='#F5F4E7')
    for index,(name,label) in enumerate((('threequarter','ОБЩИЙ ВИД'),('side','СИЛУЭТ СБОКУ'))):
        img=Image.open(source/('shark-v2-'+name+'.png')).convert('RGB')
        canvas.paste(img.resize((800,720)),(index*800,60))
        draw.text((index*800+24,792),label,font=ImageFont.truetype(font,20),fill='#F5F4E7')
    draw.text((24,834),'Реальные детали из модуля игры · Свет приближён в Blender · Не скриншот Roblox Studio',font=ImageFont.truetype(font,16),fill='#B8D4DF')
    canvas.save(target);print(target);raise SystemExit(0)

import bpy
from mathutils import Matrix, Vector
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
source=Path(args[0] if args else '/workspace/outputs/shark-v2.json')
output=Path(args[1] if len(args)>1 else '/workspace/outputs');output.mkdir(parents=True,exist_ok=True)
data=json.loads(source.read_text())
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE_NEXT';scene.eevee.taa_render_samples=64
scene.render.resolution_x=1000;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='Standard'
scene.view_settings.look='None';scene.world.use_nodes=True
bg=scene.world.node_tree.nodes.get('Background');bg.inputs['Color'].default_value=(.50,.66,.78,1);bg.inputs['Strength'].default_value=.65
convert=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
materials={};meshes={}
def linear(v):return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
def material(color):
    key=tuple(round(c,4) for c in color)
    if key not in materials:
        mat=bpy.data.materials.new('SharkColor'+str(len(materials)));mat.use_nodes=True
        bsdf=mat.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Base Color'].default_value=tuple(linear(c) for c in color)+(1,)
        bsdf.inputs['Roughness'].default_value=.52;materials[key]=mat
    return materials[key]
def primitive(kind):
    if kind in meshes:return meshes[kind]
    if kind=='Sphere':bpy.ops.mesh.primitive_uv_sphere_add(segments=40,ring_count=24,radius=.5)
    elif kind=='Wedge':
        mesh=bpy.data.meshes.new('RobloxWedge')
        mesh.from_pydata([(-.5,-.5,-.5),(.5,-.5,-.5),(-.5,-.5,.5),(.5,-.5,.5),(-.5,.5,.5),(.5,.5,.5)],[],
            [(0,2,3,1),(2,4,5,3),(0,1,5,4),(0,4,2),(1,3,5)])
        mesh.update();meshes[kind]=mesh;return mesh
    else:bpy.ops.mesh.primitive_cube_add(size=1)
    obj=bpy.context.object;mesh=obj.data
    if kind=='Sphere':
        for face in mesh.polygons:face.use_smooth=True
    meshes[kind]=mesh;bpy.data.objects.remove(obj,do_unlink=True);return mesh
for part in data['Parts']:
    kind='Sphere' if part.get('MeshType')=='Sphere' else ('Wedge' if part['Class']=='WedgePart' else part['Shape'])
    if kind=='Ball':
        # Do not invent an ellipsoid from a nonuniform native Ball: its Studio
        # scaling is constrained. SpecialMesh Sphere must be used explicitly.
        if max(part['Size'])-min(part['Size'])>.0001:
            raise ValueError('Nonuniform native Ball cannot be previewed as an ellipsoid: '+part['Name'])
        size=part['Size'];kind='Sphere'
    else:size=part['Size']
    scale=part.get('MeshScale',[1,1,1]);size=[s*m for s,m in zip(size,scale)]
    f=part['Frame'];frame=Matrix(((f[3],f[4],f[5],f[0]),(f[6],f[7],f[8],f[1]),(f[9],f[10],f[11],f[2]),(0,0,0,1)))
    obj=bpy.data.objects.new(part['Name'],primitive(kind));bpy.context.collection.objects.link(obj)
    obj.matrix_world=convert@frame@Matrix.Diagonal((*size,1));obj.data=obj.data.copy();obj.data.materials.append(material(part['Color']))
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-1.7));bpy.context.object.data.materials.append(material((.71,.79,.81)))
bpy.ops.object.light_add(type='AREA',location=(4,5,10));key=bpy.context.object;key.data.energy=1500;key.data.size=9
bpy.ops.object.light_add(type='SUN',location=(0,0,10));sun=bpy.context.object;sun.data.energy=1.2;sun.rotation_euler=(math.radians(28),math.radians(-22),math.radians(-35))
for name,location,scale in [('threequarter',(11,14,6),14.5),('side',(15,-.7,2.8),13.0)]:
    bpy.ops.object.camera_add(location=location);camera=bpy.context.object
    target=Vector((0,-.7,.15));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO';camera.data.ortho_scale=scale;scene.camera=camera
    scene.render.filepath=str(output/('shark-v2-'+name+'.png'));bpy.ops.render.render(write_still=True)
