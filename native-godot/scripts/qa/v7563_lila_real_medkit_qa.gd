extends SceneTree
## Real Godot Lila skeletal first-aid animation and bone-mounted injectable.
## One real health source and timer; no cosmetic-only life gain or dummy rig.
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7563_LILA_MEDKIT "+reason)

func _verify() -> void:
    check(str(ProjectSettings.get_setting(
        "rendering/renderer/rendering_method.mobile"))=="mobile",
        "Vulkan Mobile renderer lost")
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

    var animator: AnimationPlayer=player._animator
    check(animator!=null and animator.has_animation("AuroraHeal") and
        absf(animator.get_animation("AuroraHeal").length-3.0)<.08,
        "three-second authored Blender skeletal first-aid clip was not imported")
    var socket: BoneAttachment3D=player._medkit_socket
    var injector: Node3D=player._medkit_visual
    check(socket!=null and injector!=null and
        socket.get_parent() is Skeleton3D and
        socket.bone_name.to_lower().ends_with("lefthand"),
        "medical injector is not physically attached to Lila's left-hand bone")
    if socket!=null and injector!=null:
        check(injector.get_parent()==socket and
            injector.name=="LilaAuroraMedicalInjector" and
            not injector.visible,
            "original medical injector was not hidden before use")
        check(injector.get_child_count()==5 and
            injector.get_node_or_null("AuroraInjectorCartridge")!=null and
            injector.get_node_or_null("AuroraInjectorDoseWindow")!=null and
            injector.get_node_or_null("AuroraMedicalEmblem0")!=null,
            "medical cartridge lacks the real 3D original geometry")
        check(injector.global_position.is_finite() and
            injector.global_position.distance_to(player.global_position)<3.0,
            "medical mesh is detached from the skinned player's arm")
    check(combat._heal_remaining==0.0 and combat.medkits_remaining==2,
        "new BR unexpectedly starts healing or losing supplies")
    player.receive_training_hit(40.0,true)
    var before_health: float=player.training_health
    check(before_health==60.0,"physical environmental damage failed")
    combat._on_heal()
    check(combat._heal_remaining==combat.HEAL_APPLY_SECONDS and
        player._combat_action=="AuroraHeal" and
        player._animation_controller.action_clip.animation=="AuroraHeal" and
        injector.visible and
        player.training_health==before_health and
        combat.medkits_remaining==2 and hud._heal_progress_bar.visible,
        "real medkit start failed to activate both skeletal rig and real HUD")
    combat._process(1.0)
    check(combat._heal_remaining>1.8 and
        injector.visible and player.training_health==before_health and
        combat.medkits_remaining==2,
        "partial skeletal first aid granted life too early")
    # Existing medkit touch control cancels exactly once, no phantom prop.
    combat._on_heal()
    check(combat._heal_remaining==0.0 and not injector.visible and
        player._combat_action!="AuroraHeal" and
        combat.medkits_remaining==2 and
        not hud._heal_progress_bar.visible,
        "tap-to-cancel left injector on-screen or consumed a charge")
    combat._on_heal()
    check(injector.visible and player._combat_action=="AuroraHeal",
        "medical equipment did not reappear for a fresh channel")
    player.receive_training_hit(6.0,true)
    check(combat._heal_remaining==0.0 and not injector.visible and
        player._combat_action!="AuroraHeal" and
        combat.medkits_remaining==2,
        "physical damage interrupted health timer but not 3D injector")
    combat._on_heal()
    player.set_touch_move_axis(Vector2.RIGHT)
    combat._process(.1)
    check(combat._heal_remaining==0.0 and not injector.visible and
        combat.medkits_remaining==2,
        "physical joystick movement failed to cancel both healing and animation")
    player.set_touch_move_axis(Vector2.ZERO)
    combat._on_heal()
    var heal_target: float=player.training_health
    combat._process(combat.HEAL_APPLY_SECONDS+.1)
    check(combat._heal_remaining==0.0 and
        not injector.visible and player._combat_action!="AuroraHeal" and
        combat.medkits_remaining==1 and
        absf(player.training_health-minf(100.0,heal_target+45.0))<.01 and
        not hud._heal_progress_bar.visible,
        "completed real medkit failed to consume one supply, heal once or remove injector")
    combat._on_heal()
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    check(combat._heal_remaining==0.0 and
        not injector.visible and combat.medkits_remaining==2 and
        not hud._heal_progress_bar.visible and
        player._combat_action!="AuroraHeal",
        "BR restart leaked Lila medkit prop, animation or consumable")
    # Aircraft transition uses the same protected reset; it must not carry
    # a visible syringe during a jump/freefall or parachute.
    player.begin_aircraft()
    check(not injector.visible and
        player._combat_action!="AuroraHeal" and
        player.air_mode=="aircraft",
        "airplane spawned a phantom visible medkit")
    if not failed:
        print("V7563_LILA_MEDKIT PASS authored_animation=1 "+
            "left_hand_socket=1 original_injector=1 real_channel=3s "+
            "damage_interrupt=1 movement_interrupt=1 touch_cancel=1 "+
            "one_health_commit=1 finite_inventory=1 reset=clean "+
            "aircraft=clean vulkan=1")
    quit(1 if failed else 0)
