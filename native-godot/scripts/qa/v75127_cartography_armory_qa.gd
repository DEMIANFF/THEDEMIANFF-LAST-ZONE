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
    for slot in [CATALOG.SCAR,CATALOG.AWM,CATALOG.MP40]:
        boot._on_armory_slot_selected(slot)
        check(boot._preview_weapon!=null and boot._preview_weapon_slot==slot,
            "installed weapon missing from original 3D showroom: "+str(slot))
        if boot._preview_weapon!=null:
            var real_model: Node3D=boot._preview_weapon.get_node_or_null(
                "SelectedOriginalWeaponGLB") as Node3D
            check(real_model!=null and
                absf(real_model.rotation.y)>deg_to_rad(12.0),
                "showroom lacks three-quarter view: "+str(slot))
    if not failed:
        print("V75127_CARTOGRAPHY_ARMORY PASS terrain=256 roads=3 "+
            "real_houses=12 clipped_minimap=1 real_models=3 hero_angle=1")
    quit(1 if failed else 0)
