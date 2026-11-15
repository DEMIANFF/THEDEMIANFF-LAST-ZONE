extends SceneTree
## V75.108: touch actions change real 3D operator and camera, not screenshots.
## Cosmetic sampling is never a purchase. Accept only real lobby scene.
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,problem: String) -> void:
    if not ok:
        failed=true
        push_error("V75108_OPERATOR_LOBBY "+problem)


func _verify() -> void:
    root.size=Vector2i(964,434)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    check(front.stage=="welcome","login not separated from lobby")
    front._enter_local_lobby()
    await process_frame
    var avatar: Node3D=front._preview_avatar
    check(avatar!=null and front._game==null,"real Lila preview is missing")
    if avatar==null:
        quit(1)
        return
    var camera: Camera3D=front._preview_container.get_node_or_null(
        "PreviewViewport/AuroraCharacterStage/LobbyPortraitCamera") as Camera3D
    check(camera!=null,"actual Godot 3D portrait camera missing")
    check(front._operator_controls.size()==3,
        "touch-accessible rotation and camera controls missing")
    var safe: Rect2=root.get_visible_rect()
    for button in front._operator_controls:
        check(button.is_visible_in_tree() and
            safe.grow(2).encloses(button.get_global_rect()),
            "operator control clipped: "+button.name)
        check(button.get_global_rect().size.y>=40.0,
            "operator touch target is smaller than 40 px: "+button.name)
    var before_angle: float=avatar.rotation.y
    front._operator_controls[1].pressed.emit()
    await create_timer(.40).timeout
    check(absf(angle_difference(before_angle,avatar.rotation.y))>.20,
        "right rotation did not turn actual skinned Lila")
    front._operator_controls[0].pressed.emit()
    await create_timer(.40).timeout
    check(absf(angle_difference(before_angle,avatar.rotation.y))<.12,
        "left turn did not restore starting direction")
    front._operator_controls[2].pressed.emit()
    await create_timer(.38).timeout
    check(front._preview_zoomed and camera!=null and absf(camera.fov-45.0)<.3 and
        camera.position.y>1.43,
        "framing control did not animate actual 3D camera")
    front._operator_controls[2].pressed.emit()
    await create_timer(.38).timeout
    check(not front._preview_zoomed and absf(camera.fov-54.0)<.3 and
        absf(camera.position.y-1.18)<.03,
        "framing control did not restore full-body view")

    var state_before: Dictionary=front._offline_records.cosmetic_state().duplicate(true)
    front._select_tab("PERSONAJE")
    check(front._shop_selector.is_visible_in_tree() and
        not front._shop_buy_button.visible and
        front._info.text.contains("VISTA 3D"),
        "Personajes must allow visual outfit testing without a purchase button")
    front._on_shop_skin_selected(2)
    check(front._preview_skin_applied=="aurora_ember",
        "character preview did not change Lila original mesh material")
    check(state_before==front._offline_records.cosmetic_state(),
        "visual character selection incorrectly modified wallet or ownership")
    front._select_tab("JUGAR")
    check(front._preview_skin_applied==str(state_before["equipped"]) and
        front._battle_entry.visible and front._social_panel.visible,
        "leaving character preview lost outfit or the actual BR entry")
    front._select_tab("TIENDA")
    check(front._shop_selector.visible and front._shop_buy_button.visible,
        "real local store is no longer accessible")
    front._select_tab("JUGAR")

    front._welcome()
    await process_frame
    check(front._operator_controls.is_empty() and not front._preview_zoomed and
        front._preview_avatar==null,
        "logout did not release 3D controls and framing state")
    front._enter_local_lobby()
    await process_frame
    check(front._operator_controls.size()==3 and
        front._preview_avatar!=null and front._game==null,
        "returning to the lobby did not rebuild interactive operator")
    front.queue_free()
    await process_frame
    if not failed:
        print("V75108_OPERATOR_LOBBY PASS rotation=3d framing=3d "+
            "character_skins=read_only logout_release=1 BR_access=1")
    quit(1 if failed else 0)
