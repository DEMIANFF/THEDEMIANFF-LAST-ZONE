#!/usr/bin/env python3
"""Audit existing V3 derivatives against source hashes, without claiming original access."""
import hashlib
import json
from pathlib import Path
import struct
from recover_aurora_v3 import manifest_entries

ROOT = Path(__file__).resolve().parents[2]


def glb_document(path):
    with path.open("rb") as stream:
        header = stream.read(20)
        if len(header) != 20:
            raise ValueError("Truncated GLB: " + str(path))
        magic, version, total, chunk_size, chunk_type = struct.unpack("<5I", header)
        if (magic != 0x46546C67 or version != 2 or total != path.stat().st_size
                or chunk_type != 0x4E4F534A or chunk_size > total - 20):
            raise ValueError("Invalid GLB: " + str(path))
        return json.loads(stream.read(chunk_size))


def main():
    manifest = json.loads((ROOT / "docs/aurora-v3/AURORA_V3_INVENTARIO_80.json").read_text())
    sources = {item["name"]: item for item in manifest_entries(manifest)}
    registry = json.loads((ROOT / "docs/aurora-v3/runtime_derivatives.json").read_text())
    records = []
    for entry in registry["originals"]:
        path = ROOT / entry["path"]
        source = sources[entry["original"]]
        doc = glb_document(path)
        extras = doc["asset"]["extras"]
        if extras.get("source_sha256") != source["sha256"]:
            raise ValueError("Derivative provenance mismatch: " + entry["path"])
        if not extras.get("license", "").startswith(entry["source_license_prefix"]):
            raise ValueError("Declared derivative license changed: " + entry["path"])
        if not doc.get("meshes"):
            raise ValueError("Empty derivative: " + entry["path"])
        with path.open("rb") as stream:
            digest = hashlib.file_digest(stream, "sha256").hexdigest()
        records.append({"original": entry["original"], "source_sha256_expected": source["sha256"],
                        "derivative": entry["path"], "derivative_sha256_actual": digest,
                        "original_bytes_reverified": False, "meshes": len(doc["meshes"]),
                        "source_clips_declared": source["animations"],
                        "derivative_clips": [a.get("name", "") for a in doc.get("animations", [])],
                        "license_declared": extras.get("license"),
                        "license_source_verified": False,
                        "visual_acceptance": "PENDIENTE",
                        "physical_motorola_test": False})
    output = ROOT / "native-godot/out/qa/aurora-v3-provenance.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")
    print("AURORA_V3_DERIVATIVE_PROVENANCE PASS", len(records))
    print("ORIGINALS_NOT_REVERIFIED; VISUAL_AND_LICENSE_ACCEPTANCE_NOT_IMPLIED")


if __name__ == "__main__":
    main()
