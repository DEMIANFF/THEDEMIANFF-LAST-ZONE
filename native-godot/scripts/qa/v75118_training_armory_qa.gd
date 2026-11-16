extends SceneTree
const CATALOG=preload("res://scripts/combat/aurora_weapon_catalog.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool, message: String) -> void:
    if not ok:
        failed=true
        push_error("V75118 "+message)


func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var combat: Node3D=game.get_node("CombatRange")
    var player: CharacterBody3D=game.get_node("Operator")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    player.set_physics_process(false)
    combat.set_process(false)
    for bot: CharacterBody3D in combat._targets:
        bot.set_physics_process(false)
    check(not combat.collect_sector_loot("weapon_scar"),
        "training equipment was granted before opening the armory")
    combat.open_training_armory()
    var armory: Node3D=combat._training_armory
    check(armory!=null and armory.get_child_count()==5,"missing training pickups")
    if armory==null:
        quit(1)
        return
    combat.open_training_armory()
    check(combat._training_armory==armory and armory.get_child_count()==5,
        "opening twice duplicated supplies")
    check(not combat.collect_sector_loot("helmet_3") and
        not combat.collect_sector_loot("ammo_ar",1,true),
        "training enabled unrelated BR or opponent rewards")
    for item in ["weapon_scar","weapon_mp40","weapon_kriss","ammo_smg"]:
        var pickup: Area3D=armory.get_node("Training_"+item)
        player.global_position=pickup.global_position-Vector3.UP*.5
        # Area3D/proximity collection may queue_free the pickup during the
        # frame. Observe the result; never call a freed object a second time.
        for frame in range(24):
            await physics_frame
            await process_frame
        check(not is_instance_valid(pickup) or pickup.collected,
            "automatic physical training pickup blocked: "+item)
    check(combat.weapon_owned.size()==5 and combat.weapon_owned.all(
        func(owned: bool) -> bool: return owned),"missing inventory weapon")
    check(combat.reserve[CATALOG.MP40]==60,"SMG shared reserve duplicated or lost")
    check(combat.encounter_size==9 and not combat.sector_battle_active,
        "armory changed the training encounter into BR")
    player.global_position=Vector3(800,20,800)
    player.rotation=Vector3.ZERO
    player._camera_pivot.rotation=Vector3.ZERO
    player.get_view_camera().position=Vector3(0,0,4.6)
    var target: CharacterBody3D=combat._targets[0]
    target.global_position=player.global_position+Vector3(0,0,-12)
    await physics_frame
    await physics_frame
    for slot in [CATALOG.SCAR,CATALOG.MP40,CATALOG.KRISS]:
        combat._equip_inventory_weapon(slot)
        var visual: Node3D=combat._weapon_visuals.currently_equipped()
        combat._weapon_visuals._process(.016)
        check(visual!=null and visual.is_visible_in_tree(),"equipped mesh hidden")
        var length: float=combat._weapon_visuals.equipped_global_length()
        check(length>.25 and length<2.0,"weapon outside human scale: "+str(length))
        var health: float=target.health
        var rounds: int=combat.ammo[slot]
        combat.cooldown=0.0
        combat._shoot()
        check(combat.ammo[slot]==rounds-1 and target.health<health,
            "training gun did not consume a real round and damage an opponent")
        combat._on_reload()
        combat._process(float(CATALOG.ENTRIES[slot]["reload"])+.01)
        check(combat.ammo[slot]==rounds,"training reload did not replenish the magazine")
    # A new BR must remove the training table and all its extra ownership.
    director.start_sector_battle()
    check(combat._training_armory==null and combat.weapon_owned==[true,false],
        "training inventory leaked into BR")
    check(armory.is_queued_for_deletion(),"training objects retained on BR transition")
    combat.open_training_armory()
    check(combat._training_armory==null,"training supplies created during BR")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75118_TRAINING_ARMORY PASS physical_pickups=1 inventory=1 real_damage=1 reload=1 shared_reserve=1 no_BR_leak=1")
    quit(1 if failed else 0)
