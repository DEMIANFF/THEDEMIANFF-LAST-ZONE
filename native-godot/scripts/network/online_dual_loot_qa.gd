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
        if view._has_state and bool(session.state.get("duel_ready",false)) and session.state.loot.size()==3 and view.loot_replicas.size()==3:
            break
    if not view._has_state or session.state.get("loot",[]).size()!=3:
        push_error("V75240 missing shared loot")
        quit(1)
        return
    var visual_only: bool=true
    for item in view.loot_replicas.values():
        visual_only=visual_only and item.presentation_only and not item.monitoring
    var initial: bool=int(session.state.reserve)==90 and int(session.state.inventory.medkits)==0
    var start: Vector3=session.state.position
    var ammo_id: int=0
    var ammo_at: Vector3
    var med_at: Vector3
    var best: float=INF
    for item in session.state.loot:
        if str(item.kind)=="ammo_ar":
            ammo_id=int(item.id)
            ammo_at=item.position
        elif start.distance_squared_to(item.position)<best:
            best=start.distance_squared_to(item.position)
            med_at=item.position
    view.operator._desired_yaw=0.0
    await create_timer(.6).timeout
    for i in range(120):
        var found: bool=false
        for item in session.state.loot:
            found=found or int(item.id)==ammo_id
        if not found:
            break
        var offset: Vector3=ammo_at-session.state.position
        view.move_axis=Vector2(offset.x,offset.z).limit_length(1.0)
        await create_timer(.05).timeout
    view.move_axis=Vector2.ZERO
    await create_timer(.35).timeout
    var ammo_removed: bool=not view.loot_replicas.has(ammo_id) and int(session.state.duel_world_claims)>=1
    var own_reserve: int=int(session.state.reserve)
    for i in range(180):
        if int(session.state.inventory.medkits)==1:
            break
        var offset: Vector3=med_at-session.state.position
        view.move_axis=Vector2(offset.x,offset.z).limit_length(1.0)
        await create_timer(.05).timeout
    view.move_axis=Vector2.ZERO
    for i in range(160):
        await create_timer(.05).timeout
        if int(session.state.duel_world_claims)==3 and view.loot_replicas.is_empty():
            break
    var private_inventory: bool=int(session.state.inventory.medkits)==1 and own_reserve in [90,135] and int(session.state.reserve)==own_reserve and int(session.state.duel_loot_claims)==(2 if own_reserve==135 else 1)
    var all_removed: bool=int(session.state.duel_world_claims)==3 and session.state.loot.is_empty() and view.loot_replicas.is_empty()
    var rejected: int=int(session.state.action_rejected)
    view.request_action(session.ACTION_HEAL)
    await create_timer(.4).timeout
    var full_hp_denied: bool=int(session.state.action_rejected)>rejected and int(session.state.inventory.medkits)==1 and float(session.state.health)==200.0
    var ok: bool=initial and visual_only and ammo_removed and private_inventory and all_removed and full_hp_denied
    print("V75240_LOOT initial=",initial," visual_only=",visual_only," ammo_removed=",ammo_removed," private_inventory=",private_inventory," reserve=",own_reserve," all_removed=",all_removed," full_hp_heal_denied=",full_hp_denied)
    if ok:
        print("V75240_LOOT PASS")
    else:
        push_error("V75240 shared loot regression")
    # Both real clients completed the original loot assertions. One fires
    # a short actual burst, the other cancels then completes medical use.
    var attacker: bool=OS.get_environment("AURORA_DUAL_QA_ROLE")=="first"
    var medical_ok: bool=false
    if attacker:
        await create_timer(1.0).timeout
        if not session.state.rivals.is_empty():
            var toward: Vector3=session.state.rivals[0].position-session.state.position
            view.operator._desired_yaw=atan2(-toward.x,-toward.z)
            view.operator._desired_pitch=0.0
            await create_timer(.65).timeout
            view.firing=true
            for i in range(90):
                await create_timer(.05).timeout
                if int(session.state.hits)>=1:
                    break
            view.firing=false
        var hurt_other: bool=int(session.state.hits)>=1
        var saw_medical: bool=false
        var medical_edges: int=0
        var prior: bool=false
        for i in range(300):
            await create_timer(.05).timeout
            if session.state.rivals.is_empty():
                break
            var active: bool=bool(session.state.rivals[0].get("medical",false))
            if active and not prior:
                medical_edges+=1
            saw_medical=saw_medical or active
            prior=active
            if medical_edges>=2 and not active:
                break
        medical_ok=hurt_other and saw_medical and medical_edges>=2 and not prior and float(session.state.health)==200.0 and int(session.state.inventory.medkits)==1 and int(session.state.heal_completed)==0 and int(view.received_sounds.get("heal",0))==0 and int(session.state.reserve)==own_reserve
        print("V75241_OBSERVER damage=",hurt_other," medical_edges=",medical_edges," isolated=",medical_ok)
        await create_timer(1.0).timeout
    else:
        for i in range(180):
            await create_timer(.05).timeout
            if float(session.state.health)<200.0:
                break
        await create_timer(.8).timeout
        var hp: float=float(session.state.health)
        var injured: bool=hp>0.0 and hp<200.0 and int(session.state.inventory.medkits)==1
        view.request_action(session.ACTION_HEAL)
        var first_started: bool=false
        for i in range(60):
            await create_timer(.05).timeout
            if float(session.state.heal_remaining)>0.0:
                first_started=true
                break
        await create_timer(.35).timeout
        var no_early_grant: bool=float(session.state.health)==hp and int(session.state.inventory.medkits)==1
        view.move_axis=Vector2(0,-1)
        await create_timer(.4).timeout
        view.move_axis=Vector2.ZERO
        await create_timer(.7).timeout
        var cancelled: bool=int(session.state.heal_cancelled)==1 and float(session.state.heal_remaining)==0.0 and float(session.state.health)==hp and int(session.state.inventory.medkits)==1
        view.request_action(session.ACTION_HEAL)
        var second_started: bool=false
        var start_ms: int=Time.get_ticks_msec()
        for i in range(60):
            await create_timer(.05).timeout
            if float(session.state.heal_remaining)>0.0:
                second_started=true
                break
        var denied_before: int=int(session.state.action_rejected)
        view.request_action(session.ACTION_HEAL)
        await create_timer(.4).timeout
        var duplicate_denied: bool=int(session.state.action_rejected)>denied_before and int(session.state.inventory.medkits)==1
        for i in range(100):
            await create_timer(.05).timeout
            if int(session.state.heal_completed)==1:
                break
        await create_timer(.35).timeout
        var expected_hp: float=minf(200.0,hp+45.0)
        var completed: bool=int(session.state.heal_completed)==1 and int(session.state.inventory.medkits)==0 and is_equal_approx(float(session.state.health),expected_hp) and is_equal_approx(float(session.state.heal_gained),expected_hp-hp) and Time.get_ticks_msec()-start_ms>=2600 and int(view.received_sounds.get("heal",0))==1
        medical_ok=injured and first_started and no_early_grant and cancelled and second_started and duplicate_denied and completed
        print("V75241_MEDICAL injured=",injured," first_started=",first_started," no_early_grant=",no_early_grant," cancelled=",cancelled," second_started=",second_started," duplicate_denied=",duplicate_denied," completed=",completed," before=",hp," after=",session.state.health," medkits=",session.state.inventory.medkits)
        await create_timer(1.0).timeout
    ok=ok and medical_ok
    if ok:
        print("V75241_HEAL PASS")
    else:
        push_error("V75241 medical channel regression")
    session.multiplayer.multiplayer_peer.close()
    quit(0 if ok else 1)
