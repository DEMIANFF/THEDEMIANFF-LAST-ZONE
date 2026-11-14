extends SceneTree
## V75.93: one legitimate kill/loot event per dead CharacterBody3D,
## NEVER for training, after defeat, duplicated signals or living actors.
## 50 actual physical participants. Uses isolated real atomic match ledger.
const RECORDS=preload("res://scripts/persistence/offline_match_records.gd")
const COMBAT=preload("res://scripts/combat/training_combat.gd")
const QA_PATH: String="user://qa/v7593_elimination_integrity.json"
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7593_ELIMINATION_INTEGRITY "+reason)


func _clean() -> void:
    for suffix in ["",".bak",".tmp",".auto",".auto.tmp"]:
        var path: String=ProjectSettings.globalize_path(QA_PATH+suffix)
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(path)


func _verify() -> void:
    var file_path: String=ProjectSettings.globalize_path(QA_PATH)
    check(DirAccess.make_dir_recursive_absolute(file_path.get_base_dir())==OK,
        "test output must be isolated from actual player profile")
    _clean()
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get_node("Operator")
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var nav: Node3D=game.get_node("AuroraNavigation")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    director._records=RECORDS.new(QA_PATH)
    # Before any sector starts, a training bot can physically die. It
    # must not award Battle Royale currency/stats, nor drop battle loot.
    var practice: CharacterBody3D=combat._targets[0]
    check(practice.take_training_damage(500.0,player) and
        combat.eliminations==0 and
        combat._eliminated_actors_this_round.is_empty() and
        director._opponent_drops_spawned==0,
        "training death incorrectly credited as a BR elimination")
    combat.set_encounter_size(COMBAT.CLASSIC_BR_PARTICIPANTS)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    nav.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(combat._targets.size()==49 and combat.active_fighter_count()==50 and
        combat._eliminated_actors_this_round.is_empty(),
        "new BR retained training deaths or failed 49 physical opponents")

    # Real firearm-health damage starts the normal CharacterBody3D death
    # pipeline. This must create exactly one player kill and a real pickup.
    var victim: CharacterBody3D=combat._targets[0]
    check(victim.take_training_damage(500.0,player) and
        combat.eliminations==1 and
        combat._eliminated_actors_this_round.size()==1 and
        director._opponent_drops_spawned==1,
        "one real physical kill failed to credit one defeat/loot")
    var first_loot: int=director._opponent_drops_spawned
    var first_events: int=hud._combat_events.size()
    combat._on_bot_eliminated(victim,player)
    check(combat.eliminations==1 and
        director._opponent_drops_spawned==first_loot and
        hud._combat_events.size()==first_events,
        "repeat death signal produced duplicated HUD, loot or player kill")
    var live: CharacterBody3D=combat._targets[1]
    combat._on_bot_eliminated(live,player)
    check(combat.eliminations==1 and live.health>0.0,
        "living fighter produced a fake kill by spurious death signal")
    var hostile: CharacterBody3D=combat._targets[2]
    var hostile_victim: CharacterBody3D=combat._targets[3]
    check(hostile_victim.take_training_damage(500.0,hostile) and
        combat.eliminations==1 and
        combat._eliminated_actors_this_round.size()==2,
        "enemy-on-enemy elimination wrongly awarded human credit")

    # The same world persists through a true player death and a real new
    # 50-combatant deployment, but counters MUST be per round.
    player._training_immunity=0.0
    player.receive_training_hit(500.0,true)
    check(director.match_ended and director.last_match_saved and
        not combat.sector_battle_active,
        "player death failed to freeze battle and store defeat")
    var credits: int=combat.eliminations
    var loot: int=director._opponent_drops_spawned
    var events: int=hud._combat_events.size()
    combat._on_bot_eliminated(live,player)
    check(combat.eliminations==credits and
        director._opponent_drops_spawned==loot and
        hud._combat_events.size()==events,
        "post-match death signal still awarded kills or physical loot")
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    nav.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(combat.active_fighter_count()==50 and
        combat._eliminated_actors_this_round.is_empty() and
        combat.eliminations==0,
        "new real BR retained old elimination credits or removed actors")
    check(victim.take_training_damage(500.0,player) and
        combat.eliminations==1 and
        combat._eliminated_actors_this_round.size()==1,
        "same reused physical agent cannot be killed in a NEW round")
    game.queue_free()
    await process_frame
    _clean()
    if not failed:
        print("V7593_ELIMINATION_INTEGRITY PASS physical_roster=50 "+
            "training_credits=0 duplicate_credits=0 living_fake_deaths=0 "+
            "AI_kills_not_human=1 postmatch_credits=0 reset=50 online=false")
    quit(1 if failed else 0)
