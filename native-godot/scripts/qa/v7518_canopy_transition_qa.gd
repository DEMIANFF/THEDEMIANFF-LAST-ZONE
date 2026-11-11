extends SceneTree
## Reproduce V75.17 Motorola's last phase: canopy_deployed at y=32.94m.
const TRACE=preload("res://scripts/match/flight_diagnostics.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V7518_CANOPY "+message)

func frames(n: int) -> void:
    for i in range(n):
        await physics_frame

func _verify() -> void:
    var world: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(world)
    var player: CharacterBody3D=world.get_node("Operator")
    var terrain: StaticBody3D=world.get_node("AuroraTerrain")
    var director: Node3D=world.get_node("AuroraSectorMatch")
    var combat: Node3D=world.get_node("CombatRange")
    director.begin_aircraft_phase()
    await frames(4)
    director._flight.request_jump_or_parachute()
    await frames(8)
    check(player.air_mode=="freefall","jump failed")
    player.global_position=Vector3(0,32.9407,59.60513)
    player.velocity=Vector3(0,-26,0)
    director._flight.deploy_parachute()
    check(player.air_mode=="parachute","physics parachute did not activate")
    check(TRACE.last().get("note","")=="canopy_deployed",
        "canopy checkpoint not committed")
    # The cosmetic canopy is created via deferred main-thread work.
    await process_frame
    await frames(3)
    check(player.air_mode=="parachute","parachute failed first physics frames")
    check(bool(director._flight._parachute_first_tick_committed),
        "first parachute physics tick not persisted")
    # Player and deployment director have separate physics callbacks; the
    # actor may run before or after the director depending on tree ordering.
    check(TRACE.last().get("last_transition","") in
        ["first_parachute_physics_tick","operator_after_canopy_animation",
        "operator_after_move_and_slide"],
        "missing first parachute transition or player physics checkpoint")
    check(str(TRACE.last().get("history","")).contains("first_parachute_physics_tick"),
        "recent breadcrumb history did not preserve first director physics tick")
    check(player._parachute_visual!=null and player._parachute_visual.visible,
        "deferred real parachute mesh did not appear")
    check(player.velocity.y> -26.0 and player.global_position.is_finite(),
        "parachute failed to slow the actual descent")
    for i in range(50):
        player._turn_camera(Vector2(4.0,-1.0))
        await physics_frame
        if director.mode=="sector_battle":
            break
    check(player.global_position.is_finite() and player.velocity.is_finite(),
        "parachute camera movement produced invalid physics")
    check(not combat.visible,"ground bots resumed before landing")
    # Land and verify the full sector restoration.
    var z: float=-20.0
    player.global_position=Vector3(0,terrain.height_at(0,z)+2.8,z)
    player.velocity=Vector3(0,-5,0)
    for i in range(160):
        await physics_frame
        if director.mode=="sector_battle":
            break
    check(director.mode=="sector_battle" and player.air_mode=="ground",
        "parachute failed to restore ground mode")
    check(combat.visible and combat.active_fighter_count()==9,
        "real nine-participant sector was not restored")
    check(TRACE.last().get("state","")=="completed",
        "landing did not complete persistent flight record")
    print("V7518_CANOPY PASS deferred mesh, first physics tick, canopy slowdown, ",
        "camera movement, touchdown and real sector battle")
    quit(1 if failed else 0)
