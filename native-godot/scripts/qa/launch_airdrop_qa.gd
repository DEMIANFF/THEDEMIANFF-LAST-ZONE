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
    var preview:=front.get_node_or_null("AuroraMenuSurface/AvatarPreview") as SubViewportContainer
    if preview==null or not preview.visible:
        push_error("V75 original lobby has no visible 3D character preview viewport")
        quit(149)
        return
    if ResourceLoader.exists("res://assets/characters/aurora_operator.glb"):
        var avatar: Node=preview.get_node_or_null("PreviewViewport/AuroraCharacterStage/ProvisionalRig3D")
        if avatar==null:
            push_error("Imported rig did not appear in lobby preview")
            quit(150)
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
    var overlay:=game.get_node("TrainingHUD/AuroraTacticalOverlay") as Control
    if (overlay.get_node("CORRER") as Control).visible or (overlay.get_node("DirectionalFirePad") as Control).visible:
        push_error("Airplane HUD still shows ground sprint/fire controls")
        quit(145)
        return
    if player.get_node_or_null("AuroraTransportAircraft")==null:
        push_error("Airborne sequence has no visible original aircraft")
        quit(139)
        return
    player._turn_camera(Vector2(64,-18))
    for i in range(12):
        await physics_frame
    if absf(player.get("_yaw"))<.06:
        push_error("Plane camera cannot be rotated by touch look")
        quit(146)
        return
    flight.jump_from_aircraft()
    if flight.phase!="jump_pending":
        push_error("Aircraft jump did not enter deferred transition")
        quit(156)
        return
    for i in range(4):
        await process_frame
    if player.air_mode!="freefall" or hud.air_stage!="freefall":
        push_error("Aircraft jump did not enter freefall")
        quit(140)
        return
    player.set_touch_move_axis(Vector2(1,0))
    var freefall_start: Vector3=player.global_position
    for i in range(20):
        await physics_frame
    if player.global_position.x-freefall_start.x<.40:
        push_error("Freefall joystick does not steer horizontally")
        quit(147)
        return
    player.set_touch_move_axis(Vector2.ZERO)
    # Exercise sustained flight and landing physics, not only instantaneous
    # method calls. A real-device drop crash may occur several frames later.
    var fall_height: float=player.global_position.y
    for i in range(50):
        await physics_frame
    if player.air_mode!="freefall" or not player.global_position.is_finite() or player.global_position.y>=fall_height-1.0:
        push_error("Freefall became invalid before parachute deployment")
        quit(154)
        return
    flight.deploy_parachute()
    if player.air_mode!="parachute" or player.get_node_or_null("AuroraParachute")==null:
        push_error("Parachute not deployed")
        quit(141)
        return
    player._turn_camera(Vector2(87,-37))
    for i in range(55):
        await physics_frame
    if player.air_mode!="parachute" or not player.global_position.is_finite() or not is_finite(player._yaw):
        push_error("Parachute physics/camera became invalid during sustained descent")
        quit(155)
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
        push_error("Ground HUD/match participants not restored")
        quit(143)
        return
    if not (overlay.get_node("CORRER") as Control).visible or not (overlay.get_node("DirectionalFirePad") as Control).visible:
        push_error("Landing did not restore gameplay sprint and fire buttons")
        quit(148)
        return
    if player.global_position.distance_to(Vector3.ZERO)>200.0:
        push_error("Land took player outside Aurora sector")
        quit(144)
        return
    # Keep the native world live after landing: one-frame screenshots do not
    # exercise the risky physics-to-match transition long enough.
    var landed_match_id: int=director._match_id
    for i in range(90):
        await physics_frame
    if not is_instance_valid(player) or not is_instance_valid(director) or director.mode!="sector_battle":
        push_error("Post-landing match did not survive 90 physics ticks")
        quit(151)
        return
    if player.air_mode!="ground" or flight.phase!="landed":
        push_error("Post-landing air state regressed during physics")
        quit(152)
        return
    flight.landed()
    await process_frame
    if director._match_id!=landed_match_id:
        push_error("Duplicate landing generated a second match")
        quit(153)
        return
    print("V75 OFFLINE FLOW PASS: welcome > original lobby tabs > training > lobby > aircraft > freefall > parachute > real landed sector BR > 90 physics ticks")
    quit(0)
