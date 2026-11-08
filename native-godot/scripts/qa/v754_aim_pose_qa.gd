extends SceneTree
## Godot regression: recoil, camera-aligned muzzle and short tracer visuals.
var failed: bool=false

func _initialize() -> void:
    call_deferred("verify")

func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V754_AIM "+message)

func verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player=game.get_node("Operator")
    var combat=game.get_node("CombatRange")
    var weapons=combat._weapon_visuals
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    player.set_physics_process(false)
    combat.set_process(false)
    var angle: float=player._desired_pitch
    player.apply_recoil(.04)
    check(is_equal_approx(player._desired_pitch,angle),"finger aim changed by recoil")
    check(player._recoil_pitch>.035,"recoil kick missing")
    for i in range(40):
        player._recover_recoil(1.0/60.0)
    check(player._recoil_pitch<=.0001 and is_equal_approx(player._desired_pitch,angle),
        "recoil did not recover cleanly")
    player.set_ads(true,4.0)
    player._camera_pivot.rotation.x=.25
    player._camera_pivot.rotation.y=.34
    await physics_frame
    weapons._process(.016)
    var camera: Camera3D=player.get_view_camera()
    var sight: Vector3=-camera.global_basis.z.normalized()
    var barrel: Vector3=-weapons.mount.global_basis.z.normalized()
    check(sight.dot(barrel)>.999,"muzzle axis differs from ADS camera")
    var muzzle: Vector3=weapons.muzzle_position()
    check(muzzle.is_finite() and muzzle.distance_to(weapons.right_hand_socket.global_position)<2.0,
        "muzzle detached from skinned hand")
    var cursor: int=combat._tracer_cursor
    combat._spawn_tracer(muzzle,muzzle+sight*250.0)
    var tracer: MeshInstance3D=combat._tracers[cursor]
    var extent: float=tracer.global_transform.basis.y.length()
    check(extent>23.99 and extent<=24.001,"yellow sky streak "+str(extent))
    check(tracer.global_transform.basis.y.normalized().dot(sight)>.998,
        "tracer visual not in sight direction")
    var existing: int=combat.get_child_count()
    for i in range(200):
        combat._spawn_tracer(muzzle,muzzle+sight*250.0)
    check(existing==combat.get_child_count(),"tracer pool leaked nodes")
    var skeleton: Skeleton3D=player._avatar.find_child("Skeleton3D",true,false)
    var animator: AnimationPlayer=player._avatar.find_child("AnimationPlayer",true,false)
    check(skeleton!=null and animator!=null,"operator rig missing")
    if skeleton!=null and animator!=null:
        check(skeleton.find_bone("rig_LeftLeg")>=0,"knee bone absent")
        check(animator.has_animation("AuroraArmedRun"),"running animation missing")
    print("V754_AIM PASS camera_barrel=",sight.dot(barrel)," tracer_m=",extent)
    quit(1 if failed else 0)
