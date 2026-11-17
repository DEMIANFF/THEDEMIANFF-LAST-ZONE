extends RefCounted
## Stable slots preserve the original AR-7 and AWM inventory contracts.
const AR: int=0
const AWM: int=1
const SCAR: int=2
const MP40: int=3
const KRISS: int=4
# Optional V2 models use new slots; the historical five slots never move.
const HK416: int=5
const P90: int=6
const VSS: int=7

const MP40_RELOAD_MARKS: Array[float]=[.23,.64,.85]
const MP40_RELOAD_CUES: Array[StringName]=[&"mp40_extract",&"mp40_seat",&"mp40_bolt"]

const ENTRIES: Array[Dictionary]=[
    {"short":"AR","label":"AR-7 / ASALTO","capacity":30,"reload":1.55,
        "cadence":.105,"damage":26.0,"critical":1.85,"recoil":.005,"sample":"ar_fire"},
    {"short":"AWM","label":"AWM / FRANCOTIRADOR","capacity":5,"reload":3.10,
        "cadence":.50,"damage":115.0,"critical":1.65,"recoil":.020,"sample":"awm_fire"},
    {"short":"SCAR","label":"SCAR / ASALTO","capacity":30,"reload":1.75,
        "cadence":.126,"damage":28.0,"critical":1.70,"recoil":.006,"sample":"scar_fire",
        "asset":"res://assets/weapons/aurora_v3/aurora_scar.glb","pickup":"weapon_scar"},
    {"short":"MP40","label":"MP40 / SUBFUSIL","capacity":15,"reload":1.85,
        "cadence":.095,"damage":18.0,"critical":1.55,"recoil":.004,"sample":"mp40_fire",
        "asset":"res://assets/weapons/aurora_v3/aurora_mp40.glb","pickup":"weapon_mp40"},
    {"short":"KRISS","label":"KRISS VECTOR / SUBFUSIL","capacity":15,"reload":1.6,
        "cadence":.083,"damage":15.0,"critical":1.55,"recoil":.003,"sample":"kriss_fire",
        "asset":"res://assets/weapons/aurora_v3/aurora_kriss.glb","pickup":"weapon_kriss"},
    # Balanced starting points, not final competitive tuning. Visuals are only
    # available after installing the byte-verified, licensed optional GLB pack.
    {"short":"HK416","label":"HK416 / ASALTO","capacity":30,"reload":1.75,
        "cadence":.112,"damage":27.0,"critical":1.75,"recoil":.0055,"sample":"ar_fire",
        "asset":"res://assets/weapons/aurora_v2_optional/aurora_hk416.glb",
        "pickup":"weapon_hk416"},
    {"short":"P90","label":"P90 / SUBFUSIL","capacity":15,"reload":1.80,
        "cadence":.085,"damage":17.0,"critical":1.55,"recoil":.0038,"sample":"kriss_fire",
        "asset":"res://assets/weapons/aurora_v2_optional/aurora_p90.glb",
        "pickup":"weapon_p90"},
    {"short":"VSS","label":"VSS / DMR","capacity":10,"reload":2.15,
        "cadence":.20,"damage":38.0,"critical":1.70,"recoil":.009,"sample":"scar_fire",
        "asset":"res://assets/weapons/aurora_v2_optional/aurora_vss.glb",
        "pickup":"weapon_vss"},
]


static func pickup_slot(kind: String) -> int:
    for slot in range(SCAR,ENTRIES.size()):
        if ENTRIES[slot]["pickup"]==kind:
            return slot
    return -1


static func reserve_slot(slot: int) -> int:
    if slot==KRISS or slot==P90:
        return MP40
    if slot==SCAR or slot==HK416 or slot==VSS:
        return AR
    return slot
