extends SceneTree
## Actual scene and registered skinned character; test Android canopy
## pre-allocation and persistent first-physics callbacks from V75.18 crash.
const TRACE=preload("res://scripts/match/flight_diagnostics.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(value: bool,reason: String) -> void:
    if not value:
        failed=true
        push_error("V7519_PREWARM "+reason)

func frames(n: int) -> void:
    for i in range(n):
        await physics_frame

func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var player: CharacterBody3D=game.get_node("Operator")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var combat: Node3D=game.get_node("CombatRange")

    check(player._parachute_visual!=null and
        not player._parachute_visual.visible,
        "canopy meshes not prebuilt and hidden during scene _ready")
    var prebuilt_id: int=player._parachute_visual.get_instance_id()
    check(player._parachute_visual.get_child_count()==5,
        "original canopy and four cords not preserved")
    director.begin_aircraft_phase()
    await frames(4)
    director._flight.request_jump_or_parachute()
    await frames(8)
    check(player.air_mode=="freefall","did not enter real freefall")
    check(player._parachute_visual.get_instance_id()==prebuilt_id and
        not player._parachute_visual.visible,
        "prebuilt canopy was reconstructed or shown during freefall")

    # Exact position and velocity of Motorola's V75.18 last checkpoint.
    player.global_position=Vector3(0.0,32.9407,52.30001)
    player.velocity=Vector3(0.0,-26.0,0.0)
    director._flight.deploy_parachute()
    check(player.air_mode=="parachute" and
        player._parachute_visual.get_instance_id()==prebuilt_id,
        "parachute state replaced the prewarmed mesh")
    for i in range(3):
        await process_frame
    await frames(4)
    check(player._parachute_visual.visible and
        player._parachute_visual.get_instance_id()==prebuilt_id,
        "deferred callback did not reveal original prebuilt canopy")
    check(player._first_canopy_step_probe,
        "first physical parachute callback was not entered")
    var history: String=str(TRACE.last().get("history",""))
    for note in ["canopy_visual_before","canopy_visual_enabled",
        "operator_first_tick_enter","operator_after_move_and_slide",
        "first_parachute_physics_tick"]:
        check(history.contains(note),"diagnostic history missing "+note)
    check(player.velocity.y> -26.0 and player.global_position.is_finite(),
        "parachute did not physically slow descent")
    check(not combat.visible,"combat incorrectly resumed during flight")

    # The actual world must complete its existing touchdown flow.
    var z: float=-20.0
    player.global_position=Vector3(0.0,terrain.height_at(0,z)+2.8,z)
    player.velocity=Vector3(0.0,-5.0,0.0)
    for i in range(160):
        await physics_frame
        if director.mode=="sector_battle":
            break
    check(player.air_mode=="ground" and director.mode=="sector_battle",
        "protected prebuilt canopy broke ground handoff")
    check(combat.visible and combat.active_fighter_count()==9,
        "real eight bots and player did not resume")
    print("V7519_PREWARM PASS original mesh identity, deferred visibility, ",
        "actor-first physics markers, physical slowdown and 9-person sector")
    quit(1 if failed else 0)
