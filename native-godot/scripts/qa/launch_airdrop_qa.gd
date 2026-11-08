extends SceneTree
## Full front-end and offline deployment regression. Tests engine physics and UI
## transitions, NOT claim of Motorola physical touch or an online 100-person game.

func _initialize() -> void:
    call_deferred("_verify")


func _verify() -> void:
    var boot_scene:=load("res://scenes/Boot.tscn") as PackedScene
    if boot_scene==null:
        push_error("Boot scene not found")
        quit(131)
        return
    var front:=boot_scene.instantiate() as Control
    root.add_child(front)
    await process_frame
    if front.stage!="welcome" or front.get_node_or_null("AuroraMenuSurface/Page/EnterButton")==null:
        push_error("Original title screen did not boot with enter action")
        quit(132)
        return
    front._show_lobby()
    await process_frame
    if front.stage!="lobby" or front.get_node_or_null("AuroraMenuSurface/Page/PlayModes/BattleButton")==null:
        push_error("Lobby battle selection is missing")
        quit(133)
        return
    for panel in ["PERSONAJE","ARMAS","MISIONES","TIENDA","CUENTA"]:
        front._select_tab(panel)
        if front._info.text.is_empty():
            push_error("Empty lobby tab "+panel)
            quit(134)
            return
    front._launch(false)
    for i in range(4):
        await process_frame
    if front.stage!="training" or not front._game_active():
        push_error("Training button did not enter playable world")
        quit(135)
        return
    front._return_to_lobby()
    await process_frame
    if front.stage!="lobby" or front._game_active():
        push_error("Return-to-lobby did not unload old match")
        quit(136)
        return
    front._launch(true)
    for i in range(5):
        await process_frame
    if front.stage!="battle" or not front._game_active():
        push_error("Offline BR launch failed")
        quit(137)
        return
    var game:=front._game as Node3D
    var director:=game.get_node("AuroraSectorMatch") as Node3D
    var player:=game.get_node("Operator") as CharacterBody3D
    var hud:=game.get_node("TrainingHUD") as CanvasLayer
    var terrain:=game.get_node("AuroraTerrain") as StaticBody3D
    var flight:=director._flight as Node3D
    if director.mode!="aircraft" or player.air_mode!="aircraft" or hud.air_stage!="aircraft":
        push_error("BR must launch in a real interactive aircraft phase")
        quit(138)
        return
    if player.get_node_or_null("AuroraTransportAircraft")==null:
        push_error("Airborne sequence has no visible original aircraft")
        quit(139)
        return
    flight.jump_from_aircraft()
    if player.air_mode!="freefall" or hud.air_stage!="freefall":
        push_error("Aircraft jump did not enter freefall")
        quit(140)
        return
    flight.deploy_parachute()
    if player.air_mode!="parachute" or player.get_node_or_null("AuroraParachute")==null:
        push_error("Parachute not deployed")
        quit(141)
        return
    var landing_z: float=-20.0
    player.global_position=Vector3(0.0,terrain.height_at(0.0,landing_z)+3.0,landing_z)
    player.velocity=Vector3(0,-5,0)
    for i in range(165):
        await physics_frame
        if director.mode=="sector_battle":
            break
    if director.mode!="sector_battle" or player.air_mode!="ground":
        push_error("Land did not transition to BR match; player_air="+player.air_mode+" mode="+director.mode)
        quit(142)
        return
    var combat:=game.get_node("CombatRange") as Node3D
    if combat.active_fighter_count()!=9 or hud.air_stage!="ground":
        push_error("BR landing did not start 9-player sector match / restore HUD")
        quit(143)
        return
    if player.global_position.distance_to(Vector3.ZERO)>200.0:
        push_error("Land took player outside Aurora sector")
        quit(144)
        return
    print("V75 OFFLINE FLOW PASS: welcome > original lobby tabs > training > lobby > aircraft > freefall > parachute > real landed sector BR")
    quit(0)
