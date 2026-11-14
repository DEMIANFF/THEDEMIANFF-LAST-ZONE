extends SceneTree
## V75.82: real on-device earn/claim/recovery, no fake online wallet.
const RECORDS=preload("res://scripts/persistence/offline_match_records.gd")
const QA_PATH="user://qa/aurora_v7582_free_pass_claim.json"
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7582_FREE_PASS "+reason)


func _clean() -> void:
    var location: String=ProjectSettings.globalize_path(QA_PATH)
    DirAccess.make_dir_recursive_absolute(location.get_base_dir())
    for suffix in ["",".bak",".tmp",".auto",".auto.tmp"]:
        if FileAccess.file_exists(location+suffix):
            DirAccess.remove_absolute(location+suffix)


func _verify() -> void:
    _clean()
    var ledger=RECORDS.new(QA_PATH)
    check(int(ledger.free_pass_state()["points"])==0 and
        int(ledger.free_pass_state()["next_claimable"])==0,
        "unplayed profiles must not receive free coins")
    check(not ledger.claim_next_pass_reward(),
        "an unearned pass tier was claimed")
    check(ledger.record_result(1,true,4,600) and
        ledger.record_result(2,true,5,600),
        "real local matches did not add pass progression")
    var earned: Dictionary=ledger.free_pass_state()
    check(int(earned["points"])==388 and
        int(earned["unlocked"])==1 and
        int(earned["next_claimable"])==1,
        "real pass points not calculated from persisted matches")
    var original_coins: int=int(ledger.snapshot()["local_coins"])
    check(ledger.claim_next_pass_reward(),
        "earned free-tier reward did not commit")
    check(int(ledger.snapshot()["local_coins"])==original_coins+
        RECORDS.PASS_REWARD_COINS and
        int(ledger.free_pass_state()["claimed"])==1,
        "one-time claim did not atomically increase local coin wallet")
    check(not ledger.claim_next_pass_reward() and
        int(ledger.snapshot()["local_coins"])==original_coins+
        RECORDS.PASS_REWARD_COINS,
        "duplicate tier claim created free money")
    check(ledger.record_result(3,true,6,600) and
        int(ledger.free_pass_state()["unlocked"])==2 and
        int(ledger.free_pass_state()["next_claimable"])==2 and
        ledger.claim_next_pass_reward(),
        "second genuinely earned tier cannot be claimed")
    var total_coins: int=int(ledger.snapshot()["local_coins"])
    var next_id: int=ledger.next_match_id()
    # A free-pass-only claim leaves next_match_id unchanged; recovery must
    # select the highest verified claim count, not the stale .bak journal.
    var file:=FileAccess.open(QA_PATH,FileAccess.WRITE)
    check(file!=null,"cannot create intentional primary corruption fixture")
    if file!=null:
        file.store_string("{corrupt-primary")
        file.close()
    var recovered=RECORDS.new(QA_PATH)
    check(recovered.next_match_id()==next_id and
        int(recovered.free_pass_state()["claimed"])==2 and
        int(recovered.snapshot()["local_coins"])==total_coins,
        "pass claim lost because .bak and .auto shared match ID")
    check(recovered.retry_pending() and
        int(RECORDS.new(QA_PATH).free_pass_state()["claimed"])==2,
        "valid recovered pass data did not reach the primary journal")

    # Test real lobby route, button enablement, award and visible wallet.
    var menu: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(menu)
    await process_frame
    menu._enter_local_lobby()
    await process_frame
    menu._offline_records=recovered
    menu._select_tab("PASE")
    check(menu._pass_claim_button.visible and
        menu._pass_progress.visible and
        menu._pass_claim_button.disabled,
        "PASE displayed fake pending claim or hid the progress widgets")
    check(menu._info.text.contains("PASE GRATUITO LOCAL") and
        menu._info.text.contains("RECOMPENSAS COBRADAS: 2"),
        "lobby pass did not read committed ledger")
    # A further real match must re-enable the actual claim button.
    check(recovered.record_result(4,true,6,600),
        "third earnable tier's match did not save")
    menu._select_tab("PASE")
    check(not menu._pass_claim_button.disabled,
        "earned tier did not enable the actual native claim button")
    var before_ui_claim: int=int(recovered.snapshot()["local_coins"])
    menu._pass_claim_button.emit_signal("pressed")
    check(int(recovered.snapshot()["local_coins"])==
            before_ui_claim+RECORDS.PASS_REWARD_COINS and
        menu._currency_strip.text.contains("MONEDAS "+str(
            before_ui_claim+RECORDS.PASS_REWARD_COINS)),
        "real lobby click did not persist earned coins and refresh wallet")
    menu.queue_free()
    await process_frame
    _clean()
    if not failed:
        print("V7582_FREE_PASS PASS actual_matches=4 "+
            "once_per_tier=1 local_coins=atomic backup=recover "+
            "lobby_claim=real offline_only=1")
    quit(1 if failed else 0)
