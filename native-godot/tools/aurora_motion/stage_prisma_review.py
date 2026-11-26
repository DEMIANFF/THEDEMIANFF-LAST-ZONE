"""Stage private Prisma-derived Lila clips without replacing the production rig.

The source motion file has no declared license. This tool never publishes its
data, activates gameplay clips or modifies the input GLB. Use a private copy.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct

SOURCE_SHA = "178ff358c80acd44d33880c4d2047108e56ea75fa0053e5e82fa536fa522e393"
LILA_SHA = "62da843e0649b4274f5af4dfc75dfa3fa557d094224922c002498d5c28e15cbd"
BANK_SHA = "4f5f890a8403ff4981b31b7e3d98c9a0cc7da003ff79525443472d1d2fde18f1"
COUNTS = {
    "locomocion_a": 135, "locomocion_b": 165, "locomocion_c": 132,
    "saltos": 123, "descenso_rodada": 261, "carrera_rapida": 99,
    "flexiones_transiciones": 465, "verticales": 225, "gestos_combate": 963,
}
LEG_NAMES = {"LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"}
BODY_NAMES = LEG_NAMES | {"Hips", "Spine", "Spine1", "Spine2", "Neck", "Head",
    "LeftShoulder", "LeftArm", "LeftForeArm", "RightShoulder", "RightArm", "RightForeArm"}
EXPECTED = {"ReviewPrisma_" + name: (count, BODY_NAMES) for name, count in COUNTS.items()}
EXPECTED.update({"ReviewPrisma_Legs_" + name: (COUNTS[name], LEG_NAMES)
                 for name in ("locomocion_a", "locomocion_b", "locomocion_c", "carrera_rapida")})


def parse_glb(raw):
    magic, version, size, jlen, kind = struct.unpack_from("<5I", raw)
    if (magic, version, size, kind) != (0x46546c67, 2, len(raw), 0x4e4f534a):
        raise ValueError("Expected an intact GLB 2.0")
    document = json.loads(raw[20:20+jlen])
    length, kind = struct.unpack_from("<2I", raw, 20+jlen)
    data = raw[28+jlen:]
    if kind != 0x004e4942 or length != len(data) or len(document["buffers"]) != 1:
        raise ValueError("Expected a single embedded binary buffer")
    return document, data


def merge_private_bank(document, original_binary, bank):
    if (bank.get("schema") != "aurora-lila-private-review-v1"
            or bank.get("source_sha256") != SOURCE_SHA
            or bank.get("lila_source_sha256") != LILA_SHA
            or bank.get("review_only") is not True):
        raise ValueError("Unverified motion provenance")
    joints = document["skins"][0]["joints"]
    names = {document["nodes"][i]["name"]: i for i in joints}
    if len(joints) != 56 or len(names) != 56 or not BODY_NAMES.issubset(names):
        raise ValueError("Target must be the original 56-bone Lila hierarchy")
    clips = bank["clips"]
    if len(clips) != len(EXPECTED) or {c["name"] for c in clips} != set(EXPECTED):
        raise ValueError("Incomplete or duplicate review clips")
    current = {c["name"] for c in document["animations"]}
    if current.intersection(EXPECTED):
        raise ValueError("Refusing to overwrite an existing review clip")
    # Validate EVERYTHING before mutating the output document.
    for clip in clips:
        count, required = EXPECTED[clip["name"]]
        times = clip["times"]
        if (len(times) != count or times[0] != 0 or
                not all(math.isfinite(t) for t in times) or
                not all(b > a for a, b in zip(times, times[1:])) or times[-1] > 90):
            raise ValueError("Invalid clip timeline")
        targets = set()
        for track in clip["tracks"]:
            bone, path, values = track["bone"], track["path"], track["values"]
            key = bone, path
            if key in targets or len(values) != count:
                raise ValueError("Duplicate target or mismatched timeline")
            targets.add(key)
            if path == "rotation" and bone in required:
                if any(len(v) != 4 or not all(math.isfinite(x) for x in v)
                       or abs(sum(x*x for x in v)-1) > .0001 for v in values):
                    raise ValueError("Invalid quaternion")
            elif key == ("Hips", "translation"):
                if any(len(v) != 3 or not all(math.isfinite(x) for x in v)
                       or abs(v[0]) > .000001 or abs(v[2]) > .000001 or abs(v[1]) > 1
                       for v in values):
                    raise ValueError("Unsafe pelvis displacement")
            else:
                raise ValueError("Forbidden motion target")
        if targets != {("Hips", "translation")} | {(name, "rotation") for name in required}:
            raise ValueError("Missing review tracks")
    data = bytearray(original_binary)

    def append(rows, kind):
        width = len(rows[0])
        payload = b"".join(struct.pack("<" + "f"*width, *row) for row in rows)
        data.extend(b"\0" * (-len(data) % 4))
        offset = len(data)
        data.extend(payload)
        document["bufferViews"].append({"buffer": 0, "byteOffset": offset,
                                        "byteLength": len(payload)})
        accessor = {"bufferView": len(document["bufferViews"])-1,
                    "componentType": 5126, "count": len(rows), "type": kind}
        if kind == "SCALAR":
            accessor.update(min=[rows[0][0]], max=[rows[-1][0]])
        document["accessors"].append(accessor)
        return len(document["accessors"])-1

    for clip in clips:
        out = {"name": clip["name"], "samplers": [], "channels": []}
        time = append([(t,) for t in clip["times"]], "SCALAR")
        for tr in clip["tracks"]:
            out["channels"].append({"sampler": len(out["samplers"]),
                "target": {"node": names[tr["bone"]], "path": tr["path"]}})
            out["samplers"].append({"input": time,
                "output": append(tr["values"], "VEC4" if tr["path"] == "rotation" else "VEC3"),
                "interpolation": "LINEAR"})
        document["animations"].append(out)
    data.extend(b"\0" * (-len(data) % 4))
    document["buffers"][0]["byteLength"] = len(data)
    document["asset"].setdefault("extras", {})["private_prisma_review"] = {
        "source_sha256": SOURCE_SHA, "bank_sha256": BANK_SHA,
        "review_only": True, "production_approved": False}
    j = json.dumps(document, separators=(",", ":")).encode()
    j += b" " * (-len(j) % 4)
    return (struct.pack("<5I", 0x46546c67, 2, 28+len(j)+len(data), len(j), 0x4e4f534a)
            + j + struct.pack("<2I", len(data), 0x004e4942) + data)


def prepare(bank_path, target, output):
    if target.resolve() == output.resolve() or output.exists():
        raise FileExistsError("Private output must be a new file, never the original")
    raw = bank_path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != BANK_SHA:
        raise ValueError("Private motion bank SHA mismatch")
    document, data = parse_glb(target.read_bytes())
    result = merge_private_bank(document, data, json.loads(raw))
    with output.open("xb") as stream:
        stream.write(result)
    return {"review_clips": len(EXPECTED), "production_approved": False,
            "output_sha256": hashlib.sha256(result).hexdigest()}


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--bank", type=Path, required=True)
    p.add_argument("--target", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()
    print(json.dumps(prepare(a.bank, a.target, a.output), indent=2))
