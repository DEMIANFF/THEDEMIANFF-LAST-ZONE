extends SceneTree
## Genuine renderer screenshot of the built 3D Puerto Aurora quarter.
## Preview camera is a CI inspection fixture; normal gameplay camera unchanged.

func _initialize() -> void:
    call_deferred("_capture")


func _capture() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var hud: CanvasLayer=game.get_node("TrainingHUD") as CanvasLayer
    hud.visible=false
    var player=game.get_node("Operator")
    player.set_physics_process(false)  # Prevent TPS controller from resetting this inspection camera.
    player.visible=false
    var camera: Camera3D=player.get_node("CameraPivot/ThirdPersonCamera") as Camera3D
    camera.top_level=true
    camera.global_position=Vector3(18,38,83)
    camera.look_at(Vector3(20,7,38),Vector3.UP)
    camera.fov=61.0
    camera.current=true
    for i in range(12):
        await process_frame
    await RenderingServer.frame_post_draw
    var screenshot: Image=root.get_texture().get_image()
    var code: Error=screenshot.save_png("res://out/aurora-v75-18-coastal-quarter.png")
    if code!=OK:
        push_error("COASTAL_3D_RENDER_CAPTURE_FAILED "+str(code))
        quit(1)
        return
    camera.global_position=Vector3(5,20,73)
    camera.look_at(Vector3(18,9,41),Vector3.UP)
    camera.fov=54.0
    for i in range(12):
        await process_frame
    await RenderingServer.frame_post_draw
    var street: Image=root.get_texture().get_image()
    if street.save_png("res://out/aurora-v75-18-coastal-street.png")!=OK:
        push_error("COASTAL_3D_STREET_CAPTURE_FAILED")
        quit(2)
        return
    print("COASTAL_3D_RENDER_PASS ",screenshot.get_width(),"x",screenshot.get_height())
    quit(0)
