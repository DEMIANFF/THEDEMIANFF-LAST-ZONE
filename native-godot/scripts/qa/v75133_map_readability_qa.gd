extends SceneTree
## V75.133 real source-backed map (no imported third-party minimap art).
## Preserve all true terrain/roads, zone dynamics, player and marker inputs.
var failed: bool=false


func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V75133_MAP_READABILITY "+why)


func _initialize() -> void:
    call_deferred("_verify")


func _verify() -> void:
    root.size=Vector2i(964,434)
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var hud: CanvasLayer=game.get_node("TrainingHUD") as CanvasLayer
    var map: Control=hud.get_node(
        "AuroraTacticalOverlay/AuroraFullTacticalMap") as Control
    var radar: Control=hud.get_node(
        "AuroraTacticalOverlay/AuroraTrainingRadar") as Control
    var terrain: StaticBody3D=game.get_node("AuroraTerrain") as StaticBody3D
    var sector: Node3D=game.get_node("AuroraSectorMatch") as Node3D
    for enemy in game.get_node("CombatRange")._targets:
        enemy.set_physics_process(false)
    await process_frame
    await process_frame
    check(map!=null and radar!=null and terrain!=null and sector!=null,
        "actual physical island / minimap or zone director unavailable")
    if map==null:
        quit(1)
        return
    map.zoom=1.0
    var count: int=0
    for i in range(map.LANDMARK_NAMES.size()):
        if map._show_landmark_label(i):
            count+=1
    check(count==7 and map._show_landmark_label(0) and
        map._show_landmark_label(4) and
        map._show_landmark_label(7) and
        not map._show_landmark_label(1) and
        not map._show_landmark_label(2) and
        not map._show_landmark_label(3),
        "overview contains overlapping names rather than priority town POIs")
    check(not map._show_landmark_label(-1) and
        not map._show_landmark_label(map.LANDMARK_NAMES.size()),
        "invalid POI index incorrectly appears on map")
    map._zoom_at(2.0)
    count=0
    for i in range(map.LANDMARK_NAMES.size()):
        if map._show_landmark_label(i):
            count+=1
    check(count==11 and absf(map.zoom-2.0)<.01,
        "pinch zoom no longer reveals the full authoritative POI list")
    map.zoom=1.0
    map._follow()
    var controls: VBoxContainer=map.get_node("MapActions") as VBoxContainer
    check(controls!=null and controls.get_child_count()==6,
        "map has redundant buttons or missing real follow/zoom/route actions")
    if controls!=null:
        for child in controls.get_children():
            var button: Button=child as Button
            check(button!=null and
                button.custom_minimum_size.y>=56.0 and
                button.get_theme_font_size("font_size")>=14 and
                button.text!="NORTE ARRIBA",
                "map action has undersized touch target or duplicate control")
        var map_rect: Rect2=map._map_rect()
        var actions_rect: Rect2=controls.get_rect()
        check(map_rect.end.x+14.0<=actions_rect.position.x and
            actions_rect.end.y<=map.size.y and
            map_rect.end.y<=map.size.y,
            "tactical map action column occludes real terrain pane")
    check(map.AWM_POSITION==Vector2(8,24) and
        map.LANDMARK_NAMES.size()==map.LANDMARK_POSITIONS.size() and
        map.LANDMARK_NAMES.has("PUERTO AURORA"),
        "authoritative AWM/real Aurora POI anchors changed")
    check(map.get("_terrain_texture") is ImageTexture and
        radar.get("map_texture")==map.get("_terrain_texture"),
        "full map and minimap no longer share actual heightfield cartography")
    check(map.get("director")==sector and map.get("terrain")==terrain,
        "zone/camera map sources no longer match physical gameplay")
    if not failed:
        print("V75133_MAP_READABILITY PASS labels=7/11 zoom=2 "+
            "touch_actions=6 min_height=58 original_terrain=1 "+
            "awm=8_24 storm_authority=1")
    game.queue_free()
    await process_frame
    quit(1 if failed else 0)
