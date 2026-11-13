extends SceneTree
## V75.64 — no fictional post-kill rewards: the actual magazine and
## remaining field medkit are converted into real finite Area3D pickups.
## Uses Main.tscn, live physics opponents, real HUD/inventory and zone.
const MATCH=preload("res://scripts/match/sector_director.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool, reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7564_REAL_OPPONENT_LOOT "+reason)


func _collect_from_player(pickup: Area3D,player: CharacterBody3D) -> void:
    if not is_instance_valid(pickup) or pickup.collected:
        return
    player.global_position=pickup.global_position-Vector3.UP
    player.velocity=Vector3.ZERO
    await physics_frame
    await physics_frame
    if is_instance_valid(pickup) and not pickup.collected:
        pickup._collect(player)


func _verify() -> void:
    check(str(ProjectSettings.get_setting(
        "rendering/renderer/rendering_method.mobile"))=="mobile",
        "Vulkan Mobile was replaced by an unsupported Android renderer")
    check(MATCH.opponent_inventory_reward(0,0,true,1).is_empty() and
        MATCH.opponent_inventory_reward(-12,-1,false,4).is_empty(),
        "empty real enemy inventory generated imaginary drops")
    check(MATCH.opponent_inventory_reward(7,1,true,1)==
        {"kind":"ammo_ar","quantity":7} and
        MATCH.opponent_inventory_reward(99,1,false,4)==
        {"kind":"ammo_ar","quantity":18} and
        MATCH.opponent_inventory_reward(0,1,false,2)==
        {"kind":"medkit","quantity":1} and
        MATCH.opponent_inventory_reward(14,1,true,3)==
        {"kind":"medkit","quantity":1} and
        MATCH.opponent_inventory_reward(14,0,true,3)==
        {"kind":"ammo_ar","quantity":14},
        "rival drop quantity ignores physical ammo/medkit inventory")

    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get_node("Operator")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(director.get_loot_remaining()==25 and
        combat.opponent_caches_collected==0 and
        director._opponent_drops_spawned==0,
        "match contains unexpected invisible pre-spawned enemy supplies")

    var victim: CharacterBody3D=combat._targets[0]
    victim._magazine=7
    victim._field_medkits=1
    var before: int=combat.reserve[0]
    check(victim.take_training_damage(999.0,player),
        "player cannot eliminate a real physical opponent")
    var first: Area3D=director.get_node_or_null("AuroraOpponentLoot1") as Area3D
    check(first!=null and
        first.pickup_type=="ammo_ar" and first.quantity==7 and
        first.from_opponent and
        first.get_node_or_null("LootPickupRange")!=null,
        "enemy's remaining seven rounds didn't become physical supply")
    if first!=null:
        var sign: Label3D=first.get_node(
            "SupplyCacheVisual/SupplyLabel") as Label3D
        check(sign.text.contains("RIVAL /") and sign.text.contains("x7"),
            "rival's supply did not show grounded ammo quantity in world")
        check(first.global_position.y>=terrain.height_at(
            first.global_position.x,first.global_position.z)+.49,
            "death cache was embedded below walkable terrain")
        await _collect_from_player(first,player)
    check(combat.reserve[0]==before+7 and
        combat.opponent_caches_collected==1 and
        combat.loot_collected==1 and
        director._opponent_drops_spawned==1,
        "physical collection failed to grant exactly remaining ammo")
    director._on_opponent_eliminated(victim,player)
    check(director._opponent_drops_spawned==1,
        "duplicate kill notification cloned an opponent's real inventory")

    # A bot depleted of AR rounds drops its unused field medkit, even
    # when another physical bot scored the kill (no false player credit).
    var victim2: CharacterBody3D=combat._targets[1]
    var killer2: CharacterBody3D=combat._targets[2]
    victim2._magazine=0
    victim2._field_medkits=1
    check(victim2.take_training_damage(999.0,killer2),
        "AI-on-AI physical elimination regression")
    var second: Area3D=director.get_node_or_null("AuroraOpponentLoot2") as Area3D
    check(second!=null and second.pickup_type=="medkit" and
        second.quantity==1 and combat.eliminations==1,
        "rival did not drop unused carried medkit or credited wrong killer")
    var kit_before: int=combat.medkits_remaining
    if second!=null:
        await _collect_from_player(second,player)
    check(combat.medkits_remaining==kit_before+1 and
        combat.opponent_caches_collected==2,
        "collected real bot medkit did not replenish correct limited supply")

    # A completely depleted opponent leaves nothing. Do not generate
    # nonexistent armor or a magic medkit from the death counter.
    var empty: CharacterBody3D=combat._targets[3]
    empty._magazine=0
    empty._field_medkits=0
    check(empty.take_training_damage(999.0,player),
        "physical elimination of depleted opponent failed")
    check(director._opponent_drops_spawned==2 and
        director.get_node_or_null("AuroraOpponentLoot3")==null,
        "empty dead bot generated infinite supply loot")
    director._on_opponent_eliminated(empty,player)
    check(director._opponent_drops_spawned==2,
        "empty body generated late duplicate cache")

    # On every third spawned PLAYER cache, a real unused medkit is
    # prioritized rather than arbitrarily inventing medicine.
    var victim3: CharacterBody3D=combat._targets[4]
    victim3._magazine=11
    victim3._field_medkits=1
    check(victim3.take_training_damage(999.0,player),
        "third physical opponent elimination failed")
    var third: Area3D=director.get_node_or_null("AuroraOpponentLoot3") as Area3D
    check(third!=null and third.pickup_type=="medkit" and
        third.quantity==1 and director._opponent_drops_spawned==3,
        "unused real medkit was not prioritized for third death cache")

    # Inventory limits apply even for physical rival rewards. Full packs
    # must not be consumed when player cannot carry another item.
    combat.medkits_remaining=5
    if third!=null:
        player.global_position=third.global_position-Vector3.UP
        player.velocity=Vector3.ZERO
        await physics_frame
        await physics_frame
        if is_instance_valid(third) and not third.collected:
            third._collect(player)
        check(is_instance_valid(third) and not third.collected and
            combat.opponent_caches_collected==2,
            "full medkit inventory wrongly consumed a death cache")
        combat.medkits_remaining=4
        if is_instance_valid(third):
            third._collect(player)
    check(combat.medkits_remaining==5 and
        combat.opponent_caches_collected==3 and
        combat.inventory_snapshot().get("opponent_caches",-1)==3,
        "capacity-aware pickup didn't consume exactly one physical medkit")

    var victim4: CharacterBody3D=combat._targets[5]
    victim4._magazine=12
    victim4._field_medkits=0
    combat.reserve[0]=combat._reserve_limit(0)-2
    check(victim4.take_training_damage(999.0,player),
        "later real opponent death failed")
    var fourth: Area3D=director.get_node_or_null("AuroraOpponentLoot4") as Area3D
    check(fourth!=null and fourth.pickup_type=="ammo_ar" and
        fourth.quantity==12,
        "unused field ammo became a fixed imaginary reward instead of 12 rounds")
    if fourth!=null:
        await _collect_from_player(fourth,player)
    check(combat.reserve[0]==combat._reserve_limit(0) and
        combat.opponent_caches_collected==4 and
        combat.loot_collected==4,
        "ammo overflow exceeded real backpack capacity or double-counted pickup")
    check(not combat.collect_sector_loot("ammo_ar",0,true) and
        not combat.collect_sector_loot("ammo_ar",999,true) and
        combat.opponent_caches_collected==4,
        "invalid/overflow death cache minted extra ammunition or match statistics")

    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(director._opponent_drops_spawned==0 and
        director.get_loot_remaining()==25 and
        combat.opponent_caches_collected==0 and
        combat.loot_collected==0 and
        combat.medkits_remaining==2 and combat.reserve[0]==90,
        "second BR match leaked dead opponents' real supplies or stats")

    if not failed:
        print("V7564_REAL_OPPONENT_LOOT PASS physical_kills=1 "+
            "real_magazine_ammo=1 owned_medkits_only=1 enemy_kill=1 "+
            "empty_body_no_drops=1 duplicate_prevention=1 "+
            "world_quantity_labels=1 capacity_checks=1 "+
            "inventory_stats=1 round_reset=clean vulkan=1")
    quit(1 if failed else 0)
