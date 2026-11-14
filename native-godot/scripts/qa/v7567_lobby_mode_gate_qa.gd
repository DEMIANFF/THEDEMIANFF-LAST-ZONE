extends SceneTree
## V75.67 — the real lobby must distinguish local Classic and Training
## from competitive online. Ranked must never run AI-only matches or award RP.
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool, reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7567_LOBBY_MODE "+reason)

func _verify() -> void:
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    front._show_lobby()
    await process_frame
    check(front.stage=="lobby","real lobby not opened")
    var selector: OptionButton=front._match_mode_selector
    check(selector!=null and selector.get_item_count()==3,
        "Clásico, Clasificatoria and Entrenamiento are not selectable")
    check(front._selected_match_mode=="classic" and front._battle_entry.visible,
        "local Classic must be the initial playable mode")
    check(not front._training_entry.visible,
        "Training must not obscure the Classic start button")
    check(front._encounter_selector.visible and front._encounter_count==9,
        "safe 9-person local configuration lost")
    check(front._lobby_detail_scroll is ScrollContainer,
        "long lobby information is not scrollable on mobile")

    selector.select(1)
    front._on_match_mode_selected(1)
    check(front._selected_match_mode=="ranked",
        "ranked selection not retained in lobby state")
    check(not front._battle_entry.visible and not front._training_entry.visible,
        "ranked incorrectly exposes an offline start button")
    check(not front._encounter_selector.visible,
        "AI count shown as a ranked human queue")
    check(front._lobby_mode_status.text.contains("BLOQUEADA"),
        "ranked readiness/security conditions not disclosed")
    front._launch(true)
    check(front.stage=="lobby" and front._game==null,
        "ranked opened a fake offline match")
    front._launch(false)
    check(front.stage=="lobby" and front._game==null,
        "ranked bypassed its gate through Training")

    selector.select(2)
    front._on_match_mode_selected(2)
    check(front._selected_match_mode=="training" and front._training_entry.visible,
        "real Training mode button not available")
    check(not front._battle_entry.visible and not front._encounter_selector.visible,
        "Training displays Classic-only controls")

    front._select_tab("AJUSTES")
    check(front._settings_panel.visible and not selector.visible,
        "Settings does not make room for full controls on a small screen")
    front._select_tab("CUENTA")
    check(not front._settings_panel.visible and not selector.visible and
        front._name_entry.visible,
        "account identity editor did not replace match controls")
    check(front._info.text.contains("Google") and
        front._info.text.contains("Firebase") and
        front._info.text.contains("ID OFICIAL: PENDIENTE"),
        "account screen falsely claims Godot cloud login or player ID")
    front._select_tab("PERSONAJE")
    check(selector.visible and front._training_entry.visible and
        not front._battle_entry.visible,
        "return from Account did not preserve Training selection")
    selector.select(0)
    front._on_match_mode_selected(0)
    check(front._battle_entry.visible and not front._training_entry.visible,
        "switching back to Classic after Account did not restore start button")

    selector.select(0)
    front._on_match_mode_selected(0)
    front._on_encounter_selected(1)
    check(front._encounter_count==20 and
        front._lobby_mode_status.text.contains("20 participantes"),
        "Classic AI count not reflected in mode availability")
    for size in [Vector2i(960,540),Vector2i(1280,720)]:
        root.size=size
        await process_frame
        await process_frame
        front._layout_safe()
        check(front._battle_entry.is_visible_in_tree(),
            "Classic start button hidden by responsive layout "+str(size))
        check(front._lobby_detail_scroll.is_visible_in_tree(),
            "lobby details panel absent "+str(size))

    front.queue_free()
    await process_frame
    if not failed:
        print("V7567_LOBBY_MODE PASS classic=offline ranked=locked "+
            "training=local account=honest mobile_details=scrollable")
    quit(1 if failed else 0)
