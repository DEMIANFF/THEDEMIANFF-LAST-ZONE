extends SceneTree
const SESSION=preload("res://scripts/network/aurora_online_session.gd")
func _initialize() -> void:
    call_deferred("_verify")
func _verify() -> void:
    var session:=SESSION.new()
    session.name="AuroraOnline"
    root.add_child(session)
    if session.connect_local()!=OK:
        quit(1)
        return
    for i in range(180):
        await create_timer(.05).timeout
        if not session.state.is_empty():
            break
    if session.state.is_empty() or session.state.get("bots",0)!=49 or session.state.get("participants",0)!=50:
        push_error("No actual 50-person server state")
        quit(1)
        return
    var start: Vector3=session.state.position
    var initial_elapsed: float=session.state.elapsed
    # Invalid movement vectors are rejected by the server.
    for i in range(5):
        session.submit_input.rpc_id(1,SESSION.PROTOCOL,1,Vector2(3,0),0.0,false,false)
        await create_timer(.05).timeout
    var sequence: int=0
    for i in range(50):
        sequence+=1
        session.submit_input.rpc_id(1,SESSION.PROTOCOL,sequence,Vector2(0,-1),0.0,false,true)
        await create_timer(.05).timeout
    # Stop transmitting and verify server dead-man input timeout.
    await create_timer(1.1).timeout
    var final: Dictionary=session.state
    print("AURORA_ONLINE_TEST start=",start," final=",final)
    var moved: bool=(final.position as Vector3).distance_to(start)>1.0
    var stopped: bool=Vector2(final.velocity.x,final.velocity.z).length()<.2
    var ok: bool=moved and stopped and final.elapsed>initial_elapsed and final.accepted>10 and final.rejected>0 and final.shots>0 and final.bots==49 and final.ack==sequence
    if ok:
        print("V75221_ONLINE PASS real ENet UDP, authoritative movement/fire, malformed input rejected, timeout, 49 server bots")
    else:
        push_error("Online authoritative movement/fire/timeout regression")
    session.multiplayer.multiplayer_peer.close()
    quit(0 if ok else 1)
