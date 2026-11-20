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
    var coverage: Dictionary=radar.call("ring_coverage")
    check(float(coverage["current"])<=0.915 and
        float(coverage["next"])<=0.915,
        "current/future 245m rings still spill outside minimap")
    check(tactical.has_method("_draw_clipped_zone_outline"),
        "tactical map lacks clipped live/future rings")
    radar.call("clear_next_zone")
    check(not bool(radar.get("_next_zone_enabled")),
        "future ring persists after clearing the planned phase")
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
    check(not bool(probe.call("next_zone_preview").get("active",true)),
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
