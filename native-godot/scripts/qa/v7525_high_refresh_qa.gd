extends SceneTree
## QA for Android high refresh: rendering up to 120 FPS while keeping
## physics/AI updates independent. New preview package has pinned signing
## enforced by the GitHub Actions export workflow (not available in GDScript).
const SETTINGS=preload("res://scripts/persistence/player_settings.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V7525_HIGH_REFRESH "+why)

func _verify() -> void:
    var test_path: String="user://qa/v7525-high-refresh.cfg"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_path).get_base_dir())
    for suffix in ["",".tmp",".bak"]:
        var absolute: String=ProjectSettings.globalize_path(test_path+suffix)
        if FileAccess.file_exists(absolute):
            DirAccess.remove_absolute(absolute)
    var settings=SETTINGS.new(test_path)
    check(settings.graphics_preset=="extrema" and settings.fps_limit()==120,
        "new 120Hz preview should request 120 render FPS by default")
    check(SETTINGS.GRAPHICS_PRESETS.size()==5 and
        SETTINGS.GRAPHICS_FPS["ultra"]==90 and
        SETTINGS.GRAPHICS_FPS["extrema"]==120,
        "missing 90/120 FPS user-selectable presets")
    for pair in [
        ["baja",30],["media",45],["alta",60],
        ["ultra",90],["extrema",120]
    ]:
        check(settings.save_graphics(str(pair[0]))==OK,
            "could not save "+str(pair[0]))
        var restored=SETTINGS.new(test_path)
        check(restored.loaded and restored.graphics_preset==pair[0] and
            restored.fps_limit()==int(pair[1]),
            "persisted FPS setting differs from selection "+str(pair))
    check(settings.save_graphics("220") == ERR_INVALID_PARAMETER,
        "unsafe unsupported FPS value should be rejected")
    # Headless Godot tests can report an uncapped project default (0).
    # Verify the real Boot scene executes the user's 120 FPS option instead.
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    check(Engine.max_fps==120,
        "real front-end did not activate the default 120 FPS ceiling")
    front.queue_free()
    await process_frame
    check(bool(ProjectSettings.get_setting(
        "display/window/frame_pacing/android/enable_frame_pacing",false)),
        "Android Swappy support has been disabled")
    check(int(ProjectSettings.get_setting(
        "display/window/frame_pacing/android/swappy_mode",-1))==0,
        "Android frame pacing must honor requested 120 FPS ceiling")
    # Do not set physics ticks to 120: changing AI/physics cadence could
    # regress freefall, input, movement, and the fixed Android audio crash.
    check(int(Engine.physics_ticks_per_second)==60,
        "render FPS should not double real physics/AI work")
    print("V7525_HIGH_REFRESH PASS 30/45/60/90/120 persisted, ",
        "120 ceiling, Android Swappy and 60-tick physics isolation")
    quit(1 if failed else 0)
