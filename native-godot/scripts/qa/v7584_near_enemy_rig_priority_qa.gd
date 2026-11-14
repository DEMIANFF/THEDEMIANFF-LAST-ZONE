extends SceneTree
## V75.84 verifies that nearest active enemies win real mesh budget.
## Even visually demoted bots remain physical, targetable and visible.
const BOT=preload("res://scripts/ai/aurora_bot.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7584_AI_RIG_PRIORITY "+reason)


func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var player: CharacterBody3D=game.get_node("Operator")
    for rival in combat._targets:
        rival.set_physics_process(false)
    await physics_frame
    combat.set_encounter_size(50)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for rival in combat._targets:
        rival.set_physics_process(false)
    var chosen_distant: CharacterBody3D
    var chosen_near: CharacterBody3D
    for rival in combat._targets:
        if not rival.distance_lod:
            continue
        if rival._rig==null:
            rival._set_full_visual(true)
        if rival._rig!=null and chosen_distant==null:
            chosen_distant=rival
    for rival in combat._targets:
        if rival.distance_lod and rival._rig==null:
            chosen_near=rival
            break
    check(combat.active_fighter_count()==50 and
        get_nodes_in_group(BOT.DETAILED_ENEMY_GROUP).size()==
            BOT.MAX_DETAILED_ENEMY_RIGS,
        "50-agent roster or rig cap changed during nearest-first test")
    check(chosen_distant!=null and chosen_near!=null,
        "cannot test a skinned distant owner and low-poly close rival")
    if chosen_distant!=null and chosen_near!=null:
        var origin: Vector3=player.global_position
        # All current detailed LOD owners are placed close enough that
        # the designated 120m owner is uniquely farthest. The selection
        # is deterministic even when terrain spawns vary between builds.
        for rival in combat._targets:
            if rival.distance_lod and rival._rig!=null:
                rival.global_position=origin+Vector3(12.0,0.0,0.0)
        chosen_distant.global_position=origin+Vector3(120.0,0.0,0.0)
        chosen_near.global_position=origin+Vector3(2.0,0.0,0.0)
        var cap_before: int=get_nodes_in_group(
            BOT.DETAILED_ENEMY_GROUP).size()
        chosen_near._set_full_visual(true)
        check(chosen_near._rig!=null and chosen_distant._rig==null,
            "a close combatant did not displace a distant detail mesh")
        check(chosen_distant._lod_body!=null and
            chosen_distant._lod_body.visible,
            "far combatant vanished instead of retaining real low LOD")
        check(get_nodes_in_group(BOT.DETAILED_ENEMY_GROUP).size()==cap_before,
            "visual reprioritization exceeded rig allocation budget")
        check(chosen_distant.get_node_or_null("OpponentCollider") is CollisionShape3D
            and chosen_distant.health>0.0 and chosen_distant.sector_battle,
            "reprioritization damaged physical combatant state")
    game.queue_free()
    await process_frame
    if not failed:
        print("V7584_AI_RIG_PRIORITY PASS roster=50 "+
            "near_enemy=animated far_enemy=visible_lod "+
            "dynamic_rig_swap=actual maximum=14")
    quit(1 if failed else 0)
