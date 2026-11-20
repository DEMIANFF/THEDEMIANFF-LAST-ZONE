extends Node3D
## Real, optional training pickups. Uses the same GLBs, obstruction test and
## inventory transaction as BR; no grants to a new battle or HUD editor.
const LOOT=preload("res://scripts/match/aurora_loot.gd")
const WEAPONS=preload("res://scripts/combat/aurora_weapon_catalog.gd")
const ITEMS: Array[String]=[
    "weapon_scar","weapon_mp40","weapon_kriss","ammo_ar","ammo_smg"]
# Do not show a pickup for a weapon whose real GLB has not been staged.
const OPTIONAL: Array[String]=[
    "weapon_hk416","weapon_p90","weapon_vss",
    "weapon_mp5","weapon_shotgun","weapon_magnum","weapon_knife","weapon_sniper"
]
var player: CharacterBody3D
var combat: Node3D
var terrain: StaticBody3D
var preferred_weapon_slot: int=-1


func _ready() -> void:
    var available: Array[String]=ITEMS.duplicate()
    for kind in OPTIONAL:
        var slot: int=WEAPONS.pickup_slot(kind)
        if slot>=0 and ResourceLoader.exists(str(WEAPONS.ENTRIES[slot]["asset"])):
            available.append(kind)
    # The weapon selected in the lobby goes to the first physical pickup
    # position. A missing optional model is never fabricated or granted.
    if preferred_weapon_slot>=WEAPONS.SCAR and preferred_weapon_slot<WEAPONS.ENTRIES.size():
        var preferred: String=str(WEAPONS.ENTRIES[preferred_weapon_slot].get("pickup",""))
        if available.has(preferred):
            available.erase(preferred)
            available.push_front(preferred)
    for index in range(available.size()):
        var pickup: Area3D=LOOT.new()
        pickup.name="Training_"+available[index]
        pickup.pickup_type=available[index]
        pickup.player=player
        pickup.combat=combat
        pickup.terrain=terrain
        # Clear ground west of the spawn, outside the beacon and buildings.
        pickup.world_spot=Vector2(-9.0,-6.0-float(index)*3.5)
        add_child(pickup)


func close() -> void:
    # A deferred Area3D callback must not award training supplies to a BR
    # that starts in the same frame.
    for pickup: Area3D in get_children():
        pickup.collected=true
        pickup.set_process(false)
        pickup.set_deferred("monitoring",false)
    hide()
    queue_free()
