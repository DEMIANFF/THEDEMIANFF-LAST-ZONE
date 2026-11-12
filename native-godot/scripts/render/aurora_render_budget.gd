extends Node
## Compatibility/OpenGL-compatible 3D resolution governor. 2D touch HUD and
## subtitles stay native-resolution. No FSR/Vulkan assumption on Motorola.
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

var profile: String="AUTO"
var current_scale: float=.94
var changes: int=0
var last_draw_calls: int=0
var last_rendered_objects: int=0
var last_fps: float=0.0
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
    if profile!="AUTO":
        return
    # Export startup, aircraft rig load and scene transitions spike briefly.
    # Do not permanently degrade detail because of one such frame.
    if Time.get_ticks_msec()*.001-_startup_time<12.0:
        return
    _sample_clock+=delta
    if _sample_clock<SAMPLE_INTERVAL:
        return
    _sample_clock-=SAMPLE_INTERVAL
    last_fps=float(Engine.get_frames_per_second())
    last_draw_calls=int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
    last_rendered_objects=int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
    if last_fps<5.0 or last_fps>250.0:
        return
    var ceiling: int=Engine.max_fps
    var target: float=float(mini(60,ceiling)) if ceiling>0 else 60.0
    var process_ms: float=1000.0*(
        Performance.get_monitor(Performance.TIME_PROCESS)+
        Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
    var frame_ms: float=1000.0/maxf(last_fps,1.0)
    # Severe CPU bottlenecks need AI/navigation work, not GPU downscaling.
    var gpu_likely: bool=process_ms<frame_ms*.84
    if last_fps<target*.80 and gpu_likely:
        _low_samples+=1
        _good_samples=0
    elif last_fps>=target*.97:
        _good_samples+=1
        _low_samples=0
    else:
        _low_samples=0
        _good_samples=0
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


func snapshot() -> Dictionary:
    return {
        "profile":profile,
        "scale":current_scale,
        "draw_calls":last_draw_calls,
        "objects":last_rendered_objects,
        "fps":last_fps,
        "adjustments":changes
    }
