extends SceneTree
## V75.68 - genuine local classic rewards, never premium/online currency.
## Uses isolated QA files: no writes to installed player's saved profile.
const RECORDS=preload("res://scripts/persistence/offline_match_records.gd")
const QA_PATH="user://qa/v7568_local_coins.json"
const LEGACY_PATH="user://qa/v7568_legacy_coins_migration.json"
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7568_LOCAL_COINS "+reason)

func _clean(path: String) -> void:
    for suffix in ["",".bak",".tmp",".auto",".auto.tmp"]:
        var target: String=ProjectSettings.globalize_path(path+suffix)
        if FileAccess.file_exists(target):
            DirAccess.remove_absolute(target)

func _verify() -> void:
    var target: String=ProjectSettings.globalize_path(QA_PATH)
    check(DirAccess.make_dir_recursive_absolute(target.get_base_dir())==OK,
        "cannot isolate coin QA profile")
    _clean(QA_PATH)
    _clean(LEGACY_PATH)
    var store=RECORDS.new(QA_PATH)
    check(int(store.snapshot().get("local_coins",-1))==0,
        "a fresh local wallet must start at zero")
    check(RECORDS.local_coin_reward(true,3,93)==117 and
        RECORDS.local_coin_reward(false,1,140)==34,
        "bounded classic match coin schedule changed")
    check(RECORDS.local_coin_reward(false,-1,140)==0 and
        RECORDS.local_coin_reward(true,101,93)==0,
        "invalid combat results can generate coins")
    check(store.record_result(1,true,3,93),
        "winning classic match could not save atomically")
    var first: Dictionary=RECORDS.new(QA_PATH).snapshot()
    check(int(first.get("local_coins",-1))==117,
        "real win did not award the correct local coins")
    check(int((first["history"][0] as Dictionary).get(
        "local_coins_awarded",-1))==117,
        "audit ledger does not record its actual coin grant")
    check(not store.record_result(1,true,3,93),
        "duplicate match ID was accepted")
    check(int(RECORDS.new(QA_PATH).snapshot().get("local_coins",-1))==117,
        "repeated result granted duplicate local coins")
    check(store.record_result(2,false,1,140),
        "defeat match was not persisted")
    var combined: Dictionary=RECORDS.new(QA_PATH).snapshot()
    check(int(combined.get("local_coins",-1))==151 and
        int(combined.get("played",-1))==2,
        "wallet and match journal lost atomic consistency")

    # Migrating a valid old schema-1 save keeps previous results but does not
    # retroactively fabricate historical currency or charge purchases.
    var legacy: Dictionary=combined.duplicate(true)
    legacy.erase("local_coins")
    for entry in legacy["history"]:
        (entry as Dictionary).erase("local_coins_awarded")
    var payload: String=JSON.stringify(legacy)
    var handle:=FileAccess.open(LEGACY_PATH,FileAccess.WRITE)
    check(handle!=null,"cannot create a legacy fixture")
    if handle!=null:
        handle.store_string(JSON.stringify({
            "payload":payload,"sha256":payload.sha256_text()
        }))
        handle.flush()
        handle.close()
    var upgraded=RECORDS.new(LEGACY_PATH)
    check(int(upgraded.snapshot().get("local_coins",-1))==0 and
        upgraded.next_match_id()==3,
        "legacy journal migration lost progress or invented coins")
    check(upgraded.record_result(3,false,0,65),
        "migrated old profile cannot earn new local rewards")
    check(int(RECORDS.new(LEGACY_PATH).snapshot().get("local_coins",-1))==27,
        "migrated profile did not save its first legitimate reward")

    # A future backend must not accept local balances as authenticated
    # purchases or diamonds. No premium fields are stored in this journal.
    check(not combined.has("diamonds") and not combined.has("rank_points"),
        "offline journal contains fabricated premium or ranked balances")
    _clean(QA_PATH)
    _clean(LEGACY_PATH)
    if not failed:
        print("V7568_LOCAL_COINS PASS genuine_classic=1 duplicate=0 "+
            "legacy_migration=1 atomic=1 premium_disabled=1")
    quit(1 if failed else 0)
