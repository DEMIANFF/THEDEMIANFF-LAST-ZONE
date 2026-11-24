extends SceneTree
## V75.179: only real, unobstructed, alive AI bodies may appear as exact
## red contacts. Sounds stay approximate bearings, not hidden bot locations.
const SECTOR=preload("res://scripts/match/sector_director.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V75179_VISIBLE_ENEMY_CONTACT "+message)

func _verify() -> void:
    # These FOV/range checks work on actual Godot vectors and camera yaw.
    var eye:=Vector3(0,55,0)
    check(SECTOR.could_see_enemy(eye,0.0,Vector3(0,55,-15)),
        "a genuine in-front close opponent is invisible")
    check(not SECTOR.could_see_enemy(eye,0.0,Vector3(0,55,15))
        and not SECTOR.could_see_enemy(eye,0.0,Vector3(0,55,-45))
        and not SECTOR.could_see_enemy(eye,0.0,Vector3(0,75,-15))
        and not SECTOR.could_see_enemy(eye,0.0,Vector3.INF),
        "FOV, long range, floor separation or infinity leaks a contact")
    check(SECTOR.could_see_enemy(eye,-PI*.5,Vector3(12,55,0))
        and not SECTOR.could_see_enemy(eye,PI*.5,Vector3(12,55,0)),
        "camera yaw east/west mirrored live enemy contacts")

    root.size=Vector2i(964,434)
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var player: CharacterBody3D=game.get_node("Operator")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var radar: Control=game.get_node(
        "TrainingHUD/AuroraTacticalOverlay/AuroraTrainingRadar")
    var tactical: Control=hud.get("_map_overlay") as Control
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot: CharacterBody3D in combat._targets:
        bot.set_physics_process(false)
    check(combat._targets.size()>=1,
        "no actual damageable CharacterBody3D opponent found")
    if combat._targets.is_empty():
        game.queue_free()
        await process_frame
        quit(1)
        return
    var rival: CharacterBody3D=combat._targets[0]
    # Height isolation is intentional: it proves actual body-vs-wall
    # occlusion without a random coastal house/roof skewing the setup.
    player.global_position=Vector3(0,55,-24)
    player.set("_yaw",0.0)
    player.set("_desired_yaw",0.0)
    player.set("air_mode","ground")
    rival.global_position=Vector3(0,55,-37)
    rival.collision_layer=1
    rival.visible=true
    rival.set("health",200.0)
    await physics_frame
    await create_timer(.42).timeout
    await process_frame
    var exact: Vector2=Vector2(
        rival.global_position.x,rival.global_position.z)
    var observer:=Vector2(player.global_position.x,player.global_position.z)
    var contacts: Array[Vector2]=director.visible_enemy_contacts(observer)
    check(contacts.size()==1 and contacts[0].distance_to(exact)<.01,
        "actual unobstructed body missing from live visual contacts")
    check(int(director._visual_contact_rays_last)<=
        SECTOR.MAX_VISUAL_CONTACT_RAYS,
        "visual minimap exceeded its bounded mobile ray budget")
    check(radar.nearby_verified_enemies()==contacts and
        tactical._live_verified_enemies()==contacts,
        "minimap and tactical map disagree about real visual evidence")

    # A genuine StaticBody3D occluder removes the target from BOTH maps.
    var barrier:=StaticBody3D.new()
    barrier.name="RealEnemySightBlocker"
    barrier.collision_layer=1
    game.add_child(barrier)
    barrier.global_position=Vector3(0,56,-30.5)
    var collision:=CollisionShape3D.new()
    var box:=BoxShape3D.new()
    box.size=Vector3(4,3,1.1)
    collision.shape=box
    barrier.add_child(collision)
    await physics_frame
    await create_timer(.38).timeout
    await process_frame
    check(director.visible_enemy_contacts(observer).is_empty() and
        radar.nearby_verified_enemies().is_empty() and
        tactical._live_verified_enemies().is_empty(),
        "real physical wall failed to occlude precise red enemy markers")
    # A REAL shot behind the wall may still produce an orange sound arc,
    # but does not manufacture an exact red triangle on the enemy body.
    radar.note_enemy_gunfire(rival.global_position)
    check(radar._gunfire_pings.size()==1 and
        radar.nearby_verified_enemies().is_empty(),
        "acoustic bearing was incorrectly interpreted as exact LOS")
    barrier.queue_free()
    await physics_frame
    await create_timer(.36).timeout
    await process_frame
    check(director.visible_enemy_contacts(observer).size()==1,
        "removing the wall did not restore a physically sighted opponent")

    player.set("_yaw",PI)
    check(director.visible_enemy_contacts(observer).is_empty(),
        "turning away still reveals a stale enemy position")
    await create_timer(.37).timeout
    await process_frame
    check(director.visible_enemy_contacts(observer).is_empty(),
        "enemy behind actual camera remained on the live minimap")
    player.set("_yaw",0.0)
    await create_timer(.37).timeout
    await process_frame
    check(director.visible_enemy_contacts(observer).size()==1,
        "camera returning to target failed to reacquire visual contact")
    rival.set("health",0.0)
    check(director.visible_enemy_contacts(observer).is_empty(),
        "eliminated enemy remained as a red live map marker")
    director._finish(false)
    check(director.visible_enemy_contacts(observer).is_empty() and
        director._visible_enemy_actors.is_empty(),
        "completed battle leaked old confirmed enemy contact")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75179_VISIBLE_ENEMY_CONTACT PASS real_body=1 "+
            "occlusion=1 audio_not_wallhack=1 map_radar_shared=1 "+
            "yaw=1 death=1 session_cleanup=1 max_rays=8")
    quit(1 if failed else 0)
