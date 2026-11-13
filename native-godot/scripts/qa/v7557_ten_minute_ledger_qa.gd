extends SceneTree
## V75.57 — longer battle schedule and backwards-compatible atomic records.
## Isolated user:// QA path; NEVER modifies the player's installed profile.
const RECORDS=preload("res://scripts/persistence/offline_match_records.gd")
const QA_PATH="user://qa/aurora_match_extended_v7557.json"
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V7557_MATCH_LEDGER "+why)

func _clean() -> void:
    for suffix in ["",".bak",".tmp",".auto",".auto.tmp"]:
        var file: String=ProjectSettings.globalize_path(QA_PATH+suffix)
        if FileAccess.file_exists(file):
            DirAccess.remove_absolute(file)

func _verify() -> void:
    check(str(ProjectSettings.get_setting(
        "rendering/renderer/rendering_method.mobile"))=="mobile",
        "single Vulkan Android export was lost")
    var target: String=ProjectSettings.globalize_path(QA_PATH)
    check(DirAccess.make_dir_recursive_absolute(
        target.get_base_dir())==OK,"cannot isolate QA user ledger")
    _clean()
    var older=RECORDS.new(QA_PATH)
    check(older.next_match_id()==1 and
        older.record_result(1,true,3,93),
        "legacy four-argument match result no longer saves")
    var old_record: Dictionary=older.snapshot()["history"][0]
    check(not old_record.has("accuracy") and
        not old_record.has("damage"),
        "legacy records were rewritten with invented statistics")

    var measured: Dictionary={
        "rank":4,"participants":9,
        "damage":263,"accuracy":40,"loot":8,
        "shots":20,"hits":8,"reloads":3
    }
    check(older.record_result(2,false,1,420,measured),
        "new match metadata could not be stored atomically")
    var reopened=RECORDS.new(QA_PATH)
    var snapshot: Dictionary=reopened.snapshot()
    check(reopened.next_match_id()==3 and
        int(snapshot["played"])==2 and int(snapshot["wins"])==1 and
        int(snapshot["kills"])==4,
        "optional per-match metadata damaged legacy totals or sequential IDs")
    var latest: Dictionary=snapshot["history"][0]
    check(int(latest.get("accuracy",-1))==40 and
        int(latest.get("damage",-1))==263 and
        int(latest.get("rank",-1))==4 and
        int(latest.get("loot",-1))==8 and
        int(latest.get("shots",-1))==20 and
        int(latest.get("hits",-1))==8 and
        int(latest.get("reloads",-1))==3,
        "real match details were lost when reopened from verified SHA256 journal")
    check(not (snapshot["history"][1] as Dictionary).has("accuracy"),
        "historical record was not preserved without new optional fields")
    check(not reopened.record_result(2,false,1,420,measured),
        "idempotent result ledger accepted duplicate match ID")
    check(not reopened.record_result(3,false,2,500,{
        "rank":12,"participants":9}),
        "invalid leaderboard rank bypassed journal validation")
    check(not reopened.record_result(3,false,2,500,{
        "rank":3,"participants":9,"shots":3,"hits":5}),
        "impossible ballistics telemetry bypassed journal validation")
    check(not reopened.record_result(3,false,2,500,{
        "accuracy":200}),
        "invalid accuracy percentage bypassed ledger validation")
    check(reopened.next_match_id()==3,
        "rejected invalid records consumed a future match ID")

    # The newest automatic backup survives corrupted primary with complete
    # telemetry, while the old .bak remains a secondary fallback.
    var bad:=FileAccess.open(QA_PATH,FileAccess.WRITE)
    check(bad!=null,"cannot test interrupted local journal write")
    if bad!=null:
        bad.store_string("{broken-json")
        bad.flush()
        bad.close()
    var recovered=RECORDS.new(QA_PATH)
    check(recovered.next_match_id()==3 and
        int(recovered.snapshot()["played"])==2,
        "automatic recovery rolled back verified extended match results")
    check(recovered.record_result(3,false,1,420,measured),
        "recovered auto backup cannot append extended result idempotently")
    check(RECORDS.new(QA_PATH).next_match_id()==4,
        "recovered atomic journal did not commit new metadata")

    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var player: CharacterBody3D=game.get_node("Operator")
    var combat: Node3D=game.get_node("CombatRange")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    check(director.SHRINK_DURATION==600.0 and
        director.PHASE_COUNT==4 and
        director.PHASE_SECONDS==150.0 and
        director.PHASE_HOLD_SECONDS>=20.0,
        "match zone is not scheduled for four tactical phases in ten minutes")
    var last_radius: float=director.INITIAL_RADIUS
    var last_phase: int=0
    for t in range(0,601,15):
        var step: Dictionary=director.zone_state_at(float(t))
        var radius: float=float(step["radius"])
        var phase: int=int(step["phase"])
        check(radius<=last_radius+.001 and radius>=director.FINAL_RADIUS-.001,
            "storm radius is not monotonic across ten-minute match at "+str(t))
        check(phase>=last_phase and phase<=4,
            "storm phase order regressed at "+str(t))
        last_radius=radius
        last_phase=phase
    check(director.zone_state_at(600.0)["radius"]==
        director.FINAL_RADIUS and
        int(director.zone_state_at(600.0)["phase"])==4,
        "final safe ring was not reached at exactly ten minutes")
    for phase in range(4):
        var start: float=float(phase)*director.PHASE_SECONDS
        var a: Dictionary=director.zone_state_at(start)
        var hold: Dictionary=director.zone_state_at(
            start+director.PHASE_HOLD_SECONDS*.50)
        var close: Dictionary=director.zone_state_at(
            start+director.PHASE_SECONDS-5.0)
        check(absf(float(a["radius"])-float(hold["radius"]))<.001 and
            float(close["radius"])<float(a["radius"]),
            "phase "+str(phase)+" lacks a genuine hold-then-shrink interval")

    director._records=RECORDS.new(QA_PATH)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(director._match_id==4 and
        director.get_loot_remaining()==25,
        "new match reuses old ID or lost the original physical loot")
    # These synthetic values are ONLY ledger math fixtures, not alleged
    # measurements from a Motorola or actual player combat.
    combat.damage_dealt=125.0
    combat.loot_collected=4
    combat.shots_fired_total=10
    combat.shots_hit_total=4
    combat.reloads_completed=2
    player.receive_training_hit(500.0,true)
    check(director.match_ended and director.last_match_saved,
        "real player health death failed to atomically store final match")
    var stored: Dictionary=RECORDS.new(QA_PATH).snapshot()["history"][0]
    check(int(stored.get("damage",-1))==125 and
        int(stored.get("accuracy",-1))==40 and
        int(stored.get("loot",-1))==4 and
        int(stored.get("shots",-1))==10 and
        int(stored.get("hits",-1))==4 and
        int(stored.get("reloads",-1))==2 and
        int(stored.get("participants",-1))==9,
        "actual sector director does not persist new victory/defeat telemetry")
    _clean()
    if not failed:
        print("V7557_MATCH_LEDGER PASS ten_minutes=600 phases=4 "+
            "legacy_compatible=1 signed_journal=1 rejects_invalid=1 "+
            "recovery=1 end_to_end=1 single_vulkan=1")
    quit(1 if failed else 0)
