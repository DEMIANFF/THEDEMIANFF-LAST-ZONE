extends Node
## Internal ENet development transport. One human operator, 49 server bots.
## Loopback only until authenticated admission and a production endpoint exist.
const PORT: int=24621
const PROTOCOL: int=5
const ACTION_GRENADE: int=9
const ACTION_COVER: int=10
const TACTICAL_RANGE: float=40.0
const ACTION_NEXT_WEAPON: int=5
const ACTION_HEAL: int=6
const ACTION_SYRINGE: int=7
const ACTION_AIM: int=8
const LOOT_RANGE: float=35.0
const MAX_LOOT_SNAPSHOT: int=16
const ACTION_JUMP: int=1
const ACTION_RELOAD: int=2
const ACTION_CROUCH: int=3
const ACTION_STAND: int=4
const ACTION_MIN_INTERVAL_MS: int=180
const INPUT_TIMEOUT_MS: int=500
var world: Node3D
var operator: CharacterBody3D
var combat: Node3D
var director: Node3D
var remote_id: int=0
var last_sequence: int=0
var rejected: int=0
var accepted: int=0
var last_input_ms: int=0
var axis: Vector2=Vector2.ZERO
var yaw: float=0.0
var pitch: float=-.14
var sprint: bool=false
var fire: bool=false
var previous_fire: bool=false
var action_ack: int=0
var action_rejected: int=0
var action_applied: int=0
var _action_queue: Array[int]=[]
var _last_action_ms: Dictionary={}
var state: Dictionary={}
var _send_clock: float=0.0
var grenade_blasts: int=0
var last_blast_position: Vector3=Vector3.ZERO
var last_blast_ms: int=-10000

func listen(port: int=PORT) -> Error:
    var peer:=ENetMultiplayerPeer.new()
    peer.set_bind_ip("127.0.0.1")
    var result: Error=peer.create_server(port,1,2)
    if result!=OK:
        return result
    multiplayer.multiplayer_peer=peer
    multiplayer.peer_connected.connect(_joined)
    multiplayer.peer_disconnected.connect(_left)
    return OK

func connect_local(port: int=PORT) -> Error:
    var peer:=ENetMultiplayerPeer.new()
    var result: Error=peer.create_client("127.0.0.1",port,2)
    if result==OK:
        multiplayer.multiplayer_peer=peer
    return result

func _joined(id: int) -> void:
    if remote_id!=0 or not is_instance_valid(world):
        multiplayer.multiplayer_peer.disconnect_peer(id)
        return
    remote_id=id
    last_sequence=0
    accepted=0
    rejected=0
    last_input_ms=0
    action_ack=0
    action_rejected=0
    action_applied=0
    _action_queue.clear()
    _last_action_ms.clear()
    grenade_blasts=0
    last_blast_ms=-10000
    if not combat.grenade_detonated.is_connected(_on_server_blast):
        combat.grenade_detonated.connect(_on_server_blast)
    combat.set_encounter_size(50)
    director.start_sector_battle()
    if director.mode!="sector_battle" or combat.active_fighter_count()!=50:
        push_error("AURORA_ONLINE authoritative match failed to start")
        multiplayer.multiplayer_peer.disconnect_peer(id)
        return
    # A real extra physical pickup only in the isolated CI test room.
    # Never grant the weapon directly or enable this from a remote packet.
    if OS.get_environment("AURORA_ONLINE_QA_FIXTURE")=="1":
        var at:=Vector2(operator.global_position.x,operator.global_position.z-3.2)
        director._make_pickup(at,"weapon_awm","OnlineQAPhysicalAWM")
        director._make_pickup(at,"grenade","OnlineQAPhysicalGrenade")
    print("AURORA_ONLINE MATCH peer=",id," participants=",combat.active_fighter_count())

func _left(id: int) -> void:
    if id==remote_id:
        _stop_input()
        remote_id=0
        # A dedicated development room is single-use. Never allow a second
        # connection to inherit the previous player's in-progress match.
        get_tree().quit()

func _stop_input() -> void:
    axis=Vector2.ZERO
    sprint=false
    fire=false
    if is_instance_valid(operator):
        operator.set_touch_move_axis(Vector2.ZERO)
        operator.set_touch_run(false)
    if is_instance_valid(combat):
        combat._on_fire_released()
    previous_fire=false
    _action_queue.clear()

@rpc("any_peer","call_remote","unreliable_ordered",1)
func submit_input(version: int,sequence: int,move: Vector2,heading: float,look_pitch: float,run: bool,shoot: bool) -> void:
    if not multiplayer.is_server() or multiplayer.get_remote_sender_id()!=remote_id or remote_id==0:
        return
    # Clients send intent only, never positions, damage, inventory or kills.
    # Reject stale or unreasonable data before touching the authoritative actor.
    if version!=PROTOCOL or sequence<=last_sequence or sequence-last_sequence>256 or not move.is_finite() or move.length_squared()>1.001 or not is_finite(heading) or absf(heading)>PI or not is_finite(look_pitch) or look_pitch<-.55 or look_pitch>.62:
        rejected+=1
        return
    last_sequence=sequence
    accepted+=1
    last_input_ms=Time.get_ticks_msec()
    axis=move
    yaw=heading
    pitch=look_pitch
    sprint=run
    fire=shoot

# Reliable, ordered one-shot intent is separate from continuous movement.
# Monotonic IDs prevent repeated execution; no client-supplied ammo or HP.
@rpc("any_peer","call_remote","reliable",0)
func submit_action(version: int,request_id: int,action: int) -> void:
    if not multiplayer.is_server() or remote_id==0 or multiplayer.get_remote_sender_id()!=remote_id:
        return
    if version!=PROTOCOL or request_id<=action_ack or request_id-action_ack>256:
        action_rejected+=1
        return
    action_ack=request_id
    if action<ACTION_JUMP or action>ACTION_COVER or director.match_ended or not operator.can_act():
        action_rejected+=1
        return
    var now: int=Time.get_ticks_msec()
    if now-last_input_ms>INPUT_TIMEOUT_MS or _action_queue.size()>=4 or now-int(_last_action_ms.get(action,-1000))<ACTION_MIN_INTERVAL_MS:
        action_rejected+=1
        return
    _last_action_ms[action]=now
    _action_queue.append(action)

func _apply_actions() -> void:
    for action in _action_queue:
        if not operator.can_act():
            action_rejected+=1
            continue
        match action:
            ACTION_JUMP:
                operator.touch_jump()
            ACTION_RELOAD:
                combat._on_reload()
            ACTION_CROUCH:
                operator.set_crouch(true)
            ACTION_STAND:
                operator.set_crouch(false)
            ACTION_NEXT_WEAPON:
                combat._on_weapon()
            ACTION_HEAL:
                combat._on_heal(false)
            ACTION_SYRINGE:
                combat._on_heal(true)
            ACTION_AIM:
                combat._on_aim()
            ACTION_GRENADE:
                combat.throw_grenade()
            ACTION_COVER:
                combat._on_cover_pressed()
        action_applied+=1
    _action_queue.clear()

# Only nearby uncollected physical pickups, no simulated loot or client grants.
func _nearby_loot() -> Array[Dictionary]:
    var found: Array[Dictionary]=[]
    if director.match_ended or operator.royale_eliminated:
        return found
    for pickup in director._loot:
        if not is_instance_valid(pickup) or pickup.collected or pickup.is_queued_for_deletion():
            continue
        var distance: float=operator.global_position.distance_squared_to(pickup.global_position)
        if distance<=LOOT_RANGE*LOOT_RANGE:
            found.append({"id":pickup.get_instance_id(),"position":pickup.global_position,
                "kind":pickup.pickup_type,"from_opponent":pickup.from_opponent,
                "quantity":pickup.quantity,"distance_sq":distance})
    found.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.distance_sq)<float(b.distance_sq))
    if found.size()>MAX_LOOT_SNAPSHOT:
        found.resize(MAX_LOOT_SNAPSHOT)
    return found

func _on_server_blast(at: Vector3) -> void:
    if at.is_finite() and operator.global_position.distance_squared_to(at)<=TACTICAL_RANGE*TACTICAL_RANGE:
        grenade_blasts+=1
        last_blast_position=at
        last_blast_ms=Time.get_ticks_msec()

func _tactical_snapshot() -> Dictionary:
    var grenades: Array[Dictionary]=[]
    var covers: Array[Dictionary]=[]
    if not director.match_ended:
        for grenade in combat._grenades:
            if is_instance_valid(grenade) and not grenade.is_queued_for_deletion() and not grenade._spent and operator.global_position.distance_squared_to(grenade.global_position)<=TACTICAL_RANGE*TACTICAL_RANGE:
                grenades.append({"id":grenade.get_instance_id(),"position":grenade.global_position,"seconds":grenade._remaining})
        for cover in get_tree().get_nodes_in_group("aurora_deployable_cover"):
            if is_instance_valid(cover) and cover.is_active() and operator.global_position.distance_squared_to(cover.global_position)<=TACTICAL_RANGE*TACTICAL_RANGE:
                covers.append({"id":cover.get_instance_id(),"position":cover.global_position,"yaw":cover.rotation.y})
    return {"grenades":grenades,"covers":covers,"blast_sequence":grenade_blasts,
        "blast_position":last_blast_position if Time.get_ticks_msec()-last_blast_ms<1000 else null,
        "cover_cooldown":combat.cover_cooldown}

@rpc("authority","call_remote","unreliable_ordered",2)
func receive_state(version: int,data: Dictionary) -> void:
    if version==PROTOCOL and not multiplayer.is_server():
        state=data

func _physics_process(delta: float) -> void:
    if remote_id==0 or not multiplayer.is_server() or not is_instance_valid(operator):
        return
    if Time.get_ticks_msec()-last_input_ms>INPUT_TIMEOUT_MS or director.match_ended:
        _stop_input()
    else:
        operator.set_touch_move_axis(axis)
        operator._desired_yaw=yaw
        operator._desired_pitch=pitch
        operator.set_touch_run(sprint)
        _apply_actions()
        if fire!=previous_fire:
            if fire:
                combat._on_fire_pressed()
            else:
                combat._on_fire_released()
            previous_fire=fire
    _send_clock+=delta
    if _send_clock>=.1:
        _send_clock=fmod(_send_clock,.1)
        # Only fresh server-tested FOV/LOS contacts leave the server.
        # Never broadcast the complete bot roster or last-known positions.
        director._scan_visible_enemy_contacts()
        var rivals: Array[Dictionary]=[]
        for entry in director._visible_enemy_actors:
            var actor: CharacterBody3D=entry["actor"] as CharacterBody3D
            if is_instance_valid(actor) and actor.health>0.0:
                rivals.append({"id":actor.get_instance_id(),
                    "position":actor.global_position,"yaw":actor.rotation.y,
                    "clip":str(actor._clip)})
        # Private development snapshot: no hidden enemy coordinates.
        receive_state.rpc_id(remote_id,PROTOCOL,{
            "position":operator.global_position,"velocity":operator.velocity,
            "body_yaw":operator.rotation.y,"clip":str(operator._current_clip),
            "rivals":rivals,"ended":director.match_ended,
            "loot":_nearby_loot(),"inventory":combat.inventory_snapshot(),
            "tactical":_tactical_snapshot(),
            "weapon":combat.weapon_index,"aim":combat.aim_active,"zoom":combat.current_zoom,
            "heal_remaining":combat._heal_remaining,"firing":combat.trigger_held,
            "crouched":operator._crouching,"grounded":operator.is_on_floor(),
            "ammo":combat.ammo[combat.weapon_index],
            "reserve":combat.reserve[combat.WEAPONS.reserve_slot(combat.weapon_index)],
            "reload_remaining":combat.reload_timer,"reloads":combat.reloads_completed,
            "action_ack":action_ack,"action_applied":action_applied,"action_rejected":action_rejected,
            "health":operator.training_health,"participants":50,
            "alive":combat.active_fighter_count(),"bots":combat._targets.size(),
            "shots":combat.shots_fired_total,"zone_center":director.zone_center,
            "zone_radius":director.radius,"elapsed":director.elapsed,
            "accepted":accepted,"rejected":rejected,"ack":last_sequence})
