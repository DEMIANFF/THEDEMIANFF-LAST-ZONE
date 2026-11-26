"""Private Rev2 staging integrity check. Never writes to the repository."""
import argparse, hashlib, json, struct
from pathlib import Path
SHA="ab0df204ebe5cdbd2c9472af22eb672eac6cc9cec3818e6859baf1d884c3aa12"
EXPECTED=set(("AuroraIdle AuroraArmedIdle AuroraAim AuroraAimAWM AuroraCrouch "
"AuroraArmedWalk AuroraArmedRun AuroraCrouchWalk AuroraArmedStrafeLeft "
"AuroraArmedStrafeRight AuroraArmedBackpedal AuroraJump AuroraLand AuroraFreefall "
"AuroraParachute AuroraFire AuroraFireAWM AuroraReloadAR AuroraReloadAWM "
"AuroraReloadMP40 AuroraHeal AuroraEquip AuroraHit AuroraHitFront AuroraHitBack "
"AuroraHitLeft AuroraHitRight").split())

def require(ok, message):
    if not ok:
        raise ValueError(message)

def inspect(raw):
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
    return {"runtime_clips":len(names),"joints":56,"production_approved":False}

def validate(path):
    raw=path.read_bytes()
    require(hashlib.sha256(raw).hexdigest()==SHA,"Private candidate SHA mismatch")
    return inspect(raw)

if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate",type=Path)
    args=parser.parse_args()
    print(json.dumps(validate(args.candidate),indent=2))
