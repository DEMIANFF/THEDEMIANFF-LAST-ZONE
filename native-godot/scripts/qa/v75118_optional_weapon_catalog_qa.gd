extends SceneTree
## Regression: optional V2 slots must not corrupt the stable original 5.
const CATALOG=preload("res://scripts/combat/aurora_weapon_catalog.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(valid: bool, description: String) -> void:
    if not valid:
        failed=true
        push_error("AURORA_V2_OPTIONAL "+description)


func _verify() -> void:
    check(CATALOG.AR==0 and CATALOG.AWM==1 and CATALOG.SCAR==2 and
        CATALOG.MP40==3 and CATALOG.KRISS==4,"historical save slots changed")
    check(CATALOG.ENTRIES.size()==13,"optional catalog count mismatch")
    check(CATALOG.HK416==5 and CATALOG.P90==6 and CATALOG.VSS==7 and
        CATALOG.MP5==8 and CATALOG.SHOTGUN==9 and CATALOG.MAGNUM==10 and
        CATALOG.KNIFE==11 and CATALOG.SNIPER==12,
        "optional slots are not append-only")
    var names: Array[String]=[]
    for index in range(CATALOG.ENTRIES.size()):
        var entry: Dictionary=CATALOG.ENTRIES[index]
        var short_name: String=str(entry["short"])
        check(not names.has(short_name),"duplicate weapon short name: "+short_name)
        names.append(short_name)
        check(int(entry["capacity"])>0 and float(entry["reload"])>0.0 and
            float(entry["cadence"])>0.0 and float(entry["damage"])>0.0,
            "invalid ballistics: "+short_name)
    for info in [
        {"slot":CATALOG.HK416,"pickup":"weapon_hk416","pool":CATALOG.AR},
        {"slot":CATALOG.P90,"pickup":"weapon_p90","pool":CATALOG.MP40},
        {"slot":CATALOG.VSS,"pickup":"weapon_vss","pool":CATALOG.AR},
        {"slot":CATALOG.MP5,"pickup":"weapon_mp5","pool":CATALOG.MP40},
        {"slot":CATALOG.SHOTGUN,"pickup":"weapon_shotgun","pool":CATALOG.SHOTGUN},
        {"slot":CATALOG.MAGNUM,"pickup":"weapon_magnum","pool":CATALOG.MAGNUM},
        {"slot":CATALOG.KNIFE,"pickup":"weapon_knife","pool":CATALOG.KNIFE},
        {"slot":CATALOG.SNIPER,"pickup":"weapon_sniper","pool":CATALOG.AWM}
    ]:
        var slot: int=info["slot"]
        var pickup: String=info["pickup"]
        check(CATALOG.pickup_slot(pickup)==slot,"pickup not linked: "+pickup)
        check(CATALOG.reserve_slot(slot)==int(info["pool"]),
            "reserve slot not shared correctly: "+pickup)
        var path: String=str(CATALOG.ENTRIES[slot]["asset"])
        check(path.begins_with("res://assets/weapons/aurora_v2_optional/") or
            path.begins_with("res://assets/weapons/aurora_v3_extended/"),
            "optional path escaped asset staging: "+pickup)
        if ResourceLoader.exists(path):
            check(load(path) is PackedScene,
                "staged optional weapon is not a real imported GLB: "+path)
    check(CATALOG.reserve_slot(CATALOG.SCAR)==CATALOG.AR and
        CATALOG.reserve_slot(CATALOG.KRISS)==CATALOG.MP40,
        "historic ammunition pools changed")
    check(bool(CATALOG.ENTRIES[CATALOG.KNIFE].get("melee",false)) and
        int(CATALOG.ENTRIES[CATALOG.SHOTGUN]["pellets"])==8 and
        float(CATALOG.ENTRIES[CATALOG.SHOTGUN]["range"])<=24.0,
        "knife melee or real short-range shotgun mechanics not configured")
    check(CATALOG.pickup_slot("weapon_invalid")==-1,
        "unknown items become collectible weapons")
    if not failed:
        print("AURORA_V2_OPTIONAL_ARMORY PASS catalog=13 old_slots_unchanged=5 "+
            "pickup_and_reserves=8 optional_import_gate=1 archetypes=5")
    quit(1 if failed else 0)
