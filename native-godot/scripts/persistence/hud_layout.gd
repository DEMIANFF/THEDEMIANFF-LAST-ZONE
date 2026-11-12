extends RefCounted
## Persistent, normalized, per-control touch HUD layout. Isolated from account,
## Firebase, signed APK identity, weapon ammo and save-game/ledger data.
const DEFAULT_PATH: String="user://aurora_hud_layout.cfg"
const ACTIVE_PATH: String="user://aurora_hud_preset.cfg"
const PRESET_COUNT: int=4


static func selected_preset() -> int:
    var cfg:=ConfigFile.new()
    if cfg.load(ACTIVE_PATH)!=OK:
        return 1
    return clampi(int(cfg.get_value("hud","slot",1)),1,PRESET_COUNT)


static func slot_path(slot: int) -> String:
    return DEFAULT_PATH if slot==1 else "user://aurora_hud_layout_%d.cfg"%slot


static func choose_preset(slot: int) -> Error:
    if slot<1 or slot>PRESET_COUNT:
        return ERR_INVALID_PARAMETER
    var cfg:=ConfigFile.new()
    cfg.set_value("hud","slot",slot)
    var result: Error=cfg.save(ACTIVE_PATH+".tmp")
    if result!=OK:
        return result
    return DirAccess.rename_absolute(ACTIVE_PATH+".tmp",ACTIVE_PATH)
const IDS: Array[String]=[
    "MovePad","DirectionalFirePad","CORRER","MIRA","RECARGA","ARMA",
    "SALTAR","AGACHAR","CURAR 2","BARRERA 0","MOCHILA","AJUSTES"
]
const MIN_SCALE: float=.72
const MAX_SCALE: float=1.32
const MIN_ALPHA: float=.35
var path: String=DEFAULT_PATH
var controls: Dictionary={}
var recovered: bool=false
var loaded: bool=false


func _init(custom_path: String=DEFAULT_PATH) -> void:
    # Old installs remain HUD 1. New HUD 2–4 are separate durable files:
    # changing presets cannot overwrite the player's original layout.
    path=slot_path(selected_preset()) if custom_path==DEFAULT_PATH else custom_path
    if _read(path):
        loaded=true
    elif _read(path+".tmp") or _read(path+".bak"):
        loaded=true
        recovered=true


func valid_id(id: String) -> bool:
    return IDS.has(id)


func get_item(id: String) -> Dictionary:
    if not valid_id(id) or not controls.has(id):
        return {}
    return (controls[id] as Dictionary).duplicate(true)


func set_item(id: String, center: Vector2, scale: float, alpha: float) -> Error:
    if not valid_id(id) or not center.is_finite() or not is_finite(scale) or             not is_finite(alpha):
        return ERR_INVALID_PARAMETER
    if center.x<0.0 or center.x>1.0 or center.y<0.0 or center.y>1.0 or             scale<MIN_SCALE or scale>MAX_SCALE or             alpha<MIN_ALPHA or alpha>1.0:
        return ERR_INVALID_PARAMETER
    controls[id]={
        "center":center,
        "scale":scale,
        "alpha":alpha
    }
    return OK


func restore_defaults() -> Error:
    return _persist({})


func save() -> Error:
    return _persist(controls)


func _read(candidate: String) -> bool:
    var cfg:=ConfigFile.new()
    if cfg.load(candidate)!=OK:
        return false
    var result: Dictionary=_parse(cfg)
    if not bool(result.get("valid",false)):
        return false
    controls=(result["controls"] as Dictionary).duplicate(true)
    return true


func _parse(cfg: ConfigFile) -> Dictionary:
    if not cfg.has_section_key("hud","version") or             cfg.get_value("hud","version",0)!=1:
        return {}
    var parsed: Dictionary={}
    var keys: PackedStringArray=cfg.get_section_keys("controls") if cfg.has_section("controls") else PackedStringArray()
    for key in keys:
        # A well-formed entry has center, scale and alpha keys. Only the
        # center key starts a new item; companion keys are checked below.
        if not str(key).ends_with("_center"):
            continue
        var id: String=str(key).trim_suffix("_center")
        if not valid_id(id) or parsed.has(id):
            return {}
        if not cfg.has_section_key("controls",id+"_scale") or                 not cfg.has_section_key("controls",id+"_alpha"):
            return {}
        var center: Variant=cfg.get_value("controls",id+"_center")
        var scale: Variant=cfg.get_value("controls",id+"_scale")
        var alpha: Variant=cfg.get_value("controls",id+"_alpha")
        if not center is Vector2 or not (scale is float or scale is int) or                 not (alpha is float or alpha is int):
            return {}
        if not (center as Vector2).is_finite() or not is_finite(float(scale)) or                 not is_finite(float(alpha)):
            return {}
        if center.x<0.0 or center.x>1.0 or center.y<0.0 or center.y>1.0 or                 float(scale)<MIN_SCALE or float(scale)>MAX_SCALE or                 float(alpha)<MIN_ALPHA or float(alpha)>1.0:
            return {}
        parsed[id]={"center":center,"scale":float(scale),"alpha":float(alpha)}
    # Unknown/unpaired values are a malformed partial write, not a valid save.
    if cfg.has_section("controls") and             cfg.get_section_keys("controls").size()!=parsed.size()*3:
        return {}
    return {"valid":true,"controls":parsed}


func _persist(next: Dictionary) -> Error:
    var cfg:=ConfigFile.new()
    cfg.set_value("hud","version",1)
    for id in IDS:
        if not next.has(id):
            continue
        var v: Dictionary=next[id]
        cfg.set_value("controls",id+"_center",v["center"])
        cfg.set_value("controls",id+"_scale",v["scale"])
        cfg.set_value("controls",id+"_alpha",v["alpha"])
    var code: Error=cfg.save(path+".tmp")
    if code!=OK:
        return code
    var old:=ConfigFile.new()
    if old.load(path)==OK and bool(_parse(old).get("valid",false)):
        code=DirAccess.copy_absolute(path,path+".bak")
        if code!=OK:
            return code
    code=DirAccess.rename_absolute(path+".tmp",path)
    if code==OK:
        controls=next.duplicate(true)
        recovered=false
        loaded=true
    return code
