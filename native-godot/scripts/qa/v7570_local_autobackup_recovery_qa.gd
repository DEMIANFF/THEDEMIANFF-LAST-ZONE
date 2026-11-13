extends SceneTree
## V75.70 - offline-only automatic backup, no cloud identity or diamonds.
## The tested files live under user://qa; never touch the player's profile.
const RECORDS=preload("res://scripts/persistence/offline_match_records.gd")
const QA_PATH: String="user://qa/v7570_local_autobackup.json"
const LEGACY_PATH: String="user://qa/v7570_legacy_autobackup.json"
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7570_AUTOBACKUP "+reason)

func _clean(path: String) -> void:
    for suffix in ["",".bak",".tmp",".auto",".auto.tmp"]:
        var target: String=ProjectSettings.globalize_path(path+suffix)
        if FileAccess.file_exists(target):
            DirAccess.remove_absolute(target)

func _damage(path: String) -> void:
    var f:=FileAccess.open(path,FileAccess.WRITE)
    check(f!=null,"cannot damage QA fixture "+path)
    if f!=null:
        f.store_string("{truncated:invalid")
        f.flush()
        f.close()

func _verify() -> void:
    var root_path: String=ProjectSettings.globalize_path(QA_PATH)
    check(DirAccess.make_dir_recursive_absolute(
        root_path.get_base_dir())==OK,"QA directory is not writable")
    _clean(QA_PATH)
    _clean(LEGACY_PATH)

    var store=RECORDS.new(QA_PATH)
    check(not bool(store.auto_backup_status().get("available",true)),
        "empty profile invented a backup")
    check(not store.refresh_auto_backup(),
        "empty profile produced a valid backup without a match")
    check(store.record_result(1,true,3,93),
        "first genuine match did not commit")
    var backup: Dictionary=store.auto_backup_status()
    check(bool(backup.get("available",false)) and
        bool(backup.get("in_sync",false)) and int(backup.get("played",0))==1,
        "first completed match did not create an automatic local backup")
    check(store.record_result(2,false,1,140),
        "second genuine match did not commit")
    var current: Dictionary=store.snapshot()
    backup=store.auto_backup_status()
    check(int(current.get("local_coins",0))==151 and
        int(current.get("played",0))==2 and
        int(backup.get("played",0))==2 and
        bool(backup.get("in_sync",false)),
        "auto backup lagged behind the latest local coin and match ledger")

    # Two independent damaged files must not discard match #2 or its coins.
    _damage(QA_PATH)
    _damage(QA_PATH+".bak")
    var recovered=RECORDS.new(QA_PATH)
    check(recovered.next_match_id()==3 and
        int(recovered.snapshot().get("played",0))==2 and
        int(recovered.snapshot().get("local_coins",0))==151,
        "latest auto snapshot was not selected after double corruption")
    check(recovered.retry_pending(),
        "latest valid local auto snapshot could not restore primary")
    check(not recovered.record_result(2,false,1,140) and
        int(RECORDS.new(QA_PATH).snapshot().get("local_coins",0))==151,
        "recovery duplicated completed match or granted coins twice")

    # A corrupted auto backup must not outrank a valid primary.
    _damage(QA_PATH+".auto")
    var healthy=RECORDS.new(QA_PATH)
    check(healthy.next_match_id()==3 and
        int(healthy.snapshot().get("local_coins",0))==151,
        "damaged auto copy contaminated a valid ledger")
    check(not bool(healthy.auto_backup_status().get("in_sync",true)),
        "invalid auto backup reported healthy")
    check(healthy.refresh_auto_backup() and
        bool(healthy.auto_backup_status().get("in_sync",false)),
        "manual local backup refresh failed to repair damaged copy")
    check(int(RECORDS.new(QA_PATH).snapshot().get("local_coins",0))==151,
        "manual backup refresh created duplicate currency")

    # A previously installed schema-1 profile may not have an auto copy.
    var legacy=RECORDS.new(LEGACY_PATH)
    check(legacy.record_result(1,false,0,40),
        "could not build a valid legacy fixture")
    _clean(LEGACY_PATH+".auto")
    check(not bool(legacy.auto_backup_status().get("available",true)),
        "deleted legacy backup was still reported present")
    check(legacy.refresh_auto_backup() and
        bool(legacy.auto_backup_status().get("in_sync",false)),
        "manual refresh cannot prepare older local accounts")
    _clean(QA_PATH)
    _clean(LEGACY_PATH)
    if not failed:
        print("V7570_AUTOBACKUP PASS latest_match_recovered=1 "+
            "coins_recovered=1 duplicate=0 corrupt_backup_rejected=1 "+
            "manual_refresh=1 cloud=false")
    quit(1 if failed else 0)
