extends SceneTree
## V75.78 in-engine reference integration, not an image-only promise.
## Never contacts production Firebase or manufactures premium currency/friends.
const BRIDGE=preload("res://scripts/persistence/aurora_firebase_bridge.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7578_AURORA_LOBBY "+reason)

func _verify() -> void:
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    await process_frame
    check(front.stage=="welcome","startup entry screen not first")
    check(front._login_google_button.is_visible_in_tree() and
        front._login_guest_button.is_visible_in_tree() and
        front._login_local_button.is_visible_in_tree(),
        "real Google, Guest and explicit local entry options unavailable")
    check(not bool(BRIDGE.status().get("ready",true)) and
        front._login_status_label.text.contains("PENDIENTE"),
        "headless preview misreported App Check as verified")
    front._enter_local_lobby()
    await process_frame
    check(front.stage=="lobby" and front._selected_tab=="JUGAR",
        "offline entry did not open native Battle Royale lobby")
    check(front._left_shortcuts.get_child_count()==4 and
        front._bottom_navigation.get_child_count()==5 and
        front._bottom_navigation.has_node("BottomJUGAR"),
        "commerce rail and JUGAR return route must exist with full navigation")
    check(front._left_shortcuts.has_node("QuickTIENDA") and
        front._left_shortcuts.has_node("QuickPASE") and
        not front._left_shortcuts.has_node("QuickJUGAR") and
        front._left_shortcuts.has_node("QuickEVENTS") and
        front._left_shortcuts.has_node("QuickMISSIONS") and
        not front._left_shortcuts.has_node("QuickACHIEVEMENTS"),
        "store, pass, events, missions or achievements missing; no second JUGAR")
    check(front._social_panel.visible and
        front._social_status_label.text.contains("SIN AMIGOS"),
        "unavailable online social system was misrepresented")
    check(front._play_match_card.visible and
        front._battle_entry.text=="INICIAR" and front._battle_entry.visible,
        "golden Battle Royale start card not functional")
    check(front._preview_container.find_child(
        "AuroraSentinelCompanion",true,false)!=null,
        "original 3D sentinel companion absent")
    check(not front._auth_guest_button.visible and
        not front._auth_google_button.visible,
        "login providers wrongly shown in gameplay lobby")
    check(front._currency_strip.text.contains("MONEDAS") and
        front._currency_strip.text.contains("DIAMANTES"),
        "wallet structure missing")
    front._open_lobby_category("OBJETIVOS","missions")
    check(front._info.text.contains("MISIONES / METAS LOCALES"),
        "mission shortcut did not route to real saved-match goals")
    front._open_lobby_category("OBJETIVOS","achievements")
    check(front._info.text.contains("LOGROS / HISTORIAL REAL"),
        "achievement shortcut did not read real match records")
    front._open_lobby_category("OBJETIVOS","events")
    check(front._info.text.contains("SIN TEMPORADA ACTIVA"),
        "events cannot suggest fake rewards")
    front._select_tab("INVENTARIO")
    check(front._info.text.contains("INVENTARIO EN PARTIDA"),
        "inventory module not wired to actual match equipment")
    # V75.155: PRESET was removed from the public footer. The same four
    # persistent HUD slots and editor now live under the TOP settings gear.
    check(not front._bottom_navigation.has_node("BottomPRESET"),
        "obsolete footer PRESET still crowds mobile lobby")
    front._top_settings_button.emit_signal("pressed")
    var modal: CanvasLayer=front._settings_modal
    check(modal!=null and
        modal.find_child("HUDPresetSelector",true,false)!=null and
        modal.find_child("EditCurrentHud",true,false)!=null and
        front.stage=="lobby" and front._game==null,
        "HUD settings must be opened from the top gear, not a new match")
    if modal!=null:
        modal.call("_close")
    front._top_account_button.emit_signal("pressed")
    check(front._profile_overlay.is_visible_in_tree() and
        front._profile_stat_labels.size()==3,
        "top-left profile did not open real match-ledger stats")
    var open_account: Button=front._profile_overlay.find_child(
        "ManageProfileAccount",true,false) as Button
    check(open_account!=null,"profile has no real account/backup route")
    if open_account!=null:
        open_account.pressed.emit()
    check(front._selected_tab=="CUENTA" and
        front._login_manage_button.is_visible_in_tree(),
        "player profile did not reach native account settings")
    check(front._info.text.contains("ID OFICIAL: PENDIENTE"),
        "unverified account identity was fabricated")
    for resolution in [Vector2i(964,434),Vector2i(960,540),
            Vector2i(1280,720),Vector2i(2712,1220)]:
        root.size=resolution
        await process_frame
        await process_frame
        front._layout_safe()
        await process_frame
        var screen: Rect2=root.get_visible_rect()
        for ctl in [front._top_account_button,front._top_settings_button,
                front._login_manage_button,front._name_entry,
                front._name_save_button,front._preview_container]:
            check(screen.encloses(ctl.get_global_rect()),
                "Aurora lobby control clipped "+ctl.name+" "+str(resolution))
    front._login_manage_button.emit_signal("pressed")
    check(front.stage=="welcome" and
        front._login_google_button.visible and front._login_guest_button.visible,
        "changing accounts failed to return to dedicated provider screen")
    front.queue_free()
    await process_frame
    if not failed:
        print("V7578_AURORA_LOBBY PASS login=entry_only local=playable "+
            "left_rail=5 bottom_navigation=5 hud_only_in_settings=1 social=truthful companion=3d "+
            "missions=journal hud=real account=no_fake_id motorola=964x434")
    quit(1 if failed else 0)
