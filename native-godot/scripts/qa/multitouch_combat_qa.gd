extends SceneTree
## Dedicated three-finger test: move and aim while firing, then jump and release.
## Desktop Godot input-node simulation; physical Android remains separately required.

func _initialize() -> void:
    call_deferred("_test")


func _test() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player:=game.get_node("Operator") as CharacterBody3D
    var combat:=game.get_node("CombatRange") as Node3D
    var hud:=game.get_node("TrainingHUD") as CanvasLayer
    var left:=game.get_node("TrainingHUD/AuroraTacticalOverlay/MovePad") as Control
    var right:=game.get_node("TrainingHUD/AuroraTacticalOverlay/DirectionalFirePad") as Control
    for i in range(105):
        await physics_frame
    if not player.is_on_floor():
        push_error("MULTITOUCH QA player not grounded")
        quit(70)
        return
    var initial: Vector3=player.global_position

    var left_down:=InputEventScreenTouch.new()
    left_down.index=2
    left_down.position=left.size*.5
    left_down.pressed=true
    left._gui_input(left_down)
    var left_drag:=InputEventScreenDrag.new()
    left_drag.index=2
    left_drag.position=left_down.position+Vector2(0,-68)
    left_drag.relative=Vector2(0,-68)
    left._gui_input(left_drag)

    var right_down:=InputEventScreenTouch.new()
    right_down.index=7
    right_down.pressed=true
    right_down.position=right.size*.5
    right._gui_input(right_down)
    var yaw_before: float=player.get("_desired_yaw")
    var right_drag:=InputEventScreenDrag.new()
    right_drag.index=7
    right_drag.position=right_down.position+Vector2(60,-17)
    right_drag.relative=Vector2(60,-17)
    right._gui_input(right_drag)

    if not combat.trigger_held:
        push_error("MULTITOUCH QA fire finger not held")
        quit(71)
        return
    if (player.get("_move_axis") as Vector2).length()<.7:
        push_error("MULTITOUCH QA movement finger stolen by firepad")
        quit(72)
        return
    if absf(float(player.get("_desired_yaw"))-yaw_before)<.05:
        push_error("MULTITOUCH QA firepad did not move camera while left finger walking")
        quit(73)
        return

    var bottom: float=player.global_position.y
    hud._jump_down()
    var max_y: float=bottom
    for i in range(32):
        await physics_frame
        max_y=maxf(max_y,player.global_position.y)
    var travelled: float=Vector2(initial.x,initial.z).distance_to(Vector2(player.global_position.x,player.global_position.z))
    if max_y-bottom<.35 or travelled<.6:
        push_error("MULTITOUCH QA jump+walking+fire failed: rise="+str(max_y-bottom)+" distance="+str(travelled))
        quit(74)
        return
    var fire_up:=InputEventScreenTouch.new()
    fire_up.index=7
    fire_up.pressed=false
    fire_up.position=right_drag.position
    right._gui_input(fire_up)
    var walk_up:=InputEventScreenTouch.new()
    walk_up.index=2
    walk_up.pressed=false
    walk_up.position=left_drag.position
    left._gui_input(walk_up)
    if combat.trigger_held or (player.get("_move_axis") as Vector2).length()>.02:
        push_error("MULTITOUCH QA pointers remained stuck after release")
        quit(75)
        return
    print("MULTITOUCH_QA PASS walking=",travelled," jump=",max_y-bottom," concurrent aim/fire and released pointers")
    quit(0)
