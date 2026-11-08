extends SceneTree
## Tests joystick GUI handler, axis signal and actual walking physics.
## Does not imply hardware Android multitouch was physically tested.

func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player:=game.get_node("Operator") as CharacterBody3D
    var pad:=game.get_node_or_null("TrainingHUD/AuroraTacticalOverlay/MovePad") as Control
    if pad==null:
        push_error("Joystick GUI Control is missing")
        quit(31)
        return
    for i in range(100):
        await physics_frame
    var start: Vector3=player.global_position
    var center: Vector2=pad.size*.5
    var touch:=InputEventScreenTouch.new()
    touch.index=6
    touch.pressed=true
    touch.position=center
    pad.call("_gui_input",touch)
    var drag:=InputEventScreenDrag.new()
    drag.index=6
    drag.position=center+Vector2(0,-68)
    drag.relative=Vector2(0,-68)
    pad.call("_gui_input",drag)
    var axis: Vector2=player.get("_move_axis")
    print("JOYSTICK_GUI_AXIS ",axis," pad_size=",pad.size)
    for i in range(35):
        await physics_frame
    var distance: float=Vector2(start.x,start.z).distance_to(Vector2(player.global_position.x,player.global_position.z))
    print("JOYSTICK_GUI_DISTANCE ",distance)
    var up:=InputEventScreenTouch.new()
    up.index=6
    up.pressed=false
    up.position=drag.position
    pad.call("_gui_input",up)
    await physics_frame
    if axis.y>=-.7 or distance<=.7 or (player.get("_move_axis") as Vector2).length()>.01:
        push_error("Joystick GUI axis/movement/release regression")
        quit(32)
        return
    print("JOYSTICK_GUI PASS")
    quit(0)
