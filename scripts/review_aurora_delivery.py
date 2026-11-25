"""Verify a downloaded Aurora build and make contact sheets from its Godot captures."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import struct

from PIL import Image, ImageDraw


def check_delivery(folder, revision):
    [apk] = folder.rglob("*.apk")
    build = apk.parent
    report = json.loads((build / "vulkan-verification/apk-verification.json").read_text())
    with apk.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    recorded = (build / "SHA256SUMS.txt").read_text().split()[0]
    if (digest != recorded or digest != report["sha256"] or
            (build / "BUILD.txt").read_text().splitlines()[0] != revision):
        raise ValueError("Downloaded APK, build revision and recorded digests disagree")
    for name in ("qa", "qa-exported-vulkan"):
        summary = (build / name / "summary.log").read_text().strip()
        if summary != "AURORA_QA_ALL_PASS":
            raise ValueError(f"{name} did not finish successfully")
        for log in sorted((build / name).glob("*.log")):
            if log.name.startswith(("v75189_lila", "v75190_p90", "v752_regression", "weapon_visual_qa")):
                for line in log.read_text(errors="replace").splitlines():
                    if line.startswith(("V75189_STANCE", "V75190_CROUCH", "V752_CROUCH_HEAD_DROP",
                                        "V74_1_RIG_GRIP_AHEAD", "V75190_P90 ")):
                        print(name, line)
    signature = (build / "vulkan-verification/signature.txt").read_text()
    signer = (build / "preview-signer-sha256.txt").read_text().strip()
    if ("Signer #1 certificate SHA-256 digest: " + signer not in signature or
            not report["signature_v2_v3"] or not report["zip_alignment_16k"] or report["crc"] != "PASS"):
        raise ValueError("Incomplete Android verification evidence")
    print("AURORA_REVIEW_DELIVERY", json.dumps(dict(report, certificate_sha256=signer)))


def contact_sheets(folder, output, family, emit_images):
    paths = sorted(folder.rglob(f"*-motorola-{family}-*.png"))
    if not paths:
        raise ValueError(f"Missing real {family} captures")
    for offset in range(0, len(paths), 3):
        group = paths[offset:offset + 3]
        width, height = (350, 285) if family == "lila" else (482, 217)
        sheet = Image.new("RGB", (len(group) * width, height + 22), (21, 25, 34))
        draw = ImageDraw.Draw(sheet)
        for column, file in enumerate(group):
            with Image.open(file) as original:
                if original.size != (964, 434):
                    raise ValueError(f"Unexpected viewport in {file.name}")
                image = original.convert("RGB")
                if family == "lila":
                    # The capture camera looks at the operator at screen center.
                    image = image.crop((225, 0, 739, 434))
                image.thumbnail((width, height), Image.Resampling.LANCZOS)
                sheet.paste(image, (column * width + (width - image.width) // 2, 0))
            draw.text((column * width + 6, height + 2), file.stem.split(f"-{family}-")[-1],
                      fill="white")
        dest = output / f"{family}-{offset // 3 + 1}.jpg"
        sheet.save(dest, quality=85, optimize=True)
        if emit_images:
            # Optional transport for reviewers who can read Actions but cannot mount artifacts.
            encoded = base64.b64encode(dest.read_bytes()).decode("ascii")
            for start in range(0, len(encoded), 3000):
                print("AURORA_REVIEW_JPEG", dest.name, start, encoded[start:start + 3000])


def inspect_model(path):
    with path.open("rb") as stream:
        magic, version, size, length, chunk = struct.unpack("<4sIIII", stream.read(20))
        if (magic, version, size, chunk) != (b"glTF", 2, path.stat().st_size, 0x4e4f534a):
            raise ValueError("Invalid glTF payload")
        doc = json.loads(stream.read(length))
    print("AURORA_SOURCE_MODEL", path.name, "clips", len(doc.get("animations", [])))
    for node in doc["nodes"]:
        if "mesh" in node:
            mesh = doc["meshes"][node["mesh"]]
            bounds = []
            for primitive in mesh["primitives"]:
                accessor = doc["accessors"][primitive["attributes"]["POSITION"]]
                bounds.append([accessor["min"], accessor["max"]])
            print("AURORA_SOURCE_PART", json.dumps([node.get("name"), mesh.get("name"), bounds,
                                                   node.get("matrix"), node.get("translation")]))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifacts", type=Path)
    parser.add_argument("revision")
    parser.add_argument("output", type=Path)
    parser.add_argument("--emit-images", action="store_true")
    parser.add_argument("--inspect-glb", type=Path)
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.revision):
        parser.error("Expected an immutable commit SHA")
    check_delivery(args.artifacts, args.revision)
    args.output.mkdir(parents=True, exist_ok=True)
    for category in ("lila", "armory"):
        contact_sheets(args.artifacts, args.output, category, args.emit_images)
    if args.inspect_glb:
        inspect_model(args.inspect_glb)
