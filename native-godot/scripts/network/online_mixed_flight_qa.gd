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
        push_error("V75246 no mixed waiting roster")
        quit(1)
        return
    var slot: int=int(session.state.room_slot)
    await create_timer(.3).timeout
    var waiting: bool=session.state.match_mode=="waiting" and int(session.state.waiting_ready)==50 and int(session.state.bot_roster)==46 and is_instance_valid(view.waiting_visual) and not view._fire_pad.visible and session.state.loot.is_empty()
    var start: Vector3=session.state.position
    view.move_axis=Vector2(0,-1)
    await create_timer(.65).timeout
    view.move_axis=Vector2.ZERO
    var moved: bool=(session.state.position as Vector3).distance_to(start)>.7
    var rejected_before: int=int(session.state.action_rejected)
    view.request_action(session.ACTION_RELOAD)
    await create_timer(.4).timeout
    var denied: bool=int(session.state.action_rejected)>rejected_before and int(session.state.shots)==0
    var aircraft: bool=false
    var fall: bool=false
    var canopy: bool=false
    var landed: bool=false
    var ground: bool=false
    var jump_sent: bool=false
    var canopy_sent: bool=false
    var flight_start: Vector3=Vector3.ZERO
    var route_moved: bool=false
    var early_fire: bool=false
    var early_pickup: bool=false
    var cache_id: int=0
    var cache_at: Vector3=Vector3.ZERO
    var cache_visible: bool=false
    var landed_health: bool=true
    var start_clock: int=Time.get_ticks_msec()
    for i in range(1250):
        await create_timer(.05).timeout
        if not view._has_state:
            continue
        var mode: String=str(session.state.air_mode)
        if mode=="aircraft":
            if not aircraft:
                flight_start=session.state.position
            aircraft=aircraft or is_instance_valid(view.flight_visual)
            route_moved=route_moved or (session.state.position as Vector3).distance_to(flight_start)>2.0
            if not jump_sent and float(session.state.flight_elapsed)>2.0+float(slot)*2.7 and aircraft:
                view.request_action(session.ACTION_JUMP)
                jump_sent=true
        elif mode=="freefall":
            fall=fall or bool(session.state.flight_jumped)
            if not canopy_sent and fall:
                view.request_action(session.ACTION_JUMP)
                canopy_sent=true
        elif mode=="parachute":
            canopy=canopy or (bool(session.state.flight_canopy) and view.operator._parachute_visual.visible)
        if session.state.match_mode=="aircraft":
            denied=denied and not view._fire_pad.visible and int(session.state.shots)==0 and session.state.loot.is_empty()
            landed_health=landed_health and float(session.state.health)==200.0
        landed=landed or (bool(session.state.flight_landed) and mode=="ground")
        if slot==0 and landed and not bool(session.state.get("deployment_complete",false)) and bool(session.state.duel_ready):
            if int(session.state.shots)==0:
                view.operator._desired_yaw=0.0
                view.operator._desired_pitch=.35
                view.firing=true
            else:
                view.firing=false
                early_fire=early_fire or (int(session.state.early_ground_shots)>0 and int(session.state.ammo)<30 and view._fire_pad.visible)
            if cache_id==0:
                var nearest: float=INF
                for item in session.state.loot:
                    if str(item.kind)!="ammo_ar" or bool(item.from_opponent) or int(item.quantity)!=45:
                        continue
                    var distance: float=(session.state.position as Vector3).distance_squared_to(item.position)
                    if distance<nearest:
                        cache_id=int(item.id)
                        cache_at=item.position
                        nearest=distance
            if cache_id!=0 and int(session.state.reserve)==90:
                cache_visible=cache_visible or view.loot_replicas.has(cache_id)
                view.operator._desired_yaw=0.0
                var offset: Vector3=cache_at-session.state.position
                view.move_axis=Vector2(offset.x,offset.z).limit_length(1.0)
            elif int(session.state.reserve)>90:
                view.move_axis=Vector2.ZERO
                early_pickup=early_pickup or (cache_visible and int(session.state.early_ground_claims)>0)
        if bool(session.state.get("deployment_complete",false)):
            view.firing=false
            view.move_axis=Vector2.ZERO
            await create_timer(.25).timeout
            ground=int(session.state.flight_landed_bots)==46 and int(session.state.participants)==50 and view.zone.visible and not is_instance_valid(view.waiting_visual) and not is_instance_valid(view.flight_visual) and not view.operator._parachute_visual.visible
            break
        if Time.get_ticks_msec()-start_clock>70000:
            break
    var early_ok: bool=early_fire and early_pickup if slot==0 else int(session.state.early_ground_shots)>0 and int(session.state.early_ground_claims)>0
    var ok: bool=waiting and moved and denied and aircraft and route_moved and fall and canopy and landed and ground and landed_health and early_ok and not world.operator.is_physics_processing()
    print("V75247_INDIVIDUAL slot=",slot," early_fire=",early_fire," early_pickup=",early_pickup," air_safe=",landed_health," shared_early=",early_ok)
    print("V75246_FLIGHT slot=",slot," waiting=",waiting," moved=",moved," denied=",denied," aircraft=",aircraft," route=",route_moved," fall=",fall," canopy=",canopy," landed=",landed," ground=",ground," bots_landed=",session.state.get("flight_landed_bots",0))
    if ok:
        print("V75246_FLIGHT PASS")
    else:
        push_error("V75246 mixed flight regression")
    await create_timer(2.0).timeout
    session.multiplayer.multiplayer_peer.close()
    quit(0 if ok else 1)
