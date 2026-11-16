extends SceneTree
## V75.114: loading status motion must never invent progress or leak tweens.
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(value: bool,reason: String) -> void:
    if not value:
        failed=true
        push_error("V75114_LOADING_SIGNAL "+reason)


func _verify() -> void:
    root.size=Vector2i(964,434)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    await process_frame
    check(front.stage=="welcome","startup did not reach actual auth")
    front._show_loading("CARGANDO RECURSOS","Preparando Base Aurora…")
    await process_frame
    check(front._loading_overlay.visible and
        front._loading_heartbeat!=null and
        front._loading_heartbeat.is_running(),
        "loading panel has no active native Aurora pulse")
    check(front._loading_meter.value==0.0 and
        not front._loading_meter.indeterminate,
        "decorative motion altered the real resource progress")
    check(front._loading_accent_stripe.name=="AuroraLoadingGoldStripe",
        "animated original brand accent is missing")
    await create_timer(.3).timeout
    check(front._loading_heartbeat!=null and
        front._loading_heartbeat.is_running(),
        "progress motion stopped before resource lifecycle ended")
    front._welcome()
    await process_frame
    check(front.stage=="welcome" and front._loading_heartbeat==null and
        is_equal_approx(front._loading_chapter.modulate.a,1.0) and
        is_equal_approx(front._loading_accent_stripe.modulate.a,1.0) and
        not front._loading_overlay.visible,
        "hidden loading animation leaks into welcome screen")
    front._login_local_button.pressed.emit()
    await process_frame
    check(front.stage=="lobby" and front._preview_avatar!=null,
        "ending the loading heartbeat disrupted normal lobby entry")
    front._show_loading("CARGANDO PARTIDA","Preparando Battle Royale…")
    await process_frame
    check(front._loading_heartbeat!=null,
        "match loading no longer shares the real motion system")
    front._welcome()
    await process_frame
    check(front._preview_container==null and
        front._loading_heartbeat==null,
        "return from match loading leaked the avatar or tween")
    front.queue_free()
    await process_frame
    if not failed:
        print("V75114_LOADING_SIGNAL PASS motion=realUI "+
            "progress=resource_owned reentry=clean")
    quit(1 if failed else 0)
