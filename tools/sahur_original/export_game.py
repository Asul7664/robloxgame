"""Build a Roblox import package from the existing original sculpt, never the imported boss.
blender -b -t 6 --python tools/sahur_original/export_game.py
"""
import bpy, json, math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/creatures/original-sahur/game'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'assets/creatures/original-sahur/OriginalSahur.blend'))
rig = bpy.data.objects['OriginalSahurRig']
meshes = [o for o in bpy.data.objects if o.type == 'MESH' and o.parent == rig]
assert len(rig.data.bones) == 25 and meshes
# Explicit import markers avoid guessing FBX bone axes or the club's length.
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
club = rig.data.edit_bones['Club']
marker = rig.data.edit_bones.new('ClubTip'); marker.head = club.tail
marker.tail = club.tail + (club.tail-club.head).normalized()*.1; marker.parent = club
marker = rig.data.edit_bones.new('Facing'); marker.head = (0,-1,.16)
marker.tail = (0,-1,.36); marker.parent = rig.data.edit_bones['Root']
bpy.ops.object.mode_set(mode='OBJECT')
original = sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
# Allocate detail proportionally; tiny pupils/nails retain a minimum budget.
for o in meshes:
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True); bpy.context.view_layer.objects.active = o
    triangles = sum(len(p.vertices)-2 for p in o.data.polygons)
    target = max(32, int(triangles * 15500 / original))
    if triangles > target:
        m = o.modifiers.new('Game topology', 'DECIMATE'); m.ratio = target / triangles
        bpy.ops.object.modifier_apply(modifier=m.name)
bpy.ops.object.select_all(action='DESELECT')
for o in meshes: o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.join()
skin = bpy.context.object; skin.name = 'OriginalSahurSkin'
# One skinned mesh, one colour atlas; all 25 bone groups survive joining.
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=.008)
bpy.ops.object.mode_set(mode='OBJECT')
image = bpy.data.images.new('OriginalSahur_Color', width=2048, height=2048)
image.filepath_raw = str(OUT / 'OriginalSahur_Color.png'); image.file_format = 'PNG'
for material in skin.data.materials:
    node = material.node_tree.nodes.new('ShaderNodeTexImage'); node.image = image
    material.node_tree.nodes.active = node
scene = bpy.context.scene; scene.render.engine = 'CYCLES'; scene.cycles.samples = 8
scene.render.bake.use_pass_direct = False; scene.render.bake.use_pass_indirect = False
scene.render.bake.use_pass_color = True; scene.render.bake.margin = 12
bpy.ops.object.bake(type='DIFFUSE'); image.save()
material = bpy.data.materials.new('OriginalSahurBaked'); material.use_nodes = True
shader = material.node_tree.nodes.get('Principled BSDF'); shader.inputs['Roughness'].default_value = .4
texture = material.node_tree.nodes.new('ShaderNodeTexImage'); texture.image = image
material.node_tree.links.new(texture.outputs['Color'], shader.inputs['Base Color'])
skin.data.materials.clear(); skin.data.materials.append(material)
for polygon in skin.data.polygons: polygon.material_index = 0
# Export only the rig and skin. No review lights/cameras/floor or third-party assets.
bpy.ops.object.select_all(action='DESELECT'); skin.select_set(True); rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.fbx(filepath=str(OUT / 'OriginalSahur.fbx'), use_selection=True,
    object_types={'MESH','ARMATURE'}, add_leaf_bones=False, bake_anim=False,
    axis_forward='-Z', axis_up='Y', path_mode='COPY', embed_textures=True,
    use_mesh_modifiers=False)
triangles = sum(len(p.vertices)-2 for p in skin.data.polygons)
assert triangles <= 20000, triangles
assert skin.vertex_groups.get('Club') and skin.vertex_groups.get('Forearm.R')
for vertex in skin.data.vertices:
    assert vertex.groups and len(vertex.groups) <= 4
    assert abs(sum(g.weight for g in vertex.groups)-1) < .002
report = dict(sourceTriangles=original, triangles=triangles, bones=len(rig.data.bones),
    texture=[2048,2048], meshCount=1, source='OriginalSahur.blend', studioImportVerified=False)
(OUT / 'stats.json').write_text(json.dumps(report, indent=2)+'\n')
print('GAME_EXPORT', json.dumps(report), flush=True)
# Render the actual reduced mesh and baked atlas using the saved review camera.
scene.render.resolution_x=1000;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.cycles.samples=24
scene.render.filepath='/workspace/outputs/original-sahur-game.png'
bpy.ops.render.render(write_still=True)
