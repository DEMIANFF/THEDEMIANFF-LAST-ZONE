extends SceneTree
const PERF=preload("res://scripts/persistence/aurora_performance_report.gd")
var failed: bool=false
var bones: Dictionary={}

func _initialize() -> void:
    call_deferred("_verify")

func check(value: bool,message: String) -> void:
    if not value:
        failed=true
        push_error("V75189_BODY "+message)

func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get_node("Operator")
    var combat: Node3D=game.get_node("CombatRange")
    combat.set_process(false)
    game.get_node("AuroraSectorMatch").set_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
        var budget: Node=bot._rig.get_node_or_null("EnemyAnimationBudget")
        check(budget!=null,"ordinary enemy bypasses animation evaluation budget")
        check(bot._animation.callback_mode_process==
            AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL,
            "ordinary enemy animator still advances outside its budget")
    var platform:=StaticBody3D.new()
    var collider:=CollisionShape3D.new()
    collider.shape=BoxShape3D.new()
    collider.shape.size=Vector3(20,1,20)
    platform.add_child(collider)
    platform.position=Vector3(800,15,800)
    game.add_child(platform)
    player.global_position=Vector3(800,15.56,800)
    player.velocity=Vector3.ZERO
    var skeleton:=player._avatar.find_child("Skeleton3D",true,false) as Skeleton3D
    skeleton.skeleton_updated.connect(func():
        for name in ["LeftFoot","RightFoot","LeftToeBase","RightToeBase",
                "LeftArm","LeftForeArm","LeftHand","RightArm","RightForeArm","RightHand"]:
            bones[name]=skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone(name)).origin))
    for frame in range(24):
        await physics_frame
    check(player.is_on_floor(),"real body did not settle on collision platform")
    check(player._body_contact!=null,"post-animation body correction absent")
    check(player._body_contact.probe_count==2,"local feet must use only two cached physics probes")
    var left: Vector3=bones["LeftFoot"]
    var right: Vector3=bones["RightFoot"]
    var separation: float=absf((left-right).dot(player.global_basis.x))
    check(separation>.27 and separation<.42,"crossed or excessively wide idle feet: "+str(separation))
    var left_toe: Vector3=bones["LeftToeBase"]
    var right_toe: Vector3=bones["RightToeBase"]
    check(absf(left_toe.y-right_toe.y)<.035,"standing soles do not share ground contact")
    print("V75189_STANCE feet_m=",separation," toe_height_delta_m=",absf(left_toe.y-right_toe.y))
    # A physical slope must change foot contact, not the capsule scale or
    # just an arbitrary root offset. Check both uphill directions.
    for angle in [.18,-.18]:
        platform.rotation.z=angle
        for frame in range(45):
            await physics_frame
        left=bones["LeftFoot"]
        right=bones["RightFoot"]
        check(player.is_on_floor(),"slope correction lost physical floor contact")
        check(absf((left.y-right.y)-(left.x-right.x)*tan(angle))<.025,
            "ankle heights do not follow physical slope")
        check(player._body_contact.foot_errors.max()<.025,
            "slope foot target outside acceptable contact tolerance")
    platform.rotation.z=0.0
    for frame in range(45):
        await physics_frame
    # Test actual support geometry with the existing five installed weapons.
    combat.open_training_armory()
    for kind in ["weapon_scar","weapon_mp40","weapon_kriss"]:
        combat.collect_sector_loot(kind)
    var visuals: Node3D=combat._weapon_visuals
    for slot in range(5):
        combat._equip_inventory_weapon(slot)
        player.set_equipped_weapon(slot)
        player._animation_controller.reset_ground_pose()
        for frame in range(20):
            await physics_frame
        check(visuals._support_ik.solved,"installed weapon grip not solved: "+str(slot))
        check(visuals._support_ik.last_error_m<.045,"support grip error: "+str(slot))
        check(visuals._support_ik.right_error_m<.045,"trigger grip error: "+str(slot))
        check(visuals._support_ik.projection_iterations<=24,"unbounded arm projection")
        check(visuals._support_ik.diagnostics.is_empty(),"per-frame diagnostic string allocation")
    player.set_ads(true,2.0)
    player._pitch=.5
    player._desired_pitch=.5
    for frame in range(20):
        await physics_frame
    check(player._body_contact.aim_pitch>.30,"torso did not follow upward ADS")
    check(visuals._support_ik.last_error_m<.045,"aiming detached support hand")
    player.set_ads(false,1.0)
    player.set_physics_process(false)
    player.global_position.y+=50.0
    player.air_mode="freefall"
    for frame in range(3):
        await physics_frame
    check(player._body_contact.probe_count==0,"airborne feet still query ground")
    check(not visuals.support_grip_enabled(),"airborne hands remain pinned to gun")
    var samples: Array[float]=[20.0,30.0,60.0]
    var metrics: Dictionary={"gpu_render_ms_peak":31.0,"draw_calls_peak":350.0}
    check(PERF.record(50,samples,70.0,true,metrics)==OK,"50-player performance report rejected")
    var report: Dictionary=PERF.latest()
    check(report.participants==50 and report.metrics==metrics,"measured report lost participant count or metrics")
    check(PERF.record(51,samples,70.0,true)==ERR_INVALID_PARAMETER,"invalid roster accepted")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75189_LILA_BODY_PERFORMANCE PASS stable_stance=1 five_grips=1 torso_aim=1 cached_contacts=1 report_50=1")
    quit(1 if failed else 0)
