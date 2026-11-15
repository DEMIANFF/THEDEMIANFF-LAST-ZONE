extends SceneTree
## V75.100 — existing rig plays real firearm/reload animations ONLY
## when actual 3D bot bullets or timed magazine reloads occur.
## Physics, damage, real 50-person roster and 14-rig mobile cap unchanged.
const BOT=preload("res://scripts/ai/aurora_bot.gd")
const COMBAT=preload("res://scripts/combat/training_combat.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75100_BOT_WEAPON_MOTION "+reason)


func _verify() -> void:
    check(BOT.FIRE_PRESENTATION_SECONDS>=.12 and
        BOT.FIRE_PRESENTATION_SECONDS<=.35,
        "physical weapon recoil visual is longer than its real cadence")
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var player: CharacterBody3D=game.get_node("Operator")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var nav: Node3D=game.get_node("AuroraNavigation")
    for actor in combat._targets:
        actor.set_physics_process(false)
    await physics_frame
    combat.set_encounter_size(COMBAT.CLASSIC_BR_PARTICIPANTS)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    nav.set_physics_process(false)
    player.set_physics_process(false)
    for actor in combat._targets:
        actor.set_physics_process(false)
    check(combat._targets.size()==49 and combat.active_fighter_count()==50,
        "real 50-fighter BR missing in weapon animation integration")

    var shooter: CharacterBody3D=combat._targets[0]
    var rival: CharacterBody3D=combat._targets[1]
    var height: float=terrain.height_at(105.0,20.0)+2.0
    shooter.global_position=Vector3(105.0,height,17.0)
    rival.global_position=Vector3(105.0,height,23.0)
    player.global_position=Vector3(98.0,height,17.0)
    # PhysicsServer registers moved capsules at the next physics step,
    # not at the instant the QA assigns global_position. The existing
    # V75.50 real-shot regression waits two ticks for this exact reason.
    shooter.velocity=Vector3.ZERO
    rival.velocity=Vector3.ZERO
    await physics_frame
    await physics_frame
    var initial_rigs: int=get_nodes_in_group(BOT.DETAILED_ENEMY_GROUP).size()
    check(shooter._rig!=null and shooter._animation!=null and
        shooter._animation.has_animation("AuroraFire") and
        shooter._animation.has_animation("AuroraReloadAR"),
        "real nearby enemy is missing original keyed firearm/reload GLB")
    shooter.navigation=null
    shooter._target_actor=rival
    shooter._target_visible=true
    shooter._last_seen=rival.global_position
    shooter._alert_time=3.0
    shooter._sense_clock=100.0
    shooter._attack_clock=0.0
    shooter._reload_remaining=0.0
    shooter._magazine=7
    shooter._field_medkits=0
    shooter.safe_radius=INF
    shooter.next_zone_active=false
    shooter._impact_reaction_remaining=0.0
    check(shooter._has_line_of_fire(rival),
        "actual muzzle ray could not reach the prepared physical rival")
    var hp: float=rival.health
    var real_shots: int=shooter.shots_fired
    shooter._physics_process(.016)
    check(shooter.shots_fired==real_shots+1 and
        shooter._magazine==6,
        "physical fired shot/magazine mismatch; shots="+
        str(shooter.shots_fired-real_shots)+" ammo="+str(shooter._magazine))
    check(shooter.weapon_actions_shown==1 and
        shooter._animation.current_animation=="AuroraFire" and
        shooter._weapon_action_remaining>0.0 and
        is_equal_approx(shooter._animation.speed_scale,
            shooter._animation.get_animation("AuroraFire").length/
            BOT.FIRE_PRESENTATION_SECONDS),
        "valid physical shot did not start original GLB recoil: count="+
        str(shooter.weapon_actions_shown)+" clip="+
        str(shooter._animation.current_animation)+" timer="+
        str(shooter._weapon_action_remaining))
    check(rival.health<hp,
        "actual physics trace did not reach the rival after collider sync: "+
        "hp="+str(rival.health)+" starting="+str(hp)+
        " shots_hit="+str(shooter.shots_hit))
    var shots_after: int=shooter.shots_fired
    shooter._attack_clock=10.0
    shooter._target_visible=false
    shooter._target_actor=null
    shooter._alert_time=0.0
    shooter._sense_clock=100.0
    shooter._physics_process(BOT.FIRE_PRESENTATION_SECONDS+.04)
    check(shooter.shots_fired==shots_after and
        shooter._weapon_action_remaining==0.0 and
        shooter._animation.current_animation in ["AuroraIdle","AuroraWalk"],
        "shoot recoil locked skeletal opponent in firearm stance")

    var reload_before: int=shooter.reloads_completed
    var rounds_before: int=shooter._magazine
    shooter._reload_remaining=0.0
    shooter._attack_clock=0.0
    shooter._begin_reload()
    check(shooter._reload_remaining==BOT.RELOAD_SECONDS and
        shooter._magazine==rounds_before and
        shooter.reload_actions_shown==1 and
        shooter._animation.current_animation=="AuroraReloadAR" and
        shooter._weapon_action_remaining>0.0 and
        is_equal_approx(shooter._animation.speed_scale,
            shooter._animation.get_animation("AuroraReloadAR").length/
            BOT.RELOAD_SECONDS),
        "timed physical reload omitted authored visible skeletal reload")
    # The ordinary physics timer, not a dummy animation callback,
    # refills the real magazine and accounts for one completed reload.
    shooter._attack_clock=100.0
    shooter._physics_process(BOT.RELOAD_SECONDS+.06)
    check(shooter._magazine==BOT.MAGAZINE_CAPACITY and
        shooter.reloads_completed==reload_before+1 and
        shooter._reload_remaining==0.0 and
        shooter._weapon_action_remaining==0.0 and
        is_equal_approx(shooter._animation.speed_scale,1.0) and
        shooter._animation.current_animation in ["AuroraIdle","AuroraWalk"],
        "reload visual changed ballistics or left the bot stuck in motion")

    shooter._impact_reaction_remaining=.18
    var total: int=shooter.weapon_actions_shown
    var keep_clip: String=shooter._animation.current_animation
    check(not shooter._play_weapon_action("AuroraFire",.24) and
        shooter.weapon_actions_shown==total and
        shooter._animation.current_animation==keep_clip,
        "weapon visual overwrote a real incoming physical hit reaction")

    var far: CharacterBody3D=combat._targets[24]
    check(far._rig==null and not far._play_weapon_action("AuroraFire",.26)
        and far.weapon_actions_shown==0 and
        get_nodes_in_group(BOT.DETAILED_ENEMY_GROUP).size()==initial_rigs
        and initial_rigs<=BOT.MAX_DETAILED_ENEMY_RIGS,
        "49 real bots allocated more detailed skeletons to show shots")

    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    nav.set_physics_process(false)
    player.set_physics_process(false)
    for actor in combat._targets:
        actor.set_physics_process(false)
    check(combat.active_fighter_count()==50 and
        shooter.weapon_actions_shown==0 and
        shooter.reload_actions_shown==0 and
        shooter._weapon_action_remaining==0.0 and
        shooter.health==100.0,
        "new round inherited stale weapon action or damaged roster")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75100_BOT_WEAPON_MOTION PASS physical_roster=50 "+
            "real_bullet_rig_fire=1 physical_magazine_recoil=1 "+
            "timed_reload_visible=1 refill=authoritative "+
            "hit_reaction_priority=1 visual_rig_cap=14 "+
            "round_reset=clean online=false motorola_fps=unmeasured")
    quit(1 if failed else 0)
