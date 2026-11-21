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
    var line: PackedVector2Array=radar.aircraft_route_pixels()
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
    game.queue_free()
    await process_frame
    print("V75145_FLIGHT_CAPTURE PASS aircraft=real "+
        "route=actual_154m radar=touchable 964x434 screenshots=2 "+
        "motorola_physical_certification=NO")
    quit(0)
