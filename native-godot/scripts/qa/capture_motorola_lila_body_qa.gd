extends SceneTree
## Images from the real Main.tscn, using the installed Lila rig and weapons.
## Desktop evidence only; never interpreted as a Motorola FPS benchmark.
const VERSION=preload("res://scripts/qa/aurora_capture_version.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    root.size=Vector2i(964,434)
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get_node("Operator")
    var combat: Node3D=game.get_node("CombatRange")
    game.get_node("AuroraSectorMatch").set_process(false)
    player.set_physics_process(false)
    combat.set_process(false)
    game.get_node("TrainingHUD").hide()
    for bot in combat._targets:
        bot.set_physics_process(false)
    player.global_position=Vector3(-75,game.island.height_at(-75,-75),-75)
    player.rotation=Vector3.ZERO
    player._avatar.show()
    var controller: Node=player._animation_controller
    controller.set_process(false)
    controller.tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    var camera:=Camera3D.new()
    game.add_child(camera)
    camera.fov=43.0
    camera.current=true
    combat.open_training_armory()
    for kind in ["weapon_scar","weapon_mp40","weapon_kriss"]:
        combat.collect_sector_loot(kind)
    var poses: Array[Dictionary]=[
        {"name":"ar-front","slot":0,"clip":"AuroraArmedIdle","camera":Vector3(1.5,1.2,-3.3)},
        {"name":"awm-front","slot":1,"clip":"AuroraArmedIdle","camera":Vector3(1.5,1.2,-3.3)},
        {"name":"awm-side","slot":1,"clip":"AuroraAimAWM","camera":Vector3(3.1,1.2,-.9)},
        {"name":"scar-front","slot":2,"clip":"AuroraArmedIdle","camera":Vector3(1.5,1.2,-3.3)},
        {"name":"mp40-crouch","slot":3,"clip":"AuroraCrouch","camera":Vector3(1.5,1.2,-3.3)},
        {"name":"vector-walk","slot":4,"clip":"AuroraArmedWalk","camera":Vector3(1.5,1.2,-3.3)}]
    for pose in poses:
        combat._equip_inventory_weapon(int(pose.slot))
        player.set_equipped_weapon(int(pose.slot))
        controller.reset_ground_pose()
        controller.playback.start(str(pose.clip))
        for frame in range(20):
            controller.tree.advance(1.0/60.0)
            await process_frame
        camera.global_position=player.global_position+pose.camera
        camera.look_at(player.global_position+Vector3(0,.92,0))
        await process_frame
        await RenderingServer.frame_post_draw
        var path: String="res://out/aurora-%s-motorola-lila-%s.png"%[VERSION.tag(),pose.name]
        if root.get_texture().get_image().save_png(path)!=OK:
            failed=true
            push_error("Lila capture not saved: "+path)
        print("V75189_LILA_CAPTURE ",path)
    game.queue_free()
    await process_frame
    quit(1 if failed else 0)
