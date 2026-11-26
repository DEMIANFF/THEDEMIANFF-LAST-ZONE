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
    for i in range(240):
        await create_timer(.05).timeout
        if view._has_state and int(session.state.get("waiting_ready",0))==2 and session.state.get("rivals",[]).size()==1 and view.applied_snapshot_id>=int(session.state.snapshot_id):
            break
    if int(session.state.get("waiting_ready",0))!=2 or session.state.get("rivals",[]).size()!=1:
        push_error("V75237 missing second connection")
        quit(1)
        return
    var self_id: int=int(session.state.self_peer)
    var other_id: int=int(session.state.rivals[0].id)
    var identity: bool=self_id==session.multiplayer.get_unique_id() and self_id!=other_id and bool(session.state.rivals[0].human)
    var origin: Vector3=session.state.position
    var other_origin: Vector3=session.state.rivals[0].position
    view.operator._desired_yaw=0.0
    view.move_axis=Vector2(0,-1)
    var local_motion: bool=false
    var other_motion: bool=false
    var visible: bool=false
    for i in range(45):
        await create_timer(.05).timeout
        local_motion=local_motion or (session.state.position as Vector3).distance_to(origin)>1.0
        for item in session.state.rivals:
            if int(item.id)==other_id:
                other_motion=other_motion or (item.position as Vector3).distance_to(other_origin)>1.0
                visible=visible or (view.replicas.has(other_id) and view.replicas[other_id].find_child("Skeleton3D",true,false)!=null)
    view.move_axis=Vector2.ZERO
    var rejected: int=int(session.state.action_rejected)
    view.request_action(session.ACTION_RELOAD)
    await create_timer(.4).timeout
    var blocked: bool=int(session.state.action_rejected)>rejected and int(session.state.shots)==0 and float(session.state.health)==200.0
    var applied: int=int(session.state.action_applied)
    view.request_action(session.ACTION_JUMP)
    await create_timer(.35).timeout
    var jumped: bool=int(session.state.action_applied)>applied
    var no_local: bool=not world.operator.is_physics_processing() and world.get_node_or_null("CombatRange")==null
    var core: bool=identity and local_motion and other_motion and visible and blocked and jumped and no_local
    print("V75237_DUAL peer=",self_id," other=",other_id," identity=",identity," local_motion=",local_motion," other_motion=",other_motion," visual=",visible," blocked=",blocked," jump=",jumped," no_local=",no_local)
    var first: bool=OS.get_environment("AURORA_DUAL_QA_ROLE")=="first"
    if not first:
        var removed: bool=false
        for i in range(200):
            await create_timer(.05).timeout
            if int(session.state.get("waiting_ready",0))==1 and session.state.rivals.is_empty() and view.replicas.is_empty():
                removed=true
                break
        print("V75237_DISCONNECT removed=",removed)
        core=core and removed
    else:
        await create_timer(1.5).timeout
    if core:
        print("V75237_DUAL PASS")
    else:
        push_error("V75237 dual room regression")
    session.multiplayer.multiplayer_peer.close()
    quit(0 if core else 1)
