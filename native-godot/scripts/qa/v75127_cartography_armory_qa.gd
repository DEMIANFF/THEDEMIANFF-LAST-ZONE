extends SceneTree
## V75.127: cartographic terrain + mobile clipped minimap and side-on weapon QA.
const CATALOG=preload("res://scripts/combat/aurora_weapon_catalog.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(value: bool,message: String) -> void:
    if not value:
        failed=true
        push_error("V75127_CARTOGRAPHY_ARMORY "+message)

func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var radar: Control=hud.get_node("AuroraTacticalOverlay/AuroraTrainingRadar")
    var map: Control=hud.get_node("AuroraTacticalOverlay/AuroraFullTacticalMap")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var player: CharacterBody3D=game.get_node("Operator")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    for enemy in game.get_node("CombatRange")._targets:
        enemy.set_physics_process(false)
    await process_frame
    check(radar.clip_contents,
        "245m zone arcs leak outside the phone minimap and obscure HUD")
    check(map.get("_terrain_texture") is ImageTexture and
        (map.get("_terrain_texture") as ImageTexture).get_width()==256,
        "actual 256px relief/roads/house cartography never generated")
    check(radar.get("map_texture")==map.get("_terrain_texture"),
        "minimap not using same physical Aurora cartography as tactical map")
    check(terrain.height_at(18.0,-8.0)>terrain.sea_level,
        "mapped historic house is submerged in physical terrain")
    check(map.get("player")==player and map.get("director")==director,
        "map lost authoritative player and moving-zone state")
    var boot: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(boot)
    await boot.wait_for_startup()
    boot._show_lobby()
    boot._select_tab("ARMAS")
    var portrait: Camera3D=boot._preview_container.get_node_or_null(
        "PreviewViewport/AuroraCharacterStage/LobbyPortraitCamera") as Camera3D
    check(portrait!=null,"original lobby camera missing from showroom")
    # A raw Y Euler-angle threshold approved weapons that were visibly tilted
    # upward. The longitudinal source axis must project horizontally instead.
    for slot in [CATALOG.AR,CATALOG.AWM,CATALOG.SCAR,CATALOG.MP40]:
        boot._on_armory_slot_selected(slot)
        check(boot._preview_weapon!=null and boot._preview_weapon_slot==slot,
            "installed weapon missing from original 3D showroom: "+str(slot))
        if boot._preview_weapon!=null and portrait!=null:
            var real_model: Node3D=boot._preview_weapon.get_node_or_null(
                "SelectedOriginalWeaponGLB") as Node3D
            check(real_model!=null,
                "original showroom GLB missing: "+str(slot))
            if real_model!=null:
                var source_axis: Vector3=real_model.get_meta(
                    "armory_long_axis",Vector3.ZERO)
                check(source_axis.length_squared()>.5,
                    "missing original barrel-axis metadata: "+str(slot))
                if source_axis.length_squared()>.5:
                    var projected: Vector3=(
                        real_model.global_transform.basis*source_axis).normalized()
                    check(absf(projected.dot(
                        portrait.global_transform.basis.y))<.14,
                        "weapon appears raised/diagonal: "+str(slot))
    if not failed:
        print("V75127_CARTOGRAPHY_ARMORY PASS terrain=256 roads=3 "+
            "real_houses=12 clipped_minimap=1 real_models=4 level_pose=1")
    quit(1 if failed else 0)
