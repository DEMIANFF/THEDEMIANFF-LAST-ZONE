extends SceneTree
## V75.46: prove the source stays a safe GL compatibility control while
## Android builds may opt into Vulkan Mobile through the supported override.
## Never confuse requested project configuration with actual GPU runtime.
const PERF=preload("res://scripts/persistence/aurora_performance_report.gd")
const RENDER=preload("res://scripts/render/aurora_render_budget.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V7546_RENDER_AB "+message)

func _verify() -> void:
    var desktop: String=str(ProjectSettings.get_setting(
        "rendering/renderer/rendering_method"))
    check(desktop=="gl_compatibility",
        "desktop and existing headless QA must retain proven OpenGL baseline")
    var requested_mobile: String=str(ProjectSettings.get_setting(
        "rendering/renderer/rendering_method.mobile","gl_compatibility"))
    check(requested_mobile in ["gl_compatibility","mobile"],
        "Android build requested an invalid rendering method")
    check(bool(ProjectSettings.get_setting(
        "rendering/textures/vram_compression/import_etc2_astc",false)),
        "Godot ETC2/ASTC platform texture compression must remain enabled")
    check(int(Engine.physics_ticks_per_second)==60,
        "camera, movement, fall and bot physics are still validated at 60 Hz")
    check(RENDER.PROFILES==["AUTO","CLARIDAD","EQUILIBRADO","FLUIDEZ"],
        "render governor profile compatibility was changed unexpectedly")

    # Verify we record TRUE runtime backend. A headless GPU might return a
    # dummy renderer; no assertion claims Vulkan is active on Motorola here.
    var actually_used: String=RenderingServer.get_current_rendering_method()
    var actual_driver: String=RenderingServer.get_current_rendering_driver_name()
    var data: Array[float]=[29.0,40.0,54.0,61.0]
    check(PERF.record(20,data,19.0,true)==OK,
        "could not save measured match report with renderer details")
    var report: Dictionary=PERF.latest()
    check(str(report.get("render_method",""))==actually_used and
        str(report.get("render_driver",""))==actual_driver and
        int(report.get("participants",0))==20 and
        absf(float(report.get("average_fps",0.0))-46.0)<.1,
        "actual renderer / driver or real frame samples were not persisted")
    check(float(report.get("quality_scale",0))>.0 and
        float(report.get("quality_scale",0))<=1.0,
        "match report is missing actual 3D resolution")

    var scene: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(scene)
    await process_frame
    check(scene.get_node_or_null("AuroraRenderBudget")!=null and
        scene.get_node_or_null("CombatRange")!=null and
        scene.get_node_or_null("AuroraSectorMatch")!=null,
        "renderer A/B comparison must preserve full battle and adaptive 3D")
    var renderer: Node=scene.get_node("AuroraRenderBudget")
    check(renderer.has_method("snapshot") and
        float(renderer.call("snapshot").get("scale",0))>=.78,
        "no valid graphics budget for mobile renderer experiment")
    if not failed:
        print("V7546_RENDER_AB PASS requested_mobile=",requested_mobile,
            " desktop_gl=1 hardware_runtime_not_claimed=1 ",
            "match_20fps_reported=1 quality_profiles=4 physics_60=1")
    quit(1 if failed else 0)
