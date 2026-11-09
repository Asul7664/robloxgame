"""Preview exported native OceanFloor/ReefScenery geometry, not Studio rendering.

lune run tools/preview_ocean.luau /workspace/outputs/ocean-v2.json
blender -b -t 6 --python-exit-code 1 --python tools/preview_ocean.py -- scene.json outdir
python tools/preview_ocean.py --compose outdir target.png
The JSON schema is native Part CFrame/Size plus Sphere mesh scale and reef type.
"""
import sys, json, math
from pathlib import Path
TYPES=['CoralGarden','RockRidge','SpongeColony','SeaFanGarden','KelpGrove','TableTerraces']
LABELS=['Кораллы','Каменная гряда','Губки','Морские веера','Водоросли','Коралловые террасы']
if '--compose' in sys.argv:
    from PIL import Image, ImageDraw, ImageFont
    i=sys.argv.index('--compose');source=Path(sys.argv[i+1]);target=Path(sys.argv[i+2])
    canvas=Image.new('RGB',(1600,1190),'#153B4D');draw=ImageDraw.Draw(canvas)
    font='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
    draw.text((24,16),'ШЕСТЬ РАЗНЫХ ПОДВОДНЫХ УЧАСТКОВ',font=ImageFont.truetype(font,26),fill='#F8EBCB')
    for index,(kind,label) in enumerate(zip(TYPES,LABELS)):
        x,y=(index%3)*533,62+(index//3)*535
        img=Image.open(source/(kind+'.png')).convert('RGB').resize((533,470))
        canvas.paste(img,(x,y));draw.text((x+18,y+482),label,font=ImageFont.truetype(font,24),fill='#F8EBCB')
    draw.text((24,1150),'Геометрия из игровых модулей · Свет Blender приблизительный · Не снимок Roblox Studio',
        font=ImageFont.truetype(font,18),fill='#B9D5DB')
    canvas.save(target);print(target);raise SystemExit(0)

import bpy
from mathutils import Matrix, Vector
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
data=json.loads(Path(args[0]).read_text());out=Path(args[1]);out.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE_NEXT';scene.eevee.taa_render_samples=32
scene.render.image_settings.file_format='PNG';scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
scene.world.use_nodes=True;bg=scene.world.node_tree.nodes.get('Background')
bg.inputs['Color'].default_value=(.23,.44,.51,1);bg.inputs['Strength'].default_value=.7
convert=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
materials={};meshes={};objects=[]
def linear(x):return x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4
def material(color):
    key=tuple(round(v,4) for v in color)
    if key not in materials:
        m=bpy.data.materials.new('OceanColor'+str(len(materials)));m.use_nodes=True
        p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=tuple(linear(v) for v in color)+(1,)
        p.inputs['Roughness'].default_value=.78;materials[key]=m
    return materials[key]
def primitive(kind):
    if kind in meshes:return meshes[kind]
    if kind=='Sphere':bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,radius=.5)
    elif kind=='Cylinder':
        bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.5,depth=1)
        bpy.context.object.data.transform(Matrix.Rotation(math.pi/2,4,'Y'))
    elif kind=='Wedge':
        m=bpy.data.meshes.new('Wedge');m.from_pydata([(-.5,-.5,-.5),(.5,-.5,-.5),(-.5,-.5,.5),(.5,-.5,.5),(-.5,.5,.5),(.5,.5,.5)],[],
            [(0,2,3,1),(2,4,5,3),(0,1,5,4),(0,4,2),(1,3,5)])
        m.update();meshes[kind]=m;return m
    else:bpy.ops.mesh.primitive_cube_add(size=1)
    o=bpy.context.object;m=o.data
    if kind in ('Sphere','Cylinder'):
        for p in m.polygons:p.use_smooth=True
    meshes[kind]=m;bpy.data.objects.remove(o,do_unlink=True);return m
for part in data['Parts']:
    kind='Sphere' if part.get('MeshType')=='Sphere' else ('Wedge' if part['Class']=='WedgePart' else part['Shape'])
    if kind=='Ball':
        if max(part['Size'])-min(part['Size'])>.001:raise ValueError('Nonuniform native Ball')
        kind='Sphere'
    f=part['Frame'];cf=Matrix(((f[3],f[4],f[5],f[0]),(f[6],f[7],f[8],f[1]),(f[9],f[10],f[11],f[2]),(0,0,0,1)))
    size=[v*s for v,s in zip(part['Size'],part.get('MeshScale',[1,1,1]))]
    obj=bpy.data.objects.new(part['Name'],primitive(kind));scene.collection.objects.link(obj)
    obj.matrix_world=convert@cf@Matrix.Diagonal((*size,1));obj.data=obj.data.copy();obj.data.materials.append(material(part['Color']))
    objects.append((obj,part))
bpy.ops.object.light_add(type='SUN',location=(0,0,80));sun=bpy.context.object;sun.data.energy=2.2
sun.data.color=(.87,.97,1);sun.rotation_euler=(.48,-.65,-.55);sun.data.angle=.14
bpy.ops.object.camera_add();camera=bpy.context.object;scene.camera=camera;camera.data.clip_end=4000
def point(p):return Vector((p[0],-p[2],p[1]))
def shot(name,location,target,resolution,ortho=None):
    camera.location=point(location);camera.rotation_euler=(point(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO' if ortho else 'PERSP';camera.data.ortho_scale=ortho or 50;camera.data.lens=28
    scene.render.resolution_x,scene.render.resolution_y=resolution
    scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
if '--contacts-only' not in args:
    shot('ocean-v2-cove',(130,-1,-205),(-2,-13,-105),(1400,900))
    shot('ocean-v2-relief',(230,-4,-215),(70,-17,-85),(1400,900))
# Individual source patches keep all relative geometry and their actual slope.
for kind in TYPES:
    patch=next(p for p in data['Patches'] if p['Type']==kind)
    for obj,part in objects:obj.hide_render=part.get('Patch') is not None and part.get('Patch')!=patch['Name']
    x,y,z=patch['Center']
    shot(kind,(x+27,y+20,z-27),(x,y+2,z),(600,530),ortho=35)
