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
    for i in range(600):
        await create_timer(.05).timeout
        if view._has_state and bool(session.state.get("mixed_ready",false)):
            break
    if not bool(session.state.get("mixed_ready",false)):
        push_error("V75244 missing mixed roster")
        quit(1)
        return
    var roster: bool=int(session.state.participants)==50 and int(session.state.human_count)==4 and int(session.state.bot_roster)==46 and int(session.state.alive)<=50
    var slot: int=int(session.state.room_slot)
    if slot==1:
        view.operator._desired_yaw=float(session.state.body_yaw)
        view.operator._desired_pitch=0.0
    var seen_bot: bool=false
    var bounded: bool=true
    var original: bool=false
    var real_motion: bool=false
    var local_before: Vector3=session.state.position
    var start: int=Time.get_ticks_msec()
    var aim_target: int=0
    var aim_since: int=0
    var search_yaw: float=float(session.state.body_yaw)
    for i in range(400):
        await create_timer(.05).timeout
        bounded=bounded and session.state.rivals.size()<=8 and int(session.state.alive)<=50
        if slot==1 and not bool(session.state.eliminated):
            var closest: Dictionary={}
            var distance: float=INF
            for rival in session.state.rivals:
                if not bool(rival.get("human",false)):
                    var d: float=(session.state.position as Vector3).distance_squared_to(rival.position)
                    if d<distance:
                        distance=d
                        closest=rival
                    seen_bot=true
                    var holder: Node3D=view.replicas.get(int(rival.id))
                    if is_instance_valid(holder) and holder.find_child("Skeleton3D",true,false)!=null:
                        original=true
            if not closest.is_empty() and int(session.state.own_bot_hits)==0:
                var offset: Vector3=closest.position-session.state.position
                var heading: float=atan2(-offset.x,-offset.z)
                view.operator._desired_yaw=heading
                view.operator._desired_pitch=clampf(atan2(offset.y-.25,Vector2(offset.x,offset.z).length()),-.55,.62)
                if aim_target!=int(closest.id):
                    aim_target=int(closest.id)
                    aim_since=Time.get_ticks_msec()
                view.firing=Time.get_ticks_msec()-aim_since>=250
                search_yaw=heading
            else:
                view.firing=false
                if int(session.state.own_bot_hits)==0:
                    # A real camera sweep, never an invisible target ID
                    # or a server-side hit grant.
                    search_yaw=wrapf(search_yaw+.09,-PI,PI)
                    view.operator._desired_yaw=search_yaw
                    view.operator._desired_pitch=0.0
                    aim_target=0
        if slot!=1 and i<30:
            view.move_axis=Vector2(0,-1)
        else:
            view.move_axis=Vector2.ZERO
        real_motion=real_motion or (session.state.position as Vector3).distance_to(local_before)>1.0
        if Time.get_ticks_msec()-start>8000 and int(session.state.bot_damage_events)>0 and int(session.state.human_bot_hits)>0:
            break
    view.firing=false
    view.move_axis=Vector2.ZERO
    var cache_budget: bool=int(session.state.death_active)<=12 and int(session.state.death_peak)<=12 and int(session.state.bot_death_spawned)>0
    var combat: bool=int(session.state.bot_shots)>0 and int(session.state.bot_damage_events)>0 and int(session.state.human_bot_hits)>0
    var identity: bool=int(session.state.self_peer)==session.multiplayer.get_unique_id()
    var own: bool=seen_bot and original and int(session.state.own_bot_hits)>0 if slot==1 else real_motion or bool(session.state.eliminated)
    var ok: bool=roster and identity and bounded and combat and own and cache_budget and not world.operator.is_physics_processing()
    print("V75245_CACHE_BUDGET active=",session.state.death_active," peak=",session.state.death_peak," bot_drops=",session.state.bot_death_spawned," valid=",cache_budget)
    print("V75244_MIXED slot=",slot," roster=",roster," bounded=",bounded," combat=",combat," own=",own," bots=",session.state.bots," bot_shots=",session.state.bot_shots," damage_events=",session.state.bot_damage_events," human_hits=",session.state.human_bot_hits," seen_bot=",seen_bot," original=",original," own_shots=",session.state.shots," hp=",session.state.health)
    # Slot 1 is a real secondary operator, not the retained primary body.
    # Make its disconnect happen while the other clients and AI keep running.
    # The server must clean every AI reference, not merely avoid a crash at quit.
    if slot==1:
        await create_timer(1.0).timeout
    else:
        var removed: bool=false
        var continued: bool=false
        var after_leave: int=0
        for i in range(180):
            await create_timer(.05).timeout
            if int(session.state.human_count)==3:
                if not removed:
                    removed=true
                    after_leave=int(session.state.snapshot_id)
                continued=continued or int(session.state.snapshot_id)>after_leave+10
            if removed and continued:
                break
        ok=ok and removed and continued
        print("V75245_LIVE_DISCONNECT slot=",slot," removed=",removed," continued=",continued)
        # Keep all observers connected until each has observed the cleanup.
        await create_timer(2.5).timeout
    if ok:
        print("V75244_MIXED PASS")
    else:
        push_error("V75244 mixed roster regression")
    session.multiplayer.multiplayer_peer.close()
    quit(0 if ok else 1)
