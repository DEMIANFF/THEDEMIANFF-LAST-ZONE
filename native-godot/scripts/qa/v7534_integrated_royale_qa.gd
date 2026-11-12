extends SceneTree
## Single-build acceptance for all four integrated workstreams:
## armed locomotion, tactical bot reaction, physical loadout, coastal sector.
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(value: bool, message: String) -> void:
    if not value:
        failed=true
        push_error("V7534_INTEGRATED "+message)

func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var coastal: Node3D=game.get_node("PuertoAuroraCoastalQuarter")
    var player: CharacterBody3D=game.get_node("Operator")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    await physics_frame
    check(coastal.HOUSE_COUNT==8 and coastal.buildings_built==8 and
        coastal.furnished_interiors==8 and coastal.interior_supply_spots.size()==8,
        "eight physical furnished homes and real interior floor anchors required")
    check(coastal.navigation_points.size()>35,
        "pedestrian lane and villas have insufficient tactical navigation points")

    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(combat.sector_battle_active and director.get_loot_remaining()==25,
        "BR does not spawn 16 outdoor + 8 indoor + 1 AWM world pickups")
    check(combat.weapon_owned==[true,false] and combat.weapon_index==0,
        "BR should begin with an AR and find AWM in physical world")
    var weapon: Area3D=director.get_node("AuroraAWMWeaponPickup")
    check(weapon.pickup_type=="weapon_awm" and not weapon.collected,
        "AWM is not a live physical pickup")
    combat._on_weapon()
    check(combat.weapon_index==0,"unowned sniper weapon could be selected")
    # Collect actual world AWM. A small radius is still required by the
    # Area3D; use ground-matched placement, not a fake inventory mutation.
    player.global_position=weapon.global_position-Vector3.UP*1.0
    player.velocity=Vector3.ZERO
    await physics_frame
    await physics_frame
    weapon._collect(player)
    check(weapon.collected and combat.weapon_owned[1],
        "physical AWM did not unlock the sniper weapon slot")
    combat._on_weapon()
    check(combat.weapon_index==1,
        "collected AWM did not equip through the existing weapon button")

    var armor: Area3D=director.get_node("AuroraInteriorLoot7")
    var pack: Area3D=director.get_node("AuroraInteriorLoot8")
    check(armor.pickup_type=="armor_plate" and pack.pickup_type=="backpack",
        "new houses have no real protection/rucksack pickups")
    for item in [armor,pack]:
        player.global_position=item.global_position-Vector3.UP*1.0
        player.velocity=Vector3.ZERO
        await physics_frame
        await physics_frame
        item._collect(player)
        check(item.collected,"physical equipment pickup was not collected "+item.name)
    check(is_equal_approx(player.armor_points,75.0) and combat.backpack_level==1,
        "armor/backpack not actually equipped by the player")
    check(combat._reserve_limit(0)==360 and combat._reserve_limit(1)==60,
        "rucksack does not increase actual ammunition capacity")
    var inventory: Dictionary=combat.inventory_snapshot()
    check(int(inventory["armor"])==75 and int(inventory["backpack"])==1 and
        bool(inventory["awm_owned"]) and int(inventory["active_weapon"])==1,
        "inventory snapshot differs from equipped game objects")
    var panel: PanelContainer=hud.get_node(
        "AuroraTacticalOverlay/RealMatchInventory")
    hud._toggle_inventory()
    check(panel.visible and hud._inventory_label.text.contains("CHALECO") and
        hud._inventory_label.text.contains("AWM"),
        "touch bag does not render real combat equipment values")
    hud._toggle_inventory()
    check(not panel.visible,"inventory panel cannot close")

    player._training_immunity=0.0
    var life: float=player.training_health
    player.receive_training_hit(20.0)
    check(player.armor_points<75.0 and player.training_health>life-20.0,
        "armor does not absorb actual enemy combat damage")
    var remaining_armor: float=player.armor_points
    var after_combat: float=player.training_health
    player.receive_training_hit(10.0,true)
    check(is_equal_approx(player.armor_points,remaining_armor) and
        is_equal_approx(player.training_health,after_combat-10.0),
        "radiation must bypass armor but damage player health")
    var opponent: CharacterBody3D=combat._targets[0]
    opponent.health=60.0
    opponent._alert_time=0.0
    opponent._cover_clock=3.0
    opponent.take_training_damage(5.0,player)
    check(opponent._suppression_seconds>0.0 and opponent._cover_clock==0.0 and
        opponent._last_attacker==player,
        "injured AI did not prioritize a fresh reachable cover plan")

    # Authored gait stays in AnimationTree while upper-body actions blend.
    check(player._animation_controller!=null and
        player._animation_controller.states.has_node("AuroraArmedRun") and
        player._animation_controller.states.has_node("AuroraCrouchWalk"),
        "Lila's run/crouch rig clips not bound to live animation controller")
    player._ground_locomotion="Idle"
    check(player._select_locomotion(6.6)=="Run" and
        player._select_locomotion(5.5)=="Run" and
        player._select_locomotion(4.0)=="Walk",
        "actual gait transitions lost hysteresis during armed movement")

    # Round restart must clear protection, backpack, AWM ownership and loot.
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    check(director.get_loot_remaining()==25 and combat.backpack_level==0 and
        is_zero_approx(player.armor_points) and not combat.weapon_owned[1],
        "equipment or world loot leaked across a BR restart")
    if not failed:
        print("V7534_INTEGRATED PASS houses=8 loot=25 awm_physical=1 "+
            "armor=75 backpack=1 UI=live suppression=1 gait=1 restart=clean")
    quit(1 if failed else 0)
