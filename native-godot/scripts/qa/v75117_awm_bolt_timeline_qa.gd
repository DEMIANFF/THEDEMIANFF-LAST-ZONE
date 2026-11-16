extends SceneTree
## V75.117: original AWM shot/bolt/audio coordination, inspired only by
## structural findings in a 2019 static-analysis report. No imported assets.
const WEAPONS=preload("res://scripts/combat/aurora_weapon_catalog.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75117_AWM_BOLT "+reason)


func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var operator: CharacterBody3D=game.get_node("Operator")
    var audio: Node=game.get_node("AuroraSoundStage")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    await physics_frame
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    operator.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    var pickup: Area3D=director.get_node("AuroraAWMWeaponPickup")
    operator.global_position=pickup.global_position-Vector3.UP
    operator.velocity=Vector3.ZERO
    await physics_frame
    if not pickup.collected:
        pickup._collect(operator)
    combat._equip_inventory_weapon(WEAPONS.AWM)
    check(combat.weapon_index==WEAPONS.AWM and combat.weapon_owned[WEAPONS.AWM] and
        combat._weapon_visuals.awm.visible,
        "AWM must be physically collected and present in Lila's hands")
    check(audio._samples.has("awm_fire") and audio._samples.has("awm_bolt") and
        (audio._samples["awm_bolt"] as AudioStreamWAV).data.size()>5000 and
        audio._samples["awm_fire"]!=audio._samples["awm_bolt"],
        "distinct original shot and mechanical bolt audio missing")
    check(combat.awm_bolt_cycled.get_connections().size()>=1,
        "main audio stage not connected to the actual bolt event")
    check(combat.AWM_BOLT_CUE_SECONDS>0.0 and
        combat.AWM_BOLT_CUE_SECONDS<combat.AWM_BOLT_SECONDS,
        "bolt sound must occur inside, not after, 0.5-second shot lock")

    var cues: Array[int]=[]
    combat.awm_bolt_cycled.connect(func(): cues.append(1))
    combat.ammo[WEAPONS.AWM]=2
    combat.cooldown=0.0
    combat.reload_timer=0.0
    var shots: int=combat.shots_fired_total
    combat._shoot()
    check(combat.ammo[WEAPONS.AWM]==1 and
        combat.shots_fired_total==shots+1 and
        combat.cooldown==combat.AWM_BOLT_SECONDS and
        operator._combat_action=="AuroraFireAWM" and
        combat._awm_bolt_pending and cues.is_empty(),
        "sniper trigger did not consume exactly one real round")
    combat._shoot()
    check(combat.ammo[WEAPONS.AWM]==1 and cues.is_empty(),
        "bolt lock incorrectly admitted a second immediate round")
    combat._advance_awm_bolt(combat.AWM_BOLT_CUE_SECONDS-.02)
    check(cues.is_empty() and combat._awm_bolt_pending,
        "bolt cue triggered before action reaches mechanical cycling")
    combat._advance_awm_bolt(.025)
    combat._advance_awm_bolt(1.0)
    check(cues.size()==1 and not combat._awm_bolt_pending,
        "one sniper round generated duplicate or missing bolt cues")

    # Reload supersedes the old bolt cue; no stale sound after switching.
    combat.cooldown=0.0
    combat._shoot()
    check(combat.ammo[WEAPONS.AWM]==0 and combat._awm_bolt_pending,
        "last physical sniper round did not queue its mechanical cycle")
    combat._on_reload()
    check(combat.reload_timer>0 and not combat._awm_bolt_pending,
        "magazine reload did not supersede in-flight AWM bolt")
    combat._advance_awm_bolt(5.0)
    check(cues.size()==1,
        "cancelled bolt cue played after starting magazine reload")
    combat._clear_reload()
    combat._equip_inventory_weapon(WEAPONS.AR)
    check(combat.weapon_index==WEAPONS.AR and
        not combat._awm_bolt_pending,
        "weapon change leaked AWM bolt state")
    combat._awm_bolt_pending=true
    combat._awm_bolt_remaining=.2
    combat.end_sector_battle()
    check(not combat._awm_bolt_pending and
        combat._awm_bolt_remaining==0.0,
        "end-of-match left a delayed mechanical sound pending")

    game.queue_free()
    await process_frame
    if not failed:
        print("V75117_AWM_BOLT PASS physical_rifle=1 ammo=single "+
            "cooldown=.50 cue=once original_audio=1 "+
            "reload_cancel=1 swap_cancel=1 match_cleanup=1")
    quit(1 if failed else 0)
