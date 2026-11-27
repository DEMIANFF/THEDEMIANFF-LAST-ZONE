extends SceneTree
const SESSION=preload("res://scripts/network/aurora_online_session.gd")
const PRESENTATION=preload("res://scripts/network/online_presentation.gd")
const W=preload("res://scripts/combat/aurora_weapon_catalog.gd")
func _initialize() -> void:
    call_deferred("_verify")

func _walk(session: Node,view: Node,kind: String) -> bool:
    var id: int=0
    var target: Vector3=Vector3.ZERO
    for item in session.state.loot:
        if str(item.kind)==kind:
            id=int(item.id)
            target=item.position
            break
    if id==0:
        var index: int=W.pickup_slot(kind)
        if index>=0:
            return session.state.inventory.additions.has(index)
        return int(session.state.smg_reserve)>0 if kind=="ammo_smg" else int(session.state.ar_reserve)>90
    view.operator._desired_yaw=0.0
    await create_timer(.5).timeout
    for i in range(180):
        var found: bool=false
        for item in session.state.loot:
            found=found or int(item.id)==id
        if not found:
            view.move_axis=Vector2.ZERO
            await create_timer(.3).timeout
            return true
        var offset: Vector3=target-session.state.position
        view.move_axis=Vector2(offset.x,offset.z).limit_length(1.0)
        await create_timer(.05).timeout
    view.move_axis=Vector2.ZERO
    return false

func _switch(session: Node,view: Node,weapon: int) -> bool:
    view.request_action(session.ACTION_NEXT_WEAPON)
    await create_timer(.65).timeout
    return int(session.state.weapon)==weapon and int(view.weapon_visuals.selected_weapon)==weapon

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
    var ok: bool=bool(session.state.catalog_room) and int(session.state.participants)==4 and not world.operator.is_physics_processing()
    if slot==0:
        var denied: int=int(session.state.action_rejected)
        view.request_action(session.ACTION_NEXT_WEAPON)
        await create_timer(.5).timeout
        var unowned: bool=int(session.state.weapon)==W.AR and int(session.state.action_rejected)>denied
        var scar: bool=await _walk(session,view,"weapon_scar")
        var mp40: bool=await _walk(session,view,"weapon_mp40")
        var p90: bool=await _walk(session,view,"weapon_p90")
        var smg: bool=await _walk(session,view,"ammo_smg")
        var ar: bool=await _walk(session,view,"ammo_ar")
        var equipped: bool=await _switch(session,view,W.SCAR)
        var ar_shared: bool=int(session.state.reserve)==135 and int(session.state.ammo)==30
        var mp: bool=await _switch(session,view,W.MP40)
        var stock: bool=int(session.state.reserve)==30 and int(session.state.ammo)==15
        view.operator._desired_pitch=.45
        view.firing=true
        await create_timer(.55).timeout
        view.firing=false
        await create_timer(.25).timeout
        var spent: int=15-int(session.state.ammo)
        view.request_action(session.ACTION_RELOAD)
        await create_timer(2.3).timeout
        var reload: bool=spent>0 and int(session.state.ammo)==15 and int(session.state.reserve)==30-spent
        var p: bool=await _switch(session,view,W.P90)
        var shared: bool=int(session.state.ammo)==50 and int(session.state.reserve)==30-spent and session.state.inventory.additions[W.MP40].reserve==session.state.inventory.additions[W.P90].reserve
        var restored: bool=await _switch(session,view,W.AR)
        restored=restored and int(session.state.ammo)==30 and int(session.state.reserve)==135
        ok=ok and unowned and scar and mp40 and p90 and smg and ar and equipped and ar_shared and mp and stock and reload and p and shared and restored
        print("V75248_OWNER unowned=",unowned," scar=",scar," mp40=",mp40," p90=",p90," ar_shared=",ar_shared," reload=",reload," smg_shared=",shared," restored=",restored)
        await create_timer(4.0).timeout
    else:
        var remote_slots: Dictionary={}
        var private_stock: bool=true
        for i in range(640):
            await create_timer(.05).timeout
            private_stock=private_stock and session.state.inventory.additions.is_empty() and int(session.state.reserve)==90
            for item in session.state.rivals:
                if int(item.get("slot",-1))!=0:
                    continue
                var weapon: int=int(item.weapon)
                var holder: Node3D=view.replicas.get(int(item.id))
                if weapon in [W.SCAR,W.MP40,W.P90] and is_instance_valid(holder) and holder.find_child("OnlineRivalWeaponVisual",true,false)!=null:
                    remote_slots[weapon]=true
            if remote_slots.size()==3:
                break
        ok=ok and private_stock and remote_slots.size()==3
        print("V75248_OBSERVER slot=",slot," private=",private_stock," remote_models=",remote_slots.size())
        await create_timer(5.0).timeout
    if ok:
        print("V75248_CATALOG PASS")
    else:
        push_error("V75248 catalog regression")
    session.multiplayer.multiplayer_peer.close()
    quit(0 if ok else 1)
