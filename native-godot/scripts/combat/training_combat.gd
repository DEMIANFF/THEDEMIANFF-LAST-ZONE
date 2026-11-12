extends Node3D
## Offline native weapons training only. Real rays, ammo counts and impact bodies.
signal shot_fired(weapon: int,hit: bool)
signal impact_occurred
signal reload_started
signal healed
signal bot_shot(world_position: Vector3)

const AR_DAMAGE: int=26
const AWM_DAMAGE: int=115
const AWM_BOLT_SECONDS: float=.50
const BOT = preload("res://scripts/ai/aurora_bot.gd")
const WEAPON_VISUALS = preload("res://scripts/combat/weapon_visuals.gd")
const COVER=preload("res://scripts/combat/aurora_deployable_cover.gd")

var operator: CharacterBody3D
var hud: CanvasLayer
var navigation: Node3D
var terrain: StaticBody3D
var weapon_index: int=0
var ammo: Array[int]=[30,5]
var reserve: Array[int]=[180,30]
var trigger_held: bool=false
var aim_active: bool=false
var current_zoom: float=1.0
var cooldown: float=0.0
var reload_timer: float=0.0
var _targets: Array[CharacterBody3D]=[]
var _weapon_visuals: Node3D
var _weapon_model: Node3D # Explicit visual reference for older scripts
var eliminations: int = 0
var medkits_remaining: int = 2
var sector_battle_active: bool = false
var cover_charges: int=0
var cover_cooldown: float=0.0
var cover_last_block_reason: String=""
var _cover_serial: int=0
var _covers: Array[StaticBody3D]=[]
var tracer_events: int = 0
const TRACER_CAPACITY: int=8
# Visual effect length is bounded. Damage range and obstruction checks are
# unchanged; the 90 m yellow streak on Android was just a drawn cylinder.
const TRACER_MAX_LENGTH: float=24.0
const TRACER_LIFETIME: float=0.075
var _tracers: Array[MeshInstance3D]=[]
var _tracer_lifetimes: Array[float]=[]
var _tracer_cursor: int=0
var _tracer_materials: Array[StandardMaterial3D]=[]
var last_shot: Dictionary={}


func _ready() -> void:
    hud.fire_pressed.connect(_on_fire_pressed)
    hud.fire_released.connect(_on_fire_released)
    hud.aim_pressed.connect(_on_aim)
    hud.reload_pressed.connect(_on_reload)
    hud.weapon_pressed.connect(_on_weapon)
    hud.fire_aim_changed.connect(operator.fire_aim_delta)
    operator.sprint_cancelled.connect(hud.cancel_sprint)
    hud.heal_pressed.connect(_on_heal)
    hud.aurora_cover_pressed.connect(_on_cover_pressed)
    _make_targets()
    _draw_weapon_rig()
    _prepare_tracers()
    _sync_hud()
    hud.set_medkit_count(medkits_remaining)


func _process(dt: float) -> void:
    if cover_cooldown>0.0:
        cover_cooldown=maxf(0.0,cover_cooldown-dt)
        hud.set_aurora_cover_count(cover_charges,cover_cooldown)
    for i in range(_tracers.size()):
        if _tracer_lifetimes[i]>0.0:
            _tracer_lifetimes[i]=maxf(0.0,_tracer_lifetimes[i]-dt)
            _tracers[i].visible=_tracer_lifetimes[i]>0.0
    if not operator.can_act():
        trigger_held=false
        reload_timer=0.0
        return
    cooldown=maxf(0,cooldown-dt)
    if reload_timer>0:
        reload_timer=maxf(0,reload_timer-dt)
        if reload_timer==0:
            var cap: int=5 if weapon_index==1 else 30
            var taken: int=mini(cap-ammo[weapon_index],reserve[weapon_index])
            ammo[weapon_index]+=taken
            reserve[weapon_index]-=taken
            hud.impact("RECARGA COMPLETADA")
            _sync_hud()
    if trigger_held and weapon_index==0 and cooldown<=0 and reload_timer<=0:
        _shoot()


func _on_fire_pressed() -> void:
    if not operator.can_act():
        return
    if operator.royale_eliminated or operator.round_finished:
        return
    trigger_held=true
    operator.set_firing(true)
    if weapon_index==1:
        _shoot()  # One press, one bolt-action AWM round.
    elif cooldown<=0:
        _shoot()


func _on_fire_released() -> void:
    trigger_held=false
    operator.set_firing(false)


func _on_weapon() -> void:
    if not operator.can_act():
        return
    weapon_index=1-weapon_index
    trigger_held=false
    operator.set_firing(false)
    cooldown=.20
    reload_timer=0
    aim_active=false
    current_zoom=1.0
    if _weapon_visuals:
        _weapon_visuals.equip(weapon_index)
    operator.set_equipped_weapon(weapon_index)
    operator.set_ads(false,1.0)
    hud.set_aim(false,"MIRA LIBRE",1.0)
    _sync_hud()


func _on_aim() -> void:
    if not operator.can_act():
        return
    # AR cycles through free -> x2 -> x4 -> free. AWM has its exclusive x8.
    if weapon_index == 1:
        current_zoom = 1.0 if current_zoom >= 8.0 else 8.0
    else:
        current_zoom = 2.0 if current_zoom < 1.8 else 4.0 if current_zoom < 3.8 else 1.0
    aim_active = current_zoom > 1.0
    operator.set_ads(aim_active,current_zoom)
    var label: String = "MIRA LIBRE" if not aim_active else "AWM / 8X" if weapon_index==1 else "AR / "+str(int(current_zoom))+"X"
    hud.set_aim(aim_active,label,current_zoom)


func _on_heal() -> void:
    if not operator.can_act():
        return
    if operator.royale_eliminated:
        return
    if medkits_remaining<=0:
        hud.impact("SIN BOTIQUINES")
        return
    if operator.training_health>=99.5:
        hud.impact("SALUD COMPLETA")
        return
    medkits_remaining-=1
    operator.receive_training_heal(45.0)
    hud.set_medkit_count(medkits_remaining)
    hud.impact("BOTIQUIN +45 VIDA")
    healed.emit()


func _on_reload() -> void:
    if not operator.can_act():
        return
    if reload_timer>0:
        return
    var cap: int=5 if weapon_index==1 else 30
    if ammo[weapon_index]>=cap or reserve[weapon_index]<=0:
        hud.impact("SIN NECESIDAD DE RECARGA")
        return
    reload_timer=3.1 if weapon_index==1 else 1.55
    operator.play_weapon_action("reload",reload_timer)
    reload_started.emit()
    hud.impact("RECARGANDO")


func _shoot() -> void:
    if not operator.can_act():
        return
    if operator.royale_eliminated or cooldown>0 or reload_timer>0:
        return
    if ammo[weapon_index]<=0:
        _on_reload()
        return
    ammo[weapon_index]-=1
    cooldown=AWM_BOLT_SECONDS if weapon_index==1 else .105
    _sync_hud()
    operator.apply_recoil(.02 if weapon_index==1 else .005)
    operator.play_weapon_action("fire",.24 if weapon_index==1 else .13)
    var camera:=operator.get_view_camera() as Camera3D
    if camera==null:
        return
    # Sight selects a point; the real muzzle must have an unobstructed path
    # to it. A camera above a low wall cannot fire through that wall.
    var screen_center: Vector2=camera.get_viewport().get_visible_rect().size*.5
    var from: Vector3=camera.project_ray_origin(screen_center)
    var direction: Vector3=camera.project_ray_normal(screen_center)
    var muzzle: Vector3=_weapon_visuals.muzzle_position()
    var hit: Dictionary=resolve_shot(from,direction,muzzle)
    shot_fired.emit(weapon_index,not hit.is_empty())
    _alert_nearby_bots(muzzle,operator)
    var endpoint: Vector3=hit.get("position",from+direction*250.0)
    last_shot={"muzzle":muzzle,"endpoint":endpoint,"collider":hit.get("collider")}
    _spawn_tracer(muzzle,endpoint)
    if hit.is_empty():
        return
    impact_occurred.emit()
    var body=hit.get("collider")
    if body is CharacterBody3D and body.is_in_group("training_target"):
        var eliminated: bool=body.take_training_damage(float(AWM_DAMAGE if weapon_index==1 else AR_DAMAGE),operator)
        hud.impact("ENEMIGO NEUTRALIZADO" if eliminated else "IMPACTO CONFIRMADO")
    elif body is StaticBody3D and body.is_in_group("aurora_deployable_cover"):
        body.call("take_damage",float(AWM_DAMAGE if weapon_index==1 else AR_DAMAGE))
        hud.impact("BARRERA AURORA / IMPACTO")


func _clear_cover() -> void:
    for cover in _covers:
        if is_instance_valid(cover):
            cover.queue_free()
    _covers.clear()


func _on_cover_pressed() -> void:
    deploy_aurora_cover()


func deploy_aurora_cover() -> bool:
    cover_last_block_reason=""
    # Only a living ground combatant in a real round may place cover.
    if not sector_battle_active or not operator.can_act() or cover_charges<=0:
        cover_last_block_reason="estado_no_apto: sector="+str(sector_battle_active)+" can_act="+str(operator.can_act())+" charges="+str(cover_charges)
        return false
    if cover_cooldown>0.0:
        cover_last_block_reason="cooldown="+str(cover_cooldown)
        return false
    var camera: Camera3D=operator.get_view_camera()
    if camera==null or terrain==null:
        cover_last_block_reason="missing_camera_or_terrain"
        return false
    var forward: Vector3=-camera.global_basis.z
    forward.y=0.0
    if not forward.is_finite() or forward.length_squared()<.05:
        cover_last_block_reason="invalid_forward="+str(forward)
        return false
    forward=forward.normalized()
    var center: Vector3=operator.global_position+forward*3.6
    # Follow the actual terrain triangles under both wall ends; otherwise
    # sloped Aurora ground falsely reports obstruction on safe open sites.
    var sideways:=Vector3(-forward.z,0.0,forward.x)
    var ground_y: float=maxf(
        terrain.height_at(center.x,center.z),
        maxf(terrain.height_at(center.x+sideways.x*1.55,center.z+sideways.z*1.55),
            terrain.height_at(center.x-sideways.x*1.55,center.z-sideways.z*1.55)))
    if not is_finite(ground_y):
        cover_last_block_reason="invalid_terrain_height="+str(ground_y)
        return false
    var heading: float=atan2(-forward.x,-forward.z)

    # Validate real occupancy before consuming a charge. Start the overlap
    # probe slightly above the floor to tolerate sloped island terrain.
    var probe_shape:=BoxShape3D.new()
    probe_shape.size=Vector3(3.20,1.85,.58)
    var probe:=PhysicsShapeQueryParameters3D.new()
    probe.shape=probe_shape
    probe.collision_mask=1
    probe.exclude=[operator.get_rid()]
    probe.transform=Transform3D(Basis(Vector3.UP,heading),
        Vector3(center.x,ground_y+1.28,center.z))
    var overlaps: Array[Dictionary]=operator.get_world_3d().direct_space_state.intersect_shape(probe,16)
    for overlap in overlaps:
        var collider: Object=overlap.get("collider")
        # Aurora is an irregular terrain mesh: a wall footprint is SUPPOSED
        # to touch the walkable island. Reject actors/buildings/other cover,
        # but do not treat the ground itself as an occupied building.
        if collider==terrain:
            continue
        cover_last_block_reason="occupied:"+str(collider.name if collider is Node else collider)+" height="+str(ground_y)
        hud.impact("NO HAY ESPACIO PARA BARRERA")
        return false

    var active: int=0
    for existing in _covers:
        if is_instance_valid(existing) and existing.has_method("is_active") and bool(existing.call("is_active")):
            active+=1
    if active>=4:
        cover_last_block_reason="active_limit"
        hud.impact("LIMITE DE BARRERAS ACTIVAS")
        return false
    var cover: StaticBody3D=COVER.new()
    _cover_serial+=1
    cover.name="AuroraIceCover"+str(_cover_serial)
    add_child(cover)
    cover.global_position=Vector3(center.x,ground_y,center.z)
    cover.rotation.y=heading
    _covers.append(cover)
    cover_charges-=1
    cover_cooldown=9.0
    hud.set_aurora_cover_count(cover_charges,cover_cooldown)
    hud.impact("BARRERA AURORA DESPLEGADA")
    return true


func end_sector_battle() -> void:
    sector_battle_active=false
    _clear_cover()
    cover_charges=0
    cover_cooldown=0.0
    hud.set_aurora_cover_count(0)
    reload_timer=0.0
    trigger_held=false
    operator.set_firing(false)
    for bot in _targets:
        if is_instance_valid(bot):
            bot.set_physics_process(false)


func begin_sector_battle() -> void:
    _clear_cover()
    sector_battle_active=true
    cover_charges=2
    cover_cooldown=0.0
    hud.set_aurora_cover_count(cover_charges)
    trigger_held=false
    operator.set_firing(false)
    aim_active=false
    current_zoom=1.0
    operator.set_ads(false,1.0)
    weapon_index=0
    cooldown=0.0
    reload_timer=0.0
    ammo=[30,5]
    reserve=[90,12]
    medkits_remaining=2
    eliminations=0
    # 8 bots + player = 9 fighters in the explicitly limited sector pilot.
    var additional_spawns: Array[Vector2]=[
        Vector2(-47,-10),Vector2(55,-17),Vector2(26,-55),Vector2(-35,-48)]
    while _targets.size()<8:
        var i: int=_targets.size()
        var bot: CharacterBody3D=BOT.new()
        bot.name="AuroraPatrol"+str(i+1)
        bot.terrain=terrain
        bot.operator=operator
        bot.navigation=navigation
        if navigation:
            navigation.actors.append(bot)
        bot.spawn_coordinates=additional_spawns[i-4]
        bot.eliminated.connect(_on_bot_eliminated)
        bot.weapon_fired.connect(func(at: Vector3): bot_shot.emit(at))
        bot.weapon_fired.connect(_on_bot_weapon_fired.bind(bot))
        add_child(bot)
        _targets.append(bot)
    for bot in _targets:
        bot.configure_sector_battle(_targets)
    if _weapon_visuals:
        _weapon_visuals.equip(0)
    operator.set_equipped_weapon(0)
    hud.set_training_radar_sources(operator,_targets)
    hud.set_aim(false,"MIRA LIBRE",1.0)
    hud.set_medkit_count(medkits_remaining)
    hud.set_eliminations(0)
    _sync_hud()


func active_fighter_count() -> int:
    var count: int=0 if operator.royale_eliminated else 1
    for bot in _targets:
        if is_instance_valid(bot) and bot.health>0:
            count+=1
    return count


func collect_sector_loot(kind: String) -> bool:
    if not sector_battle_active or operator.royale_eliminated:
        return false
    match kind:
        "medkit":
            if medkits_remaining>=5:
                return false
            medkits_remaining=mini(medkits_remaining+1,5)
            hud.set_medkit_count(medkits_remaining)
            hud.impact("BOTIQUIN RECOGIDO +1")
        "ammo_ar":
            reserve[0]+=45
            hud.impact("MUNICION AR +45")
        "ammo_awm":
            reserve[1]+=8
            hud.impact("MUNICION AWM +8")
        "cover_charge":
            if cover_charges>=3:
                return false
            cover_charges+=1
            hud.set_aurora_cover_count(cover_charges,cover_cooldown)
            hud.impact("BARRERA AURORA +1")
        _:
            return false
    _sync_hud()
    return true


func resolve_shot(from: Vector3, direction: Vector3, muzzle: Vector3) -> Dictionary:
    var space:=operator.get_world_3d().direct_space_state
    var query:=PhysicsRayQueryParameters3D.create(from,from+direction*250.0)
    query.exclude=[operator.get_rid()]
    var sight: Dictionary=space.intersect_ray(query)
    var target: Vector3=sight.get("position",from+direction*250.0)
    # Check chest-to-muzzle too: a barrel poking through a thin wall must not
    # put the damage ray on the other side of the obstacle.
    var chest: Vector3=operator.global_position+Vector3.UP*(.92 if operator._crouching else 1.35)
    query.from=chest
    query.to=muzzle
    var blocked: Dictionary=space.intersect_ray(query)
    if not blocked.is_empty():
        return blocked
    query.from=muzzle
    query.to=target+(target-muzzle).normalized()*.04
    query.hit_from_inside=true
    return space.intersect_ray(query)


func _prepare_tracers() -> void:
    var mesh:=CylinderMesh.new()
    mesh.top_radius=1.0
    mesh.bottom_radius=1.0
    mesh.height=1.0
    mesh.radial_segments=6
    for color in [Color(.98,.83,.56),Color(.65,.82,.99)]:
        var material:=StandardMaterial3D.new()
        material.albedo_color=color
        material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
        _tracer_materials.append(material)
    for i in range(TRACER_CAPACITY):
        var tracer:=MeshInstance3D.new()
        tracer.name="BulletTracer"+str(i)
        tracer.mesh=mesh
        tracer.visible=false
        tracer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(tracer)
        _tracers.append(tracer)
        _tracer_lifetimes.append(0.0)


func _spawn_tracer(from: Vector3,to: Vector3) -> void:
    var span: Vector3=to-from
    if not span.is_finite() or span.length_squared()<=.0001:
        return
    var distance: float=minf(span.length(),TRACER_MAX_LENGTH)
    var visual: MeshInstance3D=_tracers[_tracer_cursor]
    var heading: Vector3=span.normalized()
    var radius: float=.014 if weapon_index==0 else .024
    visual.global_transform=Transform3D(Basis(Quaternion(Vector3.UP,heading)) * Basis.from_scale(Vector3(radius,distance,radius)),from+heading*distance*.5)
    visual.material_override=_tracer_materials[weapon_index]
    visual.visible=true
    _tracer_lifetimes[_tracer_cursor]=TRACER_LIFETIME
    _tracer_cursor=(_tracer_cursor+1)%TRACER_CAPACITY
    tracer_events+=1


func _sync_hud() -> void:
    hud.set_weapon("AWM / FRANCOTIRADOR" if weapon_index==1 else "AR-7 / ASALTO",ammo[weapon_index],reserve[weapon_index])


func _make_targets() -> void:
    # Four real skinned training opponents, independently moving and damageable.
    # Bounded LOS: walls and rocks block attacks; NPCs are not online players.
    var points: Array[Vector2]=[
        Vector2(-3,-14), Vector2(-14,-24),
        Vector2(33,-10), Vector2(12,-43)]
    for i in range(points.size()):
        var bot: CharacterBody3D=BOT.new()
        bot.name="AuroraPatrol"+str(i+1)
        bot.terrain=terrain
        bot.operator=operator
        bot.spawn_coordinates=points[i]
        bot.eliminated.connect(_on_bot_eliminated)
        bot.weapon_fired.connect(func(at: Vector3): bot_shot.emit(at))
        bot.weapon_fired.connect(_on_bot_weapon_fired.bind(bot))
        add_child(bot)
        _targets.append(bot)


## Real weapon fire provides a noisy 3D location, not a target lock.
## Perception only updates living combatants in an active BR round.
func _on_bot_weapon_fired(at: Vector3, shooter: CharacterBody3D) -> void:
    _alert_nearby_bots(at,shooter)


func _alert_nearby_bots(at: Vector3, shooter: Node3D) -> void:
    if not sector_battle_active or not at.is_finite():
        return
    for opponent in _targets:
        if is_instance_valid(opponent) and opponent.health>0:
            opponent.hear_gunshot(at,shooter)


func _on_bot_eliminated(_agent: CharacterBody3D,killer: Node3D) -> void:
    # Correct BR stats: only kills caused by this player count. Enemy-on-enemy
    # and zone eliminations reduce alive count but do NOT credit a player kill.
    if killer==operator:
        eliminations+=1
        hud.set_eliminations(eliminations)
        hud.impact("BAJA CONFIRMADA  /  "+str(eliminations))


func _draw_weapon_rig() -> void:
    # AK-74 and AWM each have a real imported GLB. Mount compensates for the
    # female FBX's centimeter-scale parent, then follows the skinned right hand.
    _weapon_visuals=WEAPON_VISUALS.new()
    _weapon_visuals.name="ActiveWeaponVisuals"
    add_child(_weapon_visuals)
    _weapon_visuals.attach_to_player(operator)
    _weapon_model=_weapon_visuals.ak
    operator.set_equipped_weapon(weapon_index)
    if _weapon_visuals.right_hand_socket==null:
        push_warning("Rigged right-hand attachment unavailable")
