extends SceneTree
## Three-tier real backpack inventory without phantom models or duplicate ammo.
const COMBAT=preload("res://scripts/combat/training_combat.gd")
const WEAPONS=preload("res://scripts/combat/aurora_weapon_catalog.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_check")


func require(ok: bool,description: String) -> void:
    if not ok:
        failed=true
        push_error("AURORA_BACKPACK_LEVELS "+description)


func _check() -> void:
    for slot in [WEAPONS.AR,WEAPONS.AWM,WEAPONS.MP40,
            WEAPONS.SHOTGUN,WEAPONS.MAGNUM]:
        var previous: int=0
        for level in range(4):
            var capacity: int=COMBAT.reserve_capacity_by_level(slot,level)
            require(capacity>previous,
                "non-monotonic ammo capacity slot="+str(slot)+
                " level="+str(level))
            previous=capacity
    require(COMBAT.reserve_capacity_by_level(WEAPONS.AR,0)==180 and
        COMBAT.reserve_capacity_by_level(WEAPONS.AR,1)==360 and
        COMBAT.reserve_capacity_by_level(WEAPONS.AWM,0)==30 and
        COMBAT.reserve_capacity_by_level(WEAPONS.AWM,1)==60,
        "pre-existing backpack and sniper capacities changed")
    require(COMBAT.reserve_capacity_by_level(WEAPONS.KNIFE,3)==0,
        "knife receives imaginary ammunition")
    require(COMBAT.reserve_capacity_by_level(WEAPONS.P90,3)==300 and
        COMBAT.reserve_capacity_by_level(WEAPONS.MP5,3)==300 and
        COMBAT.reserve_capacity_by_level(WEAPONS.SNIPER,3)==90,
        "reserve pooling broken by optional weapons")
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var combat: Node3D=game.get_node("CombatRange")
    var operator: CharacterBody3D=game.get_node("Operator")
    operator.set_physics_process(false)
    combat.set_process(false)
    for enemy: CharacterBody3D in combat._targets:
        enemy.set_physics_process(false)
    combat.sector_battle_active=true  # test only the inventory contract
    require(combat.backpack_level==0,
        "new round did not start with an empty backpack")
    var initial_ammo: Array= combat.reserve.duplicate()
    require(combat.collect_sector_loot("backpack"),
        "legacy level-1 backpack pickup failed")
    require(combat.backpack_level==1 and
        not combat.collect_sector_loot("backpack"),
        "level-1 backpack can be duplicated")
    require(combat.collect_sector_loot("backpack_3"),
        "level-3 pack could not be equipped")
    require(combat.backpack_level==3 and
        not combat.collect_sector_loot("backpack_2"),
        "lower-tier pack replaced or duplicated stronger pack")
    require(combat.inventory_snapshot()["backpack"]==3,
        "HUD/inventory snapshot omitted backpack level")
    require(combat._reserve_limit(WEAPONS.AR)==600 and
        combat._reserve_limit(WEAPONS.AWM)==90,
        "level-3 reserves not used by live combat")
    require(combat.reserve==initial_ammo,
        "collecting backpack spawned ammunition out of thin air")
    combat.backpack_level=0
    operator.set_backpack_visual_level(0)
    require(combat.collect_sector_loot("backpack_2") and
        combat.backpack_level==2,"level-2 direct pickup failed")
    game.queue_free()
    await process_frame
    if not failed:
        print("AURORA_BACKPACK_LEVELS PASS tiers=3 historical_caps=1 "+
            "reduced_pickups_ignored=1 shared_calibers=1 no_free_ammo=1")
    quit(1 if failed else 0)
