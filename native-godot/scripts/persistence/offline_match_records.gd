extends RefCounted
## Durable, offline-only match statistics for the native Aurora client.
## No fake Google/Firebase account, no currency, no network; this belongs to
## the device-local user:// sandbox and never touches legacy V70 data.
const SCHEMA: int=1
const LIMIT: int=12

var file_path: String
var _data: Dictionary
var _loaded_backup: bool=false


func _init(path: String="user://profiles/aurora_local_v1.json") -> void:
    file_path=path
    _data=_defaults()
    reload()


func _defaults() -> Dictionary:
    return {
        "schema":SCHEMA,
        "next_match_id":1,
        "played":0,
        "wins":0,
        "kills":0,
        "survival_seconds":0,
        "best_kills":0,
        "longest_survival_seconds":0,
        "history":[]
    }


func _valid(value: Variant) -> bool:
    if not (value is Dictionary):
        return false
    var d: Dictionary=value
    if int(d.get("schema",-1))!=SCHEMA:
        return false
    for key in ["next_match_id","played","wins","kills","survival_seconds","best_kills","longest_survival_seconds"]:
        var v: Variant=d.get(key)
        if not (v is int or v is float):
            return false
        if int(v)<0:
            return false
    if int(d.get("next_match_id",0))<1 or int(d.get("wins",0))>int(d.get("played",0)):
        return false
    if not (d.get("history") is Array):
        return false
    var records: Array=d["history"]
    if records.size()>LIMIT:
        return false
    for record in records:
        if not (record is Dictionary):
            return false
        if not record.has("match_id") or not record.has("victory"):
            return false
    return true


func _load_file(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var contents: String=FileAccess.get_file_as_string(path)
    var parsed: Variant=JSON.parse_string(contents)
    if _valid(parsed):
        return parsed
    return {}


func reload() -> bool:
    _loaded_backup=false
    var primary: Dictionary=_load_file(file_path)
    if not primary.is_empty():
        _data=primary
        return true
    var backup: Dictionary=_load_file(file_path+".bak")
    if not backup.is_empty():
        _data=backup
        _loaded_backup=true
        push_warning("Recovered Aurora offline stats from local backup")
        return true
    _data=_defaults()
    return not FileAccess.file_exists(file_path) and not FileAccess.file_exists(file_path+".bak")


func snapshot() -> Dictionary:
    return _data.duplicate(true)


func next_match_id() -> int:
    return int(_data["next_match_id"])


func record_result(match_id: int,victory: bool,kills: int,survived_seconds: int) -> bool:
    # Monotonic ID provides idempotence: repeated _finish() cannot double-count.
    if match_id<=0 or match_id!=next_match_id():
        return false
    if kills<0 or kills>100 or survived_seconds<0 or survived_seconds>86400:
        return false
    var previous: Dictionary=_data.duplicate(true)
    _data["next_match_id"]=match_id+1
    _data["played"]=int(_data["played"])+1
    _data["wins"]=int(_data["wins"])+(1 if victory else 0)
    _data["kills"]=int(_data["kills"])+kills
    _data["survival_seconds"]=int(_data["survival_seconds"])+survived_seconds
    _data["best_kills"]=maxi(int(_data["best_kills"]),kills)
    _data["longest_survival_seconds"]=maxi(int(_data["longest_survival_seconds"]),survived_seconds)
    var history: Array=_data["history"]
    history.push_front({
        "match_id":match_id,
        "victory":victory,
        "kills":kills,
        "survived_seconds":survived_seconds,
        "saved_at_unix":int(Time.get_unix_time_from_system())
    })
    if history.size()>LIMIT:
        history.resize(LIMIT)
    if not _write_atomic():
        _data=previous
        return false
    return true


func _write_atomic() -> bool:
    var target: String=ProjectSettings.globalize_path(file_path)
    var backup: String=ProjectSettings.globalize_path(file_path+".bak")
    var temporary: String=ProjectSettings.globalize_path(file_path+".tmp")
    var dir: String=target.get_base_dir()
    if DirAccess.make_dir_recursive_absolute(dir)!=OK:
        push_error("Aurora offline stats directory creation failed")
        return false
    var output:=FileAccess.open(temporary,FileAccess.WRITE)
    if output==null:
        push_error("Aurora offline stats temporary file could not be opened")
        return false
    output.store_string(JSON.stringify(_data))
    output.flush()
    output.close()
    if FileAccess.file_exists(target) and not _loaded_backup:
        if DirAccess.copy_absolute(target,backup)!=OK:
            push_error("Aurora offline stats backup failed; retaining previous save")
            return false
    if DirAccess.rename_absolute(temporary,target)!=OK:
        push_error("Aurora offline stats atomic commit failed; retaining previous save")
        return false
    _loaded_backup=false
    return true
