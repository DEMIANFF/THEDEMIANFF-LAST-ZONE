extends SceneTree
## Complete offline round integration; uses a SEPARATE test ledger path.
const RECORDS=preload("res://scripts/persistence/offline_match_records.gd")
const SAVE_PATH: String="user://qa/sector_integration_rounds.json"


func _initialize() -> void:
    call_deferred("_verify")


func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director:=game.get_node("AuroraSectorMatch") as Node3D
    var combat:=game.get_node("CombatRange") as Node3D
    var operator:=game.get_node("Operator") as CharacterBody3D
    var hud:=game.get_node("TrainingHUD") as CanvasLayer
    var save_path: String=ProjectSettings.globalize_path(SAVE_PATH)
    DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
    for suffix in ["",".bak",".tmp"]:
        var p: String=ProjectSettings.globalize_path(SAVE_PATH+suffix)
        if FileAccess.file_exists(p):
            DirAccess.remove_absolute(p)
    director._records=RECORDS.new(SAVE_PATH)
    if director==null:
        push_error("V74 director not created")
        quit(80)
        return
    var environment: Node3D=game.get_node_or_null("AuroraNature") as Node3D
    if environment==null:
        push_error("Aurora nature/biome instancing missing")
        quit(92)
        return
    var pines:=environment.get_node_or_null("AuroraPineCrowns") as MultiMeshInstance3D
    var crystals:=environment.get_node_or_null("LuminescentIceCrystals") as MultiMeshInstance3D
    if pines==null or crystals==null or pines.multimesh.instance_count<40 or crystals.multimesh.instance_count<15:
        push_error("Aurora 3D environment has insufficient instanced natural features")
        quit(93)
        return
    for i in range(80):
        await physics_frame
    if director.mode!="training" or combat._targets.size()!=4:
        push_error("Training sandbox compatibility lost")
        quit(81)
        return

    director.start_sector_battle()
    await process_frame
    if director.mode!="sector_battle" or combat._targets.size()!=8 or combat.active_fighter_count()!=9:
        push_error("Battle did not create one player + eight AI opponents")
        quit(82)
        return
    var danger:=director.get_node_or_null("AuroraClosingZone/SectorBoundaryMesh") as MeshInstance3D
    if danger==null or danger.mesh==null:
        push_error("Shrinking danger zone has no in-world 3D boundary")
        quit(94)
        return
    if director.get_loot_remaining()!=16:
        push_error("Battle did not spawn the 16 world loot capsules")
        quit(83)
        return
    var first: Area3D=director._loot[0]
    var ammo_before: int=combat.reserve[0]
    first._collect(operator)
    if combat.reserve[0]!=ammo_before+45 or director.get_loot_remaining()!=15:
        push_error("Physical area loot does not increase reserve and disappear")
        quit(84)
        return
    operator._training_immunity=0
    var health_before: float=operator.training_health
    operator.global_position=Vector3(155.0,28.0,-24.0)
    if not director.is_outside_zone(operator.global_position):
        push_error("Outer Aurora hazard geometry failed")
        quit(85)
        return
    director._check_hazard_damage()
    if operator.training_health>=health_before:
        push_error("Real Aurora hazard does not damage out-of-zone player")
        quit(86)
        return
    operator.global_position=operator.respawn_point
    director._process(120.0)
    if absf(director._zone_visual.safe_radius-director.radius)>.5:
        push_error("Rendered hazard radius desynchronized from damage circle")
        quit(95)
        return
    if director.radius>=director.INITIAL_RADIUS or director.radius<director.FINAL_RADIUS:
        push_error("Zone not shrinking over round time")
        quit(87)
        return

    # Assert actual bot-to-bot damage path, not merely a configured opponent list.
    var challenger: CharacterBody3D=combat._targets[0]
    var rival: CharacterBody3D=combat._targets[1]
    challenger.global_position=Vector3(4.0,game.get_node("AuroraTerrain").height_at(4.0,-40.0)+.2,-40.0)
    rival.global_position=Vector3(7.0,game.get_node("AuroraTerrain").height_at(7.0,-40.0)+.2,-40.0)
    challenger._target_actor=rival
    challenger._target_visible=true
    challenger._sense_clock=4.0
    challenger._attack_clock=0.0
    var hp_before: float=rival.health
    challenger._physics_process(.016)
    if rival.health>=hp_before:
        push_error("Opponents cannot damage other opponents in battle royale")
        quit(97)
        return
    # AI-vs-AI and permanent elimination test (no training respawn).
    var before: int=combat.active_fighter_count()
    var victim: CharacterBody3D=combat._targets[1]
    if not victim.sector_battle or victim._foes.size()!=8:
        push_error("AI not configured for free-for-all opponents")
        quit(88)
        return
    victim.take_training_damage(150.0,challenger)
    if combat.eliminations!=0:
        push_error("Bot or zone eliminations incorrectly counted as player kills")
        quit(98)
        return
    if victim.health>0 or combat.active_fighter_count()!=before-1:
        push_error("Elimination did not reduce the live participant count")
        quit(89)
        return
    var player_target: CharacterBody3D=combat._targets[2]
    player_target.take_training_damage(180.0,operator)
    if combat.eliminations!=1:
        push_error("Player kill was not credited correctly")
        quit(99)
        return
    for bot in combat._targets:
        if bot.health>0:
            bot.take_training_damage(180.0)
    director._process(.015)
    if not director.match_ended or not director.mode=="sector_battle":
        push_error("Victory did not end the last-survivor round")
        quit(90)
        return
    var result_panel:=game.get_node("TrainingHUD/AuroraTacticalOverlay/SectorMatchResult") as PanelContainer
    if not result_panel.visible:
        push_error("Victory results panel not displayed")
        quit(96)
        return
    if not director.last_match_saved:
        push_error("Winner results were not persisted")
        quit(176)
        return
    var ledger: Dictionary=director._records.snapshot()
    if int(ledger.get("played",0))!=1 or int(ledger.get("wins",0))!=1 or int(ledger.get("kills",0))!=1:
        push_error("Integrated win ledger has incorrect matches/wins/player kills")
        quit(177)
        return
    if not operator.round_finished or combat.sector_battle_active or combat.trigger_held:
        push_error("Combat or player controls continued after finished round")
        quit(178)
        return
    for bot in combat._targets:
        if bot.is_physics_processing():
            push_error("Enemy AI still attacks after the match result screen")
            quit(179)
            return
    director._finish(true)
    if int(director._records.snapshot().get("played",0))!=1:
        push_error("Double finish persisted the victory twice")
        quit(180)
        return

    director.start_sector_battle()
    await process_frame
    if director.match_ended or combat.active_fighter_count()!=9 or director.get_loot_remaining()!=16 or operator.round_finished:
        push_error("New sector battle failed to reset fighters/loot/player controls")
        quit(91)
        return
    if not combat.sector_battle_active:
        push_error("New round did not re-enable combat")
        quit(181)
        return
    for bot in combat._targets:
        if not bot.is_physics_processing():
            push_error("New round did not reactivate live opponent AI")
            quit(182)
            return
    for suffix in ["",".bak",".tmp"]:
        var p: String=ProjectSettings.globalize_path(SAVE_PATH+suffix)
        if FileAccess.file_exists(p):
            DirAccess.remove_absolute(p)
    print("SECTOR BR PASS: actual loot, zone, elimination, victory, one saved result, frozen AI after match and clean restart")
    quit(0)
