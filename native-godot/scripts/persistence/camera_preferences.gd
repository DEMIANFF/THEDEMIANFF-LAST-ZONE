extends RefCounted
## Separate from match records: changing sensitivity never rewrites progression.
const DEFAULT_PATH: String="user://aurora_camera.cfg"
var path: String=DEFAULT_PATH
var look: float=1.0
var ads: float=1.0
var recovered: bool=false

func _init(custom_path: String=DEFAULT_PATH) -> void:
    path=custom_path
    if not _read(path):
        recovered=_read(path+".tmp") or _read(path+".bak")

func _read(file: String) -> bool:
    var config:=ConfigFile.new()
    if config.load(file)!=OK:
        return false
    var values: Array=[]
    for key in ["look","ads"]:
        if not config.has_section_key("camera",key):
            return false
        var value: Variant=config.get_value("camera",key)
        if not (value is float or value is int) or not is_finite(float(value)) or float(value)<.35 or float(value)>2.5:
            return false
        values.append(float(value))
    look=values[0]
    ads=values[1]
    return true

func save(new_look: float,new_ads: float) -> Error:
    if not is_finite(new_look) or not is_finite(new_ads):
        return ERR_INVALID_PARAMETER
    var config:=ConfigFile.new()
    config.set_value("camera","look",clampf(new_look,.35,2.5))
    config.set_value("camera","ads",clampf(new_ads,.35,2.5))
    var result:=config.save(path+".tmp")
    if result!=OK:
        return result
    # Preserve a known-valid backup, even if a damaged primary was recovered.
    var prior_look:=look
    var prior_ads:=ads
    if _read(path):
        result=DirAccess.copy_absolute(path,path+".bak")
        if result!=OK:
            look=prior_look
            ads=prior_ads
            return result
    result=DirAccess.rename_absolute(path+".tmp",path)
    if result==OK:
        _read(path)
        recovered=false
    return result
