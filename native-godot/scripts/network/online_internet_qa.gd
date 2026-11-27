extends SceneTree
const SESSION=preload("res://scripts/network/aurora_online_session.gd")
const TICKET=preload("res://scripts/network/online_admission_ticket.gd")
func _initialize() -> void:
    call_deferred("_verify")
func _verify() -> void:
    var secret: PackedByteArray=OS.get_environment("AURORA_MATCH_SIGNING_KEY").hex_decode()
    var valid: String=OS.get_environment("AURORA_QA_TICKET")
    var room: String=OS.get_environment("AURORA_ROOM_ID")
    var now: int=int(Time.get_unix_time_from_system())
    var claims: Dictionary=TICKET.verify(valid,secret,room,SESSION.PROTOCOL,now)
    var ok: bool=not claims.is_empty() and TICKET.verify(valid+"0",secret,room,SESSION.PROTOCOL,now).is_empty() and TICKET.verify(valid,secret,room+"x",SESSION.PROTOCOL,now).is_empty() and TICKET.verify(valid,secret,room,SESSION.PROTOCOL,now+90).is_empty()
    var session:=SESSION.new()
    session.name="AuroraOnline"
    root.add_child(session)
    var cert:=X509Certificate.new()
    if cert.load(OS.get_environment("AURORA_TLS_CERT"))!=OK:
        quit(1)
        return
    var denied: bool=OS.get_environment("AURORA_QA_DENIED")=="1"
    var credential: String=valid+"0" if denied else valid
    if session.connect_internet("wss://localhost:24621",credential,cert)!=OK:
        quit(1)
        return
    var saw_state: bool=false
    for i in range(100):
        await create_timer(.05).timeout
        if not session.state.is_empty():
            saw_state=true
            break
    var disconnected: bool=session.multiplayer.multiplayer_peer==null or session.multiplayer.multiplayer_peer.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED
    ok=ok and (not saw_state and disconnected if denied else saw_state and bool(session.state.get("room_internet",false)))
    print("V75251_TLS ", "DENIED" if denied else "AUTH", " PASS" if ok else " FAIL")
    if not denied:
        await create_timer(7.0).timeout
    if session.multiplayer.multiplayer_peer!=null:
        session.multiplayer.multiplayer_peer.close()
    quit(0 if ok else 1)
