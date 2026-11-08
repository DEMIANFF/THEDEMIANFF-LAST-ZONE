extends SceneTree
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool, message: String) -> void:
    if not ok:
        failed=true
        push_error("RESPONSIVE "+message)

func _verify() -> void:
    check(ProjectSettings.get_setting("display/window/stretch/aspect")=="expand","fixed aspect")
    check(ProjectSettings.get_setting("display/window/handheld/orientation")==DisplayServer.SCREEN_SENSOR_LANDSCAPE,"landscape orientation")
    root.content_scale_size=Vector2i(1280,720)
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
    var game: Node=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var hud=game.get_node("TrainingHUD")
    var overlay: Control=hud.get_node("AuroraTacticalOverlay")
    for resolution in [Vector2i(1280,720),Vector2i(2712,1220),Vector2i(2400,1080),Vector2i(1024,768)]:
        root.size=resolution
        await process_frame
        await process_frame
        hud._layout()
        var visible: Rect2=root.get_visible_rect()
        check(absf(visible.size.aspect()-Vector2(resolution).aspect())<.01,"viewport bars "+str(resolution))
        var actions: Array[Control]=[]
        for child in overlay.get_children():
            if child is Button or child.name in ["MovePad","DirectionalFirePad"]:
                if child.visible:
                    actions.append(child)
                    check(visible.encloses(child.get_global_rect()),"outside viewport "+child.name)
        for i in range(actions.size()):
            for j in range(i+1,actions.size()):
                check(not actions[i].get_global_rect().intersects(actions[j].get_global_rect()),"overlap "+actions[i].name+" / "+actions[j].name)
        for stage in ["aircraft","freefall","parachute","ground"]:
            hud.set_air_stage(stage)
            check(visible.encloses(hud._jump_button.get_global_rect()),"air action outside viewport")
        print("RESPONSIVE_LAYOUT ",resolution," viewport=",visible.size)
    quit(1 if failed else 0)
