extends SceneTree
## V75.91 — real physical bot stability after the storm contracts to 0.75m.
## Guards against the old permanent "zone_escape" state for every surviving AI.
const BOT=preload("res://scripts/ai/aurora_bot.gd")
const COMBAT=preload("res://scripts/combat/training_combat.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7591_FINAL_RING_AI "+reason)


func _verify() -> void:
    check(not BOT.should_escape_current_zone(Vector3.ZERO,Vector2.ZERO,.75)
        and BOT.should_escape_current_zone(Vector3(.68,0,0),Vector2.ZERO,.75)
        and BOT.should_escape_current_zone(Vector3(1.0,0,0),Vector2.ZERO,.75)
        and not BOT.should_escape_current_zone(Vector3(0,0,0),Vector2.ZERO,12.0),
        "endgame storm marked a safe fighter as permanently outside")
    check(BOT.should_hold_final_zone(Vector3(4,0,0),Vector2.ZERO,.75,false)
        and not BOT.should_hold_final_zone(Vector3(.2,0,0),Vector2.ZERO,.75,false)
        and not BOT.should_hold_final_zone(Vector3(4,0,0),Vector2.ZERO,.75,true)
        and not BOT.should_hold_final_zone(Vector3(4,0,0),Vector2.ZERO,112.0,false),
        "small-ring patrol still leaves combatant in storm")
    var from_far: Vector3=BOT.safe_zone_destination(
        Vector3(7,2,0),Vector2.ZERO,.75)
    check(from_far.is_finite() and from_far.x>.25 and from_far.x<.75
        and absf(from_far.y-2.0)<.001,
        "all physical agents are stacked at exactly one center point")

    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var player: CharacterBody3D=game.get_node("Operator")
    var nav: Node3D=game.get_node("AuroraNavigation")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    combat.set_encounter_size(COMBAT.CLASSIC_BR_PARTICIPANTS)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    nav.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(combat._targets.size()==49 and combat.active_fighter_count()==50,
        "real 50-person battle missing at final-zone simulation")

    var fighter: CharacterBody3D=combat._targets[8]
    # Force this one manual fixture tick past the independent mobile
    # three-frame LOD scheduler; leave production LOD implementation intact.
    fighter.distance_lod=false
    var previous_navigation: Node3D=fighter.navigation
    fighter.navigation=null
    fighter._sense_clock=80.0
    fighter._alert_time=0.0
    fighter._target_actor=null
    fighter._target_visible=false
    fighter._heal_remaining=0.0
    fighter._field_medkits=0
    fighter._reload_remaining=0.0
    fighter._magazine=BOT.MAGAZINE_CAPACITY
    fighter.next_zone_active=false
    fighter.safe_center=Vector2(fighter.global_position.x,
        fighter.global_position.z)
    fighter.safe_radius=.75
    var before: Vector3=fighter.global_position
    fighter._physics_process(.016)
    check(fighter.behavior=="zone_hold"
        and fighter.global_position.distance_to(before)<1.5,
        "real live rival resumed a 4m patrol outside the 0.75m safe ring")
    fighter._target_visible=false
    fighter._alert_time=0.0
    fighter.safe_center=Vector2(fighter.global_position.x+1.5,
        fighter.global_position.z)
    fighter._physics_process(.016)
    check(fighter.behavior=="zone_escape",
        "outside opponent never attempts physical storm escape")
    fighter.navigation=previous_navigation
    game.queue_free()
    await process_frame
    if not failed:
        print("V7591_FINAL_RING_AI PASS roster=50 true_collisions=49 "+
            "inside_zone_hold=1 outside_zone_escape=1 "+
            "staggered_inner_targets=1 motorola_fps=unmeasured online=false")
    quit(1 if failed else 0)
