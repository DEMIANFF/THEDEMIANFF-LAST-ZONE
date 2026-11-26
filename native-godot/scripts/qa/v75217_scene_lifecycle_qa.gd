extends SceneTree
const BOT=preload("res://scripts/ai/aurora_bot.gd")
var failed: bool=false
func _initialize() -> void:
    call_deferred("_verify")
func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V75217_LIFECYCLE "+why)
func _verify() -> void:
    var buses: int=-1
    var baseline_orphans: int=int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
    for cycle in range(3):
        var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
        root.add_child(game)
        var combat: Node3D=game.get_node("CombatRange")
        var sound: Node3D=game.get_node("AuroraSoundStage")
        var director: Node3D=game.get_node("AuroraSectorMatch")
        await physics_frame
        var bot: CharacterBody3D=combat._targets[0]
        check(bot.health==BOT.MAX_HEALTH and bot.respawn_enabled,"training bot state")
        check(bot.take_training_damage(BOT.MAX_HEALTH),"training lethal damage")
        var timer: Timer=bot.get_node_or_null("TrainingRespawnTimer") as Timer
        if timer==null:
            check(false,"respawn timer not owned by bot")
            game.queue_free()
            await process_frame
            break
        check(timer.get_parent()==bot and not timer.is_stopped() and is_equal_approx(timer.wait_time,7.0),"training seven-second timer")
        # Shorten only the QA wait after verifying the production deadline.
        timer.start(.05)
        for frame in range(60):
            await process_frame
            if bot.health==BOT.MAX_HEALTH:
                break
        await physics_frame
        check(bot.health==BOT.MAX_HEALTH and timer.is_stopped() and bot.is_physics_processing(),"real timer failed to respawn training bot")
        check(bot.take_training_damage(BOT.MAX_HEALTH),"second training death")
        check(bot._respawn_timer==timer and not timer.is_stopped(),"duplicated training timer")
        if cycle==1:
            bot.begin_real_airdrop(Vector3(0,100,0),10.0)
            check(timer.is_stopped(),"airdrop failed to cancel training deadline")
        combat.set_encounter_size(50)
        director.start_sector_battle()
        check(combat._targets.size()==49 and combat.active_fighter_count()==50,"real BR roster")
        check(timer.is_stopped() and bot.health==BOT.MAX_HEALTH and not bot.respawn_enabled,"training timer survived BR entry")
        # Exercise a stale callback directly: live BR health and location must not change.
        bot.take_training_damage(20.0)
        var hp: float=bot.health
        var at: Vector3=bot.global_position
        bot._respawn()
        check(bot.health==hp and bot.global_position==at,"stale respawn revived live BR bot")
        check(bot.take_training_damage(BOT.MAX_HEALTH),"BR lethal damage")
        bot._respawn()
        check(bot.health==0.0 and timer.is_stopped(),"BR dead bot respawned")
        sound.play_event("ar_fire")
        sound.play_world_shot(game.get_node("Operator").global_position)
        sound.play_operator_contact(false,true)
        sound.set_aircraft_audio(true)
        var voices: Array[Node]=sound.find_children("*","AudioStreamPlayer",true,false)
        check(voices.size()==22,"unexpected voice pool size")
        var voice_refs: Array[WeakRef]=[]
        for voice in voices:
            voice_refs.append(weakref(voice))
        if buses<0:
            buses=AudioServer.bus_count
        check(AudioServer.bus_count==buses,"mixer bus count grew across maps")
        if cycle!=2:
            sound.shutdown()
            sound.shutdown()
            sound.set_enabled(true)
            check(not sound._sound_enabled and sound._closing,"shutdown not idempotent")
            for voice in voices:
                check(not voice.playing and voice.stream==null,"audio retained after explicit shutdown")
        var bot_ref: WeakRef=weakref(bot)
        var timer_ref: WeakRef=weakref(timer)
        var map_ref: WeakRef=weakref(game)
        game.queue_free()
        for frame in range(5):
            await process_frame
        check(map_ref.get_ref()==null and bot_ref.get_ref()==null and timer_ref.get_ref()==null,"map/bot/timer leaked")
        for ref in voice_refs:
            check(ref.get_ref()==null,"audio voice leaked")
        check(get_nodes_in_group(BOT.DETAILED_ENEMY_GROUP).is_empty(),"rig lease leaked")
        var orphans: int=int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
        check(orphans==baseline_orphans,"orphan node count changed: "+str(orphans))
        print("V75217_CYCLE ",cycle+1," roster=50 voices=",voices.size()," mixer_buses=",buses," orphans=",orphans," baseline=",baseline_orphans)
    if not failed:
        print("V75217_LIFECYCLE PASS cycles=3")
    quit(1 if failed else 0)
