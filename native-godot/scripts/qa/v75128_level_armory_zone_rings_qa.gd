extends SceneTree
## V75.128: level original showroom GLBs and true mobile safe-zone rings.
const CATALOG=preload("res://scripts/combat/aurora_weapon_catalog.gd")
const SECTOR=preload("res://scripts/match/sector_director.gd")
const ISLAND=preload("res://scripts/world/island_terrain.gd")
var failed: bool=false


func check(value: bool,message: String) -> void:
    if not value:
        failed=true
        push_error("V75128_LEVEL_ARMORY_ZONE "+message)


func _initialize() -> void:
    call_deferred("_verify")


func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var radar: Control=hud.get_node("AuroraTacticalOverlay/AuroraTrainingRadar")
    var tactical: Control=hud.get_node("AuroraTacticalOverlay/AuroraFullTacticalMap")
    var player: CharacterBody3D=game.get_node("Operator")
    for enemy in game.get_node("CombatRange")._targets:
        enemy.set_physics_process(false)
    await process_frame

    # Both complete circles must remain inside the mobile radar when the
    # authoritative starting radius is larger than its old 130 m viewport.
    radar.call("set_zone",SECTOR.CENTER,SECTOR.INITIAL_RADIUS)
    radar.call("set_next_zone",Vector2(12.0,-6.0),185.0)
    var zone_label: Label=radar.get("_zone_label") as Label
    check(zone_label!=null and zone_label.text.contains("245") and
        zone_label.text.contains("185"),
        "minimap does not distinguish actual current/planned zone radii")
    var coverage: Dictionary=radar.call("ring_coverage")
    check(float(coverage["current"])<=0.915 and
        float(coverage["next"])<=0.915,
        "current/future 245m rings still spill outside minimap")
    # A moving phase can place both ring centres far from the player:
    # inspect the dynamic, off-centre fit instead of only the initial stage.
    var actor_world: Vector2=Vector2(player.global_position.x,
        player.global_position.z)
    radar.call("set_zone",actor_world+Vector2(140,-85),120.0)
    radar.call("set_next_zone",actor_world+Vector2(175,-50),60.0)
    var shifted: Dictionary=radar.call("ring_coverage")
    check(float(shifted["current"])<=0.915 and
        float(shifted["next"])<=0.915 and
        float(shifted["current"])>.70,
        "off-centre shrinking zone is cropped or scales against stale 130m")
    radar.call("set_zone",SECTOR.CENTER,SECTOR.INITIAL_RADIUS)
    radar.call("set_next_zone",Vector2(12.0,-6.0),185.0)
    check(tactical.has_method("_draw_clipped_zone_outline") and
        tactical.has_method("_clipped_map_segments"),
        "tactical overlay lacks geometry clipping for zone, roads or routes")
    var map_rect: Rect2=tactical.call("_map_rect")
    if map_rect.size.x>10.0 and map_rect.size.y>10.0:
        # Route crossing two edges must never draw into the live match.
        var crossing:=PackedVector2Array([
            map_rect.get_center()+Vector2(-map_rect.size.x,0),
            map_rect.get_center()+Vector2(map_rect.size.x,0)])
        var clipped: Array=tactical.call("_clipped_map_segments",
            crossing,map_rect)
        var crossing_visible: bool=clipped.size()==1
        if crossing_visible:
            var first_section: PackedVector2Array=clipped[0]
            crossing_visible=first_section.size()>=2
        check(crossing_visible,
            "crossing road was not clipped to the tactical pane")
        for section in clipped:
            for vertex in section:
                check(map_rect.grow(.1).has_point(vertex),
                    "road/route segment still leaks outside the map pane")
    else:
        check(false,"tactical map has zero-sized mobile viewport")
    if map_rect.size.x>30.0 and map_rect.size.y>30.0:
        # Reproduce the actual Android gesture lifecycle with two fingers.
        # Releasing the second finger at its original position used to place
        # a waypoint even though this gesture was only a pinch.
        var original_waypoint: Vector2=tactical.get("waypoint")
        var one: Vector2=map_rect.get_center()+Vector2(-22,0)
        var two: Vector2=map_rect.get_center()+Vector2(22,0)
        var first:=InputEventScreenTouch.new()
        first.index=4
        first.pressed=true
        first.position=one
        tactical._gui_input(first)
        var second:=InputEventScreenTouch.new()
        second.index=5
        second.pressed=true
        second.position=two
        tactical._gui_input(second)
        second.pressed=false
        tactical._gui_input(second)
        first.pressed=false
        tactical._gui_input(first)
        check(tactical.get("waypoint")==original_waypoint and
            tactical.get("_touches").is_empty() and
            not bool(tactical.get("_touch_gesture_multitouch")),
            "pinch release placed a false waypoint or kept stale touch state")
        # Releasing the mouse outside the map must terminate dragging.
        var press:=InputEventMouseButton.new()
        press.button_index=MOUSE_BUTTON_LEFT
        press.pressed=true
        press.position=map_rect.get_center()
        tactical._gui_input(press)
        var release:=InputEventMouseButton.new()
        release.button_index=MOUSE_BUTTON_LEFT
        release.pressed=false
        release.position=map_rect.position+Vector2(-18,8)
        tactical._gui_input(release)
        check(int(tactical.get("_drag_touch"))==-1,
            "map mouse drag remains active after off-pane release")
    check(tactical.has_method("_clamp_pan_to_terrain"),
        "tactical drag/zoom lacks world-bound checks")
    tactical.set("zoom",1.0)
    tactical.set("pan",Vector2(9999,-9999))
    tactical.call("_clamp_pan_to_terrain")
    var full_pan: Vector2=tactical.get("pan")
    check(full_pan.length_squared()<.0001,
        "unzoomed tactical view should be centred on the physical island")
    tactical.set("zoom",8.0)
    tactical.set("pan",Vector2(9999,-9999))
    tactical.call("_clamp_pan_to_terrain")
    var zoom_pan: Vector2=tactical.get("pan")
    var max_pan: float=ISLAND.HALF_EXTENT*(1.0-1.0/8.0)
    check(absf(zoom_pan.x)<=max_pan+.01 and
        absf(zoom_pan.y)<=max_pan+.01,
        "zoom/pan can leave Aurora physical terrain or repeat map texture")
    tactical.set("zoom",1.0)
    tactical.set("pan",Vector2.ZERO)
    check(radar.has_method("_draw_terrain_disc"),
        "terrain cartography still uses a square instead of a circular mask")
    # World-space centre and boundaries must produce identical image UVs
    # regardless of radar compass rotation or current shrinking phase.
    var mid: Vector2=radar.call("_terrain_pixel",
        Vector2.ZERO,Vector2(256,256))
    var corner: Vector2=radar.call("_terrain_pixel",
        Vector2(-SECTOR.INITIAL_RADIUS,-SECTOR.INITIAL_RADIUS),
        Vector2(256,256))
    check(mid.distance_to(Vector2(128,128))<.001 and
        corner.x<mid.x and corner.y<mid.y,
        "disc UV mapping does not follow the world-space heightfield")
    # Regression gate: the polygon API samples normalized UVs, whereas
    # drawing the old 128px centre directly would repeatedly tile the map.
    var center_uv: Vector2=radar.call("_terrain_uv",Vector2.ZERO)
    var uv_near: Vector2=radar.call("_terrain_uv",Vector2(20,-12))
    check(center_uv.distance_to(Vector2(.5,.5))<.00001 and
        uv_near.x>center_uv.x and uv_near.y<center_uv.y and
        uv_near.x<1.0 and uv_near.y>0.0,
        "Godot polygon texture UVs must be normalized to [0,1]")
    # Entering another aircraft phase after a 12 m final ring must reset
    # the radar to its original opening geometry, without a stale future arc.
    radar.call("set_zone",SECTOR.CENTER,SECTOR.FINAL_RADIUS)
    radar.call("set_next_zone",SECTOR.CENTER,SECTOR.FINAL_RADIUS*.5)
    radar.call("set_zone",SECTOR.CENTER,SECTOR.INITIAL_RADIUS)
    radar.call("clear_next_zone")
    check(is_equal_approx(float(radar.get("_zone_radius")),
        SECTOR.INITIAL_RADIUS),
        "new aircraft phase inherited a stale final-zone radius")
    check(not bool(radar.get("_next_zone_enabled")) and
        zone_label!=null and not zone_label.text.contains("PRÓX"),
        "future ring or its label persists after clearing the planned phase")
    radar.call("set_battle_mode",false)
    check(not bool(radar.get("_zone_enabled")) and
        not bool(radar.get("_next_zone_enabled")),
        "training inherited an obsolete Battle Royale circle")

    # Test planned phase from the actual match director API without starting
    # a second 50-bot game or mutating the player's inventory.
    var probe: Node3D=SECTOR.new()
    var phase_centers: Array[Vector2]=[
        SECTOR.CENTER,SECTOR.CENTER+Vector2(4,1),
        SECTOR.CENTER+Vector2(8,2),SECTOR.CENTER+Vector2(10,4),
        SECTOR.CENTER+Vector2(12,5)]
    probe.set("_phase_centers",phase_centers)
    probe.set("mode","sector_battle")
    probe.set("zone_phase",3)
    var planned: Dictionary=probe.call("next_zone_preview")
    check(bool(planned.get("active",false)) and
        is_equal_approx(float(planned.get("radius",0.0)),SECTOR.FINAL_RADIUS),
        "fourth phase no longer plans the real final circle")
    probe.set("zone_phase",SECTOR.PHASE_COUNT)
    var overtime: Dictionary=probe.call("next_zone_preview")
    check(not bool(overtime.get("active",true)),
        "final overtime incorrectly displays an invented fifth ring")
    probe.free()

    var boot: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(boot)
    await boot.wait_for_startup()
    boot._show_lobby()
    boot._select_tab("ARMAS")
    var camera: Camera3D=boot._preview_container.get_node_or_null(
        "PreviewViewport/AuroraCharacterStage/LobbyPortraitCamera") as Camera3D
    check(camera!=null,"lobby showroom camera missing")
    # Verify the barrel in CAMERA SPACE, not the raw GLB Euler angles:
    # imported sources have different native axes, and hero yaw is allowed.
    for slot in [CATALOG.AR,CATALOG.AWM,CATALOG.SCAR,CATALOG.MP40]:
        boot._on_armory_slot_selected(slot)
        var pivot: Node3D=boot._preview_weapon
        check(pivot!=null and boot._preview_weapon_slot==slot,
            "showroom did not load weapon slot "+str(slot))
        if pivot==null or camera==null:
            continue
        # Catch the separate placement regression: a level rifle can still
        # sit above or outside the actual portrait frame at phone resolution.
        var projected_center: Vector2=camera.unproject_position(
            pivot.global_position)
        var portrait_size: Vector2=Vector2(camera.get_viewport().size)
        check(projected_center.distance_to(portrait_size*.5)<
            portrait_size.y*.24,
            "original weapon is misplaced/off-centre in lobby: "+str(slot))
        var model: Node3D=pivot.get_node_or_null(
            "SelectedOriginalWeaponGLB") as Node3D
        check(model!=null,"real GLB missing in slot "+str(slot))
        if model==null:
            continue
        if slot==CATALOG.SCAR:
            # The source has two original receiver/polymer geometry surfaces
            # (~9.4k vertices), though their Blender object names say "mag".
            # Verify actual geometry rather than assuming an incomplete GLB
            # merely from those legacy material-group names.
            var scar_surfaces: int=0
            var scar_vertices: int=0
            var scar_length: float=0.0
            for node in model.find_children("*","MeshInstance3D",true,false):
                var part: MeshInstance3D=node as MeshInstance3D
                if part.mesh==null:
                    continue
                var bounds: Vector3=part.get_aabb().size
                scar_length=maxf(scar_length,
                    maxf(bounds.x,maxf(bounds.y,bounds.z)))
                for surface in range(part.mesh.get_surface_count()):
                    scar_surfaces+=1
                    scar_vertices+=part.mesh.surface_get_array_len(surface)
            check(scar_surfaces>=2 and scar_vertices>=4000 and
                scar_length>.65,
                "SCAR original receiver/polymer model lost genuine rifle geometry")
        var axis: Vector3=model.get_meta("armory_long_axis",Vector3.ZERO)
        var source_up: Vector3=model.get_meta("armory_up_axis",Vector3.ZERO)
        check(axis.length_squared()>.5 and source_up.length_squared()>.5,
            "source-axis diagnostics missing for slot "+str(slot))
        if axis.length_squared()<=.5 or source_up.length_squared()<=.5:
            continue
        var length_in_world: Vector3=(
            model.global_transform.basis*axis).normalized()
        var up_in_world: Vector3=(
            model.global_transform.basis*source_up).normalized()
        var screen_right: Vector3=camera.global_transform.basis.x
        var screen_up: Vector3=camera.global_transform.basis.y
        check(absf(length_in_world.dot(screen_up))<.14 and
            absf(length_in_world.dot(screen_right))>.80,
            "weapon barrel is visibly raised instead of horizontal: "+str(slot))
        check(up_in_world.dot(Vector3.UP)>.90,
            "weapon body/magazine rolled sideways: "+str(slot))
    if not failed:
        print("V75128_LEVEL_ARMORY_ZONE PASS level_glbs=4 "+
            "zone_rings=2 projected_from_director=1 overtime_clear=1")
    quit(1 if failed else 0)
