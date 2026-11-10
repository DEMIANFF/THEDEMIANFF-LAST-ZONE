extends SceneTree
## Hardware crash reproduction is unavailable in headless CI. This test does
## exercise sustained 3D flight/aim, camera distance and durable breadcrumbs.
const TRACE=preload("res://scripts/match/flight_diagnostics.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V7514_FREEFALL "+message)


func frames(count: int) -> void:
    for i in range(count):
        await physics_frame


func _verify() -> void:
    # Start through the real game scene and sector director, not a simulation.
    var world: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(world)
    var director: Node3D=world.get_node("AuroraSectorMatch")
    var player: CharacterBody3D=world.get_node("Operator")
    var hud: CanvasLayer=world.get_node("TrainingHUD")
    var combat: Node3D=world.get_node("CombatRange")
    var terrain: StaticBody3D=world.get_node("AuroraTerrain")
    for bot in combat._targets:
        bot.set_physics_process(false)
    director.begin_aircraft_phase()
    await frames(8)
    check(str(director._flight.phase)=="aircraft","aircraft phase failed")
    check(TRACE.last().get("phase","")=="aircraft","missing aircraft checkpoint")

    director._flight.request_jump_or_parachute()
    check(TRACE.last().get("phase","")=="jump_requested",
        "jump input was not persisted before physics transition")
    for i in range(6):
        await physics_frame
    check(player.air_mode=="freefall" and hud.air_stage=="freefall",
        "jump did not enter real freefall")
    check(TRACE.last().get("phase","")=="freefall","jump checkpoint not persisted")
    # Extend the altitude only for this regression; otherwise auto-parachute
    # shortens the freefall before the several seconds seen in Motorola video.
    player.global_position=Vector3(0.0,215.0,0.0)
    player.velocity=Vector3(0.0,-4.0,0.0)
    player.set_touch_move_axis(Vector2(.65,-.35))
    var initial: Vector3=player.global_position
    for i in range(210):
        if i%7==0:
            player._turn_camera(Vector2(3.1,-.8))
        await physics_frame
        if i%35==0:
            var snapshot: Dictionary=TRACE.last()
            check(snapshot.get("state","")=="active",
                "flight breadcrumb vanished in active freefall")
        if player.air_mode!="freefall":
            check(false,"unexpected descent transition at physics tick "+str(i))
            break
    check(player.global_position.is_finite() and player.velocity.is_finite(),
        "freefall produced NaN/INF in position or velocity")
    check(player.global_position.distance_to(initial)>10.0,
        "freefall controls/physics stopped unexpectedly")
    check(player.get_view_camera().position.z>3.0,
        "high-altitude TPS camera was unexpectedly clamped by geometry")
    check(TRACE.last().get("phase","")=="freefall",
        "periodic diagnostic did not preserve active freefall")
    player.set_touch_move_axis(Vector2.ZERO)

    director._flight.deploy_parachute()
    check(TRACE.last().get("phase","")=="parachute",
        "parachute checkpoint not persisted")
    await frames(25)
    check(player.air_mode=="parachute","parachute flight ended unexpectedly")
    var z: float=-20.0
    player.global_position=Vector3(0,terrain.height_at(0,z)+2.8,z)
    player.velocity=Vector3(0,-5,0)
    for i in range(160):
        await physics_frame
        if director.mode=="sector_battle":
            break
    check(director.mode=="sector_battle" and player.air_mode=="ground",
        "did not enter real battle after landing")
    check(TRACE.last().get("state","")=="completed",
        "completed ground match retained stale crashed-flight diagnostic")
    check(TRACE.last().get("phase","")=="ground",
        "completed flight did not commit final ground state")

    print("V7514_FREEFALL PASS 210 airborne physics ticks, real touch look, ",
        "finite state, camera, durable diagnostics, canopy and sector landing")
    quit(1 if failed else 0)
