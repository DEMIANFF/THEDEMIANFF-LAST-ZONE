extends SceneTree
## V75.56 regression — feedback is wired to real physics bodies and
## inventory, never fake multiplayer clients or synthetic FPS samples.
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(condition: bool,reason: String) -> void:
    if not condition:
        failed=true
        push_error("V7556_COMBAT_FEEDBACK "+reason)


func _verify() -> void:
    check(str(ProjectSettings.get_setting(
        "rendering/renderer/rendering_method.mobile"))=="mobile",
        "Android preview must remain one Vulkan Mobile renderer")
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get_node("Operator")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)

    check(combat.shots_fired_total==0 and combat.shots_hit_total==0 and
        combat.shot_accuracy_percent()==0 and
        combat.reloads_completed==0 and combat.empty_magazine_attempts==0,
        "new match must begin without fabricated shooting statistics")
    check(hud._combat_events.is_empty() and
        hud._combat_feed_label.text.is_empty(),
        "a fresh battle cannot show phantom elimination events")
    check(hud._armor_label.text=="ESCUDO 0 / 75",
        "mobile HUD lost its physical armor indicator")
    check(hud._reload_progress.get_parent()==hud._reload_button,
        "reload progress must follow the existing editable HUD button")

    # A finite AR reload consumes real reserve only on completion.
    combat.ammo[0]=0
    combat.reserve[0]=31
    combat.trigger_held=false
    combat._on_reload()
    check(combat.reload_timer==combat.AR_RELOAD_SECONDS and
        combat.ammo[0]==0 and combat.reserve[0]==31 and
        hud._reload_progress.visible,
        "timed reload spent bullets immediately or never started")
    combat._process(combat.AR_RELOAD_SECONDS*.5)
    check(combat.reload_timer>0 and combat.ammo[0]==0 and
        hud._reload_progress.value>0.0 and
        hud._reload_progress.value<100.0,
        "real reload halfway point lacks progress or spends early ammo")
    combat._process(combat.AR_RELOAD_SECONDS)
    check(combat.reload_timer==0 and combat.ammo[0]==30 and
        combat.reserve[0]==1 and combat.reloads_completed==1 and
        not hud._reload_progress.visible,
        "reload completion, reserve consumption or progress reset incorrect")

    # Never let a held trigger spam a no-ammunition event once per frame.
    combat.ammo[0]=0
    combat.reserve[0]=0
    combat._on_fire_pressed()
    var once_empty: int=combat.empty_magazine_attempts
    check(once_empty==1 and not combat.trigger_held and
        hud._ammo.text.contains("SIN BALAS")==false,
        "empty shot should be refused; ammo view updates only after sync")
    combat._sync_hud()
    check(hud._ammo.text.contains("SIN BALAS"),
        "empty reserve must be visibly marked in combat HUD")
    combat._process(.5)
    check(combat.empty_magazine_attempts==once_empty and
        combat.shots_fired_total==0 and
        not combat.trigger_held,
        "holding fire with zero ammo produced false shots or repeated events")

    # Actual CharacterBody3D eliminations, not a fake feed from a timer.
    var victim: CharacterBody3D=combat._targets[0]
    var rival: CharacterBody3D=combat._targets[1]
    var other: CharacterBody3D=combat._targets[2]
    var storm_victim: CharacterBody3D=combat._targets[3]
    check(victim.take_training_damage(999.0,player),
        "player cannot eliminate a real opponent")
    check(combat.eliminations==1 and hud._combat_events.size()==1 and
        hud._combat_feed_label.text.contains("TU ELIMINASTE RIVAL 01"),
        "player elimination was not recorded in the bounded HUD feed")
    check(rival.take_training_damage(999.0,other),
        "real bot-on-bot elimination did not register")
    check(combat.eliminations==1 and hud._combat_events.size()==2 and
        hud._combat_feed_label.text.contains("RIVAL 03 ELIMINO RIVAL 02"),
        "AI elimination incorrectly credited the user or was absent")
    check(storm_victim.take_training_damage(999.0,null),
        "storm cannot physically eliminate a low-health enemy")
    check(combat.eliminations==1 and hud._combat_events.size()==3 and
        hud._combat_feed_label.text.contains("ZONA ELIMINO RIVAL 04"),
        "environment elimination invented a player kill")
    hud.push_combat_event("RIVAL 05 ELIMINO RIVAL 06")
    hud.push_combat_event("RIVAL 07 ELIMINO RIVAL 08")
    check(hud._combat_events.size()==hud.MAX_VISIBLE_COMBAT_EVENTS and
        not hud._combat_feed_label.text.contains("TU ELIMINASTE"),
        "combat feed was not bounded to four events")

    # Hits show the actual HP delta and disappear; they do not replace
    # the central scope/crosshair or become a permanent overlay.
    hud.show_confirmed_hit(18.0,false)
    check(hud._hit_confirm_label.text=="+18",
        "real damage marker missing from the attack reticle")
    hud.show_confirmed_hit(54.0,true)
    check(hud._hit_confirm_label.text=="BAJA +54",
        "confirmed elimination feedback missing")
    hud._process(.70)
    check(hud._hit_confirm_label.text.is_empty(),
        "hit markers never expire")
    hud._process(hud.COMBAT_EVENT_DURATION+.1)
    check(hud._combat_feed_label.text.is_empty(),
        "expired eliminations stay on screen and obscure battle")

    player._training_immunity=0.0
    check(player.equip_armor(75.0) and
        hud._armor_label.text=="ESCUDO 75 / 75",
        "equipping a physical shield does not update combat HUD")
    player.receive_training_hit(20.0,false,
        player.global_position+Vector3(0,0,-8))
    check(hud._armor_label.text.contains("ESCUDO 62"),
        "enemy damage did not update the shield's real durability")

    var site: Vector3=Vector3(director.CENTER.x+director.INITIAL_RADIUS+9.0,
        terrain.height_at(director.CENTER.x+director.INITIAL_RADIUS+9.0,
            director.CENTER.y)+.20,director.CENTER.y)
    player.global_position=site
    player.velocity=Vector3.ZERO
    director._ui_clock=0.0
    director._process(0.0)
    check(hud._zone_warning_label.text.contains("FUERA DE ZONA") and
        director._zone_entries==1,
        "actual player outside the physical ring lacks distance warning")
    director._ui_clock=0.0
    director._process(0.0)
    check(director._zone_entries==1,
        "same zone excursion spammed the warning again")
    player.global_position=Vector3(
        director.CENTER.x,terrain.height_at(director.CENTER.x,director.CENTER.y)+.20,
        director.CENTER.y)
    director._ui_clock=0.0
    director._process(0.0)
    check(hud._zone_warning_label.text.is_empty(),
        "safe-zone reentry leaves a stale warning")
    check(combat.shot_accuracy_percent()==0,
        "never shooting cannot be scored as accurate")
    combat.shots_fired_total=6
    combat.shots_hit_total=2
    check(combat.shot_accuracy_percent()==33 and
        int(combat.inventory_snapshot()["accuracy"])==33,
        "ballistic accuracy math disagrees with actual inventory snapshot")

    director._finish(false)
    check(hud._result_text.text.contains("PRECISIÓN: 33%") and
        director.match_ended and director.last_match_saved,
        "final match result lost accuracy or existing atomic match ledger")
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(combat.shot_accuracy_percent()==0 and
        combat.reloads_completed==0 and combat.eliminations==0 and
        hud._combat_events.is_empty() and
        hud._zone_warning_label.text.is_empty() and
        not hud._reload_progress.visible,
        "new match leaked old hits, reload, zone warnings or gunfight results")
    if not failed:
        print("V7556_COMBAT_FEEDBACK PASS vulkan=1 reload=1 no_ammo_spam=1 "+
            "real_kill_feed=1 ai_kills=1 storm_kills=1 bounded_events=1 "+
            "damage_markers=1 armor=1 zone_distance=1 accuracy=1 reset=1")
    quit(1 if failed else 0)
