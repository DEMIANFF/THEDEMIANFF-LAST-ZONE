extends SceneTree
## V75.49: healing is an actual interruptible gameplay action, not a tap
## that grants instant health. Real character, HUD, combat and battle director.
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(condition: bool,reason: String) -> void:
    if not condition:
        failed=true
        push_error("V7549_FIRST_AID "+reason)

func _verify() -> void:
    check(str(ProjectSettings.get_setting(
        "rendering/renderer/rendering_method.mobile"))=="mobile",
        "Android Vulkan Mobile must remain the only selected renderer")
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get_node("Operator")
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)

    var bar: ProgressBar=hud._heal_progress_bar
    check(bar!=null and bar.get_parent()==hud._medkit_button,
        "medkit progress must follow editable HUD button")
    check(combat.medkits_remaining==2 and combat._heal_remaining==0.0,
        "new match did not initialize medical supplies")

    player.receive_training_hit(48.0,true)
    var injured: float=player.training_health
    check(injured<60.0,"cannot test heal without real damage")

    combat._on_heal()
    check(combat._heal_remaining==combat.HEAL_APPLY_SECONDS and
        player.training_health==injured and combat.medkits_remaining==2,
        "first aid incorrectly heals instantly or spends a medkit early")
    check(bar.visible and hud._medkit_button.text=="CANCELAR",
        "live HUD lacks cancel/progress state")
    combat._process(1.0)
    check(combat.medkits_remaining==2 and
        player.training_health==injured and bar.value>0.0 and bar.value<100.0,
        "partially completed heal grants life or loses a consumable")

    combat._on_heal()
    check(combat._heal_remaining==0.0 and combat.medkits_remaining==2 and
        not bar.visible,
        "tapping medkit again must cancel without wasting a charge")

    combat._on_heal()
    player.set_touch_move_axis(Vector2.RIGHT)
    combat._process(.1)
    check(combat._heal_remaining==0.0 and combat.medkits_remaining==2,
        "moving on joystick must interrupt medkit application")
    player.set_touch_move_axis(Vector2.ZERO)

    combat._on_heal()
    player.receive_training_hit(3.0,true)
    check(combat._heal_remaining==0.0 and combat.medkits_remaining==2,
        "real incoming damage must interrupt healing")
    var injured_again: float=player.training_health

    combat._on_heal()
    combat._on_aim()
    check(combat._heal_remaining==0.0 and combat.medkits_remaining==2,
        "scope use must cancel a healing action")
    combat._on_heal()
    check(not combat.aim_active and combat.current_zoom==1.0,
        "first aid should release ADS without destroying camera state")
    combat._process(combat.HEAL_APPLY_SECONDS+.1)
    check(combat._heal_remaining==0.0 and combat.medkits_remaining==1 and
        absf(player.training_health-minf(100.0,injured_again+45.0))<.01,
        "completed heal did not restore exactly 45 HP and use one medkit")
    check(not bar.visible and hud._medkit_button.text=="CURAR 1",
        "completed first aid left a stale timer or wrong medkit count")
    check(int(combat.inventory_snapshot().get("medkits",-1))==1,
        "real inventory and on-screen first aid charges disagreed")

    combat._on_heal()
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    check(combat._heal_remaining==0.0 and combat.medkits_remaining==2 and
        not bar.visible,
        "battle restart leaked old first aid progress or medkits")
    if not failed:
        print("V7549_FIRST_AID PASS delayed_heal=1 damage_interrupt=1 "+
            "movement_cancel=1 ads_cancel=1 hud_progress=1 reset=1")
    quit(1 if failed else 0)
