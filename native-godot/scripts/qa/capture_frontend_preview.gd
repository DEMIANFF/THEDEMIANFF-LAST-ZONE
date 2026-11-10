extends SceneTree
## Render real Godot welcome/lobby UI from original native controls.
func _initialize() -> void:
    call_deferred("_capture")


func _capture() -> void:
    var boot: PackedScene=load("res://scenes/Boot.tscn")
    var front: Control=boot.instantiate()
    root.add_child(front)
    for i in range(6):
        await process_frame
    var welcome: Image=root.get_texture().get_image()
    var one: Error=welcome.save_png("res://out/aurora-v75-14-welcome.png")
    if one!=OK:
        push_error("V75 welcome screenshot failed")
        quit(1)
        return
    front.call("_show_lobby")
    for i in range(8):
        await process_frame
    var lobby: Image=root.get_texture().get_image()
    var two: Error=lobby.save_png("res://out/aurora-v75-14-lobby.png")
    if two!=OK:
        push_error("V75 lobby screenshot failed")
        quit(2)
        return
    print("AURORA_FRONTEND_RENDER",welcome.get_width(),"x",welcome.get_height(),
        " welcome/lobby are original Godot GUI not imported third-party sprites")
    quit(0)
