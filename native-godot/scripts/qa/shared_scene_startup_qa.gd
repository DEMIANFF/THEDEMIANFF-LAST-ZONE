extends SceneTree
## The user's Motorola crash occurs in Training AND in the Royale flow.
## Reproduce loading of the exact Main scene, not the parachute alone.
const STARTUP=preload("res://scripts/persistence/scene_startup_diagnostics.gd")
const TRACE=preload("res://scripts/match/flight_diagnostics.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,detail: String) -> void:
    if not ok:
        failed=true
        push_error("SHARED_SCENE_STARTUP "+detail)

func _verify() -> void:
    var initial: int=STARTUP.mode()
    var main: PackedScene=load("res://scenes/Main.tscn") as PackedScene
    for profile in range(5):
        check(STARTUP.save(profile)==OK,"unable to save startup profile "+str(profile))
        var game: Node3D=main.instantiate()
        root.add_child(game)
        check(game.get_node_or_null("AuroraTerrain")!=null,
            "profile "+str(profile)+" removed actual terrain")
        var player: CharacterBody3D=game.get_node_or_null("Operator") as CharacterBody3D
        var hud: CanvasLayer=game.get_node_or_null("TrainingHUD") as CanvasLayer
        var combat: Node3D=game.get_node_or_null("CombatRange") as Node3D
        var director: Node3D=game.get_node_or_null("AuroraSectorMatch") as Node3D
        check(player!=null and hud!=null and combat!=null and director!=null,
            "profile "+str(profile)+" broke the core playable scene")
        check(combat._targets.size()==4,
            "profile "+str(profile)+" removed actual training AI")
        var navigation: Node3D=game.get_node("AuroraNavigation")
        if profile==STARTUP.NO_NAVIGATION_GRAPH:
            check(not navigation.is_physics_processing() and not navigation.available,
                "profile 4 failed to isolate AI navigation-shape queries")
        else:
            check(navigation.is_physics_processing(),
                "profile "+str(profile)+" unintentionally disabled navigation")
        var decorations: bool=not STARTUP.without_decorations()
        check((game.get_node_or_null("PuertoAuroraCoastalQuarter")!=null)==decorations and
            (game.get_node_or_null("AuroraNature")!=null)==decorations,
            "profile "+str(profile)+" did not isolate decorative 3D world")
        for target in combat._targets:
            check((target._rig!=null)==(not STARTUP.without_enemy_rigs()),
                "profile "+str(profile)+" failed skinned-model isolation")
            check(target.get_node_or_null("OpponentCollider")!=null,
                "profile "+str(profile)+" removed actual enemy collision")
        check(str(TRACE.last().get("note",""))=="main_scene_ready",
            "profile "+str(profile)+" omitted completed scene checkpoint")
        check(int(TRACE.last().get("startup_mode",-1))==profile,
            "profile "+str(profile)+" omitted A/B mode from diagnostics")
        game.queue_free()
        await process_frame

    check(STARTUP.save(0)==OK,"could not restore normal scene mode")
    var frontend: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(frontend)
    frontend._show_lobby()
    frontend._launch(false)
    for i in range(8):
        await process_frame
        if frontend.stage=="training":
            break
    check(frontend.stage=="training" and frontend._game!=null,
        "welcome > lobby > Training failed actual shared-world startup")
    check(str(TRACE.last().get("phase",""))=="training",
        "Training startup did not write durable stage diagnosis")
    check(str(TRACE.last().get("note","")) in
        ["training_entered","shared_scene_first_frame_rendered"],
        "Training startup did not record its last successful operation")
    if frontend._game!=null:
        check(frontend._game.get_node_or_null("Operator")!=null,
            "Training lacks the real CharacterBody3D player")
    check(STARTUP.save(initial)==OK,"failed to restore initial user-selected profile")
    print("SHARED_SCENE_STARTUP PASS full 3D scene, all 4 A/B profiles, actual ",
        "terrain/bots/collisions, Training welcome-to-world and durable trace")
    quit(1 if failed else 0)
