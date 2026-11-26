extends SceneTree
const SESSION=preload("res://scripts/network/aurora_online_session.gd")
const PRESENTATION=preload("res://scripts/network/online_presentation.gd")
func _initialize() -> void:
    call_deferred("_verify")

# Use the real directional fire control, not a parallel testing trigger.
func _fire_touch(view: Node,down: bool) -> void:
    var touch:=InputEventScreenTouch.new()
    touch.index=7
    touch.position=view._fire_pad.size*.5
    touch.pressed=down
    view._fire_pad._gui_input(touch)

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
        if view._has_state and bool(session.state.get("duel_ready",false)) and session.state.rivals.size()==1 and view.applied_snapshot_id>=int(session.state.snapshot_id):
            break
    if not bool(session.state.get("duel_ready",false)):
        push_error("V75238 missing duel peer")
        quit(1)
        return
    var own_id: int=int(session.state.self_peer)
    var other_id: int=int(session.state.rivals[0].id)
    var attacker: bool=OS.get_environment("AURORA_DUAL_QA_ROLE")=="first"
    var initial: bool=int(session.state.ammo)==30 and float(session.state.health)==200.0 and view._fire_pad.visible
    await create_timer(.65).timeout
    var ok: bool=initial
    if attacker:
        var offset: Vector3=session.state.rivals[0].position-session.state.position
        view.operator._desired_yaw=atan2(-offset.x,-offset.z)
        view.operator._desired_pitch=0.0
        await create_timer(.65).timeout
        _fire_touch(view,true)
        var press_frame: int=view.applied_snapshot_id
        var held_through_snapshots: bool=true
        for i in range(80):
            await create_timer(.05).timeout
            held_through_snapshots=held_through_snapshots and view.firing and view._fire_pad.get_fire_held() and view._fire_pad.visible
            if int(session.state.shots)>=4:
                break
        var burst: bool=held_through_snapshots and view.applied_snapshot_id>=press_frame+2 and int(session.state.shots)>=4
        _fire_touch(view,false)
        await create_timer(.3).timeout
        var spent: int=30-int(session.state.ammo)
        var damaged: bool=int(session.state.hits)>0 and spent==int(session.state.shots) and spent>=4
        var released: bool=not view.firing and not view._fire_pad.get_fire_held()
        view.request_action(session.ACTION_RELOAD)
        var reloading: bool=false
        for i in range(80):
            await create_timer(.05).timeout
            reloading=reloading or float(session.state.reload_remaining)>0.0
            if int(session.state.reloads)>0:
                break
        var restored: bool=reloading and int(session.state.ammo)==30 and int(session.state.reserve)==90-spent and int(session.state.reloads)==1
        _fire_touch(view,true)
        for i in range(240):
            await create_timer(.05).timeout
            if bool(session.state.ended):
                break
        _fire_touch(view,false)
        var won: bool=bool(session.state.ended) and int(session.state.duel_winner)==own_id and int(session.state.kills)==1 and int(session.state.hits)>=8 and session.state.rivals.is_empty()
        print("V75238_FIRE_HOLD sustained=",burst," released=",released," spent=",spent," snapshot_delta=",view.applied_snapshot_id-press_frame)
        print("V75238_ATTACKER damage=",damaged," reload=",restored," won=",won," shots=",session.state.shots," hits=",session.state.hits)
        ok=ok and burst and released and damaged and restored and won
        await create_timer(.45).timeout
        var expected: int=int(session.state.shots)+int(session.state.hits)+1
        var audio_ok: bool=int(view.received_sounds.get("ar_fire",0))==int(session.state.shots) and int(view.received_sounds.get("impact",0))==int(session.state.hits) and int(view.received_sounds.get("reload",0))==1 and int(view.received_sounds.get("hit",0))==0 and int(view.received_sounds.get("duel_remote_shot",0))==0 and session.received_critical_sequence==expected and int(session.state.duel_audio_sent)==expected and session.critical_sound_gaps==0
        var before: Dictionary=view.received_sounds.duplicate()
        view._sync_sounds([session.last_critical_sound])
        var dedup: bool=before==view.received_sounds
        print("V75239_ATTACK_AUDIO local_shots=",view.received_sounds.get("ar_fire",0)," impact=",view.received_sounds.get("impact",0)," reload=",view.received_sounds.get("reload",0)," expected=",expected," received=",session.received_critical_sequence," gaps=",session.critical_sound_gaps," isolated=",audio_ok," dedup=",dedup)
        ok=ok and audio_ok and dedup
        await create_timer(.65).timeout
    else:
        var hurt: bool=false
        for i in range(400):
            await create_timer(.05).timeout
            hurt=hurt or float(session.state.health)<200.0
            if bool(session.state.ended):
                break
        var dead: bool=bool(session.state.eliminated) and float(session.state.health)==0.0 and int(session.state.duel_winner)==other_id
        var denied_before: int=int(session.state.action_rejected)
        session.submit_action.rpc_id(1,session.PROTOCOL,1,session.ACTION_RELOAD)
        await create_timer(.4).timeout
        var denied: bool=dead and int(session.state.action_rejected)>denied_before and int(session.state.shots)==0 and int(session.state.ammo)==30
        print("V75238_TARGET damaged=",hurt," eliminated=",dead," post_elimination_denied=",denied)
        ok=ok and hurt and dead and denied
        var remote_shots: int=int(view.received_sounds.get("duel_remote_shot",0))
        var received_hits: int=int(view.received_sounds.get("hit",0))
        var expected: int=int(session.state.duel_audio_sent)
        var audio_ok: bool=remote_shots>=8 and received_hits==8 and int(view.received_sounds.get("duel_remote_reload",0))==1 and int(view.received_sounds.get("ar_fire",0))==0 and int(view.received_sounds.get("impact",0))==0 and expected==remote_shots+received_hits+1 and session.received_critical_sequence==expected and session.critical_sound_gaps==0
        var before: Dictionary=view.received_sounds.duplicate()
        view._sync_sounds([session.last_critical_sound])
        var dedup: bool=before==view.received_sounds
        print("V75239_TARGET_AUDIO remote_shots=",remote_shots," hit=",received_hits," reload=",view.received_sounds.get("duel_remote_reload",0)," expected=",expected," received=",session.received_critical_sequence," gaps=",session.critical_sound_gaps," isolated=",audio_ok," dedup=",dedup)
        ok=ok and audio_ok and dedup
    if ok:
        print("V75238_DUEL PASS")
        print("V75239_AUDIO PASS")
    else:
        push_error("V75238 duel regression")
    session.multiplayer.multiplayer_peer.close()
    quit(0 if ok else 1)
