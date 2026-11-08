extends SceneTree
## Diagnostic reproduction of bugs reported from Motorola V73 video 148892.mp4.
## Unlike smoke_test.gd, this runs actual physics frames and asserts displacement
## and airborne jump. No simulated visual/audio observations are claimed.


func _initialize() -> void:
    call_deferred("_verify")


func _verify() -> void:
    var game := (load("res://scenes/Main.tscn") as PackedScene).instantiate() as Node3D
    root.add_child(game)
    var operator := game.get_node("Operator") as CharacterBody3D
    var island := game.get_node("AuroraTerrain") as StaticBody3D
    var combat := game.get_node("CombatRange") as Node3D
    var hud := game.get_node("TrainingHUD") as CanvasLayer
    for i in range(130):
        await physics_frame
    var initial_position := operator.global_position
    var floor_height: float = float(island.call("height_at", initial_position.x, initial_position.z))
    print("MOTOROLA_AUDIT settled player=", initial_position,
        " terrain=", floor_height,
        " feet_delta=", initial_position.y-floor_height,
        " is_on_floor=", operator.is_on_floor(),
        " velocity=", operator.velocity)
    for i in range(combat._targets.size()):
        var bot := combat._targets[i] as CharacterBody3D
        print("MOTOROLA_AUDIT bot_",i,
            " position=",bot.global_position,
            " visible=",bot.visible,
            " alive=",bot.get("health"),
            " floor=",bot.is_on_floor())
    if not operator.is_on_floor():
        push_error("MOTOROLA_AUDIT FAIL: character never achieved floor contact before jump")
        quit(21)
        return
    # No fake gamepad: drive the exact analogue vector consumed by _physics_process.
    operator.set("_move_axis",Vector2(0.0,-1.0))
    for i in range(75):
        await physics_frame
    operator.set("_move_axis",Vector2.ZERO)
    var after_walk := operator.global_position
    var distance := Vector2(initial_position.x,initial_position.z).distance_to(
        Vector2(after_walk.x,after_walk.z))
    print("MOTOROLA_AUDIT walk_distance_m=",distance,
        " moved_from=",initial_position," to=",after_walk,
        " floor=",operator.is_on_floor())
    if distance<1.0:
        push_error("MOTOROLA_AUDIT FAIL: analogue input did not move character on terrain")
        quit(22)
        return
    for i in range(12):
        await physics_frame
    var jump_start: float=operator.global_position.y
    operator.call("touch_jump")
    var highest: float=jump_start
    for i in range(36):
        await physics_frame
        highest=maxf(highest,operator.global_position.y)
    var jump_rise: float=highest-jump_start
    print("MOTOROLA_AUDIT jump_rise_m=",jump_rise,
        " jump_start=",jump_start,
        " highest=",highest,
        " floor=",operator.is_on_floor())
    if jump_rise<.3:
        push_error("MOTOROLA_AUDIT FAIL: touch_jump produced no actual upward motion")
        quit(23)
        return

    # This validates the HUD's signal path, distinct from pointer dispatch.
    hud.call("_run_down")
    await physics_frame
    var sprint: bool=bool(operator.get("_sprint_touch"))
    hud.call("_run_up")
    var held_after_release: bool=bool(operator.get("_sprint_touch"))
    hud.call("_run_down")
    if not sprint or not held_after_release or bool(operator.get("_sprint_touch")):
        push_error("MOTOROLA_AUDIT FAIL: tap-to-sprint state does not persist or deactivate")
        quit(24)
        return
    print("MOTOROLA_AUDIT PASS: terrain grounding, analogue walking, touch jumping, sprint signal")
    quit(0)
