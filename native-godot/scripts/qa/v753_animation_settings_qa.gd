extends SceneTree
var failed: bool=false
const PREFERENCES=preload("res://scripts/persistence/camera_preferences.gd")

func _initialize() -> void:
    call_deferred("verify")

func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V753_ANIMATION_SETTINGS "+message)

func frames(n: int) -> void:
    for i in range(n):
        await physics_frame

func verify() -> void:
    var preferences=PREFERENCES.new("user://v753_camera_test.cfg")
    check(preferences.save(1.55,.75)==OK,"save preferences")
    check(preferences.save(1.85,1.2)==OK,"backup preferences")
    var corrupt:=FileAccess.open(preferences.path,FileAccess.WRITE)
    corrupt.store_string("damaged")
    corrupt.close()
    var recovered=PREFERENCES.new(preferences.path)
    check(recovered.recovered and is_equal_approx(recovered.look,1.55) and is_equal_approx(recovered.ads,.75),"settings recovery")
    check(recovered.save(NAN,1.0)==ERR_INVALID_PARAMETER,"accepted NaN sensitivity")
    print("V753_SETTINGS recovered=",recovered.recovered," look=",recovered.look," ads=",recovered.ads)
    var game=load("res://scenes/Main.tscn").instantiate()
    root.add_child(game)
    var player=game.get_node("Operator")
    var combat=game.get_node("CombatRange")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await frames(50)
    player.look_multiplier=1.0
    player._desired_yaw=0
    player._turn_camera(Vector2(80,0))
    var standard: float=player._desired_yaw
    player.look_multiplier=2.0
    player._desired_yaw=0
    player._turn_camera(Vector2(80,0))
    check(is_equal_approx(player._desired_yaw,standard*2.0),"look slider not applied")
    player.look_multiplier=1.0
    player._desired_yaw=0
    player._yaw=0
    player.set_touch_move_axis(Vector2.UP)
    await frames(30)
    combat.ammo[0]=1
    combat._on_reload()
    await frames(8)
    var controller=player._animation_controller
    check(controller.tree.get("parameters/UpperBody/active"),"reload did not animate upper body")
    check(controller.action_clip.animation=="AuroraReloadAR","AR still uses idle reload")
    check(player._current_clip=="AuroraArmedWalk","reload stopped walking legs")
    check(player._combat_action_seconds>1.0,"reload animation ended too early")
    for track in controller.upper_tracks:
        var bone:=str(track).to_lower()
        check(not "hips" in bone and not "leg" in bone and not "foot" in bone,"upper layer includes legs")
    var skeleton: Skeleton3D=player._avatar.find_child("Skeleton3D",true,false)
    var leg: int=skeleton.find_bone("rig_LeftUpLeg")
    var first: Quaternion=skeleton.get_bone_pose_rotation(leg)
    await frames(10)
    var second: Quaternion=skeleton.get_bone_pose_rotation(leg)
    check(first.angle_to(second)>.015,"legs frozen during reload")
    print("V753_LAYERED_RELOAD clip=",player._current_clip," leg_angle=",first.angle_to(second))
    combat._on_weapon()
    await frames(2)
    check(combat.reload_timer==0 and not controller.tree.get("parameters/UpperBody/active"),"weapon change kept old reload action")
    player.set_touch_move_axis(Vector2.ZERO)
    player.set_crouch(true)
    player.play_weapon_action("fire",.24)
    await frames(6)
    check(player._current_clip.begins_with("AuroraCrouch") and controller.tree.get("parameters/UpperBody/active"),"crouch fire lost stance or action")
    player.reset_controls()
    await frames(2)
    check(not controller.tree.get("parameters/UpperBody/active"),"action survived reset")
    print("V753_ANIMATION_SETTINGS PASS")
    quit(1 if failed else 0)
