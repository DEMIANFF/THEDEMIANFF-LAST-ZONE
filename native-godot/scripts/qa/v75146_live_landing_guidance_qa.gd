extends SceneTree
## V75.146: one real, persisted tactical waypoint guides the operator
## during aircraft, freefall and canopy. No extra radar contacts or input.
## The test starts Main.tscn with 49 actual rivals and lands into real BR.
const AIRDROP=preload("res://scripts/match/airdrop_sequence.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75146_LIVE_LANDING_GUIDANCE "+reason)


func _verify() -> void:
    root.size=Vector2i(964,434)
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var player: CharacterBody3D=game.get_node("Operator")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var map: Control=hud.get_node(
        "AuroraTacticalOverlay/AuroraFullTacticalMap")
    var radar: Control=hud.get_node(
        "AuroraTacticalOverlay/AuroraTrainingRadar")
    var hint: Label=hud.get("_hint") as Label
    for rival in combat._targets:
        rival.set_physics_process(false)
    await physics_frame

    # No guidance appears in training, even with a previously saved map
    # marker or when a new destination is set before the real BR begins.
    map.call("mark",Vector2(0.0,40.0))
    check((radar.call("landing_waypoint_guidance") as Dictionary).is_empty(),
        "training mode fabricated a Battle Royale landing compass")
    director.begin_aircraft_phase()
    var flight: Node3D=director.get("_flight") as Node3D
    check(director.mode=="aircraft" and
        str(hud.get("air_stage"))=="aircraft" and
        bool(radar.get("_battle_mode")),
        "real aircraft did not expose authoritative map guidance")
    player.set("_yaw",0.0)
    hud.call("_refresh_airdrop_waypoint_guidance")
    var guidance: Dictionary=radar.call("landing_waypoint_guidance")
    check(guidance.has("world") and
        (guidance["world"] as Vector2)==Vector2(0.0,40.0) and
        absf(float(guidance["distance_m"])-36.0)<.1 and
        absf(float(guidance["relative_degrees"]))<.1 and
        hint.text.contains("OBJETIVO 36 m") and
        hint.text.contains("AL FRENTE"),
        "northward target did not derive metres/bearing from real plane")
    # A mark east of a north-facing operator must point RIGHT; a westward
    # mark must point LEFT; neither bearing comes from a fake local map.
    map.call("mark",Vector2(40.0,76.0))
    check(hint.text.contains("A LA DERECHA") and
        absf(float((radar.call("landing_waypoint_guidance") as Dictionary)[
            "relative_degrees"])-90.0)<.1,
        "true east waypoint has incorrect camera-relative direction")
    map.call("mark",Vector2(-40.0,76.0))
    check(hint.text.contains("A LA IZQUIERDA") and
        absf(float((radar.call("landing_waypoint_guidance") as Dictionary)[
            "relative_degrees"])+90.0)<.1,
        "true west waypoint has incorrect camera-relative direction")
    var destination:=Vector2(0.0,40.0)
    map.call("mark",destination)
    check(hint.text.contains("OBJETIVO") and
        (radar.get("_waypoint") as Vector2)==destination,
        "full tactical map and circular radar lost their shared target")
    check((radar.call("aircraft_route_pixels") as PackedVector2Array).size()==2,
        "flight route disappeared after selecting a destination")

    flight.request_jump_or_parachute()
    for i in range(10):
        await process_frame
    check(player.air_mode=="freefall" and
        str(hud.get("air_stage"))=="freefall" and
        hint.text.contains("OBJETIVO") and
        (radar.call("aircraft_route_pixels") as PackedVector2Array).is_empty(),
        "flight waypoint lost guidance after a genuine physical jump")
    # After moving toward the landing point, the readout must change.
    player.global_position=Vector3(0.0,60.0,46.0)
    hud.call("_refresh_airdrop_waypoint_guidance")
    guidance=radar.call("landing_waypoint_guidance")
    check(float(guidance["distance_m"])<7.0 and
        hint.text.contains("DESTINO CERCA"),
        "airborne guidance is a fixed text, not current world position")

    flight.deploy_parachute()
    check(player.air_mode=="parachute" and
        str(hud.get("air_stage"))=="parachute" and
        hint.text.contains("DESTINO CERCA") and
        (radar.get("_waypoint") as Vector2)==destination,
        "real canopy discarded the active target or changed its position")
    map.call("_clear_waypoint")
    check(not (radar.get("_waypoint") as Vector2).is_finite() and
        (radar.call("landing_waypoint_guidance") as Dictionary).is_empty() and
        hint.text.contains("MINIMAPA ACTIVO"),
        "cleared landing target leaves a phantom heading or distance")

    # The same physical transition must still restore fifty fighters.
    var z: float=-20.0
    player.global_position=Vector3(0,terrain.height_at(0,z)+2.8,z)
    player.velocity=Vector3(0,-5,0)
    for i in range(160):
        await physics_frame
        if director.mode=="sector_battle":
            break
    check(director.mode=="sector_battle" and
        combat.active_fighter_count()==50 and
        str(hud.get("air_stage"))=="ground",
        "landing guidance broke physical parachute-to-50-rival transition")
    check((radar.call("landing_waypoint_guidance") as Dictionary).is_empty(),
        "clear waypoint incorrectly revived at match start")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75146_LIVE_LANDING_GUIDANCE PASS real_50_fighters=1 "+
            "world_target=1 camera_bearing=left_right_front "+
            "metres_live=1 air_freefall_canopy=1 clear_no_ghost=1 "+
            "real_touchdown=1 device_test=NO")
    quit(1 if failed else 0)
