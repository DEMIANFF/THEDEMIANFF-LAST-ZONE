extends SceneTree
## V75.90 — actual forward rotation for 49 physical bots, never teleporting,
## while keeping combat line-of-sight and current storm survival priorities.
const BOT=preload("res://scripts/ai/aurora_bot.gd")
const COMBAT=preload("res://scripts/combat/training_combat.gd")
const DIRECTOR=preload("res://scripts/match/sector_director.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V7590_ZONE_ROTATION "+why)


func _verify() -> void:
    check(BOT.NEXT_ZONE_ROTATE_SECONDS==45,
        "AI anticipation window cannot be measured in actual seconds")
    check(not BOT.should_rotate_to_next_zone(Vector3.ZERO,Vector2(28,0),
        14.0,46,false) and
        BOT.should_rotate_to_next_zone(Vector3.ZERO,Vector2(28,0),
        14.0,45,false) and
        not BOT.should_rotate_to_next_zone(Vector3.ZERO,Vector2(28,0),
        14.0,30,true) and
        not BOT.should_rotate_to_next_zone(Vector3.ZERO,Vector2.ZERO,
        14.0,30,false) and
        not BOT.should_rotate_to_next_zone(Vector3.ZERO,Vector2(28,0),
        14.0,0,false),
        "anticipation ignores phase timing, active firefights or safe locations")
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var operator: CharacterBody3D=game.get_node("Operator")
    var nav: Node3D=game.get_node("AuroraNavigation")
    for rival in combat._targets:
        rival.set_physics_process(false)
    await physics_frame
    combat.set_encounter_size(COMBAT.CLASSIC_BR_PARTICIPANTS)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    nav.set_physics_process(false)
    operator.set_physics_process(false)
    for rival in combat._targets:
        rival.set_physics_process(false)
    check(combat.active_fighter_count()==50 and combat._targets.size()==49,
        "BR 50 physical participants disappeared in AI rotation")
    var first_center: Vector2=director._phase_centers[1]
    for rival in combat._targets:
        check(rival.next_zone_active and
            rival.next_safe_center.distance_to(first_center)<.001 and
            absf(rival.next_safe_radius-DIRECTOR.PHASE_RADII[1])<.001 and
            rival.zone_seconds_remaining==150,
            "49 AI have inconsistent next-circle position or deadline")
    director._process(109.0)
    var phase: Dictionary=director.zone_state_at(109.0)
    check(director.zone_seconds_remaining<=45 and
        director.zone_center.distance_to(phase["center"])<.001,
        "real zone did not enter 45-second decision window")
    for rival in combat._targets:
        check(rival.zone_seconds_remaining==director.zone_seconds_remaining and
            rival.next_safe_center.distance_to(first_center)<.001,
            "bots do not receive updated phase timing and safe destination")
    var test_bot: CharacterBody3D=combat._targets[8]
    var saved_nav: Node3D=test_bot.navigation
    test_bot.navigation=null
    test_bot._sense_clock=100.0
    test_bot._alert_time=0.0
    test_bot._target_actor=null
    test_bot._target_visible=false
    test_bot._heal_remaining=0.0
    test_bot._reload_remaining=0.0
    test_bot._magazine=BOT.MAGAZINE_CAPACITY
    test_bot._route_clock=100.0
    test_bot.safe_center=Vector2(test_bot.global_position.x,
        test_bot.global_position.z)
    test_bot.safe_radius=1000.0
    test_bot.next_safe_center=Vector2(test_bot.global_position.x+24.0,
        test_bot.global_position.z+12.0)
    test_bot.next_safe_radius=8.0
    test_bot.next_zone_active=true
    test_bot.zone_seconds_remaining=30
    var start: Vector3=test_bot.global_position
    test_bot._physics_process(.032)
    check(test_bot.behavior=="zone_rotate" and
        Vector2(test_bot.velocity.x,test_bot.velocity.z).length()>.01 and
        test_bot.global_position.distance_to(start)<2.0,
        "AI failed to physically navigate to next circle, or teleported")
    test_bot._target_visible=true
    test_bot._target_actor=operator
    var engaged: bool=BOT.should_rotate_to_next_zone(test_bot.global_position,
        test_bot.next_safe_center,test_bot.next_safe_radius,30,true)
    check(not engaged,
        "AI is improperly forced to rotate while fighting an actual enemy")
    test_bot.navigation=saved_nav
    director._process(551.0)
    check(director.zone_phase==DIRECTOR.PHASE_COUNT and
        director.zone_seconds_remaining==0,
        "test cannot evaluate terminal 0.75-m circle")
    for rival in combat._targets:
        check(not rival.next_zone_active,
            "AI still plans a nonexistent fifth Battle Royale zone")
    game.queue_free()
    await process_frame
    if not failed:
        print("V7590_ZONE_ROTATION PASS roster=50 timed=45s "+
            "current_hazard_priority=1 live_combat_priority=1 "+
            "physical_movement=1 last_phase_disabled=1 online=false")
    quit(1 if failed else 0)
