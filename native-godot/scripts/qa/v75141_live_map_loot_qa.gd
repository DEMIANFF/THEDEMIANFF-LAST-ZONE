extends SceneTree
## Real 3D tactical-map loot markers: an AWM exists only while its physical
## Area3D is uncollected; opponent cache icons require local proximity and
## disappear on actual pickup. Never project invisible enemy positions.
const MAP=preload("res://scripts/ui/aurora_tactical_map.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V75141_LIVE_MAP_LOOT "+why)


func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var player: CharacterBody3D=game.get_node("Operator")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var map: Control=game.get_node(
        "TrainingHUD/AuroraTacticalOverlay/AuroraFullTacticalMap")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    check(map.call("_live_awm_pickup")==null and
        director.nearby_opponent_supply_points(Vector2.ZERO).is_empty(),
        "training presented future BR weapon or enemy caches")

    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    var awm: Area3D=map.call("_live_awm_pickup") as Area3D
    check(awm!=null and awm.pickup_type=="weapon_awm" and
        awm.world_spot==MAP.AWM_POSITION,
        "tactical AWM marker is not bound to genuine physical loot")
    check(director.nearby_opponent_supply_points(Vector2.ZERO).is_empty(),
        "no player kill yet but map fabricated enemy reward markers")

    # Use the actual unobstructed field site validated by V75.138's
    # successful physical ammo pickup. (12,-12) is inside a coastal
    # house; a wall/deck blocks the genuine pickup's line-of-sight ray.
    var at:=Vector2(8.0,-22.0)
    var victim: CharacterBody3D=combat._targets[0]
    victim.global_position=Vector3(
        at.x,terrain.height_at(at.x,at.y)+2.0,at.y)
    victim._magazine=7
    victim._field_medkits=0
    check(victim.health==200.0 and
        victim.take_training_damage(999.0,player),
        "real 200HP rival did not produce a physical loot cache")
    var cache: Area3D=director.get_node_or_null("AuroraOpponentLoot1")
    check(cache!=null and cache.from_opponent and
        cache.pickup_type=="ammo_ar" and cache.quantity==7,
        "live map cache is not supported by carried physical inventory")
    var local: Array[Vector2]=director.nearby_opponent_supply_points(
        at,70.0,6)
    check(local.size()==1 and local[0].distance_to(at)<.1,
        "real enemy cache not detected locally")
    check(director.nearby_opponent_supply_points(
        Vector2(210,210),70.0,6).is_empty(),
        "map leaks distant opponent supplies across the whole island")
    check(director.nearby_opponent_supply_points(at,70.0,0).is_empty(),
        "zero-budget map still minted enemy marker geometry")
    player.global_position=Vector3(at.x,
        terrain.height_at(at.x,at.y)+1.5,at.y+7.0)
    var mapped: Array[Vector2]=map.call("_live_local_cache_markers")
    check(mapped.size()==1 and mapped[0].distance_to(at)<.1,
        "map is not reading actual nearby caches from the match director")

    if cache!=null:
        player.global_position=cache.global_position-Vector3.UP*.85
        player.velocity=Vector3.ZERO
        await physics_frame
        await physics_frame
        if is_instance_valid(cache) and not cache.collected:
            cache._collect(player)
        check(is_instance_valid(cache) and cache.collected,
            "actual pickup blocked at known accessible field site")
        check(director.nearby_opponent_supply_points(at).is_empty(),
            "collected ammo still leaves a phantom tactical marker")
        check(combat.opponent_caches_collected==1,
            "map marker removal did not reflect an actual inventory pickup")

    if is_instance_valid(awm):
        player.global_position=awm.global_position-Vector3.UP*.85
        player.velocity=Vector3.ZERO
        await physics_frame
        await physics_frame
        if is_instance_valid(awm) and not awm.collected:
            awm._collect(player)
    check(bool(combat.weapon_owned[1]) and
        map.call("_live_awm_pickup")==null,
        "AWM marker remained after collecting the physical weapon")

    director.match_ended=true
    check(director.nearby_opponent_supply_points(at).is_empty() and
        map.call("_live_awm_pickup")==null,
        "match result leaked stale gameplay loot markers")
    if not failed:
        print("V75141_LIVE_MAP_LOOT PASS original_awm=1 "+
            "real_ammo=7 proximity=70 bounded=6 real_collection=1 "+
            "no_phantom_awm=1 no_enemy_wallhack=1")
    game.queue_free()
    await process_frame
    quit(1 if failed else 0)
