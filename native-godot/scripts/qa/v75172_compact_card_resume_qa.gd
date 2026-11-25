extends SceneTree
## V75.172 — true Godot full-lobby visual geometry and Firebase-intent QA.
## Reproduces the pending->authenticated transition WITHOUT issuing
## Firebase sign-in, token fabrication or network calls; the real Android
## plugin must still pass its own compile and handset gates.
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75172_COMPACT_RESUME "+reason)


func _check_composition(front: Control,dimensions: Vector2i) -> void:
    # Measure the actual Godot safe canvas, not unscaled window pixels.
    var safe: Rect2=front._surface.get_global_rect()
    check(safe.size.distance_to(Vector2(dimensions))<3.0,
        "window resize did not produce requested logical layout: "+
        str(dimensions)+" actual="+str(safe.size))
    var card: Rect2=front._play_match_card.get_global_rect()
    var squad: Rect2=front._social_panel.get_global_rect()
    var mode: Rect2=front._match_mode_selector.get_global_rect()
    var launch: Rect2=front._battle_entry.get_global_rect()
    var footer: Rect2=front._bottom_navigation.get_global_rect()
    var header: Rect2=front._top_account_button.get_global_rect()
    print("V75178_CARD_GEOMETRY screen=",dimensions,
        " card=",card," mode=",mode," launch=",launch,
        " squad=",squad," footer=",footer,
        " mode_inside=",card.grow(2).encloses(mode),
        " launch_inside=",card.grow(2).encloses(launch),
        " intersects_squad=",card.intersects(squad),
        " intersects_footer=",card.intersects(footer))
    check(safe.grow(1).encloses(card) and
        safe.grow(1).encloses(squad) and
        safe.grow(1).encloses(header),
        "functional 3D lobby panels escape "+str(dimensions))
    check(card.grow(2).encloses(mode) and
        card.grow(2).encloses(launch) and
        not card.intersects(footer) and
        not card.intersects(squad),
        "mode selector/INICIAR escaped compact card or overlap at "+str(dimensions))
    check(card.size.y<float(safe.size.y)*(.385 if safe.size.y<560.0 else .245) and
        card.end.y-launch.end.y<float(safe.size.y)*.075,
        "right card still wastes an oversized empty black region: "+str(
        dimensions)+" unused="+str(card.end.y-launch.end.y))
    check(header.size.x<float(safe.size.x)*.185 and
        not header.intersects(front._profile_strip.get_global_rect()) and
        header.get_center().x<safe.position.x+float(safe.size.x)*.30,
        "real top-left profile consumes excessive header width")
    check(front._currency_strip.text.contains("MONEDAS") and
        front._currency_strip.text.contains("DIAMANTES —") and
        not front._currency_strip.text.contains("SIN DATOS"),
        "premium balance was invented or used as an oversized label")
    print("V75172_GEOMETRY requested=",dimensions," logical_safe=",safe,
        " match_card=",card," launch=",launch," profile=",header)
    check(front._bottom_navigation.get_child_count()==5 and
        front._left_shortcuts.get_child_count()==4 and
        not front._lobby_section_title.visible and
        not front._lobby_match_facts.visible,
        "old duplicated BR controls returned to the mobile lobby")


func _verify() -> void:
    # Exercise true pixel-sized mobile and desktop canvases in isolated QA.
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    root.size=Vector2i(964,434)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    # A startup resume *attempt* is expected; it is not an authenticated
    # account. Without an Android SDK the real welcome screen stays visible.
    check(front.stage=="welcome" and
        front._auto_resume_on_entry and
        front._login_waiting_provider.is_empty(),
        "initial startup must offer sign-in while allowing a real restore")
    # Fresh Google/Guest sign-in can be authenticated while server identity
    # is pending. Keep intent across poll cycles; do not clear it early.
    front._login_waiting_provider="google"
    check(not front._resume_native_session_if_ready({
        "authenticated":true,"pending":true}) and
        front._login_waiting_provider=="google",
        "new sign-in intent was lost while Firebase identity is pending")
    check(not front._resume_native_session_if_ready({
        "authenticated":false,"pending":false}) and
        front._login_waiting_provider=="google",
        "unverified provider was allowed to enter a fabricated session")
    check(front._resume_native_session_if_ready({
        "authenticated":true,"pending":false}) and
        front._login_waiting_provider.is_empty(),
        "confirmed Google/Guest sign-in did not transition to real lobby")
    await process_frame
    check(front.stage=="lobby" and front._preview_avatar!=null,
        "confirmed existing session failed to enter original live 3D lobby")
    for dimensions in [Vector2i(964,434),Vector2i(1280,720)]:
        root.size=dimensions
        await process_frame
        front._layout_safe()
        await process_frame
        _check_composition(front,dimensions)
    var mode: OptionButton=front._match_mode_selector
    mode.select(1)
    mode.item_selected.emit(1)
    check(not front._battle_entry.visible and
        front._lobby_mode_status.visible and
        front._lobby_mode_status.text.contains("BLOQUEADA"),
        "ranked disabled warning lost in compact card")
    mode.select(2)
    mode.item_selected.emit(2)
    check(front._training_entry.is_visible_in_tree() and
        front._training_entry.text=="INICIAR",
        "genuine Training action became clipped by card reduction")
    mode.select(0)
    mode.item_selected.emit(0)
    check(front._battle_entry.is_visible_in_tree() and
        front._battle_entry.text=="INICIAR",
        "switching back to real 50-player Classic failed")
    # Reopening account selection manually MUST NOT immediately auto-login.
    front._welcome()
    await process_frame
    check(front.stage=="welcome" and not front._auto_resume_on_entry and
        front._login_waiting_provider.is_empty() and
        front._preview_container==null,
        "manual change-account view was skipped or retained VRAM")
    front.queue_free()
    await process_frame
    if not failed:
        print("V75172_COMPACT_RESUME PASS dimensions=2 "+
            "card=content_only top_left_profile=compact "+
            "currency=honest actual_GLTF=1 "+
            "auth=pending_to_confirmed login=restored_no_spoof "+
            "ranked=gated training=real footer=5")
    quit(1 if failed else 0)
