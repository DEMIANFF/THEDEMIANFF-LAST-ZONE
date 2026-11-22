extends SceneTree
## V75.159: real 3D cover as shown by user video 181292.mp4.
## A crystal facet must never protrude behind its physics collider and
## cause third-person camera/character to disappear at the right shoulder.
const COVER=preload("res://scripts/combat/aurora_deployable_cover.gd")
const PLAYER=preload("res://scripts/player/third_person_operator.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V75159_COVER_CAMERA "+why)


func frames(count: int) -> void:
    for i in range(count):
        await physics_frame


func _camera_in_cover(camera: Camera3D,barrier: StaticBody3D) -> bool:
    var query:=PhysicsShapeQueryParameters3D.new()
    var probe:=SphereShape3D.new()
    probe.radius=.24
    query.shape=probe
    query.transform=Transform3D(Basis(),camera.global_position)
    query.collision_mask=1
    var space:=camera.get_world_3d().direct_space_state
    for hit in space.intersect_shape(query,16):
        if hit.get("collider")==barrier:
            return true
    return false


func _verify() -> void:
    root.size=Vector2i(964,434)
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var actor=game.get_node("Operator")
    var terrain=game.get_node("AuroraTerrain")
    for bot in game.get_node("CombatRange")._targets:
        bot.set_physics_process(false)
    actor.global_position=Vector3(-75.0,
        terrain.height_at(-75.0,-75.0)+2.0,-75.0)
    actor.velocity=Vector3.ZERO
    actor._yaw=0.0
    actor._desired_yaw=0.0
    actor._pitch=-.14
    actor._desired_pitch=-.14
    await frames(80)
    var camera: Camera3D=actor.get_view_camera()
    check(camera!=null and camera.position.z>2.8 and
        actor._avatar.visible,
        "real 964x434 third-person follow was missing before cover")
    check(PLAYER.GROUND_CAMERA_DISTANCE>=3.70 and
        actor._camera_collision_shape.radius>=.29,
        "close-range camera still fits through crystal render facets")

    # A real barrier placed just behind Lila's RIGHT shoulder; centre
    # and preferred shoulder are obstructed, opposite shoulder is free.
    var ground_y: float=terrain.height_at(
        actor.global_position.x,actor.global_position.z)
    var cover: StaticBody3D=COVER.new()
    cover.name="RealCameraOccludingAuroraWall"
    game.add_child(cover)
    cover.global_position=Vector3(
        actor.global_position.x+1.77,ground_y,
        actor.global_position.z+1.85)
    await frames(6)
    var collision:=cover.get_node_or_null(
        "AuroraIceWallCollision") as CollisionShape3D
    check(collision!=null and collision.shape is BoxShape3D and
        (collision.shape as BoxShape3D).size.x>=3.49 and
        (collision.shape as BoxShape3D).size.y>=2.60 and
        (collision.shape as BoxShape3D).size.z>=.86,
        "rendered barrier spires extend beyond their physical camera collision")
    var right_distance: float=actor._collision_safe_camera_distance(
        PLAYER.GROUND_CAMERA_DISTANCE,.38)
    var left_distance: float=actor._collision_safe_camera_distance(
        PLAYER.GROUND_CAMERA_DISTANCE,-.38)
    check(right_distance<1.60 and left_distance>right_distance+.65,
        "test barrier is not truly blocking right shoulder while left is free")
    await frames(40)
    check(camera.position.x<-.18 and camera.position.z>2.0 and
        actor._avatar.visible,
        "third-person camera kept right shoulder inside blue ice and hid Lila")
    check(not _camera_in_cover(camera,cover),
        "physical third-person camera penetrated solid crystal mesh")

    # An active cover still stops bullets, bots and player collisions.
    check(cover.is_active() and cover.collision_layer==1 and
        cover.get_node_or_null("AuroraIceWallCollision")!=null,
        "camera fix deleted/disabled authoritative cover collision")
    var hp: float=float(cover.health)
    cover.take_damage(12.0)
    check(absf(float(cover.health)-(hp-12.0))<.01,
        "camera fix removed real destructible 220-HP barrier gameplay")

    cover.take_damage(COVER.MAX_HEALTH)
    await frames(70)
    check(not is_instance_valid(cover) and camera.position.x>.29 and
        camera.position.z>2.8 and actor._avatar.visible,
        "breaking barrier did not restore preferred camera and operator")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75159_COVER_CAMERA PASS viewport=964x434 "+
            "real_crystal_collision=1 shoulder_left=1 "+
            "no_camera_mesh_penetration=1 Lila_visible=1 "+
            "physical_cover_hp=220 restore_right_shoulder=1 "+
            "motorola_hardware_test=NO")
    quit(1 if failed else 0)
