extends RefCounted
## Unified local options; independent from the irreversible match ledger.
## Imported assets and Firebase state are deliberately not modified.
const DEFAULT_PATH: String="user://ajustes.cfg"
const CAMERA_KEYS: Array[String]=["general","ads","red_dot","scope_2x","scope_4x","scope_8x"]
const CAMERA_DEFAULTS: Dictionary={
    "general":100.0,"ads":100.0,"red_dot":100.0,
    "scope_2x":90.0,"scope_4x":75.0,"scope_8x":50.0
}
# An actual 120Hz phone can request 120 render FPS without doubling the
# 60Hz collision/AI physics workload. Users can select lower caps for heat.
const GRAPHICS_PRESETS: Array[String]=["baja","media","alta","ultra","extrema"]
const GRAPHICS_FPS: Dictionary={"baja":30,"media":45,"alta":60,"ultra":90,"extrema":120}
var path: String=DEFAULT_PATH
var sensitivity: Dictionary=CAMERA_DEFAULTS.duplicate(true)
# V75.25 high-refresh preview defaults to the 120 FPS ceiling;
# this does not promise 120 measured FPS, which depends on hardware/OS.
var graphics_preset: String="extrema"
var recovered: bool=false
var loaded: bool=false
var legacy_imported: bool=false


func _init(custom_path: String=DEFAULT_PATH) -> void:
    path=custom_path
    if _read(path):
        loaded=true
    elif _read(path+".tmp") or _read(path+".bak"):
        loaded=true
        recovered=true
    elif path==DEFAULT_PATH:
        # One-way read-only migration. Existing installs retain old look/ADS
        # until the player explicitly changes and saves the new settings.
        _import_legacy_camera()


func _parse(cfg: ConfigFile) -> Dictionary:
    # A malformed or empty file MUST NOT masquerade as a valid profile just
    # because ConfigFile.get_value() has defaults: otherwise .bak is ignored.
    if not cfg.has_section("sensibilidad") or not cfg.has_section("graficos"):
        return {}
    if not cfg.has_section_key("graficos","preset"):
        return {}
    var values: Dictionary={}
    for key in CAMERA_KEYS:
        if not cfg.has_section_key("sensibilidad",key):
            return {}
        var raw: Variant=cfg.get_value("sensibilidad",key,CAMERA_DEFAULTS[key])
        if not (raw is float or raw is int) or not is_finite(float(raw)):
            return {}
        if float(raw)<0.0 or float(raw)>200.0:
            return {}
        values[key]=float(raw)
    var raw_preset: Variant=cfg.get_value("graficos","preset","media")
    if not (raw_preset is String) or not GRAPHICS_PRESETS.has(str(raw_preset)):
        return {}
    return {"sensitivity":values,"preset":str(raw_preset)}


func _read(file: String) -> bool:
    var cfg:=ConfigFile.new()
    if cfg.load(file)!=OK:
        return false
    var parsed: Dictionary=_parse(cfg)
    if parsed.is_empty():
        return false
    sensitivity=(parsed["sensitivity"] as Dictionary).duplicate(true)
    graphics_preset=str(parsed["preset"])
    return true


func _import_legacy_camera() -> void:
    var cfg:=ConfigFile.new()
    if cfg.load("user://aurora_camera.cfg")!=OK:
        return
    var old_look: Variant=cfg.get_value("camera","look",1.0)
    var old_ads: Variant=cfg.get_value("camera","ads",1.0)
    if not (old_look is int or old_look is float) or not (old_ads is int or old_ads is float):
        return
    if not is_finite(float(old_look)) or not is_finite(float(old_ads)):
        return
    if float(old_look)<.35 or float(old_look)>2.5 or float(old_ads)<.35 or float(old_ads)>2.5:
        return
    sensitivity["general"]=clampf(float(old_look)*100.0,0.0,200.0)
    sensitivity["ads"]=clampf(float(old_ads)*100.0,0.0,200.0)
    legacy_imported=true


func multiplier(key: String) -> float:
    # Internally 100 means the existing baseline speed; 200 means 2x.
    return float(sensitivity.get(key,100.0))/100.0


func fps_limit() -> int:
    return int(GRAPHICS_FPS.get(graphics_preset,120))


func save_sensitivity(changes: Dictionary) -> Error:
    var next: Dictionary=sensitivity.duplicate(true)
    for raw_key in changes.keys():
        var key: String=str(raw_key)
        if not CAMERA_KEYS.has(key):
            return ERR_INVALID_PARAMETER
        var value: Variant=changes[raw_key]
        if not (value is int or value is float) or not is_finite(float(value)):
            return ERR_INVALID_PARAMETER
        if float(value)<0.0 or float(value)>200.0:
            return ERR_INVALID_PARAMETER
        next[key]=float(value)
    return _commit(next,graphics_preset)


func save_graphics(preset: String) -> Error:
    if not GRAPHICS_PRESETS.has(preset):
        return ERR_INVALID_PARAMETER
    return _commit(sensitivity.duplicate(true),preset)


func _commit(next: Dictionary,preset: String) -> Error:
    var cfg:=ConfigFile.new()
    for key in CAMERA_KEYS:
        cfg.set_value("sensibilidad",key,float(next[key]))
    cfg.set_value("graficos","preset",preset)
    cfg.set_value("graficos","fps_limit",int(GRAPHICS_FPS[preset]))
    var code: Error=cfg.save(path+".tmp")
    if code!=OK:
        return code
    # Never copy an unreadable primary over a valid recovery .bak.
    var previous:=ConfigFile.new()
    if previous.load(path)==OK and not _parse(previous).is_empty():
        code=DirAccess.copy_absolute(path,path+".bak")
        if code!=OK:
            return code
    code=DirAccess.rename_absolute(path+".tmp",path)
    if code==OK:
        sensitivity=next.duplicate(true)
        graphics_preset=preset
        recovered=false
        loaded=true
    return code
