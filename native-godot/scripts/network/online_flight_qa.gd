extends SceneTree
const SESSION=preload("res://scripts/network/aurora_online_session.gd")
const PRESENTATION=preload("res://scripts/network/online_presentation.gd")

func _initialize() -> void:
    call_deferred("_verify")

func _air_rival_visible(session: Node,view: Node) -> bool:
    for item in session.state.get("rivals",[]):
        if not bool(item.get("airborne",false)):
            continue
        var id: int=int(item.id)
        if not view.replicas.has(id):
            continue
        var holder: Node3D=view.replicas[id]
        var canopy:=holder.get_node_or_null("RealRivalParachute") as MeshInstance3D
        var animator:=holder.find_child("AnimationPlayer",true,false) as AnimationPlayer
        if canopy!=null and canopy.is_visible_in_tree() and canopy.mesh!=null and animator!=null and animator.current_animation=="AuroraParachute" and holder.find_child("OnlineRivalHandSocket",true,false)==null:
            return true
    return false

func _waiting_rival_visible(session: Node,view: Node) -> bool:
    for item in session.state.get("rivals",[]):
        if not bool(item.get("waiting",false)) or int(item.weapon)!=-1:
            continue
        var id: int=int(item.id)
        if not view.replicas.has(id):
            continue
        var holder: Node3D=view.replicas[id]
        var skeleton:=holder.find_child("Skeleton3D",true,false) as Skeleton3D
        if skeleton!=null and holder.is_visible_in_tree() and holder.find_child("OnlineRivalHandSocket",true,false)==null and holder.get_node_or_null("RealRivalParachute")==null:
            return true
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
    for i in range(120):
        await create_timer(.05).timeout
        if view._has_state and session.state.get("match_mode","")=="waiting":
            break
    if not view._has_state or session.state.get("match_mode","")!="waiting":
        push_error("V75232 missing waiting island")
        quit(1)
        return
    var waiting_start: Vector3=session.state.position
    var time_start: float=float(session.state.waiting_remaining)
    var island_ok: bool=is_instance_valid(view.waiting_visual) and not view.waiting_visual.physical and not view.zone.visible and not view._fire_pad.visible and not view._reload.visible
    view.move_axis=Vector2(0,-1)
    await create_timer(.65).timeout
    view.move_axis=Vector2.ZERO
    var moved: bool=(session.state.position as Vector3).distance_to(waiting_start)>1.0 and bool(session.state.grounded)
    var waiting_reject: int=int(session.state.action_rejected)
    view.request_action(session.ACTION_RELOAD)
    await create_timer(.35).timeout
    var waiting_safe: bool=int(session.state.action_rejected)>waiting_reject and int(session.state.shots)==0 and float(session.state.health)==200.0 and session.state.loot.is_empty()
    var countdown: bool=float(session.state.waiting_remaining)<time_start and float(session.state.waiting_remaining)>0.0
    var roster_ready: bool=false
    var waiting_rival: bool=false
    var bounded: bool=true
    var walking: bool=false
    var displacement_ok: bool=false
    var first_positions: Dictionary={}
    for i in range(400):
        await create_timer(.05).timeout
        if session.state.get("match_mode","")=="waiting":
            roster_ready=roster_ready or (int(session.state.waiting_ready)==50 and int(session.state.bots)==49 and int(session.state.alive)==50)
            waiting_rival=waiting_rival or _waiting_rival_visible(session,view)
            bounded=bounded and session.state.rivals.size()<=8
            for item in session.state.rivals:
                if not bool(item.get("waiting",false)):
                    continue
                var id: int=int(item.id)
                var at: Vector3=item.position
                if not first_positions.has(id):
                    first_positions[id]=at
                elif at.distance_to(first_positions[id])>.65:
                    displacement_ok=true
                if str(item.clip)=="AuroraWalk" and view.replicas.has(id):
                    var holder: Node3D=view.replicas[id]
                    var animator:=holder.find_child("AnimationPlayer",true,false) as AnimationPlayer
                    if animator!=null and animator.current_animation=="AuroraWalk":
                        walking=true
        if view._has_state and session.state.get("air_mode","")=="aircraft":
            break
    var roster_cleared: bool=session.state.rivals.is_empty() and view.replicas.is_empty() and int(session.state.get("waiting_ready",-1))==0
    var roster_ok: bool=roster_ready and waiting_rival and bounded and roster_cleared
    var locomotion_ok: bool=walking and displacement_ok and roster_cleared
    print("V75234_WAITING_WALK clip=",walking," physical_displacement=",displacement_ok," cleared=",roster_cleared)
    print("V75233_ROSTER ready=",roster_ready," unarmed_rival=",waiting_rival," bounded=",bounded," cleared=",roster_cleared)
    var departed: bool=session.state.get("air_mode","")=="aircraft" and not is_instance_valid(view.waiting_visual) and float(session.state.waiting_remaining)==0.0
    var waiting_ok: bool=island_ok and moved and waiting_safe and countdown and departed
    print("V75232_WAITING island=",island_ok," move=",moved," safe=",waiting_safe," countdown=",countdown," departure=",departed)
    if not view._has_state:
        quit(1)
        return
    var start: Vector3=session.state.position
    await create_timer(.65).timeout
    var plane_ok: bool=session.state.get("air_mode","")=="aircraft" and (session.state.position as Vector3).distance_to(start)>2.0 and is_instance_valid(view.flight_visual) and is_instance_valid(view.flight_visual._craft) and not view.flight_visual.is_physics_processing()
    var aircraft_audio: bool=view.sound._aircraft_active
    var rejected: int=int(session.state.action_rejected)
    view.request_action(session.ACTION_RELOAD)
    await create_timer(.3).timeout
    var gated: bool=int(session.state.action_rejected)>rejected and int(session.state.shots)==0
    view.request_action(session.ACTION_JUMP)
    for i in range(80):
        await create_timer(.05).timeout
        if session.state.get("air_mode","")=="freefall":
            break
    var fall_start: float=float(session.state.position.y)
    var rival_ok: bool=false
    for i in range(16):
        await create_timer(.05).timeout
        rival_ok=rival_ok or _air_rival_visible(session,view)
    var audio_stopped: bool=not view.sound._aircraft_active and not view.sound._flight_transition.playing
    var fall_ok: bool=session.state.get("air_mode","")=="freefall" and float(session.state.position.y)<fall_start-1.0 and not is_instance_valid(view.flight_visual)
    view.request_action(session.ACTION_JUMP)
    for i in range(80):
        await create_timer(.05).timeout
        if session.state.get("air_mode","")=="parachute":
            break
    var canopy_ok: bool=session.state.get("air_mode","")=="parachute" and world.operator._parachute_visual!=null and world.operator._parachute_visual.visible
    for i in range(600):
        await create_timer(.05).timeout
        rival_ok=rival_ok or _air_rival_visible(session,view)
        if session.state.get("match_mode","")=="sector_battle" and session.state.get("air_mode","")=="ground":
            break
    await create_timer(.3).timeout
    var landed: bool=session.state.get("match_mode","")=="sector_battle" and session.state.get("air_mode","")=="ground" and bool(session.state.grounded) and int(session.state.bots)==49 and not world.operator._parachute_visual.visible
    var no_sim: bool=world.get_node_or_null("CombatRange")==null and world.get_node_or_null("AuroraSectorMatch")==null and not world.operator.is_physics_processing()
    var ok: bool=plane_ok and gated and fall_ok and canopy_ok and landed and no_sim
    print("V75230_FLIGHT aircraft=",plane_ok," airborne_combat_rejected=",gated," freefall=",fall_ok," canopy=",canopy_ok," landed=",landed," no_sim=",no_sim," state=",session.state.get("air_mode","")," match=",session.state.get("match_mode",""))
    var cleared: bool=true
    for item in session.state.get("rivals",[]):
        if bool(item.get("airborne",false)):
            cleared=false
    for holder in view.replicas.values():
        if holder.get_node_or_null("RealRivalParachute")!=null:
            cleared=false
    var air_ok: bool=rival_ok and aircraft_audio and audio_stopped and cleared
    print("V75231_AIR_VISUAL rival_canopy=",rival_ok," aircraft_audio=",aircraft_audio," audio_stopped=",audio_stopped," cleared=",cleared)
    ok=ok and air_ok and waiting_ok and roster_ok and locomotion_ok
    if ok:
        print("V75230_FLIGHT PASS")
        print("V75231_AIR_VISUAL PASS")
        print("V75232_WAITING PASS")
        print("V75233_ROSTER PASS")
        print("V75234_WAITING_WALK PASS")
    else:
        push_error("V75230 deployment regression")
    session.multiplayer.multiplayer_peer.close()
    quit(0 if ok else 1)
