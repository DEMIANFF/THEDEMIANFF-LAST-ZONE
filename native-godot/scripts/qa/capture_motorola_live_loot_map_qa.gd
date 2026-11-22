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
    # Deterministic, physically accessible field loot; avoid the coastal
    # house floor at (12,-12) which blocks line-of-sight collection.
    var at:=Vector2(8.0,-22.0)
    var rival: CharacterBody3D=combat._targets[0]
    rival.global_position=Vector3(at.x,
        terrain.height_at(at.x,at.y)+2.0,at.y)
    rival._magazine=7
    rival._field_medkits=0
    if not rival.take_training_damage(999.0,player):
        _fail("physical rival elimination failed")
        return
    player.global_position=Vector3(at.x,
        terrain.height_at(at.x,at.y)+1.5,at.y+7.0)
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
    # V75.157: two extra pictures show offscreen arrows in the REAL
    # full tactical map, with the player and an existing 3D AWM pickup.
    # This is engine-rendered UI evidence, not an artist's mockup.
    var real_awm: Area3D=map.call("_live_awm_pickup") as Area3D
    if not is_instance_valid(real_awm):
        _fail("real AWM vanished before edge marker capture")
        return
    var target_world:=Vector2(real_awm.global_position.x,
        real_awm.global_position.z)
    var player_world:=Vector2(player.global_position.x,
        player.global_position.z)
    map.call("mark",target_world)
    map.set("zoom",8.0)
    # The stretched canvas may be 1280x720 logical pixels even when the
    # captured phone window is 964x434; add a 15 m margin so the chosen
    # marker is genuinely outside either viewport without losing player.
    var route_axis: Vector2=(target_world-player_world).normalized()
    map.set("pan",player_world-route_axis*15.0)
    map.set("_follow_player",false)
    map.call("_clamp_pan_to_terrain")
    var safe: Rect2=(map.call("_map_rect") as Rect2).grow(-14.0)
    var target_edge: Dictionary=map.call(
        "_edge_map_anchor",target_world,safe)
    if target_edge.is_empty() or bool(target_edge["inside"]):
        _fail("live AWM waypoint did not become a clipped edge direction")
        return
    map.queue_redraw()
    for frame in range(6):
        await process_frame
    await RenderingServer.frame_post_draw
    var target_path: String="res://out/aurora-%s-motorola-waypoint-offscreen.png"%tag
    if root.get_texture().get_image().save_png(target_path)!=OK:
        _fail("could not save offscreen waypoint engine evidence")
        return

    map.set("pan",target_world+route_axis*15.0)
    map.call("_clamp_pan_to_terrain")
    var player_edge: Dictionary=map.call(
        "_edge_map_anchor",player_world,safe)
    if player_edge.is_empty() or bool(player_edge["inside"]):
        _fail("real player did not become an edge marker after map pan")
        return
    map.queue_redraw()
    for frame in range(6):
        await process_frame
    await RenderingServer.frame_post_draw
    var player_path: String="res://out/aurora-%s-motorola-player-offscreen.png"%tag
    if root.get_texture().get_image().save_png(player_path)!=OK:
        _fail("could not save offscreen player engine evidence")
        return
    map.call("_clear_waypoint")
    print("V75157_MAP_EDGE_CAPTURE PASS 964x434 real_awm_mark=1 "+
        "world_position_edge=1 world_player_edge=1 screenshots=2")
    print("V75141_LIVE_LOOT_MAP_CAPTURE PASS 964x434 "+
        "real_awm=1 real_bot_kill=1 real_ammo=7 local_cache=1 "+
        "no_fake_icons=1 file="+path)
    game.queue_free()
    await process_frame
    quit(0)
