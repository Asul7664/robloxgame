"""Render the production World/Archipelago geometry exported by preview_world.luau.

blender -b --python tools/preview_world.py -- /workspace/outputs/quiet-cove-world.json /workspace/outputs
python3 tools/preview_world.py --compose /workspace/outputs

Images use approximate Blender daylight. They are not Roblox Studio screenshots.
"""
import json
import math
import sys
from pathlib import Path
def compose(directory):
    from PIL import Image, ImageDraw, ImageFont
    directory = Path(directory)
    canvas = Image.new('RGB', (1280, 870), '#142845')
    draw = ImageDraw.Draw(canvas)
    font_path = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
    title = ImageFont.truetype(font_path, 20)
    label = ImageFont.truetype(font_path, 15)
    small = ImageFont.truetype(font_path, 12)
    draw.text((20, 13), 'QUIET COVE  /  ЯРКАЯ ТРОПИЧЕСКАЯ ПАЛИТРА', font=title, fill='#FFF7DF')
    draw.text((20, 43), 'Игровая геометрия и оружейная лавка · Освещение приближено в Blender', font=small, fill='#BBD5E8')
    hero = Image.open(directory / 'quiet-cove-cove-geometry.png').convert('RGB')
    canvas.paste(hero.resize((900, 800)), (0, 70))
    for index, (name, caption) in enumerate((('dunes', 'ПЕСКИ САХУРА'), ('bloom', 'ЦВЕТУЩИЙ ОСТРОВ'), ('storm', 'ГРОЗОВОЙ ОСТРОВ'))):
        image = Image.open(directory / ('quiet-cove-' + name + '-geometry.png')).convert('RGB')
        image = image.resize((380, 262))
        y = 70 + index * 266
        canvas.paste(image, (900, y))
        draw.rectangle((908, y + 8, 1100, y + 34), fill='#213E5E')
        draw.text((918, y + 12), caption, font=label, fill='#FFF7DF')
    draw.rectangle((15, 82, 175, 110), fill='#213E5E')
    draw.text((25, 87), 'ТИХАЯ БУХТА', font=label, fill='#FFF7DF')
    path = directory / 'quiet-cove-tropical-preview.png'
    canvas.save(path)
    print(path)

if '--compose' in sys.argv:
    compose(sys.argv[sys.argv.index('--compose') + 1])
    raise SystemExit(0)

import bpy
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
source = Path(args[0] if args else '/workspace/outputs/quiet-cove-world.json')
output = Path(args[1] if len(args) > 1 else '/workspace/outputs')
output.mkdir(parents=True, exist_ok=True)
data = json.loads(source.read_text())
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'None'
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1
scene.render.film_transparent = False
scene.world.color = (0.55, 0.68, 0.8)
scene.world.use_nodes = True
world = scene.world.node_tree.nodes.get('Background')
world.inputs['Color'].default_value = (0.60, 0.76, 0.91, 1)
world.inputs['Strength'].default_value = 0.65

# Roblox X/Y/Z to Blender X/-Z/Y. Mesh vertices retain Roblox local axes.
convert = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
materials = {}
meshes = {}
def linear_channel(value):
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4

def material(color, kind='SmoothPlastic'):
    key = tuple(round(c, 4) for c in color), kind
    if key in materials:
        return materials[key]
    mat = bpy.data.materials.new('World_' + str(len(materials)))
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    rgba = tuple(linear_channel(c) for c in color) + (1,)
    bsdf.inputs['Base Color'].default_value = rgba
    bsdf.inputs['Roughness'].default_value = 0.73
    if kind == 'Neon':
        bsdf.inputs['Emission Color'].default_value = rgba
        bsdf.inputs['Emission Strength'].default_value = 0.35
    materials[key] = mat
    return mat

def primitive(kind):
    if kind in meshes:
        return meshes[kind]
    if kind == 'Ball':
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.5)
    elif kind == 'Cylinder':
        bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.5, depth=1)
        obj = bpy.context.object
        obj.data.transform(Matrix.Rotation(math.pi / 2, 4, 'Y'))
    elif kind == 'Wedge':
        mesh = bpy.data.meshes.new('Wedge')
        mesh.from_pydata([(-.5,-.5,-.5),(.5,-.5,-.5),(-.5,-.5,.5),(.5,-.5,.5),(-.5,.5,.5),(.5,.5,.5)], [],
                         [(0,2,3,1),(2,4,5,3),(0,1,5,4),(0,4,2),(1,3,5)])
        mesh.update()
        meshes[kind] = mesh
        return mesh
    else:
        bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.object
    mesh = obj.data
    meshes[kind] = mesh
    bpy.data.objects.remove(obj, do_unlink=True)
    if kind == 'Ball':
        for face in mesh.polygons:
            face.use_smooth = True
    return mesh

for index, part in enumerate(data['Parts']):
    shape = 'Wedge' if part['Class'] == 'WedgePart' else part['Shape']
    mesh = primitive(shape)
    mat = material(part['Color'], part['Material'])
    # Mesh instances can have distinct object-linked materials.
    obj = bpy.data.objects.new(part['Name'], mesh)
    scene.collection.objects.link(obj)
    if len(mesh.materials) == 0:
        mesh.materials.append(mat)
    obj.material_slots[0].link = 'OBJECT'
    obj.material_slots[0].material = mat
    frame = part['Frame']
    cf = Matrix(((frame[3],frame[4],frame[5],frame[0]),
                 (frame[6],frame[7],frame[8],frame[1]),
                 (frame[9],frame[10],frame[11],frame[2]), (0,0,0,1)))
    size = part['Size']
    obj.matrix_world = convert @ cf @ Matrix.Diagonal((*size, 1))

# Global terrain water, represented as a flat plane (the production tint is retained).
bpy.ops.mesh.primitive_plane_add(size=10000, location=(0, 0, -0.02))
water = bpy.context.object
water.name = 'TerrainWater_approximate_surface'
water.data.materials.append(material(data['Palette']['Water']))
bsdf = water.data.materials[0].node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Roughness'].default_value = 0.24
bsdf.inputs['Metallic'].default_value = 0.08

light_data = bpy.data.lights.new('SoftDaylight', 'SUN')
light_data.energy = 2.2
light_data.angle = math.radians(12)
light = bpy.data.objects.new('SoftDaylight', light_data)
scene.collection.objects.link(light)
light.rotation_euler = (math.radians(25), math.radians(-30), math.radians(-22))

camera_data = bpy.data.cameras.new('GeometryPreview')
camera = bpy.data.objects.new('GeometryPreview', camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera_data.type = 'ORTHO'
camera_data.clip_end = 20000

def render(label, center, offset, scale, width, height):
    target = Vector(center)
    camera.location = target + Vector(offset)
    camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera_data.ortho_scale = scale
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.filepath = str(output / ('quiet-cove-' + label + '.png'))
    bpy.ops.render.render(write_still=True)

render('cove-geometry', (0, 15, 6), (145, 205, 150), 211, 900, 800)
islands = {i['Id']: i for i in data['Islands']}
for name in ('Dunes', 'Bloom', 'Storm'):
    island = islands[name]
    # Cameras show the same real island dimensions, with the fishing pier in view.
    center = (island['X'], -island['Z'] + 10, 8)
    render(name.lower() + '-geometry', center, (140, 220, 175), 213, 480, 330)
print('Rendered actual production geometry to', output)
