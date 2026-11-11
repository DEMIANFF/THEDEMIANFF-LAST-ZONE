extends SceneTree
## Audit regression: reproduce the *automatic* low-altitude canopy route,
## rather than manually invoking deploy_parachute() from outside physics.
const TRACE=preload("res://scripts/match/flight_diagnostics.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(condition: bool, reason: String) -> void:
    if not condition:
        failed=true
        push_error("CANOPY_AUTO_HANDOFF "+reason)

func frames(count: int) -> void:
    for i in range(count):
        await physics_frame

func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var player: CharacterBody3D=game.get_node("Operator")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var combat: Node3D=game.get_node("CombatRange")
    director.begin_aircraft_phase()
    await frames(4)
    director._flight.request_jump_or_parachute()
    await frames(8)
    check(director._flight.phase=="freefall" and player.air_mode=="freefall",
        "real jump did not reach freefall")

    # Position is just below the automatic 26m island clearance threshold.
    # On the report's x=0 trajectory this would have executed from
    # airdrop_sequence._physics_process(), not the manual HUD callback.
    var x: float=0.0
    var z: float=52.30001
    player.global_position=Vector3(x,terrain.height_at(x,z)+25.8,z)
    player.velocity=Vector3(0,-26,0)
    var prebuilt_id: int=player._parachute_visual.get_instance_id()
    check(hud.air_stage=="freefall","HUD already switched before threshold")
    director._flight._physics_process(1.0/60.0)
    check(director._flight.phase=="parachute_pending",
        "automatic physics callback performed a synchronous canopy transition")
    check(player.air_mode=="freefall" and hud.air_stage=="freefall",
        "operator/HUD were modified inside the auto-canopy physics callback")
    check(TRACE.last().get("note","")=="canopy_auto_deferred_queued",
        "missing durable entry before the automatic deferred operation")
    director._flight._physics_process(1.0/60.0)
    check(director._flight.phase=="parachute_pending" and
        player._parachute_visual.get_instance_id()==prebuilt_id,
        "duplicate pending transition or mesh replacement occurred")

    for i in range(6):
        await process_frame
        if director._flight.phase=="parachute":
            break
    check(director._flight.phase=="parachute" and
        player.air_mode=="parachute" and hud.air_stage=="parachute",
        "queued automatic handoff failed to change real physics/HUD")
    await frames(4)
    check(player._parachute_visual.visible and
        player._parachute_visual.get_instance_id()==prebuilt_id,
        "prewarmed canopy render failed or was rebuilt")
    check(player.velocity.y> -26.0 and player.global_position.is_finite(),
        "canopy failed to slow the real player")
    var history: String=str(TRACE.last().get("history",""))
    for entry in ["canopy_auto_deferred_queued",
        "canopy_deferred_commit_started","canopy_hud_after",
        "canopy_deployed","first_parachute_physics_tick"]:
        check(history.contains(entry),"missing persistent handoff checkpoint "+entry)

    # Preserve the complete playable landing and sector battle.
    player.global_position=Vector3(0,terrain.height_at(0,-20)+2.8,-20)
    player.velocity=Vector3(0,-5,0)
    for i in range(160):
        await physics_frame
        if director.mode=="sector_battle":
            break
    check(player.air_mode=="ground" and director.mode=="sector_battle",
        "auto canopy handoff broke landing")
    check(combat.visible and combat.active_fighter_count()==9,
        "auto canopy handoff lost the existing playable offline sector")
    check(TRACE.last().get("state","")=="completed",
        "successful match left an active flight crash report")
    print("CANOPY_AUTO_HANDOFF PASS physics phase queued, HUD deferred, ",
        "mesh stable, 1st canopy tick, 9-player real landing")
    quit(1 if failed else 0)
