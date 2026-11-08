extends SceneTree
## Automated viewport input-dispatch investigation, separate from physical-device QA.

func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var game := (load("res://scenes/Main.tscn") as PackedScene).instantiate() as Node3D
    root.add_child(game)
    var operator := game.get_node("Operator") as CharacterBody3D
    for i in range(100):
        await physics_frame
    var start := operator.global_position
    var touch := InputEventScreenTouch.new()
    touch.index = 6
    touch.position = Vector2(128.0, 552.0)
    touch.pressed = true
    Input.parse_input_event(touch)
    await process_frame
    var swipe := InputEventScreenDrag.new()
    swipe.index = 6
    swipe.position = Vector2(128.0, 452.0)
    swipe.relative = Vector2(0.0,-100.0)
    Input.parse_input_event(swipe)
    await process_frame
    var axis: Vector2=operator.get("_move_axis")
    print("TOUCH_ROUTE viewport size=",game.get_viewport().get_visible_rect().size," move_axis=",axis)
    for i in range(32):
        await physics_frame
    var walk_distance: float=Vector2(start.x,start.z).distance_to(Vector2(operator.global_position.x,operator.global_position.z))
    print("TOUCH_ROUTE walk_distance=",walk_distance)
    var released := InputEventScreenTouch.new()
    released.index = 6
    released.position = swipe.position
    released.pressed = false
    Input.parse_input_event(released)
    await process_frame
    if axis.length()<.12 or walk_distance<.5:
        push_error("MOTOROLA CONTROL BUG: native on-screen joystick touch/drag did not drive movement")
        quit(31)
        return
    print("TOUCH_ROUTE PASS: low-level touch-to-movement pipeline")
    quit(0)
