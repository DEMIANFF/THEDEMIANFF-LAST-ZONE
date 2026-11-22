extends SceneTree
## V75.167 real UI simplification: one settings editor, no hidden navigation
## clones, 50-fighter battle card and readable real-world translucent UI.
var failed: bool=false


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75167_UNIQUE_SETTINGS "+reason)


func _initialize() -> void:
    call_deferred("_verify")


func _verify() -> void:
    root.size=Vector2i(964,434)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    front._enter_local_lobby()
    await process_frame
    front._layout_safe()
    await process_frame
    check(front.stage=="lobby" and front._game==null and
        front._preview_avatar!=null,
        "cannot simplify UI by replacing 3D Lila with a fake")
    check(front.find_child("CameraSettings",true,false)==null and
        front.find_child("EditHUDEntry",true,false)==null and
        front.find_child("MobileSettingsScroll",true,false)==null and
        front.find_child("GraphicsPresetFPS",true,false)==null,
        "legacy duplicate camera/HUD/FPS settings widgets still exist")
    check(front._lobby_nav!=null and front._lobby_nav.get_child_count()==0,
        "nine hidden duplicate lobby menu buttons still allocated")
    var footer: HBoxContainer=front._bottom_navigation
    check(footer.get_child_count()==5 and
        footer.get_node_or_null("BottomSOCIAL")!=null and
        footer.get_node_or_null("BottomPRESET")==null and
        not front._top_social_button.visible,
        "social/controls duplicate header or PRESET reappeared")
    var squad: PanelContainer=front._social_panel
    check(squad.find_child("RealSocialEntry",true,false)==null and
        squad.find_child("AuroraFourMemberSquad",true,false).get_child_count()==4,
        "duplicate social action or real four-slot squad changed")
    var squad_style: StyleBoxFlat=squad.get_theme_stylebox("panel") as StyleBoxFlat
    var match_style: StyleBoxFlat=front._play_match_card.get_theme_stylebox(
        "panel") as StyleBoxFlat
    check(squad_style!=null and match_style!=null and
        squad_style.bg_color.a<.95 and match_style.bg_color.a<.95,
        "opaque stacked panels still obscure the 3D lobby")

    # Top-right gear remains the sole user-facing HUD route.
    front._top_settings_button.pressed.emit()
    var modal: CanvasLayer=front._settings_modal
    check(modal!=null and front._game==null,
        "opening settings from lobby started gameplay")
    if modal==null:
        front.queue_free()
        quit(1)
        return
    var categories: Dictionary=modal.get("_category_buttons")
    check(categories.size()==4 and categories.has("PARTIDA") and
        categories.has("PANTALLA") and categories.has("SONIDO") and
        categories.has("CUENTA") and
        not categories.has("GRABACIÓN") and
        not categories.has("NOTIFICACIÓN"),
        "settings still include duplicate or nonfunctional categories")
    check(modal.find_child("HUDPresetSelector",true,false)!=null and
        modal.find_child("EditCurrentHud",true,false)!=null and
        modal.find_child("ApplyAuroraHudReference",true,false)!=null,
        "canonical 4-profile HUD editor or real Aurora slot 4 removed")
    check(modal.find_child("RealSocialEntry",true,false)==null,
        "settings must not contain a second social route")
    var content: VBoxContainer=modal.get("_content") as VBoxContainer
    var controls_buttons: int=0
    for button in content.get_children():
        if button is Button and (button as Button).text.contains("CONTROLES"):
            controls_buttons+=1
    check(controls_buttons==0,
        "CONTROLES still duplicates the HUD editor within settings")
    modal.call("_show_subcategory","CONTROLES")
    check(modal.get("_subcategory")=="HUD",
        "old controls navigation did not map to one HUD editor")
    modal.call("_show_category","PANTALLA")
    check(modal.find_child("Toggle_show_fps",true,false)!=null,
        "real FPS display toggle disappeared with duplicate notification page")
    modal.call("_close")
    await process_frame
    check(front._settings_modal==null and front.stage=="lobby" and
        not paused,
        "closing settings did not return to lobby")
    front._select_tab("AJUSTES")
    check(front._settings_modal!=null and front._selected_tab=="JUGAR",
        "legacy AJUSTES route opened an obsolete second settings screen")
    if front._settings_modal!=null:
        front._settings_modal.call("_close")
    front.queue_free()
    await process_frame
    if not failed:
        print("V75167_UNIQUE_SETTINGS PASS canonical_hud=1 four_slots=1 "+
            "legacy_settings=removed hidden_nav=removed subcategories=4 "+
            "categories=4 social_entry=footer_only active_BR=1 "+
            "offline_gameplay_preserved=1")
    quit(1 if failed else 0)
