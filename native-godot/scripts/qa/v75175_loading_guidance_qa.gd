extends SceneTree
## V75.175 validates the LIVE loading overlay. Tips are original copy;
## the only determinate percentage is sourced from ResourceLoader. This is
## not a fake matchmaking counter, a simulated loading delay, or a GPU test.
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(condition: bool,reason: String) -> void:
    if not condition:
        failed=true
        push_error("V75175_LOADING_GUIDANCE "+reason)


func _verify() -> void:
    root.size=Vector2i(964,434)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    check(front.stage=="welcome" and front._game_scene!=null,
        "real resource startup was not completed")
    check(front._loading_meter.value==100.0 and
        front._loading_tip_label!=null,
        "the real threaded loading meter or advice layer is missing")
    check(front.loading_tip_for("battle",0)!=front.loading_tip_for("training",0),
        "battle and training tips are not contextual")
    check(front.loading_tip_for("invalid",0)==front.loading_tip_for("startup",0),
        "invalid loading stage did not use safe startup advice")
    front._enter_local_lobby()
    await process_frame
    check(front.stage=="lobby" and front._preview_avatar!=null,
        "original skinned lobby scene was replaced")

    front._show_loading("PREPARANDO PUERTO AURORA",
        "Montando terreno, operador y controles…",true)
    front._set_loading_tip_context("battle")
    front._loading_cancel.show()
    await process_frame
    await process_frame
    check(front._loading_overlay.visible and
        front._loading_overlay.mouse_filter==Control.MOUSE_FILTER_STOP and
        front._loading_tip_label.mouse_filter==Control.MOUSE_FILTER_IGNORE,
        "loading overlay is not a touch-blocking modal")
    check(front._loading_meter.indeterminate and
        front._loading_meter.value==0.0 and
        not front._loading_meter.show_percentage,
        "match preparation falsely displays a fake percentage")
    check(front._loading_tip_label.text==front.loading_tip_for("battle",0),
        "battle-specific advice not shown")

    var safe: Rect2=root.get_visible_rect()
    check(safe.grow(1.0).encloses(front._loading_tip_label.get_global_rect()),
        "Aurora loading tip clipped at Motorola 964x434")
    check(not front._loading_tip_label.get_global_rect().intersects(
        front._loading_cancel.get_global_rect()),
        "loading tip overlaps the real cancel touch target")
    for i in range(7):
        front._tick_loading_tip(1.0)
    check(front._loading_tip_label.text==front.loading_tip_for("battle",1),
        "loading advice does not cycle after the documented interval")
    check(front._loading_meter.indeterminate and
        front._loading_meter.value==0.0,
        "advice animation is fabricating progress")
    front._set_loading_tip_context("hud_editor")
    check(front._loading_tip_label.text==front.loading_tip_for("hud_editor",0),
        "HUD editor advice does not reflect the actual editing task")
    front._loading_cancel.pressed.emit()
    check(front.stage=="lobby" and front._game==null and
        front._preview_avatar!=null and not front._loading_overlay.visible,
        "cancel did not restore live lobby or left modal overlay visible")
    root.size=Vector2i(1280,720)
    await process_frame
    front._show_loading("PREPARANDO ENTRENAMIENTO","Preparando terreno…",true)
    front._set_loading_tip_context("training")
    front._loading_cancel.show()
    await process_frame
    await process_frame
    safe=root.get_visible_rect()
    check(safe.grow(1.0).encloses(front._loading_tip_label.get_global_rect()) and
        not front._loading_tip_label.get_global_rect().intersects(
            front._loading_cancel.get_global_rect()),
        "loading advice clips or blocks cancel in the 1280x720 layout")
    front._loading_cancel.pressed.emit()
    front._welcome()
    await process_frame
    check(front.stage=="welcome" and not front._loading_overlay.visible and
        front._loading_heartbeat==null,
        "Aurora loading advice/tween leaked into the login screen")
    front.queue_free()
    await process_frame
    if not failed:
        print("V75175_LOADING_GUIDANCE PASS startup_real_loader=1 "+
            "contextual_original_tips=1 deterministic_match_progress=0 "+
            "modal_input=1 cancel=1 964x434=1 1280x720=1")
    quit(1 if failed else 0)
