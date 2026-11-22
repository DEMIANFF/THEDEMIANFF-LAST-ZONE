extends SceneTree
## Native button-to-button acceptance for the ONLY HUD settings route:
## top right gear → Partida/HUD → Personalizar HUD → Guardar → lobby.
## Unlike a mockup this invokes the actual persistent TrainingHUD editor.
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,description: String) -> void:
    if not ok:
        failed=true
        push_error("V75155_HUD_SETTINGS_ROUNDTRIP "+description)

func frames(amount: int) -> void:
    for i in range(amount):
        await process_frame

func _verify() -> void:
    root.size=Vector2i(964,434)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    front._show_lobby()
    await frames(2)
    front._layout_safe()
    check(front.stage=="lobby" and front._game==null,
        "lobby was not ready before opening settings")
    var gear: Button=front._top_settings_button
    check(gear!=null and gear.is_visible_in_tree(),
        "the single top gear is missing in the live lobby")
    if gear==null:
        quit(1)
        return
    gear.emit_signal("pressed")
    var modal: CanvasLayer=front._settings_modal
    check(modal!=null and front.stage=="lobby" and
        front._game==null and paused,
        "opening the top gear incorrectly started a match")
    if modal==null:
        quit(1)
        return

    # Current mode information is truthful: no obsolete 8-bot assertion.
    modal.call("_show_subcategory","INFORMACIÓN")
    var correct_roster: bool=false
    var stale_roster: bool=false
    for node in modal.find_children("*","Label",true,false):
        var line: Label=node as Label
        if line!=null:
            correct_roster=correct_roster or (
                line.text.contains("50 PARTICIPANTES") and
                line.text.contains("49 IA"))
            stale_roster=stale_roster or line.text.contains("8 bots")
    check(correct_roster and not stale_roster,
        "settings did not report the true fifty-fighter local BR")
    modal.call("_show_subcategory","HUD")
    var preset: OptionButton=modal.find_child(
        "HUDPresetSelector",true,false) as OptionButton
    var edit: Button=modal.find_child(
        "EditCurrentHud",true,false) as Button
    check(preset!=null and preset.get_item_count()==4 and edit!=null,
        "top gear lost original four persistent HUD layouts/editor")
    if edit==null:
        modal.call("_close")
        front.queue_free()
        quit(1)
        return
    edit.emit_signal("pressed")
    await frames(18)
    check(front.stage=="training" and front._game!=null,
        "temporary real HUD editing host did not initialize")
    if front._game==null:
        quit(1)
        return
    var hud: CanvasLayer=front._game.get_node("TrainingHUD")
    check(hud._hud_editing and hud.return_to_lobby_on_save and paused,
        "editor launched Training instead of a paused lobby-origin edit")
    # Save only the current layout; never award wins, consume money,
    # alter the online identity or start a match in this QA.
    hud._hud_edit_save()
    await frames(12)
    check(front.stage=="lobby" and front._game==null and not paused and
        front._preview_container!=null and
        is_instance_valid(front._preview_container),
        "saving via top AJUSTES stranded the player in Training")
    check(front._bottom_navigation.get_child_count()==5 and
        front._bottom_navigation.get_node_or_null("BottomPRESET")==null and
        front._mode_gallery_entry==null,
        "saving HUD resurrected the removed PRESET or MODOS controls")

    gear=front._top_settings_button
    gear.emit_signal("pressed")
    var reopened: CanvasLayer=front._settings_modal
    check(reopened!=null and front._game==null and front.stage=="lobby",
        "second settings opening changed gameplay state")
    if reopened!=null:
        var saved_slots: OptionButton=reopened.find_child(
            "HUDPresetSelector",true,false) as OptionButton
        check(saved_slots!=null and saved_slots.get_item_count()==4,
            "HUD slot choices did not survive lobby editor round trip")
        reopened.call("_close")
    front.queue_free()
    await process_frame
    if not failed:
        print("V75155_HUD_SETTINGS_ROUNDTRIP PASS real_top_gear=1 "+
            "four_HUD_slots=1 correct_50_fighters=1 "+
            "edit_in_paused_real_scene=1 save_returns_lobby=1 "+
            "no_extra_MODOS=1 no_footer_PRESET=1 viewport=964x434")
    quit(1 if failed else 0)
