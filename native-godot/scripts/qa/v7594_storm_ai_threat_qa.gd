extends SceneTree
## V75.94 — real 50-bot storm damage without invented shooter awareness,
## and real acoustic/pathfinding events staggered over mobile physics frames.
const BOT=preload("res://scripts/ai/aurora_bot.gd")
const COMBAT=preload("res://scripts/combat/training_combat.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V7594_STORM_AI_THREAT "+why)


func _verify() -> void:
    var slots: Dictionary={}
    for id in range(49):
        var period: float=BOT.route_replan_interval(id)
        slots[roundi(period*1000.0)]=true
        check(period>=.90 and period<=1.35,
            "a living bot's true route refresh is stalled or unbounded")
    check(BOT.ROUTE_REPLAN_BUCKETS==17 and slots.size()==17,
        "49 bots still synchronize their periodic pathfinding in four bursts")

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
    nav.set_physics_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(combat.active_fighter_count()==50 and combat._targets.size()==49,
        "full BR no longer contains 49 real collision-driven rivals")

    var listener: CharacterBody3D=combat._targets[8]
    listener._sense_clock=100.0
    listener._target_actor=null
    listener._target_visible=false
    listener._alert_time=0.0
    listener._suppression_seconds=0.0
    listener._last_seen=Vector3(302.0,5.0,-221.0)
    listener._cover_clock=1.0
    listener._route_clock=1.0
    listener.health=70.0
    var prior_health: float=listener.health
    var old_seen: Vector3=listener._last_seen
    check(not listener.take_training_damage(6.0,null) and
        is_equal_approx(listener.health,prior_health-6.0) and
        listener._alert_time==0.0 and
        listener._suppression_seconds==0.0 and
        listener._last_seen==old_seen and
        listener._cover_clock==1.0 and
        listener._route_clock==1.0,
        "real damage from storm fabricated an enemy shooter or cover task")
    # A real human hit MUST still trigger the original suppressive combat
    # tactics, rather than suppressing all alerts after the storm fix.
    listener._target_actor=null
    listener.take_training_damage(3.0,player)
    check(listener._alert_time>=5.0 and
        listener._suppression_seconds>=5.0 and
        listener._last_seen.distance_to(player.global_position)<.001 and
        listener._cover_clock==0.0 and
        listener._sense_clock==0.0,
        "true physical attacker no longer triggers cover/reaction")

    # Even a previously alerted, low-HP enemy should not search cover
    # INSIDE the damaging storm when escape is immediately required.
    listener.health=38.0
    listener._sense_clock=100.0
    listener._alert_time=4.0
    listener._target_actor=null
    listener._target_visible=false
    listener._cover_clock=0.0
    listener._cover_point=Vector3(INF,INF,INF)
    listener._heal_remaining=0.0
    listener._field_medkits=0
    listener.safe_center=Vector2(listener.global_position.x+35.0,
        listener.global_position.z)
    listener.safe_radius=10.0
    listener.next_zone_active=false
    listener._physics_process(.016)
    check(listener.behavior=="zone_escape" and
        listener._cover_clock<=0.0 and not listener._cover_point.is_finite(),
        "storm-damaged real AI performed needless physical cover searches")

    var shooter: CharacterBody3D=combat._targets[9]
    listener._alert_time=0.0
    listener._target_visible=false
    listener._target_actor=null
    listener._sense_clock=3.0
    listener._route_clock=3.0
    listener._route=PackedVector3Array([Vector3(1,0,1)])
    listener.hear_gunshot(listener.global_position+Vector3(6.0,0,0),shooter)
    check(listener.heard_shots==1 and
        listener._route.is_empty() and listener._route_clock>0.0 and
        listener._route_clock<.25 and
        not listener._target_visible,
        "genuine acoustic threat was confused with sight or 49 instant A* tasks")
    game.queue_free()
    await process_frame
    if not failed:
        print("V7594_STORM_AI_THREAT PASS physical_roster=50 "+
            "ambient_damage_no_phantom_shooter=1 physical_shooter_alert=1 "+
            "hazard_no_cover=1 staggered_routes=17 sound_navigation=bounded "+
            "online=false motorola_fps=unmeasured")
    quit(1 if failed else 0)
