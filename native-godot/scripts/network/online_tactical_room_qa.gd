extends SceneTree
const SESSION=preload("res://scripts/network/aurora_online_session.gd")
const PRESENTATION=preload("res://scripts/network/online_presentation.gd")
func _initialize() -> void:
    call_deferred("_verify")
func _walk(session: Node,view: Node,kind: String) -> bool:
    var target: Vector3=Vector3.ZERO
    var found: bool=false
    for item in session.state.loot:
        if str(item.kind)==kind:
            found=true
            target=item.position
            break
    if not found:
        return false
    view.operator._desired_yaw=0.0
    await create_timer(.5).timeout
    for i in range(180):
        if int(session.state.inventory.grenades if kind=="grenade" else session.state.inventory.covers)>0:
            view.move_axis=Vector2.ZERO
            return true
        var offset: Vector3=target-session.state.position
        view.move_axis=Vector2(offset.x,offset.z).limit_length(1.0)
        await create_timer(.05).timeout
    view.move_axis=Vector2.ZERO
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
    for i in range(400):
        await create_timer(.05).timeout
        if view._has_state and bool(session.state.get("duel_ready",false)):
            break
    if not bool(session.state.get("duel_ready",false)):
        quit(1)
        return
    var slot: int=int(session.state.room_slot)
    var ok: bool=SESSION.is_private_lan_host("192.168.1.7") and not SESSION.is_private_lan_host("8.8.8.8") and not SESSION.is_private_lan_host("0.0.0.0")
    if slot==0:
        var denied: int=int(session.state.action_rejected)
        view.request_action(session.ACTION_GRENADE)
        await create_timer(.4).timeout
        var unowned: bool=int(session.state.action_rejected)>denied
        var grenade: bool=await _walk(session,view,"grenade")
        var cover: bool=await _walk(session,view,"cover_charge")
        view.operator._desired_yaw=PI*.5
        view.operator._desired_pitch=0.0
        await create_timer(.7).timeout
        view.request_action(session.ACTION_COVER)
        await create_timer(.5).timeout
        var wall: bool=int(session.state.walls)==1 and int(session.state.inventory.covers)==0 and view.cover_replicas.size()>0
        view.operator._desired_yaw=-PI*.5
        view.operator._desired_pitch=.0
        await create_timer(.7).timeout
        view.request_action(session.ACTION_GRENADE)
        var projectile: bool=false
        for i in range(100):
            await create_timer(.05).timeout
            projectile=projectile or view.grenade_replicas.size()>0
            if int(session.state.tactical.blast_sequence)>0:
                break
        ok=ok and unowned and grenade and cover and wall and projectile and int(session.state.throws)==1 and int(session.state.inventory.grenades)==0 and int(session.state.tactical.blast_sequence)==1
        print("V75249_OWNER grenade=",grenade," cover=",cover," wall=",wall," projectile=",projectile," unowned=",unowned," blast=",session.state.tactical.blast_sequence)
        await create_timer(4.0).timeout
    else:
        var observed: bool=false
        var private_stock: bool=true
        for i in range(550):
            await create_timer(.05).timeout
            private_stock=private_stock and int(session.state.inventory.grenades)==0 and int(session.state.inventory.covers)==0
            observed=observed or (int(session.state.tactical.blast_sequence)==1 and view.cover_replicas.size()>0)
            if observed:
                break
        ok=ok and observed and private_stock
        print("V75249_OBSERVER slot=",slot," observed=",observed," private=",private_stock)
        await create_timer(5.0).timeout
    if ok:
        print("V75249_TACTICAL PASS")
    else:
        push_error("V75249 tactical regression")
    session.multiplayer.multiplayer_peer.close()
    quit(0 if ok else 1)
