extends SceneTree
## V75.97 — real GLB directional hit reactions on live physical bots.
## Damage and raycast pipelines stay unchanged; no extra skeletons or AI.
const BOT=preload("res://scripts/ai/aurora_bot.gd")
const COMBAT=preload("res://scripts/combat/training_combat.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V7597_DIRECTIONAL_OPPONENT_IMPACT "+why)


func _verify() -> void:
    check(BOT.IMPACT_REACTION_SECONDS>=.20 and
        BOT.IMPACT_REACTION_SECONDS<=.4 and
        BOT.IMPACT_REACTION_VIEW_DISTANCE<=48.0,
        "hit reaction duration/distance exceeds real mobile bounds")
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
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
        "real 50-participant battle missing when testing hit skeleton")
    var victim: CharacterBody3D=combat._targets[0]
    check(victim._rig!=null and victim._animation!=null,
        "physical near enemy missing authored humanoid skeleton")
    victim.rotation=Vector3.ZERO
    victim._sense_clock=99.0
    victim._attack_clock=99.0
    var original_hp: float=victim.health
    for entry in [
        {"offset":Vector3(0,0,-6),"clip":"AuroraHitFront"},
        {"offset":Vector3(0,0,6),"clip":"AuroraHitBack"},
        {"offset":Vector3(-6,0,0),"clip":"AuroraHitLeft"},
        {"offset":Vector3(6,0,0),"clip":"AuroraHitRight"}
    ]:
        player.global_position=victim.global_position+entry.offset
        var before: int=victim.hit_reactions_shown
        check(not victim.take_training_damage(6.0,player) and
            victim.health>0.0 and
            victim.hit_reactions_shown==before+1 and
            victim.last_hit_reaction==entry.clip and
            victim._animation.current_animation==entry.clip and
            victim._impact_reaction_remaining>0.0,
            "real physical damage failed to play direction "+entry.clip)
    check(absf(victim.health-(original_hp-24.0))<.001 and
        victim.hit_reactions_shown==4 and not victim.is_physics_processing(),
        "visual hit feedback mutated health or physics state")

    var count: int=victim.hit_reactions_shown
    victim.take_training_damage(3.0,null)
    check(victim.hit_reactions_shown==count and
        victim._impact_reaction_remaining>0.0,
        "environmental damage fabricated a shooter animation")

    # Manual physics tick: a real opponent resumes its existing locomotion
    # after the brief reaction, while still being able to move and fire.
    var previous_navigation: Node3D=victim.navigation
    victim.navigation=null
    victim._sense_clock=99.0
    victim._attack_clock=99.0
    victim._alert_time=0.0
    victim._target_visible=false
    victim._target_actor=null
    victim.safe_radius=INF
    victim._physics_process(BOT.IMPACT_REACTION_SECONDS+.03)
    check(victim.health>0.0 and
        victim._impact_reaction_remaining==0.0 and
        victim._animation.current_animation in ["AuroraWalk","AuroraIdle","AuroraRun"],
        "opponent permanently stuck in hit reaction rather than walking")
    victim.navigation=previous_navigation

    # Low-poly opponents take the same physical damage without allocating
    # a 15th high-quality character rig just to display a distant injury.
    var distant: CharacterBody3D=combat._targets[25]
    var previous_rigs: int=get_nodes_in_group(
        BOT.DETAILED_ENEMY_GROUP).size()
    var before_health: float=distant.health
    check(not distant.take_training_damage(7.0,player) and
        distant.health==before_health-7.0 and
        distant._rig==null and distant.hit_reactions_shown==0 and
        get_nodes_in_group(BOT.DETAILED_ENEMY_GROUP).size()==previous_rigs,
        "distant real AI hit generated a new expensive skinned model")

    # A fatal actual hit plays the correct body-relative skeletal clip,
    # but death, collider removal and kill accounting happen immediately.
    player.global_position=victim.global_position+Vector3(0,0,-7)
    var credited: int=combat.eliminations
    var expected: String=BOT.IMPACT.directional_hit_clip(
        player.global_position,victim.global_position,victim.global_basis)
    check(victim.take_training_damage(500.0,player) and
        victim.health==0.0 and not victim.is_physics_processing() and
        victim._animation.current_animation==expected and
        combat.eliminations==credited+1,
        "physical death lost real killer direction or combat credit")
    # Bot already wounded by player can then die from the real storm.
    # Its previous attacker MUST NOT influence this fatality's animation,
    # and must not receive an unearned player elimination.
    var storm_victim: CharacterBody3D=combat._targets[1]
    var human_kills: int=combat.eliminations
    player.global_position=storm_victim.global_position+Vector3(0,0,-6)
    storm_victim.take_training_damage(8.0,player)
    check(storm_victim.health>0.0 and
        storm_victim._last_attacker==player,
        "cannot establish prior shooter before environmental death")
    check(storm_victim.take_training_damage(500.0,null) and
        storm_victim.health==0.0 and
        storm_victim._animation.current_animation=="AuroraHit" and
        combat.eliminations==human_kills,
        "storm fatality reused old attacker or awarded a fake human kill")
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    nav.set_physics_process(false)
    for rival in combat._targets:
        rival.set_physics_process(false)
    check(victim.health==100.0 and victim.last_hit_reaction=="" and
        victim.hit_reactions_shown==0 and
        victim._impact_reaction_remaining==0.0 and
        combat.active_fighter_count()==50 and combat.eliminations==0,
        "new BR retained previous injury, death pose, or kill count")
    game.queue_free()
    await process_frame
    if not failed:
        print("V7597_DIRECTIONAL_OPPONENT_IMPACT PASS roster=50 "+
            "four_rig_hit_clips=1 real_damage=1 storm_no_fake_shooter=1 "+
            "gait_resume=1 LOD_budget_14=1 physical_death_direction=1 "+
            "storm_finisher=anonymous "+
            "restart=clean multiplayer_online=false motorola_fps=unmeasured")
    quit(1 if failed else 0)
