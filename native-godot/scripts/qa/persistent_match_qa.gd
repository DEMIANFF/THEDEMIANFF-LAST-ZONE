extends SceneTree
## Isolated durable local record QA. NEVER writes the user's real profile.
const RECORDS=preload("res://scripts/persistence/offline_match_records.gd")
const TEST_FILE: String="user://qa/aurora_match_ledger_ci.json"


func _initialize() -> void:
    call_deferred("_verify")


func _fail(code: int,message: String) -> void:
    push_error("PERSISTENT_MATCH_QA: "+message)
    quit(code)


func _verify() -> void:
    var full: String=ProjectSettings.globalize_path(TEST_FILE)
    if DirAccess.make_dir_recursive_absolute(full.get_base_dir())!=OK:
        _fail(160,"Unable to create isolated QA dir")
        return
    for suffix in ["",".bak",".tmp"]:
        var candidate: String=ProjectSettings.globalize_path(TEST_FILE+suffix)
        if FileAccess.file_exists(candidate):
            DirAccess.remove_absolute(candidate)
    var store=RECORDS.new(TEST_FILE)
    if store.next_match_id()!=1 or int(store.snapshot().get("played",-1))!=0:
        _fail(161,"New profile not blank")
        return
    if not store.record_result(1,true,3,93):
        _fail(162,"Real win could not be persisted")
        return
    if store.record_result(1,true,3,93):
        _fail(163,"Double finish gave a duplicate award")
        return
    var next=RECORDS.new(TEST_FILE)
    var first: Dictionary=next.snapshot()
    if int(first.get("played",0))!=1 or int(first.get("wins",0))!=1 or int(first.get("kills",0))!=3 or next.next_match_id()!=2:
        _fail(164,"Profile did not survive store re-instantiation")
        return
    if not next.record_result(2,false,1,140):
        _fail(165,"Second legitimate completed round not saved")
        return
    var reopened=RECORDS.new(TEST_FILE)
    var state: Dictionary=reopened.snapshot()
    if int(state.get("played",0))!=2 or int(state.get("wins",0))!=1 or int(state.get("kills",0))!=4 or int(state.get("longest_survival_seconds",0))!=140:
        _fail(166,"Loss, best survival and kills were incorrectly aggregated")
        return
    var log: Array=state.get("history",[])
    if log.size()!=2 or int(log[0].get("match_id",0))!=2 or not bool(log[1].get("victory",false)):
        _fail(167,"Match history order or contents incorrect")
        return
    # Simulate interrupted write/corruption. Last-known good backup should
    # still provide a consistent snapshot (first completed match).
    var bad:=FileAccess.open(TEST_FILE,FileAccess.WRITE)
    if bad==null:
        _fail(168,"Cannot simulate a damaged current profile")
        return
    bad.store_string("{truncated-json")
    bad.flush()
    bad.close()
    var recovered=RECORDS.new(TEST_FILE)
    if int(recovered.snapshot().get("played",0))!=1 or recovered.next_match_id()!=2:
        _fail(169,"Corrupted file did not recover previous valid backup")
        return
    if not recovered.record_result(2,false,2,200):
        _fail(170,"Recovered match history could not commit safely")
        return
    var committed=RECORDS.new(TEST_FILE)
    if int(committed.snapshot().get("played",0))!=2 or int(committed.snapshot().get("kills",0))!=5:
        _fail(171,"Recovered stats lost on a subsequent write")
        return
    for suffix in ["",".bak",".tmp"]:
        var candidate: String=ProjectSettings.globalize_path(TEST_FILE+suffix)
        if FileAccess.file_exists(candidate):
            DirAccess.remove_absolute(candidate)
    print("PERSISTENT_MATCH_QA PASS: atomic write, win/loss, idempotence, reload, best scores, history, broken-file backup recovery")
    quit(0)
