extends RefCounted
## V75.71: verified LOCAL profile snapshot for a future authenticated bridge.
## Not Firebase, an import mechanism, a purchase receipt, or an online wallet.
const RECORDS=preload("res://scripts/persistence/offline_match_records.gd")
const FORMAT: String="aurora_offline_profile_export"
const FORMAT_VERSION: int=1
const DEFAULT_SOURCE: String="user://profiles/aurora_local_v1.json"
const DEFAULT_EXPORT: String="user://profiles/aurora_profile_export_v1.json"


static func _private_path(path: String) -> bool:
    return path.begins_with("user://") and not path.contains("..") and (
        path.ends_with(".json"))


## Strictly read-only verification; never restores an arbitrary file to an account.
static func inspect(path: String=DEFAULT_EXPORT) -> Dictionary:
    if not _private_path(path) or not FileAccess.file_exists(path):
        return {"valid":false,"reason":"no_file"}
    var parser:=JSON.new()
    if parser.parse(FileAccess.get_file_as_string(path))!=OK:
        return {"valid":false,"reason":"invalid_json"}
    var outer: Variant=parser.data
    if not (outer is Dictionary) or not (outer.get("payload") is String):
        return {"valid":false,"reason":"invalid_envelope"}
    var raw: String=outer["payload"]
    if raw.sha256_text()!=outer.get("sha256",""):
        return {"valid":false,"reason":"checksum"}
    if parser.parse(raw)!=OK or not (parser.data is Dictionary):
        return {"valid":false,"reason":"invalid_payload"}
    var packet: Dictionary=parser.data
    if (packet.get("format")!=FORMAT or
            int(packet.get("version",-1))!=FORMAT_VERSION or
            packet.get("origin")!="local_godot_no_auth" or
            packet.get("wallet_policy")!="no_currency_export" or
            packet.has("uid") or packet.has("diamonds")):
        return {"valid":false,"reason":"invalid_contract"}
    if not (packet.get("profile") is Dictionary):
        return {"valid":false,"reason":"invalid_profile"}
    var profile: Dictionary=packet["profile"]
    if (profile.has("local_coins") or profile.has("diamonds") or
            profile.has("rank_points")):
        return {"valid":false,"reason":"currency_forbidden"}
    var validator=RECORDS.new("user://qa/aurora_export_schema_guard_v1.json")
    if not validator._valid(profile):
        return {"valid":false,"reason":"invalid_stats"}
    for record in profile.get("history",[]):
        if record is Dictionary and (record.has("local_coins_awarded") or
                record.has("diamonds")):
            return {"valid":false,"reason":"currency_forbidden"}
    if int(packet.get("last_match_id",-1))!=int(profile.get("played",-2)):
        return {"valid":false,"reason":"revision_mismatch"}
    return {
        "valid":true,
        "reason":"verified_local_only",
        "played":int(profile.get("played",0)),
        "last_match_id":int(packet["last_match_id"]),
        "has_online_identity":false,
        "wallet_included":false
    }


## Produces a snapshot inside app-private storage; nothing is uploaded.
## All local currencies are deliberately excluded from this untrusted packet.
static func create(source_path: String=DEFAULT_SOURCE,
        export_path: String=DEFAULT_EXPORT) -> Dictionary:
    if (not _private_path(source_path) or
            not _private_path(export_path) or source_path==export_path):
        return {"valid":false,"reason":"unsafe_path"}
    var source=RECORDS.new(source_path)
    if not source.reload() or not source.retry_pending():
        return {"valid":false,"reason":"source_unavailable"}
    var local: Dictionary=source._load_file(source_path)
    if local.is_empty():
        return {"valid":false,"reason":"no_saved_profile"}
    var portable: Dictionary=local.duplicate(true)
    portable.erase("local_coins")
    for record in portable.get("history",[]):
        if record is Dictionary:
            record.erase("local_coins_awarded")
    if not source._valid(portable):
        return {"valid":false,"reason":"invalid_source"}
    var packet: Dictionary={
        "format":FORMAT,
        "version":FORMAT_VERSION,
        "origin":"local_godot_no_auth",
        "wallet_policy":"no_currency_export",
        "last_match_id":int(portable["played"]),
        "captured_at_unix":int(Time.get_unix_time_from_system()),
        "profile":portable
    }
    var payload: String=JSON.stringify(packet)
    var envelope: String=JSON.stringify({
        "payload":payload,"sha256":payload.sha256_text()
    })
    var target: String=ProjectSettings.globalize_path(export_path)
    if DirAccess.make_dir_recursive_absolute(target.get_base_dir())!=OK:
        return {"valid":false,"reason":"directory"}
    var staged_path: String=export_path+".tmp"
    var staged: String=ProjectSettings.globalize_path(staged_path)
    var file:=FileAccess.open(staged,FileAccess.WRITE)
    if file==null:
        return {"valid":false,"reason":"write"}
    file.store_string(envelope)
    file.flush()
    var saved: Error=file.get_error()
    file.close()
    if saved!=OK:
        return {"valid":false,"reason":"flush"}
    # Inspect only .json destinations; do not interpret the staging filename.
    var check:=JSON.new()
    if check.parse(FileAccess.get_file_as_string(staged))!=OK or not (
            check.data is Dictionary) or check.data.get("payload","")!=payload:
        return {"valid":false,"reason":"staged_corrupt"}
    if DirAccess.rename_absolute(staged,target)!=OK:
        return {"valid":false,"reason":"promote"}
    return inspect(export_path)
