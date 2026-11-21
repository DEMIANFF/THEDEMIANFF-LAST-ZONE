extends SceneTree
## V75.145: actual Main scene flight -> interactive tactical map ->
## physical freefall -> actual parachute -> grounded 50-person battle.
## An aircraft screenshot is not evidence that controls/routes work.
const AIRDROP=preload("res://scripts/match/airdrop_sequence.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V75145_AIRCRAFT_LIVE_MAP "+why)


func _verify() -> void:
    root.size=Vector2i(964,434)
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var player: CharacterBody3D=game.get_node("Operator")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var radar: Control=hud.get_node(
        "AuroraTacticalOverlay/AuroraTrainingRadar")
    var button: Button=hud.get_node("AuroraTacticalOverlay/MAPA")
    var map: Control=hud.get_node(
        "AuroraTacticalOverlay/AuroraFullTacticalMap")
    await physics_frame
    director.begin_aircraft_phase()
    var flight: Node3D=director.get("_flight")
    check(director.mode=="aircraft" and
        str(flight.get("phase"))=="aircraft" and
        player.air_mode=="aircraft",
        "real aircraft did not begin in physical Main scene")
    # The built-in Aurora transport is a real moving mesh, not a static
    # concept image or a six-blade propeller orbiting the entire airframe.
    var aircraft: Node3D=player.get_node("AuroraTransportAircraft")
    check(aircraft!=null and aircraft.top_level,
        "flying transport mesh is not present in the live scene")
    var imported: Node3D=aircraft.get_node_or_null("AuroraC17UserVisual")
    for sign in [-1,1]:
        var side: float=float(sign)
        for blade in range(3):
            var rotor: MeshInstance3D=aircraft.get_node_or_null(
                "AuroraPropeller%d_%d"%[sign,blade]) as MeshInstance3D
            check(rotor!=null and rotor.mesh is ArrayMesh and
                rotor.position.distance_to(
                    Vector3(side*2.03,-.31,-1.14))<.002,
                "fallback rotor is not mounted on its engine hub")
            if rotor!=null and imported==null:
                var angle_before: float=rotor.rotation.z
                flight.call("_advance_visible_propellers",.1)
                check(absf(rotor.rotation.z-angle_before)>.3,
                    "aircraft propeller is visibly static during flight")
    for name in ["AuroraPortNavigation","AuroraStarboardNavigation",
            "AuroraTailNavigation"]:
        var nav_light: MeshInstance3D=aircraft.get_node_or_null(
            name) as MeshInstance3D
        check(nav_light!=null and
            nav_light.material_override is StandardMaterial3D and
            (nav_light.material_override as StandardMaterial3D).emission_enabled,
            "missing cheap emissive navigation light "+name)
    check(str(hud.get("air_stage"))=="aircraft" and radar.visible and
        button.visible and not button.disabled and button.text=="",
        "in-air minimap remains hidden or has a separate MAPA label")
    var radar_bounds: Rect2=radar.get_global_rect()
    var touch_bounds: Rect2=button.get_global_rect()
    check(radar_bounds.grow(1.5).encloses(touch_bounds) and
        touch_bounds.grow(1.5).encloses(radar_bounds),
        "flight map hitbox does not match the displayed radar")
    check(not (hud.get("_reticle") as Control).visible and
        not hud.get_node("AuroraTacticalOverlay/MovePad").visible,
        "combat fire/movement controls obscure the aircraft map")
    var route: PackedVector2Array=(radar.call("aircraft_route_pixels") as PackedVector2Array)
    check(route.size()==2 and route[0].distance_to(route[1])>10.0 and
        AIRDROP.ROUTE_START_Z==76.0 and AIRDROP.ROUTE_END_Z==-78.0,
        "minimap route does not use the actual aircraft segment")
    check(str((hud.get("_battle_status") as Label).text).contains("SALTO EN 13s") and
        str((hud.get("_hint") as Label).text).contains("MINIMAPA"),
        "flight HUD lacks real timed deployment and map guidance")

    # The player uses the SAME radar touch target and tactical map;
    # flight phase does not replace it with a separate static screenshot.
    button.button_down.emit()
    check(map.visible and map.get("director")==director and
        map.get("player")==player and map.get("terrain")==terrain,
        "tapping flight radar failed to open authoritative map")
    var destination:=Vector2(26.0,-18.0)
    map.call("mark",destination)
    check((map.get("waypoint") as Vector2).distance_to(destination)<.01,
        "no real world landing waypoint selected on map")
    var map_route_start: Vector2=map.call(
        "project",Vector2(0,AIRDROP.ROUTE_START_Z))
    var map_route_end: Vector2=map.call(
        "project",Vector2(0,AIRDROP.ROUTE_END_Z))
    check(map_route_start.distance_to(map_route_end)>5.0,
        "large map lost aircraft deployment route")
    map.get_node("MapActions/MapAction0").pressed.emit()
    check(not map.visible,
        "route planning cannot return to real aircraft cockpit")

    for i in range(12):
        await physics_frame
    check(float(flight.get("elapsed"))>0.0 and
        str((hud.get("_battle_status") as Label).text).contains("SALTO EN") and
        (radar.call("aircraft_route_pixels") as PackedVector2Array).size()==2,
        "moving aircraft does not update real route / countdown")
    flight.request_jump_or_parachute()
    for i in range(8):
        await process_frame
    check(player.air_mode=="freefall" and str(hud.get("air_stage"))=="freefall" and
        radar.visible and button.visible and not button.disabled and
        (radar.call("aircraft_route_pixels") as PackedVector2Array).is_empty(),
        "actual freefall lost map access or retained fake aircraft line")
    check(hud.get_node("AuroraTacticalOverlay/MovePad").visible,
        "freefall has no steering joystick")
    button.button_down.emit()
    check(map.visible and (map.get("waypoint") as Vector2)==destination,
        "physical jump destroyed marked landing waypoint")
    map.get_node("MapActions/MapAction0").pressed.emit()

    flight.deploy_parachute()
    check(player.air_mode=="parachute" and
        str(hud.get("air_stage"))=="parachute" and radar.visible and
        not button.disabled,
        "real parachute phase hid the tactical minimap")
    # Same real collision-based landing technique as V75.16 QA.
    var z: float=-20.0
    player.global_position=Vector3(0,terrain.height_at(0,z)+2.8,z)
    player.velocity=Vector3(0,-5,0)
    for i in range(160):
        await physics_frame
        if director.mode=="sector_battle":
            break
    check(director.mode=="sector_battle" and
        player.air_mode=="ground" and str(hud.get("air_stage"))=="ground" and
        combat.active_fighter_count()==50,
        "minimap flight integration broke real landing or 50-person BR")
    check(radar.visible and button.visible and not button.disabled and
        (radar.call("aircraft_route_pixels") as PackedVector2Array).is_empty(),
        "landed battle lost map or still paints aircraft route")
    button.button_down.emit()
    check(map.visible and map.get("director")==director and
        (map.get("waypoint") as Vector2)==destination,
        "map touch/waypoint did not survive full flight-to-combat loop")
    map.get_node("MapActions/MapAction0").pressed.emit()
    game.queue_free()
    await process_frame
    if not failed:
        print("V75145_AIRCRAFT_LIVE_MAP PASS viewport=964x434 "+
            "original_terrain=1 flight_route=154m flight_timer=13s "+
            "touch_map=1 saved_waypoint=1 real_freefall=1 "+
            "real_canopy=1 real_touchdown=1 roster=50 no_extra_map_button=1")
    quit(1 if failed else 0)
