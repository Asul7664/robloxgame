"""Anatomical limbs for the original Sahur geometry study.

The right hand is sculpted around a separate bat.  No bat geometry or weights
are ever placed in an arm.  ``build_limbs`` deliberately receives the builder's
collections/helpers so there is one rig and one ownership map.
"""
import math

import bpy
from mathutils import Matrix, Vector


def build_limbs(api):
    sphere, path, lathe, limb = (api[k] for k in ('sphere', 'path', 'lathe', 'limb'))
    wood, end = api['WOOD'], api['END']
    art, own, bones = api['ART'], api['OWN'], api['BONES']

    def mesh_object(name, verts, faces, material, ownership):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(verts, [], faces)
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        obj.data.materials.append(material)
        for face in mesh.polygons:
            face.use_smooth = True
        art.append(obj)
        own[obj] = ownership
        return obj

    def tube(name, sections, material, ownership, sides=32):
        """Watertight elliptical rings with a stable, untwisted transverse axis.

        Sections contain (centre, transverse_radius, sagittal_radius).  Unlike
        strings of spheres this creates fingers with actual shaft/knuckle/tip
        transitions, not bead-like joints.
        """
        verts, faces = [], []
        centres = [Vector(row[0]) for row in sections]
        for i, (centre, width, depth) in enumerate(sections):
            tangent = centres[min(i + 1, len(centres) - 1)] - centres[max(0, i - 1)]
            tangent.normalize()
            side = Vector((1, 0, 0))
            side -= tangent * side.dot(tangent)
            if side.length < .1:
                side = Vector((0, 1, 0)) - tangent * tangent.y
            side.normalize()
            normal = tangent.cross(side).normalized()
            centre = Vector(centre)
            for j in range(sides):
                angle = j * math.tau / sides
                point = centre + side * (width * math.cos(angle)) + normal * (depth * math.sin(angle))
                verts.append(tuple(point))
        for i in range(len(sections) - 1):
            for j in range(sides):
                a, b = i * sides + j, i * sides + (j + 1) % sides
                faces.append((a, b, b + sides, a + sides))
        faces.append(tuple(reversed(range(sides))))
        faces.append(tuple((len(sections) - 1) * sides + j for j in range(sides)))
        return mesh_object(name, verts, faces, material, ownership)

    def continuous(name, objects, ownership, voxel):
        """Join/remesh tissue, removing bookkeeping before Blender frees IDs."""
        survivor = objects[0]
        for obj in objects[1:]:
            art.remove(obj)
            own.pop(obj, None)
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = survivor
        bpy.ops.object.join()
        joined = bpy.context.object
        joined.name = name
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        modifier = joined.modifiers.new('Unbroken anatomical skin', 'REMESH')
        modifier.mode = 'VOXEL'
        modifier.voxel_size = voxel
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        modifier = joined.modifiers.new('Soften tissue transitions', 'SMOOTH')
        modifier.factor = .85
        modifier.iterations = 4
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        for face in joined.data.polygons:
            face.use_smooth = True
        own[joined] = ownership
        return joined

    def finger(name, points, radius, ownership, flattened=.82):
        """Smooth phalanges with small knuckle swells and a rounded fingertip."""
        points = [Vector(v) for v in points]
        sections = []
        # Catmull-Rom maintains the sculpted curl and rounded knuckle profile.
        for i in range(len(points) - 1):
            p0 = points[max(0, i - 1)]
            p1, p2 = points[i], points[i + 1]
            p3 = points[min(len(points) - 1, i + 2)]
            for step in range(7):
                t = step / 7
                centre = .5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3)
                progress = (i + t) / (len(points) - 1)
                swell = 1 + .075 * math.cos(progress * math.tau * 2)
                taper = 1 - .25 * progress
                r = radius * swell * taper
                sections.append((centre, r, r * flattened))
        tangent = (points[-1] - points[-2]).normalized()
        end_radius = radius * .75
        sections.extend([
            (points[-1], end_radius, end_radius * flattened),
            (points[-1] + tangent * end_radius * .55, end_radius * .79, end_radius * .79 * flattened),
            (points[-1] + tangent * end_radius * .9, end_radius * .40, end_radius * .40 * flattened),
            (points[-1] + tangent * end_radius, .0015, .0015),
        ])
        return tube(name, sections, wood, ownership, 28)

    bones.setdefault('Root', ((0, 0, .16), (0, 0, 3.05), None))
    bones.setdefault('Body', ((0, 0, 3.05), (0, 0, 8.16), 'Root'))

    right_grip = Vector((-1.25, -.42, 3.30))
    club_tip = Vector((-2.50, -.60, .18))

    for side, sign in (('R', -1), ('L', 1)):
        shoulder = Vector((sign * 1.01, .025, 5.15))
        elbow = Vector((sign * 1.26, -.010, 4.30))
        wrist = Vector((sign * 1.25, -.225, 3.50))
        palm = wrist + Vector((0, -.045, -.205))
        bones['UpperArm.' + side] = (shoulder, elbow, 'Body')
        bones['Forearm.' + side] = (elbow, wrist, 'UpperArm.' + side)
        bones['Hand.' + side] = (wrist, palm + Vector((0, -.025, -.22)), 'Forearm.' + side)

        # A tapering upper arm and a subtly fuller proximal forearm retain a
        # human silhouette, including a small medial elbow rather than a ball.
        upper = limb('UpperArm_' + side, shoulder, elbow, .142, .112, 'UpperArm.' + side)
        forearm = tube('Forearm_' + side, [
            (elbow + Vector((0, 0, .055)), .108, .103),
            (elbow.lerp(wrist, .16), .129, .107),
            (elbow.lerp(wrist, .35), .120, .101),
            (elbow.lerp(wrist, .63), .100, .087),
            (wrist + Vector((0, 0, .045)), .083, .076),
            (wrist + Vector((0, 0, -.06)), .088, .078),
        ], wood, 'Forearm.' + side)
        joint = sphere('ElbowTissue_' + side, elbow, (.111, .105, .12), wood, 'Forearm.' + side, 32, 20)
        # Palm is a flattened tapered wedge.  Its fingers emerge from a broad
        # knuckle line rather than from the bottom of a spherical hand.
        palm_skin = tube('Palm_' + side, [
            (wrist + Vector((0, 0, .035)), .083, .077),
            (wrist + Vector((0, -.013, -.065)), .124, .090),
            (palm + Vector((0, .006, .055)), .169, .103),
            (palm + Vector((0, -.004, -.070)), .176, .098),
            (palm + Vector((0, -.010, -.145)), .148, .082),
            (palm + Vector((0, -.010, -.174)), .111, .057),
        ], wood, 'Hand.' + side)
        thenar = sphere('ThumbPad_' + side, palm + Vector((-sign * .095, -.028, .015)), (.092, .090, .139), wood, 'Hand.' + side, 32, 20)
        continuous('ContinuousArm_' + side, [upper, forearm, joint, palm_skin, thenar], ('ARM', side, elbow.z, wrist.z), .014)

        for i in range(4):
            # Index to little finger across the knuckle line.  Long middle
            # fingers and a distinctly shorter little finger avoid toy hands.
            across = (i - 1.5) * .081
            x = palm.x + sign * across
            base = Vector((x, palm.y - .018, palm.z - .105))
            length = (.345, .390, .365, .285)[i]
            if side == 'R':
                # Flex around the separate club's narrow handle, with distal
                # phalanges returning toward the palm rather than a solid fist.
                points = [base,
                    base + Vector((-sign * .012, -.125, -.110)),
                    base + Vector((-sign * .010, -.232, -.040)),
                    base + Vector((-sign * .006, -.197, .100)),
                ]
            else:
                points = [base,
                    base + Vector((sign * .010, -.020, -length * .34)),
                    base + Vector((sign * .015, -.112, -length * .64)),
                    base + Vector((sign * .007, -.208, -length * .64)),
                ]
            bone = 'Finger%d.%s' % (i, side)
            bones[bone] = (base, points[-1], 'Hand.' + side)
            finger('AnatomicalFinger%d_%s' % (i, side), points, (.046, .047, .044, .037)[i], bone)

        thumb_base = palm + Vector((-sign * .125, -.012, .095))
        if side == 'R':
            thumb_points = [thumb_base,
                palm + Vector((-sign * .188, -.115, .015)),
                palm + Vector((-sign * .125, -.228, -.015)),
                palm + Vector((-sign * .030, -.227, -.008)),
            ]
        else:
            thumb_points = [thumb_base,
                palm + Vector((-sign * .210, -.043, -.025)),
                palm + Vector((-sign * .228, -.084, -.135)),
                palm + Vector((-sign * .188, -.125, -.215)),
            ]
        bone = 'Thumb.' + side
        bones[bone] = (thumb_base, thumb_points[-1], 'Hand.' + side)
        finger('OpposedThumb_' + side, thumb_points, .062, bone, .86)

        hip = Vector((sign * .43, .035, 3.08))
        knee = Vector((sign * .48, -.035, 1.73))
        ankle = Vector((sign * .49, .025, .47))
        bones['Thigh.' + side] = (hip, knee, 'Body')
        bones['Shin.' + side] = (knee, ankle, 'Thigh.' + side)
        bones['Foot.' + side] = (ankle, (ankle.x, -.69, .14), 'Shin.' + side)
        thigh = tube('Thigh_' + side, [
            (hip + Vector((0, 0, .06)), .12, .125),
            (hip.lerp(knee, .08), .173, .168),
            (hip.lerp(knee, .27), .170, .156),
            (hip.lerp(knee, .60), .151, .140),
            (hip.lerp(knee, .85), .132, .125),
            (knee, .123, .119),
        ], wood, 'Thigh.' + side)
        shin = tube('Calf_' + side, [
            (knee + Vector((0, 0, .055)), .120, .117),
            (knee.lerp(ankle, .15) + Vector((0, .014, 0)), .145, .137),
            (knee.lerp(ankle, .30) + Vector((0, .025, 0)), .151, .142),
            (knee.lerp(ankle, .53) + Vector((0, .020, 0)), .130, .120),
            (knee.lerp(ankle, .77), .100, .092),
            (ankle + Vector((0, 0, -.06)), .090, .087),
        ], wood, 'Shin.' + side)
        joint = sphere('Patella_' + side, knee + Vector((0, -.015, 0)), (.128, .123, .130), wood, 'Shin.' + side, 32, 20)
        continuous('ContinuousLeg_' + side, [thigh, shin, joint], ('LEG', side, knee.z, ankle.z), .017)

        # Heel -> instep -> metatarsal pad, with a low sole and medial arch.
        # The five long toes below are independent volumes, not attached beads.
        foot_start = len(art)
        sections = [
            (.355, .025, .105, .145),
            (.315, .115, .055, .265),
            (.245, .158, .035, .340),
            (.100, .160, .035, .460),
            (-.020, .155, .040, .490),
            (-.155, .185, .045, .385),
            (-.325, .233, .035, .277),
            (-.480, .280, .033, .213),
            (-.585, .287, .037, .188),
            (-.655, .253, .045, .154),
            (-.695, .185, .060, .130),
        ]
        verts, faces, sides = [], [], 48
        for y, half_width, bottom, top in sections:
            for j in range(sides):
                angle = math.tau * j / sides
                x = math.cos(angle) * half_width
                # A broad flattened underside, then a continuously rising
                # dorsal surface; pinched medial midfoot creates an arch.
                height = (math.sin(angle) + 1) * .5
                z = bottom + (top - bottom) * height ** .82
                medial = max(0, -sign * x / max(.001, half_width))
                arch = .042 * math.exp(-((y + .08) / .19) ** 2) * medial
                z += arch * (1 - height) ** 2
                verts.append((ankle.x + x, y, z))
        for i in range(len(sections) - 1):
            for j in range(sides):
                a, b = i * sides + j, i * sides + (j + 1) % sides
                faces.append((a, b, b + sides, a + sides))
        faces.append(tuple(reversed(range(sides))))
        faces.append(tuple((len(sections) - 1) * sides + j for j in range(sides)))
        foot = mesh_object('SculptedFoot_' + side, verts, faces, wood, 'Foot.' + side)
        # Subdivision rounds the heel/instep transitions while keeping a flat
        # weight-bearing sole.  The model's ground plane remains at z=.02.
        modifier = foot.modifiers.new('Smooth foot anatomy', 'SUBSURF')
        modifier.levels = 2
        modifier.render_levels = 2
        bpy.context.view_layer.objects.active = foot
        bpy.ops.object.modifier_apply(modifier=modifier.name)

        toe_offsets = (-.205, -.071, .052, .158, .247)
        toe_lengths = (.385, .423, .375, .303, .218)
        toe_widths = (.080, .066, .059, .052, .043)
        toe_bases = (-.575, -.605, -.602, -.580, -.542)
        for i, (offset, length, width, base_y) in enumerate(zip(toe_offsets, toe_lengths, toe_widths, toe_bases)):
            x = ankle.x + sign * offset
            start = Vector((x, base_y, .108 + (.016 if i == 0 else 0)))
            tip = start + Vector((-sign * .018, -length, -.013))
            sections = []
            for t, swelling in ((0, .94), (.14, 1.04), (.30, 1), (.43, .89), (.58, .99), (.74, .93), (.88, .82), (.96, .57), (1, .12)):
                centre = start.lerp(tip, t)
                centre.z += .012 * math.sin(t * math.pi)
                sections.append((centre, width * swelling, width * .82 * swelling))
            toe = tube('HumanToe%d_%s' % (i, side), sections, wood, 'Foot.' + side, 32)
            # Thin nail plates remain part of the foot's rigid weighting. They
            # read as carved anatomy, not coloured toy toenails.
            nail_pos = start.lerp(tip, .76)
            nail_pos.z += width * .74
            nail = sphere('ToeNail%d_%s' % (i, side), nail_pos, (width * .68, length * .145, .008), wood, 'Foot.' + side, 24, 16)

        # A small natural turnout distinguishes the relaxed free side from
        # the club-bearing side without manufacturing a wide-legged stance.
        angle = math.radians(10 if side == 'L' else -4)
        turn = Matrix.Translation(ankle) @ Matrix.Rotation(angle, 4, 'Z') @ Matrix.Translation(-ankle)
        # Flush newly assigned tiny toenail scales before reading matrix_world.
        bpy.context.view_layer.update()
        for obj in art[foot_start:]:
            obj.matrix_world = turn @ obj.matrix_world
        head, tail, parent = bones['Foot.' + side]
        bones['Foot.' + side] = (head, turn @ Vector(tail), parent)

    return right_grip, club_tip
