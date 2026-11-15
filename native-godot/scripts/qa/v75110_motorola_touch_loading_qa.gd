extends SceneTree
## V75.110: verify actual Godot controls fit the Motorola landscape safe rect.
## The test uses native touch events for both commerce and bottom navigation.
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(result: bool,message: String) -> void:
    if not result:
        failed=true
        push_error("V75110_MOTOROLA_TOUCH "+message)


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


func _check_target(button: Button,safe: Rect2,min_height: float=40.0) -> void:
    var rect: Rect2=button.get_global_rect()
    check(button.is_visible_in_tree() and safe.grow(.5).encloses(rect),
        "button outside screen: "+button.name+" "+str(rect))
    check(rect.size.y>=min_height and rect.size.x>=40.0,
        "undersized native touch target: "+button.name+" "+str(rect.size))


func _verify() -> void:
    root.size=Vector2i(964,434)
    var scene:=load("res://scenes/Boot.tscn") as PackedScene
    var front:=scene.instantiate() as Control
    root.add_child(front)
    await front.wait_for_startup()
    await process_frame
    check(front.stage=="welcome","boot did not reach genuine login")
    var safe: Rect2=root.get_visible_rect()
    for button in [front._login_google_button,front._login_guest_button,
            front._login_local_button]:
        _check_target(button,safe)
    await _tap(front._login_local_button)
    check(front.stage=="lobby","offline native touch did not enter lobby")
    if front.stage!="lobby":
        front.queue_free()
        quit(1)
        return
    await process_frame
    safe=root.get_visible_rect()

    # These header buttons were only ~32px high in V75.109 at 434px height.
    for button in [front._top_account_button,front._top_settings_button,
            front._top_social_button]:
        _check_target(button,safe,44.0)
    check(front._left_shortcuts.get_child_count()==6,
        "six functional Aurora commerce shortcuts are missing")
    var previous_bottom: float=-1.0
    for node in front._left_shortcuts.get_children():
        var button:=node as Button
        check(button!=null,"commerce rail has a non-button child")
        if button==null:
            continue
        _check_target(button,safe)
        var rect:=button.get_global_rect()
        check(rect.position.y>=previous_bottom,
            "commerce rail touch targets overlap")
        previous_bottom=rect.end.y

    # Do not confuse a pressed.emit() unit test with a routed screen touch.
    var store: Button=front._left_shortcuts.get_node("QuickTIENDA") as Button
    await _tap(store)
    check(front._selected_tab=="TIENDA" and front._shop_selector.visible,
        "native screen touch on left rail did not open the store")
    var play: Button=front._bottom_navigation.get_node("BottomJUGAR") as Button
    _check_target(play,safe)
    await _tap(play)
    check(front._selected_tab=="JUGAR" and front._battle_entry.visible,
        "native screen touch on bottom navigation did not restore JUGAR")

    # Check the real overlay with CANCEL present; its prior box only had
    # 132px of vertical space and could clip this action on 964x434.
    front._show_loading("PREPARANDO PUERTO AURORA",
        "Montando terreno, operador y controles…",true)
    front._loading_cancel.show()
    await process_frame
    await process_frame
    var content: Control=front._loading_overlay.get_node("AuroraLoadingActions")
    check(content.get_global_rect().size.y>=180.0,
        "load action area too short for visible controls")
    for control in [front._loading_title,front._loading_detail,
            front._loading_meter,front._loading_cancel]:
        var rect: Rect2=control.get_global_rect()
        check(safe.grow(.5).encloses(rect),
            "visible loading action clipped: "+control.name+" "+str(rect))
    _check_target(front._loading_cancel,safe,44.0)

    # Cancelling the overlay does not create a second scene or lose the lobby.
    front._loading_cancel.pressed.emit()
    check(front.stage=="lobby" and front._game==null and
        front._preview_avatar!=null,"cancel did not restore lobby safely")
    front.queue_free()
    await create_timer(.12).timeout
    if not failed:
        print("V75110_MOTOROLA_TOUCH PASS native_rail=1 native_bottom=1 ",
            "header=44px shortcuts=40px load_cancel=safe")
    quit(1 if failed else 0)
