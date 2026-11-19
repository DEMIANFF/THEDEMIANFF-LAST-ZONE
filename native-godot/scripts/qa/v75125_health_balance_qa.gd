extends SceneTree
## 200 HP regression: real CharacterBody3D, HUD and medical recovery.
const BOT=preload("res://scripts/ai/aurora_bot.gd")
const PLAYER=preload("res://scripts/player/third_person_operator.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75125_HEALTH_BALANCE "+reason)

func _verify() -> void:
    check(PLAYER.MAX_HEALTH==200.0 and BOT.MAX_HEALTH==PLAYER.MAX_HEALTH,
        "player and enemy health pools must both equal 200 HP")
    check(BOT.RIFLE_DAMAGE>=18.0 and BOT.RIFLE_DAMAGE<=23.0,
        "AI still has ineffective five-HP hits or excessive one-shot damage")
    check(BOT.FIELD_MEDKIT_HEALTH_THRESHOLD>=70.0 and
        BOT.FIELD_MEDKIT_HEALTH_THRESHOLD<PLAYER.MAX_HEALTH*.5,
        "enemy tactical heal threshold not adapted to 200 HP")
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get_node("Operator")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var navigation: Node3D=game.get_node("AuroraNavigation")
    await physics_frame
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    navigation.set_physics_process(false)
    player.set_physics_process(false)
    for enemy in combat._targets:
        enemy.set_physics_process(false)
    check(player.training_health==PLAYER.MAX_HEALTH and
        player.battle_royale_active and
        float(hud._health_meter.max_value)==PLAYER.MAX_HEALTH and
        hud._health_label.text.contains("200 / 200"),
        "BR health or visual HUD is still stuck at 100")
    for rival in combat._targets:
        check(rival.health==BOT.MAX_HEALTH,
            "opponent lacks 200 physical health at match spawn")
    player._training_immunity=0.0
    player.receive_training_hit(20.0,false,Vector3(3,2,5))
    check(player.training_health==180.0 and
        hud._health_label.text.contains("180 / 200"),
        "enemy damage did not remove real health or update HUD")
    player.receive_training_heal(100.0)
    check(player.training_health==200.0,
        "medical recovery exceeded 200 HP or is still capped at 100")
    var rival: CharacterBody3D=combat._targets[0]
    check(not rival.take_training_damage(140.0,player) and
        rival.health==60.0,
        "200-HP enemy is still defeated by 140 damage")
    rival._heal_remaining=BOT.FIELD_MEDKIT_SECONDS
    rival._field_medkits=1
    rival._advance_field_heal(BOT.FIELD_MEDKIT_SECONDS)
    check(rival.health==100.0 and rival._field_medkits==0,
        "enemy medical action failed to restore actual health")
    rival.health=190.0
    rival._field_medkits=1
    rival._heal_remaining=BOT.FIELD_MEDKIT_SECONDS
    rival._advance_field_heal(BOT.FIELD_MEDKIT_SECONDS)
    check(rival.health==BOT.MAX_HEALTH,
        "enemy medicine exceeded the new maximum")
    director.start_sector_battle()
    check(player.training_health==PLAYER.MAX_HEALTH and
        combat._targets[0].health==BOT.MAX_HEALTH,
        "new round leaked wounds or reset to the old 100 HP")
    if not failed:
        print("V75125_HEALTH_BALANCE PASS player_hp=200 bot_hp=200 "+
            "combat_damage=20 visual_hud=200 timed_healing=1 restart=200")
    quit(1 if failed else 0)
