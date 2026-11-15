"""Build the handheld third-person weapon meshes from the verified transfer."""
import hashlib
import json
from pathlib import Path
import struct
import sys

import bpy
from mathutils import Matrix, Vector


MP40_BODY = ("Cube.007_MP40_0", "Cylinder.017_MP40_0", "Cube.015_MP40_0", "Circle_MP40_0")
SCAR_PARTS = tuple(f"Object_{i}" for i in range(133, 148) if i != 142)


def source_metadata(path):
    with path.open("rb") as stream:
        _, _, _, size, _ = struct.unpack("<5I", stream.read(20))
        return json.loads(stream.read(size))["asset"]["extras"]


def stamp(path, metadata, source, changes):
    content = path.read_bytes()
    _, revision, _, size, _ = struct.unpack_from("<5I", content)
    hierarchy = json.loads(content[20:20 + size])
    hierarchy["asset"]["extras"] = dict(metadata, changes=changes,
        source_sha256=hashlib.file_digest(source.open("rb"),"sha256").hexdigest())
    encoded = json.dumps(hierarchy, separators=(",", ":")).encode()
    encoded += b" " * (-len(encoded) % 4)
    remaining = content[20 + size:]
    path.write_bytes(struct.pack("<5I", 0x46546C67, revision, 20 + len(encoded) + len(remaining),
                                 len(encoded), 0x4E4F534A) + encoded + remaining)


def plain(name, rgb, metallic):
    material=bpy.data.materials.new(name)
    material.use_nodes=True
    shader=material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value=(*rgb, 1)
    shader.inputs["Roughness"].default_value=.68
    shader.inputs["Metallic"].default_value=metallic
    return material


def copy_part(root, original, mapping, material=None):
    mesh=original.data.copy()
    mesh.transform(mapping @ original.matrix_world)
    if material is not None:
        mesh.materials.clear()
        mesh.materials.append(material)
        for polygon in mesh.polygons:
            polygon.material_index=0
    obj=bpy.data.objects.new(original.name+"_Aurora",mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent=root
    return obj


def merge(parts, name, max_triangles, aim):
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    obj=parts[0]
    bpy.context.view_layer.objects.active=obj
    if len(parts)>1:
        bpy.ops.object.join()
    obj.name=name
    obj.data.calc_loop_triangles()
    count=len(obj.data.loop_triangles)
    if count>max_triangles:
        decimate=obj.modifiers.new("Mobile geometry","DECIMATE")
        decimate.ratio=max_triangles/count
        bpy.ops.object.modifier_apply(modifier=decimate.name)
    aim.append(obj)
    return obj


def marker(root, name, location, aim):
    obj=bpy.data.objects.new(name,None)
    bpy.context.collection.objects.link(obj)
    obj.parent=root
    obj.location=location
    aim.append(obj)


def build(originals, output, slot):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mp40=slot=="mp40"
    source=originals/("mp40.glb" if mp40 else "animated_scar.glb")
    metadata=source_metadata(source)
    assert metadata["license"].startswith("CC-BY-4.0")
    bpy.ops.import_scene.gltf(filepath=str(source))
    initial={obj.name:obj for obj in bpy.context.scene.objects}
    root=bpy.data.objects.new("MP40" if mp40 else "SCAR",None)
    bpy.context.collection.objects.link(root)
    aim=[root]
    if mp40:
        mapping=Matrix.Scale(.121,4) @ Matrix.Translation(Vector((0,.92,.03)))
        merge([copy_part(root,initial[name],mapping) for name in MP40_BODY],
              "Receiver",4800,aim)
        merge([copy_part(root,initial["Cube.006_MP40_0"],mapping)],"Magazine",720,aim)
        bpy.ops.mesh.primitive_cylinder_add(vertices=10,radius=.009,depth=.042,
            location=(.028,.10,.069),rotation=(0,1.5707963,0))
        lever=bpy.context.object
        lever.name="ChargingHandle"
        lever.parent=root
        lever.data.materials.append(plain("Handle",(.075,.085,.095),.5))
        aim.append(lever)
        marker(root,"Muzzle", mapping @ Vector((0,3.74,.535)),aim)
        for image in bpy.data.images:
            longest=max(image.size)
            if longest>1024:
                scale=1024/longest
                image.scale(max(1,round(image.size[0]*scale)),max(1,round(image.size[1]*scale)))
        changes="Retained one model, kept its separate magazine, reduced triangles and textures, added hand and muzzle anchors and a game charging handle."
    else:
        mapping=Matrix.Scale(.134,4) @ Matrix.Diagonal((-1,1,-1,1)) @ Matrix.Translation(Vector((-.53,-1.84,10.97)))
        groups={
            "Polymer": (plain("Aurora polymer",(.31,.26,.16),.05),[]),
            "Metal": (plain("Aurora receiver",(.073,.081,.088),.38),[]),
        }
        for name in SCAR_PARTS:
            original=initial[name]
            group="Polymer" if "tan" in original.data.materials[0].name or "fde" in original.data.materials[0].name else "Metal"
            material, parts=groups[group]
            parts.append(copy_part(root,original,mapping,material))
        for name, (_,parts) in groups.items():
            merge(parts,name,3000,aim)
        marker(root,"Muzzle",mapping @ Vector((.528,6.4847,-11.59)),aim)
        changes="Extracted the rifle geometry in bind coordinates, removed first-person arms and labels, combined materials, reduced geometry, normalized scale and set the muzzle."
    marker(root,"Grip",Vector((0,0,0)),aim)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in aim:
        obj.select_set(True)
    output.mkdir(parents=True,exist_ok=True)
    target=output/f"aurora_{slot}.glb"
    bpy.ops.export_scene.gltf(filepath=str(target),export_format="GLB",use_selection=True,
                             export_animations=False,export_skins=False,export_extras=True)
    stamp(target,metadata,source,changes)


raw, result = [Path(v).resolve() for v in sys.argv[sys.argv.index("--") + 1:]]
for weapon in ("mp40","scar"):
    build(raw,result,weapon)
