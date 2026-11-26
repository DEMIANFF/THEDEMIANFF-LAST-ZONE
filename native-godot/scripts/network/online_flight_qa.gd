extends SceneTree
const SESSION=preload("res://scripts/network/aurora_online_session.gd")
const PRESENTATION=preload("res://scripts/network/online_presentation.gd")

func _initialize() -> void:
    call_deferred("_verify")

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
    await create_timer(.8).timeout
    var fall_ok: bool=session.state.get("air_mode","")=="freefall" and float(session.state.position.y)<fall_start-1.0 and not is_instance_valid(view.flight_visual)
    view.request_action(session.ACTION_JUMP)
    for i in range(80):
        await create_timer(.05).timeout
        if session.state.get("air_mode","")=="parachute":
            break
    var canopy_ok: bool=session.state.get("air_mode","")=="parachute" and world.operator._parachute_visual!=null and world.operator._parachute_visual.visible
    for i in range(600):
        await create_timer(.05).timeout
        if session.state.get("match_mode","")=="sector_battle" and session.state.get("air_mode","")=="ground":
            break
    await create_timer(.3).timeout
    var landed: bool=session.state.get("match_mode","")=="sector_battle" and session.state.get("air_mode","")=="ground" and bool(session.state.grounded) and int(session.state.bots)==49 and not world.operator._parachute_visual.visible
    var no_sim: bool=world.get_node_or_null("CombatRange")==null and world.get_node_or_null("AuroraSectorMatch")==null and not world.operator.is_physics_processing()
    var ok: bool=plane_ok and gated and fall_ok and canopy_ok and landed and no_sim
    print("V75230_FLIGHT aircraft=",plane_ok," airborne_combat_rejected=",gated," freefall=",fall_ok," canopy=",canopy_ok," landed=",landed," no_sim=",no_sim," state=",session.state.get("air_mode","")," match=",session.state.get("match_mode",""))
    if ok:
        print("V75230_FLIGHT PASS")
    else:
        push_error("V75230 deployment regression")
    session.multiplayer.multiplayer_peer.close()
    quit(0 if ok else 1)
