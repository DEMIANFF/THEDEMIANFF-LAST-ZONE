extends SceneTree
## V75.90: 50 true physical participants complete defeat, victory, once-only
## local ledger and restart. This is deterministic QA, not fabricated match UX.
const RECORDS=preload("res://scripts/persistence/offline_match_records.gd")
const COMBAT=preload("res://scripts/combat/training_combat.gd")
const QA_PATH: String="user://qa/v7590_fifty_results.json"
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7590_FIFTY_RESULTS "+reason)


func _clean() -> void:
    for suffix in ["",".bak",".tmp",".auto",".auto.tmp"]:
        var path: String=ProjectSettings.globalize_path(QA_PATH+suffix)
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(path)


func _verify() -> void:
    var file_path: String=ProjectSettings.globalize_path(QA_PATH)
    check(DirAccess.make_dir_recursive_absolute(file_path.get_base_dir())==OK,
        "cannot isolate test results from real local player account")
    _clean()
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var operator: CharacterBody3D=game.get_node("Operator")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var navigation: Node3D=game.get_node("AuroraNavigation")
    for actor in combat._targets:
        actor.set_physics_process(false)
    await physics_frame
    director._records=RECORDS.new(QA_PATH)
    combat.set_encounter_size(COMBAT.CLASSIC_BR_PARTICIPANTS)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    operator.set_physics_process(false)
    navigation.set_physics_process(false)
    for actor in combat._targets:
        actor.set_physics_process(false)
    check(combat._targets.size()==49 and combat.active_fighter_count()==50,
        "full round did not start with one player and 49 physical rivals")

    # Real health death drives the existing elimination signal and exactly
    # one persistent defeat, with truthful rank 50/50, not a dummy result.
    operator._training_immunity=0.0
    operator.receive_training_hit(500.0,true)
    check(director.match_ended and director.last_match_saved and
        operator.royale_eliminated and combat.active_fighter_count()==49,
        "player death did not end a real 50-entrant match")
    var stored_defeat: Dictionary=director._records.snapshot()
    var history: Array=stored_defeat["history"]
    check(history.size()==1 and
        not bool(history[0].get("victory",true)) and
        int(history[0].get("rank",-1))==50 and
        int(history[0].get("participants",-1))==50,
        "first death did not persist truthful 50th-place finish")
    check(not combat.sector_battle_active and
        operator.round_finished,
        "post-match combat should be frozen")
    for actor in combat._targets:
        check(not actor.is_physics_processing(),
            "an eliminated player's enemies continued physical AI attacks")
    director._finish(false)
    check(int(director._records.snapshot().get("played",0))==1,
        "duplicate defeat event committed a second journal record")

    # A new physical round must revive all 49 agents with no lobby benchmark
    # selector and must not inherit eliminated player state.
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    operator.set_physics_process(false)
    navigation.set_physics_process(false)
    for actor in combat._targets:
        actor.set_physics_process(false)
    check(not director.match_ended and not operator.royale_eliminated and
        combat._targets.size()==49 and combat.active_fighter_count()==50,
        "restarting real Battle Royale did not restore all 50 participants")

    # One opponent truly eliminates another. All remaining takedowns use
    # the real CharacterBody3D health/death signal with the player as killer.
    # A bot kill must never be incorrectly awarded to the human.
    var rival_killer: CharacterBody3D=combat._targets[0]
    var rival_victim: CharacterBody3D=combat._targets[1]
    rival_victim.take_training_damage(500.0,rival_killer)
    check(combat.eliminations==0 and
        combat.active_fighter_count()==49,
        "AI-vs-AI fight awarded imaginary human kills")
    for actor in combat._targets:
        if actor.health>0.0:
            actor.take_training_damage(500.0,operator)
    check(combat.active_fighter_count()==1 and combat.eliminations==48,
        "49 actual enemy health deaths failed to end with player survivor")
    director._process(.016)
    check(director.match_ended and director.last_match_saved and
        not combat.sector_battle_active,
        "last surviving physical player was not declared winner")
    var snapshot: Dictionary=RECORDS.new(QA_PATH).snapshot()
    var results: Array=snapshot["history"]
    check(results.size()==2 and bool(results[0].get("victory",false)) and
        int(results[0].get("rank",-1))==1 and
        int(results[0].get("participants",-1))==50 and
        int(results[0].get("kills",-1))==48 and
        int(snapshot.get("played",0))==2 and
        int(snapshot.get("wins",0))==1 and
        int(snapshot.get("kills",0))==48,
        "atomic journal lost exact results from two real 50-fighter rounds")
    var result_window: PanelContainer=hud.get_node(
        "AuroraTacticalOverlay/SectorMatchResult")
    check(result_window.visible and combat._targets.size()==49,
        "victory panel hidden or opponents incorrectly removed from arena")
    director._finish(true)
    check(int(RECORDS.new(QA_PATH).snapshot().get("played",0))==2,
        "repeated win wrote extra match or currency payout")
    game.queue_free()
    await process_frame
    _clean()
    if not failed:
        print("V7590_FIFTY_RESULTS PASS roster=50 defeat_rank=50 "+
            "victory_rank=1 bot_kills=excluded human_kills=48 "+
            "journal_atomic=2 one_result_per_round=1")
    quit(1 if failed else 0)
