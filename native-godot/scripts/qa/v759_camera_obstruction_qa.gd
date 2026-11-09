extends SceneTree
## Camera collision QA: real 3D wall blocks rear camera, then frees it.
## Free look and combat remain covered by earlier tests.
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")


func check(valid: bool,context: String) -> void:
    if not valid:
        failed=true
        push_error("V759_CAMERA "+context)


func _wall(world: Node3D,at: Transform3D,extent: Vector3) -> StaticBody3D:
    var body:=StaticBody3D.new()
    body.name="CameraCollisionFixture"
    body.collision_layer=1
    world.add_child(body)
    body.global_transform=at
    var collision:=CollisionShape3D.new()
    var box:=BoxShape3D.new()
    box.size=extent
    collision.shape=box
    body.add_child(collision)
    return body


func _frames(count: int) -> void:
    for i in range(count):
        await physics_frame


func _verify() -> void:
    var world: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(world)
    var operator=world.get_node("Operator")
    var terrain=world.get_node("AuroraTerrain")
    for bot in world.get_node("CombatRange")._targets:
        bot.set_physics_process(false)
    operator.global_position=Vector3(-75.0,terrain.height_at(-75,-75)+.20,-75.0)
    operator.velocity=Vector3.ZERO
    operator._yaw=0
    operator._desired_yaw=0
    operator._pitch=-.14
    operator._desired_pitch=-.14
    await _frames(75)
    var camera: Camera3D=operator.get_view_camera()
    check(camera!=null and camera.position.z>2.0,"initial camera not open")
    check(operator._avatar!=null,"operator visual missing")
    var pivot: Node3D=operator._camera_pivot
    var blocking: Transform3D=pivot.global_transform*Transform3D(Basis(),Vector3(0,0,1.56))
    var back_wall:=_wall(world,blocking,Vector3(4.0,3.2,.45))
    await _frames(22)
    check(camera.position.z<1.35,"wall did not contract camera")
    check(not operator._avatar.visible,"local avatar obscures close camera")
    back_wall.queue_free()
    await _frames(70)
    check(camera.position.z>2.8,"camera did not expand after wall removed")
    check(operator._avatar.visible,"avatar failed to return after leaving wall")
    var shoulder_wall: Transform3D=pivot.global_transform*Transform3D(
        Basis(),Vector3(.47,0,1.0))
    var corner:=_wall(world,shoulder_wall,Vector3(.24,3.0,.55))
    await _frames(45)
    check(camera.position.x<.22,"right shoulder never slid toward open centerline")
    check(camera.position.z>1.45,"camera remained crushed against right-side corner")
    corner.queue_free()
    await _frames(70)
    check(camera.position.x>.29,"camera shoulder failed to return to preferred side")
    check(camera.position.z>2.8,"camera failed to restore long-range follow")
    operator.set_ads(true,8.0)
    await _frames(24)
    check(camera.position.z<1.30,"AWM x8 camera is too far from scope pivot")
    check(not operator._avatar.visible,"avatar blocks AWM x8 reticle")
    operator.set_ads(false,1.0)
    await _frames(72)
    check(camera.position.z>2.7,"TPS camera failed to restore after 8x ADS")
    check(operator._avatar.visible,"avatar missing after ending AWM scope")
    print("V759_CAMERA PASS wall_collapse,avatar_hide,soft_recovery,shoulder_slide,AWM_8x")
    quit(1 if failed else 0)
