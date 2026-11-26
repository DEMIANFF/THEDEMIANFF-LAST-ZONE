extends Node
## Internal ENet development transport. One human operator, 49 server bots.
## Loopback only until authenticated admission and a production endpoint exist.
const PORT: int=24621
const PROTOCOL: int=7
# Reserve headroom below the observed 1392-byte ENet MTU for RPC headers.
const STATE_CHUNK_BYTES: int=960
const STATE_RAW_LIMIT: int=65536
const STATE_MAX_CHUNKS: int=70
var _state_pending_id: int=0
var _state_pending_count: int=0
var _state_pending_raw_size: int=0
var _state_parts: Dictionary={}
var state_frames: int=0
var max_state_chunk_bytes: int=0
var max_state_raw_bytes: int=0
var max_state_encoded_bytes: int=0
const WEAPON_CATALOG=preload("res://scripts/combat/aurora_weapon_catalog.gd")
const SOUND_WINDOW_MS: int=650
const SOUND_LIMIT: int=32
const SOUND_BATCH: int=6
var snapshot_sequence: int=0
var last_sound_batch: Array=[]
var pending_sounds: Array=[]
var _qa_fixture: bool=false
var _qa_end_verified: bool=false
var _qa_rival_test: bool=false
var _qa_rival: CharacterBody3D
var _qa_rival_wall: StaticBody3D
var _qa_rival_start: int=0
var _qa_rival_phase: int=-1
var max_sound_bytes: int=0
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
var sound_sequence: int=0
var _sounds: Array[Dictionary]=[]

func listen(port: int=PORT) -> Error:
    var peer:=ENetMultiplayerPeer.new()
    peer.set_bind_ip("127.0.0.1")
    var result: Error=peer.create_server(port,1,4)
    if result!=OK:
        return result
    multiplayer.multiplayer_peer=peer
    multiplayer.peer_connected.connect(_joined)
    multiplayer.peer_disconnected.connect(_left)
    return OK

func connect_local(port: int=PORT) -> Error:
    var peer:=ENetMultiplayerPeer.new()
    var result: Error=peer.create_client("127.0.0.1",port,4)
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
    sound_sequence=0
    _sounds.clear()
    combat.shot_fired.connect(_on_player_shot)
    combat.reload_started.connect(_on_player_reload)
    combat.reload_cue.connect(func(sample: StringName): _sound_event("local",str(sample)))
    combat.awm_bolt_cycled.connect(func(): _sound_event("local","awm_bolt"))
    combat.healed.connect(func(): _sound_event("local","heal"))
    combat.impact_occurred.connect(func(): _sound_event("local","impact"))
    operator.jumped.connect(func(): _sound_event("local","jump"))
    operator.player_damaged.connect(func(_amount: float): _sound_event("local","hit"))
    operator.foot_contact.connect(func(stone: bool,running: bool): _sound_event("local_step","",Vector3.ZERO,running,stone))
    combat.bot_shot.connect(func(at: Vector3): _sound_event("remote_shot","",at))
    combat.bot_foot_contact.connect(func(at: Vector3,running: bool,stone: bool): _sound_event("remote_step","",at,running,stone))
    combat.grenade_fuse_close.connect(func(_seconds: float): _sound_event("local","grenade_fuse"))
    combat.set_encounter_size(50)
    director.start_sector_battle()
    if director.mode!="sector_battle" or combat.active_fighter_count()!=50:
        push_error("AURORA_ONLINE authoritative match failed to start")
        multiplayer.multiplayer_peer.disconnect_peer(id)
        return
    # A real extra physical pickup only in the isolated CI test room.
    # Never grant the weapon directly or enable this from a remote packet.
    _qa_fixture=OS.get_environment("AURORA_ONLINE_QA_FIXTURE")=="1"
    _qa_rival_test=_qa_fixture and OS.get_environment("AURORA_ONLINE_QA_RIVALS")=="1"
    if _qa_fixture:
        # Isolate mechanical regression from randomly timed bot elimination.
        # Only the private CI process activates this; normal matches retain damage.
        # The same test ends with a real lethal server hit and rejects later actions.
        operator._training_immunity=90.0
        print("AURORA_ONLINE QA fixture: temporary non-environmental immunity")
        var at:=Vector2(operator.global_position.x,operator.global_position.z-3.2)
        director._make_pickup(at,"weapon_awm","OnlineQAPhysicalAWM")
        director._make_pickup(at,"grenade","OnlineQAPhysicalGrenade")
    print("AURORA_ONLINE MATCH peer=",id," participants=",combat.active_fighter_count())
    if _qa_rival_test:
        _prepare_rival_fixture()

# Separate private QA room. Use actual server bots and physical ray occlusion,
# not a fabricated network snapshot. Never triggered by a client packet.
func _prepare_rival_fixture() -> void:
    director.set_process(false)
    combat.set_process(false)
    operator.set_physics_process(false)
    operator.global_position=Vector3(0,55,-24)
    operator.set("_yaw",0.0)
    operator.set("_desired_yaw",0.0)
    operator.set("air_mode","ground")
    for bot: CharacterBody3D in combat._targets:
        bot.set_physics_process(false)
    _qa_rival=combat._targets[0]
    _qa_rival.global_position=Vector3(0,55,-37)
    _qa_rival.collision_layer=1
    _qa_rival.visible=true
    _qa_rival.set("health",200.0)
    _qa_rival.set("_airdrop_stage","inactive")
    _qa_rival.set("_clip","AuroraIdle")
    _qa_rival_start=Time.get_ticks_msec()

func _advance_rival_fixture() -> void:
    if not is_instance_valid(_qa_rival):
        return
    var age: int=Time.get_ticks_msec()-_qa_rival_start
    var phase: int=0 if age<2500 else (1 if age<5000 else (2 if age<7500 else (3 if age<10000 else 4)))
    if phase==_qa_rival_phase:
        return
    _qa_rival_phase=phase
    match phase:
        1:
            _qa_rival.set("_clip","AuroraWalk")
            _qa_rival.global_position=Vector3(1,55,-38)
            _qa_rival.rotation.y=.65
        2:
            _qa_rival_wall=StaticBody3D.new()
            _qa_rival_wall.collision_layer=1
            world.add_child(_qa_rival_wall)
            _qa_rival_wall.global_position=Vector3(0,56,-30.5)
            var collision:=CollisionShape3D.new()
            var box:=BoxShape3D.new()
            box.size=Vector3(5,3,1.1)
            collision.shape=box
            _qa_rival_wall.add_child(collision)
        3:
            _qa_rival_wall.queue_free()
            _qa_rival.set("_clip","AuroraRun")
        4:
            _qa_rival.set("health",0.0)
    print("V75228_SERVER_RIVAL_PHASE ",phase)


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

func _on_player_shot(weapon: int,_hit: bool) -> void:
    if weapon>=0 and weapon<WEAPON_CATALOG.ENTRIES.size():
        _sound_event("local",str(WEAPON_CATALOG.ENTRIES[weapon]["sample"]))

func _on_player_reload() -> void:
    if combat.weapon_index not in [WEAPON_CATALOG.MP40,WEAPON_CATALOG.P90]:
        _sound_event("local","reload")

func _sound_event(kind: String,sample: String,at: Vector3=Vector3.ZERO,running: bool=false,stone: bool=false) -> void:
    if remote_id==0 or not is_instance_valid(operator) or director.match_ended:
        return
    if kind.begins_with("remote"):
        var maximum: float=26.0 if kind=="remote_step" else (105.0 if kind=="remote_blast" else 150.0)
        if not at.is_finite() or operator.global_position.distance_squared_to(at)>maximum*maximum:
            return
        # Audible direction only: quantize locations, never send actor IDs
        # or continuous hidden-player tracking with a sound event.
        at=at.snapped(Vector3(4.0,2.0,4.0))
    sound_sequence+=1
    _sounds.append({"seq":sound_sequence,"kind":kind,"sample":sample,
        "at":at,"run":running,"stone":stone,"time":Time.get_ticks_msec()})
    if _sounds.size()>SOUND_LIMIT:
        _sounds.pop_front()

func _sound_snapshot() -> Array[Dictionary]:
    var now: int=Time.get_ticks_msec()
    while not _sounds.is_empty() and now-int(_sounds[0].time)>SOUND_WINDOW_MS:
        _sounds.pop_front()
    var result: Array[Dictionary]=[]
    for entry in _sounds:
        var item: Dictionary=entry.duplicate()
        item.erase("time")
        result.append(item)
    return result

func _on_server_blast(at: Vector3) -> void:
    _sound_event("remote_blast","",at)
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

@rpc("authority","call_remote","unreliable_ordered",3)
func receive_sound_batch(version: int,events: Array) -> void:
    if version!=PROTOCOL or multiplayer.is_server():
        return
    last_sound_batch=events
    pending_sounds.append_array(events)
    if pending_sounds.size()>128:
        pending_sounds=pending_sounds.slice(-128)

func drain_sounds() -> Array:
    var result: Array=pending_sounds
    pending_sounds=[]
    return result

func _send_sound_batches() -> void:
    var events: Array[Dictionary]=_sound_snapshot()
    for start in range(0,events.size(),SOUND_BATCH):
        var batch: Array=events.slice(start,mini(start+SOUND_BATCH,events.size()))
        # Inspect serialized variant size; reserve margin for RPC/ENet headers.
        var bytes: int=var_to_bytes(batch).size()
        max_sound_bytes=maxi(max_sound_bytes,bytes)
        receive_sound_batch.rpc_id(remote_id,PROTOCOL,batch)

func _send_world_state(data: Dictionary) -> void:
    var raw: PackedByteArray=var_to_bytes(data)
    if raw.is_empty() or raw.size()>STATE_RAW_LIMIT:
        push_warning("AURORA_ONLINE snapshot outside raw budget")
        return
    var encoded: PackedByteArray=raw.compress(FileAccess.COMPRESSION_DEFLATE)
    if encoded.is_empty() or encoded.size()>STATE_CHUNK_BYTES*STATE_MAX_CHUNKS:
        push_warning("AURORA_ONLINE snapshot outside encoded budget")
        return
    var count: int=ceili(float(encoded.size())/float(STATE_CHUNK_BYTES))
    for index in range(count):
        var offset: int=index*STATE_CHUNK_BYTES
        var part: PackedByteArray=encoded.slice(offset,mini(offset+STATE_CHUNK_BYTES,encoded.size()))
        receive_state_chunk.rpc_id(remote_id,PROTOCOL,int(data.snapshot_id),index,count,raw.size(),part)

@rpc("authority","call_remote","unreliable_ordered",2)
func receive_state_chunk(version: int,frame: int,index: int,count: int,raw_size: int,part: PackedByteArray) -> void:
    if version==PROTOCOL and not multiplayer.is_server():
        _ingest_state_chunk(frame,index,count,raw_size,part)

# Complete frames only: missing chunks never erase loot or rival replicas.
# Newer frames supersede incomplete older ones; no reliable-channel backlog.
func _ingest_state_chunk(frame: int,index: int,count: int,raw_size: int,part: PackedByteArray) -> void:
    if frame<=int(state.get("snapshot_id",0)) or frame<_state_pending_id or count<1 or count>STATE_MAX_CHUNKS or index<0 or index>=count or raw_size<1 or raw_size>STATE_RAW_LIMIT or part.is_empty() or part.size()>STATE_CHUNK_BYTES:
        return
    if frame>_state_pending_id:
        _state_pending_id=frame
        _state_pending_count=count
        _state_pending_raw_size=raw_size
        _state_parts.clear()
    if count!=_state_pending_count or raw_size!=_state_pending_raw_size or _state_parts.has(index):
        return
    max_state_chunk_bytes=maxi(max_state_chunk_bytes,part.size())
    _state_parts[index]=part
    if _state_parts.size()!=count:
        return
    var encoded: PackedByteArray=PackedByteArray()
    for i in range(count):
        encoded.append_array(_state_parts[i])
    _state_parts.clear()
    var raw: PackedByteArray=encoded.decompress(raw_size,FileAccess.COMPRESSION_DEFLATE)
    if raw.size()!=raw_size:
        return
    var decoded: Variant=bytes_to_var(raw)
    if not decoded is Dictionary or int(decoded.get("snapshot_id",0))!=frame:
        return
    state=decoded
    state_frames+=1
    max_state_raw_bytes=maxi(max_state_raw_bytes,raw_size)
    max_state_encoded_bytes=maxi(max_state_encoded_bytes,encoded.size())

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
    # CI-only end-of-round regression after input timeout, independent of
    # tactical placement. Uses the real damage and elimination code path.
    if _qa_fixture and not _qa_end_verified and action_applied>=10 and last_input_ms>0 and Time.get_ticks_msec()-last_input_ms>3000:
        _qa_end_verified=true
        operator.receive_training_hit(operator.MAX_HEALTH,true)
    if _qa_rival_test:
        _advance_rival_fixture()
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
        snapshot_sequence+=1
        _send_world_state({
            "snapshot_id":snapshot_sequence,"eliminated":operator.royale_eliminated,
            "cover_reason":combat.cover_last_block_reason,"sound_payload_peak":max_sound_bytes,
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
        _send_sound_batches()
