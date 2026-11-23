extends SceneTree
## Verifies a touch on Lila's ACTUAL imported skinned mesh in Godot.
## A tap on the airfield, nearby companion or backdrop must NOT open EMOTES.
## Rotation, close, HUD and the single mode selector remain operational.
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V75173_SILHOUETTE "+message)


func _mouse_tap(front: Control,point: Vector2) -> void:
    var tap:=InputEventMouseButton.new()
    tap.button_index=MOUSE_BUTTON_LEFT
    tap.position=point
    tap.pressed=true
    front._preview_input(tap)
    tap.pressed=false
    front._preview_input(tap)


func _verify() -> void:
    root.size=Vector2i(964,434)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    check(front.stage=="welcome","real sign-in screen missing")
    front._enter_local_lobby()
    await process_frame
    front._layout_safe()
    await process_frame
    check(front.stage=="lobby" and front._preview_avatar!=null,
        "actual Aurora GLB not instantiated")
    var actual: Rect2=front._portrait_character_hit_rect()
    print("V75174_LILA_HIT_DEBUG canvas=",front._preview_container.size,
        " viewport=",front._preview_container.get_node("PreviewViewport").size,
        " rect=",actual," window=",root.size)
    check(actual.has_area() and
        actual.size.x<float(front._preview_container.size.x)*.27,
        "touch envelope not bounded by character geometry")
    check(actual.size.y>float(front._preview_container.size.y)*.28,
        "real character is not visible at a useful hit-test size")
    check(front._preview_hit_character(actual.get_center()),
        "center of original Lila mesh did not select her")
    # Test physical 964x434 target fractions mapped into the actual
    # SubViewportContainer's local GUI coordinates. Godot canvas_items
    # may provide a different logical canvas on a mobile-sized window.
    for normalized_point in [
        Vector2(265.0/964.0,194.0/434.0),
        Vector2(738.0/964.0,200.0/434.0),
        Vector2(78.0/964.0,240.0/434.0),
        Vector2(910.0/964.0,245.0/434.0)]:
        var background_point: Vector2=(
            normalized_point*front._preview_container.size)
        check(not front._preview_hit_character(background_point),
            "tap on scenery was mistaken for Lila: "+str(background_point))
        _mouse_tap(front,background_point)
        check(not front._emote_wheel.visible,
            "empty airfield opened a fake emote selector")
    _mouse_tap(front,actual.get_center())
    check(front._emote_wheel.visible and
        front._emote_wheel.find_child(
            "AuroraAvailableCharacterEmote",true,false)!=null,
        "tapping the skinned operator did not open original emotes")
    var emote: Button=front._emote_wheel.find_child(
        "AuroraAvailableCharacterEmote",true,false) as Button
    if emote!=null:
        emote.pressed.emit()
    check(not front._emote_wheel.visible,
        "choosing an authentic animation did not close the wheel")
    check(front._top_account_button.get_theme_font_size("font_size")>=20 and
        front._currency_strip.get_theme_font_size("font_size")>=20,
        "profile or currency illegible at Motorola landscape size")
    check(front._left_shortcuts.get_child_count()==5 and
        front._bottom_navigation.get_child_count()==5 and
        front._social_panel.get_node(
            "SocialContent/AuroraFourMemberSquad").get_child_count()==4,
        "clean five/five navigation or local four-slot squad was altered")
    check(front._match_mode_selector.get_item_text(0)=="CLÁSICO" and
        front._match_mode_selector.get_item_count()==3 and
        front._battle_entry.is_visible_in_tree(),
        "single BR classic/ranked/training selector no longer launches")
    front._welcome()
    await process_frame
    check(front._preview_container==null and front._emote_wheel==null,
        "actual imported GLB render target/emote wheel leaked on logout")
    front.queue_free()
    await process_frame
    if not failed:
        print("V75173_SILHOUETTE PASS "+
            "real_GLB_projection=1 blank_scene_tap_rejected=4 "+
            "emote=authored_animation mobile_typography=1 "+
            "footer=5 side=5 squad=4 render_target_released=1")
    quit(1 if failed else 0)
