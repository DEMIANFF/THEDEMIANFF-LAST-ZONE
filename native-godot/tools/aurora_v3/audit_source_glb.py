#!/usr/bin/env python3
"""Audit verified ORIGINAL Aurora V3 files; source integrity is not gameplay approval."""
import argparse
import hashlib
import json
from pathlib import Path
import struct


def inspect_glb(path: Path) -> dict:
    with path.open("rb") as stream:
        header = stream.read(20)
        if len(header) != 20:
            raise ValueError("Invalid GLB header: " + path.name)
        magic, version, declared, json_length, json_type = struct.unpack("<4sIIII", header)
        if magic != b"glTF" or version != 2 or json_type != 0x4E4F534A:
            raise ValueError("Invalid GLB v2/JSON chunk: " + path.name)
        if declared != path.stat().st_size or json_length > declared - 20:
            raise ValueError("Incorrect declared GLB size: " + path.name)
        doc = json.loads(stream.read(json_length))
    animations = [anim.get("name", f"unnamed_{i}")
                  for i, anim in enumerate(doc.get("animations", []))]
    return {
        "source_animations": animations,
        "animations_count": len(animations),
        "skins_count": len(doc.get("skins", [])),
        "skinned_nodes": sum(1 for n in doc.get("nodes", []) if "skin" in n),
        "meshes_count": len(doc.get("meshes", [])),
        "textures_count": len(doc.get("textures", [])),
    }


def audit(originals: Path, inventory: dict) -> dict:
    entries = inventory["files"]
    if len(entries) != inventory["received_files"]:
        raise ValueError("Inventory count mismatch")
    records = []
    for item in entries:
        path = originals / item["name"]
        if not path.is_file() or path.is_symlink():
            raise ValueError("Missing regular original: " + item["name"])
        if path.stat().st_size != item["size_bytes"]:
            raise ValueError("Original size mismatch: " + item["name"])
        with path.open("rb") as stream:
            actual_sha = hashlib.file_digest(stream, "sha256").hexdigest()
        if actual_sha != item["sha256"]:
            raise ValueError("SHA-256 mismatch: " + item["name"])
        record = {"name": item["name"], "bytes": item["size_bytes"],
                  "sha256": actual_sha, "integrity": "verified",
                  "gameplay_integrated": False}
        if path.suffix.lower() == ".glb":
            facts = inspect_glb(path)
            record.update(facts)
            if sorted(item.get("animations", [])) != sorted(facts["source_animations"]):
                raise ValueError("Original animation list mismatch: " + item["name"])
            declared = item.get("asset_license", "").upper().replace("-", "")
            if "BYNC" in declared:
                gate = "hold_noncommercial"
            elif "BYND" in declared:
                gate = "hold_no_derivatives"
            elif "SKETCHFAB STANDARD" in declared:
                gate = "hold_standard_approval"
            elif "BY4.0" in declared:
                gate = "attribution_and_rights_review"
            else:
                gate = "hold_unknown_license"
            record.update({
                "license_gate": gate,
                "triangles_inventory": item.get("triangle_instances"),
                "mobile_geometry_review": item.get("triangle_instances", 0) > 35000,
                "mobile_memory_review": item["size_bytes"] > 16 * 1024 * 1024,
                "retarget_required": bool(facts["source_animations"]),
                "animation_preserved_in_game": False,
            })
        elif path.suffix.lower() == ".mp3":
            record["license_gate"] = "hold_audio_rights_review"
        else:
            record["license_gate"] = "manual_archive_review"
        records.append(record)
    if sum(x["bytes"] for x in records) != inventory["total_original_bytes"]:
        raise ValueError("Inventory total size mismatch")
    return {
        "scope": "offline_original_integrity_and_glb_metadata_only",
        "original_count": len(records),
        "unique_source_sha256": len(set(x["sha256"] for x in records)),
        "all_source_hashes_verified": True,
        "license_clearance_implied": False,
        "gameplay_integration_implied": False,
        "records": records,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--originals", type=Path, required=True)
    parser.add_argument("--inventory", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        parser.error("Refusing to overwrite an existing audit report")
    report = audit(args.originals, json.loads(args.inventory.read_text(encoding="utf-8")))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n",
                           encoding="utf-8")
    print("VERIFIED", report["original_count"], "UNIQUE_SHA",
          report["unique_source_sha256"])
    print("SOURCE_FILES_ARE_NOT_GAMEPLAY_OR_DISTRIBUTION_APPROVED")


if __name__ == "__main__":
    main()
