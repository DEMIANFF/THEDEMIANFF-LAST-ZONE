extends SceneTree
const SESSION=preload("res://scripts/network/aurora_online_session.gd")
const PRESENTATION=preload("res://scripts/network/online_presentation.gd")

func _initialize() -> void:
    call_deferred("_verify")

func _air_rival_visible(session: Node,view: Node) -> bool:
    for item in session.state.get("rivals",[]):
        if not bool(item.get("airborne",false)):
            continue
        var id: int=int(item.id)
        if not view.replicas.has(id):
            continue
        var holder: Node3D=view.replicas[id]
        var canopy:=holder.get_node_or_null("RealRivalParachute") as MeshInstance3D
        var animator:=holder.find_child("AnimationPlayer",true,false) as AnimationPlayer
        if canopy!=null and canopy.is_visible_in_tree() and canopy.mesh!=null and animator!=null and animator.current_animation=="AuroraParachute" and holder.find_child("OnlineRivalHandSocket",true,false)==null:
            return true
    return false

func _verify() -> void:
    var world: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    world.online_presentation_only=true
    root.add_child(world)
    var session:=SESSION.new()
    session.name="AuroraOnline"
    root.add_child(session)
    var view:=PRESENTATION.new()
    world.add_child(view)
    view.setup(world,session)
    if session.connect_local()!=OK:
        quit(1)
        return
    for i in range(120):
        await create_timer(.05).timeout
        if view._has_state and session.state.get("air_mode","")=="aircraft":
            break
    if not view._has_state:
        quit(1)
        return
    var start: Vector3=session.state.position
    await create_timer(.65).timeout
    var plane_ok: bool=session.state.get("air_mode","")=="aircraft" and (session.state.position as Vector3).distance_to(start)>2.0 and is_instance_valid(view.flight_visual) and is_instance_valid(view.flight_visual._craft) and not view.flight_visual.is_physics_processing()
    var aircraft_audio: bool=view.sound._aircraft_active
    var rejected: int=int(session.state.action_rejected)
    view.request_action(session.ACTION_RELOAD)
    await create_timer(.3).timeout
    var gated: bool=int(session.state.action_rejected)>rejected and int(session.state.shots)==0
    view.request_action(session.ACTION_JUMP)
    for i in range(80):
        await create_timer(.05).timeout
        if session.state.get("air_mode","")=="freefall":
            break
    var fall_start: float=float(session.state.position.y)
    var rival_ok: bool=false
    for i in range(16):
        await create_timer(.05).timeout
        rival_ok=rival_ok or _air_rival_visible(session,view)
    var audio_stopped: bool=not view.sound._aircraft_active and not view.sound._flight_transition.playing
    var fall_ok: bool=session.state.get("air_mode","")=="freefall" and float(session.state.position.y)<fall_start-1.0 and not is_instance_valid(view.flight_visual)
    view.request_action(session.ACTION_JUMP)
    for i in range(80):
        await create_timer(.05).timeout
        if session.state.get("air_mode","")=="parachute":
            break
    var canopy_ok: bool=session.state.get("air_mode","")=="parachute" and world.operator._parachute_visual!=null and world.operator._parachute_visual.visible
    for i in range(600):
        await create_timer(.05).timeout
        rival_ok=rival_ok or _air_rival_visible(session,view)
        if session.state.get("match_mode","")=="sector_battle" and session.state.get("air_mode","")=="ground":
            break
    await create_timer(.3).timeout
    var landed: bool=session.state.get("match_mode","")=="sector_battle" and session.state.get("air_mode","")=="ground" and bool(session.state.grounded) and int(session.state.bots)==49 and not world.operator._parachute_visual.visible
    var no_sim: bool=world.get_node_or_null("CombatRange")==null and world.get_node_or_null("AuroraSectorMatch")==null and not world.operator.is_physics_processing()
    var ok: bool=plane_ok and gated and fall_ok and canopy_ok and landed and no_sim
    print("V75230_FLIGHT aircraft=",plane_ok," airborne_combat_rejected=",gated," freefall=",fall_ok," canopy=",canopy_ok," landed=",landed," no_sim=",no_sim," state=",session.state.get("air_mode","")," match=",session.state.get("match_mode",""))
    var cleared: bool=true
    for item in session.state.get("rivals",[]):
        if bool(item.get("airborne",false)):
            cleared=false
    for holder in view.replicas.values():
        if holder.get_node_or_null("RealRivalParachute")!=null:
            cleared=false
    var air_ok: bool=rival_ok and aircraft_audio and audio_stopped and cleared
    print("V75231_AIR_VISUAL rival_canopy=",rival_ok," aircraft_audio=",aircraft_audio," audio_stopped=",audio_stopped," cleared=",cleared)
    ok=ok and air_ok
    if ok:
        print("V75230_FLIGHT PASS")
        print("V75231_AIR_VISUAL PASS")
    else:
        push_error("V75230 deployment regression")
    session.multiplayer.multiplayer_peer.close()
    quit(0 if ok else 1)
