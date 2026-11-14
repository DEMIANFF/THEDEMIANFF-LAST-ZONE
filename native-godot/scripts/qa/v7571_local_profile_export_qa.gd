extends SceneTree
## V75.71: versioned local-only profile export with no online wallet or UID.
## QA uses isolated user://qa paths. It never modifies installed profiles.
const RECORDS=preload("res://scripts/persistence/offline_match_records.gd")
const EXPORT=preload("res://scripts/persistence/local_profile_export.gd")
const SOURCE="user://qa/v7571_profile.json"
const TARGET="user://qa/v7571_profile_export.json"
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7571_PROFILE_EXPORT "+reason)

func _clean(path: String) -> void:
    for suffix in ["",".bak",".tmp",".auto",".auto.tmp"]:
        var target: String=ProjectSettings.globalize_path(path+suffix)
        if FileAccess.file_exists(target):
            DirAccess.remove_absolute(target)

func _write(path: String,data: String) -> bool:
    var f:=FileAccess.open(path,FileAccess.WRITE)
    if f==null:
        return false
    f.store_string(data)
    f.flush()
    var err: Error=f.get_error()
    f.close()
    return err==OK

func _verify() -> void:
    check(DirAccess.make_dir_recursive_absolute(
        ProjectSettings.globalize_path(SOURCE).get_base_dir())==OK,
        "cannot isolate export QA storage")
    _clean(SOURCE)
    _clean(TARGET)

    check(not bool(EXPORT.create(SOURCE,TARGET).get("valid",true)),
        "missing profile was exported as an existing account")
    check(not bool(EXPORT.inspect(TARGET).get("valid",true)),
        "missing export was accepted as verified")
    var ledger=RECORDS.new(SOURCE)
    check(ledger.record_result(1,true,3,93) and
        ledger.record_result(2,false,1,140),
        "cannot create two real saved match fixtures")
    var created: Dictionary=EXPORT.create(SOURCE,TARGET)
    check(bool(created.get("valid",false)) and
        int(created.get("played",0))==2 and
        not bool(created.get("wallet_included",true)) and
        not bool(created.get("has_online_identity",true)),
        "verified export failed or invented premium/online identity")
    var parser:=JSON.new()
    check(parser.parse(FileAccess.get_file_as_string(TARGET))==OK,
        "export has invalid outer JSON")
    var envelope: Dictionary=parser.data if parser.data is Dictionary else {}
    var raw: String=str(envelope.get("payload",""))
    check(raw.sha256_text()==str(envelope.get("sha256","")),
        "export integrity digest mismatched")
    check(parser.parse(raw)==OK,"snapshot has invalid payload JSON")
    var packet: Dictionary=parser.data if parser.data is Dictionary else {}
    var profile: Dictionary=packet.get("profile",{}) if (
        packet.get("profile") is Dictionary) else {}
    check(str(packet.get("format",""))==EXPORT.FORMAT and
        int(packet.get("version",0))==1 and
        packet.get("origin")=="local_godot_no_auth",
        "wrong backup contract version or origin")
    check(int(profile.get("played",0))==2 and
        int(profile.get("wins",0))==1 and
        int(profile.get("kills",0))==4 and
        int(packet.get("last_match_id",0))==2,
        "real match statistics or last match ID were lost")
    check(not profile.has("local_coins") and
        not profile.has("diamonds") and not profile.has("rank_points") and
        not packet.has("uid") and
        not (profile.get("history",[]) as Array).is_empty(),
        "offline wallet or identity leaked into portable profile")
    for entry in profile.get("history",[]):
        check(not (entry as Dictionary).has("local_coins_awarded"),
            "untrusted local currency grants leaked into future cloud payload")
    check(int(ledger.snapshot().get("local_coins",0))==151,
        "read-only export changed the real local wallet")

    # Tamper without recomputing the digest: verify must reject the packet.
    check(_write(TARGET,"{\"payload\":\"tampered\",\"sha256\":\"wrong\"}"),
        "cannot write corrupt QA packet")
    check(not bool(EXPORT.inspect(TARGET).get("valid",true)),
        "invalid export was treated as authenticated cloud data")
    check(bool(EXPORT.create(SOURCE,TARGET).get("valid",false)),
        "a valid local export could not replace a corrupt packet")

    # Even a recomputed SHA256 is not authority to carry a premium wallet.
    packet["profile"]["local_coins"]=999999
    var malicious: String=JSON.stringify(packet)
    check(_write(TARGET,JSON.stringify({
        "payload":malicious,"sha256":malicious.sha256_text()
    })),"cannot write forged QA packet")
    check(EXPORT.inspect(TARGET).get("reason")=="currency_forbidden",
        "local SHA256 was mistaken for authorization to import currency")

    check(ledger.record_result(3,false,0,65),
        "next legitimate local match failed after export")
    var latest: Dictionary=EXPORT.create(SOURCE,TARGET)
    check(bool(latest.get("valid",false)) and
        int(latest.get("played",0))==3 and
        int(latest.get("last_match_id",0))==3,
        "export was not refreshed to the last committed result")
    check(int(RECORDS.new(SOURCE).snapshot().get("local_coins",0))==178,
        "new snapshot duplicated or dropped local coins")
    _clean(SOURCE)
    _clean(TARGET)
    if not failed:
        print("V7571_PROFILE_EXPORT PASS schema=1 journal=verified "+
            "wallet=excluded identity=none tamper=rejected "+
            "revision=latest cloud=false")
    quit(1 if failed else 0)
