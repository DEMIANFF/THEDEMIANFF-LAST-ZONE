extends SceneTree
## V75.131 - Real user-interactive mode selection on the original lobby.
## Do not mock ranked, online squads, paid rewards or match entitlements.
var failed: bool=false


func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V75131_MODE_GALLERY "+message)


func _initialize() -> void:
    call_deferred("_verify")


func _verify() -> void:
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    front._show_lobby()
    var entry: Button=front._mode_gallery_entry
    var overlay: Control=front._mode_gallery_overlay
    var cards: Dictionary=front._mode_gallery_cards
    check(entry!=null and overlay!=null and cards.size()==3,
        "mode entry, 3 original cards or overlay missing")
    if entry==null or overlay==null or cards.size()!=3:
        quit(1)
        return
    check(entry.visible and not overlay.visible and
        front._selected_match_mode=="classic",
        "default local Classic lobby obscured by mode gallery")
    # Check actual hit targets remain on-screen on the Edge 60 Fusion.
    root.size=Vector2i(964,434)
    await process_frame
    await process_frame
    front._layout_safe()
    check(root.get_visible_rect().encloses(entry.get_global_rect()),
        "mode gallery entry off-screen on 964x434 Motorola landscape")
    entry.emit_signal("pressed")
    check(overlay.visible,"tapping MODOS did not open a working gallery")
    var panel: PanelContainer=overlay.get_node("ModeGalleryPanel") as PanelContainer
    check(panel!=null and
        root.get_visible_rect().encloses(panel.get_global_rect()),
        "3-card mode selector clipped by phone safe layout")
    await process_frame
    await process_frame
    var modal_exit: Button=panel.find_child(
        "CloseModeGallery",true,false) as Button
    check(modal_exit!=null and modal_exit.is_visible_in_tree() and
        modal_exit.custom_minimum_size.y>=72.0 and
        modal_exit.get_global_rect().size.y>=40.0,
        "mode gallery close target too small for Motorola touch controls")
    check(cards["classic"] is Button and cards["training"] is Button and
        cards["ranked"] is Button,
        "mode choices are not interactive native buttons")
    check(bool((cards["classic"] as Button).get_meta(
        "aurora_selected_mode",false)),
        "Classic card did not display the actual active mode")
    # A blocked mode is DISCOVERABLE but cannot load AI-only ranked combat.
    (cards["ranked"] as Button).emit_signal("pressed")
    check(not overlay.visible and front._selected_match_mode=="ranked" and
        front._match_mode_selector.selected==1 and
        front._lobby_mode_status.text.contains("BLOQUEADA") and
        not front._battle_entry.visible and not front._training_entry.visible,
        "ranked card incorrectly starts or disguises a local match")
    front._launch(true)
    check(front.stage=="lobby" and front._game==null,
        "ranked mode gallery bypassed real backend gate")

    entry.emit_signal("pressed")
    check(overlay.visible,"cannot reopen mode gallery from locked ranked")
    (cards["training"] as Button).emit_signal("pressed")
    check(not overlay.visible and front._selected_match_mode=="training" and
        front._match_mode_selector.selected==2 and
        front._training_entry.visible and not front._battle_entry.visible,
        "Training card is not linked to actual local training action")
    entry.emit_signal("pressed")
    (cards["classic"] as Button).emit_signal("pressed")
    check(front._selected_match_mode=="classic" and
        front._battle_entry.visible and not front._training_entry.visible and
        front._lobby_mode_status.text.contains("50 PARTICIPANTES"),
        "Classic card failed to restore local 50-fighter mode")
    entry.emit_signal("pressed")
    front._select_tab("INVENTARIO")
    check(not entry.visible and not overlay.visible and
        front._equipment_selector.visible,
        "gallery leaked into equipment screen")
    front._open_mode_gallery()
    check(not overlay.visible,"gallery can open from a non-play tab")
    front._select_tab("JUGAR")
    entry.emit_signal("pressed")
    check(overlay.visible,"gallery cannot reopen after leaving inventory")
    var close: Button=panel.find_child("CloseModeGallery",true,false) as Button
    check(close!=null,"mode gallery cannot be dismissed")
    if close!=null:
        close.emit_signal("pressed")
    check(not overlay.visible and front.stage=="lobby",
        "mode gallery close changed match state or failed to dismiss")
    front._welcome()
    check(not entry.visible and not overlay.visible,
        "mode entry or popup leaks onto authentication screen")
    front.queue_free()
    await process_frame
    if not failed:
        print("V75131_MODE_GALLERY PASS cards=3 classic=50 training=local "+
            "ranked=gated viewport=964x434 account=hidden")
    quit(1 if failed else 0)
