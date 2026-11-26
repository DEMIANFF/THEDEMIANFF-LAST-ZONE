extends SceneTree
const PERF=preload("res://scripts/persistence/aurora_performance_report.gd")
var failed: bool=false
var bones: Dictionary={}
const REV9_SHA: String="19c93a00c114246aba2dca99c3a53698990dea2b9c519fc50a61a159331c4d45"

func _own_children(parent: Node, scene_root: Node) -> void:
    for child in parent.get_children():
        child.owner=scene_root
        _own_children(child,scene_root)

func _review_candidate(path: String) -> PackedScene:
    if not path.is_absolute_path() or not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=REV9_SHA:
        return null
    var doc:=GLTFDocument.new()
    var state:=GLTFState.new()
    if doc.append_from_file(path,state)!=OK:
        return null
    var node: Node=doc.generate_scene(state)
    if node==null:
        return null
    _own_children(node,node)
    var scene:=PackedScene.new()
    var status: Error=scene.pack(node)
    node.free()
    return scene if status==OK else null

func _initialize() -> void:
    call_deferred("_verify")

func check(value: bool,message: String) -> void:
    if not value:
        failed=true
        push_error("V75189_BODY "+message)

func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    var args: PackedStringArray=OS.get_cmdline_user_args()
    var candidate: PackedScene
    if not args.is_empty():
        if args.size()!=2 or args[0]!="--candidate":
            push_error("Use -- --candidate /absolute/private/Rev9.glb")
            quit(2)
            return
        candidate=_review_candidate(args[1])
        if candidate==null:
            push_error("Rev9 private candidate missing, changed or invalid")
            quit(2)
            return
        game.review_operator_scene=candidate
    root.add_child(game)
    var player: CharacterBody3D=game.get_node("Operator")
    check(player.approved_operator_scene==candidate,"unexpected operator scene routing")
    if candidate!=null:
        var imported_meshes: Array[Node]=[]
        for child in player._avatar.find_children("*","MeshInstance3D",true,false):
            if (child as MeshInstance3D).skin!=null:
                imported_meshes.append(child)
        check(imported_meshes.size()==1,"private candidate mesh count changed")
        if imported_meshes.size()==1:
            var visual: MeshInstance3D=imported_meshes[0] as MeshInstance3D
            var arrays: Array=visual.mesh.surface_get_arrays(0)
            check(arrays[Mesh.ARRAY_VERTEX].size()==93572 and arrays[Mesh.ARRAY_INDEX].size()==95885*3,
                "actual player visual is not the Rev9 mesh")
        print("V75189_PRIVATE_MAIN candidate_sha256=",REV9_SHA," injected=true")
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
                "Hips","Spine1","Head","LeftUpLeg","LeftLeg","RightUpLeg","RightLeg",
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
        check(player._body_contact.slope_drop>=0.0 and player._body_contact.slope_drop<=.08,
            "slope pelvis compensation exceeded its bounded reach")
        check(player._body_contact.probe_count==2,"slope added extra physics probes")
        print("V75199_SLOPE angle=",angle," drop_m=",player._body_contact.slope_drop,
            " foot_errors_m=",player._body_contact.foot_errors)
        check(player._body_contact.foot_errors.max()<.025,
            "slope foot target outside acceptable contact tolerance")
    platform.rotation.z=0.0
    for frame in range(45):
        await physics_frame
    check(player._body_contact.slope_drop<.001,"slope pelvis compensation retained on flat ground")
    var standing_pelvis: float=(bones["Hips"] as Vector3).y
    player.set_crouch(true)
    for frame in range(35):
        await physics_frame
    var pelvis_drop: float=standing_pelvis-(bones["Hips"] as Vector3).y
    check(pelvis_drop>.20 and pelvis_drop<.40,"crouch must lower pelvis, not fold torso: "+str(pelvis_drop))
    var torso: Vector3=(bones["Head"] as Vector3)-(bones["Spine1"] as Vector3)
    check(torso.angle_to(Vector3.UP)<deg_to_rad(40.0),"crouched torso folds too far forward")
    for side in ["Left","Right"]:
        var knee: Vector3=bones[side+"Leg"]
        var thigh: Vector3=(bones[side+"UpLeg"] as Vector3)-knee
        var shin: Vector3=(bones[side+"Foot"] as Vector3)-knee
        var knee_angle: float=rad_to_deg(thigh.angle_to(shin))
        print("V75190_KNEE side=",side," angle_deg=",knee_angle)
        check(knee_angle>60.0 and knee_angle<150.0,"crouch knee not naturally flexed: "+side+str(knee_angle))
    check(absf((bones["LeftToeBase"] as Vector3).y-(bones["RightToeBase"] as Vector3).y)<.035,
        "crouch feet lost equal ground contact")
    print("V75190_CROUCH pelvis_drop_m=",pelvis_drop," torso_deg=",rad_to_deg(torso.angle_to(Vector3.UP)))
    # The device video shows a lifted knee persisting for seconds while
    # the joystick is neutral. Sample the settled crouch throughout time,
    # not just one lucky frame. No forced pose or edited bone positions.
    for sample in range(8):
        for frame in range(15):
            await physics_frame
        check(player._current_clip=="AuroraCrouch" and player.is_on_floor(),
            "stationary crouch drifted into locomotion")
        check(absf((bones["LeftToeBase"] as Vector3).y-(bones["RightToeBase"] as Vector3).y)<.035,
            "stationary crouch left one foot raised at sample "+str(sample))
        for side in ["Left","Right"]:
            var joint: Vector3=bones[side+"Leg"]
            var upper: Vector3=(bones[side+"UpLeg"] as Vector3)-joint
            var lower: Vector3=(bones[side+"Foot"] as Vector3)-joint
            var angle: float=rad_to_deg(upper.angle_to(lower))
            check(angle>60.0 and angle<150.0,
                "stationary crouch knee angle out of range "+side+" "+str(angle))
    player.set_touch_move_axis(Vector2(0,-1))
    for frame in range(24):
        await physics_frame
    torso=(bones["Head"] as Vector3)-(bones["Spine1"] as Vector3)
    check(player._current_clip=="AuroraCrouchWalk","crouch movement did not use locomotion clip")
    check(standing_pelvis-(bones["Hips"] as Vector3).y>.20,"crouch walking raised pelvis to standing")
    check(torso.angle_to(Vector3.UP)<deg_to_rad(40.0),"crouch walk restored folded torso")
    check(player.is_on_floor(),"crouch walking lost physical floor")
    player.set_touch_move_axis(Vector2.ZERO)
    player.set_crouch(false)
    for frame in range(35):
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
        player.set_crouch(true)
        for frame in range(24):
            await physics_frame
        check(visuals._support_ik.last_error_m<.045 and visuals._support_ik.right_error_m<.045,
            "crouching detached installed weapon grip: "+str(slot))
        player.set_crouch(false)
        for frame in range(24):
            await physics_frame
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
    check(player._body_contact.slope_drop==0.0,"slope pelvis compensation retained in flight")
    check(not visuals.support_grip_enabled(),"airborne hands remain pinned to gun")
    if candidate!=null:
        print("V75189_PRIVATE_MAIN PHYSICS_CHECKS_COMPLETE")
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
