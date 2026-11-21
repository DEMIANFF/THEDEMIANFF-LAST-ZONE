extends SceneTree
## V75.138: a 50-combatant round may drop up to twelve enemy caches
## simultaneously, but collecting one must allow a future real kill to
## drop actual supplies. Never mint items or exceed the mobile cache cap.
const MATCH=preload("res://scripts/match/sector_director.gd")
const COMBAT=preload("res://scripts/combat/training_combat.gd")
var failed: bool=false


func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V75138_OPPONENT_LOOT_BUDGET "+why)


func _kill(victim: CharacterBody3D,player: CharacterBody3D,
        terrain: StaticBody3D,index: int) -> bool:
    var where:=Vector2(8.0+float(index%4)*5.0,
        -22.0+float(index/4)*5.0)
    var y: float=terrain.height_at(where.x,where.y)
    victim.global_position=Vector3(where.x,y+2.0,where.y)
    victim.velocity=Vector3.ZERO
    victim._magazine=7
    victim._field_medkits=0
    return victim.take_training_damage(999.0,player)


func _initialize() -> void:
    call_deferred("_verify")


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
    # The scene defaults to the internal nine-person training fixture.
    # Exercise the actual single public 50-participant BR configuration.
    combat.set_encounter_size(COMBAT.CLASSIC_BR_PARTICIPANTS)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(combat.encounter_size==50 and combat._targets.size()==49 and
        MATCH.MAX_OPPONENT_DROPS==12,
        "actual 50-participant physical roster or cache budget missing")
    if combat._targets.size()!=49:
        quit(1)
        return

    # The first dozen true player eliminations each leave one finite
    # carried-ammo cache. There is no virtual kill/loot counter simulation.
    for i in range(12):
        var opponent: CharacterBody3D=combat._targets[i]
        check(_kill(opponent,player,terrain,i),
            "physical opponent elimination failed at "+str(i))
        check(director._active_opponent_drop_count()==i+1,
            "real cache count did not increase exactly once")
    check(director._opponent_drops_spawned==12 and
        director._active_opponent_drop_count()==12 and
        director.get_node_or_null("AuroraOpponentLoot12")!=null,
        "twelve real uncollected cache budget not enforced")

    # While all twelve caches remain, a thirteenth body must not allocate
    # more active Area3D, avoiding GPU/physics growth during intense fights.
    check(_kill(combat._targets[12],player,terrain,12),
        "13th physical bot elimination failed")
    check(director._active_opponent_drop_count()==12 and
        director._opponent_drops_spawned==12 and
        director.get_node_or_null("AuroraOpponentLoot13")==null,
        "full cache budget allocated an extra live pickup")

    # Consume the actual cached ammo through its original pickup method;
    # collected loot must free a slot even before queue_free has completed.
    var first: Area3D=director.get_node(
        "AuroraOpponentLoot1") as Area3D
    var before: int=int(combat.reserve[0])
    if first!=null:
        player.global_position=first.global_position-Vector3.UP*.85
        player.velocity=Vector3.ZERO
        await physics_frame
        await physics_frame
        if is_instance_valid(first) and not first.collected:
            first._collect(player)
        check(is_instance_valid(first) and first.collected and
            int(combat.reserve[0])>before,
            "first opponent cache did not physically grant carried ammo")
    check(director._active_opponent_drop_count()==11,
        "collected/queued cache still counted against active budget")

    # A *later*, distinct enemy can now place its real carried ammo even
    # though the original cumulative counter has reached 12.
    check(_kill(combat._targets[13],player,terrain,13),
        "14th physical bot elimination failed")
    var later: Area3D=director.get_node_or_null(
        "AuroraOpponentLoot13") as Area3D
    check(later!=null and director._opponent_drops_spawned==13 and
        director._active_opponent_drop_count()==12,
        "later physical kill lost loot despite a recycled active slot")
    if later!=null:
        check(later.pickup_type=="ammo_ar" and later.quantity==7 and
            later.from_opponent and
            later.get_node_or_null("LootPickupRange") is CollisionShape3D,
            "recycled cache fabricated quantity or lacks physical collider")
    director._on_opponent_eliminated(combat._targets[13],player)
    check(director._opponent_drops_spawned==13,
        "duplicate late kill signal created extra loot")

    check(_kill(combat._targets[14],player,terrain,14),
        "15th physical bot elimination failed")
    check(director._active_opponent_drop_count()==12 and
        director._opponent_drops_spawned==13,
        "cache slot was reused again while all 12 were occupied")

    # A new round clears the live-loot budget immediately, while Godot
    # queue_free() keeps old nodes accessible until the end of the frame.
    # Assert both lifecycle phases rather than treating deferred deletion
    # as a gameplay regression.
    var stale: Area3D=director.get_node_or_null(
        "AuroraOpponentLoot13") as Area3D
    check(stale!=null and not stale.is_queued_for_deletion(),
        "test fixture lost late-round cache before reset")
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(director._active_opponent_drop_count()==0 and
        director._opponent_drops_spawned==0 and
        stale!=null and stale.is_queued_for_deletion(),
        "new round failed to reset cache budget or queue old caches")
    await process_frame
    check(not is_instance_valid(stale) and
        director.get_node_or_null("AuroraOpponentLoot13")==null and
        director._active_opponent_drop_count()==0,
        "old cache survived the next frame after queue_free")
    if not failed:
        print("V75138_OPPONENT_LOOT_BUDGET PASS max_live=12 "+
            "later_kill_drops=1 real_pickup=1 no_fake_items=1 "+
            "no_duplicate=1 new_round_reset=1 vulkan_budget=1")
    game.queue_free()
    await process_frame
    quit(1 if failed else 0)
