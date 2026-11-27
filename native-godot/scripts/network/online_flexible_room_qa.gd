extends SceneTree
const SESSION=preload("res://scripts/network/aurora_online_session.gd")
const PRESENTATION=preload("res://scripts/network/online_presentation.gd")
func _initialize() -> void:
    call_deferred("_verify")
func _verify() -> void:
    if OS.get_environment("AURORA_FLEX_LATE")=="1":
        var late:=SESSION.new()
        late.name="AuroraOnline"
        root.add_child(late)
        if late.connect_local()!=OK:
            quit(1)
            return
        await create_timer(3.0).timeout
        var transport: MultiplayerPeer=late.multiplayer.multiplayer_peer
        var ok: bool=(transport==null or transport.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED) and late.state.is_empty()
        print("V75250_LATE ", "PASS" if ok else "FAIL")
        quit(0 if ok else 1)
        return
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
    var queued: bool=false
    var roster: bool=false
    var aircraft: bool=false
    var freefall: bool=false
    var canopy: bool=false
    var landed: bool=false
    var completed: bool=false
    var jump_sent: bool=false
    var chute_sent: bool=false
    for i in range(1450):
        await create_timer(.05).timeout
        if not view._has_state:
            continue
        var data: Dictionary=session.state
        queued=queued or (bool(data.get("room_flexible",false)) and not bool(data.get("room_sealed",false)) and float(data.get("room_join_remaining",0.0))>0.0 and int(data.get("human_count",0))<=2 and not view._fire_pad.visible)
        if bool(data.get("mixed_ready",false)):
            roster=roster or (int(data.participants)==50 and int(data.bot_roster)==48 and int(data.room_initial_humans)==2 and int(data.human_count)==2)
        var air: String=str(data.air_mode)
        if air=="aircraft":
            aircraft=aircraft or is_instance_valid(view.flight_visual)
            if not jump_sent and float(data.flight_elapsed)>2.0+float(data.room_slot)*2.0:
                view.request_action(session.ACTION_JUMP)
                jump_sent=true
        elif air=="freefall":
            freefall=true
            if not chute_sent:
                view.request_action(session.ACTION_JUMP)
                chute_sent=true
        elif air=="parachute":
            canopy=true
        landed=landed or bool(data.get("flight_landed",false))
        if bool(data.get("deployment_complete",false)):
            completed=int(data.flight_landed_bots)==48 and int(data.participants)==50
            break
    var ok: bool=queued and roster and aircraft and freefall and canopy and landed and completed and not world.operator.is_physics_processing()
    print("V75250_FLEX slot=",session.state.get("room_slot",-1)," queued=",queued," roster=",roster," aircraft=",aircraft," fall=",freefall," canopy=",canopy," landed=",landed," complete=",completed)
    print("V75250_FLEX ", "PASS" if ok else "FAIL")
    await create_timer(2.5).timeout
    session.multiplayer.multiplayer_peer.close()
    quit(0 if ok else 1)
