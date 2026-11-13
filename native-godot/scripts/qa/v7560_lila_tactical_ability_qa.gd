extends SceneTree
## V75.60 — Lila's original approved tactical acceleration is triggered
## by real CharacterBody3D eliminations only. No simulated opponents.
const OPERATOR=preload("res://scripts/player/third_person_operator.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(value: bool,reason: String) -> void:
    if not value:
        failed=true
        push_error("V7560_LILA_ABILITY "+reason)


func _verify() -> void:
    check(OPERATOR.LILA_ACCELERATION_SECONDS==4.0 and
        is_equal_approx(OPERATOR.LILA_ACCELERATION_MULTIPLIER,1.20),
        "Lila mobility bonus was changed without balancing")
    check(OPERATOR.tactical_acceleration_scale(0.0)==1.0 and
        OPERATOR.tactical_acceleration_scale(-9.0)==1.0 and
        OPERATOR.tactical_acceleration_scale(INF)==1.0 and
        is_equal_approx(OPERATOR.tactical_acceleration_scale(3.0),1.2),
        "tactical mobility multiplier ignores invalid or expired status")
    var scene: PackedScene=load("res://scenes/Main.tscn") as PackedScene
    var world: Node3D=scene.instantiate()
    root.add_child(world)
    var player: CharacterBody3D=world.get_node("Operator")
    var director: Node3D=world.get_node("AuroraSectorMatch")
    var combat: Node3D=world.get_node("CombatRange")
    var hud: CanvasLayer=world.get_node("TrainingHUD")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    check(not player.activate_tactical_acceleration() and
        player.tactical_acceleration_remaining==0.0,
        "training must not grant Battle Royale-only Lila skill")
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(player.battle_royale_active and player.can_act() and
        player.tactical_acceleration_remaining==0.0,
        "fresh real BR must start with no fictitious ability bonus")
    var victim: CharacterBody3D=combat._targets[0]
    check(victim.health==100.0 and
        victim.take_training_damage(999.0,player),
        "player kill cannot be confirmed against a real target")
    check(combat.eliminations==1 and
        player.tactical_acceleration_remaining==4.0 and
        hud._lila_ability_seconds==4.0 and
        hud._lila_ability_label.text.contains("ACELERACIÓN TÁCTICA"),
        "physically confirmed player elimination did not activate Lila skill")
    var before: float=player.tactical_acceleration_remaining
    var rival_killer: CharacterBody3D=combat._targets[2]
    var rival_victim: CharacterBody3D=combat._targets[1]
    check(rival_victim.take_training_damage(999.0,rival_killer),
        "real enemy-on-enemy kill failed in tactical ability QA")
    check(combat.eliminations==1 and
        player.tactical_acceleration_remaining==before,
        "enemy-on-enemy kill granted player an unearned speed buff")
    var storm_victim: CharacterBody3D=combat._targets[3]
    check(storm_victim.take_training_damage(999.0,null),
        "storm elimination of a real enemy no longer works")
    check(combat.eliminations==1 and
        player.tactical_acceleration_remaining==before,
        "storm elimination falsely refreshed Lila's ability")
    var second_player_kill: CharacterBody3D=combat._targets[4]
    player.tactical_acceleration_remaining=1.25
    check(second_player_kill.take_training_damage(999.0,player) and
        is_equal_approx(player.tactical_acceleration_remaining,4.0),
        "second real player kill should refresh, not stack, acceleration")
    # UI countdown is distinct from the physics timer and never redraws
    # per-frame text unless the displayed whole second changes.
    hud._process(1.05)
    check(hud._lila_ability_label.text.contains("3s"),
        "real temporary-ability HUD has no visible countdown")
    hud._process(5.0)
    check(hud._lila_ability_label.text.is_empty(),
        "expired Lila skill left a permanent overlay")
    player.tactical_acceleration_remaining=0.0
    check(player.tactical_acceleration_scale(
        player.tactical_acceleration_remaining)==1.0,
        "expired sprint acceleration remains permanently active")
    player.royale_eliminated=true
    check(not player.activate_tactical_acceleration(),
        "dead player can activate a mobility ability")
    player.royale_eliminated=false
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(player.tactical_acceleration_remaining==0.0 and
        hud._lila_ability_seconds==0.0 and
        hud._lila_ability_label.text.is_empty() and
        combat.eliminations==0,
        "new round retained previous round's Lila buff or kill count")
    if not failed:
        print("V7560_LILA_ABILITY PASS real_player_kills=2 "+
            "enemy_kill_no_buff=1 storm_no_buff=1 "+
            "four_second_bounded_speed=1 hud_countdown=1 "+
            "no_dead_ability=1 round_reset=clean")
    quit(1 if failed else 0)
