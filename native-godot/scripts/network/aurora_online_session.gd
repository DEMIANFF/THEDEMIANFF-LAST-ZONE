extends Node
## Internal ENet development transport. One human operator, 49 server bots.
## Loopback only until authenticated admission and a production endpoint exist.
const PORT: int=24621
const PROTOCOL: int=2
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
var state: Dictionary={}
var _send_clock: float=0.0

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
    combat.set_encounter_size(50)
    director.start_sector_battle()
    if director.mode!="sector_battle" or combat.active_fighter_count()!=50:
        push_error("AURORA_ONLINE authoritative match failed to start")
        multiplayer.multiplayer_peer.disconnect_peer(id)
        return
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
            "health":operator.training_health,"participants":50,
            "alive":combat.active_fighter_count(),"bots":combat._targets.size(),
            "shots":combat.shots_fired_total,"zone_center":director.zone_center,
            "zone_radius":director.radius,"elapsed":director.elapsed,
            "accepted":accepted,"rejected":rejected,"ack":last_sequence})
