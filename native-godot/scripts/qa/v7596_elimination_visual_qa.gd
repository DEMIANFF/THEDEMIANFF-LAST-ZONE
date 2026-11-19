extends SceneTree
## V75.96: real CharacterBody3D death yields brief authentic visual
## reaction and then releases resources. The victim is physically dead
## immediately, cannot shoot, collide or duplicate kills while animating.
const BOT=preload("res://scripts/ai/aurora_bot.gd")
const COMBAT=preload("res://scripts/combat/training_combat.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7596_ELIMINATION_VISUAL "+reason)


func _verify() -> void:
    check(BOT.DEFEAT_PRESENTATION_SECONDS>=.55 and
        BOT.DEFEAT_PRESENTATION_SECONDS<=1.0,
        "death reaction has unbounded or imperceptible lifespan")
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
        "death visuals reduced the count of real BR participants")

    var physical_victim: CharacterBody3D=combat._targets[0]
    var marker: Label3D=physical_victim.get_node("TrainingTargetMarker")
    check(physical_victim._rig!=null and physical_victim._animation!=null,
        "the baseline physical enemy lost its humanoid animation rig")
    var original: Transform3D=physical_victim._rig.transform
    var expected_impact: String=BOT.IMPACT.directional_hit_clip(
        player.global_position,physical_victim.global_position,
        physical_victim.global_basis)
    check(physical_victim.take_training_damage(500.0,player) and
        physical_victim.health==0.0 and
        not physical_victim.is_physics_processing() and
        physical_victim.visible and
        not marker.visible and
        physical_victim._death_tween!=null and
        physical_victim._death_tween.is_running() and
        physical_victim._animation.current_animation==expected_impact and
        combat.eliminations==1 and combat.active_fighter_count()==49,
        "actual death did not immediately disable hitbox/AI and play real rig")
    check(not physical_victim.take_training_damage(500.0,player) and
        combat.eliminations==1,
        "visible fall reaction generated extra phantom eliminations")
    await create_timer(BOT.DEFEAT_PRESENTATION_SECONDS+.12).timeout
    check(not physical_victim.visible and
        physical_victim.health==0.0 and
        not physical_victim.is_physics_processing(),
        "eliminated physical enemy stayed visible or attacking indefinitely")

    # LOD enemies must use their existing low-poly mesh, not generate a
    # fresh high-poly rig for each death across 49 mobile combatants.
    var distant: CharacterBody3D=combat._targets[21]
    check(distant._lod_body!=null and distant._rig==null,
        "distant enemy would allocate unbounded skeletal death meshes")
    check(distant.take_training_damage(500.0,player) and
        distant.visible and distant._death_tween!=null and
        combat.eliminations==2,
        "low-poly rival has no physical death/collider-free reaction")
    # Restart during a still-running corpse reaction: it must not hide
    # a NEW live fighter later or retain the prior collapsed visual pose.
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    nav.set_physics_process(false)
    for rival in combat._targets:
        rival.set_physics_process(false)
    check(physical_victim.visible and physical_victim.health==BOT.MAX_HEALTH and
        distant.visible and distant.health==BOT.MAX_HEALTH and
        physical_victim._rig.transform==original and
        distant._death_tween==null and
        combat.eliminations==0 and combat.active_fighter_count()==50,
        "new round inherited corpse pose, deferred hide, or past human kills")
    await create_timer(BOT.DEFEAT_PRESENTATION_SECONDS+.12).timeout
    check(distant.visible and distant.health==BOT.MAX_HEALTH and
        combat.active_fighter_count()==50,
        "old corpse callback hid a live respawned opponent")
    game.queue_free()
    await process_frame
    if not failed:
        print("V7596_ELIMINATION_VISUAL PASS roster=50 "+
            "real_skeletal_hit=1 noncolliding_death=1 animation=.75s "+
            "low_poly_death=1 dead_loot_immediate=1 restart=clean "+
            "online=false motorola_fps=unmeasured")
    quit(1 if failed else 0)
