extends SceneTree
## V75.113: acceptance of three live Godot screens, never static mockups.
## Every state change exercises the same buttons and objects used on Android.
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75113_PREMIUM_FRONTEND "+reason)


func _within_screen(control: Control,context: String) -> void:
    var screen: Rect2=root.get_visible_rect().grow(1.0)
    check(control.is_visible_in_tree() and
        screen.encloses(control.get_global_rect()),
        context+" escapes visible screen: "+control.name)


func _verify() -> void:
    root.size=Vector2i(1280,720)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    await process_frame
    check(front.stage=="welcome" and front._preview_container==null,
        "startup rendered a costly 3D lobby before sign-in")
    check(front._entry_hero_plate.name=="AuroraEntryHeroPanel" and
        front._entry_hero_plate.visible and front._entry_hero_kicker.visible and
        front._entry_panel_accent.visible,
        "the custom command center entry hierarchy is not real UI")
    check(front._entry_mission_caption.text.contains("ÚLTIMA ZONA") and
        front._entry_mission_caption.anchor_top<.43,
        "Aurora introduction is not an intentional hero composition")
    for button in [front._login_google_button,front._login_guest_button,
            front._login_local_button]:
        _within_screen(button,"large-screen login")
        check(button.get_global_rect().size.y>=40.0,
            "sign-in button too short")

    # A real threaded loading surface, with a styled progress bar,
    # visible retry/cancel actions only in appropriate lifecycle states.
    front._show_loading("CARGANDO RECURSOS","Preparando Base Aurora…")
    await process_frame
    check(front._loading_overlay.visible and
        front._loading_surface_plate.name=="AuroraLoadingConsolePlate" and
        front._loading_chapter.text.contains("A U R O R A") and
        front._loading_meter.visible and front._loading_meter.max_value>=100.0,
        "splash screen is missing the live progress console")
    _within_screen(front._loading_surface_plate,"loading console")
    front._welcome()
    await process_frame

    for dimensions in [Vector2i(964,434),Vector2i(2712,1220)]:
        root.size=dimensions
        await process_frame
        front._layout_safe()
        await process_frame
        for action in [front._login_google_button,front._login_guest_button,
                front._login_local_button]:
            _within_screen(action,"responsive login "+str(dimensions))
            check(action.get_global_rect().size.y>=40.0,
                "small sign-in hit area "+str(dimensions))
        var hero: Rect2=front._entry_hero_plate.get_global_rect()
        var login: Rect2=front._entry_glass.get_global_rect()
        check(hero.end.x<=login.position.x,
            "left artwork intro overlaps native account actions")
        check(not front._entry_info_panel.visible if
            dimensions.x/dimensions.y>=2 else
            front._entry_info_panel.visible,
            "optional information must adapt to physical aspect")

    root.size=Vector2i(964,434)
    await process_frame
    front._layout_safe()
    await process_frame
    front._login_local_button.pressed.emit()
    await process_frame
    check(front.stage=="lobby" and
        not front._entry_hero_plate.visible and
        not front._entry_mission_caption.visible,
        "welcome intro overlapped the real Battle Royale lobby")
    check(front._preview_container!=null and
        front._preview_container.visible and
        front._preview_avatar!=null,
        "full-sized native Godot 3D Lila preview was replaced")
    check(front._lobby_status_ribbon.visible and
        front._lobby_status_ribbon.name=="AuroraLiveOperationRibbon",
        "battle preparation identity missing")
    _within_screen(front._lobby_status_ribbon,"operation ribbon")
    _within_screen(front._play_match_card,"battle card")
    _within_screen(front._social_panel,"local squad")
    var slots: HBoxContainer=front._social_panel.get_node(
        "SocialContent/AuroraFourMemberSquad")
    check(slots.get_child_count()==4,"the squad does not have four distinct slots")
    check((slots.get_child(0).get_child(0) as Label).text.contains("LOCAL"),
        "first squad slot is not the real local operator")
    for i in range(1,4):
        check((slots.get_child(i).get_child(0) as Label).text.contains("—"),
            "empty squad slot fabricates a remote player")
    check(front._battle_entry.text=="INICIAR" and front._battle_entry.visible,
        "real match action no longer available")
    var camera: Camera3D=front._preview_container.get_node(
        "PreviewViewport/AuroraCharacterStage/LobbyPortraitCamera")
    check(camera.fov>=53.0,"full-body Lila framing regressed")
    var hangar: Node3D=front._preview_container.get_node(
        "PreviewViewport/AuroraCharacterStage/AuroraReal3DLobbyEnvironment")
    check(hangar.find_child("AuroraRunwayCentralSpine",true,false)!=null and
        hangar.find_child("AuroraRunwayReflector",true,false)!=null and
        hangar.find_child("AuroraResearchStation",true,false)!=null,
        "original 3D Aurora base lost its premium staging geometry")

    front._select_tab("TIENDA")
    await process_frame
    check(not front._battle_entry.visible and front._shop_selector.visible,
        "shop access broke while rebuilding lobby")
    front._select_tab("JUGAR")
    check(front._battle_entry.visible,"INICIAR did not return after navigation")
    front._welcome()
    await process_frame
    check(front.stage=="welcome" and
        front._preview_container==null and
        front._entry_hero_plate.visible and
        not front._lobby_status_ribbon.visible,
        "3D preview leaked into welcome after session exit")
    front.queue_free()
    await process_frame
    if not failed:
        print("V75113_PREMIUM_FRONTEND PASS loading=live "+
            "entry=responsive lobby=real3d squad=4 exit=clean")
    quit(1 if failed else 0)
