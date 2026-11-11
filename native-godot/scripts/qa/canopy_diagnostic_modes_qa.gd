extends SceneTree
## Android field A/B: same real airborne actor/physics, isolated visual toggles.
const MODE=preload("res://scripts/persistence/flight_safety_mode.gd")
const TRACE=preload("res://scripts/match/flight_diagnostics.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("CANOPY_DIAGNOSTIC_MODE "+message)

func _verify() -> void:
    var world: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(world)
    var player: CharacterBody3D=world.get_node("Operator")
    var terrain: StaticBody3D=world.get_node("AuroraTerrain")
    var original_mode: int=MODE.current_mode()
    var mesh_id: int=player._parachute_visual.get_instance_id()
    for mode in range(4):
        player.begin_aircraft()
        player.global_position=Vector3(0,terrain.height_at(0,52.3)+60.0,52.3)
        player.begin_freefall(Vector3.ZERO)
        player.velocity=Vector3(0,-26.0,0)
        player.canopy_diagnostic_mode=mode
        player.deploy_parachute()
        for j in range(6):
            await physics_frame
        await process_frame
        check(player.air_mode=="parachute",
            "mode "+str(mode)+" disabled actual parachute physics")
        check(player.velocity.y>-26.0 and player.global_position.is_finite(),
            "mode "+str(mode)+" lost controlled physical descent")
        check(player._parachute_visual.get_instance_id()==mesh_id,
            "mode "+str(mode)+" unexpectedly rebuilt canopy")
        var should_show: bool=not MODE.skip_canopy_mesh(mode)
        check(player._parachute_visual.visible==should_show,
            "mode "+str(mode)+" incorrect physical canopy visibility")
        if player._animator:
            var expected_clip: String="AuroraFreefall" if MODE.skip_canopy_animation(mode) else "AuroraParachute"
            check(player._current_clip==expected_clip,
                "mode "+str(mode)+" incorrect animation branch: "+player._current_clip)
    check(MODE.label_for(0)!="" and MODE.label_for(3)!="",
        "missing human-readable A/B selector labels")
    check(MODE.save_mode(2)==OK and MODE.current_mode()==2,
        "flight A/B mode did not persist")
    check(TRACE.checkpoint("active","parachute",player,"diag_mode_test")==OK,
        "could not persist selected flight-mode report")
    check(int(TRACE.last().get("diagnostic_mode",-1))==2,
        "flight crash report omits selected graphics mode")
    check(MODE.save_mode(original_mode)==OK,
        "flight A/B mode did not restore original setting")
    print("CANOPY_DIAGNOSTIC_MODE PASS all 4 modes retain real physics, ",
        "same 3D mesh identity, isolated animation/visual paths, reports")
    quit(1 if failed else 0)
