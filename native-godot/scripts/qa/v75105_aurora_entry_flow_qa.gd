extends SceneTree

var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(result: bool,message: String) -> void:
    if not result:
        failed=true
        push_error("V75105_ENTRY "+message)


func _tap(button: Button) -> void:
    var center: Vector2=button.get_global_transform_with_canvas()*(button.size*.5)
    var event:=InputEventScreenTouch.new()
    event.index=0
    event.position=root.get_final_transform()*center
    event.pressed=true
    Input.parse_input_event(event)
    await process_frame
    event=event.duplicate()
    event.pressed=false
    Input.parse_input_event(event)
    await process_frame


func _verify() -> void:
    root.size=Vector2i(964,434)
    var scene:=load("res://scenes/Boot.tscn") as PackedScene
    var front:=scene.instantiate() as Control
    front.game_scene_path="res://scenes/unavailable_entry_qa.tscn"
    root.add_child(front)
    await process_frame
    check(front.stage=="startup_failed" and front._loading_retry.is_visible_in_tree() and
        front._game==null and front._preview_container==null,
        "invalid resource did not hold a recoverable error screen")
    front.game_scene_path="res://scenes/Main.tscn"
    var boot_start: int=Time.get_ticks_msec()
    front._loading_retry.pressed.emit()
    check(front.stage=="startup" and front._loading_overlay.is_visible_in_tree() and
        front._loading_meter.is_visible_in_tree() and not front._loading_meter.indeterminate,
        "retry bypassed the real progress screen")
    await front.wait_for_startup()
    var load_ms: int=Time.get_ticks_msec()-boot_start
    check(front.stage=="welcome" and front._loading_meter.value==100 and
        not front._loading_overlay.visible and front._preview_container==null,
        "login appeared before the resource loaded or created a 3D renderer")
    await process_frame
    await process_frame
    var guest: Button=front._login_guest_button
    var google: Button=front._login_google_button
    var offline: Button=front._login_local_button
    # The refined entry flow uses an accessible right-hand VERTICAL card.
    # Preserve logical Google → Guest → Offline order and actual taps.
    check(guest.get_parent()==google.get_parent() and
        google.get_parent()==offline.get_parent() and
        google.global_position.y<guest.global_position.y and
        guest.global_position.y<offline.global_position.y,
        "login providers must remain grouped and vertically ordered")
    var safe: Rect2=root.get_visible_rect()
    for button in [guest,google,offline]:
        check(button.is_visible_in_tree() and safe.encloses(button.get_global_rect()),
            "a login action clipped at Motorola aspect ratio")
    await _tap(offline)
    check(front.stage=="lobby" and front._preview_avatar!=null and front._game==null,
        "native screen touch did not enter the local lobby")
    if front.stage!="lobby":
        quit(1)
        return

    front._battle_entry.pressed.emit()
    check(front.stage=="loading" and front._loading_meter.indeterminate and
        front._preview_container==null,"deployment did not unload the lobby preview first")
    front._loading_cancel.pressed.emit()
    check(front.stage=="lobby" and front._game==null,"cancel did not recover the lobby")
    var launch_start: int=Time.get_ticks_msec()
    front._launch(false)
    for i in range(12):
        await process_frame
        if front.stage!="loading":
            break
    check(front.stage=="training" and front._game!=null and front._game.has_node("TrainingHUD") and
        front._game.get_node("AuroraSectorMatch").mode=="training",
        "a canceled BR request leaked into the following training launch")
    var launch_ms: int=Time.get_ticks_msec()-launch_start
    front._return_to_lobby()
    check(front.stage=="lobby" and front._game==null and front._preview_avatar!=null,
        "game exit did not restore the playable lobby")
    front._welcome()
    front.queue_free()
    await create_timer(.12).timeout
    if not failed:
        print("V75105_ENTRY PASS retry=1 native_touch=1 no_lobby_world_overlap=1 cancel=1 training=1 load_ms=",
            load_ms," launch_ms=",launch_ms)
    quit(1 if failed else 0)
