extends SceneTree
## Android exit stopped at jump_committed, before next flight breadcrumb.
## Isolate real 3D character visibility and first freefall animation/physics.
const TRACE=preload("res://scripts/match/flight_diagnostics.gd")
const MODE=preload("res://scripts/persistence/flight_safety_mode.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V7520_FREEFALL "+message)

func _verify() -> void:
    var prior: int=MODE.current_mode()
    for selected in [MODE.MODE_NO_FREEFALL_ANIMATION,MODE.MODE_NO_FREEFALL_AVATAR]:
        check(MODE.save_mode(selected)==OK,"cannot enable freefall test mode")
        var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
        root.add_child(game)
        var player: CharacterBody3D=game.get_node("Operator")
        var terrain: StaticBody3D=game.get_node("AuroraTerrain")
        check(player.canopy_diagnostic_mode==selected,
            "real actor did not read saved Android A/B mode")
        player.global_position=Vector3(0,terrain.height_at(0,52.3)+75.0,52.3)
        player.begin_aircraft()
        player.begin_freefall(Vector3(0.0,0.0,-11.85))
        check(player.air_mode=="freefall",
            "flight mode disabled actual character movement")
        check(player._avatar!=null and player._avatar.visible==
            (not MODE.skip_freefall_avatar(selected)),
            "freefall visual A/B mode did not isolate the skinned mesh")
        for i in range(6):
            await physics_frame
        check(player.air_mode=="freefall" and
            player._first_freefall_step_probe and
            player.velocity.y<0.0 and player.global_position.is_finite(),
            "first freefall physics cycle failed on real actor")
        var history: String=str(TRACE.last().get("history",""))
        for note in ["freefall_tick_actor_enter","freefall_tick_after_camera",
            "freefall_tick_before_move_and_slide",
            "freefall_tick_after_move_and_slide",
            "freefall_tick_before_animation","freefall_tick_after_animation"]:
            check(history.contains(note),
                "missing persisted first freefall detail "+note)
        if player._animator:
            var clip: String="AuroraArmedIdle" if selected==MODE.MODE_NO_FREEFALL_ANIMATION else "AuroraFreefall"
            check(player._current_clip==clip,
                "freefall skeletal animation branch was not isolated")
        player.deploy_parachute()
        check(player.air_mode=="parachute" and player._avatar.visible,
            "A/B freefall visibility was not restored at physical canopy")
        game.queue_free()
        await process_frame
    check(MODE.save_mode(prior)==OK,"user flight mode was not restored")
    check(MODE.label_for(4)!="" and MODE.label_for(5)!="",
        "new freefall A/B modes missing from the actual welcome screen")
    print("V7520_FREEFALL PASS first physics/camera/move/skeleton markers and ",
        "two independent real descent visibility/animation A/B profiles")
    quit(1 if failed else 0)
