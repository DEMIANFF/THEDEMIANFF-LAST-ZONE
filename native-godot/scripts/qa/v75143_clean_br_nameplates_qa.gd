extends SceneTree
## V75.143: developer-only "ENEMIGO IA"/healing nameplates must not
## be visible in the 50-participant Battle Royale. Training still uses
## its diagnostic nameplate. Health, collision and medicine remain real.
const COMBAT=preload("res://scripts/combat/training_combat.gd")
const BOT=preload("res://scripts/ai/aurora_bot.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75143_CLEAN_BR_NAMEPLATES "+reason)


func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var player: CharacterBody3D=game.get_node("Operator")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    # The original human-readable training marker must remain available.
    var training: CharacterBody3D=combat._targets[0]
    var training_plate: Label3D=training.get_node_or_null(
        "TrainingTargetMarker") as Label3D
    check(training_plate!=null and training_plate.visible and
        training_plate.text=="ENEMIGO IA" and not training.sector_battle,
        "debug names were removed from training instead of BR only")

    combat.set_encounter_size(COMBAT.CLASSIC_BR_PARTICIPANTS)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for rival in combat._targets:
        rival.set_physics_process(false)
    check(combat._targets.size()==49 and
        combat.active_fighter_count()==50,
        "physical 50-combatant Battle Royale was replaced")
    for rival in combat._targets:
        var plate: Label3D=rival.get_node_or_null(
            "TrainingTargetMarker") as Label3D
        check(plate!=null and not plate.visible and
            rival.health==BOT.MAX_HEALTH and
            rival.get_node_or_null("OpponentCollider") is CollisionShape3D,
            "visible debug name or missing real 200HP physics opponent")

    # Heal-status name changes must never reveal a rival from behind
    # foliage, rooftops or walls. The existing finite field medkit still
    # restores only its authored 40 HP after a real three-second channel.
    var wounded: CharacterBody3D=combat._targets[0]
    var wound_plate: Label3D=wounded.get_node("TrainingTargetMarker")
    wounded.health=80.0
    wounded._field_medkits=1
    wounded._target_visible=false
    wounded._reload_remaining=0.0
    wounded._heal_remaining=0.0
    wounded.safe_center=Vector2(
        wounded.global_position.x,wounded.global_position.z)
    wounded.safe_radius=50.0
    check(wounded._begin_field_heal() and
        wound_plate.text=="RIVAL / CURANDO" and
        not wound_plate.visible,
        "real enemy medicine exposed an overhead healing status")
    wounded._advance_field_heal(BOT.FIELD_MEDKIT_SECONDS+.01)
    check(wounded.health==80.0+BOT.FIELD_MEDKIT_HEAL and
        wounded._field_medkits==0 and
        wound_plate.text=="ENEMIGO IA" and
        not wound_plate.visible,
        "finite field medkit or label privacy regressed")

    # The animation/lifecycle reset must not resurrect a debug label.
    wounded._reset_death_presentation()
    check(not wound_plate.visible,
        "death presentation reset makes BR AI marker visible again")
    var airborne: CharacterBody3D=combat._targets[1]
    airborne.begin_real_airdrop(
        airborne.global_position+Vector3.UP*70.0,5.0)
    check(not airborne.get_node("TrainingTargetMarker").visible,
        "aircraft deployment exposes a training debug marker")
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for rival in combat._targets:
        rival.set_physics_process(false)
        var fresh: Label3D=rival.get_node("TrainingTargetMarker")
        check(not fresh.visible and rival.health==BOT.MAX_HEALTH,
            "next BR round resurrected a prototype label or kept wounds")
    check(combat.active_fighter_count()==50,
        "nameplate removal changed real fighter inventory")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75143_CLEAN_BR_NAMEPLATES PASS real_roster=50 "+
            "200hp=1 colliders=49 training_label=1 battle_labels=0 "+
            "heal_status_hidden=1 real_medkit=40 air_drop_hidden=1 "+
            "round_reset_hidden=1")
    quit(1 if failed else 0)
