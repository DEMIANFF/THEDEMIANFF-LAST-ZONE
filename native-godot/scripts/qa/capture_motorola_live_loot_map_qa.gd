extends SceneTree
## 964x434 live Godot screenshot: physical AWM still on plaza and one
## actual seven-round rival cache visible on the tactical map.
## Desktop software OpenGL evidence; NOT physical Motorola Vulkan testing.
const CAPTURE_VERSION=preload("res://scripts/qa/aurora_capture_version.gd")


func _initialize() -> void:
    call_deferred("_capture")


func _fail(reason: String) -> void:
    push_error("V75141_LIVE_LOOT_MAP_CAPTURE "+reason)
    quit(1)


func _capture() -> void:
    root.size=Vector2i(964,434)
    var tag: String=CAPTURE_VERSION.tag()
    if tag.is_empty():
        _fail("missing preview version tag")
        return
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var player: CharacterBody3D=game.get_node("Operator")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var map: Control=game.get_node(
        "TrainingHUD/AuroraTacticalOverlay/AuroraFullTacticalMap")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    var at:=Vector2(12.0,-12.0)
    var rival: CharacterBody3D=combat._targets[0]
    rival.global_position=Vector3(at.x,
        terrain.height_at(at.x,at.y)+2.0,at.y)
    rival._magazine=7
    rival._field_medkits=0
    if not rival.take_training_damage(999.0,player):
        _fail("physical rival elimination failed")
        return
    player.global_position=Vector3(12.0,
        terrain.height_at(12.0,-12.0)+1.5,-5.0)
    map.set("_follow_player",false)
    map.set("zoom",2.0)
    map.set("pan",Vector2(8,6))
    map.visible=true
    if map.call("_live_awm_pickup")==null or (
            (map.call("_live_local_cache_markers") as Array).size()!=1):
        _fail("map has no actual AWM or nearby physical enemy cache")
        return
    map.queue_redraw()
    for frame in range(14):
        await process_frame
    await RenderingServer.frame_post_draw
    var image: Image=root.get_texture().get_image()
    if image.get_size()!=Vector2i(964,434):
        _fail("actual render not 964x434")
        return
    var path: String="res://out/aurora-"+tag+"-motorola-live-loot-map.png"
    if image.save_png(path)!=OK:
        _fail("could not save actual engine screenshot")
        return
    print("V75141_LIVE_LOOT_MAP_CAPTURE PASS 964x434 "+
        "real_awm=1 real_bot_kill=1 real_ammo=7 local_cache=1 "+
        "no_fake_icons=1 file="+path)
    game.queue_free()
    await process_frame
    quit(0)
