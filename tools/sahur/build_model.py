#!/usr/bin/env python3
"""Package Blender geometry as a native Roblox model with embedded meshes.

Usage: python3 tools/sahur/build_model.py /path/to/geometry.json
The JSON is produced by build_sahur.py. No uploaded mesh IDs are required.
Rojo can build this file, but its live plugin cannot write SolidMeshHolder;
import the resulting .rbxm once into Studio before syncing this model.

The native SolidMesh v0 layout was cross-checked against the existing Sahur
asset and the MIT-licensed EgoMoose/rbx-csg-to-mesh-plugin SolidMesh parser:
https://github.com/EgoMoose/rbx-csg-to-mesh-plugin
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import math
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[2]
U64 = lambda value: struct.pack("<Q", value)
WOOD_MATERIALS = {"Honey_Oak", "Golden_Endgrain", "Bark_Sculpt", "Wood_Grain_Inlay", "Wood_Highlights"}
FABRIC_MATERIALS = {"Ocean_Rope", "Rope_Twist"}


def encode_indices(indices):
    """Encode the native signed-delta / 23-bit wrapped index stream."""
    output = bytearray()
    previous = 0
    for index in indices:
        index = int(index)
        assert 0 <= index < 0x800000, "Index exceeds native SolidMesh range"
        delta = index - previous
        if -64 <= delta <= 63:
            output.append(delta & 0x7F)
        else:
            delta &= 0x7FFFFF
            output.extend((0x80 | (delta >> 16), (delta >> 8) & 255, delta & 255))
        previous = index
    return U64(len(indices)) + output


def encode_mesh(positions, normals, triangles, color):
    assert positions and len(normals) == len(positions)
    assert all(len(v) == 3 and all(math.isfinite(x) for x in v) for v in positions + normals)
    assert all(len(t) == 3 for t in triangles)
    faces = [index for triangle in triangles for index in triangle]
    assert faces and min(faces) >= 0 and max(faces) < len(positions)
    payload = b"SolidMesh\0\0\0\0"
    payload += U64(len(positions)) + b"".join(struct.pack("<3f", *p) for p in positions)
    payload += U64(len(normals)) + b"".join(struct.pack("<3f", *n) for n in normals)
    payload += U64(0)  # No UVs: geometry is colored directly, not texture dependent.
    payload += U64(1) + struct.pack("<3f", *(channel / 255 for channel in color))
    payload += encode_indices(faces) + encode_indices(faces) + U64(0)
    payload += encode_indices([0] * len(faces))
    return b"\x03\x01" + U64(len(payload)) + struct.pack("<I", len(payload)) + payload


def decode_mesh(data):
    """Independently read a finished native blob for export validation."""
    assert data[:2] == b"\x03\x01"
    assert struct.unpack_from("<Q", data, 2)[0] == len(data) - 14
    assert struct.unpack_from("<I", data, 10)[0] == len(data) - 14
    assert data[14:27] == b"SolidMesh\0\0\0\0"
    offset = 27

    def count():
        nonlocal offset
        value = struct.unpack_from("<Q", data, offset)[0]
        offset += 8
        return value

    def vectors(arity):
        nonlocal offset
        length = count()
        values = [struct.unpack_from(f"<{arity}f", data, offset + i * arity * 4) for i in range(length)]
        offset += length * arity * 4
        return values

    def indices():
        nonlocal offset
        length = count()
        values = []
        index = 0
        for _ in range(length):
            value = data[offset]
            offset += 1
            if value & 128:
                delta = ((value & 127) << 16) | (data[offset] << 8) | data[offset + 1]
                offset += 2
            else:
                delta = value if value < 64 else value - 128
            index += delta
            values.append(index & 0x7FFFFF)
        return values

    result = {
        "positions": vectors(3), "normals": vectors(3), "uvs": vectors(2), "colors": vectors(3),
        "faces": indices(), "faceNormals": indices(), "faceUvs": indices(), "faceColors": indices(),
    }
    assert offset == len(data), "Unexpected native mesh trailing data"
    return result


def text_property(properties, kind, name, value):
    child = ET.SubElement(properties, kind, {"name": name})
    child.text = str(value)
    return child


def vector_property(properties, name, value):
    child = ET.SubElement(properties, "Vector3", {"name": name})
    for component, number in zip("XYZ", value):
        ET.SubElement(child, component).text = format(number, ".9g")


def frame_property(properties, name, position):
    child = ET.SubElement(properties, "CoordinateFrame", {"name": name})
    for component, number in zip("XYZ", position):
        ET.SubElement(child, component).text = format(number, ".9g")
    for row in range(3):
        for column in range(3):
            ET.SubElement(child, f"R{row}{column}").text = "1" if row == column else "0"


def subtract(a, b):
    return tuple(x - y for x, y in zip(a, b))


def midpoint(a, b):
    return tuple((x + y) * 0.5 for x, y in zip(a, b))


class ModelBuilder:
    def __init__(self):
        self.root = ET.Element("roblox", {"version": "4"})
        self.shared_strings = {}
        self.next_referent = 1

    def item(self, parent, class_name, name):
        referent = f"RBX{self.next_referent}"
        self.next_referent += 1
        item = ET.SubElement(parent, "Item", {"class": class_name, "referent": referent})
        properties = ET.SubElement(item, "Properties")
        text_property(properties, "string", "Name", name)
        return item, properties, referent

    def shared(self, value):
        # XML labels need only be unique; native serializers normalize their hash.
        label = base64.b64encode(hashlib.md5(value).digest()).decode("ascii")
        self.shared_strings[label] = value
        return label

    def finish(self, path):
        definitions = ET.SubElement(self.root, "SharedStrings")
        for label, value in self.shared_strings.items():
            ET.SubElement(definitions, "SharedString", {"md5": label}).text = base64.b64encode(value).decode("ascii")
        ET.indent(self.root, space="  ")
        ET.ElementTree(self.root).write(path, encoding="utf-8", xml_declaration=False)


def export_model(geometry, output):
    builder = ModelBuilder()
    model, model_properties, _ = builder.item(builder.root, "Model", "sahur")
    bone_folder, _, _ = builder.item(model, "Folder", "Rig")
    visuals, _, _ = builder.item(model, "Folder", "Visuals")
    bones = {}
    rig = geometry["rig"]
    assert all(math.isfinite(number) for bone in rig.values() for field in ("head", "tail") for number in bone[field])
    assert rig["RightUpperArm"]["head"][0] > 0 and rig["RightHand"]["head"][0] > 0
    assert rig["LeftUpperArm"]["head"][0] < 0 and rig["LeftHand"]["head"][0] < 0

    for name, bone in rig.items():
        part_name = "HumanoidRootPart" if name == "Root" else "Torso" if name == "Body" else name
        center = midpoint(bone["head"], bone["tail"])
        item, properties, ref = builder.item(model if name == "Root" else bone_folder, "Part", part_name)
        frame_property(properties, "CFrame", center)
        if name == "Root":
            # Catch viewports animate the model pivot around their origin. Keep
            # that pivot at the artwork origin, not at the lower root bone.
            frame_property(properties, "PivotOffset", tuple(-component for component in center))
        vector_property(properties, "size", (0.35, 0.35, 0.35))
        text_property(properties, "float", "Transparency", 1)
        text_property(properties, "bool", "Anchored", str(name == "Root").lower())
        text_property(properties, "bool", "CanCollide", "false")
        text_property(properties, "bool", "CanQuery", "false")
        text_property(properties, "bool", "CanTouch", "false")
        text_property(properties, "bool", "Massless", str(name != "Root").lower())
        text_property(properties, "int", "RootPriority", 127 if name == "Root" else 0)
        bones[name] = (item, ref, center)

    text_property(model_properties, "Ref", "PrimaryPart", bones["Root"][1])
    controller, _, _ = builder.item(model, "AnimationController", "AnimationController")
    builder.item(controller, "Animator", "Animator")

    for name, bone in rig.items():
        if not bone["parent"]:
            continue
        parent_item, parent_ref, parent_center = bones[bone["parent"]]
        _, child_ref, child_center = bones[name]
        _, properties, _ = builder.item(parent_item, "Motor6D", name + "Joint")
        text_property(properties, "Ref", "Part0", parent_ref)
        text_property(properties, "Ref", "Part1", child_ref)
        frame_property(properties, "C0", subtract(bone["head"], parent_center))
        frame_property(properties, "C1", subtract(bone["head"], child_center))

    total_triangles = 0
    for obj in geometry["objects"]:
        vertices = obj["vertices"]
        minima = tuple(min(p[axis] for p in vertices) for axis in range(3))
        maxima = tuple(max(p[axis] for p in vertices) for axis in range(3))
        center = midpoint(minima, maxima)
        dimensions = tuple(max(0.001, high - low) for low, high in zip(minima, maxima))
        positions = [subtract(vertex, center) for vertex in vertices]
        mesh = encode_mesh(positions, obj["normals"], obj["triangles"], obj["color"])
        decoded = decode_mesh(mesh)
        assert len(decoded["positions"]) == len(vertices)
        assert decoded["faces"] == [i for triangle in obj["triangles"] for i in triangle]
        assert decoded["faceNormals"] == decoded["faces"]
        assert not decoded["faceUvs"] and not decoded["uvs"]
        assert len(decoded["faceColors"]) == len(decoded["faces"])
        for position in decoded["positions"]:
            assert all(math.isfinite(component) and abs(component) <= size * 0.5 + 1e-5 for component, size in zip(position, dimensions))
        for normal in decoded["normals"]:
            assert all(math.isfinite(component) for component in normal)
            assert abs(sum(component * component for component in normal) - 1) < 0.005

        item, properties, ref = builder.item(visuals, "UnionOperation", obj["name"])
        frame_property(properties, "CFrame", center)
        vector_property(properties, "size", dimensions)
        vector_property(properties, "InitialSize", dimensions)
        text_property(properties, "NetAssetRef", "SolidMeshHolder", builder.shared(mesh))
        text_property(properties, "SharedString", "MeshData2", builder.shared(b""))
        text_property(properties, "SharedString", "ChildData2", builder.shared(b""))
        # Exact UnionOperation default from Rojo v7.7.1's engine reflection
        # database: PhysicalConfigData.SharedString = Q1NHUEhTAAAAAEJMT0NL.
        # Visual meshes never collide; future NPC movement uses rig colliders.
        text_property(properties, "SharedString", "PhysicalConfigData", builder.shared(b"CSGPHS\0\0\0\0BLOCK"))
        text_property(properties, "bool", "CanCollide", "false")
        text_property(properties, "bool", "CanQuery", "false")
        text_property(properties, "bool", "CanTouch", "false")
        text_property(properties, "bool", "Massless", "true")
        text_property(properties, "bool", "Anchored", "false")
        text_property(properties, "bool", "UsePartColor", "false")
        text_property(properties, "bool", "OffCentered", "false")
        text_property(properties, "float", "SmoothingAngle", 180)
        text_property(properties, "float", "Reflectance", 0)
        material = 512 if obj["material"] in WOOD_MATERIALS else 1312 if obj["material"] in FABRIC_MATERIALS else 272
        # Native Wood/Fabric shading complements the modeled grain and rope.
        # Blender node shaders are preview-only; no external texture assets.
        text_property(properties, "token", "Material", material)
        text_property(properties, "token", "CollisionFidelity", 1)  # Hull, unused decorative collider
        text_property(properties, "token", "RenderFidelity", 1)  # Precise
        text_property(properties, "int", "TriangleCount", len(obj["triangles"]))
        text_property(properties, "Color3uint8", "Color3uint8", (obj["color"][0] << 16) | (obj["color"][1] << 8) | obj["color"][2])
        _, bone_ref, _ = bones[obj["bone"]]
        _, weld_properties, _ = builder.item(item, "WeldConstraint", "RigWeld")
        text_property(weld_properties, "Ref", "Part0", bone_ref)
        text_property(weld_properties, "Ref", "Part1", ref)
        total_triangles += len(obj["triangles"])

    assert total_triangles == geometry["triangles"], "Blender triangle total differs from native export"
    output.parent.mkdir(parents=True, exist_ok=True)
    builder.finish(output)
    return {"objects": len(geometry["objects"]), "bones": len(bones), "joints": len(bones) - 1, "triangles": total_triangles}


def convert_binary(xml_path, binary_path, lune):
    source = """local fs = require('@lune/fs')
local roblox = require('@lune/roblox')
local process = require('@lune/process')
local roots = roblox.deserializeModel(fs.readFile(process.args[1]))
fs.writeFile(process.args[2], roblox.serializeModel(roots))
local roundtrip = roblox.deserializeModel(fs.readFile(process.args[2]))
fs.writeFile(process.args[1], roblox.serializeModel(roundtrip, true))
print('Native Roblox binary and XML round-trip passed')
"""
    binary_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="sahur-export-") as directory:
        script = Path(directory) / "convert.luau"
        script.write_text(source, encoding="utf-8")
        subprocess.run([str(lune), "run", str(script), str(xml_path), str(binary_path)], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("geometry", type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / "assets/creatures/Sahur.rbxmx")
    parser.add_argument("--binary", type=Path)
    parser.add_argument("--lune", type=Path)
    args = parser.parse_args()
    geometry = json.loads(args.geometry.read_text(encoding="utf-8"))
    stats = export_model(geometry, args.output)
    if args.binary:
        lune = args.lune or shutil.which("lune") or ROOT.parent / "robloxgame-tools/bin/lune"
        convert_binary(args.output, args.binary, lune)
    print(json.dumps(stats, ensure_ascii=False))


if __name__ == "__main__":
    main()
