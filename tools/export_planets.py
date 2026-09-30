"""Run with Blender: blender -b --python tools/export_planets.py -- --stage=basic|all"""

import math
import sys
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "models"
OUT.mkdir(parents=True, exist_ok=True)
stage = "all"
for arg in sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []:
    if arg.startswith("--stage="):
        stage = arg.split("=", 1)[1]
if stage not in {"basic", "all"}:
    raise ValueError("stage must be basic or all")


def material(name, color, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.9
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def palette(name):
    if name == "sun":
        return [material("Sun_Gold_Emissive", (1.0, 0.50, 0.07), 1.3),
                material("Sun_Amber_Emissive", (1.0, 0.28, 0.025), 0.9)]
    if name == "earth":
        return [material("Earth_Ocean", (0.025, 0.20, 0.55)),
                material("Earth_Land", (0.11, 0.45, 0.25)),
                material("Earth_Highlands", (0.37, 0.43, 0.25)),
                material("Earth_Ice", (0.78, 0.87, 0.91))]
    if name == "mars":
        return [material("Mars_Rust", (0.62, 0.22, 0.105)),
                material("Mars_Ochre", (0.77, 0.35, 0.16)),
                material("Mars_Dark", (0.34, 0.125, 0.09)),
                material("Mars_Ice", (0.78, 0.71, 0.62))]
    return [material("Jupiter_Cream", (0.81, 0.69, 0.51)),
            material("Jupiter_Tan", (0.65, 0.41, 0.25)),
            material("Jupiter_Rust", (0.55, 0.28, 0.17)),
            material("Jupiter_Light", (0.89, 0.79, 0.62))]


def paint(name, point):
    x, y, z = point
    latitude = math.asin(max(-1.0, min(1.0, z)))
    longitude = math.atan2(y, x)
    noise = (math.sin(longitude * 5.0 + z * 8.0) * 0.18
             + math.sin(longitude * 11.0 - z * 13.0) * 0.08)
    if name == "sun":
        return 1 if noise > 0.11 else 0
    if name == "earth":
        if abs(z) > 0.88:
            return 3
        continent = (math.sin(longitude * 2.6 + z * 5.0)
                     + 0.55 * math.cos(longitude * 5.0 - z * 7.0) + noise)
        if continent > 0.58:
            return 2 if continent > 1.1 else 1
        return 0
    if name == "mars":
        if abs(z) > 0.92:
            return 3
        return 2 if noise < -0.14 else (1 if noise > 0.08 else 0)
    band = math.sin(latitude * 15.0 + math.sin(longitude * 3.0) * 0.35)
    if band > 0.42:
        return 3
    if band < -0.52:
        return 2
    return 1 if band < 0.0 else 0


def export_body(name):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=20)
    obj = bpy.context.object
    obj.name = name.capitalize()
    obj.data.name = f"{obj.name}_LowPolyMesh"
    for mat in palette(name):
        obj.data.materials.append(mat)
    for face in obj.data.polygons:
        point = face.center.normalized()
        face.material_index = paint(name, point)
        face.use_smooth = True
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / f"{name}.glb"),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
    )
    print(f"Exported {name}.glb ({len(obj.data.polygons)} faces)")


for body in (["sun", "earth"] if stage == "basic" else ["sun", "earth", "mars", "jupiter"]):
    export_body(body)
