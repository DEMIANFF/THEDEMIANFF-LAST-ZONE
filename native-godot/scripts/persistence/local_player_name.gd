extends RefCounted
## Private device-only player nickname. A real numeric ID must be assigned
## by the authenticated Firebase callable, never generated in this file.
const DEFAULT_PATH: String="user://profiles/aurora_player_name_v1.cfg"
const DEFAULT_NAME: String="Operador"
const NAME_PATTERN: String="^[A-Za-z0-9ÁÉÍÓÚÜÑáéíóúüñ_]+( [A-Za-z0-9ÁÉÍÓÚÜÑáéíóúüñ_]+)*$"

var file_path: String=DEFAULT_PATH
var display_name: String=DEFAULT_NAME
var recovered: bool=false


func _init(path: String=DEFAULT_PATH) -> void:
    file_path=path
    if _load(file_path):
        return
    if _load(file_path+".tmp") or _load(file_path+".bak"):
        recovered=true


static func valid_name(value: String) -> bool:
    if value.length()<3 or value.length()>16 or value!=value.strip_edges():
        return false
    var rule:=RegEx.new()
    if rule.compile(NAME_PATTERN)!=OK or rule.search(value)==null:
        return false
    if value.to_upper() in ["ADMIN","ADMINISTRADOR","MODERADOR","SOPORTE",
            "THEDEMIAN","FIREBASE","SISTEMA"]:
        return false
    return true


func _load(path: String) -> bool:
    var data:=ConfigFile.new()
    if data.load(path)!=OK:
        return false
    if int(data.get_value("player","schema",0))!=1:
        return false
    var value: Variant=data.get_value("player","name",null)
    if not (value is String) or not valid_name(value):
        return false
    display_name=value
    return true


func save_name(value: String) -> Error:
    if not valid_name(value):
        return ERR_INVALID_PARAMETER
    var payload:=ConfigFile.new()
    payload.set_value("player","schema",1)
    payload.set_value("player","name",value)
    var full: String=ProjectSettings.globalize_path(file_path)
    if DirAccess.make_dir_recursive_absolute(full.get_base_dir())!=OK:
        return ERR_CANT_CREATE
    var tmp: String=file_path+".tmp"
    var code: Error=payload.save(tmp)
    if code!=OK:
        return code
    var verification:=ConfigFile.new()
    if verification.load(tmp)!=OK or int(verification.get_value(
            "player","schema",0))!=1 or verification.get_value(
            "player","name","")!=value:
        return ERR_FILE_CORRUPT
    # Back up only valid prior names; damaged files cannot replace recovery.
    var old:=ConfigFile.new()
    if old.load(file_path)==OK and valid_name(str(old.get_value(
            "player","name",""))):
        code=DirAccess.copy_absolute(
            ProjectSettings.globalize_path(file_path),
            ProjectSettings.globalize_path(file_path+".bak"))
        if code!=OK:
            return code
    code=DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp),full)
    if code==OK:
        display_name=value
        recovered=false
    return code
