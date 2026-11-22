extends SceneTree
## Regression of REAL AuroraRealSettings and gameplay, no duplicate
## CameraSettings/slider panel. Uses genuine UI signals and persists values.
const PLAYER_SETTINGS=preload("res://scripts/persistence/player_settings.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("verify")

func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V753_FRONTEND "+message)

func verify() -> void:
    root.size=Vector2i(964,434)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    front._show_lobby()
    front._top_settings_button.pressed.emit()
    var modal: CanvasLayer=front._settings_modal
    check(modal!=null and paused and front.stage=="lobby",
        "real settings unavailable without entering Training")
    if modal==null:
        front.queue_free()
        quit(1)
        return
    var options: RefCounted=modal.get("_options") as RefCounted
    var original_sensitivity: Dictionary=(options.get("sensitivity") as Dictionary).duplicate(true)
    var original_graphics: String=str(options.get("graphics_preset"))
    var original_fps: int=Engine.max_fps
    modal.call("_show_subcategory","SENSIBILIDAD")
    var look: HSlider=modal.find_child("Sensitivity_general",true,false) as HSlider
    var ads: HSlider=modal.find_child("Sensitivity_ads",true,false) as HSlider
    var two: HSlider=modal.find_child("Sensitivity_scope_2x",true,false) as HSlider
    var eight: HSlider=modal.find_child("Sensitivity_scope_8x",true,false) as HSlider
    check(look!=null and ads!=null and two!=null and eight!=null,
        "real camera, ADS and scope sliders are missing")
    for size in [Vector2i(1280,720),Vector2i(2712,1220),Vector2i(1024,768)]:
        root.size=size
        await process_frame
        await process_frame
        front._layout_safe()
        var panel: Control=modal.find_child("SettingsWindow",true,false) as Control
        check(panel!=null and
            root.get_visible_rect().grow(1).encloses(panel.get_global_rect()),
            "settings overlay exceeds landscape viewport "+str(size))
        check(front._bottom_navigation.get_child_count()==5,
            "duplicate footer HUD/PRESET actions reappeared")
    if look!=null and ads!=null and two!=null and eight!=null:
        look.value=165.0
        ads.value=80.0
        two.value=135.0
        eight.value=60.0
    var saved: RefCounted=PLAYER_SETTINGS.new()
    check(is_equal_approx(float(saved.call("multiplier","general")),1.65) and
        is_equal_approx(float(saved.call("multiplier","ads")),.80) and
        is_equal_approx(float(saved.call("multiplier","scope_2x")),1.35) and
        is_equal_approx(float(saved.call("multiplier","scope_8x")),.60),
        "visible slider changes did not persist actual camera sensitivity")
    modal.call("_show_category","PANTALLA")
    var graphics: OptionButton=modal.find_child("GraphicsSelector",true,false) as OptionButton
    check(graphics!=null and graphics.get_item_count()==5,
        "canonical screen FPS selector is absent")
    if graphics!=null:
        graphics.select(0)
        graphics.item_selected.emit(0)
    check(Engine.max_fps==30 and int(PLAYER_SETTINGS.new().call("fps_limit"))==30,
        "graphics FPS setting not applied/persisted")
    modal.call("_close")
    check(front._settings_modal==null and not paused,
        "closing canonical settings left lobby paused")
    front._launch(false)
    for i in range(16):
        await process_frame
    check(front.stage=="training" and front._game!=null,
        "real training launch failed")
    check(front._preview_container==null and front._preview_avatar==null,
        "lobby 3D world still allocated during gameplay")
    if front._game!=null:
        var player: CharacterBody3D=front._game.get_node("Operator")
        check(is_equal_approx(player.look_multiplier,1.65) and
            is_equal_approx(player.ads_multiplier,.80),
            "camera/ADS sensitivity did not reach live player")
        check(is_equal_approx(float(player._scope_sensitivity["scope_2x"]),1.35) and
            is_equal_approx(float(player._scope_sensitivity["scope_8x"]),.60),
            "scope sensitivities not connected to gameplay camera")
        front._return_to_lobby()
        for i in range(4):
            await process_frame
        check(front.stage=="lobby" and front._game==null and
            front._preview_container!=null and
            is_instance_valid(front._preview_container),
            "actual 3D lobby did not return after Training")
    check(options.call("save_sensitivity",original_sensitivity)==OK and
        options.call("save_graphics",original_graphics)==OK,
        "QA did not restore original local camera/FPS preferences")
    Engine.max_fps=original_fps
    front.queue_free()
    await process_frame
    if not failed:
        print("V753_FRONTEND PASS canonical_settings=1 responsive=1 "+
            "saved_camera=1 fps_cap=30 training=real 3d_lobby_return=1")
    quit(1 if failed else 0)
