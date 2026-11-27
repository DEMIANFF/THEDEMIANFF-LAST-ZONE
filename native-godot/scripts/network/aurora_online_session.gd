extends Node
## Internal ENet development transport. One human operator, 49 server bots.
## Loopback only until authenticated admission and a production endpoint exist.
const PORT: int=24621
const PROTOCOL: int=31
const TICKETS=preload("res://scripts/network/online_admission_ticket.gd")
var room_internet: bool=false
var _internet_room_id: String=""
var _internet_secret: PackedByteArray=[]
var _used_tickets: Dictionary={}
var _internet_users: Dictionary={}
var _internet_ticket: String=""
var _internet_auth: SceneMultiplayer
var _internet_records: Dictionary={}
var _internet_result_emitted: bool=false
var room_flexible: bool=false
var room_sealed: bool=false
var room_join_remaining: float=20.0
var room_bot_target: int=46
var room_initial_humans: int=0
var room_occupied_slots: Dictionary={}
const ROOM_GRENADE=preload("res://scripts/combat/aurora_grenade.gd")
const ROOM_COVER=preload("res://scripts/combat/aurora_deployable_cover.gd")
var room_tactical: bool=false
var room_lan: bool=false
var room_team_size: int=1
var room_winner_team: int=-1
var room_projectiles: Array[Node3D]=[]
var room_covers: Array[StaticBody3D]=[]
var room_blast_seq: int=0
var room_blast_at: Vector3=Vector3.ZERO
var room_blast_ms: int=-10000
var room_vehicle_ready: bool=false
var room_result: Dictionary={}
var catalog_room: bool=false
var _catalog_available: Array[int]=[]
const CATALOG_VISUALS=preload("res://scripts/combat/weapon_visuals.gd")
var _mixed_ground_bots: Dictionary={}
var _early_ground_shots: int=0
var _early_ground_claims: int=0
var _early_ground_started: bool=false
const ROOM_FLIGHT=preload("res://scripts/match/airdrop_sequence.gd")
var mixed_flight: bool=false
var _mixed_phase: String="waiting"
var _mixed_wait: float=15.0
var _mixed_flight_elapsed: float=0.0
var _mixed_landed_bots: int=0
var _mixed_depart_pending: bool=false
var _mixed_battle_pending: bool=false
const ROOM_DEATH_CAP: int=12
var _bot_death_spawned: int=0
var _bot_death_claims: int=0
var _death_retired: int=0
var _death_peak: int=0
const MIXED_BOTS: int=46
var mixed_room: bool=false
var _mixed_ready: bool=false
var _mixed_bots: Array[CharacterBody3D]=[]
var _mixed_bot_shots: int=0
var _mixed_human_damage: int=0
var _mixed_human_hits: int=0
var _mixed_bot_dead: Dictionary={}
var _mixed_winner_bot: bool=false
var terrain_room: bool=false
var _terrain_ready: bool=false
var _room_elapsed: float=0.0
var _room_damage_clock: float=0.0
var _room_zone: Dictionary={}
var _terrain_sites: Array[Vector2]=[]
var expanded_room: bool=false
var room_capacity: int=2
var _death_claims: int=0
var _death_spawned: int=0
var _death_pending: Array[Dictionary]=[]
const DUAL_HEAL_SECONDS: float=3.0
const DUAL_HEAL_HP: float=45.0
const SHARED_LOOT=preload("res://scripts/match/aurora_loot.gd")
var dual_loot: bool=false
var _dual_loot_nodes: Array[Area3D]=[]
var _dual_loot_claims: int=0
var dual_combat: bool=false
var _dual_winner: int=0
var _dual_finished: bool=false
const HUMAN_OPERATOR=preload("res://scripts/player/third_person_operator.gd")
# Explicit local development room. Normal BR admission remains single-human
# until per-human combat, inventory and flight directors are migrated.
var dual_waiting: bool=false
var dual_peers: Dictionary={}
var _dual_admitted: int=0
const ACTION_VEHICLE: int=11
const VEHICLE=preload("res://scripts/world/aurora_driveable_vehicle.gd")
var _qa_vehicle_test: bool=false
var vehicle_action_result: String=""
const WAITING_BOT_LIMIT: int=49
const WAITING_CONTACT_LIMIT: int=8
var _waiting_roster: Array[CharacterBody3D]=[]
const WAITING_ISLAND=preload("res://scripts/network/online_waiting_island.gd")
const WAIT_SECONDS: float=15.0
var waiting_remaining: float=0.0
var waiting_island: Node3D
var _waiting_transition: bool=false
const AIR_CONTACT_LIMIT: int=8
const AIR_CONTACT_RANGE: float=65.0
var _qa_air_rival_prepared: bool=false
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
var pending_critical_sounds: Array=[]
var last_critical_sound: Dictionary={}
var critical_sound_sequence: int=0
var received_critical_sequence: int=0
var critical_sound_gaps: int=0
var _qa_fixture: bool=false
var _qa_end_verified: bool=false
var _qa_rival_test: bool=false
var _qa_flight_test: bool=false
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
    room_internet=OS.get_environment("AURORA_INTERNET_SERVER")=="1"
    var peer: MultiplayerPeer
    var bind_ip: String=OS.get_environment("AURORA_LAN_BIND").strip_edges()
    room_lan=not bind_ip.is_empty()
    if room_lan and not is_private_lan_host(bind_ip):
        return ERR_INVALID_PARAMETER
    if room_internet and room_lan:
        return ERR_INVALID_PARAMETER
    var flexible_qa: bool=OS.get_environment("AURORA_FLEX_QA")=="1"
    room_flexible=room_internet or room_lan or flexible_qa
    room_join_remaining=6.0 if flexible_qa else 20.0
    mixed_flight=room_flexible or OS.get_environment("AURORA_ONLINE_MIXED_FLIGHT")=="1"
    mixed_room=mixed_flight or OS.get_environment("AURORA_ONLINE_MIXED_COMBAT")=="1"
    terrain_room=mixed_room or OS.get_environment("AURORA_ONLINE_TERRAIN_COMBAT")=="1"
    catalog_room=mixed_room or OS.get_environment("AURORA_ONLINE_CATALOG_QA")=="1"
    expanded_room=terrain_room or catalog_room or OS.get_environment("AURORA_ONLINE_FOUR_COMBAT")=="1"
    if catalog_room:
        _catalog_available=[WEAPON_CATALOG.AR]
        for slot in range(1,WEAPON_CATALOG.ENTRIES.size()):
            var path: String=CATALOG_VISUALS.AWM_PATH if slot==WEAPON_CATALOG.AWM else str(WEAPON_CATALOG.ENTRIES[slot].get("asset",""))
            if not path.is_empty() and ResourceLoader.exists(path,"PackedScene"):
                _catalog_available.append(slot)
    room_tactical=mixed_room or OS.get_environment("AURORA_ONLINE_TACTICAL_QA")=="1"
    var requested_team: int=int(OS.get_environment("AURORA_TEAM_SIZE"))
    room_team_size=requested_team if mixed_room and requested_team in [2,4] else 1
    room_capacity=4 if expanded_room else 2
    dual_loot=expanded_room or OS.get_environment("AURORA_ONLINE_DUAL_LOOT")=="1"
    dual_combat=dual_loot or OS.get_environment("AURORA_ONLINE_DUAL_COMBAT")=="1"
    dual_waiting=dual_combat or OS.get_environment("AURORA_ONLINE_DUAL_WAITING")=="1"
    var result: Error
    if room_internet:
        _internet_room_id=OS.get_environment("AURORA_ROOM_ID")
        _internet_secret=OS.get_environment("AURORA_MATCH_SIGNING_KEY").hex_decode()
        if _internet_room_id.length()<16 or _internet_secret.size()!=32:
            return ERR_INVALID_PARAMETER
        var cert:=X509Certificate.new()
        var key:=CryptoKey.new()
        if cert.load(OS.get_environment("AURORA_TLS_CERT"))!=OK or key.load(OS.get_environment("AURORA_TLS_KEY"))!=OK:
            return ERR_CANT_OPEN
        var ws:=WebSocketMultiplayerPeer.new()
        ws.inbound_buffer_size=65536
        ws.outbound_buffer_size=131072
        ws.max_queued_packets=128
        var address: String="127.0.0.1" if OS.get_environment("AURORA_INTERNET_QA")=="1" else "0.0.0.0"
        result=ws.create_server(port,address,TLSOptions.server(key,cert))
        peer=ws
        if result==OK:
            _install_server_auth()
    else:
        var enet:=ENetMultiplayerPeer.new()
        enet.set_bind_ip(bind_ip if room_lan else "127.0.0.1")
        result=enet.create_server(port,room_capacity if dual_waiting else 1,5)
        peer=enet
    if result!=OK:
        return result
    multiplayer.multiplayer_peer=peer
    multiplayer.peer_connected.connect(_joined)
    multiplayer.peer_disconnected.connect(_left)
    return OK

func _install_server_auth() -> void:
    _internet_auth=multiplayer as SceneMultiplayer
    _internet_auth.auth_timeout=8.0
    _internet_auth.server_relay=false
    _internet_auth.auth_callback=_authenticate_internet_peer
    _internet_auth.peer_authentication_failed.connect(func(id: int): _internet_users.erase(id))

func _authenticate_internet_peer(id: int,payload: PackedByteArray) -> void:
    if not room_internet or room_sealed or _internet_users.size()>=room_capacity or payload.size()>2048:
        multiplayer.multiplayer_peer.disconnect_peer(id)
        return
    var claims: Dictionary=TICKETS.verify(payload.get_string_from_utf8(),_internet_secret,_internet_room_id,PROTOCOL,int(Time.get_unix_time_from_system()))
    if claims.is_empty() or _used_tickets.has(claims.nonce) or _internet_users.values().has(claims.sub) or _used_tickets.size()>=256:
        print("V75251_AUTH_DENIED")
        multiplayer.multiplayer_peer.disconnect_peer(id)
        return
    _used_tickets[claims.nonce]=true
    _internet_users[id]=claims.sub
    _internet_auth.send_auth(id,"OK".to_utf8_buffer())
    if _internet_auth.complete_auth(id)!=OK:
        _internet_users.erase(id)
        multiplayer.multiplayer_peer.disconnect_peer(id)
        return
    print("V75251_AUTH_ACCEPTED")

func connect_internet(endpoint: String,ticket: String,qa_certificate: X509Certificate=null) -> Error:
    if not endpoint.begins_with("wss://") or endpoint.length()>240 or ticket.is_empty() or ticket.length()>2048:
        return ERR_INVALID_PARAMETER
    # No insecure TLS options. A private test CA is allowed only in headless QA.
    if qa_certificate!=null and (DisplayServer.get_name()!="headless" or OS.get_environment("AURORA_INTERNET_QA")!="1"):
        return ERR_INVALID_PARAMETER
    var peer:=WebSocketMultiplayerPeer.new()
    peer.inbound_buffer_size=131072
    peer.outbound_buffer_size=65536
    peer.max_queued_packets=128
    var result: Error=peer.create_client(endpoint,TLSOptions.client(qa_certificate))
    if result!=OK:
        return result
    _internet_ticket=ticket
    _internet_auth=multiplayer as SceneMultiplayer
    _internet_auth.auth_timeout=8.0
    _internet_auth.auth_callback=func(id: int,payload: PackedByteArray):
        if id==1 and payload.get_string_from_utf8()=="OK":
            _internet_ticket=""
            _internet_auth.complete_auth(id)
        else:
            multiplayer.multiplayer_peer.disconnect_peer(id)
    _internet_auth.peer_authenticating.connect(func(id: int):
        if id==1:
            _internet_auth.send_auth(id,_internet_ticket.to_utf8_buffer()))
    multiplayer.multiplayer_peer=peer
    return OK

static func is_private_lan_host(host: String) -> bool:
    var parts: PackedStringArray=host.split(".")
    if parts.size()!=4:
        return false
    for part in parts:
        if not part.is_valid_int() or int(part)<0 or int(part)>255 or str(int(part))!=part:
            return false
    return int(parts[0])==10 or (int(parts[0])==192 and int(parts[1])==168) or (int(parts[0])==172 and int(parts[1])>=16 and int(parts[1])<=31)

func connect_lan(host: String,port: int=PORT) -> Error:
    if not is_private_lan_host(host):
        return ERR_INVALID_PARAMETER
    return _connect_endpoint(host,port)

func connect_local(port: int=PORT) -> Error:
    return _connect_endpoint("127.0.0.1",port)

func _connect_endpoint(host: String,port: int) -> Error:
    var peer:=ENetMultiplayerPeer.new()
    var result: Error=peer.create_client(host,port,5)
    if result==OK:
        multiplayer.multiplayer_peer=peer
    return result

func _joined(id: int) -> void:
    if room_internet and not _internet_users.has(id):
        multiplayer.multiplayer_peer.disconnect_peer(id)
        return
    if dual_waiting:
        _dual_joined(id)
        return
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
    critical_sound_sequence=0
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
    _qa_fixture=OS.get_environment("AURORA_ONLINE_QA_FIXTURE")=="1"
    _qa_rival_test=_qa_fixture and OS.get_environment("AURORA_ONLINE_QA_RIVALS")=="1"
    _qa_flight_test=_qa_fixture and OS.get_environment("AURORA_ONLINE_QA_FLIGHT")=="1"
    _qa_vehicle_test=_qa_fixture and OS.get_environment("AURORA_ONLINE_QA_VEHICLE")=="1"
    combat.set_encounter_size(50)
    # Existing isolated ground regressions retain their exact starting room.
    # Normal development matches now use the original authoritative airdrop.
    if not _qa_fixture or _qa_flight_test:
        _begin_waiting()
        return
    director.start_sector_battle()
    if director.mode!="sector_battle" or combat.active_fighter_count()!=50:
        push_error("AURORA_ONLINE authoritative match failed to start")
        multiplayer.multiplayer_peer.disconnect_peer(id)
        return
    # A real extra physical pickup only in the isolated CI test room.
    # Never grant the weapon directly or enable this from a remote packet.
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
    if _qa_vehicle_test:
        _prepare_vehicle_fixture()

# A bounded physical staging island, separate from the combat terrain.
# Test-only wheel chassis with no render model. Never instantiated in
# normal matches and never advertised as an authentic car asset.
func _prepare_vehicle_fixture() -> void:
    director.set_process(false)
    combat.set_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    director._remove_driveable_vehicles()
    var car: AuroraDriveableVehicle=preload("res://scripts/network/qa_vehicle_chassis.gd").new()
    car.terrain=director.terrain
    var site:=Vector2(72,-6)
    car.position=Vector3(site.x,director.terrain.height_at(site.x,site.y)+1.4,site.y)
    director.add_child(car)
    director._driveable_cars.append(car)
    operator.global_position=car.global_position+Vector3(-7,0,0)
    operator.velocity=Vector3.ZERO
    print("V75235_SERVER_FIXTURE chassis_only=true")

func _begin_waiting() -> void:
    combat.end_sector_battle()
    combat.visible=false
    combat.set_process(false)
    director.mode="waiting"
    director.match_ended=false
    operator.reset_controls()
    operator.round_finished=false
    operator.royale_eliminated=false
    operator.air_mode="ground"
    operator.training_health=operator.MAX_HEALTH
    operator._training_immunity=WAIT_SECONDS+5.0
    waiting_island=WAITING_ISLAND.new()
    waiting_island.physical=true
    world.add_child(waiting_island)
    operator.global_position=WAITING_ISLAND.SPAWN
    operator.velocity=Vector3.ZERO
    waiting_remaining=WAIT_SECONDS
    _waiting_transition=false
    _waiting_roster.clear()
    # Server scene remains visible for LOS, but all staged actors are noncombat.
    combat.visible=true
    _stage_waiting_roster()
    print("AURORA_ONLINE MATCH peer=",remote_id," capacity=50 phase=waiting")

# Stage original match actors incrementally on the idle thread, never
# instantiate colliders in a physics callback or duplicate the battle roster.
func _admission_complete() -> bool:
    return room_sealed if room_flexible else _dual_admitted==room_capacity

func _seal_flexible_room() -> void:
    if room_sealed or dual_peers.is_empty():
        return
    room_sealed=true
    room_initial_humans=dual_peers.size()
    if room_internet:
        for peer in dual_peers.values():
            var sub: String=str(peer.online_sub)
            if sub.length()==64:
                _internet_records[sub]={"sub":sub,"slot":peer.slot,"kills":0,"hits":0,"won":false,"abandoned":false}
        print("AURORA_ROOM_ROSTER "+JSON.stringify({"room":_internet_room_id,"accounts":_internet_records.keys()}))
    room_bot_target=50-room_initial_humans
    combat.encounter_size=room_bot_target+1
    print("V75250_SEALED humans=",room_initial_humans," bots=",room_bot_target," total=",room_initial_humans+room_bot_target)

func _process(_delta: float) -> void:
    if room_flexible and multiplayer.is_server() and not room_sealed and not dual_peers.is_empty():
        room_join_remaining=maxf(0.0,room_join_remaining-_delta)
        if room_join_remaining<=0.0 or dual_peers.size()==room_capacity:
            _seal_flexible_room()
    if mixed_room and multiplayer.is_server() and _admission_complete() and not _mixed_ready and not _dual_finished and not dual_peers.is_empty():
        _stage_mixed_roster()
    if remote_id!=0 and multiplayer.is_server() and director.mode=="waiting" and not _waiting_transition:
        _stage_waiting_roster()

func _stage_waiting_roster() -> void:
    if _waiting_roster.size()>=WAITING_BOT_LIMIT:
        return
    combat._ensure_encounter_capacity(3)
    var next: int=mini(combat._targets.size(),_waiting_roster.size()+3)
    for i in range(_waiting_roster.size(),next):
        var bot: CharacterBody3D=combat._targets[i]
        bot.set_physics_process(false)
        bot.cancel_real_airdrop()
        bot.health=bot.MAX_HEALTH
        bot.velocity=Vector3.ZERO
        bot.visible=true
        bot._clip="AuroraIdle"
        var ring: int=0 if i<12 else (1 if i<28 else 2)
        var index: int=i if ring==0 else (i-12 if ring==1 else i-28)
        var count: int=12 if ring==0 else (16 if ring==1 else 21)
        var angle: float=TAU*float(index)/float(count)+float(ring)*.13
        var radius: float=8.0+float(ring)*5.0
        var home: Vector3=WAITING_ISLAND.SPAWN+Vector3(sin(angle)*radius,-.15,-cos(angle)*radius)
        bot.rotation.y=angle+PI
        bot.begin_waiting_walk(home,Vector3(cos(angle),0,sin(angle)),i)
        _waiting_roster.append(bot)
    if _waiting_roster.size()==WAITING_BOT_LIMIT:
        print("V75233_SERVER_ROSTER physical_bots=",_waiting_roster.size()," fighters=",combat.active_fighter_count())

func _waiting_contacts() -> Array[Dictionary]:
    var contacts: Array[Dictionary]=[]
    if director.mode!="waiting":
        return contacts
    var eye: Vector3=operator.global_position+Vector3.UP*1.4
    var forward:=Vector2(-sin(operator._yaw),-cos(operator._yaw))
    var candidates: Array[Dictionary]=[]
    for bot in _waiting_roster:
        if not is_instance_valid(bot) or bot.health<=0.0 or not bot.is_visible_in_tree():
            continue
        var offset: Vector3=bot.global_position-eye
        var horizontal:=Vector2(offset.x,offset.z)
        if horizontal.length_squared()<2.25 or horizontal.length_squared()>35.0*35.0 or horizontal.normalized().dot(forward)<.35:
            continue
        candidates.append({"actor":bot,"distance":offset.length_squared()})
    candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.distance)<float(b.distance))
    for i in range(mini(WAITING_CONTACT_LIMIT,candidates.size())):
        var actor: CharacterBody3D=candidates[i].actor
        var ray:=PhysicsRayQueryParameters3D.create(eye,actor.global_position+Vector3.UP)
        ray.exclude=[operator.get_rid()]
        var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
        if hit.get("collider")==actor:
            contacts.append({"id":actor.get_instance_id(),"position":actor.global_position,
                "yaw":actor.rotation.y,"clip":str(actor._clip),"weapon":-1,"waiting":true})
    return contacts

func _depart_waiting() -> void:
    if director.mode!="waiting" or remote_id==0:
        return
    _stop_input()
    # Same bodies and spawn assignments survive. Restore their original
    # anchors before the director stages the real aircraft departures.
    var moved: int=0
    var shots: int=0
    for bot in _waiting_roster:
        if is_instance_valid(bot):
            if bot.waiting_distance>1.0:
                moved+=1
            shots+=int(bot.shots_fired)
            bot.end_waiting_walk()
            bot.global_position=bot._anchor
    print("V75234_SERVER_WAITING moved=",moved," shots=",shots)
    _waiting_roster.clear()
    director.begin_aircraft_phase()
    if director.mode!="aircraft":
        push_error("AURORA_ONLINE authoritative aircraft failed to start")
        multiplayer.multiplayer_peer.disconnect_peer(remote_id)
        return
    if is_instance_valid(waiting_island):
        waiting_island.queue_free()
    waiting_island=null
    print("V75232_SERVER_DEPARTURE countdown=",waiting_remaining)

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
    _qa_rival.set("weapon_slot",WEAPON_CATALOG.AR)
    _qa_rival.set("_clip","AuroraIdle")
    _qa_rival_start=Time.get_ticks_msec()

func _advance_rival_fixture() -> void:
    if not is_instance_valid(_qa_rival):
        return
    var age: int=Time.get_ticks_msec()-_qa_rival_start
    var phase: int=mini(age/2500,7)
    if phase==_qa_rival_phase:
        return
    _qa_rival_phase=phase
    match phase:
        1:
            _qa_rival.set("_clip","AuroraWalk")
            _qa_rival.global_position=Vector3(1,55,-38)
            _qa_rival.rotation.y=.65
        2:
            _qa_rival.set("_clip","AuroraFire")
        3:
            _qa_rival.set("weapon_slot",WEAPON_CATALOG.AWM)
            _qa_rival.set("_clip","AuroraReloadAR")
        4:
            _qa_rival.set("_clip","AuroraHitFront")
        5:
            _qa_rival_wall=StaticBody3D.new()
            _qa_rival_wall.collision_layer=1
            world.add_child(_qa_rival_wall)
            _qa_rival_wall.global_position=Vector3(0,56,-30.5)
            var collision:=CollisionShape3D.new()
            var box:=BoxShape3D.new()
            box.size=Vector3(5,3,1.1)
            collision.shape=box
            _qa_rival_wall.add_child(collision)
        6:
            _qa_rival_wall.queue_free()
            _qa_rival.set("_clip","AuroraRun")
        7:
            _qa_rival.set("health",0.0)
    print("V75228_SERVER_RIVAL_PHASE ",phase)


func _left(id: int) -> void:
    _internet_users.erase(id)
    if dual_waiting:
        _dual_left(id)
        return
    if id==remote_id:
        _stop_input()
        remote_id=0
        # A dedicated development room is single-use. Never allow a second
        # connection to inherit the previous player's in-progress match.
        get_tree().quit()

# Two authenticated-by-transport peer IDs, no client-selected actor IDs.
# This is an isolated noncombat staging room, not a 50-human battle.
func _dual_joined(id: int) -> void:
    if _dual_admitted>=room_capacity or (room_flexible and room_sealed) or not is_instance_valid(world):
        if room_flexible and room_sealed:
            print("V75250_LATE_DENIED peer=",id)
        multiplayer.multiplayer_peer.disconnect_peer(id)
        return
    var slot: int=_dual_admitted
    if room_flexible:
        for candidate in range(room_capacity):
            if not room_occupied_slots.has(candidate):
                slot=candidate
                break
    if _dual_admitted==0:
        combat.end_sector_battle()
        combat.hide()
        combat.set_process(false)
        for bot in combat._targets:
            bot.set_physics_process(false)
            bot.collision_layer=0
        director.mode="waiting"
        director.set_process(false)
        director.match_ended=false
        if terrain_room:
            director._configure_zone_centers(1)
            _room_zone=director.zone_state_at(0.0)
            _terrain_sites=_choose_terrain_sites()
            if _terrain_sites.size()!=room_capacity:
                push_error("V75243 unable to find four safe terrain starts")
                multiplayer.multiplayer_peer.disconnect_peer(id)
                return
        if not terrain_room or mixed_flight:
            waiting_island=WAITING_ISLAND.new()
            waiting_island.physical=true
            world.add_child(waiting_island)
    var actor: CharacterBody3D=operator
    if slot>0:
        actor=HUMAN_OPERATOR.new()
        actor.name="OnlineHuman"+str(id)
        world.add_child(actor)
    var side: float=-1.0 if slot==0 else 1.0
    var home: Vector3=WAITING_ISLAND.SPAWN+Vector3(side*3.0,0,0)
    var heading: float=side*PI*.5
    if expanded_room:
        var offsets: Array[Vector3]=[Vector3(-6,0,0),Vector3(6,0,0),Vector3(0,0,-9),Vector3(0,0,9)]
        home=WAITING_ISLAND.SPAWN+offsets[slot]
        heading=atan2(offsets[slot].x,offsets[slot].z)
    if terrain_room and not mixed_flight:
        var site: Vector2=_terrain_sites[slot]
        home=Vector3(site.x,director.terrain.height_at(site.x,site.y)+.45,site.y)
        var toward: Vector2=director.CENTER-site
        heading=atan2(-toward.x,-toward.y)
    actor.reset_controls()
    actor.round_finished=false
    actor.royale_eliminated=false
    actor.air_mode="ground"
    actor.training_health=actor.MAX_HEALTH
    actor.battle_royale_active=dual_combat
    actor.set_meta("online_team",floori(float(slot)/float(room_team_size)) if room_team_size>1 else -1)
    if room_flexible:
        actor.collision_layer=1
        actor.collision_mask=1
        actor.set_physics_process(true)
        actor.show()
        room_occupied_slots[slot]=id
    actor.armor_points=0.0
    actor.helmet_points=0.0
    actor.vest_level=0
    actor.helmet_level=0
    actor.set_equipped_weapon(WEAPON_CATALOG.AR)
    actor._training_immunity=0.0
    actor.global_position=home
    actor.velocity=Vector3.ZERO
    actor.rotation.y=heading
    actor._yaw=heading
    actor._desired_yaw=heading
    actor.get_view_camera().current=false
    dual_peers[id]={"actor":actor,"home":home,"sequence":0,"accepted":0,"rejected":0,
        "input_ms":0,"axis":Vector2.ZERO,"yaw":heading,"pitch":-.14,"run":false,
        "action_ack":0,"action_rejected":0,"action_applied":0,"jump_pending":false,"jump_ms":-1000,
        "fire":false,"ammo":int(WEAPON_CATALOG.ENTRIES[WEAPON_CATALOG.AR].capacity),
        "reserve":90,"shots":0,"hits":0,"kills":0,"reload_pending":false,
        "reload_remaining":0.0,"reloads":0,"fire_clock":0.0,"audio_seq":0,
        "medkits":0,"loot_claims":0,"heal_pending":false,"heal_remaining":0.0,
        "heal_anchor":home,"heal_completed":0,"heal_cancelled":0,"heal_gained":0.0,
        "slot":slot,"weapon":WEAPON_CATALOG.AR,"awm_owned":false,
        "stored_ar":30,"stored_ar_reserve":90,"stored_awm":0,"stored_awm_reserve":0,
        "aim":false,"stance_pending":0,"switch_ms":-1000,"backpack":0,"zone_hits":0,"bot_hits":0,"bot_damage":0,"bot_loot_claims":0,"bot_loot_rounds":0,"ambient_seq":0,"ambient":[],
        "flight_jumped":false,"flight_canopy":false,"flight_landed":false,"flight_pending":false,
        "catalog_owned":[WEAPON_CATALOG.AR],"catalog_mags":{WEAPON_CATALOG.AR:30},
        "catalog_reserves":{WEAPON_CATALOG.AR:90},"catalog_switches":0,
        "grenades":0,"covers":0,"cover_clock":0.0,"tactical_ms":-1000,"tactical_pending":0,
        "throws":0,"walls":0,"vehicle_result":"","online_sub":str(_internet_users.get(id,""))}
    _dual_admitted+=1
    if not room_flexible and dual_loot and dual_peers.size()==room_capacity:
        if terrain_room:
            _terrain_ready=not mixed_room
            if not mixed_flight:
                _spawn_terrain_loot()
            if mixed_room:
                combat.encounter_size=MIXED_BOTS+1
        else:
            _spawn_dual_loot()
    print("V75237_SERVER_ADMIT peer=",id," live_humans=",dual_peers.size())

# Reuse the established map's terrain checks instead of spawning bodies
# on arbitrary coordinates or adding an invisible test platform.
func _choose_terrain_sites() -> Array[Vector2]:
    var result: Array[Vector2]=[]
    for slot in range(room_capacity):
        # Outer starting point is deliberately outside the opening circle;
        # only the explicit CI fixture uses this to exercise zone damage.
        var qa_outer: bool=slot==0 and OS.get_environment("AURORA_TERRAIN_QA")=="1"
        var found: bool=false
        for i in range(128):
            var angle: float=float(slot)*TAU/float(room_capacity)+float(i)*.39
            var distance: float=250.0+float(i%10)*1.5 if qa_outer else 38.0+float(i%15)*3.0
            var site: Vector2=director.CENTER+Vector2.from_angle(angle)*distance
            var valid: bool=combat._is_clear_spawn(site)
            if qa_outer:
                # Existing clear-spawn helper may cap at the initial ring.
                # Require real land, moderate slopes and terrain height.
                var h: float=director.terrain.height_at(site.x,site.y)
                valid=h>float(director.terrain.sea_level)+1.0 and absf(director.terrain.height_at(site.x+1.5,site.y)-director.terrain.height_at(site.x-1.5,site.y))<2.0 and absf(director.terrain.height_at(site.x,site.y+1.5)-director.terrain.height_at(site.x,site.y-1.5))<2.0
            if not valid:
                continue
            var separated: bool=true
            for old in result:
                separated=separated and old.distance_to(site)>20.0
            if separated:
                result.append(site)
                found=true
                break
        if not found:
            return []
    return result

func _spawn_terrain_loot() -> void:
    for slot in range(_terrain_sites.size()):
        var site: Vector2=_terrain_sites[slot]
        for item in [{"kind":"ammo_ar","amount":45,"offset":Vector2(3,0)},
                {"kind":"medkit","amount":1,"offset":Vector2(0,3)}]:
            var at: Vector2=site+item.offset
            if combat._is_clear_spawn(at):
                _spawn_room_pickup(str(item.kind),Vector3(at.x,director.terrain.height_at(at.x,at.y),at.y),int(item.amount))
    if room_tactical and OS.get_environment("AURORA_MIXED_QA")!="1" and OS.get_environment("AURORA_MIXED_LOOT_QA")!="1" and OS.get_environment("AURORA_MIXED_FLIGHT_QA")!="1":
        for site in _terrain_sites:
            for item in [{"kind":"grenade","offset":Vector2(-4,2)},{"kind":"cover_charge","offset":Vector2(4,-2)},{"kind":"vest_2","offset":Vector2(-5,-3)},{"kind":"helmet_2","offset":Vector2(5,3)},{"kind":"backpack","offset":Vector2(0,-5)}]:
                var spot: Vector2=site+item.offset
                if combat._is_clear_spawn(spot):
                    _spawn_room_pickup(str(item.kind),Vector3(spot.x,director.terrain.height_at(spot.x,spot.y),spot.y),1)
    if catalog_room and OS.get_environment("AURORA_MIXED_QA")!="1" and OS.get_environment("AURORA_MIXED_LOOT_QA")!="1" and OS.get_environment("AURORA_MIXED_FLIGHT_QA")!="1":
        var spawned: int=0
        for slot in _catalog_available:
            if slot==WEAPON_CATALOG.AR:
                continue
            var site: Vector2=_terrain_sites[spawned%_terrain_sites.size()]
            for attempt in range(24):
                var at: Vector2=site+Vector2.from_angle(float(spawned)*2.4+float(attempt)*.6)*(7.0+float(spawned/4)*4.0)
                if combat._is_clear_spawn(at):
                    _spawn_room_pickup("weapon_awm" if slot==WEAPON_CATALOG.AWM else str(WEAPON_CATALOG.ENTRIES[slot].pickup),Vector3(at.x,director.terrain.height_at(at.x,at.y),at.y),1)
                    var ammo_at: Vector2=at+Vector2(2.5,0)
                    var ammo_kind: String=_catalog_ammo_kind(slot)
                    if not ammo_kind.is_empty() and combat._is_clear_spawn(ammo_at):
                        _spawn_room_pickup(ammo_kind,Vector3(ammo_at.x,director.terrain.height_at(ammo_at.x,ammo_at.y),ammo_at.y),_catalog_pickup_amount(ammo_kind))
                    break
            spawned+=1
    print("V75243_TERRAIN_READY humans=",dual_peers.size()," radius=",_room_zone.radius," sites=",_terrain_sites.size())

func _stage_mixed_roster() -> void:
    # Stage the original CharacterBody3D agents in small batches. No fake
    # counters and no second combat simulation on clients.
    combat._ensure_encounter_capacity(3)
    for bot in combat._targets:
        bot.set_physics_process(false)
        bot.collision_layer=0
    if combat._targets.size()!=room_bot_target:
        return
    _mixed_bots.assign(combat._targets)
    var foes: Array[CharacterBody3D]=[]
    foes.assign(_mixed_bots)
    for peer in dual_peers.values():
        if peer.actor!=operator:
            foes.append(peer.actor)
    if OS.get_environment("AURORA_MIXED_QA")=="1" or OS.get_environment("AURORA_MIXED_LOOT_QA")=="1":
        # Place one REAL bot on clear terrain near slot 1 for the network
        # interaction regression, not for normal match population.
        var site: Vector2=_terrain_sites[1]
        var toward: Vector2=(director.CENTER-site).normalized()
        var shooter: CharacterBody3D=null
        for participant in dual_peers.values():
            if int(participant.slot)==1:
                shooter=participant.actor
                break
        var found_clear: bool=false
        if is_instance_valid(shooter):
            var origin: Vector3=shooter.global_position+Vector3.UP*1.35
            for step in range(64):
                var near: Vector2=site+toward.rotated(float(step%32)*TAU/32.0)*(5.5+float(step/32)*2.0)
                if not combat._is_clear_spawn(near):
                    continue
                var at:=Vector3(near.x,director.terrain.height_at(near.x,near.y)+1.15,near.y)
                if absf(at.y-origin.y)>1.2:
                    continue
                var ray:=PhysicsRayQueryParameters3D.create(origin,at)
                ray.exclude=[shooter.get_rid()]
                ray.collision_mask=1
                if not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
                    continue
                var separated: bool=true
                for rival in _mixed_bots:
                    if rival!=_mixed_bots[0] and near.distance_squared_to(rival.spawn_coordinates)<3.0*3.0:
                        separated=false
                        break
                if not separated:
                    continue
                _mixed_bots[0].set_match_spawn(near)
                _mixed_bots[0].weapon_slot=WEAPON_CATALOG.AR
                var offset: Vector3=at-origin
                var heading: float=atan2(-offset.x,-offset.z)
                shooter._yaw=heading
                shooter._desired_yaw=heading
                shooter.rotation.y=heading
                for participant in dual_peers.values():
                    if participant.actor==shooter:
                        participant.yaw=heading
                found_clear=true
                print("V75247_QA_CLEAR_TARGET at=",near," heading=",heading)
                break
        if not found_clear:
            push_warning("V75247 QA could not establish an unobstructed nearby bot start")
    for i in range(_mixed_bots.size()):
        var bot: CharacterBody3D=_mixed_bots[i]
        bot.set_meta("online_team",ceili(4.0/float(room_team_size))+floori(float(i)/float(room_team_size)) if room_team_size>1 else -1)
        if mixed_flight:
            # Keep the original map anchor for later physical descent.
            # Staging movement uses a separate island position.
            bot.health=bot.MAX_HEALTH
            bot.collision_layer=1
            bot.sector_battle=false
            bot.cancel_real_airdrop()
            var ring: int=0 if i<16 else 1
            var idx: int=i if ring==0 else i-16
            var count: int=16 if ring==0 else room_bot_target-16
            var angle: float=TAU*float(idx)/float(count)
            var radius: float=13.0 if ring==0 else 19.0
            var home: Vector3=WAITING_ISLAND.SPAWN+Vector3(sin(angle)*radius,-.15,-cos(angle)*radius)
            bot.begin_waiting_walk(home,Vector3(cos(angle),0,sin(angle)),i)
            var marker: Label3D=bot.get_node_or_null("TrainingTargetMarker")
            if marker!=null:
                marker.hide()
        else:
            bot.configure_sector_battle(foes)
        bot.safe_center=_room_zone.center
        bot.safe_radius=float(_room_zone.radius)
        bot.human_damaged.connect(_mixed_on_human_damage)
        bot.weapon_fired.connect(_mixed_on_bot_shot.bind(bot))
        bot.eliminated.connect(_mixed_on_bot_dead)
    _mixed_ready=true
    _terrain_ready=not mixed_flight
    if not mixed_flight and room_tactical and not room_vehicle_ready:
        room_vehicle_ready=true
        director.call_deferred("_spawn_authentic_vehicles")
    var physical: int=0
    for bot in _mixed_bots:
        if bot.is_physics_processing() and bot.collision_layer==1 and bot.health==bot.MAX_HEALTH:
            physical+=1
    print("V75244_MIXED_READY humans=",dual_peers.size()," physical_bots=",physical," total=",_living_room_count())
    if OS.get_environment("AURORA_MIXED_QA")=="1" or OS.get_environment("AURORA_MIXED_LOOT_QA")=="1":
        # Give the test client time for its first real replicated contact;
        # this does not disable the bot, its movement, or its hit collider.
        _mixed_bots[0]._attack_clock=2.5
    if OS.get_environment("AURORA_MIXED_LOOT_QA")=="1":
        # Separate QA room: one wounded original bot, real shots required.
        # The ordinary 50-full-health combat regression remains unchanged.
        _mixed_bots[0].health=26.0
        _mixed_bots[0]._attack_clock=4.0
        _mixed_bots[0]._magazine=18

func _mixed_route(progress: float) -> Vector3:
    return Vector3(0,ROOM_FLIGHT.FLIGHT_ALTITUDE,lerpf(ROOM_FLIGHT.ROUTE_START_Z,ROOM_FLIGHT.ROUTE_END_Z,clampf(progress,0.0,1.0)))

func _mixed_depart() -> void:
    if not mixed_flight or _mixed_phase!="waiting" or _dual_finished or not _mixed_ready:
        return
    _mixed_phase="aircraft"
    _mixed_flight_elapsed=0.0
    # Place actual world supplies before the first touchdown. Airborne
    # clients cannot claim them and do not receive their pickup snapshots.
    _spawn_terrain_loot()
    for peer in dual_peers.values():
        var actor: CharacterBody3D=peer.actor
        actor.begin_aircraft()
        actor.global_position=_mixed_route(0.0)
        actor.collision_layer=0
        actor.collision_mask=0
        peer.axis=Vector2.ZERO
        peer.fire=false
        peer.jump_pending=false
    for i in range(_mixed_bots.size()):
        var bot: CharacterBody3D=_mixed_bots[i]
        bot.end_waiting_walk()
        var progress: float=float(i%23)/23.0
        var origin: Vector3=_mixed_route(progress)+Vector3(float(i%5-2)*2.3,0,0)
        # Original authored descent, staggered along the actual flight.
        bot.begin_real_airdrop(origin,progress*ROOM_FLIGHT.FLIGHT_SECONDS+.4)
    if is_instance_valid(waiting_island):
        waiting_island.hide()
        waiting_island.queue_free()
    waiting_island=null
    print("V75246_DEPART humans=",dual_peers.size()," bots=",_mixed_bots.size())

func _mixed_air_action(id: int) -> void:
    if not dual_peers.has(id) or _mixed_phase!="aircraft":
        return
    var peer: Dictionary=dual_peers[id]
    peer.flight_pending=false
    var actor: CharacterBody3D=peer.actor
    if actor.royale_eliminated:
        return
    if actor.air_mode=="aircraft":
        # Keep players physically separate during the first falling step.
        actor.global_position+=Vector3(float(peer.slot-1.5)*1.2,0,0)
        actor.collision_layer=1
        actor.collision_mask=1
        actor.begin_freefall(Vector3(0,0,(ROOM_FLIGHT.ROUTE_END_Z-ROOM_FLIGHT.ROUTE_START_Z)/ROOM_FLIGHT.FLIGHT_SECONDS))
        peer.flight_jumped=true
        peer.action_applied+=1
        print("V75246_JUMP slot=",peer.slot," at=",actor.global_position)
    elif actor.air_mode=="freefall":
        actor.deploy_parachute()
        peer.flight_canopy=true
        peer.action_applied+=1
        print("V75246_CANOPY slot=",peer.slot)

func _mixed_enable_ground() -> void:
    if _early_ground_started:
        return
    _early_ground_started=true
    _terrain_ready=true
    if room_tactical and not room_vehicle_ready:
        room_vehicle_ready=true
        director.call_deferred("_spawn_authentic_vehicles")
    print("V75247_GROUND_OPEN elapsed=",_mixed_flight_elapsed," bots_landed=",_mixed_landed_bots)

func _mixed_activate_bot(bot: CharacterBody3D) -> void:
    if not is_instance_valid(bot) or _dual_finished or _mixed_ground_bots.has(bot.get_instance_id()) or bot._airdrop_stage!="landed":
        return
    var foes: Array[CharacterBody3D]=[]
    foes.assign(_mixed_bots)
    for peer in dual_peers.values():
        if peer.actor!=operator:
            foes.append(peer.actor)
    # Preserve the true landing position. Activate exactly once; a later
    # arrival must never reset this bot's health or inventory.
    bot.online_ground_only=true
    bot.configure_sector_battle(foes,true)
    bot.safe_center=_room_zone.center
    bot.safe_radius=float(_room_zone.radius)
    _mixed_ground_bots[bot.get_instance_id()]=true
    _mixed_enable_ground()

func _mixed_complete_deployment() -> void:
    if _mixed_phase!="aircraft" or _dual_finished:
        return
    _mixed_phase="sector_battle"
    # Individual combat already runs. Do not reset health, ammo, input,
    # zone clock, bot state or spawn the supplies a second time.
    print("V75246_GROUND humans=",dual_peers.size()," bots_landed=",_mixed_landed_bots," total=",dual_peers.size()+_mixed_bots.size()," alive=",_living_room_count())
    print("V75247_DEPLOY_COMPLETE early_shots=",_early_ground_shots," early_claims=",_early_ground_claims)

func _peer_ground_ready(peer: Dictionary) -> bool:
    return not mixed_flight or (bool(peer.flight_landed) and peer.actor.air_mode=="ground")

func _human_ground_ready(actor: CharacterBody3D) -> bool:
    if not mixed_flight:
        return true
    for peer in dual_peers.values():
        if peer.actor==actor:
            return _peer_ground_ready(peer)
    return false

func _mixed_flight_tick(delta: float) -> void:
    if not mixed_flight or not _mixed_ready or _dual_finished:
        return
    if _mixed_phase=="waiting":
        _mixed_wait=maxf(0.0,_mixed_wait-delta)
        if _mixed_wait<=0.0 and not _mixed_depart_pending:
            _mixed_depart_pending=true
            call_deferred("_mixed_depart")
        return
    if _mixed_phase!="aircraft":
        return
    _mixed_flight_elapsed+=delta
    var all_humans: bool=true
    for id in dual_peers:
        var peer: Dictionary=dual_peers[id]
        var actor: CharacterBody3D=peer.actor
        if actor.air_mode=="aircraft":
            actor.global_position=_mixed_route(_mixed_flight_elapsed/ROOM_FLIGHT.FLIGHT_SECONDS)
            if _mixed_flight_elapsed>=ROOM_FLIGHT.FLIGHT_SECONDS and not bool(peer.flight_pending):
                peer.flight_pending=true
                call_deferred("_mixed_air_action",int(id))
        elif actor.air_mode=="freefall":
            var clearance: float=actor.global_position.y-director.terrain.height_at(actor.global_position.x,actor.global_position.z)
            if clearance<ROOM_FLIGHT.AUTO_PARACHUTE_CLEARANCE_M and not bool(peer.flight_pending):
                peer.flight_pending=true
                call_deferred("_mixed_air_action",int(id))
        if actor.air_mode=="ground" and bool(peer.flight_jumped):
            if not bool(peer.flight_landed):
                peer.flight_landed=true
                actor._training_immunity=0.0
                peer.fire=false
                peer.jump_pending=false
                _mixed_enable_ground()
                print("V75246_LAND slot=",peer.slot," at=",actor.global_position)
                print("V75247_HUMAN_GROUND slot=",peer.slot," flight_elapsed=",_mixed_flight_elapsed)
                if OS.get_environment("AURORA_MIXED_FLIGHT_QA")=="1" and int(peer.slot)==0:
                    # QA-only physical ammunition cache near the actual
                    # touchdown, never a synthetic inventory grant.
                    var at: Vector3=actor.global_position+Vector3(2.8,0,0)
                    var surface: float=_death_surface(at,actor)
                    call_deferred("_spawn_room_pickup","ammo_ar",at,45,false,surface,false)
        else:
            all_humans=false
    for bot in _mixed_bots:
        if bot._airdrop_stage=="landed" and not _mixed_ground_bots.has(bot.get_instance_id()):
            _mixed_activate_bot(bot)
    _mixed_landed_bots=_mixed_ground_bots.size()
    if all_humans and _mixed_landed_bots==room_bot_target and not _mixed_battle_pending:
        _mixed_battle_pending=true
        call_deferred("_mixed_complete_deployment")

func _mixed_on_bot_shot(at: Vector3,bot: CharacterBody3D) -> void:
    if not _mixed_ready or _dual_finished:
        return
    _mixed_bot_shots+=1
    for peer in dual_peers.values():
        if peer.actor.royale_eliminated or peer.actor.global_position.distance_squared_to(at)>150.0*150.0 or peer.ambient.size()>=12:
            continue
        peer.ambient_seq+=1
        peer.ambient.append({"seq":peer.ambient_seq,"kind":"remote_shot","sample":"","at":at.snapped(Vector3(4,2,4)),"run":false,"stone":false})
    for other in _mixed_bots:
        if is_instance_valid(other) and other.health>0.0:
            other.hear_gunshot(at,bot)

func _mixed_on_human_damage(victim: CharacterBody3D,amount: float) -> void:
    if not _mixed_ready or _dual_finished or amount<=0.0:
        return
    for id in dual_peers:
        var peer: Dictionary=dual_peers[id]
        if peer.actor!=victim:
            continue
        peer.bot_damage+=1
        _mixed_human_damage+=1
        _dual_cancel_heal(peer,"bot_damage")
        _dual_sound(int(id),"local","hit")
        if peer.bot_damage==1:
            print("V75244_BOT_HUMAN slot=",peer.slot," hp=",victim.training_health)
        if victim.royale_eliminated:
            _queue_death_loot(peer)
            victim.set_deferred("collision_layer",0)
            victim.set_deferred("collision_mask",0)
            victim.hide()
            _finish_room_if_needed()
        return

func _mixed_on_bot_dead(bot: CharacterBody3D,killer: Node3D) -> void:
    if not _mixed_ready or _dual_finished or _mixed_bot_dead.has(bot.get_instance_id()):
        return
    _mixed_bot_dead[bot.get_instance_id()]=true
    _queue_bot_death_loot(bot,killer)
    for peer in dual_peers.values():
        if peer.actor==killer:
            peer.kills+=1
            break
    _finish_room_if_needed()

func _same_team(a: Node,b: Node) -> bool:
    if room_team_size<=1 or not is_instance_valid(a) or not is_instance_valid(b) or a==b:
        return false
    var team: int=int(a.get_meta("online_team",-1))
    return team>=0 and team==int(b.get_meta("online_team",-1))

func _living_teams() -> Array[int]:
    var teams: Array[int]=[]
    for peer in dual_peers.values():
        if not peer.actor.royale_eliminated:
            var team: int=int(peer.actor.get_meta("online_team",-1))
            if not teams.has(team):
                teams.append(team)
    for bot in _mixed_bots:
        if is_instance_valid(bot) and bot.health>0.0:
            var team: int=int(bot.get_meta("online_team",-1))
            if not teams.has(team):
                teams.append(team)
    return teams

func _room_active() -> bool:
    return _admission_complete() and not _dual_finished and (not mixed_room or _mixed_ready) and (not mixed_flight or _early_ground_started) and (_living_teams().size()>1 if room_team_size>1 else _living_room_count()>1)

func _terrain_zone_tick(delta: float) -> void:
    if not terrain_room or not _terrain_ready or not _room_active():
        return
    _room_elapsed+=delta
    # Accelerated clock is isolated to a server environment fixture.
    # The normal room uses the existing ten-minute schedule unchanged.
    var clock: float=_room_elapsed*(12.0 if OS.get_environment("AURORA_TERRAIN_QA")=="1" else 1.0)
    _room_zone=director.zone_state_at(clock)
    if mixed_room:
        for bot in _mixed_bots:
            if is_instance_valid(bot) and bot.health>0.0:
                bot.safe_center=_room_zone.center
                bot.safe_radius=float(_room_zone.radius)
                bot.zone_seconds_remaining=int(_room_zone.remaining)
    _room_damage_clock+=delta
    if _room_damage_clock<1.0:
        return
    _room_damage_clock=fmod(_room_damage_clock,1.0)
    var phase: int=int(_room_zone.phase)
    var damage: float=6.0 if phase==0 else (8.0 if phase==1 else (10.0 if phase==2 else 13.0))
    if clock>=director.SHRINK_DURATION:
        damage=13.0+clampf(clock-director.SHRINK_DURATION,0.0,director.OVERTIME_DURATION)*.15
    for peer in dual_peers.values():
        var actor: CharacterBody3D=peer.actor
        if actor.royale_eliminated or not _peer_ground_ready(peer):
            continue
        var at:=Vector2(actor.global_position.x,actor.global_position.z)
        if at.distance_to(_room_zone.center)<=float(_room_zone.radius):
            continue
        var before: float=actor.training_health
        actor.receive_training_hit(damage,true)
        if actor.training_health<before:
            peer.zone_hits+=1
            _dual_cancel_heal(peer,"zone")
            if peer.zone_hits==1:
                print("V75243_ZONE_HIT slot=",peer.slot," hp=",actor.training_health," phase=",phase)
        if actor.royale_eliminated:
            _queue_death_loot(peer)
            actor.collision_layer=0
            actor.collision_mask=0
            actor.hide()
            print("V75243_ZONE_ELIMINATION slot=",peer.slot)
    if mixed_room:
        for bot in _mixed_bots:
            if is_instance_valid(bot) and bot.health>0.0 and (not mixed_flight or _mixed_ground_bots.has(bot.get_instance_id())) and Vector2(bot.global_position.x,bot.global_position.z).distance_to(_room_zone.center)>float(_room_zone.radius):
                bot.take_training_damage(damage)
    _finish_room_if_needed()

func _terrain_contact(observer: CharacterBody3D,target: CharacterBody3D) -> bool:
    var offset: Vector3=target.global_position-observer.global_position
    if offset.length_squared()>80.0*80.0:
        return false
    var horizontal:=Vector2(offset.x,offset.z)
    var forward:=Vector2(-sin(observer._yaw),-cos(observer._yaw))
    if horizontal.length_squared()>1.0 and horizontal.normalized().dot(forward)<.30:
        return false
    var ray:=PhysicsRayQueryParameters3D.create(observer.global_position+Vector3.UP*1.4,target.global_position+Vector3.UP*(.85 if target.has_method("receive_training_hit") and target._crouching else 1.1))
    ray.exclude=[observer.get_rid()]
    ray.collision_mask=1
    return world.get_world_3d().direct_space_state.intersect_ray(ray).get("collider")==target

func _living_room_count() -> int:
    var alive: int=0
    for peer in dual_peers.values():
        if not peer.actor.royale_eliminated:
            alive+=1
    if mixed_room:
        for bot in _mixed_bots:
            if is_instance_valid(bot) and bot.health>0.0:
                alive+=1
    return alive

func _spawn_room_pickup(kind: String,at: Vector3,amount: int,death: bool=false,surface: float=NAN,bot_drop: bool=false) -> void:
    var pickup: Area3D=SHARED_LOOT.new()
    pickup.pickup_type=kind
    pickup.quantity=amount
    pickup.from_opponent=death
    pickup.terrain=director.terrain
    pickup.world_spot=Vector2(at.x,at.z)
    pickup.surface_height_override=surface if is_finite(surface) else (director.terrain.height_at(at.x,at.z) if terrain_room else WAITING_ISLAND.SPAWN.y-.3)
    pickup.set_meta("mixed_bot_cache",bot_drop)
    pickup.shared_grant=Callable(self,"_grant_dual_loot").bind(death,bot_drop)
    world.add_child(pickup)
    _dual_loot_nodes.append(pickup)

func _spawn_dual_loot() -> void:
    # Actual existing Area3D pickups on the walkable shared deck.
    var items: Array=[{"kind":"ammo_ar","offset":Vector3(0,0,0),"amount":45},
            {"kind":"medkit","offset":Vector3(-5,0,-4),"amount":1},
            {"kind":"medkit","offset":Vector3(5,0,-4),"amount":1}]
    if expanded_room:
        items=[{"kind":"weapon_awm","offset":Vector3(-6,0,-3),"amount":1},
            {"kind":"ammo_awm","offset":Vector3(-6,0,-6),"amount":8},
            {"kind":"backpack","offset":Vector3(-9,0,-3),"amount":1},
            {"kind":"vest_2","offset":Vector3(6,0,3),"amount":1},
            {"kind":"helmet_2","offset":Vector3(6,0,6),"amount":1},
            {"kind":"medkit","offset":Vector3(9,0,6),"amount":1}]
    if catalog_room and OS.get_environment("AURORA_ONLINE_CATALOG_QA")=="1":
        items=[{"kind":"weapon_scar","offset":Vector3(-6,0,-3),"amount":1},
            {"kind":"weapon_mp40","offset":Vector3(-6,0,-6),"amount":1},
            {"kind":"weapon_p90","offset":Vector3(-9,0,-6),"amount":1},
            {"kind":"ammo_smg","offset":Vector3(-9,0,-3),"amount":30},
            {"kind":"ammo_ar","offset":Vector3(-9,0,0),"amount":45}]
    if OS.get_environment("AURORA_ONLINE_TACTICAL_QA")=="1":
        items=[{"kind":"grenade","offset":Vector3(-6,0,-3),"amount":1},
            {"kind":"cover_charge","offset":Vector3(-6,0,-6),"amount":1}]
    for item in items:
        _spawn_room_pickup(str(item.kind),WAITING_ISLAND.SPAWN+item.offset,int(item.amount))

func _death_surface(at: Vector3,victim: CharacterBody3D) -> float:
    if not terrain_room:
        return WAITING_ISLAND.SPAWN.y-.3
    var ground: float=director.terrain.height_at(at.x,at.z)
    # Only actual support close to the fallen body is accepted. Airborne
    # deaths settle onto terrain, not an arbitrary elevated ray contact.
    if at.y>=ground-.25 and at.y-ground<40.0:
        var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.35,Vector3(at.x,ground-2.0,at.z))
        ray.collision_mask=3
        ray.exclude=[victim.get_rid()]
        var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
        if not hit.is_empty() and hit.get("collider") is StaticBody3D:
            var point: Vector3=hit.position
            var normal: Vector3=hit.normal
            if normal.y>.55 and point.y>=ground-.15 and point.y<=at.y+.35 and at.y-point.y<=1.25:
                return point.y
    return ground

func _catalog_ammo_kind(slot: int) -> String:
    match WEAPON_CATALOG.reserve_slot(slot):
        WEAPON_CATALOG.AR: return "ammo_ar"
        WEAPON_CATALOG.AWM: return "ammo_awm"
        WEAPON_CATALOG.MP40: return "ammo_smg"
        WEAPON_CATALOG.SHOTGUN: return "ammo_shells"
        WEAPON_CATALOG.MAGNUM: return "ammo_pistol"
    return ""

func _catalog_pickup_amount(kind: String) -> int:
    match kind:
        "ammo_ar": return 45
        "ammo_awm": return 8
        "ammo_smg": return 30
        "ammo_shells": return 16
        "ammo_pistol": return 24
    return 0

func _catalog_reserve(peer: Dictionary,family: int) -> int:
    if WEAPON_CATALOG.reserve_slot(int(peer.weapon))==family:
        return int(peer.reserve)
    return int(peer.catalog_reserves.get(family,0))

func _catalog_set_reserve(peer: Dictionary,family: int,value: int) -> void:
    peer.catalog_reserves[family]=value
    if WEAPON_CATALOG.reserve_slot(int(peer.weapon))==family:
        peer.reserve=value

func _catalog_next(peer: Dictionary) -> int:
    var owned: Array=peer.catalog_owned
    return int(owned[(owned.find(int(peer.weapon))+1)%owned.size()])

func _catalog_additions(peer: Dictionary) -> Dictionary:
    var result: Dictionary={}
    for slot in peer.catalog_owned:
        if int(slot)>=WEAPON_CATALOG.SCAR:
            result[slot]={"loaded":int(peer.ammo) if int(peer.weapon)==int(slot) else int(peer.catalog_mags.get(slot,0)),
                "reserve":_catalog_reserve(peer,WEAPON_CATALOG.reserve_slot(int(slot)))}
    return result

func _catalog_claim(peer: Dictionary,kind: String,quantity: int) -> int:
    var slot: int=WEAPON_CATALOG.AWM if kind=="weapon_awm" else WEAPON_CATALOG.pickup_slot(kind)
    if slot>=0:
        if not _catalog_available.has(slot) or peer.catalog_owned.has(slot):
            return -1
        peer.catalog_owned.append(slot)
        peer.catalog_owned.sort()
        peer.catalog_mags[slot]=int(WEAPON_CATALOG.ENTRIES[slot].capacity)
        if slot==WEAPON_CATALOG.AWM:
            peer.awm_owned=true
        print("V75248_OWN slot=",peer.slot," weapon=",slot," owned=",peer.catalog_owned)
        return 0
    var family: int=-1
    match kind:
        "ammo_ar": family=WEAPON_CATALOG.AR
        "ammo_awm": family=WEAPON_CATALOG.AWM
        "ammo_smg": family=WEAPON_CATALOG.MP40
        "ammo_shells": family=WEAPON_CATALOG.SHOTGUN
        "ammo_pistol": family=WEAPON_CATALOG.MAGNUM
    if family<0:
        return -1
    # Preserve original AR/AWM pickup behavior; other families require
    # ownership of a weapon that consumes the corresponding reserve.
    if family!=WEAPON_CATALOG.AR and family!=WEAPON_CATALOG.AWM:
        var owned_family: bool=false
        for index in peer.catalog_owned:
            owned_family=owned_family or WEAPON_CATALOG.reserve_slot(int(index))==family
        if not owned_family:
            return -1
    var capacity: int=180+int(peer.backpack)*45 if family==WEAPON_CATALOG.AR else (30+int(peer.backpack)*8 if family==WEAPON_CATALOG.AWM else combat.reserve_capacity_by_level(family,int(peer.backpack)))
    var stock: int=_catalog_reserve(peer,family)
    var amount: int=mini(clampi(quantity,0,_catalog_pickup_amount(kind)),maxi(0,capacity-stock))
    if amount<=0:
        return -1
    _catalog_set_reserve(peer,family,stock+amount)
    return amount

func _queue_bot_death_loot(bot: CharacterBody3D,killer: Node3D) -> void:
    var at: Vector3=bot.global_position
    if not at.is_finite() or Vector2(at.x,at.z).distance_to(_room_zone.center)>float(_room_zone.radius):
        return
    var rounds: int=maxi(0,int(bot._magazine))
    var kits: int=clampi(int(bot._field_medkits),0,1)
    var kind: String=""
    var amount: int=0
    # Do not convert unrelated SMG/shotgun ammunition into AR rounds.
    # The two currently implemented human ammunition families are exact.
    if rounds>0 and int(bot.weapon_slot)==WEAPON_CATALOG.AR:
        kind="ammo_ar"
        amount=mini(rounds,18)
    elif rounds>0 and int(bot.weapon_slot)==WEAPON_CATALOG.AWM:
        kind="ammo_awm"
        amount=mini(rounds,8)
    elif catalog_room and rounds>0 and not _catalog_ammo_kind(int(bot.weapon_slot)).is_empty():
        kind=_catalog_ammo_kind(int(bot.weapon_slot))
        amount=mini(rounds,mini(18,_catalog_pickup_amount(kind)))
    elif kits>0:
        kind="medkit"
        amount=kits
    if amount<=0:
        return
    var human_kill: bool=false
    for peer in dual_peers.values():
        human_kill=human_kill or peer.actor==killer
    _death_pending.append({"kind":kind,"at":at,"amount":amount,"surface":_death_surface(at,bot),
        "bot":true,"human_kill":human_kill})
    # Only the actual one-time inventory reward survives elimination.
    bot._magazine=0
    bot._field_medkits=0
    call_deferred("_flush_death_loot")

func _active_room_deaths() -> int:
    var active: int=0
    for pickup in _dual_loot_nodes:
        if is_instance_valid(pickup) and pickup.from_opponent and not pickup.collected and not pickup.is_queued_for_deletion():
            active+=1
    return active

func _distance_to_living_humans(at: Vector3) -> float:
    var nearest: float=INF
    for peer in dual_peers.values():
        if not peer.actor.royale_eliminated:
            nearest=minf(nearest,peer.actor.global_position.distance_squared_to(at))
    return nearest

func _retire_remote_room_cache(at: Vector3) -> bool:
    if _distance_to_living_humans(at)>38.0*38.0:
        return false
    var furthest: float=95.0*95.0
    var chosen: Area3D=null
    for pickup in _dual_loot_nodes:
        if not is_instance_valid(pickup) or not pickup.from_opponent or pickup.collected or pickup.is_queued_for_deletion():
            continue
        var distance: float=_distance_to_living_humans(pickup.global_position)
        if distance>furthest:
            chosen=pickup
            furthest=distance
    if chosen==null:
        return false
    _dual_loot_nodes.erase(chosen)
    chosen.hide()
    chosen.queue_free()
    _death_retired+=1
    return true

func _queue_death_loot(peer: Dictionary) -> void:
    if not expanded_room:
        return
    var at: Vector3=peer.actor.global_position
    if not at.is_finite():
        return
    var ar_reserve: int=_catalog_reserve(peer,WEAPON_CATALOG.AR) if catalog_room else (int(peer.reserve) if int(peer.weapon)==WEAPON_CATALOG.AR else int(peer.stored_ar_reserve))
    if ar_reserve>0:
        var spot: Vector3=at+Vector3(.8,0,0)
        _death_pending.append({"kind":"ammo_ar","at":spot,"amount":mini(ar_reserve,18),"surface":_death_surface(spot,peer.actor)})
    if int(peer.medkits)>0:
        var spot: Vector3=at+Vector3(-.8,0,0)
        _death_pending.append({"kind":"medkit","at":spot,"amount":1,"surface":_death_surface(spot,peer.actor)})
    # No second claim from the victim. Drop bounded amounts, discard remainder.
    peer.medkits=0
    peer.reserve=0
    peer.stored_ar_reserve=0
    peer.stored_awm_reserve=0
    peer.catalog_reserves.clear()
    call_deferred("_flush_death_loot")

func _flush_death_loot() -> void:
    if _dual_finished:
        _death_pending.clear()
        return
    # Prioritize real nearby kills if multiple deaths share one frame.
    _death_pending.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return _distance_to_living_humans(a.at)<_distance_to_living_humans(b.at))
    for item in _death_pending:
        if _active_room_deaths()>=ROOM_DEATH_CAP and not _retire_remote_room_cache(item.at):
            continue
        var bot_drop: bool=bool(item.get("bot",false))
        _spawn_room_pickup(str(item.kind),item.at,int(item.amount),true,float(item.get("surface",NAN)),bot_drop)
        _death_spawned+=1
        _death_peak=maxi(_death_peak,_active_room_deaths())
        if bot_drop:
            _bot_death_spawned+=1
            print("V75245_BOT_DROP kind=",item.kind," amount=",item.amount," human_kill=",item.human_kill," active=",_active_room_deaths()," cumulative=",_death_spawned)
        print("V75242_DEATH_DROP kind=",item.kind," total=",_death_spawned)
    _death_pending.clear()
    # Trim freed nodes from the ledger; never count historical slots.
    for i in range(_dual_loot_nodes.size()-1,-1,-1):
        if not is_instance_valid(_dual_loot_nodes[i]):
            _dual_loot_nodes.remove_at(i)

func _capture_internet_record(peer: Dictionary,abandoned: bool,won: bool) -> void:
    var sub: String=str(peer.online_sub)
    if not _internet_records.has(sub):
        return
    _internet_records[sub]={"sub":sub,"slot":peer.slot,"kills":clampi(int(peer.kills),0,49),
        "hits":clampi(int(peer.hits),0,100000),"won":won and not abandoned,"abandoned":abandoned}

func _emit_internet_result(completed: bool) -> void:
    if not room_internet or not room_sealed or _internet_result_emitted or _internet_records.is_empty():
        return
    _internet_result_emitted=true
    # Private process-to-worker envelope. Never part of gameplay snapshots.
    # A cancelled room has no winner; no competitive points are awarded.
    print("AURORA_ROOM_RESULT "+JSON.stringify({"room":_internet_room_id,"completed":completed,
        "seconds":clampi(roundi(_room_elapsed),0,7200),"records":_internet_records.values()}))

func _finish_room_if_needed() -> void:
    if not dual_combat or not _admission_complete() or _dual_finished or (mixed_room and not _mixed_ready):
        return
    if (_living_teams().size()>1 if room_team_size>1 else _living_room_count()>1):
        return
    if room_team_size>1 and _living_teams().size()==1:
        room_winner_team=_living_teams()[0]
    _dual_finished=true
    _dual_winner=0
    for id in dual_peers:
        var peer: Dictionary=dual_peers[id]
        if not peer.actor.royale_eliminated:
            _dual_winner=int(id)
        if peer.actor.vehicle_ride_active():
            peer.actor.force_vehicle_exit()
        peer.actor.reset_controls()
        peer.actor.round_finished=true
        peer.fire=false
    if mixed_room:
        for bot in _mixed_bots:
            if is_instance_valid(bot):
                if bot.health>0.0:
                    _mixed_winner_bot=true
                bot.set_physics_process(false)
    var records: Array[Dictionary]=[]
    for id in dual_peers:
        var peer: Dictionary=dual_peers[id]
        records.append({"slot":peer.slot,"team":int(peer.actor.get_meta("online_team",-1)),"kills":peer.kills,"hits":peer.hits,"survived":not peer.actor.royale_eliminated})
    room_result={"winner":_dual_winner,"winner_team":room_winner_team,"winner_bot":_mixed_winner_bot,"records":records,"seconds":_room_elapsed,"ranked":false}
    if room_internet:
        for peer in dual_peers.values():
            var won: bool=not peer.actor.royale_eliminated
            if room_team_size>1:
                won=room_winner_team>=0 and int(peer.actor.get_meta("online_team",-1))==room_winner_team
            _capture_internet_record(peer,false,won)
        _emit_internet_result(true)
    print("V75242_ROOM_END winner=",_dual_winner," alive=",_living_room_count())

func _grant_dual_loot(body: Node3D,kind: String,quantity: int,death: bool=false,bot_drop: bool=false) -> bool:
    if not dual_loot or not _room_active():
        return false
    for id in dual_peers:
        var peer: Dictionary=dual_peers[id]
        if peer.actor!=body or not peer.actor.can_act() or not _peer_ground_ready(peer):
            continue
        var actual_rounds: int=0
        if catalog_room and (kind.begins_with("weapon_") or kind.begins_with("ammo_")):
            actual_rounds=_catalog_claim(peer,kind,quantity)
            if actual_rounds<0:
                return false
        else:
            match kind:
                "ammo_ar":
                    var current: bool=int(peer.weapon)==WEAPON_CATALOG.AR
                    var stock: int=int(peer.reserve) if current else int(peer.stored_ar_reserve)
                    var gained: int=mini(clampi(quantity,0,45),180+int(peer.backpack)*45-stock)
                    if gained<=0:
                        return false
                    actual_rounds=gained
                    if current:
                        peer.reserve+=gained
                    else:
                        peer.stored_ar_reserve+=gained
                "ammo_awm":
                    if not expanded_room:
                        return false
                    var current: bool=int(peer.weapon)==WEAPON_CATALOG.AWM
                    var stock: int=int(peer.reserve) if current else int(peer.stored_awm_reserve)
                    var gained: int=mini(clampi(quantity,0,8),30+int(peer.backpack)*8-stock)
                    if gained<=0:
                        return false
                    actual_rounds=gained
                    if current:
                        peer.reserve+=gained
                    else:
                        peer.stored_awm_reserve+=gained
                "weapon_awm":
                    if not expanded_room or bool(peer.awm_owned) or not ResourceLoader.exists("res://assets/weapons/aurora_awm.glb"):
                        return false
                    peer.awm_owned=true
                    peer.stored_awm=int(WEAPON_CATALOG.ENTRIES[WEAPON_CATALOG.AWM].capacity)
                "vest_1","vest_2","vest_3","helmet_1","helmet_2","helmet_3":
                    if not expanded_room or not peer.actor.equip_protection(kind.begins_with("helmet"),int(kind.get_slice("_",1))):
                        return false
                "backpack","backpack_2","backpack_3":
                    var level: int=1 if kind=="backpack" else int(kind.get_slice("_",1))
                    if not expanded_room or int(peer.backpack)>=level:
                        return false
                    peer.backpack=level
                    peer.actor.set_backpack_visual_level(level)
                "medkit":
                    if int(peer.medkits)>=5 or quantity!=1:
                        return false
                    peer.medkits+=1
                "grenade":
                    if not room_tactical or int(peer.grenades)>=3 or quantity!=1:
                        return false
                    peer.grenades+=1
                "cover_charge":
                    if not room_tactical or int(peer.covers)>=3 or quantity!=1:
                        return false
                    peer.covers+=1
                _:
                    return false
        peer.loot_claims+=1
        _dual_loot_claims+=1
        if mixed_flight and _mixed_phase=="aircraft":
            _early_ground_claims+=1
            print("V75247_EARLY_PICKUP slot=",peer.slot," kind=",kind," total=",_early_ground_claims)
        if bot_drop:
            _bot_death_claims+=1
            peer.bot_loot_claims+=1
            peer.bot_loot_rounds+=actual_rounds
            print("V75245_BOT_CLAIM peer=",id," slot=",peer.slot," kind=",kind," amount=",quantity," rounds_granted=",actual_rounds," total=",_bot_death_claims)
        if death:
            _death_claims+=1
            print("V75242_DEATH_CLAIM peer=",id," kind=",kind," total=",_death_claims)
        print("V75240_SERVER_CLAIM kind=",kind," peer=",id," total=",_dual_loot_claims," reserve=",peer.reserve," medkits=",peer.medkits)
        return true
    return false

func _dual_loot_snapshot(actor: CharacterBody3D) -> Array[Dictionary]:
    var result: Array[Dictionary]=[]
    if not dual_loot or _dual_finished or actor.royale_eliminated or not _human_ground_ready(actor):
        return result
    for pickup in _dual_loot_nodes:
        if not is_instance_valid(pickup) or pickup.collected or pickup.is_queued_for_deletion():
            continue
        if actor.global_position.distance_squared_to(pickup.global_position)<=LOOT_RANGE*LOOT_RANGE:
            result.append({"id":pickup.get_instance_id(),"position":pickup.global_position,
                "kind":pickup.pickup_type,"from_opponent":pickup.from_opponent,"quantity":pickup.quantity,
                "from_ai":bool(pickup.get_meta("mixed_bot_cache",false)),"distance_sq":actor.global_position.distance_squared_to(pickup.global_position)})
    result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.distance_sq)<float(b.distance_sq))
    if result.size()>MAX_LOOT_SNAPSHOT:
        result.resize(MAX_LOOT_SNAPSHOT)
    return result

func _dual_left(id: int) -> void:
    if not dual_peers.has(id):
        return
    var actor: CharacterBody3D=dual_peers[id].actor
    if room_internet and room_sealed and not _internet_result_emitted:
        _capture_internet_record(dual_peers[id],not actor.royale_eliminated,false)
    if actor.vehicle_ride_active():
        actor.force_vehicle_exit()
    actor.reset_controls()
    actor.royale_eliminated=true
    actor.set_physics_process(false)
    actor.collision_layer=0
    actor.collision_mask=0
    actor.hide()
    if mixed_room:
        var checked: int=0
        var remaining_refs: int=0
        for bot in _mixed_bots:
            if not is_instance_valid(bot):
                continue
            bot.forget_departed_foe(actor)
            checked+=1
            if bot._foes.has(actor) or bot._target_actor==actor or bot._last_attacker==actor:
                remaining_refs+=1
        print("V75245_DISCONNECT_CLEAN slot=",dual_peers[id].slot," bots_checked=",checked," remaining_refs=",remaining_refs)
    if room_flexible and not room_sealed:
        room_occupied_slots.erase(int(dual_peers[id].slot))
        _dual_admitted=maxi(0,_dual_admitted-1)
        print("V75250_QUEUE_RELEASE slot=",dual_peers[id].slot," remaining=",_dual_admitted)
    dual_peers.erase(id)
    if actor!=operator:
        actor.queue_free()
    print("V75237_SERVER_LEAVE peer=",id," remaining=",dual_peers.size())
    _finish_room_if_needed()
    if dual_peers.is_empty():
        if room_internet and room_sealed:
            _emit_internet_result(false)
        get_tree().quit()

func _dual_input(version: int,sequence: int,move: Vector2,heading: float,look_pitch: float,run: bool,shoot: bool) -> void:
    if not multiplayer.is_server():
        return
    var id: int=multiplayer.get_remote_sender_id()
    if not dual_peers.has(id):
        return
    var peer: Dictionary=dual_peers[id]
    if version!=PROTOCOL or sequence<=int(peer.sequence) or sequence-int(peer.sequence)>256 or not move.is_finite() or move.length_squared()>1.001 or not is_finite(heading) or absf(heading)>PI or not is_finite(look_pitch) or look_pitch<-.55 or look_pitch>.62 or (shoot and not dual_combat) or (dual_combat and (_dual_finished or peer.actor.royale_eliminated)):
        peer.rejected+=1
        return
    peer.sequence=sequence
    peer.accepted+=1
    peer.input_ms=Time.get_ticks_msec()
    peer.axis=move
    peer.yaw=heading
    peer.pitch=look_pitch
    peer.run=run
    # Keep steering packets valid during deployment but ignore held fire
    # until this human's actual touchdown has been committed.
    peer.fire=shoot and _peer_ground_ready(peer)

func _dual_action(version: int,request_id: int,action: int) -> void:
    if not multiplayer.is_server():
        return
    var id: int=multiplayer.get_remote_sender_id()
    if not dual_peers.has(id):
        return
    var peer: Dictionary=dual_peers[id]
    if version!=PROTOCOL or request_id<=int(peer.action_ack) or request_id-int(peer.action_ack)>256:
        peer.action_rejected+=1
        return
    peer.action_ack=request_id
    var now: int=Time.get_ticks_msec()
    if mixed_flight and not _peer_ground_ready(peer):
        if peer.actor.royale_eliminated or action!=ACTION_JUMP or now-int(peer.input_ms)>INPUT_TIMEOUT_MS or now-int(peer.jump_ms)<ACTION_MIN_INTERVAL_MS:
            peer.action_rejected+=1
            return
        peer.jump_ms=now
        if _mixed_phase=="waiting" and not bool(peer.jump_pending):
            peer.jump_pending=true
            return
        if _mixed_phase=="aircraft" and peer.actor.air_mode in ["aircraft","freefall"] and not bool(peer.flight_pending):
            peer.flight_pending=true
            call_deferred("_mixed_air_action",id)
            return
        peer.action_rejected+=1
        return
    if dual_combat and (not _room_active() or peer.actor.royale_eliminated):
        peer.action_rejected+=1
        return
    if room_tactical and action in [ACTION_GRENADE,ACTION_COVER,ACTION_VEHICLE]:
        if now-int(peer.input_ms)>INPUT_TIMEOUT_MS or now-int(peer.tactical_ms)<ACTION_MIN_INTERVAL_MS or int(peer.tactical_pending)!=0:
            peer.action_rejected+=1
            return
        peer.tactical_ms=now
        peer.tactical_pending=action
        return
    if expanded_room and action in [ACTION_NEXT_WEAPON,ACTION_AIM,ACTION_CROUCH,ACTION_STAND]:
        if now-int(peer.input_ms)>INPUT_TIMEOUT_MS or now-int(peer.switch_ms)<ACTION_MIN_INTERVAL_MS or not peer.actor.can_act() or int(peer.stance_pending)!=0:
            peer.action_rejected+=1
            return
        if action==ACTION_NEXT_WEAPON and ((peer.catalog_owned.size()<2 if catalog_room else not bool(peer.awm_owned)) or float(peer.reload_remaining)>0.0 or bool(peer.reload_pending)):
            peer.action_rejected+=1
            return
        peer.stance_pending=action
        peer.switch_ms=now
        return
    if dual_loot and action==ACTION_HEAL:
        if now-int(peer.input_ms)>INPUT_TIMEOUT_MS or bool(peer.heal_pending) or float(peer.heal_remaining)>0.0 or int(peer.medkits)<=0 or float(peer.actor.training_health)>=peer.actor.MAX_HEALTH or bool(peer.fire) or bool(peer.run) or (peer.axis as Vector2).length_squared()>.01 or float(peer.reload_remaining)>0.0 or bool(peer.reload_pending):
            peer.action_rejected+=1
            return
        peer.heal_pending=true
        return
    if dual_combat and action==ACTION_RELOAD:
        if now-int(peer.input_ms)>INPUT_TIMEOUT_MS or bool(peer.reload_pending) or float(peer.reload_remaining)>0.0 or int(peer.ammo)>=int(WEAPON_CATALOG.ENTRIES[int(peer.weapon)].capacity) or int(peer.reserve)<=0:
            peer.action_rejected+=1
            return
        peer.reload_pending=true
        return
    if action!=ACTION_JUMP or now-int(peer.input_ms)>INPUT_TIMEOUT_MS or now-int(peer.jump_ms)<ACTION_MIN_INTERVAL_MS or bool(peer.jump_pending):
        peer.action_rejected+=1
        return
    peer.jump_pending=true
    peer.jump_ms=now

# Minimal AR duel: server owns magazine, reload, cadence, ray and damage.
# No client hit claims or target IDs; the first actual physics collider wins.
# Per-recipient sequence space. The original single-player reliable audio
# channel is reused, never a broadcast containing another player's local cues.
func _dual_sound(recipient: int,kind: String,sample: String,at: Vector3=Vector3.ZERO) -> void:
    if not dual_peers.has(recipient) or not multiplayer.get_peers().has(recipient):
        return
    var peer: Dictionary=dual_peers[recipient]
    if kind.begins_with("duel_remote"):
        var maximum: float=150.0 if kind=="duel_remote_shot" else 26.0
        if not at.is_finite() or peer.actor.global_position.distance_squared_to(at)>maximum*maximum:
            return
        at=at.snapped(Vector3(4.0,2.0,4.0))
    peer.audio_seq+=1
    receive_critical_sound.rpc_id(recipient,PROTOCOL,{"seq":peer.audio_seq,"kind":kind,
        "sample":sample,"at":at,"run":false,"stone":false})

func _dual_sound_action(id: int,local_sample: String,remote_kind: String,at: Vector3) -> void:
    _dual_sound(id,"local",local_sample)
    for other_id in dual_peers:
        if other_id!=id:
            _dual_sound(int(other_id),remote_kind,local_sample,at)

func _dual_cancel_heal(peer: Dictionary,reason: String) -> void:
    if float(peer.heal_remaining)<=0.0:
        return
    peer.heal_remaining=0.0
    peer.heal_cancelled+=1
    peer.actor.cancel_medical_action()
    print("V75241_SERVER_HEAL_CANCEL reason=",reason," medkits=",peer.medkits)

func _apply_room_stance(peer: Dictionary,fresh: bool) -> void:
    var action: int=int(peer.stance_pending)
    if action==0:
        return
    peer.stance_pending=0
    var actor: CharacterBody3D=peer.actor
    if not fresh or not actor.can_act() or not _room_active():
        peer.action_rejected+=1
        return
    _dual_cancel_heal(peer,"stance")
    match action:
        ACTION_NEXT_WEAPON:
            if (peer.catalog_owned.size()<2 if catalog_room else not bool(peer.awm_owned)) or float(peer.reload_remaining)>0.0:
                peer.action_rejected+=1
                return
            if catalog_room:
                var old: int=int(peer.weapon)
                peer.catalog_mags[old]=int(peer.ammo)
                peer.catalog_reserves[WEAPON_CATALOG.reserve_slot(old)]=int(peer.reserve)
                var next: int=_catalog_next(peer)
                peer.weapon=next
                peer.ammo=int(peer.catalog_mags.get(next,0))
                peer.reserve=int(peer.catalog_reserves.get(WEAPON_CATALOG.reserve_slot(next),0))
                peer.catalog_switches+=1
                print("V75248_SWITCH slot=",peer.slot," weapon=",next," loaded=",peer.ammo," reserve=",peer.reserve)
            elif int(peer.weapon)==WEAPON_CATALOG.AR:
                peer.stored_ar=peer.ammo
                peer.stored_ar_reserve=peer.reserve
                peer.weapon=WEAPON_CATALOG.AWM
                peer.ammo=peer.stored_awm
                peer.reserve=peer.stored_awm_reserve
            else:
                peer.stored_awm=peer.ammo
                peer.stored_awm_reserve=peer.reserve
                peer.weapon=WEAPON_CATALOG.AR
                peer.ammo=peer.stored_ar
                peer.reserve=peer.stored_ar_reserve
            actor.set_equipped_weapon(int(peer.weapon))
            peer.fire_clock=maxf(float(peer.fire_clock),.25)
            peer.aim=false
            actor.set_ads(false,1.0)
        ACTION_AIM:
            peer.aim=not bool(peer.aim)
            actor.set_ads(bool(peer.aim),4.0 if WEAPON_CATALOG.reserve_slot(int(peer.weapon))==WEAPON_CATALOG.AWM else 2.0)
        ACTION_CROUCH,ACTION_STAND:
            var desired: bool=action==ACTION_CROUCH
            actor.set_crouch(desired)
            if bool(actor._crouching)!=desired:
                peer.action_rejected+=1
                return
    peer.action_applied+=1

func _room_blast_damage(at: Vector3,target: CharacterBody3D) -> float:
    var center: Vector3=target.global_position+Vector3.UP*.85
    var distance: float=at.distance_to(center)
    if distance>=8.0:
        return 0.0
    var ray:=PhysicsRayQueryParameters3D.create(at,center,1,[target.get_rid()])
    if distance>.001 and not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
        return 0.0
    return lerpf(90.0,15.0,distance/8.0)

func _room_grenade_blast(at: Vector3,owner_id: int) -> void:
    if not _room_active() or not at.is_finite():
        return
    room_blast_seq+=1
    room_blast_at=at
    room_blast_ms=Time.get_ticks_msec()
    var attacker: CharacterBody3D=null
    if dual_peers.has(owner_id):
        attacker=dual_peers[owner_id].actor
    for id in dual_peers:
        var peer: Dictionary=dual_peers[id]
        var target: CharacterBody3D=peer.actor
        if target.royale_eliminated or not _peer_ground_ready(peer) or _same_team(attacker,target):
            continue
        var damage: float=_room_blast_damage(at,target)
        if damage<=0.0:
            continue
        var before: float=target.training_health
        target.receive_training_hit(damage,false,at)
        if target.training_health<before:
            _dual_cancel_heal(peer,"grenade")
        if target.royale_eliminated:
            if id!=owner_id and dual_peers.has(owner_id):
                dual_peers[owner_id].kills+=1
            if target.vehicle_ride_active():
                target.force_vehicle_exit()
            _queue_death_loot(peer)
            target.set_deferred("collision_layer",0)
            target.set_deferred("collision_mask",0)
            target.hide()
    for bot in _mixed_bots:
        if not is_instance_valid(bot) or bot.health<=0.0 or _same_team(attacker,bot) or (mixed_flight and not _mixed_ground_bots.has(bot.get_instance_id())):
            continue
        var damage: float=_room_blast_damage(at,bot)
        if damage>0.0:
            bot.take_training_damage(damage,attacker)
    for wall in room_covers:
        if is_instance_valid(wall) and wall.is_active() and wall.global_position.distance_squared_to(at)<64.0:
            wall.take_damage(60.0)
    print("V75249_BLAST seq=",room_blast_seq," at=",at)
    _finish_room_if_needed()

func _room_throw(id: int,peer: Dictionary) -> bool:
    var actor: CharacterBody3D=peer.actor
    if int(peer.grenades)<=0 or room_projectiles.size()>=12 or not actor.can_act() or not actor.is_on_floor():
        return false
    var aim:=Vector3(-sin(actor._yaw)*cos(actor._pitch),sin(actor._pitch),-cos(actor._yaw)*cos(actor._pitch))
    var at: Vector3=actor.global_position+Vector3.UP*1.15
    var ray:=PhysicsRayQueryParameters3D.create(at,at+aim*.55,1,[actor.get_rid()])
    if not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
        return false
    var grenade: Node3D=ROOM_GRENADE.new()
    grenade.excluded=actor.get_rid()
    grenade.velocity=aim*13.0+Vector3.UP*4.7
    grenade.position=world.to_local(at+aim*.55)
    room_projectiles.append(grenade)
    grenade.detonated.connect(_room_grenade_blast.bind(id))
    grenade.audible_fuse.connect(func(where: Vector3,left: float):
        for bot in _mixed_bots:
            if is_instance_valid(bot) and bot.health>0.0:
                bot.warn_explosive(where,left))
    grenade.tree_exited.connect(func(): room_projectiles.erase(grenade),CONNECT_ONE_SHOT)
    world.add_child(grenade)
    peer.grenades-=1
    peer.throws+=1
    _dual_cancel_heal(peer,"grenade")
    print("V75249_THROW slot=",peer.slot," remaining=",peer.grenades)
    return true

func _room_wall(peer: Dictionary) -> bool:
    var actor: CharacterBody3D=peer.actor
    if int(peer.covers)<=0 or float(peer.cover_clock)>0.0 or room_covers.size()>=12 or not actor.can_act() or not actor.is_on_floor():
        return false
    var forward:=Vector3(-sin(actor._yaw),0,-cos(actor._yaw))
    var at: Vector3=actor.global_position+forward*3.6
    var side:=Vector3(-forward.z,0,forward.x)
    if terrain_room:
        at.y=maxf(director.terrain.height_at(at.x,at.z),maxf(director.terrain.height_at(at.x+side.x*1.55,at.z+side.z*1.55),director.terrain.height_at(at.x-side.x*1.55,at.z-side.z*1.55)))
        if absf(at.y-actor.global_position.y)>1.25 or at.y<float(director.terrain.sea_level)+.25:
            return false
    else:
        if Vector2(at.x-WAITING_ISLAND.CENTER.x,at.z-WAITING_ISLAND.CENTER.z).length()>19.0:
            return false
        at.y=WAITING_ISLAND.SPAWN.y-.3
    var shape:=BoxShape3D.new()
    shape.size=Vector3(3.5,2.3,.94)
    var query:=PhysicsShapeQueryParameters3D.new()
    query.shape=shape
    query.transform=Transform3D(Basis(Vector3.UP,actor._yaw),at+Vector3.UP*1.45)
    query.collision_mask=1
    query.exclude=[actor.get_rid()]
    for hit in world.get_world_3d().direct_space_state.intersect_shape(query,16):
        if hit.get("collider")!=director.terrain:
            return false
    var wall: StaticBody3D=ROOM_COVER.new()
    wall.position=world.to_local(at)
    wall.rotation.y=actor._yaw
    room_covers.append(wall)
    wall.tree_exited.connect(func(): room_covers.erase(wall),CONNECT_ONE_SHOT)
    world.add_child(wall)
    peer.covers-=1
    peer.cover_clock=4.0
    peer.walls+=1
    _dual_cancel_heal(peer,"cover")
    print("V75249_WALL slot=",peer.slot," remaining=",peer.covers)
    return true

func _room_vehicle(peer: Dictionary) -> bool:
    var actor: CharacterBody3D=peer.actor
    if actor.vehicle_ride_active():
        var car: AuroraDriveableVehicle=actor._vehicle_ride
        if not car.exit_motion_safe():
            peer.vehicle_result="moving"
            return false
        var at: Vector3=car.exit_position(actor)
        if not at.is_finite():
            peer.vehicle_result="blocked_exit"
            return false
        actor.force_vehicle_exit(at)
        peer.vehicle_result="exited"
        return true
    if not actor.can_act():
        return false
    var closest: AuroraDriveableVehicle=null
    var distance: float=INF
    for car in director._driveable_cars:
        if is_instance_valid(car) and car.can_enter(actor):
            var gap: float=actor.global_position.distance_to(car.global_position)
            if gap<distance:
                closest=car
                distance=gap
    if closest!=null and actor.begin_vehicle_ride(closest):
        _dual_cancel_heal(peer,"vehicle")
        peer.reload_pending=false
        peer.reload_remaining=0.0
        peer.vehicle_result="entered"
        return true
    peer.vehicle_result="no_nearby_vehicle"
    return false

func _room_tactical_action(id: int,peer: Dictionary,fresh: bool,delta: float) -> void:
    peer.cover_clock=maxf(0.0,float(peer.cover_clock)-delta)
    var action: int=int(peer.tactical_pending)
    peer.tactical_pending=0
    if action==0:
        return
    if not fresh or not _room_active() or not _peer_ground_ready(peer) or peer.actor.royale_eliminated:
        peer.action_rejected+=1
        return
    var ok: bool=false
    match action:
        ACTION_GRENADE: ok=_room_throw(id,peer)
        ACTION_COVER: ok=_room_wall(peer)
        ACTION_VEHICLE: ok=_room_vehicle(peer)
    if ok:
        peer.action_applied+=1
    else:
        peer.action_rejected+=1

func _room_vehicle_snapshot(peer: Dictionary) -> Dictionary:
    var cars: Array[Dictionary]=[]
    var actor: CharacterBody3D=peer.actor
    var ride: int=0
    var near: bool=false
    var exit_ready: bool=false
    if room_tactical and _peer_ground_ready(peer) and not actor.royale_eliminated:
        for car in director._driveable_cars:
            if not is_instance_valid(car) or not car._model_ready:
                continue
            if car.driver!=actor and actor.global_position.distance_squared_to(car.global_position)>95.0*95.0:
                continue
            if car.driver==actor:
                ride=car.get_instance_id()
                exit_ready=car.exit_motion_safe()
            near=near or (actor.can_act() and car.can_enter(actor))
            cars.append({"id":car.get_instance_id(),"kind":car.variant,"transform":car.global_transform,"speed":car.speed_kmh(),"fixture":false})
    return {"cars":cars,"ride":ride,"near":near,"exit_ready":exit_ready,"result":peer.vehicle_result}

func _dual_combat_tick(id: int,peer: Dictionary,fresh: bool,delta: float) -> void:
    var actor: CharacterBody3D=peer.actor
    var ready: bool=_room_active() and actor.can_act() and _peer_ground_ready(peer)
    if not ready:
        peer.fire=false
        peer.reload_pending=false
        peer.reload_remaining=0.0
        peer.heal_pending=false
        _dual_cancel_heal(peer,"round_end")
        actor.set_firing(false)
        return
    if bool(peer.heal_pending):
        peer.heal_pending=false
        if fresh and int(peer.medkits)>0 and actor.training_health<actor.MAX_HEALTH and float(peer.reload_remaining)<=0.0 and not bool(peer.reload_pending) and not bool(peer.fire) and not bool(peer.run) and (peer.axis as Vector2).length_squared()<=.01 and Vector2(actor.velocity.x,actor.velocity.z).length_squared()<=.49:
            peer.heal_remaining=DUAL_HEAL_SECONDS
            peer.heal_anchor=actor.global_position
            peer.action_applied+=1
            actor.play_weapon_action("heal",DUAL_HEAL_SECONDS)
        else:
            peer.action_rejected+=1
    if float(peer.heal_remaining)>0.0:
        if not fresh or bool(peer.fire) or bool(peer.run) or bool(peer.reload_pending) or (peer.axis as Vector2).length_squared()>.01 or actor.global_position.distance_squared_to(peer.heal_anchor)>.36:
            _dual_cancel_heal(peer,"input_or_movement")
        else:
            peer.heal_remaining=maxf(0.0,float(peer.heal_remaining)-delta)
            if float(peer.heal_remaining)<=0.0:
                actor.cancel_medical_action()
                if int(peer.medkits)>0 and actor.training_health<actor.MAX_HEALTH:
                    var before: float=actor.training_health
                    peer.medkits-=1
                    actor.receive_training_heal(DUAL_HEAL_HP)
                    peer.heal_gained=actor.training_health-before
                    peer.heal_completed+=1
                    _dual_sound(id,"local","heal")
                    print("V75241_SERVER_HEAL peer=",id," before=",before," after=",actor.training_health," gained=",peer.heal_gained," medkits=",peer.medkits)
            actor.set_firing(false)
            return
    var spec: Dictionary=WEAPON_CATALOG.ENTRIES[int(peer.weapon)]
    peer.fire_clock=maxf(0.0,float(peer.fire_clock)-delta)
    if bool(peer.reload_pending):
        peer.reload_pending=false
        peer.reload_remaining=float(spec.reload)
        peer.action_applied+=1
        actor.play_weapon_action("reload",float(spec.reload))
        _dual_sound_action(id,"reload","duel_remote_reload",actor.global_position)
    if float(peer.reload_remaining)>0.0:
        peer.reload_remaining=maxf(0.0,float(peer.reload_remaining)-delta)
        if float(peer.reload_remaining)<=0.0:
            var amount: int=mini(int(spec.capacity)-int(peer.ammo),int(peer.reserve))
            peer.ammo+=amount
            peer.reserve-=amount
            peer.reloads+=1
        actor.set_firing(false)
        return
    var melee: bool=catalog_room and bool(spec.get("melee",false))
    var firing_now: bool=fresh and bool(peer.fire) and (melee or int(peer.ammo)>0)
    actor.set_firing(firing_now)
    if not firing_now or float(peer.fire_clock)>0.0:
        return
    peer.fire_clock=float(spec.cadence)
    if not melee:
        peer.ammo-=1
    peer.shots+=1
    if mixed_flight and _mixed_phase=="aircraft":
        _early_ground_shots+=1
        if _early_ground_shots==1:
            print("V75247_EARLY_SHOT slot=",peer.slot," bots_landed=",_mixed_landed_bots)
    actor.play_weapon_action("fire",.10)
    _dual_sound_action(id,str(spec.sample),"duel_remote_shot",actor.global_position)
    var origin: Vector3=actor.global_position+Vector3.UP*(.95 if actor._crouching else 1.35)
    var angle: float=actor._yaw
    var pitch_angle: float=actor._pitch
    var direction:=Vector3(-sin(angle)*cos(pitch_angle),sin(pitch_angle),-cos(angle)*cos(pitch_angle))
    if mixed_room:
        for bot in _mixed_bots:
            if is_instance_valid(bot) and bot.health>0.0:
                bot.hear_gunshot(origin,actor)
    var impacts: Dictionary={}
    var count: int=clampi(int(spec.get("pellets",1)),1,8)
    var rng:=RandomNumberGenerator.new()
    rng.seed=hash([id,int(peer.shots),int(peer.weapon)])
    var right: Vector3=direction.cross(Vector3.UP).normalized()
    var up: Vector3=right.cross(direction).normalized()
    for i in range(count):
        var shot: Vector3=direction
        if count>1:
            var spread: float=float(spec.get("spread",0.0))
            shot=(direction+right*rng.randf_range(-spread,spread)+up*rng.randf_range(-spread,spread)).normalized()
        var ray:=PhysicsRayQueryParameters3D.create(origin,origin+shot*float(spec.get("range",80.0)))
        ray.exclude=[actor.get_rid()]
        ray.collision_mask=1
        var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
        if hit.is_empty():
            continue
        var key: int=hit.collider.get_instance_id()
        if not impacts.has(key):
            impacts[key]={"hit":hit,"damage":0.0}
        impacts[key].damage+=float(spec.damage)
    for record in impacts.values():
        _room_apply_impact(id,peer,actor,origin,record.hit,float(record.damage))

func _room_apply_impact(id: int,peer: Dictionary,actor: CharacterBody3D,origin: Vector3,impact: Dictionary,damage: float) -> void:
    if _dual_finished:
        return
    if mixed_room or room_tactical:
        var body: Object=impact.get("collider")
        if body is CharacterBody3D and _mixed_bots.has(body) and body.health>0.0 and not _same_team(actor,body) and (not mixed_flight or _mixed_ground_bots.has(body.get_instance_id())):
            var old_hp: float=body.health
            body.take_training_damage(damage,actor)
            if body.health<old_hp:
                peer.hits+=1
                peer.bot_hits+=1
                _mixed_human_hits+=1
                _dual_sound(id,"local","impact")
                if peer.bot_hits==1:
                    print("V75244_HUMAN_BOT slot=",peer.slot," hp=",body.health)
            return
        if body is StaticBody3D and body.is_in_group("aurora_deployable_cover"):
            body.take_damage(damage)
            return
    for other_id in dual_peers:
        if other_id==id:
            continue
        var target: CharacterBody3D=dual_peers[other_id].actor
        if impact.get("collider")!=target or target.royale_eliminated or _same_team(actor,target) or not _peer_ground_ready(dual_peers[other_id]):
            continue
        var old_hp: float=target.training_health
        target.receive_training_hit(damage,false,origin,impact.position)
        if target.training_health<old_hp:
            _dual_cancel_heal(dual_peers[other_id],"damage")
            peer.hits+=1
            _dual_sound(id,"local","impact")
            _dual_sound(int(other_id),"local","hit")
        if target.royale_eliminated:
            peer.kills+=1
            if expanded_room:
                if target.vehicle_ride_active():
                    target.force_vehicle_exit()
                _queue_death_loot(dual_peers[other_id])
                target.collision_layer=0
                target.collision_mask=0
                target.hide()
                print("V75242_ELIMINATION killer=",id," victim=",other_id," alive=",_living_room_count()," weapon=",peer.weapon)
            _finish_room_if_needed()
            print("V75238_SERVER_ELIMINATION winner=",id," target=",other_id," shots=",peer.shots," hits=",peer.hits," hp=",target.training_health)
        break

func _dual_tick(delta: float) -> void:
    if dual_peers.is_empty():
        return
    _mixed_flight_tick(delta)
    _terrain_zone_tick(delta)
    for id in dual_peers:
        var peer: Dictionary=dual_peers[id]
        var actor: CharacterBody3D=peer.actor
        var fresh: bool=Time.get_ticks_msec()-int(peer.input_ms)<=INPUT_TIMEOUT_MS and not (dual_combat and _dual_finished)
        actor.set_touch_move_axis(peer.axis if fresh else Vector2.ZERO)
        actor.set_touch_run(bool(peer.run) and fresh)
        actor._desired_yaw=float(peer.yaw)
        actor._desired_pitch=float(peer.pitch)
        if bool(peer.jump_pending):
            if fresh and actor.can_act():
                _dual_cancel_heal(peer,"jump")
                actor.touch_jump()
                peer.action_applied+=1
            else:
                peer.action_rejected+=1
            peer.jump_pending=false
        if (not terrain_room or (mixed_flight and _mixed_phase=="waiting")) and actor.global_position.y<WAITING_ISLAND.SPAWN.y-3.0:
            actor.global_position=peer.home
            actor.velocity=Vector3.ZERO
        elif terrain_room and _peer_ground_ready(peer) and not actor.royale_eliminated and actor.global_position.y<float(director.terrain.sea_level)-12.0:
            actor.receive_training_hit(actor.MAX_HEALTH,true)
            if actor.royale_eliminated:
                _queue_death_loot(peer)
                actor.collision_layer=0
                actor.collision_mask=0
                actor.hide()
                _finish_room_if_needed()
        if room_tactical:
            _room_tactical_action(int(id),peer,fresh,delta)
        if expanded_room:
            _apply_room_stance(peer,fresh)
        if dual_combat:
            _dual_combat_tick(int(id),peer,fresh,delta)
    _send_clock+=delta
    if _send_clock<.1:
        return
    _send_clock=fmod(_send_clock,.1)
    snapshot_sequence+=1
    for id in dual_peers:
        var peer: Dictionary=dual_peers[id]
        var actor: CharacterBody3D=peer.actor
        var rivals: Array[Dictionary]=[]
        for other_id in dual_peers:
            if other_id==id:
                continue
            var other: CharacterBody3D=dual_peers[other_id].actor
            if other.royale_eliminated or (mixed_flight and other.air_mode=="aircraft") or (mixed_flight and actor.air_mode=="aircraft") or (terrain_room and not _terrain_contact(actor,other)):
                continue
            # The isolated open platform has no hidden combat roster.
            var clip: String=str(other._current_clip)
            if dual_combat:
                if float(dual_peers[other_id].heal_remaining)>0.0:
                    clip="AuroraHeal"
                elif float(dual_peers[other_id].reload_remaining)>0.0:
                    clip="AuroraReloadAWM" if int(dual_peers[other_id].weapon)==WEAPON_CATALOG.AWM else ("AuroraReloadMP40" if int(dual_peers[other_id].weapon)==WEAPON_CATALOG.MP40 else "AuroraReloadAR")
                elif bool(other._fire_held) and not _dual_finished:
                    clip="AuroraFireAWM" if int(dual_peers[other_id].weapon)==WEAPON_CATALOG.AWM else "AuroraFire"
            var staged: bool=mixed_flight and not _peer_ground_ready(dual_peers[other_id])
            if mixed_flight and other.air_mode=="freefall":
                clip="AuroraFreefall"
            elif mixed_flight and other.air_mode=="parachute":
                clip="AuroraParachute"
            rivals.append({"id":other_id,"position":other.global_position,
                "yaw":other.rotation.y,"clip":clip,
                "weapon":int(dual_peers[other_id].weapon) if dual_combat and not staged else -1,
                "waiting":not dual_combat or staged,"airborne":mixed_flight and other.air_mode=="parachute","human":true,"team":int(other.get_meta("online_team",-1)),
                "slot":dual_peers[other_id].slot,"vest_level":other.vest_level,"helmet_level":other.helmet_level,
                "medical":float(dual_peers[other_id].heal_remaining)>0.0})
        if mixed_room and _mixed_ready and not actor.royale_eliminated and (not mixed_flight or actor.air_mode!="aircraft"):
            var near: Array[Dictionary]=[]
            for bot in _mixed_bots:
                if not is_instance_valid(bot) or bot.health<=0.0 or (mixed_flight and bot._airdrop_stage=="waiting"):
                    continue
                var distance: float=actor.global_position.distance_squared_to(bot.global_position)
                if distance<=80.0*80.0:
                    near.append({"bot":bot,"distance":distance})
            near.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.distance)<float(b.distance))
            var checked: int=0
            for item in near:
                if checked>=12 or rivals.size()>=8:
                    break
                checked+=1
                var bot: CharacterBody3D=item.bot
                if not _terrain_contact(actor,bot):
                    continue
                var staged: bool=mixed_flight and not _mixed_ground_bots.has(bot.get_instance_id())
                var canopy: bool=mixed_flight and bot._airdrop_stage=="descending"
                rivals.append({"id":1099511627776+bot.get_instance_id(),"position":bot.global_position,
                    "yaw":bot.rotation.y,"clip":"AuroraParachute" if canopy else str(bot._clip),"weapon":-1 if staged else int(bot.weapon_slot),
                    "waiting":staged,"airborne":canopy,"human":false,"team":int(bot.get_meta("online_team",-1)),"vest_level":0,"helmet_level":0})
        var alive: int=_living_room_count()
        var bot_alive: int=0
        if mixed_room:
            for bot in _mixed_bots:
                if is_instance_valid(bot) and bot.health>0.0:
                    bot_alive+=1
        var grenade_items: Array[Dictionary]=[]
        for grenade in room_projectiles:
            if is_instance_valid(grenade) and not grenade._spent and actor.global_position.distance_squared_to(grenade.global_position)<=TACTICAL_RANGE*TACTICAL_RANGE:
                grenade_items.append({"id":grenade.get_instance_id(),"position":grenade.global_position,"seconds":grenade._remaining})
        var cover_items: Array[Dictionary]=[]
        if mixed_room or room_tactical:
            for cover in get_tree().get_nodes_in_group("aurora_deployable_cover"):
                if is_instance_valid(cover) and cover.is_active() and actor.global_position.distance_squared_to(cover.global_position)<=TACTICAL_RANGE*TACTICAL_RANGE:
                    cover_items.append({"id":cover.get_instance_id(),"position":cover.global_position,"yaw":cover.rotation.y})
        if not peer.ambient.is_empty():
            if multiplayer.get_peers().has(int(id)):
                receive_sound_batch.rpc_id(int(id),PROTOCOL,peer.ambient)
            peer.ambient=[]
        _send_world_state({"snapshot_id":snapshot_sequence,"self_peer":id,"dual_waiting":true,"dual_combat":dual_combat,"dual_loot":dual_loot,
            "duel_loot_claims":peer.loot_claims,"duel_world_claims":_dual_loot_claims,
            "heal_remaining":peer.heal_remaining,"heal_completed":peer.heal_completed,
            "heal_cancelled":peer.heal_cancelled,"heal_gained":peer.heal_gained,
            "duel_ready":_room_active() and _peer_ground_ready(peer) and not actor.royale_eliminated,"duel_winner":_dual_winner,
            "expanded_room":expanded_room,"room_capacity":room_capacity,"room_slot":peer.slot,
            "death_spawned":_death_spawned,"death_claims":_death_claims,
            "death_active":_active_room_deaths(),"death_peak":_death_peak,"death_retired":_death_retired,
            "bot_death_spawned":_bot_death_spawned,"bot_death_claims":_bot_death_claims,
            "own_bot_loot_claims":peer.bot_loot_claims,"own_bot_loot_rounds":peer.bot_loot_rounds,
            "armor":actor.armor_points,"helmet":actor.helmet_points,"vest_level":actor.vest_level,"helmet_level":actor.helmet_level,
            "backpack":peer.backpack,"awm_reserve":_catalog_reserve(peer,WEAPON_CATALOG.AWM) if catalog_room else (peer.reserve if int(peer.weapon)==WEAPON_CATALOG.AWM else peer.stored_awm_reserve),
            "catalog_room":catalog_room,"catalog_available":_catalog_available,"catalog_switches":peer.catalog_switches,
            "ar_reserve":_catalog_reserve(peer,WEAPON_CATALOG.AR) if catalog_room else (peer.reserve if int(peer.weapon)==WEAPON_CATALOG.AR else peer.stored_ar_reserve),
            "smg_reserve":_catalog_reserve(peer,WEAPON_CATALOG.MP40) if catalog_room else 0,
            "hits":peer.hits,"kills":peer.kills,"reloads":peer.reloads,"duel_audio_sent":peer.audio_seq,
            "position":actor.global_position,"velocity":actor.velocity,"body_yaw":actor.rotation.y,
            "clip":str(actor._current_clip),"air_mode":actor.air_mode if mixed_flight else "ground",
            "match_mode":("sector_battle" if _peer_ground_ready(peer) else _mixed_phase) if mixed_flight else ("sector_battle" if terrain_room else "waiting"),
            "waiting_remaining":_mixed_wait if mixed_flight else 0.0,
            "room_flexible":room_flexible,"room_sealed":room_sealed,"room_internet":room_internet,"room_join_remaining":room_join_remaining,
            "room_initial_humans":room_initial_humans if room_flexible else room_capacity,"room_bot_target":room_bot_target,"waiting_ready":dual_peers.size()+_mixed_bots.size() if mixed_flight else dual_peers.size(),"rivals":rivals,
            "mixed_flight":mixed_flight,"flight_elapsed":_mixed_flight_elapsed,"flight_landed_bots":_mixed_landed_bots,
            "flight_jumped":peer.flight_jumped,"flight_canopy":peer.flight_canopy,"flight_landed":peer.flight_landed,
            "deployment_complete":mixed_flight and _mixed_phase=="sector_battle",
            "early_ground_shots":_early_ground_shots,"early_ground_claims":_early_ground_claims,
            "ended":dual_combat and _dual_finished,"eliminated":actor.royale_eliminated,"loot":_dual_loot_snapshot(actor),"vehicles":_room_vehicle_snapshot(peer) if room_tactical else {},
            "inventory":{"awm_owned":peer.awm_owned,"additions":_catalog_additions(peer) if catalog_room else {},"medkits":peer.medkits,"grenades":peer.grenades,"covers":peer.covers},
            "tactical":{"cover_cooldown":peer.cover_clock,"covers":cover_items,"grenades":grenade_items,"blast_sequence":room_blast_seq,"blast_position":room_blast_at if Time.get_ticks_msec()-room_blast_ms<1000 and actor.global_position.distance_squared_to(room_blast_at)<TACTICAL_RANGE*TACTICAL_RANGE else null},
            "room_tactical":room_tactical,"throws":peer.throws,"walls":peer.walls,"team_size":room_team_size,"team":int(actor.get_meta("online_team",-1)),"winner_team":room_winner_team,"round_result":room_result,"weapon":peer.weapon,"aim":peer.aim,"zoom":(4.0 if WEAPON_CATALOG.reserve_slot(int(peer.weapon))==WEAPON_CATALOG.AWM else 2.0) if bool(peer.aim) else 1.0,
            "firing":dual_combat and bool(actor._fire_held),"crouched":actor._crouching,"grounded":actor.is_on_floor(),
            "ammo":peer.ammo if dual_combat else 0,"reserve":peer.reserve if dual_combat else 0,
            "reload_remaining":peer.reload_remaining if dual_combat else 0.0,"health":actor.training_health,"participants":50 if mixed_room and _mixed_ready else dual_peers.size(),
            "alive":alive,"bots":bot_alive,"shots":peer.shots,
            "mixed_room":mixed_room,"mixed_ready":_mixed_ready,"human_count":dual_peers.size(),
            "bot_roster":_mixed_bots.size(),"bot_shots":_mixed_bot_shots,"bot_damage_events":_mixed_human_damage,"human_bot_hits":_mixed_human_hits,
            "own_bot_hits":peer.bot_hits,"own_bot_damage":peer.bot_damage,"winner_bot":_mixed_winner_bot,
            "terrain_room":terrain_room,"zone_hits":peer.zone_hits,
            "zone_center":_room_zone.get("center",Vector2.ZERO),"zone_radius":float(_room_zone.get("radius",0.0)),
            "zone_phase":int(_room_zone.get("phase",0)),"zone_remaining":int(_room_zone.get("remaining",0)),
            "zone_outside":terrain_room and _peer_ground_ready(peer) and Vector2(actor.global_position.x,actor.global_position.z).distance_to(_room_zone.get("center",Vector2.ZERO))>float(_room_zone.get("radius",0.0)),
            "action_ack":peer.action_ack,"action_applied":peer.action_applied,"action_rejected":peer.action_rejected,
            "accepted":peer.accepted,"rejected":peer.rejected,"ack":peer.sequence},id)

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
    if dual_waiting:
        _dual_input(version,sequence,move,heading,look_pitch,run,shoot)
        return
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
    if dual_waiting:
        _dual_action(version,request_id,action)
        return
    if not multiplayer.is_server() or remote_id==0 or multiplayer.get_remote_sender_id()!=remote_id:
        return
    if version!=PROTOCOL or request_id<=action_ack or request_id-action_ack>256:
        action_rejected+=1
        return
    action_ack=request_id
    var air_jump: bool=action==ACTION_JUMP and director.mode=="aircraft" and director._flight.phase in ["aircraft","freefall"]
    var waiting_denied: bool=director.mode=="waiting" and action!=ACTION_JUMP
    var vehicle_action: bool=action==ACTION_VEHICLE and director.mode=="sector_battle" and operator.air_mode=="ground" and not operator.royale_eliminated
    if action<ACTION_JUMP or action>ACTION_VEHICLE or director.match_ended or waiting_denied or (action==ACTION_VEHICLE and not vehicle_action) or (not operator.can_act() and not air_jump and not vehicle_action):
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
        if director.mode=="waiting":
            if action==ACTION_JUMP and operator.can_act():
                operator.touch_jump()
                action_applied+=1
            else:
                action_rejected+=1
            continue
        if director.mode=="aircraft":
            if action==ACTION_JUMP and director._flight.phase in ["aircraft","freefall"]:
                director._flight.call_deferred("request_jump_or_parachute")
                action_applied+=1
            else:
                action_rejected+=1
            continue
        if action==ACTION_VEHICLE:
            var was_riding: bool=operator.vehicle_ride_active()
            var motion_blocked: bool=was_riding and not operator._vehicle_ride.exit_motion_safe()
            director._on_real_vehicle_action()
            if was_riding!=operator.vehicle_ride_active():
                action_applied+=1
                vehicle_action_result="exited" if was_riding else "entered"
            else:
                action_rejected+=1
                vehicle_action_result="moving" if motion_blocked else ("blocked_exit" if was_riding else "no_nearby_vehicle")
            continue
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
    if director.mode!="sector_battle" or director.match_ended or operator.royale_eliminated:
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
    # Critical cues cannot be evicted by the high-volume bot sound history.
    # Both streams have independent sequences; remote positions remain quantized.
    if kind=="local" or kind=="remote_blast":
        critical_sound_sequence+=1
        receive_critical_sound.rpc_id(remote_id,PROTOCOL,{"seq":critical_sound_sequence,"kind":kind,
            "sample":sample,"at":at,"run":running,"stone":stone})
        return
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
    if director.mode=="sector_battle" and not director.match_ended:
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

# Reliable, ordered channel isolated from snapshots and ambient sound.
@rpc("authority","call_remote","reliable",4)
func receive_critical_sound(version: int,event: Dictionary) -> void:
    if version!=PROTOCOL or multiplayer.is_server():
        return
    var id: int=int(event.get("seq",0))
    if id<=received_critical_sequence:
        return
    if id!=received_critical_sequence+1:
        critical_sound_gaps+=1
    received_critical_sequence=id
    last_critical_sound=event
    pending_critical_sounds.append(event)

func drain_sounds() -> Array:
    var result: Array=pending_critical_sounds
    pending_critical_sounds=[]
    result.append_array(pending_sounds)
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

func _send_world_state(data: Dictionary,destination: int=0) -> void:
    var recipient: int=remote_id if destination==0 else destination
    if recipient<=0 or not multiplayer.get_peers().has(recipient):
        return
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
        receive_state_chunk.rpc_id(recipient,PROTOCOL,int(data.snapshot_id),index,count,raw.size(),part)

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

# Only actual descending, alive bodies in view and unobstructed by physics.
# This separate visual stream does not change ground radar visibility.
func _airborne_contacts() -> Array[Dictionary]:
    var found: Array[Dictionary]=[]
    if director.mode!="aircraft" or operator.air_mode not in ["freefall","parachute"]:
        return found
    var eye: Vector3=operator.global_position+Vector3.UP*1.4
    var forward:=Vector2(-sin(operator._yaw),-cos(operator._yaw))
    var candidates: Array[Dictionary]=[]
    for rival in combat._targets:
        if not is_instance_valid(rival) or rival.is_queued_for_deletion() or not rival.is_visible_in_tree() or rival.health<=0.0 or rival._airdrop_stage!="descending":
            continue
        var offset: Vector3=rival.global_position-eye
        var horizontal:=Vector2(offset.x,offset.z)
        var distance: float=offset.length_squared()
        if distance>AIR_CONTACT_RANGE*AIR_CONTACT_RANGE or horizontal.length_squared()<2.25 or horizontal.normalized().dot(forward)<.35:
            continue
        candidates.append({"actor":rival,"distance":distance})
    candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.distance)<float(b.distance))
    for i in range(mini(AIR_CONTACT_LIMIT,candidates.size())):
        var actor: CharacterBody3D=candidates[i].actor
        var ray:=PhysicsRayQueryParameters3D.create(eye,actor.global_position+Vector3.UP)
        ray.exclude=[operator.get_rid()]
        var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
        if hit.get("collider")!=actor:
            continue
        found.append({"id":actor.get_instance_id(),"position":actor.global_position,
            "yaw":actor.rotation.y,"clip":"AuroraParachute","weapon":-1,"airborne":true})
    return found

func _prepare_air_rival_qa() -> void:
    if not _qa_flight_test or _qa_air_rival_prepared or operator.air_mode!="freefall" or not director._rivals_departed or combat._targets.is_empty():
        return
    # Deterministic sighting in the existing flight room: start one actual
    # descending bot in front, then let its normal physical descent run.
    var actor: CharacterBody3D=combat._targets[0]
    var origin: Vector3=operator.global_position+Vector3(0,0,-14)
    actor.retarget_real_airdrop(Vector2(origin.x,origin.z))
    actor.begin_real_airdrop(origin,0.0)
    _qa_air_rival_prepared=true
    print("V75231_AIR_FIXTURE real_bot=",actor.get_instance_id())

func _vehicle_snapshot() -> Dictionary:
    var cars: Array[Dictionary]=[]
    var ride: int=0
    var near: bool=false
    var exit_ready: bool=false
    if director.mode=="sector_battle" and not director.match_ended and not operator.royale_eliminated:
        for car in director._driveable_cars:
            if not is_instance_valid(car) or car.is_queued_for_deletion() or not car._model_ready:
                continue
            if car.global_position.distance_squared_to(operator.global_position)>95.0*95.0 and car.driver!=operator:
                continue
            var fixture: bool=_qa_vehicle_test and car.get_script().resource_path.ends_with("qa_vehicle_chassis.gd")
            if not fixture and not VEHICLE.source_available(car.variant):
                continue
            var id: int=car.get_instance_id()
            if car.driver==operator:
                ride=id
                exit_ready=car.exit_motion_safe()
            near=near or (operator.can_act() and car.can_enter(operator))
            cars.append({"id":id,"kind":car.variant,"transform":car.global_transform,
                "speed":car.speed_kmh(),"fixture":fixture})
    return {"cars":cars,"ride":ride,"near":near,"exit_ready":exit_ready,"result":vehicle_action_result}

func _physics_process(delta: float) -> void:
    if dual_waiting and multiplayer.is_server():
        _dual_tick(delta)
        return
    if remote_id==0 or not multiplayer.is_server() or not is_instance_valid(operator):
        return
    if director.mode=="waiting":
        waiting_remaining=maxf(0.0,waiting_remaining-delta)
        if operator.global_position.y<WAITING_ISLAND.SPAWN.y-3.0:
            operator.global_position=WAITING_ISLAND.SPAWN
            operator.velocity=Vector3.ZERO
        if waiting_remaining<=0.0 and _waiting_roster.size()==WAITING_BOT_LIMIT and not _waiting_transition:
            _waiting_transition=true
            call_deferred("_depart_waiting")
    if Time.get_ticks_msec()-last_input_ms>INPUT_TIMEOUT_MS or director.match_ended:
        _stop_input()
    else:
        operator.set_touch_move_axis(axis)
        operator._desired_yaw=yaw
        operator._desired_pitch=pitch
        operator.set_touch_run(sprint)
        _apply_actions()
        var allowed_fire: bool=fire and director.mode=="sector_battle" and operator.can_act()
        if allowed_fire!=previous_fire:
            if allowed_fire:
                combat._on_fire_pressed()
            else:
                combat._on_fire_released()
            previous_fire=allowed_fire
    # CI-only end-of-round regression after input timeout, independent of
    # tactical placement. Uses the real damage and elimination code path.
    if _qa_fixture and not _qa_flight_test and not _qa_vehicle_test and not _qa_end_verified and action_applied>=10 and last_input_ms>0 and Time.get_ticks_msec()-last_input_ms>3000:
        _qa_end_verified=true
        operator.receive_training_hit(operator.MAX_HEALTH,true)
    if _qa_rival_test:
        _advance_rival_fixture()
    _prepare_air_rival_qa()
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
                    "clip":str(actor._clip),"weapon":int(actor.weapon_slot)})
        rivals.append_array(_airborne_contacts())
        rivals.append_array(_waiting_contacts())
        # Private development snapshot: no hidden enemy coordinates.
        snapshot_sequence+=1
        _send_world_state({
            "snapshot_id":snapshot_sequence,"eliminated":operator.royale_eliminated,
            "cover_reason":combat.cover_last_block_reason,"sound_payload_peak":max_sound_bytes,
            "position":operator.global_position,"velocity":operator.velocity,
            "body_yaw":operator.rotation.y,"clip":str(operator._current_clip),
            "air_mode":str(operator.air_mode),"match_mode":str(director.mode),
            "flight_elapsed":director._flight.elapsed,
            "waiting_remaining":waiting_remaining,"waiting_ready":_waiting_roster.size()+1 if director.mode=="waiting" else 0,
            "rivals":rivals,"ended":director.match_ended,
            "loot":_nearby_loot(),"inventory":combat.inventory_snapshot(),
            "tactical":_tactical_snapshot(),"vehicles":_vehicle_snapshot(),
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
