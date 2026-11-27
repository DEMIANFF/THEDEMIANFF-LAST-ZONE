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
        push_error("V75245 missing mixed roster")
        quit(1)
        return
    var slot: int=int(session.state.room_slot)
    if slot==1:
        view.operator._desired_yaw=float(session.state.body_yaw)
        view.operator._desired_pitch=0.0
    var search_yaw: float=float(session.state.body_yaw)
    var initial_reserve: int=int(session.state.reserve)
    var budget: bool=true
    var killed: bool=false
    var cache_seen: bool=false
    var visual_only: bool=false
    var cache_id: int=0
    var quantity: int=0
    var cache_pos: Vector3=Vector3.ZERO
    for i in range(440):
        await create_timer(.05).timeout
        budget=budget and int(session.state.death_active)<=12 and int(session.state.death_peak)<=12
        if slot==1 and not bool(session.state.eliminated):
            killed=killed or int(session.state.kills)>0
            if not killed:
                var closest: Dictionary={}
                var distance: float=INF
                for rival in session.state.rivals:
                    if not bool(rival.get("human",false)):
                        var d: float=(session.state.position as Vector3).distance_squared_to(rival.position)
                        if d<distance:
                            distance=d
                            closest=rival
                if not closest.is_empty():
                    var offset: Vector3=closest.position-session.state.position
                    view.operator._desired_yaw=atan2(-offset.x,-offset.z)
                    view.operator._desired_pitch=clampf(atan2(offset.y-.25,Vector2(offset.x,offset.z).length()),-.55,.62)
                    view.firing=true
                    search_yaw=view.operator._desired_yaw
                else:
                    view.firing=false
                    search_yaw=wrapf(search_yaw+.09,-PI,PI)
                    view.operator._desired_yaw=search_yaw
                    view.operator._desired_pitch=0.0
            else:
                view.firing=false
                if cache_id==0:
                    for item in session.state.loot:
                        if bool(item.get("from_ai",false)) and str(item.kind)=="ammo_ar":
                            cache_id=int(item.id)
                            quantity=int(item.quantity)
                            cache_pos=item.position
                            break
                if cache_id!=0:
                    var holder: Area3D=view.loot_replicas.get(cache_id)
                    if is_instance_valid(holder):
                        cache_seen=true
                        visual_only=visual_only or (holder.presentation_only and not holder.monitoring and holder.global_position.distance_to(cache_pos)<.1)
                    view.operator._desired_yaw=0.0
                    var offset: Vector3=cache_pos-session.state.position
                    view.move_axis=Vector2(offset.x,offset.z).limit_length(1.0)
                    if int(session.state.own_bot_loot_rounds)>0:
                        view.move_axis=Vector2.ZERO
        if int(session.state.bot_death_claims)>0 and i>100:
            break
    view.firing=false
    view.move_axis=Vector2.ZERO
    await create_timer(.5).timeout
    var observed: bool=int(session.state.bot_death_spawned)>0 and int(session.state.bot_death_claims)>0
    var recovered: bool=killed and cache_seen and visual_only and quantity>0 and quantity<=18 and int(session.state.own_bot_loot_rounds)>0 and int(session.state.reserve)>=initial_reserve+int(session.state.own_bot_loot_rounds) and not view.loot_replicas.has(cache_id)
    var private_stock: bool=int(session.state.own_bot_loot_claims)==0
    var ok: bool=budget and observed and (recovered if slot==1 else private_stock)
    print("V75245_BOT_LOOT slot=",slot," budget=",budget," observed=",observed," killed=",killed," cache_seen=",cache_seen," visual_only=",visual_only," recovered=",recovered," private=",private_stock," own_rounds=",session.state.own_bot_loot_rounds)
    if ok:
        print("V75245_BOT_LOOT PASS")
    else:
        push_error("V75245 mixed loot regression")
    await create_timer(3.0).timeout
    session.multiplayer.multiplayer_peer.close()
    quit(0 if ok else 1)
