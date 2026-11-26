extends SceneTree
const SESSION=preload("res://scripts/network/aurora_online_session.gd")
const PRESENTATION=preload("res://scripts/network/online_presentation.gd")
func _initialize() -> void:
    call_deferred("_verify")
func _verify_state_codec() -> bool:
    var probe:=SESSION.new()
    var raw: PackedByteArray=var_to_bytes({"snapshot_id":2,"loot":[{"id":77,"position":Vector3(1,2,3)}],"rivals":[]})
    var packed: PackedByteArray=raw.compress(FileAccess.COMPRESSION_DEFLATE)
    var middle: int=packed.size()/2
    var first: PackedByteArray=packed.slice(0,middle)
    var second: PackedByteArray=packed.slice(middle)
    probe._ingest_state_chunk(1,0,2,raw.size(),first)
    var incomplete: bool=probe.state.is_empty()
    probe._ingest_state_chunk(2,1,2,raw.size(),second)
    probe._ingest_state_chunk(1,1,2,raw.size(),second)
    probe._ingest_state_chunk(2,1,2,raw.size(),second)
    var isolated: bool=probe.state.is_empty()
    probe._ingest_state_chunk(2,0,2,raw.size(),first)
    var decoded: bool=probe.state.get("snapshot_id",0)==2 and probe.state.get("loot",[])==[{"id":77,"position":Vector3(1,2,3)}]
    probe._ingest_state_chunk(1,0,1,raw.size(),packed)
    var old_rejected: bool=probe.state.get("snapshot_id",0)==2 and probe.state_frames==1
    probe.free()
    print("V75227_CODEC incomplete=",incomplete," isolated=",isolated," decoded=",decoded," stale_rejected=",old_rejected)
    return incomplete and isolated and decoded and old_rejected

func _verify() -> void:
    var codec_ok: bool=_verify_state_codec()
    var world: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    world.online_presentation_only=true
    root.add_child(world)
    var session:=SESSION.new()
    session.name="AuroraOnline"
    root.add_child(session)
    var view:=PRESENTATION.new()
    world.add_child(view)
    view.setup(world,session)
    view.send_controls=false
    var no_sim: bool=world.get_node_or_null("CombatRange")==null and world.get_node_or_null("AuroraNavigation")==null and world.get_node_or_null("AuroraSectorMatch")==null and not world.operator.is_physics_processing()
    if not no_sim or session.connect_local()!=OK:
        push_error("Client instantiated local simulation or connection failed")
        quit(1)
        return
    for i in range(180):
        await create_timer(.05).timeout
        if view._has_state:
            break
    if not view._has_state or session.state.get("bots",0)!=49 or session.state.get("participants",0)!=50:
        push_error("No actual 50-person server state on presentation client")
        quit(1)
        return
    var start: Vector3=session.state.position
    var initial_elapsed: float=session.state.elapsed
    for i in range(5):
        session.submit_input.rpc_id(1,SESSION.PROTOCOL,1,Vector2(3,0),0.0,-.14,false,false)
        await create_timer(.05).timeout
    # Attempt to select the next weapon before physical ownership exists.
    view.send_controls=true
    await create_timer(.25).timeout
    view.request_action(session.ACTION_NEXT_WEAPON)
    await create_timer(.30).timeout
    var denied_unowned: bool=int(session.state.weapon)==0 and not bool(session.state.inventory.awm_owned)
    var fixture_id: int=0
    for item in session.state.loot:
        if str(item.kind)=="weapon_awm" and float(item.distance_sq)<25.0:
            fixture_id=int(item.id)
            break
    var had_replica: bool=fixture_id!=0 and view.loot_replicas.has(fixture_id)
    var noninteractive: bool=false
    if had_replica:
        var replica: Area3D=view.loot_replicas[fixture_id]
        noninteractive=not replica.monitoring and not replica.monitorable and replica.get_node_or_null("LootPickupRange")==null
    view.move_axis=Vector2(0,-1)
    view.firing=true
    await create_timer(.65).timeout
    view.firing=false
    view.move_axis=Vector2.ZERO
    await create_timer(.45).timeout
    var picked_up: bool=bool(session.state.inventory.awm_owned) and int(session.state.inventory.loot_collected)>0
    var removed: bool=not view.loot_replicas.has(fixture_id)
    var ammo_before: int=int(session.state.ammo)
    var reload_before: int=int(session.state.reloads)
    view.request_action(session.ACTION_RELOAD)
    # Duplicate reliable command must never repeat the authoritative action.
    session.submit_action.rpc_id(1,SESSION.PROTOCOL,view.action_sequence,session.ACTION_RELOAD)
    await create_timer(3.0).timeout
    var reload_ok: bool=int(session.state.reloads)>reload_before and int(session.state.ammo)>ammo_before
    view.request_action(session.ACTION_CROUCH)
    await create_timer(.5).timeout
    var crouch_ok: bool=bool(session.state.crouched)
    view.request_action(session.ACTION_STAND)
    await create_timer(.5).timeout
    var stand_ok: bool=not bool(session.state.crouched)
    # Sample during the actual jump, not merely a server ACK.
    for i in range(20):
        if bool(session.state.grounded):
            break
        await create_timer(.05).timeout
    var jump_base: float=session.state.position.y
    view.request_action(session.ACTION_JUMP)
    var jump_ok: bool=false
    for i in range(20):
        await create_timer(.05).timeout
        if not bool(session.state.grounded) and float(session.state.position.y)>jump_base+.15:
            jump_ok=true
    view.request_action(session.ACTION_NEXT_WEAPON)
    await create_timer(.35).timeout
    var equipped: bool=int(session.state.weapon)==1 and view.weapon_visuals.selected_weapon==1 and view.weapon_visuals.currently_equipped()!=null
    view.request_action(session.ACTION_AIM)
    await create_timer(.30).timeout
    var aimed: bool=bool(session.state.aim) and float(session.state.zoom)==8.0
    view.move_axis=Vector2(0,-1)
    await create_timer(1.0).timeout
    view.move_axis=Vector2.ZERO
    await create_timer(.5).timeout
    var grenade_before: int=int(session.state.inventory.grenades)
    var blast_before: int=int(session.state.tactical.blast_sequence)
    view.request_action(session.ACTION_GRENADE)
    var live_grenade: bool=false
    var no_local_fuse: bool=false
    for i in range(18):
        await create_timer(.05).timeout
        if not view.grenade_replicas.is_empty():
            live_grenade=true
            var replica: Node3D=view.grenade_replicas.values()[0]
            no_local_fuse=replica.presentation_only and not replica.is_physics_processing()
    await create_timer(1.4).timeout
    var grenade_ok: bool=grenade_before>0 and int(session.state.inventory.grenades)==grenade_before-1 and live_grenade and no_local_fuse and int(session.state.tactical.blast_sequence)>blast_before and view.grenade_replicas.is_empty()
    var cover_before: int=int(session.state.inventory.covers)
    var cover_ok: bool=false
    var tries: int=0
    # At a real world location, try four headings to avoid incidental obstacles.
    for heading in [0.0,PI*.5,-PI*.5,PI-.01]:
        world.operator._desired_yaw=heading
        await create_timer(.55).timeout
        view.request_action(session.ACTION_COVER)
        tries+=1
        await create_timer(.40).timeout
        if int(session.state.inventory.covers)==cover_before-1 and not view.cover_replicas.is_empty():
            var wall: StaticBody3D=view.cover_replicas.values()[0]
            cover_ok=wall.presentation_only and not wall.is_processing() and wall.get_node_or_null("AuroraIceWallCollision")!=null and float(session.state.tactical.cover_cooldown)>0.0
            break
    # Even after a second request, the existing cooldown must preserve inventory.
    view.request_action(session.ACTION_COVER)
    await create_timer(.40).timeout
    var cooldown_ok: bool=int(session.state.inventory.covers)==cover_before-1
    view.send_controls=false
    await create_timer(1.3).timeout
    var final: Dictionary=session.state
    var tactical_ok: bool=grenade_ok and cover_ok and cooldown_ok
    var sound_counts: Dictionary=view.received_sounds.duplicate()
    var sound_seq: int=view.last_sound_sequence
    view._sync_sounds(session.last_sound_batch)
    var dedup: bool=sound_counts==view.received_sounds and sound_seq==view.last_sound_sequence
    var audio_ok: bool=int(sound_counts.get("ar_fire",0))==int(final.shots) and int(sound_counts.get("reload",0))>=1 and int(sound_counts.get("jump",0))>=1 and int(sound_counts.get("remote_blast",0))>=1 and dedup and view.sound._voices.size()==8 and int(final.sound_payload_peak)>0 and int(final.sound_payload_peak)<1200
    print("V75226_AUDIO counts=",sound_counts," shots=",final.shots," dedup=",dedup," pool=",view.sound._voices.size())
    print("V75225_TACTICAL grenade=",grenade_ok," cover=",cover_ok," cooldown=",cooldown_ok," attempts=",tries," hp=",final.health," ended=",final.ended," cover_reason=",final.cover_reason," snapshot_id=",final.snapshot_id," sound_payload_peak=",final.sound_payload_peak)
    print("V75223_ACTIONS reload=",reload_ok," crouch=",crouch_ok," stand=",stand_ok," jump=",jump_ok," action_ack=",final.action_ack," applied=",final.action_applied," rejected=",final.action_rejected)
    var loot_ok: bool=denied_unowned and had_replica and noninteractive and picked_up and removed and equipped and aimed
    print("V75224_LOOT unowned_denied=",denied_unowned," replica=",had_replica," no_local_collision=",noninteractive," physical_pickup=",picked_up," removed=",removed," equipped=",equipped," aim=",aimed)
    var moved: bool=(final.position as Vector3).distance_to(start)>1.0
    var stopped: bool=Vector2(final.velocity.x,final.velocity.z).length()<.2
    var synced: bool=world.operator.global_position.distance_to(final.position)<.4
    var ok: bool=moved and stopped and synced and final.elapsed>initial_elapsed and final.accepted>10 and final.rejected>0 and final.shots>0 and final.bots==49 and final.has("rivals") and no_sim and reload_ok and crouch_ok and stand_ok and jump_ok and int(final.action_applied)==9+tries and loot_ok and tactical_ok and audio_ok and int(final.action_rejected)>=1
    print("V75222_CLIENT local_ai=0 local_match=0 local_nav=0 start=",start," authoritative=",final.position," presented=",world.operator.global_position," shots=",final.shots," accepted=",final.accepted," rejected=",final.rejected," replicas=",view.replicas.size())
    # The server fixture performs a real lethal hit after >3s without input.
    # Verify end-of-round and a post-elimination command rejection, not just
    # the protected mechanics path. Production damage remains unchanged.
    await create_timer(2.5).timeout
    var ended: Dictionary=session.state
    var count_before: int=int(ended.action_applied)
    var rejected_before: int=int(ended.action_rejected)
    session.submit_action.rpc_id(1,SESSION.PROTOCOL,view.action_sequence+1,session.ACTION_COVER)
    await create_timer(.4).timeout
    var end_ok: bool=bool(ended.ended) and bool(ended.eliminated) and float(ended.health)<=0.0 and int(session.state.action_applied)==count_before and int(session.state.action_rejected)>rejected_before and view.cover_replicas.is_empty()
    print("V75226_END ended=",ended.ended," eliminated=",ended.eliminated," health=",ended.health," post_end_rejected=",end_ok)
    var transport_ok: bool=session.state_frames>10 and session.max_state_chunk_bytes>0 and session.max_state_chunk_bytes<=SESSION.STATE_CHUNK_BYTES and session.max_state_encoded_bytes>0 and session.max_state_encoded_bytes<session.max_state_raw_bytes
    print("V75227_STATE frames=",session.state_frames," raw_peak=",session.max_state_raw_bytes," encoded_peak=",session.max_state_encoded_bytes," chunk_peak=",session.max_state_chunk_bytes)
    ok=ok and end_ok and codec_ok and transport_ok
    if ok:
        print("V75227_STATE PASS")
        print("V75226_AUDIO PASS")
        print("V75225_TACTICAL PASS")
        print("V75224_LOOT PASS")
        print("V75223_ACTIONS PASS")
        print("V75222_ONLINE PASS")
        print("V75221_ONLINE PASS")
    else:
        push_error("Online presentation regression")
    session.multiplayer.multiplayer_peer.close()
    quit(0 if ok else 1)
