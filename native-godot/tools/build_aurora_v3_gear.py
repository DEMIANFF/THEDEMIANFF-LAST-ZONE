"""Generate compact third-person Aurora gear from the verified GLB originals."""
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_aurora_v3_weapons import copy_part, merge, plain, source_metadata, stamp


GEAR = (
    ("tactical_helmet_with_headset_game-ready.glb", "AuroraHelmet", "Object_4",
     (.285, .318, .268), (0, 0, .09), (.15, .18, .19), 2500),
    ("tactical_plate_carrier_vest_-_game_ready.glb", "AuroraPlateCarrier", "Object_4",
     (.385, .358, .392), (0, -.035, 0), (.21, .24, .22), 2200),
    ("military_armor_3d_model.glb", "AuroraHeavyVest", "Object_4",
     (.410, .375, .403), (0, -.035, 0), (.19, .23, .24), 2800),
    ("medical_syringe_-_jeringa_medica_videogame_free.glb", "AuroraSyringe",
     "ModSyringe_MatSyringe_0", (.039, .103, .220), (0, 0, 0), (.14, .72, .75), 900),
)


def build(raw, result, entry):
    filename, name, part, size, offset, color, budget = entry
    source = raw / filename
    metadata = source_metadata(source)
    assert metadata["license"].startswith("CC-BY-4.0")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    original = bpy.data.objects[part]
    points = [original.matrix_world @ Vector(corner) for corner in original.bound_box]
    lower = Vector([min(p[i] for p in points) for i in range(3)])
    upper = Vector([max(p[i] for p in points) for i in range(3)])
    center = (lower + upper) * .5
    scale = Matrix.Diagonal([size[i] / (upper[i] - lower[i]) for i in range(3)] + [1])
    mapping = Matrix.Translation(Vector(offset)) @ scale @ Matrix.Translation(-center)
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    surface = plain(name, color, .20)
    selected = [root]
    merge([copy_part(root, original, mapping, surface)], name + "Mesh", budget, selected)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in selected:
        obj.select_set(True)
    result.mkdir(parents=True, exist_ok=True)
    output = result / (name + ".glb")
    bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB", use_selection=True,
                              export_animations=False, export_skins=False, export_extras=True)
    stamp(output, metadata, source, "Simplified geometry, normalized scale and removed source texture; uses an original Aurora material.")


if __name__ == "__main__":
    originals, destination = [Path(v).resolve() for v in sys.argv[sys.argv.index("--") + 1:]]
    for gear in GEAR:
        build(originals, destination, gear)
