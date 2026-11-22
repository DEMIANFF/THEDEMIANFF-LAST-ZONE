extends SceneTree
## V75.158: validate the REAL player's camera-up minimap, not an artist
## mockup. Movement RIGHT must shift terrain LEFT while the player stays
## centered. Physics camera yaw, loot, aircraft and world-zone sources share
## one consistent X/Z projection in the 964x434 mobile game.
const SECTOR=preload("res://scripts/match/sector_director.gd")
const RADAR=preload("res://scripts/ui/aurora_training_radar.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V75158_MINIMAP_PRECISION "+why)


func _verify() -> void:
    root.size=Vector2i(964,434)
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get_node("Operator")
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var radar: Control=game.get_node(
        "TrainingHUD/AuroraTacticalOverlay/AuroraTrainingRadar")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    var origin:=Vector2(8.0,-22.0)
    player.global_position=Vector3(origin.x,
        terrain.height_at(origin.x,origin.y)+1.5,origin.y)
    player.velocity=Vector3.ZERO
    player.set("_yaw",0.0)
    player.set("_desired_yaw",0.0)
    radar.set("rotate_with_camera",true)
    check(radar.get("player")==player,
        "actual Main.tscn radar is not attached to the playable operator")
    var center: Vector2=radar.call("_radar_center")
    var radius: float=radar.call("_radar_radius")
    var range_m: float=radar.call("_detail_range")
    check(center.distance_to(radar.size*.5)<.01 and
        is_equal_approx(range_m,RADAR.GROUND_DETAIL_METRES),
        "player arrow is offset or combat radar is not local detail")

    # A north-looking camera sees true east on the RIGHT and north ABOVE.
    var east: Vector2=radar.call("_world_to_radar",
        origin+Vector2(20.0,0.0),center,radius,range_m)
    var west: Vector2=radar.call("_world_to_radar",
        origin+Vector2(-20.0,0.0),center,radius,range_m)
    var north: Vector2=radar.call("_world_to_radar",
        origin+Vector2(0.0,-20.0),center,radius,range_m)
    check(east.x>center.x+10.0 and west.x<center.x-10.0 and
        absf(east.y-center.y)<.01 and north.y<center.y-10.0,
        "world right/left/north are mirrored on north-facing minimap")

    var listener: Vector2=radar.call("_world_to_radar",
        origin,center,radius,range_m)
    check(listener.distance_to(center)<.001,
        "real player did not stay at actual centre")
    for yaw in [0.0,PI*.5,-PI*.5,PI]:
        player.set("_yaw",yaw)
        var forward: Vector2=Vector2(-sin(yaw),-cos(yaw))
        var forward_pixel: Vector2=radar.call("_world_to_radar",
            origin+forward*22.0,center,radius,range_m)
        check(forward_pixel.y<center.y-12.0 and
            absf(forward_pixel.x-center.x)<.01,
            "Godot camera forward did not stay at minimap TOP")
        var right: Vector2=Vector2(cos(yaw),-sin(yaw))
        var right_pixel: Vector2=radar.call("_world_to_radar",
            origin+right*22.0,center,radius,range_m)
        check(right_pixel.x>center.x+12.0 and
            absf(right_pixel.y-center.y)<.01,
            "camera-relative right projects to the wrong minimap side")
        var roundtrip: Vector2=radar.call("_radar_to_world",
            right_pixel,center,radius,range_m)
        check(roundtrip.distance_to(origin+right*22.0)<.015,
            "world-to-minimap-to-world accumulated location error")
        var arrow: Vector2=radar.call("_player_screen_forward")
        check(arrow.distance_to(Vector2.UP)<.01,
            "camera-up player pointer is not pointing toward real view")

    # Explicit north-up option: no camera rotation of static world
    # landmarks, but the player arrow still shows real facing.
    radar.set("rotate_with_camera",false)
    player.set("_yaw",-PI*.5)
    var fixed_east: Vector2=radar.call("_world_to_radar",
        origin+Vector2(20,0),center,radius,range_m)
    var fixed_heading: Vector2=radar.call("_player_screen_forward")
    check(fixed_east.x>center.x+10.0 and
        fixed_heading.distance_to(Vector2.RIGHT)<.01,
        "north-up map ignored player heading or rotated world incorrectly")
    radar.set("rotate_with_camera",true)
    player.set("_yaw",0.0)
    player.set("_desired_yaw",0.0)

    # A safe zone of 245m must not shrink 80m neighbourhood navigation
    # or make 5m of actual movement imperceptible.
    radar.set_zone(SECTOR.CENTER,SECTOR.INITIAL_RADIUS)
    radar.set_next_zone(Vector2(35,20),185.0)
    check(is_equal_approx(float(radar.call("_detail_range")),
        RADAR.GROUND_DETAIL_METRES),
        "far-away zone radius falsely zoomed the local player's map")
    var zone_coverage: Dictionary=radar.call("ring_coverage")
    check(float(zone_coverage.get("current",2.0))<=1.0 and
        float(zone_coverage.get("next",2.0))<=1.0,
        "legacy full-ring overview diagnostic was discarded")
    player.set("air_mode","parachute")
    check(is_equal_approx(float(radar.call("_detail_range")),
        RADAR.CANOPY_DETAIL_METRES),
        "parachute minimap lost airborne landing context")
    player.set("air_mode","aircraft")
    check(is_equal_approx(float(radar.call("_detail_range")),
        RADAR.AIRCRAFT_DETAIL_METRES),
        "aircraft minimap lost larger genuine route view")
    player.set("air_mode","ground")

    # ACTUAL mobile joystick and CharacterBody3D movement, not a manual
    # translation of map decoration; physics collision remains engaged.
    player.set_physics_process(true)
    player.set_touch_move_axis(Vector2.RIGHT)
    for frame in range(24):
        await physics_frame
    player.set_touch_move_axis(Vector2.ZERO)
    player.set_physics_process(false)
    var moved:=Vector2(player.global_position.x,player.global_position.z)
    check(moved.x>origin.x+.30 and
        absf(moved.y-origin.y)<1.25,
        "physical right-stick movement did not move Lila toward +world X")
    var old_landmark: Vector2=radar.call("_world_to_radar",
        origin,center,radius,range_m)
    var current_player: Vector2=radar.call("_world_to_radar",
        moved,center,radius,range_m)
    check(old_landmark.x<center.x-.2 and
        current_player.distance_to(center)<.01,
        "moving RIGHT did not scroll island LEFT with player centered")

    # Redraw on yaw/movement rather than waiting 200ms for a slow scan.
    radar.set("_tick",0.05)
    radar.set("_last_radar_position",origin)
    radar.set("_last_radar_yaw",0.0)
    radar.call("_process",0.0)
    check(float(radar.get("_tick"))<.001,
        "moving radar still waits for 5Hz repaint after camera/player move")
    check(radar.has_method("_draw_zone_in_local_disc") and
        radar.has_method("_draw_navigation_compass"),
        "zone rings/compass not integrated into real draw path")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75158_MINIMAP_PRECISION PASS 964x434 real_joystick_right=1 "+
            "player_center=1 camera_yaw_4=1 world_roundtrip=1 "+
            "north_up=1 local_80m=1 zone_245m_stable=1 "+
            "air_range=145 canopy_range=110 compass=1 motion_redraw=1")
    quit(1 if failed else 0)
