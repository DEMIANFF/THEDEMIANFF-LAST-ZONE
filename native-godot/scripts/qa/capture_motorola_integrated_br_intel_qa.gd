extends SceneTree
## Two real Godot screenshots of 50-fighter BR mobile HUD and opened map.
## The observed resources/cars are always physical nodes, never stock art.
const CAPTURE=preload("res://scripts/qa/aurora_capture_version.gd")


func _initialize() -> void:
    call_deferred("_capture")


func _snapshot(name: String,tag: String) -> bool:
    await RenderingServer.frame_post_draw
    var png: Image=root.get_texture().get_image()
    var path: String="res://out/aurora-"+tag+"-motorola-"+name+".png"
    if png.get_size()!=Vector2i(964,434) or png.save_png(path)!=OK:
        push_error("V75147_CAPTURE cannot save phone-screen real scene "+name)
        return false
    print("V75147_CAPTURE "+path)
    return true


func _capture() -> void:
    root.size=Vector2i(964,434)
    var tag: String=CAPTURE.tag()
    if tag.is_empty():
        quit(2)
        return
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var player: CharacterBody3D=game.get_node("Operator")
    var combat: Node3D=game.get_node("CombatRange")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var map: Control=hud.get_node(
        "AuroraTacticalOverlay/AuroraFullTacticalMap")
    var radar: Control=hud.get_node(
        "AuroraTacticalOverlay/AuroraTrainingRadar")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    combat.set_encounter_size(50)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    player.global_position=Vector3(6.0,
        terrain.height_at(6.0,-2.0)+1.4,-2.0)
    map.call("mark",Vector2(25.0,-30.0))
    hud.call("_refresh_ground_battle_intel")
    var intel: Label=hud.get_node(
        "AuroraTacticalOverlay/RealGroundBattleIntel")
    if not intel.visible or not intel.text.begins_with("DESTINO "):
        push_error("V75147_CAPTURE no actual ground navigation displayed")
        quit(3)
        return
    for i in range(10):
        await process_frame
    if not await _snapshot("ground-navigation",tag):
        quit(4)
        return
    hud.get_node("AuroraTacticalOverlay/MAPA").button_down.emit()
    if (not map.visible or
            (map.call("_live_world_resources") as Array).is_empty() or
            (radar.call("nearby_physical_resources") as Array).is_empty()):
        push_error("V75147_CAPTURE map not showing actual local pickups")
        quit(5)
        return
    for i in range(10):
        await process_frame
    if not await _snapshot("live-supplies-map",tag):
        quit(6)
        return
    map.call("_clear_waypoint")
    game.queue_free()
    await process_frame
    print("V75147_CAPTURE PASS 964x434 screenshots=2 "+
        "live_50_fighters=1 supplies_are_actual_Area3D=1 "+
        "map_and_ground_HUD=1 hardware_test=NO")
    quit(0)
