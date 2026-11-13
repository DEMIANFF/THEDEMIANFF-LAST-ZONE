extends SceneTree
## V75.63 — real Main.tscn physics character + hand-bound 3D medkit.
## Healing animation/visuals follow the existing inventory and interruption
## rules; no fake HP, dummy enemies, screenshot renders or server clients.
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
        "Vulkan Mobile is no longer the only Android rendering method")
    var scene: PackedScene=load("res://scenes/Main.tscn") as PackedScene
    check(scene!=null,"real Main.tscn battle royale missing")
    if scene==null:
        quit(1)
        return
    var game: Node3D=scene.instantiate()
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

    var medkit: Node3D=combat._medical_visual
    var weapons: Node3D=combat._weapon_visuals
    check(medkit!=null and medkit.get_piece_count()==6,
        "Lila's real first aid case must have six PBR geometric pieces")
    check(medkit.attachment_uses_hand and
        medkit.hand_socket is BoneAttachment3D and
        medkit.hand_socket.bone_name.to_lower().ends_with("lefthand") and
        medkit.hand_socket.get_parent() is Skeleton3D,
        "original first aid prop is not attached to animated left hand bone")
    check(not medkit.healing and not medkit.medical_case.visible and
        not weapons.medical_busy and weapons.ak.visible,
        "medical kit must be hidden while physically inactive")
    check(player._animator!=null and
        player._animator.has_animation("AuroraHeal"),
        "exported original Blender 3D rig lacks authored medical clip")
    if player._animator!=null and player._animator.has_animation("AuroraHeal"):
        check(player._animator.get_animation("AuroraHeal").length>=2.5,
            "aurora medical body movement is not a timed 3D clip")

    player.receive_training_hit(48.0,true)
    var before: float=player.training_health
    check(before<99.0,"real damage did not decrease player HP")
    combat._on_heal()
    check(combat._heal_remaining==combat.HEAL_APPLY_SECONDS and
        medkit.healing and medkit.medical_case.visible and
        weapons.medical_busy and not weapons.ak.visible and
        player._combat_action=="AuroraHeal" and
        hud._heal_progress_bar.visible and combat.medkits_remaining==2,
        "real player first aid did not mount 3D case/animate/stow gun")
    var old_pos: Vector3=medkit.medical_case.global_position
    check(old_pos.is_finite() and
        old_pos.distance_to(player.global_position)<3.0,
        "medical case is not physically at Lila's hands")
    for element in medkit.medical_case.get_children():
        var mesh: MeshInstance3D=element as MeshInstance3D
        check(mesh!=null and mesh.mesh is BoxMesh and
            mesh.material_override is StandardMaterial3D and
            not mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
            "real medical geometry is missing or expensive shadow casting enabled")

    combat._process(1.0)
    check(player.training_health==before and
        combat.medkits_remaining==2 and medkit.medical_case.visible and
        hud._heal_progress_bar.value>0.0 and
        hud._heal_progress_bar.value<100.0,
        "displayed medical animation granted health before channel completion")

    combat._on_heal()
    check(combat._heal_remaining==0.0 and
        not medkit.healing and not medkit.medical_case.visible and
        not weapons.medical_busy and weapons.ak.visible and
        player._combat_action!="AuroraHeal" and
        combat.medkits_remaining==2 and player.training_health==before,
        "cancel medkit failed to restore rifle/animation without spending item")

    combat._on_heal()
    player.set_touch_move_axis(Vector2.RIGHT)
    combat._process(.1)
    player.set_touch_move_axis(Vector2.ZERO)
    check(combat._heal_remaining==0.0 and
        not medkit.medical_case.visible and weapons.ak.visible,
        "movement failed to interrupt real medicine action/prop")

    combat._on_heal()
    player.receive_training_hit(3.0,true)
    check(combat._heal_remaining==0.0 and
        not medkit.medical_case.visible and
        not weapons.medical_busy and combat.medkits_remaining==2,
        "enemy's actual incoming damage failed to stop healing visual")

    var injured: float=player.training_health
    combat._on_heal()
    combat._process(combat.HEAL_APPLY_SECONDS+.1)
    check(combat._heal_remaining==0.0 and
        combat.medkits_remaining==1 and
        absf(player.training_health-minf(100.0,injured+45.0))<.01 and
        not medkit.medical_case.visible and weapons.ak.visible and
        not weapons.medical_busy and hud._medkit_button.text=="CURAR 1",
        "completed real healing mismatched HP, item consumption or geometry")

    # The player can collect a physical AWM during BR and swap it to hand.
    # The medical state then temporarily stows the selected AWM, not just AR.
    var pickup: Area3D=director.get_node("AuroraAWMWeaponPickup")
    player.global_position=pickup.global_position-Vector3.UP
    player.velocity=Vector3.ZERO
    await physics_frame
    await physics_frame
    if is_instance_valid(pickup) and not pickup.collected:
        pickup._collect(player)
    combat._equip_inventory_weapon(1)
    check(combat.weapon_index==1 and weapons.awm.visible and
        weapons.awm_owned and not weapons.medical_busy,
        "AWM physical pickup/switch broke in first aid integration")
    player.receive_training_hit(4.0,true)
    combat._on_heal()
    check(medkit.medical_case.visible and weapons.medical_busy and
        not weapons.awm.visible and weapons.back_awm.visible,
        "healing did not holster equipped sniper without losing ownership")
    combat._on_aim()
    check(combat._heal_remaining==0.0 and
        not medkit.medical_case.visible and
        weapons.awm.visible and not weapons.back_awm.visible,
        "ADS cancel didn't restore actual AWM mount after medicine")

    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    check(combat.medkits_remaining==2 and combat._heal_remaining==0.0 and
        not medkit.medical_case.visible and not medkit.healing and
        weapons.ak.visible and not weapons.medical_busy and
        player._combat_action!="AuroraHeal" and
        not combat.weapon_owned[1],
        "new game reused last match's medkit prop or equipped sniper")
    if not failed:
        print("V7563_LILA_MEDKIT PASS authored_bone_clip=1 "+
            "PBR_medkit_six_meshes=1 left_hand_socket=1 "+
            "physical_3s_healing=1 movement_interrupt=1 "+
            "damage_interrupt=1 inventory_consumption=1 "+
            "AR_AWM_mount_restore=1 match_reset=1 vulkan=1")
    quit(1 if failed else 0)
