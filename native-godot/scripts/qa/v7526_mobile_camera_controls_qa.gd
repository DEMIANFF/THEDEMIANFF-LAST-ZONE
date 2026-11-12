extends SceneTree
## V75.26 native Godot QA. The real scene and real touch / HUD signals are
## exercised. This is NOT a substitute for an on-device 120Hz Motorola test.
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(condition: bool,detail: String) -> void:
    if not condition:
        failed=true
        push_error("V7526_MOBILE_CAMERA "+detail)

func frame_count(n: int) -> void:
    for i in range(n):
        await physics_frame

func touch(index: int,position: Vector2,down: bool) -> InputEventScreenTouch:
    var event:=InputEventScreenTouch.new()
    event.index=index
    event.position=position
    event.pressed=down
    return event

func drag(index: int,at: Vector2,relative: Vector2) -> InputEventScreenDrag:
    var event:=InputEventScreenDrag.new()
    event.index=index
    event.position=at
    event.relative=relative
    return event

func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get_node("Operator")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var combat: Node3D=game.get_node("CombatRange")
    var stick: Control=game.get_node("TrainingHUD/AuroraTacticalOverlay/MovePad")
    var firepad: Control=game.get_node("TrainingHUD/AuroraTacticalOverlay/DirectionalFirePad")
    var camera: Camera3D=player.get_view_camera()
    for bot in combat._targets:
        bot.set_physics_process(false)
    await frame_count(110)
    check(player.is_on_floor(),"character not grounded for real movement QA")
    check(camera!=null and stick!=null and firepad!=null,
        "missing actual camera / analog joystick / drag-fire button")

    # One erroneous 1000px event must not spin the third-person camera.
    var yaw_start: float=player._desired_yaw
    player._turn_camera(Vector2(1000.0,0))
    var first_step: float=absf(angle_difference(yaw_start,player._desired_yaw))
    check(first_step<=player.CAMERA_MAX_SWIPE_PIXELS*
        player.LOOK_SENSITIVITY*player.look_multiplier+.002,
        "camera failed to clamp an anomalous touch delta")
    var after_step: float=player._desired_yaw
    for i in range(12):
        player._turn_camera(Vector2(-90,0))
    check(absf(angle_difference(after_step,player._desired_yaw))>.75,
        "legitimate repeated 360-degree swipe is blocked")
    await frame_count(28)
    check(player._camera.position.z>=1.0 and player._camera.position.z<=4.65,
        "camera collision / shoulder clearance out of bounds")

    # Crouching changes the real collider instantly, but eases the camera
    # to avoid nausea. Animation uses actual rig; never squash body mesh.
    var old_height: float=player._camera_pivot.position.y
    player.set_crouch(true)
    check(player._crouching and is_equal_approx(player._camera_height_target,1.13),
        "crouch stance did not request eye height")
    check(player._camera_pivot.position.y>=old_height-.02,
        "crouching caused an immediate eye-level camera teleport")
    await frame_count(24)
    check(absf(player._camera_pivot.position.y-1.13)<.03,
        "camera eye did not ease into crouched height")
    player.set_crouch(false)
    await frame_count(24)
    check(absf(player._camera_pivot.position.y-1.55)<.03,
        "camera eye did not ease back to standing height")

    # New floating joystick: first touch inside the thumb zone should not
    # unexpectedly walk; subsequent drag controls actual analog velocity.
    var start: Vector2=stick.size*.5+Vector2(25,10)
    stick._gui_input(touch(1,start,true))
    check(player._move_axis.length()<.015,
        "floating stick instantly moved player on initial touch")
    var move_at: Vector2=start+Vector2(0,-65)
    stick._gui_input(drag(1,move_at,Vector2(0,-65)))
    var axis_before: Vector2=player._move_axis
    check(axis_before.y<-.6,"floating joystick did not drive real movement")
    stick._gui_input(touch(8,start,true))
    stick._gui_input(drag(8,start+Vector2(50,0),Vector2(50,0)))
    check(player._move_axis.is_equal_approx(axis_before),
        "secondary pointer stole the movement joystick")
    await frame_count(28)
    # Android release may arrive outside the joystick, not through gui_input.
    stick._input(touch(1,Vector2(-500,-500),false))
    check(player._move_axis.length()<.015 and stick._finger==-1,
        "outside joystick release left unwanted movement active")

    # Sprint toggle must cancel when real weapon starts firing; both HUD
    # display and character velocity mode must agree.
    hud._run_down()
    check(player._sprint_touch and hud._run_latched,
        "tap-to-run no longer engages")
    hud._fire_down()
    check(combat.trigger_held and player._fire_held,
        "physical fire button did not start the real gun")
    check(not player._sprint_touch and not hud._run_latched and
        hud._run_button.text=="CORRER",
        "gunfire failed to cancel and re-label sprint")
    hud._fire_up()

    # Fire pointer capture must also release globally outside the button.
    firepad._gui_input(touch(4,firepad.size*.5,true))
    check(combat.trigger_held,"fire finger not captured")
    var pre_aim: float=player._desired_yaw
    firepad._gui_input(drag(4,firepad.size*.5+Vector2(55,-18),Vector2(55,-18)))
    check(absf(angle_difference(pre_aim,player._desired_yaw))>.05,
        "drag-to-aim failed to rotate real sight")
    firepad._input(touch(4,Vector2(4000,4000),false))
    check(not combat.trigger_held and not player._fire_held,
        "outside fire-pad release left continuous firing active")

    # A second mid-air jump is a short buffer, not a deferred auto-jump
    # long after touchdown.
    var jumps: Array[int]=[0]
    player.jumped.connect(func(): jumps[0]+=1)
    check(player.is_on_floor(),"player left floor before jump test")
    player.touch_jump()
    await frame_count(7)
    check(not player.is_on_floor(),"touch jump did not leave ground")
    player.touch_jump()
    await frame_count(95)
    check(jumps[0]==1 and player.is_on_floor() and
        not player._jump_requested and player._jump_buffer_seconds<=0.0,
        "stale airborne jump re-triggered after touchdown")

    # Retain camera freedom in the aircraft without enabling the combat UI.
    var before_air: float=player._desired_yaw
    player.begin_aircraft()
    player._turn_camera(Vector2(75,-12))
    await frame_count(8)
    check(absf(angle_difference(before_air,player._desired_yaw))>.04 and
        absf(angle_difference(player._yaw,player._desired_yaw))<.20,
        "aircraft/freefall camera lost independent 360-degree look")
    check(player.air_mode=="aircraft","flight-phase camera QA changed game mode")
    if not failed:
        print("V7526_MOBILE_CAMERA PASS actual free-look, jitter clamp, smooth stance,",
            " floating analog / multi-touch release, sprint cancel, fire drag,",
            " bounded jump and independent aircraft camera")
    quit(1 if failed else 0)
