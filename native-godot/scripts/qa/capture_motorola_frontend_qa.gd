extends SceneTree
## Original in-engine UI captures, rendered at actual 964x434 viewport.
## This is software OpenGL desktop evidence, not a Motorola hardware test.
const CAPTURE_VERSION=preload("res://scripts/qa/aurora_capture_version.gd")


func _initialize() -> void:
    call_deferred("_capture")


func _save(stage_label: String) -> bool:
    var image: Image=root.get_texture().get_image()
    if image.get_width()!=964 or image.get_height()!=434:
        push_error("V75113_MOTOROLA_CAPTURE wrong resolution "+
            str(image.get_size())+" for "+stage_label)
        return false
    var path: String="res://out/aurora-"+CAPTURE_VERSION.tag()+
        "-motorola-"+stage_label+".png"
    if image.save_png(path)!=OK:
        push_error("V75113_MOTOROLA_CAPTURE failed "+path)
        return false
    print("V75113_MOTOROLA_CAPTURE "+stage_label+" "+str(image.get_size()))
    return true


func _capture() -> void:
    root.size=Vector2i(964,434)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await RenderingServer.frame_post_draw
    if not _save("loading"):
        quit(1)
        return
    await front.wait_for_startup()
    for frame in range(7):
        await process_frame
    front._layout_safe()
    await RenderingServer.frame_post_draw
    if not _save("login"):
        quit(2)
        return
    front._enter_local_lobby()
    for frame in range(12):
        await process_frame
    front._layout_safe()
    await RenderingServer.frame_post_draw
    if not _save("lobby"):
        quit(3)
        return
    front._welcome()
    front.queue_free()
    await process_frame
    print("V75113_MOTOROLA_CAPTURE PASS real_godot=1 "+
        "screens=loading,login,lobby native_vulkan_phone=not_tested")
    quit(0)
