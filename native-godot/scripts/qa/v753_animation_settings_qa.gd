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

func wait_for_action_evaluation(tree: AnimationTree) -> void:
    for tick in range(4):
        await process_frame
        if tree.get("parameters/UpperBody/request")==AnimationNodeOneShot.ONE_SHOT_REQUEST_NONE:
            break

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
    var leg: int=skeleton.find_bone("LeftUpLeg")
    var first: Quaternion=skeleton.get_bone_pose_rotation(leg)
    await frames(10)
    var second: Quaternion=skeleton.get_bone_pose_rotation(leg)
    check(first.angle_to(second)>.015,"legs frozen during reload")
    print("V753_LAYERED_RELOAD clip=",player._current_clip," leg_angle=",first.angle_to(second))
    combat._on_weapon()
    await wait_for_action_evaluation(controller.tree)
    check(combat.reload_timer==0 and controller.action_clip.animation=="AuroraEquip" and
        player._combat_action!="AuroraReloadAR",
        "weapon change retained old reload instead of a real equip gesture")
    var equip: Animation=player._animator.get_animation("AuroraEquip")
    check(equip!=null and equip.get_track_count()>0 and
        equip.loop_mode==Animation.LOOP_NONE and is_equal_approx(equip.length,.20),
        "derived equip gesture missing real skeletal tracks")
    if equip!=null:
        var moving_tracks: int=0
        for i in range(equip.get_track_count()):
            var bone: String=str(equip.track_get_path(i)).to_lower()
            check(not "leg" in bone and not "foot" in bone and not "hips" in bone,
                "equip animation interferes with legs")
            if equip.track_get_key_count(i)>=3:
                var initial: Quaternion=equip.track_get_key_value(i,0)
                var lowered: Quaternion=equip.track_get_key_value(i,1)
                if initial.angle_to(lowered)>.001:
                    moving_tracks+=1
        check(moving_tracks>0,"equip gesture does not change any bone rotation")
    await frames(24)
    check(not controller.tree.get("parameters/UpperBody/active"),
        "equip transition did not finish")
    player.set_touch_move_axis(Vector2.ZERO)
    player.set_crouch(true)
    player.play_weapon_action("fire",.24)
    await wait_for_action_evaluation(controller.tree)
    var crouch_fire: bool=controller.tree.get("parameters/UpperBody/active")
    await frames(6)
    check(player._current_clip.begins_with("AuroraCrouch") and crouch_fire,"crouch fire lost stance or action")
    player.reset_controls()
    await wait_for_action_evaluation(controller.tree)
    check(not controller.tree.get("parameters/UpperBody/active"),"action survived reset")
    print("V753_ANIMATION_SETTINGS PASS")
    quit(1 if failed else 0)
