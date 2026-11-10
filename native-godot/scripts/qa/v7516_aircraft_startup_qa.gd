extends SceneTree
## Real scene isolation: the first aircraft frames must not start the ground
## navmesh/shape-cast workload or render the bot squad. Ground battle must
## restore both systems without losing the original playable loop.
const TRACE=preload("res://scripts/match/flight_diagnostics.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7516_AIRCRAFT "+reason)


func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var player: CharacterBody3D=game.get_node("Operator")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var combat: Node3D=game.get_node("CombatRange")
    var navigation: Node3D=game.get_node("AuroraNavigation")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    check(navigation.is_physics_processing(),"navigation already inactive before battle")
    director.begin_aircraft_phase()
    check(director.mode=="aircraft" and player.air_mode=="aircraft",
        "real aircraft mode was not started")
    check(not navigation.is_physics_processing(),
        "navigation still builds an expensive physics graph in the aircraft")
    check(not combat.visible and combat.process_mode==Node.PROCESS_MODE_DISABLED,
        "ground bots/weapon rigs kept rendering or running during the flight")
    check(TRACE.last().get("note","")=="start",
        "aircraft start should be persisted before the first physics tick")
    await physics_frame
    var first: Dictionary=TRACE.last()
    check(first.get("phase","")=="aircraft" and
        first.get("note","")=="first_aircraft_frame_committed",
        "first physics/render movement checkpoint was not persisted")
    check(player.global_position.z<76.0,
        "first aircraft tick failed to advance player along flight route")
    check(first.get("last_transition","")=="first_aircraft_frame_committed",
        "first aircraft motion was not preserved as the last transition")
    for i in range(55):
        await physics_frame
    check(TRACE.last().get("note","").begins_with("aircraft_tick_"),
        "sustained flight diagnostics did not advance after startup")
    check(TRACE.last().get("last_transition","")=="first_aircraft_frame_committed",
        "routine telemetry overwrote the last meaningful aircraft transition")
    check(not navigation.is_physics_processing() and not combat.visible,
        "ground resources reactivated while riding aircraft")
    check(player.global_position.is_finite() and player.global_position.z<74.0,
        "aircraft flight is not advancing with finite transforms")

    director._flight.request_jump_or_parachute()
    for i in range(8):
        await process_frame
    check(player.air_mode=="freefall","real freefall did not begin")
    check(not combat.visible and not navigation.is_physics_processing(),
        "full ground combat or navigation reactivated before landing")
    director._flight.deploy_parachute()
    check(player.air_mode=="parachute","real parachute was not deployed")
    var z: float=-20.0
    player.global_position=Vector3(0,terrain.height_at(0,z)+2.8,z)
    player.velocity=Vector3(0,-5,0)
    for i in range(160):
        await physics_frame
        if director.mode=="sector_battle":
            break
    check(director.mode=="sector_battle" and player.air_mode=="ground",
        "aircraft isolation broke real landing transition")
    check(combat.visible and combat.process_mode==Node.PROCESS_MODE_INHERIT,
        "ground bots/combat render did not return on landing")
    check(navigation.is_physics_processing() or bool(navigation.available),
        "pathfinding did not resume after landing")
    check(combat.active_fighter_count()==9 and hud.air_stage=="ground",
        "ground Battle Royale controls or eight bots were not restored")
    check(TRACE.last().get("state","")=="completed",
        "successful landing left a false active crash report")
    print("V7516_AIRCRAFT PASS: first render/physics frame checkpoint, aircraft ticks, ",
        "paused pathfinding and 3D combat, restored real 9-participant match")
    quit(1 if failed else 0)
