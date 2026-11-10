extends SceneTree
## Software OpenGL capture for build review, not Android device acceptance.
func _initialize() -> void:
    call_deferred("_capture")
func _capture() -> void:
    var scene: PackedScene = load("res://scenes/Main.tscn")
    var instance: Node3D = scene.instantiate()
    root.add_child(instance)
    await process_frame
    # The CI image must show actual battle mode, not only the old training scene.
    var hud:=instance.get_node("TrainingHUD") as CanvasLayer
    hud._battle_down()
    for n in range(6):
        await process_frame
    var screenshot: Image = root.get_texture().get_image()
    var result: Error = screenshot.save_png("res://out/aurora-native-v75-15-preview.png")
    if result != OK:
        push_error("Render capture failed: "+str(result))
        quit(1)
        return
    print("Aurora CI capture:",screenshot.get_width(),"x",screenshot.get_height())
    quit(0)
