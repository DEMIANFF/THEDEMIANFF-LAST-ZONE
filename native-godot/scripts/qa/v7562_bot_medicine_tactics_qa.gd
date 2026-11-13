extends SceneTree
## V75.62 — real physics CharacterBody3D medkit channel and tactical
## magazines. Tests player-shot interruption; no simulated online clients.
const BOT=preload("res://scripts/ai/aurora_bot.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7562_BOT_MEDICINE "+reason)

func _verify() -> void:
    check(BOT.FIELD_MEDKIT_CAPACITY==1 and BOT.FIELD_MEDKIT_SECONDS>=2.5 and
        BOT.FIELD_MEDKIT_SECONDS<=4.0 and
        BOT.FIELD_MEDKIT_HEAL<=50.0 and BOT.PROACTIVE_RELOAD_THRESHOLD<=4,
        "limited supplies or mobile tactical action balance regressed")
    check(str(ProjectSettings.get_setting(
        "rendering/renderer/rendering_method.mobile"))=="mobile",
        "Android Vulkan renderer must remain the only mobile target")
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get_node("Operator")
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var nav: Node3D=game.get_node("AuroraNavigation")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    for b in combat._targets:
        b.set_physics_process(false)
    await physics_frame
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    nav.set_physics_process(false)
    player.set_physics_process(false)
    for b in combat._targets:
        b.set_physics_process(false)
    var actor: CharacterBody3D=combat._targets[0]
    actor.global_position=Vector3(5.0,terrain.height_at(5.0,-20.0)+.17,-20.0)
    actor.velocity=Vector3.ZERO
    actor._sense_clock=90.0
    actor._target_actor=null
    actor._target_visible=false
    actor._magazine=9
    actor.health=35.0
    await physics_frame
    check(actor._should_field_heal() and actor._field_medkits==1,
        "physical wounded enemy cannot access one real carried medkit")
    check(actor._begin_field_heal() and
        actor._heal_remaining==BOT.FIELD_MEDKIT_SECONDS and
        actor.get_node("TrainingTargetMarker").text.contains("CURANDO"),
        "tactical healing never creates a visible timed enemy state")
    check(actor._advance_field_heal(1.0) and
        actor.health==35.0 and actor._field_medkits==1 and
        actor.heal_channels_completed==0,
        "medkit applied immediately instead of waiting for real channel")
    check(actor.take_training_damage(6.0,player)==false and
        actor._heal_remaining==0.0 and
        actor._field_medkits==1 and
        actor.heal_channels_interrupted==1 and
        actor.get_node("TrainingTargetMarker").text=="ENEMIGO IA",
        "real damage failed to interrupt enemy healing without consuming item")
    check(not actor._begin_field_heal() and actor._heal_cooldown>0.0,
        "interrupted heal immediately restarted without tactical delay")
    actor._heal_cooldown=0.0
    actor._target_visible=true
    check(not actor._should_field_heal(),
        "exposed enemy cannot heal while a live opponent is visible")
    actor._target_visible=false
    actor.safe_radius=10.0
    actor.safe_center=Vector2(1000,1000)
    check(not actor._should_field_heal(),
        "enemy started a three-second medkit outside active safe ring")
    actor.safe_radius=112.0
    actor.safe_center=director.CENTER
    actor._sense_clock=90.0
    actor._magazine=9
    check(actor._should_field_heal(),"wounded enemy never recovered to a safe healing state")
    # Reach the action using the real bot physics handler, rather than
    # only invoking its internal method through a synthetic data structure.
    actor._physics_process(.016)
    check(actor._heal_remaining==BOT.FIELD_MEDKIT_SECONDS,
        "real opponent physics did not enter autonomous healing state")
    actor._advance_field_heal(1.25)
    check(actor.health==29.0 and actor._field_medkits==1,
        "healing granted life before physical channel elapsed")
    actor._advance_field_heal(2.0)
    check(actor._heal_remaining==0.0 and
        actor.health==69.0 and actor._field_medkits==0 and
        actor.heal_channels_completed==1 and
        actor.get_node("TrainingTargetMarker").text=="ENEMIGO IA",
        "completed limited field medkit did not restore actual AI health once")
    actor.health=15.0
    check(not actor._begin_field_heal(),
        "bot illegally generated unlimited medkits after first use")

    # Another physical opponent can reload proactively while undetected.
    var gunner: CharacterBody3D=combat._targets[1]
    gunner.global_position=Vector3(6.0,terrain.height_at(6.0,-20.0)+.17,-20.0)
    gunner.health=90.0
    gunner._target_visible=false
    gunner._target_actor=null
    gunner._sense_clock=90.0
    gunner._attack_clock=20.0
    gunner._magazine=3
    gunner._reload_remaining=0.0
    await physics_frame
    gunner._physics_process(.016)
    check(gunner._reload_remaining>BOT.RELOAD_SECONDS-.1 and
        gunner._magazine==3 and gunner.shots_fired==0,
        "hidden armed opponent did not anticipate a low magazine")
    for step in range(3):
        gunner._physics_process(.40)
    check(gunner._reload_remaining>0.0 and
        gunner._magazine==3 and gunner.shots_fired==0,
        "tactical enemy fired rounds while still reloading")
    for step in range(3):
        gunner._physics_process(.40)
    check(gunner._reload_remaining==0.0 and
        gunner._magazine==BOT.MAGAZINE_CAPACITY and
        gunner.reloads_completed==1,
        "real AI reload was not completed with full magazine")
    # A visible target must be engaged rather than abruptly reloading.
    gunner._target_visible=true
    gunner._target_actor=player
    gunner._sense_clock=90.0
    gunner._magazine=BOT.PROACTIVE_RELOAD_THRESHOLD
    gunner._reload_remaining=0.0
    gunner._attack_clock=20.0
    gunner._physics_process(.016)
    check(gunner._reload_remaining==0.0 and
        gunner._magazine==BOT.PROACTIVE_RELOAD_THRESHOLD,
        "AI attempted proactive reload with a live target in sight")

    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    nav.set_physics_process(false)
    player.set_physics_process(false)
    for b in combat._targets:
        b.set_physics_process(false)
    check(actor._field_medkits==1 and actor._heal_remaining==0.0 and
        actor.heal_channels_completed==0 and
        actor.heal_channels_interrupted==0 and
        gunner._field_medkits==1 and gunner._reload_remaining==0.0 and
        gunner.reloads_completed==0,
        "BR restart leaked medkits, healing states or old reloading stats")
    if not failed:
        print("V7562_BOT_MEDICINE PASS one_use_medkit=1 "+
            "three_second_channel=1 damage_interrupt=1 cooldown=1 "+
            "visible_enemy_blocked=1 zone_safe=1 physics_autonomous=1 "+
            "limited_healing=1 proactive_reload=1 active_fire_priority=1 "+
            "match_reset=clean vulkan=1")
    quit(1 if failed else 0)
