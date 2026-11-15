extends RefCounted
## User-supplied 13-weapon geometry: staged optional import, never a fake
## gameplay weapon. Combat inventory is still strictly AR/AWM until damage,
## pickups, ammunition, animations and HUD are implemented and validated.
## The source OBJ/FBX/Blend files contain no redistribution licence.
const ROOT: String="res://assets/weapons/user_pack/"
const AR_MODEL: String=ROOT+"aurora_w04.glb"
const AWM_MODEL: String=ROOT+"aurora_w11.glb"
# UE5 FPS packs are reference rigs only; Lila requires explicit retargeting.
const PISTOL_ANIM_MODEL: String=ROOT+"fps_pistol_animations_mobile.glb"
const AK_ANIM_MODEL: String=ROOT+"fps_ak47_animations_mobile.glb"
const SAPS_ANIM_MODEL: String=ROOT+"fps_saps12_animations_mobile.glb"
const SIG225_STATIC_MODEL: String=ROOT+"fps_sig225_reference_mobile.glb"
const C17_TRANSPORT_MODEL: String="res://assets/vehicles/user_pack/aurora_c17_mobile.glb"

static func model_path(one_based_index: int) -> String:
    if one_based_index<1 or one_based_index>13:
        return ""
    return ROOT+("aurora_w%02d.glb"%one_based_index)


static func all_paths() -> Array[String]:
    var files: Array[String]=[]
    for index in range(1,14):
        files.append(model_path(index))
    return files


static func supplemental_paths() -> Array[String]:
    return [PISTOL_ANIM_MODEL,AK_ANIM_MODEL,SAPS_ANIM_MODEL,
        SIG225_STATIC_MODEL,C17_TRANSPORT_MODEL]


static func is_user_pack(path: String) -> bool:
    return path.begins_with(ROOT) and path.ends_with(".glb")


static func preferred_path(combat_slot: int,legacy_path: String) -> String:
    # Original assets remain the fallback. Shipping no uploaded models must
    # not break the production mobile BR nor any existing automated QA.
    var candidate: String=AR_MODEL if combat_slot==0 else (
        AWM_MODEL if combat_slot==1 else "")
    if not candidate.is_empty() and ResourceLoader.exists(candidate):
        return candidate
    return legacy_path


static func muzzle_marker(visual: Node3D) -> Node3D:
    if visual==null:
        return null
    return visual.find_child("AuroraMuzzle",true,false) as Node3D
