extends SceneTree
## V75.157: the actual tactical map must retain truthful, clipped player
## and waypoint edge indicators through pinch/pan on Motorola 964x434.
## No fictional enemy markers or offscreen icon over HUD controls.
const MAP=preload("res://scripts/ui/aurora_tactical_map.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V75157_MAP_EDGE_GUIDANCE "+why)


func _verify() -> void:
    root.size=Vector2i(964,434)
    var phone:=Control.new()
    phone.size=Vector2(964,434)
    root.add_child(phone)
    var tactical: Control=MAP.new()
    phone.add_child(tactical)
    var actor:=CharacterBody3D.new()
    root.add_child(actor)
    tactical.set("player",actor)
    await process_frame
    check(tactical.size.distance_to(phone.size)<1.0,
        "real cartographic overlay failed to fill Motorola reference canvas")
    tactical.set("zoom",8.0)
    tactical.set("pan",Vector2.ZERO)
    var rect: Rect2=tactical.call("_map_rect")
    var safe: Rect2=rect.grow(-14.0)
    var east: Vector2=Vector2(MAP.WORLD_HALF*.8,0.0)
    var west: Vector2=Vector2(-MAP.WORLD_HALF*.8,0.0)
    var north: Vector2=Vector2(0.0,-MAP.WORLD_HALF*.8)
    var south: Vector2=Vector2(0.0,MAP.WORLD_HALF*.8)
    var borders: Array[Vector2]=[east,west,north,south,
        Vector2(MAP.WORLD_HALF*.8,MAP.WORLD_HALF*.8)]
    for coordinate in borders:
        var tip: Dictionary=tactical.call("_edge_map_anchor",coordinate,safe)
        var direction: Vector2=tip.get("direction",Vector2.ZERO)
        var at: Vector2=tip.get("at",Vector2.ZERO)
        check(not tip.is_empty() and not bool(tip.get("inside",true)) and
            safe.has_point(at) and direction.length()>.99 and
            direction.length()<1.01,
            "offscreen physical waypoint has no safely clipped edge arrow")
        var outside: Vector2=tactical.call("project",coordinate)
        check((outside-safe.get_center()).dot(direction)>0.0 and
            at.distance_to(safe.get_center())>20.0,
            "map edge arrow points away from its real-world destination")
    var at_center: Dictionary=tactical.call("_edge_map_anchor",
        Vector2.ZERO,safe)
    check(bool(at_center.get("inside",false)) and
        (at_center.get("at",Vector2.ZERO) as Vector2).distance_to(
            safe.get_center())<.1,
        "on-screen player incorrectly replaced with an edge arrow")

    # A selected waypoint remains in true world-space through zoom and
    # the player can be off-screen instead when panning to destination.
    tactical.set("waypoint",east)
    tactical.queue_redraw()
    await process_frame
    tactical.set("pan",east)
    tactical.call("_clamp_pan_to_terrain")
    var player_edge: Dictionary=tactical.call("_edge_map_anchor",
        Vector2.ZERO,safe)
    check(not bool(player_edge.get("inside",true)) and
        safe.has_point(player_edge.get("at",Vector2.ZERO)),
        "zoom-to-waypoint lost the player's real off-screen reference")
    var destination: Dictionary=tactical.call("_edge_map_anchor",east,safe)
    check(bool(destination.get("inside",false)),
        "world destination is not restored on-screen after pan")

    # Invalid geometry cannot create arrows outside the map or HUD.
    var invalid: Dictionary=tactical.call("_edge_map_anchor",
        Vector2(INF,INF),safe)
    check(invalid.is_empty(),
        "non-finite waypoint created an invalid projected marker")
    var tiny: Dictionary=tactical.call("_edge_map_anchor",
        east,Rect2(Vector2.ZERO,Vector2(8,8)))
    check(tiny.is_empty(),"undersized map invented a callout")
    phone.queue_free()
    actor.queue_free()
    await process_frame
    if not failed:
        print("V75157_MAP_EDGE_GUIDANCE PASS viewport=964x434 "+
            "real_world_edges=5 offscreen_player=1 "+
            "on_screen_waypoint=1 no_offmap_icons=1 invalid_safe=1")
    quit(1 if failed else 0)
