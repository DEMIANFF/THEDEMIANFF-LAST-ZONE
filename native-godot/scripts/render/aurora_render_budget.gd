extends Node
## Vulkan Mobile / OpenGL 3D resolution governor. 2D touch HUD and text
## remain at native resolution, independent of the 3D scaling factor.
##
## A sustained drop in FPS only scales 3D *when CPU frame time indicates the
## GPU/driver may be the bottleneck*. Slow AI/pathfinding is not "fixed" by
## blurring pixels. Quality returns with long recovery hysteresis.

const OPTIONS_FILE: String="user://aurora_render_quality.cfg"
const PROFILES: Array[String]=["AUTO","CLARIDAD","EQUILIBRADO","FLUIDEZ","PERSONALIZADO"]
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
var _sun: DirectionalLight3D
var _environment: WorldEnvironment
var _nature: Node3D
var shadow_detail_enabled: bool=false
var fog_detail_enabled: bool=false
var layered_foliage_enabled: bool=true
var aa_detail: String="NONE"


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
    cfg.load(OPTIONS_FILE)
    cfg.set_value("render","preset",value)
    return cfg.save(OPTIONS_FILE)


## Persist independent 3D resolution, never the 2D canvas/HUD scale.
static func read_custom_scale() -> float:
    var cfg:=ConfigFile.new()
    if cfg.load(OPTIONS_FILE)!=OK:
        return .85
    var raw: Variant=cfg.get_value("render","custom_scale",.85)
    if not (raw is float or raw is int) or not is_finite(float(raw)):
        return .85
    return clampf(float(raw),.65,1.0)


static func save_custom_scale(value: float) -> Error:
    if not is_finite(value) or value<.65 or value>1.0:
        return ERR_INVALID_PARAMETER
    var cfg:=ConfigFile.new()
    cfg.load(OPTIONS_FILE)
    cfg.set_value("render","preset","PERSONALIZADO")
    cfg.set_value("render","custom_scale",snappedf(value,.05))
    return cfg.save(OPTIONS_FILE)


static func preferred_scale(preset: String) -> float:
    match preset:
        "CLARIDAD":
            return 1.0
        "EQUILIBRADO":
            return .90
        "FLUIDEZ":
            return .78
        "PERSONALIZADO":
            return read_custom_scale()
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


## Mobile renderer supports MSAA; Compatibility does not. The player
## never pays the cost of near-sun shadow maps on AUTO/FLUIDEZ by default.
## Synthetic inputs test the decision without claiming actual Motorola FPS.
static func quality_flags(preset: String,scale: float,
        method: String) -> Dictionary:
    var lowest: bool=(preset=="FLUIDEZ" or
        (preset=="AUTO" and scale<.86) or
        (preset=="PERSONALIZADO" and scale<.80))
    var clarity: bool=preset=="CLARIDAD"
    var msaa: bool=clarity and method=="mobile"
    return {
        "msaa":msaa,
        "fxaa":not msaa and not lowest,
        "sun_shadow":clarity and method=="mobile",
        "fog":not lowest,
        "foliage":not lowest
    }


func configure_scene(game: Node3D) -> void:
    # Called after the REAL scene and MultiMeshes are instantiated, without
    # rescanning the tree or allocating resources in each physics frame.
    _sun=game.get_node_or_null("ArcticSun") as DirectionalLight3D
    _environment=game.get_node_or_null("AuroraAtmosphere") as WorldEnvironment
    _nature=game.get_node_or_null("AuroraNature") as Node3D
    _apply_scene_quality()


func _apply_scene_quality() -> void:
    if not is_instance_valid(_environment) or not is_instance_valid(_sun):
        return
    var flags: Dictionary=quality_flags(
        profile,current_scale,RenderingServer.get_current_rendering_method())
    var viewport: Viewport=get_viewport()
    if viewport!=null:
        viewport.msaa_3d=(
            Viewport.MSAA_2X if bool(flags["msaa"]) else
            Viewport.MSAA_DISABLED)
        viewport.screen_space_aa=(
            Viewport.SCREEN_SPACE_AA_FXAA if bool(flags["fxaa"]) else
            Viewport.SCREEN_SPACE_AA_DISABLED)
    shadow_detail_enabled=bool(flags["sun_shadow"])
    fog_detail_enabled=bool(flags["fog"])
    layered_foliage_enabled=bool(flags["foliage"])
    aa_detail=("MSAA_2X" if bool(flags["msaa"]) else
        "FXAA" if bool(flags["fxaa"]) else "OFF")
    _sun.shadow_enabled=shadow_detail_enabled
    if _environment.environment!=null:
        _environment.environment.fog_enabled=fog_detail_enabled
    if is_instance_valid(_nature):
        _nature.call("set_visual_detail",layered_foliage_enabled)


func _ready() -> void:
    name="AuroraRenderBudget"
    _startup_time=Time.get_ticks_msec()*.001
    profile=read_profile()
    _apply_scale(preferred_scale(profile))
    if DisplayServer.get_name()=="headless":
        set_process(false)


func _apply_scale(next: float) -> void:
    current_scale=clampf(next,.65,1.0)
    var viewport: Viewport=get_viewport()
    if viewport==null:
        return
    viewport.scaling_3d_mode=Viewport.SCALING_3D_MODE_BILINEAR
    viewport.scaling_3d_scale=current_scale
    _apply_scene_quality()


func select_profile(value: String) -> Error:
    var result: Error=save_profile(value)
    if result!=OK:
        return result
    profile=value
    _low_samples=0
    _good_samples=0
    _apply_scale(preferred_scale(profile))
    return OK


## Called on slider release so Android does not write a config per touch event.
## Changes only the 3D viewport; the persisted four HUD layouts stay intact.
func select_custom_scale(value: float) -> Error:
    var result: Error=save_custom_scale(value)
    if result!=OK:
        return result
    profile="PERSONALIZADO"
    _low_samples=0
    _good_samples=0
    _apply_scale(read_custom_scale())
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
        viewport.msaa_3d=Viewport.MSAA_DISABLED
        viewport.screen_space_aa=Viewport.SCREEN_SPACE_AA_DISABLED


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
        "adjustments":changes,
        "sun_shadows":shadow_detail_enabled,
        "depth_fog":fog_detail_enabled,
        "pine_detail":layered_foliage_enabled,
        "antialiasing":aa_detail
    }
