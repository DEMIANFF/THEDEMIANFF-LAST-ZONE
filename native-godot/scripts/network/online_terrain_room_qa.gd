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
    for i in range(400):
        await create_timer(.05).timeout
        if view._has_state and bool(session.state.get("duel_ready",false)) and int(session.state.get("participants",0))==4:
            break
    if not bool(session.state.get("duel_ready",false)):
        push_error("V75243 no four-peer terrain state")
        quit(1)
        return
    var slot: int=int(session.state.room_slot)
    var initial_radius: float=float(session.state.zone_radius)
    var terrain: Node3D=world.get_node("AuroraTerrain")
    var grounded: bool=false
    var real_map: bool=false
    var filtered: bool=false
    var hazard: bool=false
    var contraction: bool=false
    var safe: bool=true
    var start: Vector3=session.state.position
    for i in range(190):
        await create_timer(.05).timeout
        var at: Vector3=session.state.position
        grounded=grounded or bool(session.state.grounded)
        real_map=real_map or (absf(at.y-terrain.height_at(at.x,at.z))<2.0 and not is_instance_valid(view.waiting_visual) and view.zone.visible)
        filtered=filtered or session.state.rivals.size()<3
        contraction=contraction or float(session.state.zone_radius)<initial_radius-1.0
        if slot==0:
            hazard=hazard or (bool(session.state.zone_outside) and int(session.state.zone_hits)>0 and float(session.state.health)<200.0)
        else:
            safe=safe and int(session.state.zone_hits)==0 and float(session.state.health)==200.0
        if i>=30 and i<65 and slot!=0:
            view.operator._desired_yaw=0.0
            view.move_axis=Vector2(0,-1)
        else:
            view.move_axis=Vector2.ZERO
        if i>80 and contraction and (hazard if slot==0 else safe):
            break
    view.move_axis=Vector2.ZERO
    var movement: bool=slot==0 or (session.state.position as Vector3).distance_to(start)>1.0
    var identity: bool=int(session.state.self_peer)==session.multiplayer.get_unique_id()
    var ok: bool=identity and grounded and real_map and filtered and contraction and movement and (hazard if slot==0 else safe) and not world.operator.is_physics_processing()
    print("V75243_TERRAIN slot=",slot," grounded=",grounded," real_map=",real_map," filtered=",filtered," contraction=",contraction," movement=",movement," hazard=",hazard," safe=",safe," radius=",session.state.zone_radius," hp=",session.state.health)
    if ok:
        print("V75243_TERRAIN PASS")
    else:
        push_error("V75243 terrain room regression")
    await create_timer(3.0).timeout
    session.multiplayer.multiplayer_peer.close()
    quit(0 if ok else 1)
