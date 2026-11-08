extends SceneTree
var failed: bool=false

func _initialize() -> void:
    call_deferred("verify")

func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V753_FRONTEND "+message)

func verify() -> void:
    var front: Control=load("res://scenes/Boot.tscn").instantiate()
    root.add_child(front)
    front._show_lobby()
    front._select_tab("AJUSTES")
    for resolution in [Vector2i(1280,720),Vector2i(2712,1220),Vector2i(1024,768)]:
        root.size=resolution
        await process_frame
        await process_frame
        front._layout_safe()
        var visible:=root.get_visible_rect()
        check(visible.encloses(front._look_slider.get_global_rect()),"look slider outside screen")
        check(visible.encloses(front._ads_slider.get_global_rect()),"ADS slider outside screen")
        for button in front.find_children("*","Button",true,false):
            if button.is_visible_in_tree():
                check(visible.encloses(button.get_global_rect()),"lobby action outside screen "+str(button.name))
    front._look_slider.value=1.65
    front._ads_slider.value=.8
    front._save_preferences()
    front._launch(false)
    for i in range(10):
        await process_frame
    check(front.stage=="training" and front._game!=null,"lobby launch failed")
    if front._game:
        var player=front._game.get_node("Operator")
        check(is_equal_approx(player.look_multiplier,1.65) and is_equal_approx(player.ads_multiplier,.8),"saved sensitivity not applied in game")
        front._return_to_lobby()
        await process_frame
        check(front.stage=="lobby" and front._game==null,"return to lobby failed")
    print("V753_FRONTEND PASS: responsive settings, saved sensitivity, launch and return")
    quit(1 if failed else 0)
