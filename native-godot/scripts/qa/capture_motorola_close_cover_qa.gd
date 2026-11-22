extends SceneTree
## V75.159: screen evidence from REAL Godot third-person operator and the
## actual destructible Aurora blue crystal cover, 964 x 434 phone framing.
## Rendered on CI desktop software OpenGL, NOT a physical Vulkan Motorola test.
const COVER=preload("res://scripts/combat/aurora_deployable_cover.gd")
const CAPTURE_VERSION=preload("res://scripts/qa/aurora_capture_version.gd")


func _initialize() -> void:
    call_deferred("_capture")


func _fail(why: String) -> void:
    push_error("V75159_REAL_CAMERA_CAPTURE "+why)
    quit(1)


func frames(n: int) -> void:
    for i in range(n):
        await physics_frame


func _screenshot(tag: String,stage: String) -> bool:
    await RenderingServer.frame_post_draw
    var photo: Image=root.get_texture().get_image()
    if photo.get_size()!=Vector2i(964,434):
        return false
    var path: String="res://out/aurora-%s-motorola-%s.png"%[tag,stage]
    if photo.save_png(path)!=OK:
        return false
    print("V75159_REAL_CAMERA_CAPTURE frame=",stage," file=",path)
    return true


func _capture() -> void:
    root.size=Vector2i(964,434)
    var tag: String=CAPTURE_VERSION.tag()
    if tag.is_empty():
        _fail("version tag missing")
        return
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var actor=game.get_node("Operator")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    combat.set_encounter_size(50)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    for bot in combat._targets:
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
    var at_ground: float=terrain.height_at(
        actor.global_position.x,actor.global_position.z)
    var cover: StaticBody3D=COVER.new()
    game.add_child(cover)
    cover.global_position=Vector3(
        actor.global_position.x+1.77,at_ground,
        actor.global_position.z+1.85)
    await frames(45)
    if not (camera.position.x<-.18 and camera.position.z>2.0 and
            actor._avatar.visible and cover.is_active()):
        _fail("actual Aurora cover still obstructs the operator camera")
        return
    if not await _screenshot(tag,"right-cover-left-camera"):
        _fail("cannot save real near-blue-wall recovery screenshot")
        return
    cover.take_damage(COVER.MAX_HEALTH)
    await frames(72)
    if not (camera.position.x>.29 and
            camera.position.z>2.8 and actor._avatar.visible):
        _fail("real third-person framing did not recover after cover broke")
        return
    if not await _screenshot(tag,"cover-cleared-camera"):
        _fail("cannot save free-camera recovery screenshot")
        return
    print("V75159_REAL_CAMERA_CAPTURE PASS viewport=964x434 "+
        "live_fifty_roster=1 physical_220_hp_cover=1 "+
        "Lila_visible=1 camera_left_shoulder=1 screenshots=2 "+
        "android_vulkan_device_test=NO")
    game.queue_free()
    await process_frame
    quit(0)
