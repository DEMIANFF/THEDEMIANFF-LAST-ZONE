extends SceneTree
## Visible evidence of the ACTUAL Main.tscn and original physical
## Puerto Aurora roofs/roads/cargo, NOT manufactured third-party map art.
## Xvfb 964x434 desktop OpenGL captures; Motorola Vulkan still needs trial.
const CAPTURE_VERSION=preload("res://scripts/qa/aurora_capture_version.gd")
const COMBAT=preload("res://scripts/combat/training_combat.gd")
const TACTICAL_MAP=preload("res://scripts/ui/aurora_tactical_map.gd")


func _initialize() -> void:
    call_deferred("_capture")


func frames(n: int) -> void:
    for i in range(n):
        await process_frame


func _fail(why: String) -> void:
    push_error("V75160_LIVE_MAP_CAPTURE "+why)
    quit(1)


func _save(stage: String,tag: String) -> bool:
    await RenderingServer.frame_post_draw
    var image: Image=root.get_texture().get_image()
    if image.get_size()!=Vector2i(964,434):
        push_error("V75160_LIVE_MAP_CAPTURE incorrect physical screenshot resolution")
        return false
    var path: String="res://out/aurora-%s-motorola-%s.png"%[tag,stage]
    if image.save_png(path)!=OK:
        push_error("V75160_LIVE_MAP_CAPTURE image saving failed "+stage)
        return false
    print("V75160_LIVE_MAP_CAPTURE ",path)
    return true


func _capture() -> void:
    root.size=Vector2i(964,434)
    var tag: String=CAPTURE_VERSION.tag()
    if tag.is_empty():
        _fail("export version metadata missing")
        return
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var player: CharacterBody3D=game.get_node("Operator")
    var world: StaticBody3D=game.get_node("AuroraTerrain")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var map: Control=hud.get_node(
        "AuroraTacticalOverlay/AuroraFullTacticalMap")
    var radar: Control=hud.get_node(
        "AuroraTacticalOverlay/AuroraTrainingRadar")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    combat.set_encounter_size(COMBAT.CLASSIC_BR_PARTICIPANTS)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    player.set_physics_process(false)
    if combat._targets.size()!=49:
        _fail("the real fifty-person Battle Royale match was replaced")
        return
    var at:=Vector2(18.0,31.0)
    player.global_position=Vector3(
        at.x,world.height_at(at.x,at.y)+1.25,at.y)
    player.velocity=Vector3.ZERO
    player.set("_yaw",0.0)
    player.set("_desired_yaw",0.0)
    map.visible=false
    radar.visible=true
    radar.queue_redraw()
    await frames(12)
    var mini_ok: bool=await _save("detailed-roof-minimap",tag)
    if not mini_ok:
        _fail("could not capture playable real minimap")
        return
    map.set("zoom",2.4)
    map.visible=true
    map.call("_follow")
    map.queue_redraw()
    await frames(12)
    if (TACTICAL_MAP.MAP_SAMPLES!=512 or
            not (map.get("_terrain_texture") is ImageTexture)):
        _fail("the actual physical map texture was not built")
        return
    var local_ok: bool=await _save("right-side-urban-map",tag)
    if not local_ok:
        _fail("cannot capture right-side street-level cartography")
        return
    map.set("zoom",1.0)
    map.call("_clamp_pan_to_terrain")
    map.queue_redraw()
    await frames(12)
    var island_ok: bool=await _save("full-island-overview",tag)
    if not island_ok:
        _fail("cannot capture original island overview")
        return
    game.queue_free()
    await process_frame
    print("V75160_LIVE_MAP_CAPTURE PASS 964x434 original_world=1 "+
        "50_fighters=1 512px_roof_texture=1 right_side_map=1 "+
        "overview_zoom=1 screenshots=3 android_device_test=NO")
    quit(0)
