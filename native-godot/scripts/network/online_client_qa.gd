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
    view.send_controls=false
    var no_sim: bool=world.get_node_or_null("CombatRange")==null and world.get_node_or_null("AuroraNavigation")==null and world.get_node_or_null("AuroraSectorMatch")==null and not world.operator.is_physics_processing()
    if not no_sim or session.connect_local()!=OK:
        push_error("Client instantiated local simulation or connection failed")
        quit(1)
        return
    for i in range(180):
        await create_timer(.05).timeout
        if view._has_state:
            break
    if not view._has_state or session.state.get("bots",0)!=49 or session.state.get("participants",0)!=50:
        push_error("No actual 50-person server state on presentation client")
        quit(1)
        return
    var start: Vector3=session.state.position
    var initial_elapsed: float=session.state.elapsed
    for i in range(5):
        session.submit_input.rpc_id(1,SESSION.PROTOCOL,1,Vector2(3,0),0.0,-.14,false,false)
        await create_timer(.05).timeout
    view.move_axis=Vector2(0,-1)
    view.firing=true
    view.send_controls=true
    await create_timer(.65).timeout
    view.firing=false
    view.move_axis=Vector2.ZERO
    await create_timer(.45).timeout
    var ammo_before: int=int(session.state.ammo)
    var reload_before: int=int(session.state.reloads)
    view.request_action(session.ACTION_RELOAD)
    # Duplicate reliable command must never repeat the authoritative action.
    session.submit_action.rpc_id(1,SESSION.PROTOCOL,view.action_sequence,session.ACTION_RELOAD)
    await create_timer(3.0).timeout
    var reload_ok: bool=int(session.state.reloads)>reload_before and int(session.state.ammo)>ammo_before
    view.request_action(session.ACTION_CROUCH)
    await create_timer(.5).timeout
    var crouch_ok: bool=bool(session.state.crouched)
    view.request_action(session.ACTION_STAND)
    await create_timer(.5).timeout
    var stand_ok: bool=not bool(session.state.crouched)
    # Sample during the actual jump, not merely a server ACK.
    for i in range(20):
        if bool(session.state.grounded):
            break
        await create_timer(.05).timeout
    var jump_base: float=session.state.position.y
    view.request_action(session.ACTION_JUMP)
    var jump_ok: bool=false
    for i in range(20):
        await create_timer(.05).timeout
        if not bool(session.state.grounded) and float(session.state.position.y)>jump_base+.15:
            jump_ok=true
    view.move_axis=Vector2(0,-1)
    await create_timer(1.0).timeout
    view.send_controls=false
    await create_timer(1.3).timeout
    var final: Dictionary=session.state
    print("V75223_ACTIONS reload=",reload_ok," crouch=",crouch_ok," stand=",stand_ok," jump=",jump_ok," action_ack=",final.action_ack," applied=",final.action_applied," rejected=",final.action_rejected)
    var moved: bool=(final.position as Vector3).distance_to(start)>1.0
    var stopped: bool=Vector2(final.velocity.x,final.velocity.z).length()<.2
    var synced: bool=world.operator.global_position.distance_to(final.position)<.4
    var ok: bool=moved and stopped and synced and final.elapsed>initial_elapsed and final.accepted>10 and final.rejected>0 and final.shots>0 and final.bots==49 and final.has("rivals") and no_sim and reload_ok and crouch_ok and stand_ok and jump_ok and int(final.action_applied)==4 and int(final.action_rejected)>=1
    print("V75222_CLIENT local_ai=0 local_match=0 local_nav=0 start=",start," authoritative=",final.position," presented=",world.operator.global_position," shots=",final.shots," accepted=",final.accepted," rejected=",final.rejected," replicas=",view.replicas.size())
    if ok:
        print("V75223_ACTIONS PASS")
        print("V75222_ONLINE PASS")
        print("V75221_ONLINE PASS")
    else:
        push_error("Online presentation regression")
    session.multiplayer.multiplayer_peer.close()
    quit(0 if ok else 1)
