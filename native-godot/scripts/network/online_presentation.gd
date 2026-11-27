extends Node3D
## Presentation-only scene for the private loopback online development test.
## No bots, damage calculations, inventory writes or local match director.
const ZONE=preload("res://scripts/match/aurora_zone_visual.gd")
const PAD=preload("res://scripts/ui/virtual_joystick.gd")
const FIRE=preload("res://scripts/ui/directional_fire_pad.gd")
const LOOT=preload("res://scripts/match/aurora_loot.gd")
const GRENADE=preload("res://scripts/combat/aurora_grenade.gd")
const COVER=preload("res://scripts/combat/aurora_deployable_cover.gd")
const WEAPON_VISUALS=preload("res://scripts/combat/weapon_visuals.gd")
const WEAPONS=preload("res://scripts/combat/aurora_weapon_catalog.gd")
const AUDIO=preload("res://scripts/audio/aurora_audio.gd")
const FLIGHT_VISUAL=preload("res://scripts/match/airdrop_sequence.gd")
const CANOPY_VISUAL=preload("res://scripts/match/rival_canopy_visual.gd")
const WAITING_ISLAND=preload("res://scripts/network/online_waiting_island.gd")
const VEHICLE=preload("res://scripts/world/aurora_driveable_vehicle.gd")
var vehicle_replicas: Dictionary={}
var vehicle_targets: Dictionary={}
var _vehicle: Button
var _ride_id: int=0
var waiting_visual: Node3D
var _reload: Button
var _presented_match_mode: String=""
var flight_visual: Node3D
var _jump: Button
var sound: Node3D
var last_sound_sequence: int=0
var last_critical_sound_sequence: int=0
var received_sounds: Dictionary={}
var world: Node3D
var operator: CharacterBody3D
var session: Node
var zone: Node3D
var replicas: Dictionary={}
var loot_replicas: Dictionary={}
var grenade_replicas: Dictionary={}
var cover_replicas: Dictionary={}
var grenade_targets: Dictionary={}
var _last_blast_sequence: int=0
var _grenade: Button
var _cover: Button
var weapon_visuals: Node3D
var _presented_weapon: int=-1
var _weapon: Button
var _heal: Button
var _aim: Button
var _last_shots: int=-1
var _was_reloading: bool=false
var _was_duel_healing: bool=false
var target_positions: Dictionary={}
var target_yaws: Dictionary={}
var rig_source: PackedScene
var last_ack: int=0
var sequence: int=0
var action_sequence: int=0
var _crouch: Button
var move_axis: Vector2=Vector2.ZERO
var sprint: bool=false
var firing: bool=false
var send_controls: bool=true
var _clock: float=0.0
var _last_state: Dictionary={}
var _last_state_ms: int=0
# Commit marker is advanced only after all visuals and HUD are applied.
var applied_snapshot_id: int=0
var _has_state: bool=false
var _status: Label
var _touch_root: Control
var _fire_pad: Control
var _run: Button
var _pad: Control

func setup(source: Node3D,transport: Node) -> void:
    world=source
    operator=world.get_node("Operator")
    session=transport
    rig_source=load("res://assets/characters/aurora_operator.glb") as PackedScene
    zone=ZONE.new()
    zone.terrain=world.get_node("AuroraTerrain")
    world.add_child(zone)
    zone.hide()
    operator.hide()
    # Disable ground-contact modifiers on the presentation actor. No local
    # physics solver may change the authoritative pose/position.
    for modifier in operator.find_children("LilaBodyContact","SkeletonModifier3D",true,false):
        modifier.active=false
        modifier.set_physics_process(false)
    if operator._ground_contact!=null:
        operator._ground_contact.hide()
    weapon_visuals=WEAPON_VISUALS.new()
    add_child(weapon_visuals)
    weapon_visuals.attach_to_player(operator)
    sound=AUDIO.new()
    sound.name="OnlineSoundStage"
    world.add_child(sound)
    _build_touch_hud()

func _build_touch_hud() -> void:
    # Construct the scripted adapter directly, not a dynamically retyped CanvasLayer.
    var layer:=preload("res://scripts/network/online_touch_hud.gd").new()
    layer.name="OnlineTouchHUD"
    world.add_child(layer)
    _touch_root=Control.new()
    _touch_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _touch_root.mouse_filter=Control.MOUSE_FILTER_IGNORE
    layer.add_child(_touch_root)
    _status=Label.new()
    _status.position=Vector2(24,24)
    _status.add_theme_font_size_override("font_size",23)
    _status.text="ONLINE · Conectando al servidor de desarrollo"
    _touch_root.add_child(_status)
    _pad=PAD.new()
    _pad.name="MovePad"
    _touch_root.add_child(_pad)
    _pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    _pad.offset_left=35
    _pad.offset_top=-235
    _pad.offset_right=265
    _pad.offset_bottom=-15
    _pad.vector_changed.connect(func(value: Vector2): move_axis=value.limit_length(1.0))
    _fire_pad=FIRE.new()
    _fire_pad.name="DirectionalFirePad"
    _touch_root.add_child(_fire_pad)
    _fire_pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    _fire_pad.offset_left=-190
    _fire_pad.offset_top=-215
    _fire_pad.offset_right=-20
    _fire_pad.offset_bottom=-45
    _fire_pad.pressed.connect(func(): firing=true)
    _fire_pad.released.connect(func(): firing=false)
    _fire_pad.look_dragged.connect(operator.fire_aim_delta)
    _run=Button.new()
    _run.text="CORRER"
    _run.toggle_mode=true
    _run.focus_mode=Control.FOCUS_NONE
    _touch_root.add_child(_run)
    _run.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    _run.offset_left=44
    _run.offset_right=150
    _run.offset_top=-310
    _run.offset_bottom=-248
    _run.toggled.connect(func(value: bool): sprint=value)
    _jump=_action_button("SALTAR",Vector2(-315,-140),func(): request_action(session.ACTION_JUMP))
    _reload=_action_button("RECARGA",Vector2(-315,-218),func(): request_action(session.ACTION_RELOAD))
    _crouch=_action_button("AGACHAR",Vector2(-445,-140),func():
        request_action(session.ACTION_STAND if bool(_last_state.get("crouched",false)) else session.ACTION_CROUCH))
    _weapon=_action_button("ARMA",Vector2(-190,-285),func(): request_action(session.ACTION_NEXT_WEAPON))
    _heal=_action_button("CURAR",Vector2(-445,-218),func(): request_action(session.ACTION_HEAL))
    _aim=_action_button("MIRA",Vector2(-315,-296),func(): request_action(session.ACTION_AIM))
    _grenade=_action_button("GRANADA",Vector2(-575,-140),func(): request_action(session.ACTION_GRENADE))
    _cover=_action_button("BARRERA",Vector2(-575,-218),func(): request_action(session.ACTION_COVER))
    _vehicle=_action_button("CONDUCIR",Vector2(-705,-140),func(): request_action(session.ACTION_VEHICLE))
    _vehicle.hide()
    layer.actions=[_pad,_fire_pad,_run,_jump,_reload,_crouch,_weapon,_heal,_aim,_grenade,_cover,_vehicle]

func _action_button(label: String,offset: Vector2,callback: Callable) -> Button:
    var button:=Button.new()
    button.text=label
    button.focus_mode=Control.FOCUS_NONE
    _touch_root.add_child(button)
    button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    button.offset_left=offset.x
    button.offset_top=offset.y
    button.offset_right=offset.x+118
    button.offset_bottom=offset.y+58
    button.pressed.connect(callback)
    return button

func request_action(action: int) -> void:
    if not _has_state or not send_controls or bool(_last_state.get("ended",false)) or bool(_last_state.get("eliminated",false)):
        return
    if session.multiplayer.multiplayer_peer==null or session.multiplayer.multiplayer_peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:
        return
    action_sequence+=1
    session.submit_action.rpc_id(1,session.PROTOCOL,action_sequence,action)

func _new_replica(id: int) -> Node3D:
    if rig_source==null:
        return null
    var holder:=Node3D.new()
    holder.name="RemoteRival"+str(id)
    world.add_child(holder)
    var rig: Node3D=rig_source.instantiate() as Node3D
    holder.add_child(rig)
    operator.fit_operator_visual(rig)
    for name in ["LilaAuroraSignatureKit","LilaAuroraOriginalHair"]:
        var part:=rig.find_child(name,true,false) as MeshInstance3D
        if part!=null:
            part.hide()
            part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    # Replicas are visual-only. Imported collision or processing bodies
    # must not interfere with camera rays or local movement.
    for collision in rig.find_children("*","CollisionObject3D",true,false):
        collision.collision_layer=0
        collision.collision_mask=0
    return holder

# Match the existing local bot's real skeletal hand mount and asset selection.
# No combat script, collider, inventory or synthetic replacement weapon.
func _sync_rival_weapon(holder: Node3D,slot: int) -> void:
    if int(holder.get_meta("weapon_slot",-1))==slot:
        return
    var skeleton:=holder.find_child("Skeleton3D",true,false) as Skeleton3D
    if skeleton==null:
        return
    var old:=skeleton.get_node_or_null("OnlineRivalHandSocket") as BoneAttachment3D
    if old!=null:
        skeleton.remove_child(old)
        old.queue_free()
    holder.set_meta("weapon_slot",slot)
    if slot<0 or slot>=WEAPONS.ENTRIES.size():
        return
    var path: String=str(WEAPONS.ENTRIES[slot].get("asset",""))
    if slot==WEAPONS.AR:
        path=WEAPON_VISUALS.AK_PATH
    elif slot==WEAPONS.AWM:
        path=WEAPON_VISUALS.AWM_PATH
    if path.is_empty() or not ResourceLoader.exists(path):
        return
    var hand: int=-1
    for i in range(skeleton.get_bone_count()):
        if skeleton.get_bone_name(i).to_lower().ends_with("righthand"):
            hand=i
            break
    var imported_scale: float=skeleton.global_transform.basis.get_scale().x
    if hand<0 or not is_finite(imported_scale) or imported_scale<=.00001:
        return
    var socket:=BoneAttachment3D.new()
    socket.name="OnlineRivalHandSocket"
    socket.bone_name=skeleton.get_bone_name(hand)
    skeleton.add_child(socket)
    var mount:=Node3D.new()
    mount.name="OnlineRivalWeaponMount"
    socket.add_child(mount)
    mount.scale=Vector3.ONE/imported_scale
    mount.position=Vector3(0,-.012,-.075)/imported_scale
    mount.rotation_degrees=Vector3(-12,0,90)
    var loader: Node3D=WEAPON_VISUALS.new()
    var visual: Node3D=loader._load_visual(path,"AK74OnlineRivalVisual" if slot==WEAPONS.AR else "OnlineRivalWeaponVisual",mount)
    loader.free()
    if visual==null:
        skeleton.remove_child(socket)
        socket.queue_free()
        return
    for collision in visual.find_children("*","CollisionObject3D",true,false):
        collision.collision_layer=0
        collision.collision_mask=0

func _sync_loot(items: Array) -> void:
    var seen: Dictionary={}
    for item in items:
        var id: int=int(item.id)
        var at: Vector3=item.position
        if not at.is_finite():
            continue
        seen[id]=true
        if loot_replicas.has(id):
            continue
        var pickup: Area3D=LOOT.new()
        pickup.name="RemoteLoot"+str(id)
        pickup.presentation_only=true
        pickup.pickup_type=str(item.kind)
        pickup.from_opponent=bool(item.from_opponent)
        pickup.quantity=int(item.quantity)
        pickup.terrain=world.get_node("AuroraTerrain")
        pickup.world_spot=Vector2(at.x,at.z)
        pickup.surface_height_override=at.y-.50
        world.add_child(pickup)
        loot_replicas[id]=pickup
    for id in loot_replicas.keys():
        if not seen.has(id):
            loot_replicas[id].hide()
            loot_replicas[id].queue_free()
            loot_replicas.erase(id)

func _sync_tactical(data: Dictionary) -> void:
    var seen_grenades: Dictionary={}
    var seen_covers: Dictionary={}
    for item in data.get("grenades",[]):
        var id: int=int(item.id)
        var at: Vector3=item.position
        if not at.is_finite():
            continue
        seen_grenades[id]=true
        if not grenade_replicas.has(id):
            var grenade: Node3D=GRENADE.new()
            grenade.presentation_only=true
            world.add_child(grenade)
            grenade.global_position=at
            grenade_replicas[id]=grenade
        grenade_targets[id]=at
    for item in data.get("covers",[]):
        var id: int=int(item.id)
        var at: Vector3=item.position
        if not at.is_finite():
            continue
        seen_covers[id]=true
        if not cover_replicas.has(id):
            var cover: StaticBody3D=COVER.new()
            cover.presentation_only=true
            world.add_child(cover)
            cover.global_position=at
            cover.rotation.y=float(item.yaw)
            cover_replicas[id]=cover
    for id in grenade_replicas.keys():
        if not seen_grenades.has(id):
            grenade_replicas[id].hide()
            grenade_replicas[id].queue_free()
            grenade_replicas.erase(id)
            grenade_targets.erase(id)
    for id in cover_replicas.keys():
        if not seen_covers.has(id):
            var cover: StaticBody3D=cover_replicas[id]
            cover.hide()
            cover.collision_layer=0
            cover.queue_free()
            cover_replicas.erase(id)
    var blast: int=int(data.get("blast_sequence",0))
    if blast>_last_blast_sequence:
        _last_blast_sequence=blast
        var at: Variant=data.get("blast_position")
        if at is Vector3 and at.is_finite():
            _show_blast(at)

func _show_blast(at: Vector3) -> void:
    # Visual confirmation only. No damage, collision or locally timed grenade.
    var flash:=MeshInstance3D.new()
    var sphere:=SphereMesh.new()
    sphere.radial_segments=10
    sphere.rings=4
    flash.mesh=sphere
    flash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var material:=StandardMaterial3D.new()
    material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color=Color(1.0,.51,.17,.72)
    flash.material_override=material
    world.add_child(flash)
    flash.global_position=at
    var fade:=flash.create_tween().set_parallel()
    fade.tween_property(flash,"scale",Vector3.ONE*5.5,.24)
    fade.tween_property(material,"albedo_color:a",0.0,.24)
    fade.chain().tween_callback(flash.queue_free)

func _sync_inventory(data: Dictionary) -> void:
    var inventory: Dictionary=data.inventory
    var weapon: int=int(data.weapon)
    var owned_awm: bool=bool(inventory.awm_owned)
    if weapon_visuals.awm_owned!=owned_awm:
        weapon_visuals.set_awm_owned(owned_awm)
    if weapon!=_presented_weapon:
        if weapon>=WEAPONS.SCAR and inventory.additions.has(weapon):
            weapon_visuals.add_expansion(weapon)
        weapon_visuals.equip(weapon)
        operator.set_equipped_weapon(weapon)
        _presented_weapon=weapon
    var aiming: bool=bool(data.aim)
    var zoom: float=float(data.zoom)
    if operator._ads_active!=aiming or not is_equal_approx(operator._ads_zoom,zoom):
        operator.set_ads(aiming,zoom)
    operator.set_firing(bool(data.firing))
    var reloading: bool=float(data.reload_remaining)>0.0
    if reloading and not _was_reloading:
        operator.play_weapon_action("reload",float(data.reload_remaining))
        weapon_visuals.play_source_action(weapon,"reload",float(data.reload_remaining))
    elif not reloading and _was_reloading:
        operator.cancel_reload_action()
        weapon_visuals.finish_source_reload(weapon)
    _was_reloading=reloading
    var medical: bool=bool(data.get("dual_loot",false)) and float(data.get("heal_remaining",0.0))>0.0
    if medical and not _was_duel_healing:
        operator.play_weapon_action("heal",float(data.heal_remaining))
    elif not medical and _was_duel_healing:
        operator.cancel_medical_action()
    _was_duel_healing=medical
    var shots: int=int(data.shots)
    if _last_shots>=0 and shots>_last_shots:
        operator.play_weapon_action("fire",.10)
        weapon_visuals.play_source_action(weapon,"fire",.10)
    _last_shots=shots
    _weapon.text=str(WEAPONS.ENTRIES[weapon]["short"])
    _heal.text="CURAR %d"%int(inventory.medkits)
    _grenade.text="GRANADA %d"%int(inventory.grenades)
    _grenade.disabled=int(inventory.grenades)<=0
    _cover.text="BARRERA %d"%int(inventory.covers)
    _cover.disabled=int(inventory.covers)<=0 or float(data.tactical.cover_cooldown)>0.0
    _aim.text="MIRA %dX"%roundi(zoom) if aiming else "MIRA"

func _sync_sounds(events: Array) -> void:
    # Separate sequence spaces: ambient bot traffic cannot suppress a
    # reliable local cue or nearby detonation that arrives later.
    for item in events:
        var id: int=int(item.seq)
        var kind: String=str(item.kind)
        if kind=="local" or kind=="remote_blast" or kind in ["duel_remote_shot","duel_remote_reload"]:
            if id<=last_critical_sound_sequence:
                continue
            last_critical_sound_sequence=id
        else:
            if id<=last_sound_sequence:
                continue
            last_sound_sequence=id
        var sample: String=str(item.sample)
        var at: Vector3=item.at
        var counter: String=kind
        match kind:
            "local":
                if not sound._samples.has(sample):
                    continue
                sound.play_event(sample)
                counter=sample
            "local_step":
                sound.play_operator_contact(bool(item.stone),bool(item.run))
            "remote_shot","duel_remote_shot":
                sound.play_world_shot(at,sample if kind=="duel_remote_shot" else "ar_fire")
            "duel_remote_reload":
                sound.play_world_reload(at)
            "remote_step":
                sound.play_bot_contact(at,bool(item.run),bool(item.stone))
            "remote_blast":
                sound.play_grenade_detonation(at)
            _:
                continue
        received_sounds[counter]=int(received_sounds.get(counter,0))+1

# Original aircraft builder and canopy mesh; never start local flight physics.
func _sync_air_presentation(mode: String,combat_controls: bool=true) -> void:
    operator.air_mode=mode
    sound.set_aircraft_audio(mode=="aircraft")
    if mode=="aircraft":
        if not is_instance_valid(flight_visual):
            flight_visual=FLIGHT_VISUAL.new()
            flight_visual.player=operator
            world.add_child(flight_visual)
            flight_visual._build_craft()
        _jump.text="SALTAR AVIÓN"
    else:
        _release_aircraft_visual()
        _jump.text="ABRIR PARACAÍDAS" if mode=="freefall" else "SALTAR"
    _jump.disabled=mode=="parachute"
    if operator._parachute_visual!=null:
        operator._parachute_visual.visible=mode=="parachute"
    _fire_pad.visible=mode=="ground" and combat_controls
    _run.visible=mode=="ground"
    _crouch.visible=mode=="ground"
    _weapon.visible=mode=="ground"
    _heal.visible=mode=="ground"
    _aim.visible=mode=="ground"
    _grenade.visible=mode=="ground"
    _cover.visible=mode=="ground"

func _release_aircraft_visual() -> void:
    if is_instance_valid(flight_visual):
        if is_instance_valid(flight_visual._craft):
            flight_visual._craft.hide()
            flight_visual._craft.queue_free()
        flight_visual.queue_free()
    flight_visual=null

func _sync_waiting(mode: String,duel_playable: bool=false,duel_medical: bool=false) -> void:
    if mode=="waiting":
        if not is_instance_valid(waiting_visual):
            waiting_visual=WAITING_ISLAND.new()
            waiting_visual.physical=false
            world.add_child(waiting_visual)
        # Never hide a held fire pad on a playable duel snapshot:
        # visibility notification resets its finger and emits released.
        _fire_pad.visible=duel_playable
        _reload.visible=duel_playable
        _crouch.hide()
        _weapon.hide()
        _heal.visible=duel_medical
        _aim.hide()
        _grenade.hide()
        _cover.hide()
        weapon_visuals.visible=duel_playable
        if not duel_playable:
            firing=false
    else:
        _release_waiting()
        _reload.visible=operator.air_mode=="ground"
        weapon_visuals.show()

func _release_waiting() -> void:
    if is_instance_valid(waiting_visual):
        waiting_visual.hide()
        waiting_visual.queue_free()
    waiting_visual=null

func _sync_vehicles(data: Dictionary) -> void:
    var seen: Dictionary={}
    _ride_id=int(data.get("ride",0))
    for item in data.get("cars",[]):
        var id: int=int(item.id)
        var transform: Transform3D=item.transform
        if id<=0 or not transform.is_finite():
            continue
        if not vehicle_replicas.has(id):
            var holder:=Node3D.new()
            holder.name="OnlineVehicle"+str(id)
            world.add_child(holder)
            holder.global_transform=transform
            var visual: Node3D=VEHICLE.create_authentic_visual(str(item.kind),holder) if not bool(item.get("fixture",false)) else null
            if visual==null and not (bool(item.get("fixture",false)) and OS.get_environment("AURORA_ONLINE_QA_VEHICLE")=="1"):
                holder.queue_free()
                continue
            if visual!=null:
                for collider in visual.find_children("*","CollisionObject3D",true,false):
                    collider.collision_layer=0
                    collider.collision_mask=0
            vehicle_replicas[id]=holder
        seen[id]=true
        vehicle_targets[id]=transform
    for id in vehicle_replicas.keys():
        if not seen.has(id):
            vehicle_replicas[id].hide()
            vehicle_replicas[id].queue_free()
            vehicle_replicas.erase(id)
            vehicle_targets.erase(id)
    _vehicle.visible=_ride_id!=0 or bool(data.get("near",false))
    _vehicle.text=("BAJAR" if bool(data.get("exit_ready",false)) else "DETÉN AUTO") if _ride_id!=0 else "CONDUCIR"
    if _ride_id!=0:
        for control in [_fire_pad,_reload,_run,_jump,_crouch,_weapon,_heal,_aim,_grenade,_cover]:
            control.hide()
        weapon_visuals.hide()
        firing=false
    else:
        _jump.visible=true

func apply_snapshot(data: Dictionary) -> void:
    if not data.has("position") or not data.has("rivals"):
        return
    _last_state=data
    _last_state_ms=Time.get_ticks_msec()
    last_ack=int(data.get("ack",0))
    if not _has_state:
        operator.global_position=data.position
        operator.show()
        _has_state=true
    var air: String=str(data.get("air_mode","ground"))
    var match_mode: String=str(data.get("match_mode","sector_battle"))
    if match_mode!=_presented_match_mode:
        operator.global_position=data.position
        _presented_match_mode=match_mode
    var duel: bool=bool(data.get("dual_combat",false))
    var duel_playable: bool=duel and bool(data.get("duel_ready",false)) and not bool(data.get("ended",false))
    _sync_air_presentation(air,duel_playable if duel else match_mode!="waiting")
    _sync_waiting(match_mode,duel_playable,duel_playable and bool(data.get("dual_loot",false)))
    var previous_ride: int=_ride_id
    _sync_vehicles(data.get("vehicles",{}))
    if previous_ride!=_ride_id:
        operator.global_position=data.position
        move_axis=Vector2.ZERO
        firing=false
    zone.visible=match_mode=="sector_battle"
    zone.set_zone_state(data.zone_center,float(data.zone_radius))
    var seen: Dictionary={}
    for item in data.rivals:
        var id: int=int(item.id)
        var at: Vector3=item.position
        var heading: float=float(item.yaw)
        if id<=0 or not at.is_finite() or not is_finite(heading):
            continue
        if not replicas.has(id):
            var holder: Node3D=_new_replica(id)
            if holder==null:
                continue
            replicas[id]=holder
            holder.global_position=item.position
            holder.rotation.y=float(item.yaw)
        seen[id]=true
        target_positions[id]=item.position
        target_yaws[id]=float(item.yaw)
        var replica: Node3D=replicas[id]
        if bool(data.get("expanded_room",false)):
            var vest: int=int(item.get("vest_level",0))
            var helmet: int=int(item.get("helmet_level",0))
            var protection: Node3D=replica.get_node_or_null("OnlineProtection")
            if protection==null and (vest>0 or helmet>0):
                protection=preload("res://scripts/player/aurora_protection_visual.gd").new()
                protection.name="OnlineProtection"
                replica.add_child(protection)
                protection.attach(replica)
            if protection!=null:
                protection.apply_levels(helmet,vest)
        var airborne: bool=bool(item.get("airborne",false))
        var waiting: bool=bool(item.get("waiting",false))
        _sync_rival_weapon(replica,-1 if airborne or waiting else int(item.get("weapon",-1)))
        var canopy:=replica.get_node_or_null("RealRivalParachute") as MeshInstance3D
        if airborne and canopy==null:
            canopy=CANOPY_VISUAL.create()
            replica.add_child(canopy)
        elif not airborne and canopy!=null:
            canopy.hide()
            canopy.queue_free()
        var animator:=replica.find_child("AnimationPlayer",true,false) as AnimationPlayer
        var clip: String=str(item.clip)
        if animator!=null:
            if not animator.has_animation(clip):
                clip="AuroraIdle"
            if animator.current_animation!=clip and animator.has_animation(clip):
                animator.play(clip,.1)
    for id in replicas.keys():
        if not seen.has(id):
            # Hide immediately and release; no rendering stale hidden enemies.
            replicas[id].hide()
            replicas[id].queue_free()
            replicas.erase(id)
            target_positions.erase(id)
            target_yaws.erase(id)
    _sync_loot(data.loot)
    _sync_tactical(data.tactical)
    _sync_inventory(data)
    if duel:
        _fire_pad.visible=duel_playable
        _reload.visible=duel_playable
        _grenade.hide()
        _cover.hide()
        if bool(data.get("expanded_room",false)):
            _weapon.visible=duel_playable
            _weapon.disabled=not bool(data.inventory.awm_owned)
            _aim.visible=duel_playable
            _crouch.visible=duel_playable
            operator.vest_level=int(data.vest_level)
            operator.helmet_level=int(data.helmet_level)
            operator.armor_points=float(data.armor)
            operator.helmet_points=float(data.helmet)
            operator._sync_protection_visual()
            operator.set_backpack_visual_level(int(data.backpack))
        _heal.visible=duel_playable and bool(data.get("dual_loot",false))
        _heal.disabled=int(data.inventory.medkits)<=0 or float(data.health)>=200.0 or float(data.get("heal_remaining",0.0))>0.0
        weapon_visuals.visible=duel_playable and not bool(data.get("eliminated",false))
        if not duel_playable:
            firing=false
    _crouch.text="LEVANTAR" if bool(data.crouched) else "AGACHAR"
    _status.text="ONLINE · %d VIVOS · HP %d · ZONA %.0fm · MUNICIÓN %d/%d%s"%[
        int(data.alive),roundi(float(data.health)),float(data.zone_radius),
        int(data.ammo),int(data.reserve)," · RECARGANDO" if float(data.reload_remaining)>0.0 else ""]
    if bool(data.get("terrain_room",false)):
        if bool(data.get("mixed_room",false)):
            _status.text+=" · IA %d"%int(data.bots)
        _status.text+=" · FASE %d · %ds"%[int(data.get("zone_phase",0))+1,int(data.get("zone_remaining",0))]
        if bool(data.get("zone_outside",false)):
            _status.text+=" · FUERA DE ZONA"
    if _ride_id!=0:
        for car in data.get("vehicles",{}).get("cars",[]):
            if int(car.id)==_ride_id:
                _status.text="ONLINE · AUTO %d km/h%s"%[roundi(float(car.speed))," · FRENA PARA BAJAR" if not bool(data.vehicles.get("exit_ready",false)) else ""]
                if str(data.vehicles.get("result",""))=="blocked_exit":
                    _status.text+=" · BUSCA SALIDA SEGURA"
    if match_mode=="waiting":
        if bool(data.get("mixed_flight",false)):
            _status.text="ISLA DE ESPERA · %d/50 · DESPEGUE EN %02d s"%[int(data.waiting_ready),ceili(float(data.waiting_remaining))]
        elif bool(data.get("dual_combat",false)):
            _status.text="DUELO LOCAL · HP %d · %s %d/%d · BAJAS %d"%[roundi(float(data.health)),str(WEAPONS.ENTRIES[int(data.weapon)].short),int(data.ammo),int(data.reserve),int(data.get("kills",0))]
            if bool(data.get("expanded_room",false)):
                _status.text="SALA %d VIVOS · "%int(data.alive)+_status.text+" · CHALECO %d · CASCO %d · MOCHILA %d"%[roundi(float(data.armor)),roundi(float(data.helmet)),int(data.backpack)]
            if bool(data.get("dual_loot",false)):
                _status.text+=" · BOTIQUINES %d"%int(data.inventory.medkits)
                if float(data.get("heal_remaining",0.0))>0.0:
                    _status.text+=" · CURANDO %.1fs"%float(data.heal_remaining)
                    _heal.text="CURANDO %.1fs"%float(data.heal_remaining)
        elif bool(data.get("dual_waiting",false)):
            _status.text="SALA DE RED · %d/2 JUGADORES · SIN COMBATE"%int(data.get("waiting_ready",1))
        else:
            _status.text="ISLA DE ESPERA · %d/50 PARTICIPANTES · DESPEGUE EN %02d s"%[int(data.get("waiting_ready",1)),ceili(float(data.get("waiting_remaining",0.0)))]
    elif air!="ground":
        _status.text="ONLINE · "+("AERONAVE" if air=="aircraft" else ("CAÍDA LIBRE" if air=="freefall" else "PARACAÍDAS"))
    if bool(data.get("mixed_flight",false)) and match_mode=="aircraft" and air=="ground":
        _status.text="ONLINE · ATERRIZADO · ESPERANDO DESPLIEGUE %d/46 IA"%int(data.get("flight_landed_bots",0))
    if bool(data.get("eliminated",false)):
        _status.text="ONLINE · ELIMINADO"
    elif bool(data.get("ended",false)):
        _status.text="ONLINE · VICTORIA IA" if bool(data.get("winner_bot",false)) else ("DUELO · VICTORIA" if bool(data.get("dual_combat",false)) and int(data.get("duel_winner",0))==int(data.get("self_peer",-1)) else "ONLINE · PARTIDA FINALIZADA")
    applied_snapshot_id=int(data.get("snapshot_id",0))

func _clear_remote() -> void:
    if _was_duel_healing:
        operator.cancel_medical_action()
        _was_duel_healing=false
    firing=false
    _fire_pad.hide()
    _fire_pad.reset()
    _sync_vehicles({})
    _release_waiting()
    _presented_match_mode=""
    sound.set_aircraft_audio(false)
    _release_aircraft_visual()
    if operator._parachute_visual!=null:
        operator._parachute_visual.hide()
    for id in replicas.keys():
        replicas[id].hide()
        replicas[id].queue_free()
    replicas.clear()
    _sync_loot([])
    _sync_tactical({})
    target_positions.clear()
    target_yaws.clear()
    _has_state=false
    operator.hide()
    zone.hide()

func _physics_process(delta: float) -> void:
    if not is_instance_valid(session) or session.multiplayer.multiplayer_peer==null:
        if _has_state:
            _clear_remote()
        return
    var connected: bool=session.multiplayer.multiplayer_peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED
    if not connected or (_has_state and Time.get_ticks_msec()-_last_state_ms>750):
        if _has_state:
            _clear_remote()
        _status.text="ONLINE · Esperando estado del servidor"
    if connected and int(session.state.get("snapshot_id",0))>int(_last_state.get("snapshot_id",0)):
        apply_snapshot(session.state)
    if connected and _has_state:
        _sync_sounds(session.drain_sounds())
    if _has_state:
        var factor: float=1.0-exp(-delta*15.0)
        operator.global_position=operator.global_position.lerp(_last_state.position,factor)
        operator.rotation.y=lerp_angle(operator.rotation.y,float(_last_state.body_yaw),factor)
        operator._yaw=operator._desired_yaw
        operator._camera_pivot.rotation.y=wrapf(operator._yaw-operator.rotation.y,-PI,PI)
        operator._camera_pivot.rotation.x=operator._desired_pitch
        operator._camera_pivot.position.y=lerpf(operator._camera_pivot.position.y,1.13 if bool(_last_state.get("crouched",false)) else 1.55,factor)
        var clip: String=str(_last_state.clip)
        if not clip.is_empty() and operator._current_clip!=clip:
            operator._play_matching_animation(clip)
        operator._camera.fov=lerpf(operator._camera.fov,clampf(74.0/float(_last_state.zoom),9.0,74.0),factor)
        var air: String=str(_last_state.get("air_mode","ground"))
        var desired_distance: float=operator.ADS_CAMERA_DISTANCE if bool(_last_state.aim) else operator.GROUND_CAMERA_DISTANCE
        var distance: float=operator._collision_safe_camera_distance(desired_distance) if air=="ground" else (7.1 if air=="aircraft" else 6.4)
        operator._camera.position.z=distance
        if air!="ground":
            operator._camera.fov=lerpf(operator._camera.fov,76.0,factor)
        if _ride_id!=0:
            operator._camera.position.z=operator._collision_safe_camera_distance(6.0,.20)
            operator._camera.fov=lerpf(operator._camera.fov,77.0,factor)
        if operator._avatar!=null:
            operator._avatar.visible=_ride_id==0 and air!="aircraft" and distance>1.50
        for id in vehicle_replicas.keys():
            var car: Node3D=vehicle_replicas[id]
            car.global_transform=car.global_transform.interpolate_with(vehicle_targets[id],factor)
        if is_instance_valid(flight_visual) and is_instance_valid(flight_visual._craft):
            flight_visual._craft.global_position=operator.global_position+Vector3(0,.7,-1)
            flight_visual._advance_visible_propellers(delta)
        for id in grenade_replicas.keys():
            var projectile: Node3D=grenade_replicas[id]
            projectile.global_position=projectile.global_position.lerp(grenade_targets[id],factor)
        for id in replicas.keys():
            var replica: Node3D=replicas[id]
            replica.global_position=replica.global_position.lerp(target_positions[id],factor)
            replica.rotation.y=lerp_angle(replica.rotation.y,target_yaws[id],factor)
    if not connected or not send_controls or not _has_state or bool(_last_state.get("ended",false)) or bool(_last_state.get("eliminated",false)):
        return
    _clock+=delta
    if _clock>=.05:
        _clock=fmod(_clock,.05)
        sequence+=1
        var keyboard: Vector2=Input.get_vector("move_left","move_right","move_forward","move_backward")
        var intent: Vector2=move_axis if move_axis.length_squared()>.001 else keyboard
        session.submit_input.rpc_id(1,session.PROTOCOL,sequence,intent.limit_length(1.0),
            operator._desired_yaw,operator._desired_pitch,sprint or Input.is_action_pressed("run"),firing)

func _notification(what: int) -> void:
    if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
        move_axis=Vector2.ZERO
        firing=false
        sprint=false
        if is_instance_valid(_run):
            _run.set_pressed_no_signal(false)
