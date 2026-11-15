extends SceneTree
## V75.101: 49 actual physical BR rivals; bounded 14 nearby skinned
## characters get the EXISTING rifle GLB attached to a genuine right
## hand bone. Distant rivals retain their real colliders/AI without a
## costly rifle mesh or invented remote position.
const BOT=preload("res://scripts/ai/aurora_bot.gd")
const COMBAT=preload("res://scripts/combat/training_combat.gd")
const RIFLE=preload("res://scripts/combat/weapon_visuals.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V75101_BOT_HAND_RIFLE "+why)


func _test_rifle(agent: CharacterBody3D,context: String) -> void:
    var rig: Node3D=agent._rig
    var socket: BoneAttachment3D=agent._enemy_right_hand_socket
    var visual: Node3D=agent._enemy_hand_rifle
    check(is_instance_valid(rig) and
        is_instance_valid(socket) and
        is_instance_valid(visual),
        context+" failed to mount an original detailed gun on live bot")
    if not is_instance_valid(socket) or not is_instance_valid(visual):
        return
    var skeleton: Skeleton3D=socket.get_parent() as Skeleton3D
    check(skeleton!=null and
        socket.bone_name.to_lower().ends_with("righthand") and
        socket.get_parent() is Skeleton3D,
        context+" gun was glued to camera/chest instead of skeleton hand")
    check(visual.name=="AK74TacticalOpponentVisual" and
        visual.get_parent() is Node3D and
        visual.get_parent().get_parent()==socket and
        visual.visible and visual.global_position.is_finite() and
        visual.global_position.distance_to(agent.global_position)<4.5,
        context+" hand weapon has invalid 3D mount or scaled displacement")
    var meshes: Array[Node]=visual.find_children(
        "*","MeshInstance3D",true,false)
    check(meshes.size()>=1 and
        visual.find_children("*","CollisionShape3D",true,false).is_empty(),
        context+" AR model missing geometry or added fake physics colliders")
    check(agent.get_node_or_null("OpponentCollider") is CollisionShape3D and
        agent.health>0.0,
        context+" rifle model removed the authentic hitbox/health")


func _verify() -> void:
    check(ResourceLoader.exists(RIFLE.AK_PATH),
        "the original AK model used by Lila was not imported")
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var player: CharacterBody3D=game.get_node("Operator")
    var nav: Node3D=game.get_node("AuroraNavigation")
    for rival in combat._targets:
        rival.set_physics_process(false)
    await physics_frame
    combat.set_encounter_size(COMBAT.CLASSIC_BR_PARTICIPANTS)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    nav.set_physics_process(false)
    for rival in combat._targets:
        rival.set_physics_process(false)
    check(combat._targets.size()==49 and
        combat.active_fighter_count()==50,
        "attaching hand guns deleted a physical BR fighter")
    var attached: int=0
    var low_poly: int=0
    for rival in combat._targets:
        if rival._rig!=null:
            attached+=1
            _test_rifle(rival,"initial detailed opponent")
        else:
            low_poly+=1
            check(rival._enemy_hand_rifle==null and
                rival._enemy_right_hand_socket==null and
                rival._lod_body!=null and rival._lod_body.visible and
                rival.get_node_or_null("OpponentCollider") is CollisionShape3D,
                "distant opponent acquired expensive weapon or lost body")
    check(attached==8 and low_poly==41 and
        get_nodes_in_group(BOT.DETAILED_ENEMY_GROUP).size()==8,
        "new hand weapons breached the original 8/41 mobile LOD split")

    var shooter: CharacterBody3D=combat._targets[0]
    var shot_before: int=shooter.shots_fired
    var rounds_before: int=shooter._magazine
    check(shooter._fire_at_target(combat._targets[1]) and
        shooter.shots_fired==shot_before+1 and
        shooter._magazine==rounds_before and
        shooter._enemy_hand_rifle.visible and
        shooter._animation.current_animation=="AuroraFire",
        "existing physical firearm was replaced with a decorative fake")
    shooter._begin_reload()
    check(shooter._reload_remaining==BOT.RELOAD_SECONDS and
        shooter._animation.current_animation=="AuroraReloadAR" and
        shooter._enemy_hand_rifle.visible,
        "timed real reload lost bone-attached rifle")

    var promoted: CharacterBody3D
    for rival in combat._targets:
        if rival.distance_lod and rival._rig==null:
            promoted=rival
            break
    check(promoted!=null,"no genuine low-poly bot for weapon LOD promotion")
    if promoted!=null:
        var before: int=get_nodes_in_group(
            BOT.DETAILED_ENEMY_GROUP).size()
        promoted._set_full_visual(true)
        check(get_nodes_in_group(BOT.DETAILED_ENEMY_GROUP).size()==before+1,
            "promoting one physical opponent did not allocate one rig")
        _test_rifle(promoted,"dynamic LOD promotion")
        promoted._set_full_visual(false)
        check(promoted._rig==null and
            promoted._enemy_hand_rifle==null and
            promoted._enemy_right_hand_socket==null and
            promoted._lod_body.visible and
            get_nodes_in_group(BOT.DETAILED_ENEMY_GROUP).size()==before,
            "LOD demotion leaked weapon/rig or removed live bot")
        check(promoted.health>0.0 and promoted.sector_battle and
            promoted.get_node_or_null("OpponentCollider") is CollisionShape3D,
            "freeing a detailed weapon also removed the opponent physics")

    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    nav.set_physics_process(false)
    for rival in combat._targets:
        rival.set_physics_process(false)
    check(combat.active_fighter_count()==50 and
        shooter._enemy_hand_rifle.visible and
        shooter._animation.current_animation=="AuroraIdle",
        "new round inherited stale recoil or lost rifle/physical roster")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75101_BOT_HAND_RIFLE PASS roster=50 "+
            "hand_socket=actual_bone original_AK_GLb=1 "+
            "detailed_with_rifles=8 distant_without_extra_draw=41 "+
            "shoot_and_reload=real low_poly_demote=clean "+
            "dynamic_rig_cap=14 online=false motorola_fps=unmeasured")
    quit(1 if failed else 0)
