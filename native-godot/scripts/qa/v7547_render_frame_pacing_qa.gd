extends SceneTree
## V75.47 regression: synthetic inputs test math only, never claim real FPS.
const RENDER=preload("res://scripts/render/aurora_render_budget.gd")
const PERF=preload("res://scripts/persistence/aurora_performance_report.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7547_FRAME_PACING "+reason)

func _verify() -> void:
    check(RENDER.target_fps_for_cap(30,60.0)==30.0,
        "30 FPS user cap lost")
    check(RENDER.target_fps_for_cap(60,120.0)==60.0,
        "60 FPS user cap lost")
    check(RENDER.target_fps_for_cap(90,120.0)==90.0,
        "90 FPS user cap lost")
    check(RENDER.target_fps_for_cap(120,120.0)==120.0,
        "120 Hz panel incorrectly capped at 60 FPS")
    check(RENDER.target_fps_for_cap(120,60.0)==60.0,
        "60 Hz panel falsely targeted at 120 FPS")
    check(RENDER.target_fps_for_cap(0,90.0)==90.0,
        "uncapped mode ignored panel refresh")
    check(RENDER.target_fps_for_cap(300,240.0)==120.0,
        "unsupported refresh requested")
    check(RENDER.classify_bottleneck(39.0,60.0,22.0,25.0)=="CPU_BOUND",
        "CPU-limited AI frame must not trigger GPU resolution downgrade")
    check(RENDER.classify_bottleneck(39.0,60.0,5.0,25.0)=="RENDER_OR_DRIVER",
        "slow render/driver frame not identified")
    check(RENDER.classify_bottleneck(60.0,60.0,5.0,16.7)=="ON_TARGET",
        "on-target frame flagged as slow")
    check(RENDER.classify_bottleneck(-1.0,60.0,5.0,16.7)=="INVALID",
        "invalid FPS classified as a real hardware bottleneck")
    check(absf(RENDER.lower_step(.94)-.86)<.001 and
        absf(RENDER.higher_step(.78)-.86)<.001,
        "quality resolution step regression")
    check(RENDER.save_profile("AUTO")==OK,"cannot restore AUTO profile")

    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    await process_frame
    var budget: Node=game.get_node("AuroraRenderBudget")
    var snapshot: Dictionary=budget.call("snapshot")
    for key in ["fps","target_fps","refresh_hz","cpu_ms","frame_ms",
            "draw_calls","objects","bottleneck","scale","adjustments"]:
        check(snapshot.has(key),"missing runtime measurement field: "+key)
    check(float(snapshot.get("scale",0))>=.78 and
        float(snapshot.get("scale",0))<=1.0,
        "rendering scale violates mobile bounds")
    check(game.get_node_or_null("TrainingHUD")!=null and
        game.get_node_or_null("AuroraSectorMatch")!=null,
        "performance patch lost real HUD or match director")

    var samples: Array[float]=[30.0,45.0,60.0,90.0,120.0]
    check(PERF.record(20,samples,10.0,true)==OK,"benchmark save failed")
    var latest: Dictionary=PERF.latest()
    check(absf(float(latest.get("median_fps",0.0))-60.0)<.1 and
        absf(float(latest.get("p90_fps",0.0))-90.0)<.1,
        "real sampled P50/P90 were not persisted")
    check(PERF.record(20,samples,-1.0,true)==ERR_INVALID_PARAMETER,
        "negative duration incorrectly accepted")
    check(PERF.record(20,samples,INF,true)==ERR_INVALID_PARAMETER,
        "infinite duration incorrectly accepted")
    check(RENDER.save_profile("AUTO")==OK,"cannot reset profile")
    if not failed:
        print("V7547_FRAME_PACING PASS panel30_60_90_120=1 "+
            "cpu_render_guard=1 hud_native=1 quantiles=1")
    quit(1 if failed else 0)
