extends SceneTree
## V74 offline single-device gameplay loop, not a claim of 100 network players.


func _initialize() -> void:
    call_deferred("_verify")


func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director:=game.get_node("AuroraSectorMatch") as Node3D
    var combat:=game.get_node("CombatRange") as Node3D
    var operator:=game.get_node("Operator") as CharacterBody3D
    var hud:=game.get_node("TrainingHUD") as CanvasLayer
    if director==null:
        push_error("V74 director not created")
        quit(80)
        return
    for i in range(80):
        await physics_frame
    if director.mode!="training" or combat._targets.size()!=4:
        push_error("Training sandbox compatibility lost")
        quit(81)
        return

    hud._battle_down()
    await process_frame
    if director.mode!="sector_battle" or combat._targets.size()!=8 or combat.active_fighter_count()!=9:
        push_error("Battle did not create one player + eight AI opponents")
        quit(82)
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
    if director.radius>=director.INITIAL_RADIUS or director.radius<director.FINAL_RADIUS:
        push_error("Zone not shrinking over round time")
        quit(87)
        return

    # AI-vs-AI and permanent elimination test (no training respawn).
    var before: int=combat.active_fighter_count()
    var victim: CharacterBody3D=combat._targets[1]
    if not victim.sector_battle or victim._foes.size()!=8:
        push_error("AI not configured for free-for-all opponents")
        quit(88)
        return
    victim.take_training_damage(150.0)
    if victim.health>0 or combat.active_fighter_count()!=before-1:
        push_error("Elimination did not reduce the live participant count")
        quit(89)
        return
    for bot in combat._targets:
        if bot.health>0:
            bot.take_training_damage(180.0)
    director._process(.015)
    if not director.match_ended or not director.mode=="sector_battle":
        push_error("Victory did not end the last-survivor round")
        quit(90)
        return

    hud._battle_down()
    await process_frame
    if director.match_ended or combat.active_fighter_count()!=9 or director.get_loot_remaining()!=16:
        push_error("New sector battle failed to reset fighters/loot")
        quit(91)
        return

    print("V74 SECTOR BR PASS: 9 fighters, real supply pickup, zone damage+shrink, permanent eliminations, victory and retry")
    quit(0)
