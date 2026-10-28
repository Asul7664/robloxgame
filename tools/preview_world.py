"""Render the production World/Archipelago geometry exported by preview_world.luau.

blender -b --python-exit-code 1 --python tools/preview_world.py -- /workspace/outputs/quiet-cove-world.json /workspace/outputs
python3 tools/preview_world.py --compose /workspace/outputs

Optional: --shots npc-market,npc-mara,npc-captain or --all-islands after the output path.

Images use approximate Blender daylight. They are not Roblox Studio screenshots.
"""
import json
import math
import sys
from pathlib import Path
def compose(directory):
    from PIL import Image, ImageDraw, ImageFont
    directory = Path(directory)
    canvas = Image.new('RGB', (1400, 1052), '#142845')
    draw = ImageDraw.Draw(canvas)
    font_path = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
    title = ImageFont.truetype(font_path, 24)
    label = ImageFont.truetype(font_path, 17)
    small = ImageFont.truetype(font_path, 15)
    draw.text((20, 13), 'QUIET COVE  /  ДЕТАЛИ НА УРОВНЕ ИГРОКА', font=title, fill='#FFF7DF')
    draw.text((20, 49), 'Геометрия из игровых модулей · Blender: приблизительное освещение, не скриншот Studio', font=small, fill='#BBD5E8')
    shots = (
        ('harbor-ground', 'БУХТА · ВИД С ВЫСОТЫ ПЕРСОНАЖА', (0, 88, 900, 506)),
        ('palm-ground', 'ПАЛЬМА · СИЛУЭТ И ДЕТАЛИ ВБЛИЗИ', (904, 88, 496, 506)),
        ('dunes-ground', 'ПЕСКИ САХУРА · ВИД С ЗЕМЛИ', (0, 598, 700, 394)),
        ('cove-geometry', 'БУХТА · ОБЩИЙ ПЛАН', (704, 598, 696, 394)),
    )
    for name, caption, (x, y, width, height) in shots:
        image = Image.open(directory / ('quiet-cove-' + name + '.png')).convert('RGB')
        canvas.paste(image.resize((width, height)), (x, y))
        box = draw.textbbox((0, 0), caption, font=label)
        draw.rectangle((x + 12, y + 12, x + 36 + box[2], y + 46), fill='#213E5E')
        draw.text((x + 24, y + 19), caption, font=label, fill='#FFF7DF')
    draw.text((20, 1010), 'Свет и материалы нужно окончательно оценить в Roblox Studio. Превью проверяет форму, масштаб и наполнение.', font=small, fill='#BBD5E8')
    path = directory / 'quiet-cove-detailed-world-preview.png'
    canvas.save(path)
    print(path)

def compose_npcs(directory, target):
    from PIL import Image, ImageDraw, ImageFont
    directory = Path(directory)
    canvas = Image.new('RGB', (1400, 650), '#142845')
    draw = ImageDraw.Draw(canvas)
    font = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
    title = ImageFont.truetype(font, 27)
    label = ImageFont.truetype(font, 21)
    small = ImageFont.truetype(font, 16)
    draw.text((20, 14), 'QUIET COVE / ПЕРСОНАЖИ БУХТЫ', font=title, fill='#FFF7DF')
    draw.text((20, 53), 'Игровые R6-модели · Свет, головы и встроенная улыбка приближены в Blender · Не скриншот Studio', font=small, fill='#BBD5E8')
    for index, (shot, name, role) in enumerate((('npc-market', 'ЛЕВ', 'Удочки и мастерская'), ('npc-mara', 'МАРА', 'Улов и поручения'), ('npc-captain', 'КАПИТАН МИРОН', 'Лодки и экспедиции'))):
        x = index * 468
        image = Image.open(directory / ('quiet-cove-' + shot + '.png')).convert('RGB')
        canvas.paste(image.resize((464, 464)), (x, 89))
        draw.rectangle((x + 12, 102, x + 450, 139), fill='#213E5E')
        draw.text((x + 24, 108), name, font=label, fill='#FFF7DF')
        draw.text((x + 20, 568), role, font=label, fill='#FFF7DF')
    draw.text((20, 616), 'Диалоги, выдача поручений и награды работают в игре; это только предпросмотр внешности NPC.', font=small, fill='#BBD5E8')
    canvas.save(target)
    print(target)

if '--compose-npcs' in sys.argv:
    i = sys.argv.index('--compose-npcs')
    compose_npcs(sys.argv[i + 1], sys.argv[i + 2])
    raise SystemExit(0)

if '--compose' in sys.argv:
    compose(sys.argv[sys.argv.index('--compose') + 1])
    raise SystemExit(0)

import bpy
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
source = Path(args[0] if args else '/workspace/outputs/quiet-cove-world.json')
output = Path(args[1] if len(args) > 1 else '/workspace/outputs')
selected = set(args[args.index('--shots') + 1].split(',')) if '--shots' in args else None
output.mkdir(parents=True, exist_ok=True)
data = json.loads(source.read_text())
lighting = data.get('Lighting', {})
effects = data.get('Effects', {})
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.eevee.taa_render_samples = 32
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'None'
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1
scene.render.film_transparent = False
scene.world.color = (0.55, 0.68, 0.8)
scene.world.use_nodes = True
nodes = scene.world.node_tree.nodes
links = scene.world.node_tree.links
world = nodes.get('Background')
# Exported ambient/diffuse settings guide this approximation. Blender does not
# reproduce Roblox's Soft lighting, Atmosphere, exposure or display pipeline.
outdoor = lighting.get('OutdoorAmbient', (0.49, 0.56, 0.65))
diffuse = lighting.get('EnvironmentDiffuseScale', 0.45)
world.inputs['Strength'].default_value = 0.22 + diffuse * 0.55 + sum(outdoor) / 3 * 0.35
coordinates = nodes.new('ShaderNodeTexCoord')
separate = nodes.new('ShaderNodeSeparateXYZ')
links.new(coordinates.outputs['Normal'], separate.inputs[0])
ramp = nodes.new('ShaderNodeValToRGB')
sky_height = nodes.new('ShaderNodeMath')
sky_height.operation = 'MULTIPLY'
sky_height.inputs[1].default_value = -1
links.new(separate.outputs['Z'], sky_height.inputs[0])
links.new(sky_height.outputs[0], ramp.inputs['Fac'])
ramp.color_ramp.elements[0].position = 0
ramp.color_ramp.elements[0].color = (0.63, 0.82, 0.96, 1)
ramp.color_ramp.elements[1].position = 0.82
ramp.color_ramp.elements[1].color = (0.18, 0.48, 0.82, 1)
links.new(ramp.outputs['Color'], world.inputs['Color'])

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
    bsdf.inputs['Roughness'].default_value = 0.80 if kind in ('Sand', 'Rock', 'Slate') else 0.68
    if kind == 'Neon':
        bsdf.inputs['Emission Color'].default_value = rgba
        bsdf.inputs['Emission Strength'].default_value = 0.35
    materials[key] = mat
    return mat

def primitive(kind):
    if kind in meshes:
        return meshes[kind]
    if kind == 'ClassicHead':
        bpy.ops.mesh.primitive_cube_add(size=1)
        obj = bpy.context.object
        bevel = obj.modifiers.new('Classic rounded head approximation', 'BEVEL')
        bevel.width = 0.22
        bevel.segments = 4
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=bevel.name)
    elif kind == 'Ball':
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
    if kind in ('Ball', 'Cylinder', 'ClassicHead'):
        for face in mesh.polygons:
            face.use_smooth = True
    return mesh

def classic_face_material():
    # Approximation of the built-in Roblox smile, generated locally for preview.
    image = bpy.data.images.new('Builtin smile approximation', width=128, height=128, alpha=True)
    pixels = []
    for y in range(128):
        for x in range(128):
            u, v = x / 127, y / 127
            eye = ((u - .31) / .045) ** 2 + ((v - .65) / .065) ** 2 < 1 or ((u - .69) / .045) ** 2 + ((v - .65) / .065) ** 2 < 1
            curve = .28 + 1.6 * (u - .5) ** 2
            smile = .27 < u < .73 and abs(v - curve) < .018
            pixels.extend((.012, .014, .018, 1 if eye or smile else 0))
    image.pixels[:] = pixels
    mat = bpy.data.materials.new('Builtin face approximation')
    mat.use_nodes = True
    mat.surface_render_method = 'DITHERED'
    texture = mat.node_tree.nodes.new('ShaderNodeTexImage')
    texture.image = image
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Roughness'].default_value = .9
    mat.node_tree.links.new(texture.outputs['Color'], shader.inputs['Base Color'])
    mat.node_tree.links.new(texture.outputs['Alpha'], shader.inputs['Alpha'])
    return mat

face_material = None
for index, part in enumerate(data['Parts']):
    shape = 'ClassicHead' if part.get('ClassicHead') else ('Wedge' if part['Class'] == 'WedgePart' else part['Shape'])
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
    if len(frame) != 12 or any(not isinstance(value, (int, float)) or not math.isfinite(value) for value in frame):
        raise ValueError('Non-finite production CFrame: ' + part['Name'])
    cf = Matrix(((frame[3],frame[4],frame[5],frame[0]),
                 (frame[6],frame[7],frame[8],frame[1]),
                 (frame[9],frame[10],frame[11],frame[2]), (0,0,0,1)))
    size = part['Size']
    obj.matrix_world = convert @ cf @ Matrix.Diagonal((*size, 1))
    if part.get('ClassicFace'):
        if face_material is None:
            face_material = classic_face_material()
        face_mesh = bpy.data.meshes.new('Classic face preview plane')
        face_mesh.from_pydata([(-.36,-.38,-.505),(.36,-.38,-.505),(.36,.38,-.505),(-.36,.38,-.505)], [], [(0,1,2,3)])
        face_mesh.uv_layers.new(name='UVMap')
        for loop, uv in zip(face_mesh.uv_layers.active.data, ((0,0),(1,0),(1,1),(0,1))):
            loop.uv = uv
        face_object = bpy.data.objects.new(part['Name'] + '/builtin_face_approximation', face_mesh)
        scene.collection.objects.link(face_object)
        face_object.data.materials.append(face_material)
        face_object.matrix_world = obj.matrix_world

# Global terrain water, represented as a flat plane (the production tint is retained).
bpy.ops.mesh.primitive_plane_add(size=10000, location=(0, 0, -0.02))
water = bpy.context.object
water.name = 'TerrainWater_approximate_surface'
water.data.materials.append(material(data['Palette']['Water']))
bsdf = water.data.materials[0].node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Roughness'].default_value = 0.24
bsdf.inputs['Metallic'].default_value = 0.08

light_data = bpy.data.lights.new('SoftDaylight', 'SUN')
light_data.energy = lighting.get('Brightness', 2.2) * 0.9
light_data.angle = math.radians(12)
shift = lighting.get('ColorShift_Top', (0, 0, 0))
light_data.color = tuple(0.96 + channel * 0.25 for channel in shift)
light = bpy.data.objects.new('SoftDaylight', light_data)
scene.collection.objects.link(light)
clock = lighting.get('ClockTime', 13)
light.rotation_euler = (math.radians(25), math.radians((clock - 12) * -25), math.radians(-22))

camera_data = bpy.data.cameras.new('GeometryPreview')
camera = bpy.data.objects.new('GeometryPreview', camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera_data.clip_end = 20000
camera_data.lens = 26

# Apply only the exported restrained color-correction direction. No attempt is
# made to claim equivalent Roblox postprocessing or atmosphere.
correction = effects.get('QCColor', {}).get('Properties', {})
scene.use_nodes = True
compositor = scene.node_tree
compositor.nodes.clear()
layers = compositor.nodes.new('CompositorNodeRLayers')
saturation = compositor.nodes.new('CompositorNodeHueSat')
saturation.inputs['Saturation'].default_value = 1 + correction.get('Saturation', 0)
contrast = compositor.nodes.new('CompositorNodeBrightContrast')
contrast.inputs['Bright'].default_value = correction.get('Brightness', 0) * 100
contrast.inputs['Contrast'].default_value = correction.get('Contrast', 0) * 100
result = compositor.nodes.new('CompositorNodeComposite')
compositor.links.new(layers.outputs['Image'], saturation.inputs['Image'])
compositor.links.new(saturation.outputs['Image'], contrast.inputs['Image'])
compositor.links.new(contrast.outputs['Image'], result.inputs['Image'])

def render(label, center, offset, scale, width, height):
    if selected is not None and label not in selected:
        return
    camera_data.type = 'ORTHO'
    target = Vector(center)
    camera.location = target + Vector(offset)
    camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera_data.ortho_scale = scale
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.filepath = str(output / ('quiet-cove-' + label + '.png'))
    bpy.ops.render.render(write_still=True)

def ground(label, position, target, width=1280, height=720, lens=26):
    if selected is not None and label not in selected:
        return
    # Input remains Roblox world coordinates to make camera review straightforward.
    def point(value):
        return Vector((value[0], -value[2], value[1]))
    camera_data.type = 'PERSP'
    camera_data.lens = lens
    camera.location = point(position)
    direction = point(target) - camera.location
    camera.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.filepath = str(output / ('quiet-cove-' + label + '.png'))
    bpy.ops.render.render(write_still=True)

ground('harbor-ground', (0, 12.5, -32), (0, 16.5, 19), lens=18.6)
ground('palm-ground', (26, 12.5, -14), (40, 18, 4), 720, 734, lens=25)
ground('npc-market', (17, 11.7, -35), (20, 10.5, -25), 1000, 1000, lens=36)
ground('npc-mara', (-23, 11.7, -35), (-20, 10.5, -25), 1000, 1000, lens=36)
ground('npc-captain', (-10, 12.2, 62), (-7, 11.1, 72), 1000, 1000, lens=36)
islands = {i['Id']: i for i in data['Islands']}
dunes = islands['Dunes']
ground('dunes-ground', (dunes['X'] + 7, 12.5, dunes['Z'] - 58),
       (dunes['X'] + 10, 12, dunes['Z'] + 6))
render('cove-geometry', (0, 15, 6), (145, 205, 150), 211, 1280, 724)
for name in (('Dunes', 'Bloom', 'Storm') if '--all-islands' in args else ()):
    island = islands[name]
    # Cameras show the same real island dimensions, with the fishing pier in view.
    center = (island['X'], -island['Z'] + 10, 8)
    render(name.lower() + '-geometry', center, (140, 220, 175), 213, 480, 330)
print('Rendered actual production geometry to', output)
