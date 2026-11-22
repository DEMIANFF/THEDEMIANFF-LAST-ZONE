extends SceneTree
## V75.156: mobile 964x434 pinch and pointer zoom must keep the map
## location under the gesture, without snapping back to player-follow.
## Tests the live AuroraFullTacticalMap control, not a mock texture.
const MAP=preload("res://scripts/ui/aurora_tactical_map.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V75156_PINCH_ANCHOR "+why)


func _touch(index: int,at: Vector2,pressed: bool) -> InputEventScreenTouch:
    var event:=InputEventScreenTouch.new()
    event.index=index
    event.position=at
    event.pressed=pressed
    return event


func _verify() -> void:
    root.size=Vector2i(964,434)
    var tactical: Control=MAP.new()
    root.add_child(tactical)
    await process_frame
    check(tactical.size==Vector2(964,434),
        "real tactical map did not occupy the Motorola viewport")
    tactical.set("zoom",2.0)
    tactical.set("pan",Vector2.ZERO)
    tactical.set("_follow_player",true)
    var canvas_rect: Rect2=tactical.call("_map_rect")
    var center: Vector2=canvas_rect.get_center()
    var pointer: Vector2=center+Vector2(55,-23)
    var before: Vector2=tactical.call("unproject",pointer)
    tactical.call("_zoom_at_point",1.35,pointer)
    var after: Vector2=tactical.call("unproject",pointer)
    check(after.distance_to(before)<.05 and
        not bool(tactical.get("_follow_player")),
        "exploratory zoom jumped the selected world position or kept follow")
    check(absf(float(tactical.get("zoom"))-2.7)<.01,
        "pointer zoom did not update the live map scale")

    # The toolbar zoom has a separate contract: SEGUIR remains active.
    tactical.set("_follow_player",true)
    tactical.call("_zoom_at",.9)
    check(bool(tactical.get("_follow_player")),
        "toolbar zoom unexpectedly disabled SEGUIR")

    # Pinch moves the midpoint and zooms simultaneously. No finger-up
    # may place a waypoint; that would persist a spurious map marker.
    tactical.set("zoom",2.0)
    tactical.set("pan",Vector2.ZERO)
    tactical.set("_follow_player",true)
    tactical.set("waypoint",Vector2(INF,INF))
    var a: Vector2=center+Vector2(-40,0)
    var b: Vector2=center+Vector2(40,0)
    tactical.call("_gui_input",_touch(0,a,true))
    tactical.call("_gui_input",_touch(1,b,true))
    var drag:=InputEventScreenDrag.new()
    drag.index=0
    drag.position=a+Vector2(-12,4)
    drag.relative=Vector2(-12,4)
    tactical.call("_gui_input",drag)
    check(float(tactical.get("zoom"))>2.0 and
        not bool(tactical.get("_follow_player")),
        "physical two-finger zoom snapped to player or ignored the scale")
    tactical.call("_gui_input",_touch(0,drag.position,false))
    tactical.call("_gui_input",_touch(1,b,false))
    var untouched_waypoint: Vector2=tactical.get("waypoint")
    var touches: Dictionary=tactical.get("_touches")
    check(not untouched_waypoint.is_finite() and touches.is_empty(),
        "pinch release placed an unwanted marker or left touches captured")

    # Interrupt a physical touch by closing the tactical overlay.
    # A new map opening must not inherit ghost touch indices.
    tactical.call("_gui_input",_touch(0,center,true))
    var active: Dictionary=tactical.get("_touches")
    check(active.size()==1,
        "the native map never began the new one-finger gesture")
    tactical.visible=false
    await process_frame
    var released: Dictionary=tactical.get("_touches")
    check(released.is_empty() and int(tactical.get("_drag_touch"))==-1,
        "closing map retained a captured touch and corrupted reopening")
    tactical.visible=true
    await process_frame

    # At whole-island zoom no pan may expose repeated terrain tiles.
    tactical.set("zoom",1.0)
    tactical.set("pan",Vector2(32,20))
    tactical.call("_zoom_at_point",.75,pointer)
    var pan: Vector2=tactical.get("pan")
    check(float(tactical.get("zoom"))==1.0 and pan.length()<.01,
        "the clamped whole-island overview leaked outside terrain")
    tactical.queue_free()
    await process_frame
    if not failed:
        print("V75156_PINCH_ANCHOR PASS viewport=964x434 "+
            "pinch_anchor=stable follow=manual toolbar_follow=preserved "+
            "unwanted_waypoint=0 whole_island_clamped=1")
    quit(1 if failed else 0)
