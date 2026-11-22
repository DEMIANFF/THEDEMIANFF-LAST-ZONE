extends SceneTree
## V75.153 integration: the same true 50-fighter battle can end and restart
## without carrying previous rifle recoil, AWM bolt, MP40 magazine progress,
## sped-up original GLB reload clips or quick-switch to unowned weapon.
const WEAPONS=preload("res://scripts/combat/aurora_weapon_catalog.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75153_WEAPON_ROUND_LIFECYCLE "+reason)


func _verify() -> void:
    root.size=Vector2i(964,434)
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var actor: CharacterBody3D=game.get_node("Operator")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    combat.set_encounter_size(50)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    actor.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(combat.active_fighter_count()==50 and
        combat._targets.size()==49,
        "real 50-body battle replaced by a static fixture")

    check(combat.weapon_index==WEAPONS.AR and
        combat.weapon_owned==[true,false],
        "initial owned-weapon inventory is inconsistent")
    var initial_rounds: int=combat.ammo[WEAPONS.AR]
    var initial_shots: int=combat.shots_fired_total
    combat._on_weapon()
    check(combat.weapon_index==WEAPONS.AR and
        combat.ammo[WEAPONS.AR]==initial_rounds and
        combat.shots_fired_total==initial_shots,
        "quick-switch falsely equips a never-collected AWM")

    var visual: Node3D=combat._weapon_visuals
    var ar: Node3D=visual.currently_equipped()
    var rest: Transform3D=ar.transform
    combat.ammo[WEAPONS.AR]=2
    combat.cooldown=0.0
    combat.reload_timer=0.0
    combat._shoot()
    check(combat.ammo[WEAPONS.AR]==1 and
        visual._visual_recoil_left>0.0 and
        ar.transform.origin.distance_to(rest.origin)>.005,
        "actual AR-7 shot did not create physical model recoil")
    # An authentic source AnimationPlayer may be supplied by private GLB,
    # but this public QA uses an explicitly identified source-time fixture.
    var fixture:=AnimationPlayer.new()
    fixture.name="SourcePlaybackLifecycleFixture"
    visual.add_child(fixture)
    var library:=AnimationLibrary.new()
    var clip:=Animation.new()
    clip.length=3.2
    library.add_animation("reload",clip)
    fixture.add_animation_library("fixture",library)
    visual._source_animation_players[WEAPONS.SCAR]=fixture
    check(visual.play_source_action(WEAPONS.SCAR,"reload",1.6) and
        absf(fixture.speed_scale-2.0)<.001 and
        fixture.is_playing(),
        "original-source clip timer cannot be set up")
    combat._auto_reload_queued=true
    combat.end_sector_battle()
    check(not combat.sector_battle_active and
        not combat._auto_reload_queued and
        visual._visual_recoil_left==0.0 and
        ar.transform.origin.distance_to(rest.origin)<.0001 and
        ar.transform.basis.is_equal_approx(rest.basis) and
        visual._awm_mechanical_left==0.0 and
        not fixture.is_playing() and
        absf(fixture.speed_scale-1.0)<.001,
        "post-result kept physical recoil/animation/auto-reload ghosts")

    # Replaying from the lobby after results must restore 200 HP,
    # the single original AR-7 and all 49 physical enemy bodies.
    visual._source_animation_players.erase(WEAPONS.SCAR)
    fixture.queue_free()
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    actor.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(combat.active_fighter_count()==50 and
        combat.weapon_index==WEAPONS.AR and
        combat.weapon_owned==[true,false] and
        combat.ammo[WEAPONS.AR]==30 and
        visual._visual_recoil_left==0.0,
        "a second real BR leaked previous weapon state or reduced opponents")
    # Real physical weapon collection must unlock quick-switch again.
    check(combat.collect_sector_loot("weapon_mp40"),
        "MP40 original world mesh is not collectible")
    combat._on_weapon()
    check(combat.weapon_index==WEAPONS.MP40 and
        visual.selected_weapon==WEAPONS.MP40,
        "quick-switch failed to honor a legitimately owned second gun")
    combat._on_weapon()
    check(combat.weapon_index==WEAPONS.AR and
        visual.selected_weapon==WEAPONS.AR,
        "weapon cycle did not wrap to original AR-7")

    combat.end_sector_battle()
    game.queue_free()
    await process_frame
    if not failed:
        print("V75153_WEAPON_ROUND_LIFECYCLE PASS fighters=50 "+
            "unowned_AWM_blocked=1 real_AR_shot=1 "+
            "model_recoil_reset=1 imported_animation_stop=1 "+
            "source_speed_restored=1 second_match_50=1 "+
            "physical_MP40_quickswitch=1 no_last_round_ghosts=1")
    quit(1 if failed else 0)
