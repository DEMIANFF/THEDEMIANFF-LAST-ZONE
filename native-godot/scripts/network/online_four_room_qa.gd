extends SceneTree
const SESSION=preload("res://scripts/network/aurora_online_session.gd")
const PRESENTATION=preload("res://scripts/network/online_presentation.gd")

func _initialize() -> void:
    call_deferred("_verify")

func _rival(session: Node,slot: int) -> Dictionary:
    for item in session.state.get("rivals",[]):
        if int(item.get("slot",-1))==slot:
            return item
    return {}

func _walk_loot(session: Node,view: Node,kind: String,death: bool=false) -> bool:
    var id: int=0
    var target: Vector3=Vector3.ZERO
    for item in session.state.loot:
        if str(item.kind)==kind and bool(item.from_opponent)==death:
            id=int(item.id)
            target=item.position
            break
    if id==0:
        return false
    view.operator._desired_yaw=0.0
    await create_timer(.6).timeout
    var collected: bool=false
    for i in range(220):
        var present: bool=false
        for item in session.state.loot:
            present=present or int(item.id)==id
        if not present:
            collected=true
            break
        var offset: Vector3=target-session.state.position
        view.move_axis=Vector2(offset.x,offset.z).limit_length(1.0)
        await create_timer(.05).timeout
    view.move_axis=Vector2.ZERO
    await create_timer(.5).timeout
    return collected

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
        if view._has_state and bool(session.state.get("duel_ready",false)) and int(session.state.participants)==4 and session.state.rivals.size()==3:
            break
    if not bool(session.state.get("duel_ready",false)) or int(session.state.get("participants",0))!=4:
        push_error("V75242 missing four-client room")
        quit(1)
        return
    var slot: int=int(session.state.room_slot)
    var own_id: int=int(session.state.self_peer)
    var identity: bool=own_id==session.multiplayer.get_unique_id()
    var peers: Dictionary={}
    for item in session.state.rivals:
        peers[int(item.id)]=true
    var roster: bool=peers.size()==3 and not peers.has(own_id) and int(session.state.alive)==4
    var ok: bool=identity and roster and not world.operator.is_physics_processing()
    if slot==0:
        var awm: bool=await _walk_loot(session,view,"weapon_awm")
        var ammo: bool=await _walk_loot(session,view,"ammo_awm")
        var backpack: bool=await _walk_loot(session,view,"backpack")
        var owned: bool=awm and ammo and backpack and bool(session.state.inventory.awm_owned) and int(session.state.backpack)==1
        view.request_action(session.ACTION_NEXT_WEAPON)
        await create_timer(.4).timeout
        var equipped: bool=int(session.state.weapon)==1 and int(session.state.ammo)==5 and int(session.state.reserve)==8
        view.request_action(session.ACTION_AIM)
        await create_timer(.4).timeout
        var scoped: bool=bool(session.state.aim) and float(session.state.zoom)==4.0
        var target_ready: bool=false
        for i in range(260):
            await create_timer(.05).timeout
            var target: Dictionary=_rival(session,1)
            if not target.is_empty() and int(target.vest_level)==2 and int(target.helmet_level)==2:
                target_ready=true
                break
        await create_timer(.8).timeout
        var target_id: int=int(_rival(session,1).get("id",0))
        for i in range(260):
            var target: Dictionary=_rival(session,1)
            if target.is_empty():
                break
            var offset: Vector3=target.position-session.state.position
            view.operator._desired_yaw=atan2(-offset.x,-offset.z)
            view.operator._desired_pitch=0.0
            view.firing=true
            await create_timer(.05).timeout
            if int(session.state.kills)>0:
                break
        view.firing=false
        await create_timer(.6).timeout
        var kill: bool=int(session.state.kills)==1 and int(session.state.alive)==3 and not bool(session.state.ended) and not view.replicas.has(target_id)
        var death_visible: bool=false
        for item in session.state.loot:
            death_visible=death_visible or bool(item.from_opponent)
        view.request_action(session.ACTION_NEXT_WEAPON)
        await create_timer(.4).timeout
        var ar_restored: bool=int(session.state.weapon)==0 and int(session.state.ammo)==30 and int(session.state.reserve)==90
        var recovered: bool=await _walk_loot(session,view,"ammo_ar",true)
        var death_claim: bool=recovered and int(session.state.death_claims)>=1 and int(session.state.reserve)==108
        print("V75242_ATTACKER owned=",owned," equipped=",equipped," scoped=",scoped," target_ready=",target_ready," kill=",kill," death_visible=",death_visible," ar_restored=",ar_restored," death_claim=",death_claim)
        ok=ok and owned and equipped and scoped and target_ready and kill and death_visible and ar_restored and death_claim
    elif slot==1:
        var med: bool=await _walk_loot(session,view,"medkit")
        var helmet: bool=await _walk_loot(session,view,"helmet_2")
        var vest: bool=await _walk_loot(session,view,"vest_2")
        var gear: bool=med and helmet and vest and int(session.state.vest_level)==2 and int(session.state.helmet_level)==2 and int(session.state.inventory.medkits)==1
        var absorbed: bool=false
        for i in range(600):
            await create_timer(.05).timeout
            absorbed=absorbed or (float(session.state.armor)<50.0 and float(session.state.health)>0.0)
            if bool(session.state.eliminated):
                break
        var eliminated: bool=bool(session.state.eliminated) and float(session.state.health)==0.0 and not bool(session.state.ended) and int(session.state.alive)==3
        for i in range(280):
            await create_timer(.05).timeout
            if int(session.state.death_claims)>=1:
                break
        print("V75242_TARGET gear=",gear," absorbed=",absorbed," eliminated=",eliminated," death_claims=",session.state.death_claims)
        ok=ok and gear and absorbed and eliminated and int(session.state.death_claims)>=1
    else:
        # Two independent surviving peers verify the match does not end at
        # the first elimination, and no victim's inventory is granted to them.
        for i in range(850):
            await create_timer(.05).timeout
            if int(session.state.death_claims)>=1:
                break
        var survivors: bool=int(session.state.alive)==3 and not bool(session.state.ended) and int(session.state.death_claims)>=1
        var isolated: bool=int(session.state.reserve)==90 and int(session.state.inventory.medkits)==0 and not bool(session.state.inventory.awm_owned) and float(session.state.health)==200.0
        print("V75242_SURVIVOR slot=",slot," survives=",survivors," private_inventory=",isolated)
        ok=ok and survivors and isolated
    if ok:
        print("V75242_FOUR PASS slot=",slot)
    else:
        push_error("V75242 integrated room regression slot="+str(slot))
    await create_timer(2.0).timeout
    session.multiplayer.multiplayer_peer.close()
    quit(0 if ok else 1)
