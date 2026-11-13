extends SceneTree
## V75.66 — Verify one AWM round drives the real skinned 0.5s bolt,
## a pooled muzzle flash and bounded visual recoil. Ballistics and
## physical cover checks must use a muzzle unaffected by visual effects.
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V7566_AWM_BOLT_RECOIL "+why)


func _verify() -> void:
    check(str(ProjectSettings.get_setting(
        "rendering/renderer/rendering_method.mobile"))=="mobile",
        "Android must remain Vulkan Mobile only")
    var main: PackedScene=load("res://scenes/Main.tscn") as PackedScene
    var game: Node3D=main.instantiate()
    root.add_child(game)
    var combat: Node3D=game.get_node("CombatRange")
    var operator: CharacterBody3D=game.get_node("Operator")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var visuals: Node3D=combat._weapon_visuals
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    operator.set_physics_process(false)
    director.set_process(false)
    combat.set_process(false)

    var player_animation: AnimationPlayer=operator._animator
    var controller: Node=operator._animation_controller
    check(player_animation!=null and controller!=null and
        player_animation.has_animation("AuroraBoltAWM") and
        controller.tree.active,
        "original rig did not import actual articulated AWM bolt clip")
    if player_animation!=null and player_animation.has_animation("AuroraBoltAWM"):
        var animation: Animation=player_animation.get_animation("AuroraBoltAWM")
        check(animation.length>=.45 and animation.length<=.58 and
            animation.get_track_count()>12 and
            animation.loop_mode==Animation.LOOP_NONE,
            "AWM bolt must animate real arm/wrist bones for exactly its cooldown")
        var bones: String=""
        for i in range(animation.get_track_count()):
            bones+=str(animation.track_get_path(i)).to_lower()+" "
        check(bones.contains("spine") and bones.contains("rightarm") and
            bones.contains("rightforearm") and bones.contains("righthand"),
            "AWM bolt uses decorative camera shaking rather than articulated rig")
    check(visuals.attachment_uses_hand and
        visuals.right_hand_socket is BoneAttachment3D and
        visuals.right_hand_socket.get_parent() is Skeleton3D,
        "recoil model lost real skinned RightHand attachment")

    var effect: Node3D=visuals.muzzle_flash
    check(effect!=null and effect.get_child_count()==3 and
        not effect.visible and visuals.visual_shots==0,
        "reusable three-piece muzzle flash not prebuilt and hidden")
    if effect!=null:
        for mesh_node in effect.get_children():
            var part: MeshInstance3D=mesh_node as MeshInstance3D
            check(part!=null and
                part.material_override is StandardMaterial3D and
                part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
                "flash material is missing or creates expensive mobile shadows")

    # One actual AR shot after ammo decrement should create a flash and
    # small kick; neither affects the physical sight-to-muzzle cover ray.
    var first_muzzle: Vector3=visuals.muzzle_position()
    var ar_ammo: int=combat.ammo[0]
    var ar_events: int=combat.shots_fired_total
    combat.cooldown=0.0
    combat._on_fire_pressed()
    check(combat.ammo[0]==ar_ammo-1 and
        combat.shots_fired_total==ar_events+1 and
        visuals.visual_shots==1 and visuals._flash_remaining>0.0 and
        effect.visible and visuals._visual_kick>0.0 and
        visuals._visual_kick<=visuals.AR_VISUAL_KICK+.001 and
        operator._combat_action=="AuroraFire",
        "AR actual bullet isn't synchronized with pooled muzzle flash")
    var after_flash_muzzle: Vector3=visuals.muzzle_position()
    check(first_muzzle.is_finite() and after_flash_muzzle.is_finite() and
        first_muzzle.distance_to(after_flash_muzzle)<.012,
        "visual recoil moved the authoritative physical muzzle ray")
    combat._on_fire_released()
    visuals._process(.20)
    check(not effect.visible and visuals._flash_remaining==0.0 and
        visuals._visual_kick==0.0,
        "brief muzzle flash or visual kick does not decay on time")

    # Empty magazine must not create decorative fake shots, even if the
    # player presses the fire button repeatedly at full frame rate.
    combat.ammo[0]=0
    combat.reserve[0]=0
    combat.cooldown=0.0
    var shots_before_dry: int=visuals.visual_shots
    combat._on_fire_pressed()
    combat._on_fire_pressed()
    check(visuals.visual_shots==shots_before_dry and
        not effect.visible and combat.ammo[0]==0,
        "empty AR creates duplicate visuals without an actual bullet")

    # Training provides two owned weapons. AWM one-shot has its own
    # authored half-second bolt plus a visibly stronger weapon mesh kick.
    combat._on_weapon()
    combat.cooldown=0.0
    check(combat.weapon_index==1 and
        visuals.selected_weapon==1 and visuals.awm.visible and
        not effect.visible and visuals._visual_kick==0.0,
        "rifle switch left stale AR flash or chose the wrong visible weapon")
    combat._on_aim()
    check(combat.current_zoom==8.0 and operator._ads_active,
        "original AWM-exclusive x8 ADS has regressed")
    var awm_muzzle: Vector3=visuals.muzzle_position()
    var awm_ammo: int=combat.ammo[1]
    combat._on_fire_pressed()
    check(combat.ammo[1]==awm_ammo-1 and
        combat.cooldown>=.49 and
        visuals.visual_shots==shots_before_dry+1 and
        effect.visible and visuals._visual_kick>=visuals.AWM_VISUAL_KICK-.001 and
        operator._combat_action=="AuroraBoltAWM" and
        absf(operator._combat_action_seconds-.50)<.001 and
        controller.action_clip.animation=="AuroraBoltAWM" and
        controller.tree.get("parameters/UpperBody/active"),
        "real AWM round does not trigger authored half-second bolt and flash")
    check(awm_muzzle.distance_to(visuals.muzzle_position())<.012,
        "sniper visual recoil changed the actual ballistic muzzle")
    combat._process(.6)
    check(combat.ammo[1]==awm_ammo-1,
        "AWM unexpectedly fired automatically while fire button was held")
    combat._on_fire_released()
    visuals._process(.25)
    check(not effect.visible and visuals._visual_kick==0.0,
        "AWM bright muzzle flash remained active beyond its lifetime")

    # Medical action stows the selected AWM: no gun sparks while Lila is
    # applying the actual left-hand 3D medkit.
    operator.receive_training_hit(40.0,true)
    combat._on_heal()
    check(visuals.medical_busy and combat._heal_remaining>0.0 and
        not effect.visible and not visuals.awm.visible and
        visuals.back_awm.visible,
        "medical state failed to stow rifle and hide live muzzle effects")
    var events_before_heal: int=visuals.visual_shots
    visuals.register_shot(1)
    check(events_before_heal==visuals.visual_shots and not effect.visible,
        "medical action generated fictional muzzle flashes")
    combat._on_heal()
    check(not visuals.medical_busy and combat._heal_remaining==0.0 and
        visuals.awm.visible and not visuals.back_awm.visible,
        "cancel medical operation failed to restore original sniper")

    # Switching away after an AWM shot must remove the scoped flash and
    # restore the AR equipment, no cross-weapon effects or phantom ammo.
    combat.cooldown=0.0
    combat._on_fire_pressed()
    check(effect.visible,"secondary AWM shot failed to create new gun flash")
    combat._on_fire_released()
    combat._on_weapon()
    check(combat.weapon_index==0 and visuals.ak.visible and
        not visuals.awm.visible and not effect.visible and
        visuals._visual_kick==0.0,
        "weapon swap leaked the last rifle's recoil into the AR view")

    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    operator.set_physics_process(false)
    check(not combat.weapon_owned[1] and
        combat.weapon_index==0 and not visuals.awm_owned and
        not effect.visible and visuals._flash_remaining==0.0 and
        visuals._visual_kick==0.0 and not visuals.medical_busy,
        "new BR leaked muzzle flash, AWM ownership or recoil from training")

    if not failed:
        print("V7566_AWM_BOLT_RECOIL PASS skeletal_bolt=.50 "+
            "right_hand_bone=1 pooled_flash_meshes=3 "+
            "ar_real_round=1 awm_real_round=1 "+
            "visual_recoil_nonballistic=1 no_empty_flash=1 "+
            "awm_no_autofire=1 aim_x8=1 medkit_safe=1 "+
            "weapon_switch_clean=1 battle_reset=1 vulkan=1")
    quit(1 if failed else 0)
