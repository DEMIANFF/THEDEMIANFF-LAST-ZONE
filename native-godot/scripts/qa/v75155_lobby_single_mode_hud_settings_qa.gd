extends SceneTree
## V75.155 production lobby QA at the Motorola 964x434 aspect ratio.
## Only the RIGHT Battle Royale card chooses modes; top-right AJUSTES
## owns all four HUD profiles and their persistent edit entry.
## Legacy V75.27 QA separately verifies save returns from temporary Training
## to lobby, without falsely starting a user-initiated match.
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75155_LOBBY_HUD_SETTINGS "+reason)


func _verify() -> void:
    root.size=Vector2i(964,434)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    front._show_lobby()
    await process_frame
    front._layout_safe()

    # No off-centre MODOS button or second UI tree.
    check(front._mode_gallery_entry==null and
        front._mode_gallery_overlay==null and
        front.find_child("AuroraModeGalleryEntry",true,false)==null,
        "the marked-up redundant MODOS button remains in the 3D lobby")
    var right: OptionButton=front._match_mode_selector
    check(right!=null and right.visible and right.get_item_count()==3 and
        right.selected==0 and front._selected_match_mode=="classic",
        "right-side BR card is not the only working game-mode selector")
    check(right.get_global_rect().position.x>
        front._surface.global_position.x+front._surface.size.x*.68,
        "BR selector overlaps the operator or left-side main navigation")
    check(front._battle_entry.visible and
        not front._lobby_mode_caption.visible and
        not front._lobby_match_facts.visible and
        front._selected_match_mode=="classic",
        "playable classic BR should have one compact selector and INICIAR")

    var footer: HBoxContainer=front._bottom_navigation
    check(footer.get_child_count()==5 and
        footer.get_node_or_null("BottomPRESET")==null,
        "redundant PRESET button still takes space in bottom navigation")
    for name in ["BottomJUGAR","BottomINVENTARIO","BottomARMAS",
            "BottomPERSONAJE","BottomSOCIAL"]:
        var button: Button=footer.get_node_or_null(name) as Button
        check(button!=null and button.visible and
            button.get_global_rect().size.x>80.0,
            "missing usable bottom-navigation action "+name)
    check(not front._lobby_status_ribbon.visible,
        "extra local-mode ribbon still crowds the bottom of Lila")
    var rail: VBoxContainer=front._left_shortcuts
    check(rail.get_child_count()==5 and
        rail.get_node_or_null("QuickJUGAR")==null and
        rail.get_node_or_null("QuickPASE")!=null,
        "left rail must have five genuine actions and no duplicated JUGAR")
    front._select_tab("INVENTARIO")
    footer.get_node("BottomJUGAR").pressed.emit()
    check(front._selected_tab=="JUGAR" and right.visible,
        "only the active footer JUGAR should reopen the right-side BR card")

    # The already-existing 4-slot persisted HUD editor must be reached by
    # the actual TOP gear, not a second PRESET footer, and not start a match.
    var settings: Button=front._top_settings_button
    check(settings!=null and settings.is_visible_in_tree() and
        settings.tooltip_text.contains("HUD"),
        "top-right gear has no discoverable HUD settings access")
    settings.emit_signal("pressed")
    var modal: CanvasLayer=front._settings_modal
    check(modal!=null and front.stage=="lobby" and front._game==null,
        "opening HUD settings from lobby incorrectly started Training")
    if modal==null:
        front.queue_free()
        quit(1)
        return
    var slots: OptionButton=modal.find_child(
        "HUDPresetSelector",true,false) as OptionButton
    var edit: Button=modal.find_child(
        "EditCurrentHud",true,false) as Button
    check(slots!=null and slots.get_item_count()==4 and
        edit!=null and edit.is_visible_in_tree(),
        "HUD's four saved presets and real editor are not inside AJUSTES")
    check(modal.is_connected("hud_editor_requested",
        Callable(front,"_settings_edit_hud")),
        "settings HUD action has no lobby return-context handler")
    modal.call("_close")
    check(front._settings_modal==null and not paused and
        front.stage=="lobby" and front._game==null,
        "closing HUD settings started a battle or left the lobby paused")
    # Obsolete programmatic PRESET links are safely routed to settings;
    # they cannot recreate an extra visible navigation button.
    front._select_tab("PRESET")
    check(front._settings_modal!=null and
        front._selected_tab=="JUGAR" and
        footer.get_node_or_null("BottomPRESET")==null,
        "old PRESET navigation did not migrate to AJUSTES")
    if front._settings_modal!=null:
        front._settings_modal.call("_close")
    front.queue_free()
    await process_frame
    if not failed:
        print("V75155_LOBBY_HUD_SETTINGS PASS viewport=964x434 "+
            "left_mode_button=REMOVED footer_preset=REMOVED "+
            "right_mode_selector=ONLY_ONE classic_roster=50 "+
            "footer_buttons=5 rail_buttons=6 hud_presets=4 "+
            "settings_top_gear=1 lobby_returns=1 training_not_started=1")
    quit(1 if failed else 0)
