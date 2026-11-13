extends RefCounted
## Durable, offline-only match statistics for the native Aurora client.
## No fake Google/Firebase account, premium currency or network; this belongs to
## the device-local user:// sandbox and never touches legacy V70 data.
const SCHEMA: int=1
const LIMIT: int=12
const LOCAL_COIN_LIMIT: int=1000000000
const AUTOBACKUP_SUFFIX: String=".auto"
# Optional per-match fields preserve schema-1 saves from all prior builds.
# Never rewrite legacy data or touch Firebase/Google identity collections.
const EXTENDED_LIMITS: Dictionary={
    "rank":100,"participants":100,"damage":500000,
    "accuracy":100,"loot":1000,"shots":20000,
    "hits":20000,"headshots":20000,"reloads":10000
}

var file_path: String
var _data: Dictionary
var _loaded_backup: bool=false
var _pending: Dictionary={}
var _load_failed: bool=false


func _init(path: String="user://profiles/aurora_local_v1.json") -> void:
    file_path=path
    _data=_defaults()
    reload()


func _defaults() -> Dictionary:
    return {
        "schema":SCHEMA,
        "next_match_id":1,
        "local_coins":0,
        "played":0,
        "wins":0,
        "kills":0,
        "survival_seconds":0,
        "best_kills":0,
        "longest_survival_seconds":0,
        "history":[]
    }


## Validate only actual measured, bounded fields. The record's extra
## metadata remains optional so previously signed journals still reopen.
static func _valid_extra_fields(extra: Dictionary) -> bool:
    for key in extra.keys():
        if not EXTENDED_LIMITS.has(key):
            return false
        var v: Variant=extra[key]
        if not (v is int or v is float):
            return false
        if not is_finite(float(v)) or float(v)!=float(int(v)):
            return false
        if int(v)<0 or int(v)>int(EXTENDED_LIMITS[key]):
            return false
    if extra.has("rank") and extra.has("participants"):
        if (int(extra["rank"])<1 or int(extra["participants"])<1 or
                int(extra["rank"])>int(extra["participants"])):
            return false
    if extra.has("hits") and extra.has("shots"):
        if int(extra["hits"])>int(extra["shots"]):
            return false
    if extra.has("headshots") and extra.has("hits"):
        if int(extra["headshots"])>int(extra["hits"]):
            return false
    if (extra.has("accuracy") and extra.has("shots") and
            int(extra["shots"])==0 and int(extra["accuracy"])>0):
        return false
    return true


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
        if not is_finite(float(v)) or float(v)!=float(int(v)) or int(v)<0:
            return false
    if int(d.get("next_match_id",0))<1 or int(d.get("wins",0))>int(d.get("played",0)):
        return false
    # Old schema-1 journals have no local_coins; migrate them as zero.
    if d.has("local_coins"):
        var coins: Variant=d["local_coins"]
        if (not (coins is int or coins is float) or not is_finite(float(coins)) or
                float(coins)!=float(int(coins)) or int(coins)<0 or
                int(coins)>LOCAL_COIN_LIMIT):
            return false
    if not (d.get("history") is Array):
        return false
    if int(d["next_match_id"])!=int(d["played"])+1:
        return false
    var records: Array=d["history"]
    if records.size()>LIMIT:
        return false
    for record in records:
        if not (record is Dictionary):
            return false
        if not (record.get("victory") is bool):
            return false
        for key in ["match_id","kills","survived_seconds","saved_at_unix"]:
            var field: Variant=record.get(key)
            if not (field is float or field is int) or not is_finite(float(field)) or float(field)!=float(int(field)) or int(field)<0:
                return false
        if int(record["match_id"])!=int(d["played"])-records.find(record):
            return false
        if int(record["kills"])>100 or int(record["survived_seconds"])>86400:
            return false
        # Coins are earned only by actual stored BR results, never by a UI click.
        if record.has("local_coins_awarded"):
            var award: Variant=record["local_coins_awarded"]
            if (not (award is int or award is float) or not is_finite(float(award)) or
                    float(award)!=float(int(award)) or int(award)!=local_coin_reward(
                    bool(record["victory"]),int(record["kills"]),
                    int(record["survived_seconds"]))):
                return false
        var extra: Dictionary={}
        for key in EXTENDED_LIMITS.keys():
            if record.has(key):
                extra[key]=record[key]
        if not _valid_extra_fields(extra):
            return false
    return true


func _load_file(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var contents: String=FileAccess.get_file_as_string(path)
    var parser:=JSON.new()
    if parser.parse(contents)!=OK:
        return {}
    var parsed: Variant=parser.data
    if parsed is Dictionary and parsed.has("payload"):
        var payload: Variant=parsed.get("payload")
        if not (payload is String) or payload.sha256_text()!=parsed.get("sha256"):
            return {}
        if parser.parse(payload)!=OK:
            return {}
        parsed=parser.data
    if _valid(parsed):
        # JSON parses numbers as floats; keep the ledger's canonical integer
        # types before comparing the verified journal with the in-memory data.
        for key in ["schema","next_match_id","played","wins","kills","survival_seconds","best_kills","longest_survival_seconds"]:
            parsed[key]=int(parsed[key])
        parsed["local_coins"]=int(parsed.get("local_coins",0))
        for record in parsed["history"]:
            if record.has("local_coins_awarded"):
                record["local_coins_awarded"]=int(record["local_coins_awarded"])
            for key in ["match_id","kills","survived_seconds","saved_at_unix"]:
                record[key]=int(record[key])
            for key in EXTENDED_LIMITS.keys():
                if record.has(key):
                    record[key]=int(record[key])
        return parsed
    return {}


func reload() -> bool:
    _loaded_backup=false
    _load_failed=false
    var primary: Dictionary=_load_file(file_path)
    var best: Dictionary=primary
    # Prefer the highest valid journal revision. The independent last-good
    # .auto copy can recover the *latest* result if primary and .bak break.
    for suffix in [".bak",".tmp",AUTOBACKUP_SUFFIX]:
        var candidate: Dictionary=_load_file(file_path+suffix)
        if not candidate.is_empty() and (best.is_empty() or int(candidate["next_match_id"])>int(best["next_match_id"])):
            best=candidate
    if not best.is_empty():
        _data=best
        _loaded_backup=primary!=best
        if _loaded_backup:
            _pending=best.duplicate(true)
        return true
    _data=_defaults()
    _load_failed=(FileAccess.file_exists(file_path) or
        FileAccess.file_exists(file_path+".bak") or
        FileAccess.file_exists(file_path+AUTOBACKUP_SUFFIX))
    return not _load_failed


func retry_pending() -> bool:
    if _load_failed:
        return false
    if _pending.is_empty():
        return true
    var previous: Dictionary=_data
    _data=_pending.duplicate(true)
    if not _write_atomic():
        _data=previous
        return false
    _pending.clear()
    return true


func snapshot() -> Dictionary:
    return _data.duplicate(true)


## Local-only backup. SHA256 detects accidental damage, NOT attacker tampering.
## It does NOT survive uninstall and is never evidence of cloud identity.
func auto_backup_status() -> Dictionary:
    var copy: Dictionary=_load_file(file_path+AUTOBACKUP_SUFFIX)
    var present: bool=not copy.is_empty()
    return {
        "available":present,
        "in_sync":present and int(copy.get("next_match_id",0))==
            int(_data.get("next_match_id",0)) and
            int(copy.get("local_coins",-1))==int(_data.get("local_coins",0)),
        "played":int(copy.get("played",0)) if present else 0
    }


## User-facing explicit refresh for older valid local profiles without .auto.
func refresh_auto_backup() -> bool:
    if not retry_pending() or not reload():
        return false
    if _load_file(file_path).is_empty():
        return false
    return _sync_auto_backup()


func _sync_auto_backup() -> bool:
    var auto_path: String=file_path+AUTOBACKUP_SUFFIX
    if _load_file(auto_path)==_data:
        return true
    # Copy only a committed and re-validated primary, never a stale in-memory
    # record or an untrusted external payload.
    if _load_file(file_path)!=_data:
        return false
    var source: String=ProjectSettings.globalize_path(file_path)
    var staging: String=ProjectSettings.globalize_path(auto_path+".tmp")
    var destination: String=ProjectSettings.globalize_path(auto_path)
    if DirAccess.copy_absolute(source,staging)!=OK:
        return false
    if _load_file(auto_path+".tmp")!=_data:
        return false
    if DirAccess.rename_absolute(staging,destination)!=OK:
        return false
    return _load_file(auto_path)==_data


func next_match_id() -> int:
    return int(_data["next_match_id"])


## Strictly offline reward schedule. This balance is NOT a cloud wallet and
## must never be accepted as payment, premium diamonds, or ranked RP.
static func local_coin_reward(victory: bool,kills: int,survived_seconds: int) -> int:
    if kills<0 or kills>100 or survived_seconds<0 or survived_seconds>86400:
        return 0
    var minutes: int=mini(10,int(floor(float(survived_seconds)/60.0)))
    return 25+mini(kills,20)*5+minutes*2+(75 if victory else 0)


func record_result(match_id: int,victory: bool,kills: int,
        survived_seconds: int,extra: Dictionary={}) -> bool:
    if not retry_pending():
        return false
    if not reload():
        return false
    # Monotonic ID provides idempotence: repeated _finish() cannot double-count.
    if match_id<=0 or match_id!=next_match_id():
        return false
    if kills<0 or kills>100 or survived_seconds<0 or survived_seconds>86400:
        return false
    if not _valid_extra_fields(extra):
        return false
    var reward: int=local_coin_reward(victory,kills,survived_seconds)
    if int(_data.get("local_coins",0))>LOCAL_COIN_LIMIT-reward:
        return false
    var previous: Dictionary=_data.duplicate(true)
    _data["next_match_id"]=match_id+1
    _data["played"]=int(_data["played"])+1
    _data["wins"]=int(_data["wins"])+(1 if victory else 0)
    _data["kills"]=int(_data["kills"])+kills
    _data["survival_seconds"]=int(_data["survival_seconds"])+survived_seconds
    _data["best_kills"]=maxi(int(_data["best_kills"]),kills)
    _data["longest_survival_seconds"]=maxi(int(_data["longest_survival_seconds"]),survived_seconds)
    # Wallet and match result use ONE atomic journal commit, so retries cannot
    # add the same payout twice after an interrupted write.
    _data["local_coins"]=int(_data.get("local_coins",0))+reward
    var history: Array=_data["history"]
    var entry: Dictionary={
        "match_id":match_id,
        "victory":victory,
        "kills":kills,
        "survived_seconds":survived_seconds,
        "saved_at_unix":int(Time.get_unix_time_from_system()),
        "local_coins_awarded":reward
    }
    # Optional fields are serialized inside the existing SHA256-protected
    # atomic record. A recovered legacy record simply lacks these keys.
    for key in EXTENDED_LIMITS.keys():
        if extra.has(key):
            entry[key]=int(extra[key])
    history.push_front(entry)
    if history.size()>LIMIT:
        history.resize(LIMIT)
    if not _write_atomic():
        _pending=_data.duplicate(true)
        _data=previous
        return false
    return true


func _write_atomic() -> bool:
    var target: String=ProjectSettings.globalize_path(file_path)
    var backup: String=ProjectSettings.globalize_path(file_path+".bak")
    var temporary: String=ProjectSettings.globalize_path(file_path+".tmp")
    var dir: String=target.get_base_dir()
    if DirAccess.make_dir_recursive_absolute(dir)!=OK:
        push_warning("Aurora offline stats directory creation failed")
        return false
    # Preserve the complete journal during promotion retries.
    if _load_file(file_path+".tmp")!=_data:
        var output:=FileAccess.open(temporary,FileAccess.WRITE)
        if output==null:
            push_warning("Aurora offline stats temporary file could not be opened")
            return false
        var payload: String=JSON.stringify(_data)
        output.store_string(JSON.stringify({"payload":payload,"sha256":payload.sha256_text()}))
        output.flush()
        var write_error: Error=output.get_error()
        output.close()
        if write_error!=OK or _load_file(file_path+".tmp")!=_data:
            return false
    if FileAccess.file_exists(target) and not _loaded_backup:
        if DirAccess.dir_exists_absolute(backup):
            return false
        if not _load_file(file_path).is_empty() and DirAccess.copy_absolute(target,backup)!=OK:
            push_warning("Aurora offline stats backup failed; retaining previous save")
            return false
    if DirAccess.rename_absolute(temporary,target)!=OK:
        push_warning("Aurora offline stats atomic commit failed; retaining previous save")
        return false
    _loaded_backup=false
    # The match result was already committed: a failed extra local copy is
    # reported but never falsely converts a successful result into a failure.
    if not _sync_auto_backup():
        push_warning("Aurora local automatic profile backup could not be refreshed")
    return true
