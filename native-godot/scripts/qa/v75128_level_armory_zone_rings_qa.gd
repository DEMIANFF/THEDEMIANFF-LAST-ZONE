extends SceneTree
## V75.128: level original showroom GLBs and true mobile safe-zone rings.
const CATALOG=preload("res://scripts/combat/aurora_weapon_catalog.gd")
const SECTOR=preload("res://scripts/match/sector_director.gd")
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
    check(tactical.has_method("_draw_clipped_zone_outline"),
        "tactical map lacks clipped live/future rings")
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
    radar.call("clear_next_zone")
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
        var model: Node3D=pivot.get_node_or_null(
            "SelectedOriginalWeaponGLB") as Node3D
        check(model!=null,"real GLB missing in slot "+str(slot))
        if model==null:
            continue
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
