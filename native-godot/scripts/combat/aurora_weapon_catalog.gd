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
# Aurora V3 original-source expansion. Append only; never move save slots 0–7.
const MP5: int=8
const SHOTGUN: int=9
const MAGNUM: int=10
const KNIFE: int=11
const SNIPER: int=12

const MP40_RELOAD_MARKS: Array[float]=[.23,.64,.85]
const MP40_RELOAD_CUES: Array[StringName]=[&"mp40_extract",&"mp40_seat",&"mp40_bolt"]
# Synchronize to the existing procedural hand gesture, not a claimed
# detachable magazine. Release, upper receiver contact, return.
const P90_RELOAD_MARKS: Array[float]=[.12,.32,.82]
const P90_RELOAD_CUES: Array[StringName]=[&"p90_release",&"p90_contact",&"p90_return"]

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
    {"short":"P90","label":"P90 / SUBFUSIL","capacity":50,"reload":1.80,
        "cadence":.085,"damage":17.0,"critical":1.55,"recoil":.0038,"sample":"p90_fire",
        "asset":"res://assets/weapons/aurora_v2_optional/aurora_p90.glb",
        "pickup":"weapon_p90"},
    {"short":"VSS","label":"VSS / DMR","capacity":10,"reload":2.15,
        "cadence":.20,"damage":38.0,"critical":1.70,"recoil":.009,"sample":"scar_fire",
        "asset":"res://assets/weapons/aurora_v2_optional/aurora_vss.glb",
        "pickup":"weapon_vss"},
    # These resources are NOT bundled publicly. Gameplay spawns them only
    # when the matching privately staged original-derived GLB is imported.
    {"short":"MP5","label":"MP5 / SUBFUSIL","capacity":30,"reload":1.85,
        "cadence":.095,"damage":18.0,"critical":1.60,"recoil":.004,"sample":"mp40_fire",
        "asset":"res://assets/weapons/aurora_v3_extended/aurora_mp5_source.glb",
        "pickup":"weapon_mp5"},
    {"short":"ESCOPETA","label":"ESCOPETA / PERDIGONES","capacity":8,"reload":2.80,
        "cadence":.73,"damage":12.0,"critical":1.35,"recoil":.024,"sample":"shotgun_fire",
        "pellets":8,"range":22.0,"spread":.055,
        "asset":"res://assets/weapons/aurora_v3_extended/aurora_shotgun_source.glb",
        "pickup":"weapon_shotgun"},
    {"short":"MAGNUM","label":"MAGNUM / PISTOLA","capacity":6,"reload":2.00,
        "cadence":.42,"damage":52.0,"critical":1.72,"recoil":.018,"sample":"pistol_fire",
        "asset":"res://assets/weapons/aurora_v3_extended/aurora_magnum_source.glb",
        "pickup":"weapon_magnum"},
    {"short":"CUCHILLO","label":"CUCHILLO / MELEE","capacity":1,"reload":.5,
        "cadence":.62,"damage":70.0,"critical":1.0,"recoil":0.0,"sample":"knife_swing",
        "melee":true,"range":2.3,
        "asset":"res://assets/weapons/aurora_v3_extended/aurora_knife_source.glb",
        "pickup":"weapon_knife"},
    {"short":"SNIPER","label":"SNIPER / PRECISION","capacity":5,"reload":2.80,
        "cadence":.85,"damage":94.0,"critical":1.7,"recoil":.018,"sample":"awm_fire",
        "asset":"res://assets/weapons/aurora_v3_extended/aurora_sniper_source.glb",
        "pickup":"weapon_sniper"},
]


static func pickup_slot(kind: String) -> int:
    for slot in range(SCAR,ENTRIES.size()):
        if ENTRIES[slot]["pickup"]==kind:
            return slot
    return -1


static func reserve_slot(slot: int) -> int:
    if slot==KRISS or slot==P90 or slot==MP5:
        return MP40
    if slot==SCAR or slot==HK416 or slot==VSS:
        return AR
    if slot==SNIPER:
        return AWM
    return slot
