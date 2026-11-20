extends SceneTree
## Native Godot 964x434 visual fixtures for live physical-zone cartography.
## Xvfb desktop rendering is NOT a physical Motorola Vulkan certification.
const CAPTURE_VERSION=preload("res://scripts/qa/aurora_capture_version.gd")
const SECTOR=preload("res://scripts/match/sector_director.gd")


func _initialize() -> void:
    call_deferred("_capture")


func _save(stage: String,tag: String) -> bool:
    await RenderingServer.frame_post_draw
    var image: Image=root.get_texture().get_image()
    if image.get_size()!=Vector2i(964,434):
        push_error("ZONE_MAP_CAPTURE phone viewport is not 964x434")
        return false
    var path: String="res://out/aurora-"+tag+"-motorola-"+stage+".png"
    if image.save_png(path)!=OK:
        push_error("ZONE_MAP_CAPTURE cannot save "+path)
        return false
    print("ZONE_MAP_CAPTURE ",stage," ",path)
    return true


func _capture() -> void:
    root.size=Vector2i(964,434)
    var tag: String=CAPTURE_VERSION.tag()
    if tag.is_empty():
        quit(2)
        return
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get_node("Operator")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var radar: Control=hud.get_node(
        "AuroraTacticalOverlay/AuroraTrainingRadar")
    var map: Control=hud.get_node(
        "AuroraTacticalOverlay/AuroraFullTacticalMap")
    for rival in game.get_node("CombatRange")._targets:
        rival.set_physics_process(false)
    player.set_physics_process(false)
    # A static screenshot fixture, not a mock damage simulation or new match.
    # Read the exact constants used by the live sector director.
    director.set_process(false)
    director.set("mode","sector_battle")
    director.set("match_ended",false)
    director.set("zone_phase",0)
    director.set("zone_center",SECTOR.CENTER)
    director.set("radius",SECTOR.INITIAL_RADIUS)
    var centres: Array[Vector2]=[
        SECTOR.CENTER,SECTOR.CENTER+Vector2(12,8),
        SECTOR.CENTER+Vector2(20,12),SECTOR.CENTER+Vector2(25,17),
        SECTOR.CENTER+Vector2(30,20)]
    director.set("_phase_centers",centres)
    hud.set_radar_battle_mode(true)
    hud.set_sector_zone(SECTOR.CENTER,SECTOR.INITIAL_RADIUS)
    hud.set_next_sector_zone(centres[1],SECTOR.PHASE_RADII[1])
    for frame in range(8):
        await process_frame
    if not await _save("minimap-zones",tag):
        quit(3)
        return
    map.visible=true
    map.queue_redraw()
    for frame in range(8):
        await process_frame
    if not await _save("tactical-zones",tag):
        quit(4)
        return
    var coverage: Dictionary=radar.call("ring_coverage")
    if float(coverage["current"])>1.0 or float(coverage["next"])>1.0:
        push_error("ZONE_MAP_CAPTURE clipping mismatches safe-zone circles")
        quit(5)
        return
    game.queue_free()
    for frame in range(8):
        await process_frame
    print("ZONE_MAP_CAPTURE PASS 964x434 minimap=tactical "+
        "actual_zone_radii=245,185 hardware_test=NO")
    quit(0)
