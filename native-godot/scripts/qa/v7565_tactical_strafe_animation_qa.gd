extends SceneTree
## V75.65: authored skinned Lila directional gaits in the REAL Main.tscn.
## Aiming while moving sideways/backward must no longer slide a forward
## animation along the ground. Preserve physics, flight, ADS, armor and UI.
const OPERATOR=preload("res://scripts/player/third_person_operator.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7565_LILA_TACTICAL_GAIT "+reason)


func frames(n: int) -> void:
    for i in range(n):
        await physics_frame


func _verify() -> void:
    check(str(ProjectSettings.get_setting(
        "rendering/renderer/rendering_method.mobile"))=="mobile",
        "mobile must remain a single Vulkan Android build")
    check(OPERATOR.tactical_gait_clip(Vector3(-4.5,0,0),4.5,true)==
        "AuroraArmedStrafeLeft" and
        OPERATOR.tactical_gait_clip(Vector3(4.5,0,0),4.5,true)==
        "AuroraArmedStrafeRight" and
        OPERATOR.tactical_gait_clip(Vector3(0,0,3.9),3.9,true)==
        "AuroraArmedBackpedal" and
        OPERATOR.tactical_gait_clip(Vector3(0,0,-4.5),4.5,true).is_empty() and
        OPERATOR.tactical_gait_clip(Vector3(4.5,0,0),4.5,false).is_empty() and
        OPERATOR.tactical_gait_clip(Vector3(4.5,0,0),0.0,true).is_empty() and
        OPERATOR.tactical_gait_clip(Vector3(INF,0,0),1.0,true).is_empty(),
        "physical local-facing directional selection is inconsistent")

    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get_node("Operator")
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    for bot in combat._targets:
        bot.set_physics_process(false)
    director.set_process(false)
    combat.set_process(false)
    await frames(3)
    check(player._animator!=null and player._animation_controller!=null,
        "third person Lila's actual humanoid animation tree missing")
    if player._animator==null or player._animation_controller==null:
        quit(1)
        return
    var controller: Node=player._animation_controller
    check(controller.tree.active,
        "character animation blend tree is no longer rendering")
    for clip in ["AuroraArmedStrafeLeft",
            "AuroraArmedStrafeRight","AuroraArmedBackpedal"]:
        check(player._animator.has_animation(clip) and
            controller.states.has_node(clip),
            "original Blender GLB doesn't export actual skeleton clip "+clip)
        if player._animator.has_animation(clip):
            var animation: Animation=player._animator.get_animation(clip)
            check(animation.length>.85 and animation.length<1.25 and
                animation.get_track_count()>6 and
                animation.loop_mode==Animation.LOOP_LINEAR,
                "new sidestep uses empty/fake animation with no leg movement")

    var skeleton: Skeleton3D=player._avatar.find_child(
        "Skeleton3D",true,false) as Skeleton3D
    check(skeleton!=null and skeleton.get_bone_count()>35,
        "Lila's original weighted skeleton was replaced by an animation dummy")
    var knee: int=skeleton.find_bone("rig_LeftUpLeg")
    if knee<0:
        knee=skeleton.find_bone("rig:LeftUpLeg")
    check(knee>=0,"procedural step lost its original thigh bone")
    if knee<0:
        quit(1)
        return

    # Keep real island and player, then create a remote solid physics stage
    # so heading tests are independent of randomly placed coastal houses.
    var floor:=StaticBody3D.new()
    floor.name="V7565RealPhysicalFooting"
    floor.collision_layer=1
    var shape:=CollisionShape3D.new()
    shape.shape=BoxShape3D.new()
    (shape.shape as BoxShape3D).size=Vector3(75,1,75)
    floor.add_child(shape)
    floor.position=Vector3(800,15,800)
    game.add_child(floor)

    player.set_touch_move_axis(Vector2.ZERO)
    player.global_position=Vector3(800,15.56,800)
    player.velocity=Vector3.ZERO
    player._yaw=0.0
    player._desired_yaw=0.0
    player.rotation.y=0.0
    await frames(17)
    check(player.is_on_floor() and player.get_view_camera()!=null,
        "TPS Lila is not physically grounded with a real shoulder camera")
    player.set_ads(true,2.0)
    player.set_touch_move_axis(Vector2.LEFT)
    await frames(31)
    check(player.measured_ground_speed>2.0 and
        player._current_clip=="AuroraArmedStrafeLeft" and
        controller.playback.get_current_node()=="AuroraArmedStrafeLeft",
        "ADS sidestep left uses sliding forward walk instead of original clip")
    var first: Quaternion=skeleton.get_bone_pose_rotation(knee)
    await frames(8)
    var second: Quaternion=skeleton.get_bone_pose_rotation(knee)
    check(first.angle_to(second)>.01,
        "side-step thigh stays frozen despite physically moving left")

    player.set_touch_move_axis(Vector2.RIGHT)
    await frames(33)
    check(player.measured_ground_speed>2.0 and
        player._current_clip=="AuroraArmedStrafeRight" and
        controller.playback.get_current_node()=="AuroraArmedStrafeRight",
        "ADS sidestep right didn't transition while moving through real physics")
    player.play_weapon_action("reload",1.55)
    await frames(5)
    check(controller.action_clip.animation=="AuroraReloadAR" and
        controller.tree.get("parameters/UpperBody/active") and
        player._current_clip=="AuroraArmedStrafeRight",
        "layered gun reload stopped legs or exited tactical strafe state")
    player.cancel_medical_action()
    # Reload is cancelled through normal weapon change/round reset.
    player.set_touch_move_axis(Vector2.DOWN)
    await frames(33)
    check(player.measured_ground_speed>2.0 and
        player._current_clip=="AuroraArmedBackpedal",
        "rearward tactical movement plays wrong forward stride")

    player.set_touch_move_axis(Vector2.UP)
    await frames(29)
    check(player.measured_ground_speed>2.0 and
        player._current_clip=="AuroraArmedWalk",
        "advancing while aiming should keep the existing armed forward walk")

    # Side steps without aiming return to the classic body-facing locomotion
    # and never move camera yaw with the character's shoulder.
    player.set_ads(false,1.0)
    player.set_touch_move_axis(Vector2.LEFT)
    await frames(30)
    check(player.measured_ground_speed>1.0 and
        player._current_clip=="AuroraArmedWalk" and
        absf(player._camera_pivot.global_rotation.y-player._yaw)<.15,
        "unscoped strafe incorrectly became aim lock or destabilized camera")
    player.set_touch_move_axis(Vector2.ZERO)
    await frames(28)
    check(player.measured_ground_speed<.6 and
        player._current_clip=="AuroraArmedIdle",
        "movement stopped but directional gait kept running on the spot")

    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    check(not player._ads_active and
        not player._fire_held and not player._sprint_touch and
        player.measured_ground_speed==0.0 and
        controller.tree.active,
        "Battle Royale reset leaked tactical aim or disabled animation tree")
    if not failed:
        print("V7565_LILA_TACTICAL_GAIT PASS "+
            "three_skeletal_clips=1 left_right_strafe=1 "+
            "backpedal=1 thigh_animation=1 "+
            "reload_over_strafe=1 forward_transition=1 "+
            "free_look=1 physical_ground=1 reset=clean vulkan=1")
    quit(1 if failed else 0)
