extends RefCounted
## Stable slots preserve the original AR-7 and AWM inventory contracts.
const AR: int=0
const AWM: int=1
const SCAR: int=2
const MP40: int=3

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
]


static func pickup_slot(kind: String) -> int:
    for slot in range(SCAR,ENTRIES.size()):
        if ENTRIES[slot]["pickup"]==kind:
            return slot
    return -1


static func reserve_slot(slot: int) -> int:
    return AR if slot==SCAR else slot
