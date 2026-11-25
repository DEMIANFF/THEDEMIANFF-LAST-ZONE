"""Prepare the user's exact Aurora V2 P90 for the mobile renderer.

Preserves geometry, UVs, node transforms and source material assignments.
Only embedded texture resolution and redundant opaque blending are changed.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import struct

from PIL import Image

SOURCE_SHA256 = "3daa1c9d1596a223a95ef873271adb961cbf6d75bfcdebf59f6a71b434e1a67e"


def build(source: Path, destination: Path) -> dict:
    original = source.read_bytes()
    if hashlib.sha256(original).hexdigest() != SOURCE_SHA256:
        raise ValueError("P90 source differs from the recovered Aurora V2 original")
    if original[:4] != b"glTF" or struct.unpack_from("<I", original, 4)[0] != 2:
        raise ValueError("Expected glTF 2.0 GLB")
    json_length = struct.unpack_from("<I", original, 12)[0]
    document = json.loads(original[20:20 + json_length])
    binary = original[28 + json_length:]
    if len(document["buffers"]) != 1 or document.get("animations"):
        raise ValueError("Unexpected P90 source structure")
    views = document["bufferViews"]
    replacements = {}
    opaque_images = set()
    source_pixels = mobile_pixels = 0
    for index, image in enumerate(document["images"]):
        view = views[image["bufferView"]]
        start = view.get("byteOffset", 0)
        pixels = Image.open(io.BytesIO(binary[start:start + view["byteLength"]]))
        pixels = pixels.convert("RGBA" if "A" in pixels.getbands() or
                                "transparency" in pixels.info else "RGB")
        source_pixels += pixels.width * pixels.height
        if "A" not in pixels.getbands() or pixels.getchannel("A").getextrema() == (255, 255):
            opaque_images.add(index)
        pixels.thumbnail((512, 512), Image.Resampling.LANCZOS)
        mobile_pixels += pixels.width * pixels.height
        out = io.BytesIO()
        pixels.save(out, format="PNG", optimize=True)
        replacements[image["bufferView"]] = out.getvalue()
        image["mimeType"] = "image/png"
    opaque_conversions = 0
    for material in document["materials"]:
        pbr = material.get("pbrMetallicRoughness", {})
        texture = pbr.get("baseColorTexture", {}).get("index")
        source_index = document["textures"][texture]["source"] if texture is not None else None
        if material.get("alphaMode") == "BLEND" and source_index in opaque_images and \
                pbr.get("baseColorFactor", [1, 1, 1, 1])[3] == 1:
            material["alphaMode"] = "OPAQUE"
            opaque_conversions += 1
    output_binary = bytearray()
    for index, view in enumerate(views):
        start = view.get("byteOffset", 0)
        chunk = replacements.get(index, binary[start:start + view["byteLength"]])
        output_binary.extend(b"\x00" * (-len(output_binary) % 4))
        view["byteOffset"] = len(output_binary)
        view["byteLength"] = len(chunk)
        output_binary.extend(chunk)
    output_binary.extend(b"\x00" * (-len(output_binary) % 4))
    document["buffers"][0]["byteLength"] = len(output_binary)
    extras = document["asset"].setdefault("extras", {})
    extras["source_sha256"] = SOURCE_SHA256
    extras["changes"] = "Embedded textures reduced to at most 512px; redundant blending removed only for fully opaque base color. Original geometry, UVs, nodes and material assignments retained. No original animations in source."
    encoded = json.dumps(document, separators=(",", ":"), ensure_ascii=False).encode()
    encoded += b" " * (-len(encoded) % 4)
    output = struct.pack("<4sII", b"glTF", 2, 28 + len(encoded) + len(output_binary))
    output += struct.pack("<II", len(encoded), 0x4e4f534a) + encoded
    output += struct.pack("<II", len(output_binary), 0x004e4942) + output_binary
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(output)
    return {"source_sha256": SOURCE_SHA256, "source_bytes": len(original),
            "mobile_sha256": hashlib.sha256(output).hexdigest(), "mobile_bytes": len(output),
            "source_texture_pixels": source_pixels, "mobile_texture_pixels": mobile_pixels,
            "textures": len(document["images"]), "opaque_material_conversions": opaque_conversions,
            "triangles": sum(document["accessors"][p["indices"]]["count"] // 3
                             for m in document["meshes"] for p in m["primitives"]),
            "original_animation_count": 0}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    print(json.dumps(build(args.source, args.destination), indent=2))
