extends SceneTree
## Verify that the problematic aircraft->freefall handoff is split across
## render frames, with a durable diagnostic BEFORE any player/hud mutation.
const TRACE=preload("res://scripts/match/flight_diagnostics.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(condition: bool,description: String) -> void:
    if not condition:
        failed=true
        push_error("V7515_JUMP "+description)


func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get_node("Operator")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var combat: Node3D=game.get_node("CombatRange")
    for bot in combat._targets:
        bot.set_physics_process(false)

    director.begin_aircraft_phase()
    await physics_frame
    var flight: Node3D=director._flight
    check(str(flight.phase)=="aircraft","aircraft did not start")
    check(TRACE.last().get("last_transition","") in ["start","first_player_motion","first_aircraft_frame_committed"],
        "aircraft start/first motion diagnostic absent")

    flight.jump_from_aircraft()
    check(str(flight.phase)=="jump_pending",
        "jump mutates player before leaving physics/render frame")
    check(player.air_mode=="aircraft" and hud.air_stage=="aircraft",
        "deferred jump is not isolating player and HUD")
    check(TRACE.last().get("phase","")=="jump_pending" and
        TRACE.last().get("note","")=="jump_transition_started",
        "no durable checkpoint ahead of aircraft release")

    # A rapid second tap must not execute the jump twice.
    flight.request_jump_or_parachute()
    flight.jump_from_aircraft()
    for i in range(6):
        await process_frame
    check(str(flight.phase)=="freefall" and player.air_mode=="freefall",
        "jump never reached the real freefall physics phase")
    check(hud.air_stage=="freefall","HUD did not transition")
    check(player.get_node_or_null("AuroraTransportAircraft")==null,
        "aircraft renderer remains attached after jump")
    var log: Dictionary=TRACE.last()
    # V75.22 deliberately records the first freefall rig reveal/physics
    # after jump_committed. These newer breadcrumbs must not be mistaken for
    # an incomplete jump simply because last_transition moved forward.
    check(str(log.get("history","")).contains("freefall / jump_committed"),
        "jump terminal checkpoint missing from durable event sequence")
    check(str(log.get("build","")).begins_with("THEDEMIAN: LAST ZONE"),
        "diagnostic does not identify build")
    # This is the REQUESTED Android renderer stored by flight diagnostics,
    # not the GPU backend on a headless desktop runner. The real hardware
    # driver is reported separately in Android Settings and logcat.
    var requested: String=str(ProjectSettings.get_setting(
        "rendering/renderer/rendering_method.mobile","gl_compatibility"))
    check(requested in ["gl_compatibility","mobile"] and
        str(log.get("render_backend",""))==requested,
        "diagnostic must identify the selected Android renderer")

    for i in range(30):
        await physics_frame
    check(player.air_mode=="freefall" and player.global_position.is_finite(),
        "freefall did not remain playable after deferred swap")
    var after: Dictionary=TRACE.last()
    check(str(after.get("history","")).contains("freefall_tick_actor_enter") and
        str(after.get("history","")).contains("freefall_tick_after_move_and_slide"),
        "first real freefall physics checkpoints missing after jump")
    print("V7515_JUMP PASS deferred 3D release, idempotent jump, early checkpoint, ",
        "real airborne physics, renderer/build and retained last transition")
    quit(1 if failed else 0)
