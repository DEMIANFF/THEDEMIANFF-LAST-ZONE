extends Node
## Vulkan Mobile / OpenGL 3D resolution governor. 2D touch HUD and text
## remain at native resolution, independent of the 3D scaling factor.
##
## A sustained drop in FPS only scales 3D *when CPU frame time indicates the
## GPU/driver may be the bottleneck*. Slow AI/pathfinding is not "fixed" by
## blurring pixels. Quality returns with long recovery hysteresis.

const OPTIONS_FILE: String="user://aurora_render_quality.cfg"
const PROFILES: Array[String]=["AUTO","CLARIDAD","EQUILIBRADO","FLUIDEZ"]
const STEPS: Array[float]=[.78,.86,.94,1.0]
const SAMPLE_INTERVAL: float=.75
const BAD_SAMPLES: int=9
const GOOD_SAMPLES: int=18
const MAX_TARGET_FPS: float=120.0
const SAMPLE_WARMUP_SECONDS: float=12.0
const CPU_FRAME_RATIO: float=.84

var profile: String="AUTO"
var current_scale: float=.94
var changes: int=0
var last_draw_calls: int=0
var last_rendered_objects: int=0
var last_fps: float=0.0
var last_target_fps: float=60.0
var last_refresh_hz: float=0.0
var last_cpu_ms: float=0.0
var last_frame_ms: float=0.0
var last_bottleneck: String="NOT_SAMPLED"
var _sample_clock: float=0.0
var _low_samples: int=0
var _good_samples: int=0
var _startup_time: float=0.0


static func read_profile() -> String:
    var cfg:=ConfigFile.new()
    if cfg.load(OPTIONS_FILE)!=OK:
        return "AUTO"
    var value: String=str(cfg.get_value("render","preset","AUTO"))
    return value if PROFILES.has(value) else "AUTO"


static func save_profile(value: String) -> Error:
    if not PROFILES.has(value):
        return ERR_INVALID_PARAMETER
    var cfg:=ConfigFile.new()
    cfg.set_value("render","preset",value)
    return cfg.save(OPTIONS_FILE)


static func preferred_scale(preset: String) -> float:
    match preset:
        "CLARIDAD":
            return 1.0
        "EQUILIBRADO":
            return .90
        "FLUIDEZ":
            return .78
        _:
            return .94


static func lower_step(current: float) -> float:
    for i in range(STEPS.size()-1,-1,-1):
        if STEPS[i]<current-.015:
            return STEPS[i]
    return STEPS[0]


static func higher_step(current: float) -> float:
    for step in STEPS:
        if step>current+.015:
            return step
    return STEPS[STEPS.size()-1]


## Respect both the player's cap and the panel's real refresh rate.
static func target_fps_for_cap(cap: int,refresh_hz: float) -> float:
    var target: float=60.0
    if cap>0:
        target=clampf(float(cap),15.0,MAX_TARGET_FPS)
    elif is_finite(refresh_hz) and refresh_hz>=30.0:
        target=minf(refresh_hz,MAX_TARGET_FPS)
    if is_finite(refresh_hz) and refresh_hz>=30.0:
        target=minf(target,refresh_hz)
    return clampf(target,15.0,MAX_TARGET_FPS)


## Reducing render resolution will not fix CPU-heavy AI navigation.
static func classify_bottleneck(fps: float,target: float,
        cpu_ms: float,frame_ms: float) -> String:
    if not is_finite(fps) or not is_finite(target) or not is_finite(cpu_ms) or not is_finite(frame_ms):
        return "INVALID"
    if fps<=0.0 or target<=0.0 or frame_ms<=0.0 or cpu_ms<0.0:
        return "INVALID"
    if fps>=target*.80:
        return "ON_TARGET"
    if cpu_ms>=frame_ms*CPU_FRAME_RATIO:
        return "CPU_BOUND"
    return "RENDER_OR_DRIVER"


func _ready() -> void:
    name="AuroraRenderBudget"
    _startup_time=Time.get_ticks_msec()*.001
    profile=read_profile()
    _apply_scale(preferred_scale(profile))
    if DisplayServer.get_name()=="headless":
        set_process(false)


func _apply_scale(next: float) -> void:
    current_scale=clampf(next,.78,1.0)
    var viewport: Viewport=get_viewport()
    if viewport==null:
        return
    viewport.scaling_3d_mode=Viewport.SCALING_3D_MODE_BILINEAR
    viewport.scaling_3d_scale=current_scale


func select_profile(value: String) -> Error:
    var result: Error=save_profile(value)
    if result!=OK:
        return result
    profile=value
    _low_samples=0
    _good_samples=0
    _apply_scale(preferred_scale(profile))
    return OK


func _process(delta: float) -> void:
    if not is_finite(delta) or delta<0.0:
        return
    # Initial terrain, 3D rig and sky creation must not trigger downscaling.
    if Time.get_ticks_msec()*.001-_startup_time<SAMPLE_WARMUP_SECONDS:
        return
    _sample_clock+=minf(delta,1.0)
    if _sample_clock<SAMPLE_INTERVAL:
        return
    _sample_clock=fmod(_sample_clock,SAMPLE_INTERVAL)
    # Diagnostics update even when a fixed user profile is selected.
    last_fps=float(Engine.get_frames_per_second())
    last_draw_calls=int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
    last_rendered_objects=int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
    if not is_finite(last_fps) or last_fps<5.0 or last_fps>250.0:
        last_bottleneck="INVALID"
        return
    last_refresh_hz=float(DisplayServer.screen_get_refresh_rate())
    last_target_fps=target_fps_for_cap(Engine.max_fps,last_refresh_hz)
    last_cpu_ms=1000.0*(
        Performance.get_monitor(Performance.TIME_PROCESS)+
        Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
    last_frame_ms=1000.0/maxf(last_fps,1.0)
    last_bottleneck=classify_bottleneck(
        last_fps,last_target_fps,last_cpu_ms,last_frame_ms)
    if profile!="AUTO":
        _low_samples=0
        _good_samples=0
        return
    if last_bottleneck=="RENDER_OR_DRIVER":
        _low_samples+=1
        _good_samples=0
    elif last_bottleneck=="ON_TARGET" and last_fps>=last_target_fps*.97:
        _good_samples+=1
        _low_samples=0
    else:
        _low_samples=0
        _good_samples=0
    # Hysteresis prevents rapid quality oscillation in the Mobile renderer.
    if _low_samples>=BAD_SAMPLES:
        _low_samples=0
        var lower: float=lower_step(current_scale)
        if lower<current_scale-.01:
            _apply_scale(lower)
            changes+=1
    elif _good_samples>=GOOD_SAMPLES:
        _good_samples=0
        var upper: float=higher_step(current_scale)
        if upper>current_scale+.01:
            _apply_scale(upper)
            changes+=1

func _exit_tree() -> void:
    # Restore the 3D scale for the standalone login/lobby viewport.
    # The next battle reads the chosen profile again.
    var viewport: Viewport=get_viewport()
    if viewport!=null:
        viewport.scaling_3d_scale=1.0


func snapshot() -> Dictionary:
    return {
        "profile":profile,
        "scale":current_scale,
        "draw_calls":last_draw_calls,
        "objects":last_rendered_objects,
        "fps":last_fps,
        "target_fps":last_target_fps,
        "refresh_hz":last_refresh_hz,
        "cpu_ms":last_cpu_ms,
        "frame_ms":last_frame_ms,
        "bottleneck":last_bottleneck,
        "adjustments":changes
    }
