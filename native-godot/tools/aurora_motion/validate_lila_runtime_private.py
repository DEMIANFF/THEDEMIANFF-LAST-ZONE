"""Private Rev2 staging integrity check. Never writes to the repository."""
import argparse, hashlib, json, struct
from pathlib import Path
SHA="ab0df204ebe5cdbd2c9472af22eb672eac6cc9cec3818e6859baf1d884c3aa12"
CONTACT_SHA="b3fd330483756a16d2a5022776428e54db39f916404ec70438b64de37932b896"
CACHE_SHA="2a4c00e4ec9afcfcc7d529d73dadb85e57b94f80e2b59a6e25c7f599b5289c7d"
HAND_SHA="c9b755349a4dc2692f45f3bec1918001d72a05f01b3bcad4aff406c743afb74b"
SLEEVE_SHA="a98b6cca5b51fff38ff1570704dedbe58b4be90edbc84f0685b9bd282d74e6b1"
HAIR_SHA="7e01f72eced0556b29c6232f999e1a6351fcc4e39563e6a32f5cf2ab13f274a8"
RESIDUAL_SHA="498d7dd7e4f5346e81fd20ddc7c9ff442f14dddaa0a42a41f941dc9a313880ed"
CANDIDATES={SHA: "Rev2", CONTACT_SHA: "Rev3", CACHE_SHA: "Rev4", HAND_SHA: "Rev5", SLEEVE_SHA: "Rev6", HAIR_SHA: "Rev7", RESIDUAL_SHA: "Rev8"}
HAND_DIGITS={side+"Hand"+digit+str(segment)
             for side in ("Left","Right")
             for digit in ("Thumb","Index","Middle","Ring","Pinky")
             for segment in (1,2,3)}
EXPECTED=set(("AuroraIdle AuroraArmedIdle AuroraAim AuroraAimAWM AuroraCrouch "
"AuroraArmedWalk AuroraArmedRun AuroraCrouchWalk AuroraArmedStrafeLeft "
"AuroraArmedStrafeRight AuroraArmedBackpedal AuroraJump AuroraLand AuroraFreefall "
"AuroraParachute AuroraFire AuroraFireAWM AuroraReloadAR AuroraReloadAWM "
"AuroraReloadMP40 AuroraHeal AuroraEquip AuroraHit AuroraHitFront AuroraHitBack "
"AuroraHitLeft AuroraHitRight").split())

def require(ok, message):
    if not ok:
        raise ValueError(message)

def digit_counts(names, joints, weights):
    """Count actual per-vertex influences, never just existing bone names."""
    import math
    counts=dict.fromkeys(names,0)
    for ji, wi in zip(joints,weights,strict=True):
        require(len(ji)==len(wi)==4,"Expected four influences")
        require(all(0<=j<len(names) for j in ji),"Joint index out of bounds")
        require(all(math.isfinite(w) and w>=0 for w in wi) and abs(sum(wi)-1)<1e-5,
                "Invalid skin weights")
        for k in {j for j,w in zip(ji,wi) if w>1e-5}:
            counts[names[k]]+=1
    require(HAND_DIGITS.issubset(counts),"Missing digit bone")
    require(all(counts[k]>=30 for k in HAND_DIGITS),"Insufficient direct digit support")
    return {k:counts[k] for k in sorted(HAND_DIGITS)}

def inspect(raw, require_compact_joints=False, require_hand_refit=False):
    require(len(raw)>=28,"Truncated GLB")
    magic,version,length,n,kind=struct.unpack_from("<5I",raw)
    require((magic,version,length,kind)==(0x46546c67,2,len(raw),0x4e4f534a),
            "Invalid GLB header")
    require(20+n+8<=len(raw),"Invalid JSON chunk")
    d=json.loads(raw[20:20+n])
    size,kind=struct.unpack_from("<2I",raw,20+n)
    require(kind==0x004e4942 and size==len(raw)-28-n,"Invalid BIN chunk")
    names=[a["name"] for a in d["animations"]]
    require(len(names)==len(EXPECTED) and set(names)==EXPECTED,"Missing/duplicate runtime clip")
    require(len(d["skins"])==1 and len(d["skins"][0]["joints"])==56,"Incorrect skeleton")
    p=d["meshes"][0]["primitives"][0]
    require("TEXCOORD_1" in p["attributes"],"Missing outfit mask")
    require(d["accessors"][p["attributes"]["POSITION"]]["count"]==93572,
            "Unexpected geometry")
    require(d["accessors"][p["indices"]]["count"]==95885*3,"Unexpected topology")
    if require_compact_joints:
        joint=d["accessors"][p["attributes"]["JOINTS_0"]]
        require(joint["componentType"]==5121 and joint["type"]=="VEC4"
                and joint["count"]==93572 and not joint.get("normalized",False),
                "Rev4 requires exact unsigned-byte joint indices")
        view=d["bufferViews"][joint["bufferView"]]
        require("sparse" not in joint and view.get("byteStride",4)==4,
                "Unexpected joint layout")
        offset=view.get("byteOffset",0)+joint.get("byteOffset",0)
        start=28+n
        require(offset>=view.get("byteOffset",0) and
                offset+4*joint["count"]<=view.get("byteOffset",0)+view["byteLength"]<=size,
                "Joint index buffer exceeds bounds")
        require(max(raw[start+offset:start+offset+4*joint["count"]])<56,
                "Rev4 joint index out of bounds")
    result={"runtime_clips":len(names),"joints":56,"production_approved":False}
    if require_hand_refit:
        require(require_compact_joints,"Hand refit requires checked compact joints")
        skin=d["skins"][0]
        joint_names=[d["nodes"][i]["name"] for i in skin["joints"]]
        require(len(set(joint_names))==56,"Duplicate skin joint name")
        weight=d["accessors"][p["attributes"]["WEIGHTS_0"]]
        require(weight["componentType"]==5126 and weight["type"]=="VEC4"
                and weight["count"]==93572 and "sparse" not in weight,
                "Expected original float weights")
        wview=d["bufferViews"][weight["bufferView"]]
        wbase=wview.get("byteOffset",0)
        woff=wbase+weight.get("byteOffset",0)
        stride=wview.get("byteStride",16)
        require(stride>=16 and woff>=wbase and
                woff+stride*(weight["count"]-1)+16<=wbase+wview["byteLength"]<=size,
                "Weight buffer exceeds bounds")
        js=struct.iter_unpack("<4B",raw[start+offset:start+offset+4*joint["count"]])
        ws=(struct.unpack_from("<4f",raw,start+woff+i*stride)
            for i in range(weight["count"]))
        counts=digit_counts(joint_names,js,ws)
        result["min_direct_digit_vertices"]=min(counts.values())
        result["digit_counts"]=counts
    return result

def validate(path):
    raw=path.read_bytes()
    digest=hashlib.sha256(raw).hexdigest()
    require(digest in CANDIDATES,"Private candidate SHA mismatch")
    return {**inspect(raw, digest in (CACHE_SHA,HAND_SHA,SLEEVE_SHA,HAIR_SHA,RESIDUAL_SHA), digest in (HAND_SHA,SLEEVE_SHA,HAIR_SHA,RESIDUAL_SHA)), "revision": CANDIDATES[digest], "sha256": digest}

if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate",type=Path)
    args=parser.parse_args()
    print(json.dumps(validate(args.candidate),indent=2))
