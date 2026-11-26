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
        if view._has_state and not session.state.get("vehicles",{}).get("cars",[]).is_empty():
            break
    if not view._has_state or session.state.get("vehicles",{}).get("cars",[]).is_empty():
        push_error("V75235 no chassis state")
        quit(1)
        return
    await create_timer(.25).timeout
    var rejected: int=int(session.state.action_rejected)
    view.request_action(session.ACTION_VEHICLE)
    await create_timer(.4).timeout
    var denied: bool=int(session.state.action_rejected)>rejected and int(session.state.vehicles.ride)==0
    for i in range(100):
        if bool(session.state.vehicles.near):
            break
        view.move_axis=Vector2(1,0)
        await create_timer(.05).timeout
    view.move_axis=Vector2.ZERO
    await create_timer(.2).timeout
    var nearby: bool=bool(session.state.vehicles.near) and view._vehicle.visible
    view.request_action(session.ACTION_VEHICLE)
    await create_timer(.4).timeout
    var entered: bool=int(session.state.vehicles.ride)>0 and not view._fire_pad.visible and view._vehicle.text=="BAJAR"
    var id: int=int(session.state.vehicles.ride)
    var origin: Vector3=session.state.vehicles.cars[0].transform.origin
    view.move_axis=Vector2(0,-1)
    var speed: float=0.0
    for i in range(70):
        await create_timer(.05).timeout
        speed=maxf(speed,float(session.state.vehicles.cars[0].speed))
    view.move_axis=Vector2.ZERO
    var displacement: float=origin.distance_to(session.state.vehicles.cars[0].transform.origin)
    var replica: bool=view.vehicle_replicas.has(id) and not view.vehicle_replicas[id] is PhysicsBody3D
    var combat_blocked: bool=not view._fire_pad.visible
    rejected=int(session.state.action_rejected)
    view.request_action(session.ACTION_RELOAD)
    await create_timer(.4).timeout
    combat_blocked=combat_blocked and int(session.state.action_rejected)>rejected
    var ok: bool=denied and nearby and entered and speed>1.0 and displacement>1.0 and replica and combat_blocked
    print("V75235_VEHICLE distant_denied=",denied," nearby=",nearby," entered=",entered," speed=",speed," displacement=",displacement," visual_only_holder=",replica," combat_blocked=",combat_blocked)
    if ok:
        print("V75235_VEHICLE PASS")
    else:
        push_error("V75235 vehicle regression")
    session.multiplayer.multiplayer_peer.close()
    quit(0 if ok else 1)
