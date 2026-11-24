extends SceneTree
## A nearby actual kill can free one 95m-remote abandoned crate without
## raising the 12-collider Vulkan budget or inventing any rounds/medkits.
const MATCH=preload("res://scripts/match/sector_director.gd")
const COMBAT=preload("res://scripts/combat/training_combat.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V75179_DEATH_CACHE_PRIORITY "+why)

func _real_death(victim: CharacterBody3D,player: CharacterBody3D,
        terrain: StaticBody3D,site: Vector2) -> bool:
    victim.global_position=Vector3(site.x,
        terrain.height_at(site.x,site.y)+1.85,site.y)
    victim.velocity=Vector3.ZERO
    victim._magazine=7
    victim._field_medkits=0
    return victim.take_training_damage(999.0,player)

func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var player: CharacterBody3D=game.get_node("Operator")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    combat.set_encounter_size(COMBAT.CLASSIC_BR_PARTICIPANTS)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    var near:=Vector2(8,-22)
    player.global_position=Vector3(near.x,
        terrain.height_at(near.x,near.y)+1.2,near.y)
    check(combat._targets.size()==49 and
        MATCH.MAX_OPPONENT_DROPS==12,
        "actual 50-participant roster/collider budget unavailable")
    for i in range(12):
        var remote:=Vector2(130.0+float(i%4)*2.0,
            -23.0+float(i/4)*3.0)
        check(_real_death(combat._targets[i],player,terrain,remote),
            "remote enemy failed actual health/weapon elimination")
    check(director._active_opponent_drop_count()==12 and
        director._remote_death_caches_retired==0,
        "first twelve real physical remote crates not preserved")
    var old: Area3D=director.get_node_or_null(
        "AuroraOpponentLoot1") as Area3D
    check(old!=null and old.quantity==7 and old.from_opponent,
        "remote actor's remaining ammo not conserved in physical crate")
    # New remote death cannot evict another remote cache when nobody is
    # nearby to retrieve the fresh reward.
    check(_real_death(combat._targets[12],player,terrain,
        Vector2(143,-36)),"13th distant real elimination failed")
    check(director._active_opponent_drop_count()==12 and
        director._opponent_drops_spawned==12 and
        director._remote_death_caches_retired==0,
        "remote kill evicted real cache without close-quarters priority")
    # Next real fight is near Lila; remote abandoned drops yield one
    # collider slot. The NEW body contributes ONLY its actual 7 rounds.
    check(_real_death(combat._targets[13],player,terrain,
        near+Vector2(3,2)),"14th nearby enemy did not genuinely die")
    var fresh: Area3D=director.get_node_or_null(
        "AuroraOpponentLoot13") as Area3D
    check(fresh!=null and fresh.from_opponent and fresh.quantity==7
        and fresh.pickup_type=="ammo_ar",
        "nearby enemy ammo crate missing or has fictional supplies")
    check(director._active_opponent_drop_count()==12 and
        director._remote_death_caches_retired==1 and
        old.is_queued_for_deletion(),
        "real near kill failed to recycle just one abandoned distant crate")
    # A second local kill must retain the previous near crate, recycling
    # a different far-away crate rather than erasing loot under Lila.
    check(_real_death(combat._targets[14],player,terrain,
        near+Vector2(-3,3)),"15th nearby physical elimination failed")
    var fresh_second: Area3D=director.get_node_or_null(
        "AuroraOpponentLoot14") as Area3D
    check(fresh_second!=null and
        director._active_opponent_drop_count()==12 and
        director._remote_death_caches_retired==2 and
        is_instance_valid(fresh) and not fresh.is_queued_for_deletion(),
        "local crate was evicted instead of safely recycling distant loot")
    director.start_sector_battle()
    director.set_process(false)
    check(director._remote_death_caches_retired==0 and
        director._active_opponent_drop_count()==0,
        "the next round inherited stale item slots or recycling ledger")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75179_DEATH_CACHE_PRIORITY PASS 49_real_AI=1 "+
            "nearby_kills_keep_real_loot=1 far_recycled=2 "+
            "near_crates_protected=1 max_live=12 "+
            "real_ammo=7 no_fabricated_rewards=1 reset=1")
    quit(1 if failed else 0)
