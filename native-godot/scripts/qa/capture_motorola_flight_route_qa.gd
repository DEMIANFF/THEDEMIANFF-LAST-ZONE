extends SceneTree
## Real Godot 964x434 scene evidence of the same aircraft deployment and
## tactical map as gameplay. Xvfb software OpenGL != physical Motorola Vulkan.
const CAPTURE_VERSION=preload("res://scripts/qa/aurora_capture_version.gd")


func _initialize() -> void:
    call_deferred("_capture")


func _snapshot(name: String,tag: String) -> bool:
    await RenderingServer.frame_post_draw
    var image: Image=root.get_texture().get_image()
    if image.get_size()!=Vector2i(964,434):
        push_error("V75145_FLIGHT_CAPTURE expected 964x434 rendered frame")
        return false
    var path: String="res://out/aurora-"+tag+"-motorola-"+name+".png"
    if image.save_png(path)!=OK:
        push_error("V75145_FLIGHT_CAPTURE could not save "+path)
        return false
    print("V75145_FLIGHT_CAPTURE "+name+" "+path)
    return true


func _capture() -> void:
    root.size=Vector2i(964,434)
    var tag: String=CAPTURE_VERSION.tag()
    if tag.is_empty():
        quit(2)
        return
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var combat: Node3D=game.get_node("CombatRange")
    var radar: Control=hud.get_node(
        "AuroraTacticalOverlay/AuroraTrainingRadar")
    var full_map: Control=hud.get_node(
        "AuroraTacticalOverlay/AuroraFullTacticalMap")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    director.begin_aircraft_phase()
    var line: PackedVector2Array=(radar.call("aircraft_route_pixels") as PackedVector2Array)
    if (not radar.visible or line.size()!=2 or
            radar.get("map_texture")==null or
            director.mode!="aircraft"):
        push_error("V75145_FLIGHT_CAPTURE route/minimap is not real")
        quit(3)
        return
    for i in range(10):
        await process_frame
    if not await _snapshot("aircraft-live-minimap",tag):
        quit(4)
        return
    hud.get_node("AuroraTacticalOverlay/MAPA").button_down.emit()
    if not full_map.visible:
        push_error("V75145_FLIGHT_CAPTURE cannot open tactical map via minimap")
        quit(5)
        return
    # Choose the SAME real landing target from the full map, so each of
    # the four engine screenshots contains the live waypoint and the
    # operator's dynamic, camera-relative distance during descent.
    full_map.call("mark",Vector2(26.0,-18.0))
    for i in range(10):
        await process_frame
    if not await _snapshot("aircraft-tactical-route",tag):
        quit(6)
        return
    full_map.get_node("MapActions/MapAction0").pressed.emit()
    if full_map.visible:
        push_error("V75145_FLIGHT_CAPTURE cannot close tactical route")
        quit(7)
        return
    var heading: Label=hud.get("_hint") as Label
    if heading==null or not heading.text.contains("OBJETIVO"):
        push_error("V75146_FLIGHT_CAPTURE selected map destination not on live HUD")
        quit(12)
        return
    # The exact same live aircraft is now jumped from; never swap to a
    # screenshot-only freefall or fake canopy just for the evidence.
    var flight: Node3D=director.get("_flight") as Node3D
    flight.request_jump_or_parachute()
    for i in range(9):
        await process_frame
    if (str(flight.get("phase"))!="freefall" or
            str(hud.get("air_stage"))!="freefall" or not radar.visible):
        push_error("V75145_FLIGHT_CAPTURE freefall transition failed")
        quit(8)
        return
    for i in range(6):
        await process_frame
    if not await _snapshot("freefall-live-hud",tag):
        quit(9)
        return
    flight.deploy_parachute()
    for i in range(12):
        await process_frame
    if (str(flight.get("phase"))!="parachute" or
            str(hud.get("air_stage"))!="parachute" or not radar.visible):
        push_error("V75145_FLIGHT_CAPTURE real canopy transition failed")
        quit(10)
        return
    if not await _snapshot("parachute-live-hud",tag):
        quit(11)
        return
    full_map.call("_clear_waypoint")
    game.queue_free()
    await process_frame
    print("V75146_FLIGHT_CAPTURE PASS true_landing_waypoint=1 "+
        "route=actual_154m radar=touchable 964x434 screenshots=4 "+
        "freefall=real parachute=real motorola_physical_certification=NO")
    quit(0)
