extends SceneTree
## Real-world low-altitude regression for the reported Motorola V75.16 crash.
## V75.14's 215-m high-altitude test never crossed the 39-m roof-ray gate.
const TRACE=preload("res://scripts/match/flight_diagnostics.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(condition: bool, message: String) -> void:
    if not condition:
        failed=true
        push_error("V7517_TERRAIN_FREEFALL "+message)


func frames(count: int) -> void:
    for i in range(count):
        await physics_frame


func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get_node("Operator")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var hud: CanvasLayer=game.get_node("TrainingHUD")

    director.begin_aircraft_phase()
    await frames(4)
    director._flight.request_jump_or_parachute()
    await frames(8)
    check(player.air_mode=="freefall" and director._flight.phase=="freefall",
        "did not enter real flight after jumping from aircraft")

    # Exact horizontal position and speed direction from physical Motorola
    # crash report (freefall_tick_235), normalized to 40m above real terrain.
    var x: float=-5.024177
    var z: float=43.35427
    var ground_y: float=terrain.height_at(x,z)
    player.global_position=Vector3(x,ground_y+40.0,z)
    player.velocity=Vector3(-6.144969,-26.0,-5.872764)
    player.set_touch_move_axis(Vector2(-.72,-.69))
    for i in range(5):
        player._turn_camera(Vector2(8.0,-1.0))
        await physics_frame
    check(player.air_mode=="freefall" and
        str(director._flight.phase)=="freefall",
        "danger-zone proximity triggered an incorrect fall phase")
    check(bool(director._flight._ground_approach_marked),
        "39-m approach marker not committed on the physical crash route")
    check(str(TRACE.last().get("last_transition","")).begins_with("terrain_approach_no_ray_"),
        "persistent diagnostic does not identify entry into near-ground path")
    check(player.global_position.is_finite() and player.velocity.is_finite(),
        "proximity traversal produced a non-finite motion state")
    check(not combat.visible,
        "ground combat was erroneously activated while still freefalling")

    # The live Motorola position was still above 26 m clearance. Approach
    # the actual deploy threshold under the same -26m/s vertical velocity.
    x=player.global_position.x
    z=player.global_position.z
    player.global_position=Vector3(x,terrain.height_at(x,z)+27.0,z)
    player.velocity=Vector3(-6.144969,-26.0,-5.872764)
    for i in range(8):
        await physics_frame
        if player.air_mode=="parachute":
            break
    check(player.air_mode=="parachute" and
        str(director._flight.phase)=="parachute",
        "real canopy did not deploy automatically based on island heightfield")
    check(str(TRACE.last().get("phase",""))=="parachute",
        "canopy checkpoint was not saved after terrain-controlled deployment")

    # Complete the same playable world after avoiding the suspect ray.
    player.set_touch_move_axis(Vector2.ZERO)
    z=-20.0
    player.global_position=Vector3(0.0,terrain.height_at(0.0,z)+2.8,z)
    player.velocity=Vector3(0.0,-5.0,0.0)
    for i in range(160):
        await physics_frame
        if director.mode=="sector_battle":
            break
    check(director.mode=="sector_battle" and player.air_mode=="ground",
        "removing roof rays broke genuine touchdown or combat")
    check(combat.visible and combat.active_fighter_count()==9 and
        hud.air_stage=="ground",
        "ground match was not restored after protected real canopy")
    check(str(TRACE.last().get("state",""))=="completed",
        "successful landing retained an active crash breadcrumb")
    print("V7517_TERRAIN_FREEFALL PASS Motorola horizontal crash route, ",
        "39-m boundary, real 26-m parachute and full 9-participant ground battle")
    quit(1 if failed else 0)
