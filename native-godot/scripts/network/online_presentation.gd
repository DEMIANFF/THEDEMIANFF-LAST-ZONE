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
var sound: Node3D
var last_sound_sequence: int=0
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
    var jump: Button=_action_button("SALTAR",Vector2(-315,-140),func(): request_action(session.ACTION_JUMP))
    var reload: Button=_action_button("RECARGA",Vector2(-315,-218),func(): request_action(session.ACTION_RELOAD))
    _crouch=_action_button("AGACHAR",Vector2(-445,-140),func():
        request_action(session.ACTION_STAND if bool(_last_state.get("crouched",false)) else session.ACTION_CROUCH))
    _weapon=_action_button("ARMA",Vector2(-190,-285),func(): request_action(session.ACTION_NEXT_WEAPON))
    _heal=_action_button("CURAR",Vector2(-445,-218),func(): request_action(session.ACTION_HEAL))
    _aim=_action_button("MIRA",Vector2(-315,-296),func(): request_action(session.ACTION_AIM))
    _grenade=_action_button("GRANADA",Vector2(-575,-140),func(): request_action(session.ACTION_GRENADE))
    _cover=_action_button("BARRERA",Vector2(-575,-218),func(): request_action(session.ACTION_COVER))
    layer.actions=[_pad,_fire_pad,_run,jump,reload,_crouch,_weapon,_heal,_aim,_grenade,_cover]

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
    if not _has_state or not send_controls or bool(_last_state.get("ended",false)):
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
    return holder

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
    # Repeated short snapshot history tolerates individual UDP packet losses.
    # Each event is consumed at most once, and old events never replay.
    for item in events:
        var id: int=int(item.seq)
        if id<=last_sound_sequence:
            continue
        last_sound_sequence=id
        var kind: String=str(item.kind)
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
            "remote_shot":
                sound.play_world_shot(at)
            "remote_step":
                sound.play_bot_contact(at,bool(item.run),bool(item.stone))
            "remote_blast":
                sound.play_grenade_detonation(at)
            _:
                continue
        received_sounds[counter]=int(received_sounds.get(counter,0))+1

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
    zone.show()
    zone.set_zone_state(data.zone_center,float(data.zone_radius))
    var seen: Dictionary={}
    for item in data.rivals:
        var id: int=int(item.id)
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
    _crouch.text="LEVANTAR" if bool(data.crouched) else "AGACHAR"
    _status.text="ONLINE · %d VIVOS · HP %d · ZONA %.0fm · MUNICIÓN %d/%d%s"%[
        int(data.alive),roundi(float(data.health)),float(data.zone_radius),
        int(data.ammo),int(data.reserve)," · RECARGANDO" if float(data.reload_remaining)>0.0 else ""]
    if bool(data.get("ended",false)):
        _status.text="ONLINE · ELIMINADO" if bool(data.get("eliminated",false)) else "ONLINE · PARTIDA FINALIZADA"

func _clear_remote() -> void:
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
    if connected and session.state!=_last_state:
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
        var desired_distance: float=operator.ADS_CAMERA_DISTANCE if bool(_last_state.aim) else operator.GROUND_CAMERA_DISTANCE
        var distance: float=operator._collision_safe_camera_distance(desired_distance)
        operator._camera.position.z=distance
        if operator._avatar!=null:
            operator._avatar.visible=distance>1.50
        for id in grenade_replicas.keys():
            var projectile: Node3D=grenade_replicas[id]
            projectile.global_position=projectile.global_position.lerp(grenade_targets[id],factor)
        for id in replicas.keys():
            var replica: Node3D=replicas[id]
            replica.global_position=replica.global_position.lerp(target_positions[id],factor)
            replica.rotation.y=lerp_angle(replica.rotation.y,target_yaws[id],factor)
    if not connected or not send_controls or not _has_state or bool(_last_state.get("ended",false)):
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
