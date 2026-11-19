#!/usr/bin/env python3
"""Verify both reproducible GLBs even when the CI model cache is a hit.

Checks the actual GLB JSON chunk, animation names, skinned Lila material
budget, and AWM mesh complexity before importing the models into Godot.
No Blender, network, or third-party Python packages required.
"""
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OPERATOR = ROOT / "assets/characters/aurora_operator.glb"
AWM = ROOT / "assets/weapons/aurora_awm.glb"


def gltf_json(path: Path) -> dict:
    data = path.read_bytes()
    if len(data) < 20:
        raise AssertionError(f"GLB header missing: {path}")
    magic, version, total_length = struct.unpack_from("<III", data)
    assert (magic, version, total_length) == (0x46546C67, 2, len(data)), path
    json_length, json_type = struct.unpack_from("<II", data, 12)
    assert json_type == 0x4E4F534A and 0 < json_length <= len(data) - 20, path
    return json.loads(data[20:20 + json_length])


def assert_operator(gltf: dict) -> None:
    assert gltf.get("skins"), "Cached Lila rig lost its actual skin"
    animations = [str(x.get("name", "")) for x in gltf.get("animations", [])]
    required = (
        "AuroraArmedStrafeLeft", "AuroraArmedStrafeRight",
        "AuroraArmedBackpedal", "AuroraHitFront", "AuroraHitBack",
        "AuroraHitLeft", "AuroraHitRight", "AuroraFireAWM",
    )
    for clip in required:
        assert any(clip in name for name in animations), f"Missing rig clip: {clip}"
    kit = [x for x in gltf.get("nodes", []) if x.get("name") == "LilaAuroraSignatureKit"]
    hair = [x for x in gltf.get("nodes", []) if x.get("name") == "LilaAuroraOriginalHair"]
    assert len(kit) == 1 and "skin" in kit[0], "Lila armor not skinned"
    assert len(hair) == 1 and "skin" in hair[0], "Lila hair not skinned"
    assert sum(x.get("name", "").startswith("LilaAuroraHair") for x in gltf.get("materials", [])) == 3, "Lila hair PBR materials changed"
    print("AURORA_MODEL_CACHE_RIG_PASS clips=", len(animations), "skins=", len(gltf["skins"]))


def assert_awm(gltf: dict) -> None:
    meshes = gltf.get("meshes", [])
    assert len(meshes) >= 32, "Cached AWM lost its authored geometry"
    print("AURORA_MODEL_CACHE_AWM_PASS meshes=", len(meshes))


def main() -> None:
    assert_operator(gltf_json(OPERATOR))
    assert_awm(gltf_json(AWM))
    print("AURORA_REPRODUCIBLE_MODELS PASS cache_or_build=1")


if __name__ == "__main__":
    main()
