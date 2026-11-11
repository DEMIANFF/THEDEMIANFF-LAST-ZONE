extends SceneTree
## Software OpenGL scene verification of the first actual moving parachute.
## This does NOT test the Motorola GPU or prove Android crash resolution.
const TRACE=preload("res://scripts/match/flight_diagnostics.gd")

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var scene: PackedScene=load("res://scenes/Main.tscn") as PackedScene
    var game: Node3D=scene.instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var player: CharacterBody3D=game.get_node("Operator")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    director.begin_aircraft_phase()
    for i in range(5):
        await physics_frame
    director._flight.request_jump_or_parachute()
    for i in range(9):
        await process_frame
    if player.air_mode!="freefall":
        push_error("CANOPY_OPENGL_RENDER no real freefall entry")
        quit(1)
        return
    var x: float=0.0
    var z: float=52.30001
    player.global_position=Vector3(x,terrain.height_at(x,z)+25.8,z)
    player.velocity=Vector3(0,-26,0)
    var passed_auto: bool=false
    for i in range(25):
        await physics_frame
        if director._flight.phase=="parachute":
            passed_auto=true
            break
    if not passed_auto or player.air_mode!="parachute" or hud.air_stage!="parachute":
        push_error("CANOPY_OPENGL_RENDER auto canopy/HUD failed in live physics")
        quit(2)
        return
    for i in range(10):
        await process_frame
    if player._parachute_visual==null or not player._parachute_visual.visible:
        push_error("CANOPY_OPENGL_RENDER canopy mesh not visible")
        quit(3)
        return
    if player._animator==null or player._current_clip!="AuroraParachute":
        push_error("CANOPY_OPENGL_RENDER authored skeletal parachute clip not active")
        quit(4)
        return
    if not player.global_position.is_finite() or not player.velocity.is_finite():
        push_error("CANOPY_OPENGL_RENDER non-finite actor physics")
        quit(5)
        return
    await RenderingServer.frame_post_draw
    var screenshot: Image=root.get_texture().get_image()
    if screenshot==null or screenshot.get_width()<720 or screenshot.get_height()<400:
        push_error("CANOPY_OPENGL_RENDER empty rendered frame")
        quit(6)
        return
    var code: Error=screenshot.save_png("res://out/audit-first-canopy-opengl.png")
    if code!=OK:
        push_error("CANOPY_OPENGL_RENDER failed to save first canopy image "+str(code))
        quit(7)
        return
    print("CANOPY_OPENGL_RENDER PASS auto physical transition, authored clip, ",
        "visible preloaded canopy, graphics frame ",screenshot.get_width(),"x",
        screenshot.get_height()," last_checkpoint=",TRACE.last().get("note",""))
    quit(0)
