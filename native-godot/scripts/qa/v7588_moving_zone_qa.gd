extends SceneTree
## V75.88 real Battle Royale storm: moving nested safe circles, same actual
## HUD/hazard/AI destination, no teleporting, sub-meter final ring visual.
const DIRECTOR=preload("res://scripts/match/sector_director.gd")
const COMBAT=preload("res://scripts/combat/training_combat.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7588_MOVING_ZONE "+reason)


func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var operator: CharacterBody3D=game.get_node("Operator")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    combat.set_encounter_size(COMBAT.CLASSIC_BR_PARTICIPANTS)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    operator.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(combat.active_fighter_count()==50 and combat._targets.size()==49,
        "moving zone test lost real 49-foe Battle Royale")
    check(director._phase_centers.size()==5 and
        director.zone_center==DIRECTOR.CENTER,
        "zone starts outside the shared aircraft landing island")
    var final_center: Vector2=director._phase_centers[4]
    check(final_center.distance_to(DIRECTOR.CENTER)>1.0 and
        combat._is_clear_spawn(final_center),
        "chosen final circle is static, offshore, steep or inaccessible")
    var original_centers: Array[Vector2]=director._phase_centers.duplicate()
    director._configure_zone_centers(director._match_id)
    check(director._phase_centers==original_centers,
        "same persisted match ID no longer regenerates identical circle")
    director._configure_zone_centers(director._match_id+1)
    check(director._phase_centers[4]!=final_center,
        "different match IDs always replay exactly the same final circle")
    director._configure_zone_centers(director._match_id)
    var last_radius: float=INF
    var last_center: Vector2=DIRECTOR.CENTER
    for sec in range(0,661,2):
        var state: Dictionary=director.zone_state_at(float(sec))
        var radius: float=float(state["radius"])
        var center: Vector2=state["center"]
        if last_radius<INF:
            check(radius<=last_radius+.001 and
                center.distance_to(last_center)<=last_radius-radius+.012,
                "consecutive 2-second safe circles are not nested at "+str(sec))
        last_radius=radius
        last_center=center
    director._process(120.0)
    var radar: Control=game.get_node("TrainingHUD")._training_radar
    var actual: Dictionary=director.zone_state_at(120.0)
    check(director.zone_center.distance_to(actual["center"])<.001 and
        director._zone_visual.world_center.distance_to(director.zone_center)<.001 and
        absf(director._zone_visual.safe_radius-director.radius)<.35,
        "gameplay damage radius or visible ring does not follow moving center")
    check(absf(float(radar.get("_zone_radius"))-director.radius)<.001 and
        absf(float(radar.get("_next_zone_radius"))-DIRECTOR.PHASE_RADII[1])<.001 and
        (radar.get("_next_zone_center") as Vector2).distance_to(
            director._phase_centers[1])<.001,
        "real minimap lost current/next moving storm circles")
    for bot in combat._targets:
        check(bot.safe_center.distance_to(director.zone_center)<.001,
            "bot AI still navigates toward outdated fixed storm center")
    check(not director.is_outside_zone(Vector3(
        director.zone_center.x,0.0,director.zone_center.y)),
        "storm damages players standing at its true current center")
    var outside: Vector2=director.zone_center+Vector2(director.radius+5.0,0.0)
    check(director.is_outside_zone(Vector3(outside.x,0.0,outside.y)),
        "storm fails to damage outside the moving ring")
    director._process(540.0)
    check(director.radius==DIRECTOR.OVERTIME_RADIUS and
        absf(director._zone_visual.safe_radius-DIRECTOR.OVERTIME_RADIUS)<.001 and
        director._zone_visual.world_center.distance_to(final_center)<.001,
        "visible final ring stays 3m while actual damage zone is 0.75m")
    # The final overtime has no hypothetical fifth safe circle. The
    # next-ring indicator must be hidden, not forced to match the last radius.
    # The old assertion inspected a stale hidden cache and reported a false
    # visible-map regression despite the actual zone already being 0.75m.
    check(absf(float(radar.get("_zone_radius"))-DIRECTOR.OVERTIME_RADIUS)<.001
        and not bool(radar.get("_next_zone_enabled")),
        "minimap is not at the true 0.75m final radius or shows a fifth zone")
    var zone_label: Label=radar.get("_zone_label") as Label
    check(zone_label!=null and zone_label.text.contains("0.75") and
        not zone_label.text.contains("PRÓX"),
        "final minimap label must show 0.75m without any future circle")
    game.queue_free()
    await process_frame
    if not failed:
        print("V7588_MOVING_ZONE PASS roster=50 seeded=1 nested=1 "+
            "visual_hazard_center=aligned radar_next=1 bots=49 final_radius=0.75 "+
            "online=not_claimed motorola_fps=unmeasured")
    quit(1 if failed else 0)
