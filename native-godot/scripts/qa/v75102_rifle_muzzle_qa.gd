extends SceneTree
## V75.102: the original right-hand gun emits a short reusable muzzle
## effect and the visual tracer starts at its barrel only on real shots.
## Physics ray origin, health and 50 physical participants remain unchanged.
const BOT=preload("res://scripts/ai/aurora_bot.gd")
const COMBAT=preload("res://scripts/combat/training_combat.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75102_RIFLE_MUZZLE "+reason)


func _verify() -> void:
    check(BOT.REAL_MUZZLE_FLASH_SECONDS>.04 and
        BOT.REAL_MUZZLE_FLASH_SECONDS<.15,
        "the effect would persist or flash too quickly on Android")
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
    check(combat._targets.size()==49 and combat.active_fighter_count()==50,
        "50 genuine collision-driven fighters disappeared")
    var shooter: CharacterBody3D=combat._targets[0]
    var rival: CharacterBody3D=combat._targets[1]
    var flash: MeshInstance3D=shooter._enemy_muzzle_flash
    check(shooter._rig!=null and shooter._enemy_hand_rifle!=null and
        flash!=null and flash.get_parent()==
            shooter._enemy_hand_rifle.get_parent() and
        flash.mesh!=null and not flash.visible and
        flash.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
        "original skinned hand-rifle missing its reusable unlit muzzle")
    if flash==null:
        game.queue_free()
        await process_frame
        quit(1)
        return

    var physics_origin: Vector3=shooter.global_position+Vector3.UP*1.35
    var visual_origin: Vector3=shooter._visible_trace_origin(physics_origin)
    check(visual_origin.is_finite() and
        visual_origin.distance_to(flash.global_position)<.001 and
        visual_origin.distance_to(shooter.global_position)<5.0,
        "visual tracer not attached to the genuine rifle barrel")
    var fallback: Vector3=Vector3(10000,10000,10000)
    check(shooter._visible_trace_origin(fallback)==fallback,
        "bad imported rig transform moved the actual ballistics ray")

    var traces: Array[Vector3]=[]
    shooter.shot_trace.connect(func(origin: Vector3,_end: Vector3):
        traces.append(origin))
    var initial_rounds: int=shooter._magazine
    var shots: int=shooter.shots_fired
    check(shooter._fire_at_target(rival) and
        shooter.shots_fired==shots+1 and
        shooter._magazine==initial_rounds and
        traces.size()==1 and
        traces[0].distance_to(flash.global_position)<.001 and
        flash.visible and
        shooter.muzzle_flashes_shown==1 and
        shooter._muzzle_flash_remaining==BOT.REAL_MUZZLE_FLASH_SECONDS,
        "genuine physical shot did not trigger barrel-position tracer/flash")
    var flare_count: int=shooter.muzzle_flashes_shown
    shooter._play_weapon_action("AuroraFire",.26)
    check(shooter.muzzle_flashes_shown==flare_count,
        "playing cosmetic recoil without a real shot fabricated muzzle fire")

    # The effect is bounded in physics time. It does not start new shots,
    # change magazine counts, take cover damage, or allocate lights.
    shooter._sense_clock=100.0
    shooter._attack_clock=100.0
    shooter._target_actor=null
    shooter._target_visible=false
    shooter._alert_time=0.0
    shooter._field_medkits=0
    shooter.safe_radius=INF
    shooter.navigation=null
    shooter._physics_process(BOT.REAL_MUZZLE_FLASH_SECONDS+.04)
    check(not flash.visible and
        shooter._muzzle_flash_remaining==0.0 and
        shooter.muzzle_flashes_shown==flare_count and
        shooter.shots_fired==shots+1 and
        shooter._magazine==initial_rounds,
        "muzzle effect stayed visible or altered actual shot cadence")
    shooter._begin_reload()
    check(not flash.visible and shooter.muzzle_flashes_shown==flare_count and
        shooter._reload_remaining==BOT.RELOAD_SECONDS,
        "physical reload created an unauthorized muzzle flash")

    # Low-detail agents keep their true health, AI, bullets and collider
    # but never receive a high-detail flash or gun mesh as a side effect.
    var distant: CharacterBody3D=combat._targets[24]
    check(distant._rig==null and distant._enemy_hand_rifle==null and
        distant._enemy_muzzle_flash==null and
        distant.get_node_or_null("OpponentCollider") is CollisionShape3D,
        "41 distant physical bots gained an expensive new gun draw-call")
    var old_events: int=distant.muzzle_flashes_shown
    distant._show_real_muzzle_flash()
    check(distant.muzzle_flashes_shown==old_events and
        distant._visible_trace_origin(fallback)==fallback,
        "LOD muzzle animation invented a high-resolution visual")

    # Dynamic rig promotion/demotion must allocate/release the marker
    # with its original weapon bone without leaking objects in memory.
    var candidate: CharacterBody3D=combat._targets[8]
    var rigs: int=get_nodes_in_group(BOT.DETAILED_ENEMY_GROUP).size()
    candidate._set_full_visual(true)
    check(candidate._enemy_muzzle_flash!=null and
        not candidate._enemy_muzzle_flash.visible and
        get_nodes_in_group(BOT.DETAILED_ENEMY_GROUP).size()==rigs+1,
        "close real fighter promotion lacks a hidden shared muzzle effect")
    candidate._set_full_visual(false)
    check(candidate._enemy_muzzle_flash==null and
        candidate._enemy_hand_rifle==null and
        get_nodes_in_group(BOT.DETAILED_ENEMY_GROUP).size()==rigs and
        candidate.health>0.0,
        "far opponent LOD demotion leaked muzzle or removed combat body")

    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    nav.set_physics_process(false)
    for opponent in combat._targets:
        opponent.set_physics_process(false)
    check(combat.active_fighter_count()==50 and
        shooter.health==100.0 and shooter.muzzle_flashes_shown==0 and
        shooter._enemy_muzzle_flash!=null and
        not shooter._enemy_muzzle_flash.visible and
        shooter._muzzle_flash_remaining==0.0,
        "new BR inherited old muzzle flare or lost real opponents")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75102_RIFLE_MUZZLE PASS roster=50 original_hand_rifle=1 "+
            "physical_shot_flash=1 tracer_from_bone=1 no_fake_fire=1 "+
            "flash_decay=0.09s LOD_41_no_extra_rig=1 "+
            "dynamic_promotion_demotion=clean reload_no_flare=1 "+
            "new_round=clean online=false motorola_fps=unmeasured")
    quit(1 if failed else 0)
