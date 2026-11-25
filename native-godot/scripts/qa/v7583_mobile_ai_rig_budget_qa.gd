extends SceneTree
## V75.83 + V75.183: 50 physical fighters, shared original enemy visual\n## at all distances, with just 14 active AnimationPlayer leases.
const BOT=preload("res://scripts/ai/aurora_bot.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7583_AI_RIG_BUDGET "+reason)


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
    check(combat.active_fighter_count()==50 and combat._targets.size()==49,
        "rig budget removed actual physical AI fighters")
    var baseline: int=get_nodes_in_group(BOT.DETAILED_ENEMY_GROUP).size()
    check(baseline==8,
        "the eight ordinary combatants lost their genuine animated rig")
    var distant: Array[CharacterBody3D]=[]
    for rival in combat._targets:
        if rival.distance_lod:
            distant.append(rival)
    check(distant.size()==41,"distance LOD roster is not 41 real bots")
    for rival in distant:
        rival._set_full_visual(true)
    var detailed: int=get_nodes_in_group(BOT.DETAILED_ENEMY_GROUP).size()
    check(detailed==BOT.MAX_DETAILED_ENEMY_RIGS and
        detailed<combat._targets.size(),
        "live AI skinned meshes exceeded the mobile GPU memory budget")
    var fallback_count: int=0
    var populated: int=0
    var owner_to_free: CharacterBody3D
    var bot_to_promote: CharacterBody3D
    for rival in distant:
        if rival._rig==null:
            fallback_count+=1
            if bot_to_promote==null:
                bot_to_promote=rival
        else:
            if owner_to_free==null:
                owner_to_free=rival
            populated+=1
        check(rival.get_node_or_null("OpponentCollider") is CollisionShape3D and
            rival.health>0.0 and rival.sector_battle,
            "visual budget removed a damageable live opponent")
        if rival._rig==null:
            check(rival._lod_rig!=null and rival._lod_rig.visible and
                rival._lod_rig.find_child("Skeleton3D",true,false)!=null
                and not (rival._lod_rig.find_child(
                    "AnimationPlayer",true,false) as AnimationPlayer).active,
                "far rival does not retain identical frozen original 3D character")
    check(populated==BOT.MAX_DETAILED_ENEMY_RIGS-baseline and
        fallback_count==distant.size()-populated,
        "budget overflow did not preserve deterministic low-poly enemies")
    if owner_to_free!=null and bot_to_promote!=null:
        owner_to_free._set_full_visual(false)
        bot_to_promote._set_full_visual(true)
        check(get_nodes_in_group(BOT.DETAILED_ENEMY_GROUP).size()==
                BOT.MAX_DETAILED_ENEMY_RIGS and
                bot_to_promote._rig!=null and
                owner_to_free._lod_rig.visible and
                owner_to_free._lod_rig.find_child(
                    "Skeleton3D",true,false)!=null,
            "rig lease swap changed the character's visible appearance")
    game.queue_free()
    await process_frame
    if not failed:
        print("V7583_AI_RIG_BUDGET PASS roster=50 colliders=49 "+
            "rig_cap=14 initial_rigs=8 dynamic_rigs=6 "+
            "overflow=original_frozen_rig rig_reuse=real")
    quit(1 if failed else 0)
