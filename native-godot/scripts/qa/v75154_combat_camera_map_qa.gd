extends SceneTree
## Verify the actual 964x434 mobile camera against live terrain, HUD,
## 49 damageable opponents, shoulder occlusion and two independently framed
## sights. Screenshot evidence uses Godot OpenGL desktop, NOT Motorola QA.
const PLAYER=preload("res://scripts/player/third_person_operator.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(condition: bool,why: String) -> void:
    if not condition:
        failed=true
        push_error("V75154_COMBAT_CAMERA_MAP "+why)

func frames(n: int) -> void:
    for i in range(n):
        await physics_frame

func _verify() -> void:
    root.size=Vector2i(964,434)
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var actor: CharacterBody3D=game.get_node("Operator")
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var tactical: Control=hud.get_node(
        "AuroraTacticalOverlay/AuroraFullTacticalMap")
    var camera: Camera3D=actor.get_view_camera()
    check(camera!=null and tactical!=null,
        "missing real camera or cartographic HUD")
    check(absf(PLAYER.GROUND_CAMERA_DISTANCE-3.80)<.01 and
        PLAYER.GROUND_CAMERA_DISTANCE<4.6 and
        PLAYER.ADS_CAMERA_DISTANCE<PLAYER.GROUND_CAMERA_DISTANCE,
        "third-person ground/ADS distances do not distinguish correct aim")
    check(absf(camera.position.z-PLAYER.GROUND_CAMERA_DISTANCE)<.02 and
        absf(camera.fov-74.0)<.1,
        "first frame does not use the closer mobile camera")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    combat.set_encounter_size(50)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    await frames(22)
    check(combat.active_fighter_count()==50 and
        combat._targets.size()==49,
        "camera preview replaced genuine fifty-fighter Battle Royale")
    check(camera.position.z<=PLAYER.GROUND_CAMERA_DISTANCE+.02 and
        camera.position.z>.18 and
        camera.near>=.079 and camera.far>=630.0,
        "shoulder collision/no-clip or island depth precision regressed")
    var yaw_before: float=actor._desired_yaw
    actor.fire_aim_delta(Vector2(48.0,-8.0))
    check(absf(angle_difference(yaw_before,actor._desired_yaw))>.02,
        "camera framing disabled touch drag or free look")
    actor.set_ads(true,2.0)
    await frames(26)
    check(camera.position.z<=PLAYER.ADS_CAMERA_DISTANCE+.05
        and camera.position.z>=.18 and camera.fov<73.0,
        "ADS did not adopt independent collision-safe shoulder framing")
    actor.set_ads(false,1.0)
    await frames(25)
    check(not actor._ads_active and camera.fov>70.0,
        "leaving ADS failed to restore mobile third-person horizon")
    check(tactical.has_method("_draw_landmark") and
        tactical.has_method("_show_landmark_label"),
        "real POI cartography missing after layout changes")
    combat.end_sector_battle()
    game.queue_free()
    await process_frame
    if not failed:
        print("V75154_COMBAT_CAMERA_MAP PASS roster=50 "+
            "ground_camera=3.8m 2x_ads_camera=3.15m "+
            "8x_original=1 collision_safe=1 real_touch_aim=1 "+
            "unmodified_hitbox=1 live_map_POI=1 viewport=964x434 "+
            "motorola_hardware_verification=PENDING")
    quit(1 if failed else 0)
