extends SceneTree
## Evidence from the actual Godot scene, not concept art.
## The QA-only framing brings Lila's arm into view; default game camera
## and touch/HUD layout remain unchanged in the shipped application.
func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var world: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(world)
    var player: CharacterBody3D=world.get_node("Operator")
    var director: Node3D=world.get_node("AuroraSectorMatch")
    var combat: Node3D=world.get_node("CombatRange")
    var camera: Camera3D=player.get_view_camera()
    for bot in combat._targets:
        bot.set_physics_process(false)
    await process_frame
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    player.receive_training_hit(48.0,true)
    var health_before_heal: float=player.training_health
    combat._on_heal()
    if not player._medkit_visual or not player._medkit_visual.visible or (
            player._combat_action!="AuroraHeal"):
        push_error("Lila medical visual isn't linked to real first aid")
        quit(1)
        return
    camera.position=Vector3(.58,.08,2.25)
    camera.fov=65.0
    # Allow the actual AnimationTree to advance into the three-second pose.
    for i in range(38):
        await process_frame
    var active: Image=root.get_texture().get_image()
    if active.save_png("res://out/aurora-v75-63-lila-medkit-active.png")!=OK:
        push_error("Could not save rendered active medical animation")
        quit(2)
        return
    if combat._heal_remaining<=0.0 or not player._medkit_visual.visible:
        push_error("Lila's medkit unexpectedly finished before screenshot")
        quit(3)
        return
    combat._process(combat.HEAL_APPLY_SECONDS+.1)
    for i in range(10):
        await process_frame
    var finished: Image=root.get_texture().get_image()
    if finished.save_png("res://out/aurora-v75-63-lila-medkit-finished.png")!=OK:
        push_error("Could not save rendered post-medkit frame")
        quit(4)
        return
    if (player._medkit_visual.visible or combat._heal_remaining>0 or
            absf(player.training_health-health_before_heal-45.0)>.01):
        push_error("Completed real healing failed: invalid HP or phantom 3D medical item")
        quit(5)
        return
    print("V7563_MEDKIT_RENDER PASS ",active.get_width(),"x",
        active.get_height()," actual_Godot_animation=true real_HEAL=45")
    quit(0)
