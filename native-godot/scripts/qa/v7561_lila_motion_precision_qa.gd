extends SceneTree
## V75.61: actual CharacterBody3D movement and collision-measured gait,
## buffered/coyote jump, safe ADS sprint and mobile physics. No fake FPS.
const OPERATOR=preload("res://scripts/player/third_person_operator.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V7561_LILA_MOTION "+message)

func frames(n: int) -> void:
    for i in range(n):
        await physics_frame

func _verify() -> void:
    check(str(ProjectSettings.get_setting(
        "rendering/renderer/rendering_method.mobile"))=="mobile",
        "Android Vulkan mobile renderer lost")
    check(OPERATOR.COYOTE_JUMP_SECONDS>=.09 and
        OPERATOR.COYOTE_JUMP_SECONDS<=.14 and
        OPERATOR.JUMP_BUFFER_SECONDS>=.12 and
        OPERATOR.JUMP_BUFFER_SECONDS<=.19,
        "unbounded double jump or mobile input grace timing")
    check(OPERATOR.measured_motion_speed(Vector3.ZERO,1.0/60.0)==0.0 and
        OPERATOR.measured_motion_speed(Vector3(0,10,0),1.0/60.0)==0.0 and
        absf(OPERATOR.measured_motion_speed(Vector3(.0,0,-.1),.02)-5.0)<.01 and
        OPERATOR.measured_motion_speed(Vector3(1000,0,0),.016)<=
            OPERATOR.MAX_REPORTED_MOTION_SPEED+.001 and
        OPERATOR.measured_motion_speed(Vector3(INF,0,0),.016)==0.0 and
        OPERATOR.measured_motion_speed(Vector3(1,0,0),0.0)==0.0,
        "animation speed wrongly depends on target velocity or invalid motion")

    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get_node("Operator")
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    for bot in combat._targets:
        bot.set_physics_process(false)
    director.set_process(false)
    combat.set_process(false)
    await frames(3)

    # Isolate a real ground and collision wall away from Puerto Aurora.
    # The existing island/AI/3D Lila are still instantiated and retained.
    var ground:=StaticBody3D.new()
    ground.name="V7561PhysicalGround"
    ground.collision_layer=1
    ground.collision_mask=0
    var slab:=CollisionShape3D.new()
    slab.shape=BoxShape3D.new()
    (slab.shape as BoxShape3D).size=Vector3(70,1,70)
    ground.add_child(slab)
    ground.position=Vector3(800,15,800)
    game.add_child(ground)
    var wall:=StaticBody3D.new()
    wall.name="V7561DoorwayBlocker"
    wall.collision_layer=1
    var barrier:=CollisionShape3D.new()
    barrier.shape=BoxShape3D.new()
    (barrier.shape as BoxShape3D).size=Vector3(18,4,1)
    wall.add_child(barrier)
    wall.position=Vector3(800,16.5,793.5)
    game.add_child(wall)

    player.set_touch_move_axis(Vector2.ZERO)
    player.global_position=Vector3(800,15.56,800)
    player.velocity=Vector3.ZERO
    player._yaw=0.0
    player._desired_yaw=0.0
    await frames(15)
    check(player.is_on_floor(),
        "Lila no longer lands on a real collision platform")
    var hits: Array[int]=[0]
    var steps: Array[int]=[0]
    player.jumped.connect(func(): hits[0]+=1)
    player.footstep.connect(func(_stone: bool): steps[0]+=1)

    # Prove locomotion from actual displacement, not desired speed.
    player.set_touch_move_axis(Vector2.UP)
    player.set_touch_run(true)
    await frames(34)
    check(player.global_position.z<799.0 and
        player.measured_ground_speed>1.0 and
        player._current_clip=="AuroraArmedRun" and steps[0]>=1,
        "sprint did not move physical Lila and animate running limbs")
    await frames(85)
    var saved_position: Vector3=player.global_position
    var saved_steps: int=steps[0]
    await frames(22)
    check(player.global_position.distance_to(saved_position)<.22 and
        player.measured_ground_speed<.60 and
        player._current_clip!="AuroraArmedRun" and
        steps[0]<=saved_steps+1,
        "Lila continues running/playing footsteps into a collision wall")
    check(player._animation_controller!=null and
        player._animation_controller.tree.active,
        "physically resolved walk/idle stopped upper-body animation tree")

    # Releasing input brakes quickly without a camera snap.
    player.set_touch_run(false)
    player.set_touch_move_axis(Vector2.ZERO)
    await frames(22)
    check(Vector2(player.velocity.x,player.velocity.z).length()<.25 and
        player._footstep_distance==0.0,
        "operator keeps drifting or sounding footsteps after joystick release")

    # ADS cancels a latched sprint and preserves the existing shoulder camera.
    var cancelled: Array[int]=[0]
    player.sprint_cancelled.connect(func(): cancelled[0]+=1)
    player.set_touch_run(true)
    player.set_ads(true,2.0)
    check(cancelled[0]==1 and not player._sprint_touch and
        player._ads_active and player._ads_zoom==2.0,
        "aiming while sprinting did not cancel the actual run control")
    player.set_touch_run(true)
    check(not player._sprint_touch,
        "touch sprint relatches silently while ADS remains active")
    player.set_ads(false,1.0)
    # Test stand/crouch well away from the physical blocker. Otherwise
    # refusal to stand below a wall would be correct gameplay behavior.
    player.global_position=Vector3(810,15.56,810)
    player.velocity=Vector3.ZERO
    await frames(12)
    player.set_touch_run(true)
    player.set_crouch(true)
    check(player._crouching and not player._sprint_touch and
        cancelled[0]==2,
        "crouch failed to cancel sprint in controls and the real HUD")
    player.set_crouch(false)
    check(not player._sprint_touch,
        "standing resumed sprint unexpectedly after crouching")
    check(player.get_view_camera()!=null and
        player.get_view_camera().position.z>1.0,
        "ADS broke real safe third-person camera distance")

    # Buffered mobile jump performs one physics impulse, not double jump.
    player.global_position=Vector3(810,15.56,810)
    player.velocity=Vector3.ZERO
    await frames(14)
    check(player.is_on_floor(),"fresh jump test cannot ground Lila")
    player.touch_jump()
    await physics_frame
    check(hits[0]==1 and player.velocity.y>3.0 and
        not player._jump_requested and player._coyote_seconds==0.0,
        "valid touch jump did not consume its request exactly once")
    player.touch_jump()
    await frames(3)
    check(hits[0]==1 and not player.is_on_floor(),
        "Lila jumped twice in the air without a second ground contact")
    await frames(13)
    check(hits[0]==1 and player._jump_buffer_seconds<=0.0 and
        not player._jump_requested,
        "midair jump buffer was not bounded")

    # Coyote jump permits a narrow edge-miss, but not arbitrary flight.
    player.global_position=Vector3(900,40,900)
    player.velocity=Vector3.ZERO
    await frames(3)
    check(not player.is_on_floor(),"coyote test must start in actual free fall")
    player._coyote_seconds=.075
    player.touch_jump()
    await physics_frame
    check(hits[0]==2 and player.velocity.y>3.0 and
        player._coyote_seconds==0.0,
        "physical coyote window did not accept one late-edge jump")

    # Actual lifecycle resets buffers for flight and round restarts.
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    check(not player._jump_requested and
        player._jump_buffer_seconds==0.0 and player._coyote_seconds==0.0 and
        player.measured_ground_speed==0.0 and
        not player._ads_active and not player._sprint_touch,
        "new BR leaked jump, animation speed or camera sprint state")
    if not failed:
        print("V7561_LILA_MOTION PASS physical_sprint=1 "+
            "wall_stop=1 gait_displacement=1 footstep_no_spam=1 "+
            "coyote_jump=1 buffered_touch=1 double_jump=blocked "+
            "ads_sprint_cancel=1 crouch_sprint_cancel=1 camera=1 restart=clean vulkan=1")
    quit(1 if failed else 0)
