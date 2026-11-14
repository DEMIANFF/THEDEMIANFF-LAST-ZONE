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
    var one: Error=welcome.save_png("res://out/aurora-v75-19-welcome.png")
    if one!=OK or welcome.save_png("res://out/aurora-v75-78-login.png")!=OK:
        push_error("V75.78 login screenshot failed")
        quit(1)
        return
    front.call("_show_lobby")
    for i in range(8):
        await process_frame
    var lobby: Image=root.get_texture().get_image()
    var two: Error=lobby.save_png("res://out/aurora-v75-19-lobby.png")
    if two!=OK or lobby.save_png("res://out/aurora-v75-78-lobby.png")!=OK:
        push_error("V75.78 lobby screenshot failed")
        quit(2)
        return
    front._select_tab("CUENTA")
    for i in range(5):
        await process_frame
    var account: Image=root.get_texture().get_image()
    var account_saved: Error=account.save_png("res://out/aurora-v75-77-account.png")
    if account_saved!=OK or account.save_png("res://out/aurora-v75-78-account.png")!=OK:
        push_error("V75.78 account screen screenshot failed")
        quit(3)
        return
    print("AURORA_FRONTEND_RENDER",welcome.get_width(),"x",welcome.get_height(),
        " login is separated from playable lobby; 3D assets and buttons render in Godot")
    quit(0)
