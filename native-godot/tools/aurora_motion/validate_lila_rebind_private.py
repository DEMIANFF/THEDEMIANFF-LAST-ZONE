"""Validate the private reconstructed 2K Lila GLB before any Godot review.

No binary assets are embedded or distributed by this script. The verified
candidate must be supplied locally. It never overwrites the production model.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct

CANDIDATE_SHA = "1c6c4c8bf3fb1d36624e95d5041cf222c55b003f9ffcfd2c6e9bb0b0c409e3a1"
ACTIONS = {"Idle": 61, "ArmedIdle": 46, "Aim": 46, "Crouch": 46,
           "Walk": 28, "Run": 21, "CrouchWalk": 34, "Jump": 27,
           "Land": 12, "Reload": 67, "Heal": 91}
DIGITS = {side + "Hand" + digit + str(i)
          for side in ("Left", "Right")
          for digit in ("Thumb", "Index", "Middle", "Ring", "Pinky")
          for i in range(1, 4)}
CONTROL_JOINTS = {"Root", "HeadTop_End", "LeftToe_End", "RightToe_End"}


def require(ok, message):
    if not ok:
        raise ValueError(message)


def parse_glb(raw):
    require(len(raw) >= 28, "Truncated GLB")
    magic, version, length, jlen, jkind = struct.unpack_from("<5I", raw)
    require((magic, version, length, jkind) ==
            (0x46546c67, 2, len(raw), 0x4e4f534a), "Invalid GLB header")
    require(20 + jlen + 8 <= len(raw), "Invalid JSON chunk size")
    d = json.loads(raw[20:20+jlen])
    n, kind = struct.unpack_from("<2I", raw, 20+jlen)
    data = raw[28+jlen:]
    require(kind == 0x004e4942 and n == len(data), "Invalid binary chunk")
    require(len(d["buffers"]) == 1 and d["buffers"][0]["byteLength"] <= n,
            "Unexpected binary buffer")
    return d, data


def rows(d, data, index):
    a = d["accessors"][index]
    require("sparse" not in a, "Sparse accessor not supported by review gate")
    view = d["bufferViews"][a["bufferView"]]
    width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
    fmt = "<" + {5121: "B", 5123: "H", 5125: "I", 5126: "f"}[a["componentType"]] * width
    size = struct.calcsize(fmt)
    stride = view.get("byteStride", size)
    base = view.get("byteOffset", 0)
    offset = base + a.get("byteOffset", 0)
    end = offset + max(0, a["count"]-1)*stride + size
    require(stride >= size and a["count"] > 0 and offset >= base and
            end <= base + view["byteLength"] <= len(data), "Accessor outside buffer")
    for i in range(a["count"]):
        yield struct.unpack_from(fmt, data, offset+i*stride)


def validate_skin(names, joint_rows, weight_rows):
    counts = dict.fromkeys(names, 0)
    n = 0
    for joints, weights in zip(joint_rows, weight_rows, strict=True):
        require(len(joints) == len(weights) == 4, "Expected four skin influences")
        require(all(0 <= j < len(names) for j in joints), "Invalid joint index")
        require(all(math.isfinite(w) and w >= 0 for w in weights)
                and abs(sum(weights)-1) < 1e-5, "Non-normalized or invalid skin weights")
        for j, w in zip(joints, weights):
            if w > 1e-5:
                counts[names[j]] += 1
        n += 1
    require(n == 93572, "Unexpected vertex count")
    require(DIGITS.issubset({name for name, n in counts.items() if n > 0}),
            "A digit has no deformation influence")
    require({name for name, n in counts.items() if n == 0} == CONTROL_JOINTS,
            "Unexpected inactive joint")
    return counts


def png_size(d, data, image):
    v = d["bufferViews"][image["bufferView"]]
    start = v.get("byteOffset", 0)
    require(start+v["byteLength"] <= len(data), "Image exceeds binary buffer")
    b = data[start:start+24]
    require(b[:8] == b"\x89PNG\r\n\x1a\n" and b[12:16] == b"IHDR", "Expected PNG")
    return struct.unpack_from(">2I", b, 16)


def validate(path):
    raw = path.read_bytes()
    require(hashlib.sha256(raw).hexdigest() == CANDIDATE_SHA, "Private candidate SHA mismatch")
    d, b = parse_glb(raw)
    require(len(d["skins"]) == 1, "Expected one skin")
    skin = d["skins"][0]
    names = [d["nodes"][i]["name"] for i in skin["joints"]]
    require(len(names) == len(set(names)) == 56, "Unexpected skeleton")
    require(len(d["meshes"]) == 1 and len(d["meshes"][0]["primitives"]) == 1,
            "Unexpected mesh topology")
    p = d["meshes"][0]["primitives"][0]
    a = p["attributes"]
    require(d["accessors"][a["POSITION"]]["count"] == 93572 and
            d["accessors"][p["indices"]]["count"] == 95885*3, "Unexpected source geometry")
    counts = validate_skin(names, rows(d,b,a["JOINTS_0"]), rows(d,b,a["WEIGHTS_0"]))
    require(len(d["images"]) == 2 and all(png_size(d,b,i) == (2048,2048)
            for i in d["images"]), "Expected two 2K texture maps")
    clips = {c["name"]: c for c in d["animations"]}
    require(len(clips) == len(d["animations"]) == 68, "Unexpected clip count")
    frames = 0
    for name, count in ACTIONS.items():
        clip = clips["ReviewRebuild_" + name]
        require(len(clip["channels"]) == 56, "Incomplete review action")
        for c in clip["channels"]:
            target = c["target"]
            s = clip["samplers"][c["sampler"]]
            times = [v[0] for v in rows(d,b,s["input"])]
            values = list(rows(d,b,s["output"]))
            require(len(times) == len(values) == count and abs(times[0]) < 1e-6
                    and all(math.isfinite(t) for t in times)
                    and all(y>x for x,y in zip(times,times[1:])), "Invalid action timeline")
            bone = d["nodes"][target["node"]]["name"]
            if target["path"] == "translation":
                require(bone == "Hips" and all(abs(v[0]) < 1e-6 and abs(v[2]) < 1e-6
                        and math.isfinite(v[1]) for v in values), "Unexpected root motion")
            else:
                require(target["path"] == "rotation" and bone != "Root" and
                        all(len(v) == 4 and all(math.isfinite(x) for x in v)
                        and abs(sum(x*x for x in v)-1) < 1e-5 for v in values),
                        "Invalid review rotation")
        frames += count
    require(frames == 479, "Unexpected frame count")
    return {"sha256": CANDIDATE_SHA, "joints": len(names), "weighted_joints": sum(n>0 for n in counts.values()),
            "weighted_digit_joints": len(DIGITS), "review_actions": len(ACTIONS),
            "review_frames": frames, "texture_size": [2048,2048],
            "production_approved": False}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", type=Path)
    args = parser.parse_args()
    print(json.dumps(validate(args.candidate), indent=2))
