extends Node3D
## Offline native weapons training only. Real rays, ammo counts and impact bodies.
signal shot_fired(weapon: int,hit: bool)
signal impact_occurred
signal reload_started
signal reload_cue(sample: StringName)
signal awm_bolt_cycled
signal healed
signal bot_shot(world_position: Vector3)
signal bot_foot_contact(world_position: Vector3,running: bool,on_stone: bool)
signal grenade_detonated(world_position: Vector3)
const GRENADE = preload("res://scripts/combat/aurora_grenade.gd")
const MAX_GRENADES: int=3
const BLAST_RADIUS: float=6.5
## Actual battle elimination event for physical opponent supply drops.
signal bot_eliminated(victim: CharacterBody3D, killer: Node3D)

const AR_DAMAGE: int=26
const AWM_DAMAGE: int=115
# OpponentCollider is an actual 1.74 m capsule whose base is at local y=.01.
# A headshot is only awarded when the PhysicsServer's real hit enters
# the upper capsule section, not merely when the camera points high.
const HEADSHOT_START_HEIGHT: float=1.43
const HEADSHOT_TOP_HEIGHT: float=1.78
const AR_HEADSHOT_MULTIPLIER: float=1.85
const AWM_HEADSHOT_MULTIPLIER: float=1.65
const AWM_BOLT_SECONDS: float=.50
# Time of the mechanical bolt cue AFTER a confirmed AWM round. The lock
# remains 0.50 s. This event is original, not copied from 2019 assets.
const AWM_BOLT_CUE_SECONDS: float=.28
# Field first aid uses a real time window. Interruptions never waste a kit.
const HEAL_APPLY_SECONDS: float=3.0
const SYRINGE_APPLY_SECONDS: float=1.35
const HEAL_MOVE_TOLERANCE_SQ: float=.16
const AR_RELOAD_SECONDS: float=1.55
const AWM_RELOAD_SECONDS: float=3.10
const BOT = preload("res://scripts/ai/aurora_bot.gd")
const RESIDENTIAL=preload("res://scripts/world/coastal_residential_layout.gd")
const WEAPON_VISUALS = preload("res://scripts/combat/weapon_visuals.gd")
const MEDKIT_VISUAL = preload("res://scripts/player/aurora_medkit_visual.gd")
const COVER=preload("res://scripts/combat/aurora_deployable_cover.gd")
const WEAPONS=preload("res://scripts/combat/aurora_weapon_catalog.gd")
const TRAINING_ARMORY=preload("res://scripts/match/training_armory.gd")
var _training_armory: Node3D

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
var _reload_duration: float=0.0
var _reload_ui_clock: float=0.0
var _mp40_reload_cue: int=0
var _awm_bolt_remaining: float=0.0
var _awm_bolt_pending: bool=false
var shots_fired_total: int=0
var shots_hit_total: int=0
var headshots_total: int=0
var reloads_completed: int=0
var empty_magazine_attempts: int=0
var _targets: Array[CharacterBody3D]=[]
var _weapon_visuals: Node3D
var _medical_visual: Node3D
var _weapon_model: Node3D # Explicit visual reference for older scripts
var eliminations: int = 0
# Only one health-death signal per physical enemy may award kills, loot and
# public kill-feed events. Reset at the start of each new 50-person round.
var _eliminated_actors_this_round: Dictionary={}
# Measured from actual CharacterBody3D health lost and successful Area3D pickups.
var damage_dealt: float=0.0
var loot_collected: int=0
var opponent_caches_collected: int=0
var medkits_remaining: int = 2
var syringes_remaining: int=0
var grenades_remaining: int=0
var _grenades: Array[Node3D]=[]
var _heal_remaining: float=0.0
var _heal_duration: float=HEAL_APPLY_SECONDS
var _healing_with_syringe: bool=false
var _heal_anchor: Vector3=Vector3.ZERO
# Real match equipment: two weapon slots, an upgradeable backpack and armor.
# The BR's AWM must be found as a physical pickup; training keeps both guns.
var weapon_owned: Array[bool]=[true,true]
var backpack_level: int=0
const AR_RESERVE_BASE: int=180
const AWM_RESERVE_BASE: int=30
const AR_RESERVE_BACKPACK: int=360
const AWM_RESERVE_BACKPACK: int=60
var sector_battle_active: bool = false
## Single visible Battle Royale playlist: 50 physical fighters, offline.
## Internal small-roster sizes remain ONLY for deterministic engineering QA.
const CLASSIC_BR_PARTICIPANTS: int=50
# The parachute landing must not overlap an enemy spawn; this is only a
# pre-match placement rule, not invulnerability or fake active-bot movement.
const PLAYER_LANDING_CLEARANCE: float=14.0
var encounter_size: int=9
const ALLOWED_ENCOUNTERS: Array[int]=[9,20,30,CLASSIC_BR_PARTICIPANTS]
var cover_charges: int=0
var cover_cooldown: float=0.0
var cover_last_block_reason: String=""
var _cover_serial: int=0
var _covers: Array[StaticBody3D]=[]
var tracer_events: int = 0
var bot_tracer_events: int=0
const TRACER_CAPACITY: int=8
# Additional pooled enemy tracers are rendered only for real ray hits.
# Separate from the existing 8-player pool (old QA invariant).
const BOT_TRACER_CAPACITY: int=8
# Visual effect length is bounded. Damage range and obstruction checks are
# unchanged; the 90 m yellow streak on Android was just a drawn cylinder.
const TRACER_MAX_LENGTH: float=24.0
const TRACER_LIFETIME: float=0.075
var _tracers: Array[MeshInstance3D]=[]
var _tracer_lifetimes: Array[float]=[]
var _tracer_cursor: int=0
var _tracer_materials: Array[StandardMaterial3D]=[]
var _bot_tracers: Array[MeshInstance3D]=[]
var _bot_tracer_lifetimes: Array[float]=[]
var _bot_tracer_cursor: int=0
var _bot_tracer_material: StandardMaterial3D
var last_shot: Dictionary={}


func _ready() -> void:
    hud.fire_pressed.connect(_on_fire_pressed)
    hud.fire_released.connect(_on_fire_released)
    hud.aim_pressed.connect(_on_aim)
    hud.reload_pressed.connect(_on_reload)
    hud.weapon_pressed.connect(_on_weapon)
    hud.inventory_equip_requested.connect(_equip_inventory_weapon)
    hud.grenade_requested.connect(throw_grenade)
    operator.incoming_fire.connect(func(at: Vector3):
        hud.show_incoming_fire(at,operator))
    hud.fire_aim_changed.connect(operator.fire_aim_delta)
    operator.sprint_cancelled.connect(hud.cancel_sprint)
    hud.heal_pressed.connect(_on_heal)
    hud.syringe_pressed.connect(func(): _on_heal(true))
    operator.player_damaged.connect(_on_healing_damage)
    operator.armor_changed.connect(func(_value: float): _sync_hud())
    hud.aurora_cover_pressed.connect(_on_cover_pressed)
    operator.tactical_acceleration_activated.connect(
        hud.start_tactical_acceleration)
    _make_targets()
    _draw_weapon_rig()
    _draw_medical_rig()
    _prepare_tracers()
    _sync_hud()
    hud.set_medkit_count(medkits_remaining)
    hud.set_heal_channel(false,0.0,HEAL_APPLY_SECONDS,medkits_remaining)


func _process(dt: float) -> void:
    if cover_cooldown>0.0:
        cover_cooldown=maxf(0.0,cover_cooldown-dt)
        hud.set_aurora_cover_count(cover_charges,cover_cooldown)
    for i in range(_tracers.size()):
        if _tracer_lifetimes[i]>0.0:
            _tracer_lifetimes[i]=maxf(0.0,_tracer_lifetimes[i]-dt)
            _tracers[i].visible=_tracer_lifetimes[i]>0.0
    for i in range(_bot_tracers.size()):
        if _bot_tracer_lifetimes[i]>0.0:
            _bot_tracer_lifetimes[i]=maxf(0.0,_bot_tracer_lifetimes[i]-dt)
            _bot_tracers[i].visible=_bot_tracer_lifetimes[i]>0.0
    if _heal_remaining>0.0:
        var moving: bool=(operator._move_axis.length_squared()>.01 or
            operator._sprint_touch or operator._jump_requested or
            operator.global_position.distance_squared_to(_heal_anchor)>HEAL_MOVE_TOLERANCE_SQ)
        if not operator.can_act() or moving:
            _cancel_healing("CURACION INTERRUMPIDA")
        else:
            _heal_remaining=maxf(0.0,_heal_remaining-maxf(0.0,dt))
            if _heal_remaining<=0.0:
                _complete_healing()
            else:
                hud.set_heal_channel(true,_heal_remaining,_heal_duration,medkits_remaining)
    if not operator.can_act():
        _cancel_healing()
        trigger_held=false
        _cancel_awm_bolt()
        _clear_reload()
        return
    cooldown=maxf(0,cooldown-dt)
    _advance_awm_bolt(dt)
    if reload_timer>0:
        reload_timer=maxf(0,reload_timer-dt)
        _reload_ui_clock-=dt
        if weapon_index==WEAPONS.MP40:
            _advance_mp40_reload(1.0-reload_timer/_reload_duration)
        if reload_timer==0:
            var cap: int=WEAPONS.ENTRIES[weapon_index]["capacity"]
            var pool: int=WEAPONS.reserve_slot(weapon_index)
            var taken: int=mini(maxi(0,cap-ammo[weapon_index]),reserve[pool])
            ammo[weapon_index]+=taken
            reserve[pool]-=taken
            reloads_completed+=1
            _clear_reload()
            hud.impact("RECARGA COMPLETADA")
            _sync_hud()
        elif _reload_ui_clock<=0.0:
            _reload_ui_clock=.10
            hud.set_reload_state(true,reload_timer,_reload_duration)
    if trigger_held and weapon_index!=WEAPONS.AWM and cooldown<=0 and reload_timer<=0:
        _shoot()


func _on_fire_pressed() -> void:
    if not operator.can_act():
        return
    if operator.royale_eliminated or operator.round_finished:
        return
    if ammo[weapon_index]<=0 and reserve[WEAPONS.reserve_slot(weapon_index)]<=0:
        empty_magazine_attempts+=1
        trigger_held=false
        operator.set_firing(false)
        hud.impact("SIN MUNICION / BUSCA BOTIN")
        return
    _cancel_healing("CURACION CANCELADA / DISPARO")
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
    for step in range(1,weapon_owned.size()):
        var next: int=(weapon_index+step)%weapon_owned.size()
        if weapon_owned[next]:
            _equip_inventory_weapon(next)
            return
    _equip_inventory_weapon(WEAPONS.AWM)


## Both the quick-switch button and actual inventory use this same
## authoritative equipment path, so an uncollected AWM cannot be equipped.
func _equip_inventory_weapon(index: int) -> void:
    if not operator.can_act() or index<0 or index>=weapon_owned.size():
        return
    if not weapon_owned[index]:
        hud.impact("ARMA SIN RECOGER")
        return
    if index==weapon_index:
        return
    _cancel_healing("CURACION CANCELADA / ARMA")
    _cancel_awm_bolt()
    weapon_index=index
    trigger_held=false
    operator.set_firing(false)
    cooldown=.20
    _clear_reload()
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
    _cancel_healing("CURACION CANCELADA / MIRA")
    # AR cycles through free -> x2 -> x4 -> free. AWM has its exclusive x8.
    if weapon_index == 1:
        current_zoom = 1.0 if current_zoom >= 8.0 else 8.0
    else:
        current_zoom = 2.0 if current_zoom < 1.8 else 4.0 if current_zoom < 3.8 else 1.0
    aim_active = current_zoom > 1.0
    operator.set_ads(aim_active,current_zoom)
    var label: String="MIRA LIBRE" if not aim_active else "%s / %dX"%[
        WEAPONS.ENTRIES[weapon_index]["short"],int(current_zoom)]
    hud.set_aim(aim_active,label,current_zoom)


func _on_heal(syringe: bool=false) -> void:
    if _heal_remaining>0.0:
        # Press the same medkit button again to cancel without consuming it.
        _cancel_healing("CURACION CANCELADA")
        return
    if not operator.can_act():
        return
    if (syringes_remaining if syringe else medkits_remaining)<=0:
        hud.impact("SIN JERINGAS" if syringe else "SIN BOTIQUINES")
        return
    if operator.training_health>=99.5:
        hud.impact("SALUD COMPLETA")
        return
    if (trigger_held or reload_timer>0.0 or operator._sprint_touch or
            operator._move_axis.length_squared()>.01 or
            Vector2(operator.velocity.x,operator.velocity.z).length_squared()>.49):
        hud.impact("DETENTE PARA CURAR")
        return
    # Camera look remains free while stationary; movement, damage, fire,
    # zoom, reload and weapon change cancel an in-progress medical action.
    if aim_active:
        aim_active=false
        current_zoom=1.0
        operator.set_ads(false,1.0)
        hud.set_aim(false,"MIRA LIBRE",1.0)
    _healing_with_syringe=syringe
    _heal_duration=SYRINGE_APPLY_SECONDS if syringe else HEAL_APPLY_SECONDS
    _heal_remaining=_heal_duration
    _heal_anchor=operator.global_position
    _set_medical_presentation(true)
    hud.set_heal_channel(true,_heal_remaining,_heal_duration,medkits_remaining)
    hud.impact("APLICANDO JERINGA" if syringe else "APLICANDO BOTIQUIN / 3 SEGUNDOS")


func _on_healing_damage(amount: float) -> void:
    if amount>0.0:
        _cancel_healing("CURACION INTERRUMPIDA POR DANO")


func _cancel_healing(reason: String="") -> void:
    if _heal_remaining<=0.0:
        return
    _heal_remaining=0.0
    _set_medical_presentation(false)
    _healing_with_syringe=false
    hud.set_heal_channel(false,0.0,HEAL_APPLY_SECONDS,medkits_remaining)
    if not reason.is_empty():
        hud.impact(reason)


func _complete_healing() -> void:
    # A consumable is deducted exactly once, when the channel completes.
    var syringe: bool=_healing_with_syringe
    _healing_with_syringe=false
    _heal_remaining=0.0
    _set_medical_presentation(false)
    hud.set_heal_channel(false,0.0,HEAL_APPLY_SECONDS,medkits_remaining)
    if not operator.can_act() or operator.training_health>=99.5 or (
            (syringes_remaining if syringe else medkits_remaining)<=0):
        return
    if syringe:
        syringes_remaining-=1
    else:
        medkits_remaining-=1
    operator.receive_training_heal(20.0 if syringe else 45.0)
    _sync_hud()
    hud.set_medkit_count(medkits_remaining)
    hud.impact("JERINGA +20 VIDA" if syringe else "BOTIQUIN +45 VIDA")
    healed.emit()

func _on_reload() -> void:
    if not operator.can_act():
        return
    _cancel_healing("CURACION CANCELADA / RECARGA")
    if reload_timer>0:
        return
    var cap: int=WEAPONS.ENTRIES[weapon_index]["capacity"]
    if ammo[weapon_index]>=cap or reserve[WEAPONS.reserve_slot(weapon_index)]<=0:
        hud.impact("SIN NECESIDAD DE RECARGA")
        return
    # Swapping magazines supersedes any remaining sniper bolt sound.
    _cancel_awm_bolt()
    reload_timer=WEAPONS.ENTRIES[weapon_index]["reload"]
    _reload_duration=reload_timer
    _reload_ui_clock=0.0
    _mp40_reload_cue=0
    hud.set_reload_state(true,reload_timer,_reload_duration)
    operator.play_weapon_action("reload",reload_timer)
    reload_started.emit()
    hud.impact("RECARGANDO")


func _clear_reload() -> void:
    if _reload_duration<=0.0 and reload_timer<=0.0:
        return
    reload_timer=0.0
    _reload_duration=0.0
    _mp40_reload_cue=0
    if _weapon_visuals:
        _weapon_visuals.set_mp40_reload_progress(0.0)
    hud.set_reload_state(false,0.0,0.0)


func _advance_mp40_reload(progress: float) -> void:
    _weapon_visuals.set_mp40_reload_progress(progress)
    while _mp40_reload_cue<WEAPONS.MP40_RELOAD_MARKS.size() and (
            progress>=WEAPONS.MP40_RELOAD_MARKS[_mp40_reload_cue]):
        reload_cue.emit(WEAPONS.MP40_RELOAD_CUES[_mp40_reload_cue])
        _mp40_reload_cue+=1


## One cue for one consumed AWM round; release does not cancel the
## mechanical cycle, but a swap/reload/death or new match must cancel it.
## The actual shot cooldown is authoritative and unchanged.
func _advance_awm_bolt(delta: float) -> void:
    if not _awm_bolt_pending:
        return
    if weapon_index!=WEAPONS.AWM or reload_timer>0.0 or not operator.can_act():
        _cancel_awm_bolt()
        return
    _awm_bolt_remaining=maxf(0.0,_awm_bolt_remaining-maxf(0.0,delta))
    if _awm_bolt_remaining<=0.0:
        _awm_bolt_pending=false
        awm_bolt_cycled.emit()


func _cancel_awm_bolt() -> void:
    _awm_bolt_pending=false
    _awm_bolt_remaining=0.0


func _shoot() -> void:
    if not operator.can_act():
        return
    if operator.royale_eliminated or cooldown>0 or reload_timer>0:
        return
    if ammo[weapon_index]<=0:
        if reserve[WEAPONS.reserve_slot(weapon_index)]>0:
            _on_reload()
        else:
            trigger_held=false
            operator.set_firing(false)
            empty_magazine_attempts+=1
            hud.impact("SIN MUNICION / BUSCA BOTIN")
        return
    ammo[weapon_index]-=1
    shots_fired_total+=1
    cooldown=WEAPONS.ENTRIES[weapon_index]["cadence"]
    if weapon_index==WEAPONS.AWM:
        _awm_bolt_remaining=AWM_BOLT_CUE_SECONDS
        _awm_bolt_pending=true
    _sync_hud()
    operator.apply_recoil(WEAPONS.ENTRIES[weapon_index]["recoil"])
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
        # The same physical hit used for collision determines damage region.
        # Never infer a critical hit from crosshair projection alone.
        _apply_verified_opponent_hit(hit)
    elif body is StaticBody3D and body.is_in_group("aurora_deployable_cover"):
        body.call("take_damage",physical_hit_damage(weapon_index,false))
        hud.impact("BARRERA AURORA / IMPACTO")


## Safe classification for the actual 1.74m OpponentCollider. Must be
## called after a physical ray confirms this actor is the collider.
static func is_critical_contact(contact: Vector3,foot: Vector3) -> bool:
    if not contact.is_finite() or not foot.is_finite():
        return false
    var height: float=contact.y-foot.y
    return height>=HEADSHOT_START_HEIGHT and height<=HEADSHOT_TOP_HEIGHT


static func physical_hit_damage(weapon: int,is_critical: bool) -> float:
    if weapon<0 or weapon>=WEAPONS.ENTRIES.size():
        return 0.0
    var definition: Dictionary=WEAPONS.ENTRIES[weapon]
    return float(definition["damage"])*(float(definition["critical"]) if is_critical else 1.0)


## Only the dictionary returned by the PhysicsServer's actual ray enters
## this path in a match. Real damage and health loss still come from the
## CharacterBody3D; misses, walls and dead bots never produce headshots.
func _apply_verified_opponent_hit(hit: Dictionary) -> Dictionary:
    var opponent: CharacterBody3D=hit.get("collider") as CharacterBody3D
    if not is_instance_valid(opponent) or not opponent.is_in_group(
            "training_target") or opponent.health<=0.0:
        return {}
    var contact: Vector3=hit.get("position",Vector3(INF,INF,INF))
    if not contact.is_finite():
        return {}
    var critical: bool=is_critical_contact(contact,opponent.global_position)
    var before: float=float(opponent.health)
    var eliminated: bool=opponent.take_training_damage(
        physical_hit_damage(weapon_index,critical),operator)
    var caused: float=maxf(0.0,before-float(opponent.health))
    if caused<=0.0:
        return {}
    shots_hit_total+=1
    if critical:
        headshots_total+=1
    damage_dealt+=caused
    hud.show_confirmed_hit(caused,eliminated,critical)
    hud.impact("TIRO A LA CABEZA" if critical else
        "ENEMIGO NEUTRALIZADO" if eliminated else "IMPACTO CONFIRMADO")
    _sync_hud()
    return {"critical":critical,"damage":caused,"eliminated":eliminated}


func _clear_cover() -> void:
    for cover in _covers:
        if is_instance_valid(cover):
            cover.queue_free()
    _covers.clear()


func _on_cover_pressed() -> void:
    _cancel_healing("CURACION CANCELADA / BARRERA")
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


func throw_grenade() -> bool:
    if not sector_battle_active or not operator.can_act() or not operator.is_on_floor() or (
            grenades_remaining<=0 or _grenades.size()>=MAX_GRENADES):
        return false
    var camera: Camera3D=operator.get_view_camera()
    if camera==null:
        return false
    var aim: Vector3=-camera.global_basis.z
    var center: Vector3=operator.global_position+Vector3.UP*1.15
    var query:=PhysicsRayQueryParameters3D.create(center,center+aim*.55,1,[operator.get_rid()])
    if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
        hud.impact("LANZAMIENTO BLOQUEADO")
        return false
    _cancel_healing()
    _clear_reload()
    var grenade: Node3D=GRENADE.new()
    grenade.excluded=operator.get_rid()
    grenade.velocity=aim*13.0+Vector3.UP*4.7
    grenade.position=to_local(center+aim*.55)
    _grenades.append(grenade)
    grenade.detonated.connect(_on_grenade_detonated)
    grenade.tree_exited.connect(func(): _grenades.erase(grenade),CONNECT_ONE_SHOT)
    add_child(grenade)
    grenades_remaining-=1
    _sync_hud()
    return true


func _on_grenade_detonated(at: Vector3) -> void:
    if not sector_battle_active or not at.is_finite():
        return
    _flash_grenade(at)
    grenade_detonated.emit(at)
    for rival in _targets:
        if not is_instance_valid(rival) or rival.health<=0.0:
            continue
        var damage: float=_blast_damage_to(at,rival)
        if damage>0.0:
            var health_before: float=rival.health
            rival.take_training_damage(damage,operator)
            damage_dealt+=health_before-maxf(0.0,rival.health)
    var self_damage: float=_blast_damage_to(at,operator)
    if self_damage>0.0:
        operator.receive_training_hit(self_damage,false,at)


func _blast_damage_to(at: Vector3,target: CharacterBody3D) -> float:
    var center: Vector3=target.global_position+Vector3.UP*.85
    var distance: float=at.distance_to(center)
    if distance>=BLAST_RADIUS:
        return 0.0
    var query:=PhysicsRayQueryParameters3D.create(at,center,1,[target.get_rid()])
    if distance>.001 and not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
        return 0.0
    return lerpf(90.0,15.0,distance/BLAST_RADIUS)


func _flash_grenade(at: Vector3) -> void:
    var flash:=MeshInstance3D.new()
    var sphere:=SphereMesh.new()
    sphere.radial_segments=10
    sphere.rings=4
    flash.mesh=sphere
    flash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var light:=StandardMaterial3D.new()
    light.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    light.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    light.albedo_color=Color(1.0,.51,.17,.72)
    flash.material_override=light
    add_child(flash)
    flash.global_position=at
    var fade:=flash.create_tween().set_parallel()
    fade.tween_property(flash,"scale",Vector3.ONE*5.5,.24)
    fade.tween_property(light,"albedo_color:a",0.0,.24)
    fade.chain().tween_callback(flash.queue_free)


func _clear_grenades() -> void:
    for grenade in _grenades:
        if is_instance_valid(grenade):
            grenade.cancel()
    _grenades.clear()
    grenades_remaining=0


func end_sector_battle() -> void:
    _close_training_armory()
    _cancel_healing()
    _cancel_awm_bolt()
    _clear_reload()
    for i in range(_bot_tracers.size()):
        _bot_tracer_lifetimes[i]=0.0
        _bot_tracers[i].visible=false
    sector_battle_active=false
    _clear_cover()
    _clear_grenades()
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
    _close_training_armory()
    _cancel_healing()
    _cancel_awm_bolt()
    _clear_reload()
    _clear_cover()
    _clear_grenades()
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
    _reload_duration=0.0
    _reload_ui_clock=0.0
    hud.set_reload_state(false,0.0,0.0)
    shots_fired_total=0
    shots_hit_total=0
    headshots_total=0
    reloads_completed=0
    empty_magazine_attempts=0
    hud.clear_combat_events()
    ammo=[30,5]
    reserve=[90,12]
    weapon_owned=[true,false]
    backpack_level=0
    medkits_remaining=2
    syringes_remaining=0
    eliminations=0
    _eliminated_actors_this_round.clear()
    damage_dealt=0.0
    loot_collected=0
    opponent_caches_collected=0
    _ensure_encounter_capacity()
    _protect_player_landing_from_spawn_overlap()
    for bot in _targets:
        if is_instance_valid(bot):
            bot.configure_sector_battle(_targets)
    if _weapon_visuals:
        _weapon_visuals.clear_expansion()
        _weapon_visuals.set_awm_owned(weapon_owned[1])
        _weapon_visuals.equip(0)
    operator.set_equipped_weapon(0)
    hud.set_training_radar_sources(operator,_targets)
    hud.set_aim(false,"MIRA LIBRE",1.0)
    hud.set_medkit_count(medkits_remaining)
    hud.set_heal_channel(false,0.0,HEAL_APPLY_SECONDS,medkits_remaining)
    hud.set_eliminations(0)
    _sync_hud()


## Explicit offline-only difficulty selection. 50-person stress mode uses
## one real local player and 49 damageable, autonomous CharacterBody3D bots.
## It is an experimental Motorola load level, NOT online multiplayer.
func set_encounter_size(size: int) -> void:
    if size in ALLOWED_ENCOUNTERS:
        encounter_size=size


func _is_clear_spawn(at: Vector2) -> bool:
    if at.distance_to(Vector2(0,-24))>102.0:
        return false
    var sea: float=float(terrain.get("sea_level"))
    var floor_y: float=float(terrain.call("height_at",at.x,at.y))
    if floor_y<sea+1.0:
        return false
    if RESIDENTIAL.grading_weight(at.x,at.y)>.3:
        return false
    for old in [Vector2(18,-8),Vector2(-19,-29),
            Vector2(46,-36),Vector2(-48,22)]:
        if at.distance_to(old)<15.0:
            return false
    var left: float=float(terrain.call("height_at",at.x-1.5,at.y))
    var right: float=float(terrain.call("height_at",at.x+1.5,at.y))
    var front: float=float(terrain.call("height_at",at.x,at.y-1.5))
    var rear: float=float(terrain.call("height_at",at.x,at.y+1.5))
    return absf(left-right)<3.5 and absf(front-rear)<3.5


func _spawn_has_clearance(at: Vector2) -> bool:
    if not _is_clear_spawn(at):
        return false
    for rival in _targets:
        if is_instance_valid(rival) and at.distance_squared_to(
                rival.spawn_coordinates)<3.2*3.2:
            return false
    return true


func _encounter_spawn(index: int) -> Vector2:
    # Offline match: each physical combatant starts on distinct walkable
    # terrain. Low-discrepancy angular sampling covers inner/outer sectors
    # without piling 49 rivals around one fixed fallback coordinate.
    var base: float=float(index)*2.3999632297
    for attempt in range(128):
        var angle: float=base+float(attempt)*.61803398875
        var radius: float=22.0+float((index*17+attempt*11)%75)
        var at:=Vector2(sin(angle),cos(angle))*radius+Vector2(0,-24)
        if _spawn_has_clearance(at):
            return at
    # Search progressively around the full island if a ring intersects
    # houses, rocks or steep slopes; NEVER blindly stack at (33,-10).
    for attempt in range(400):
        var phase: float=base+float(attempt)*2.3999632297
        var radius: float=16.0+float((index*29+attempt*31)%81)
        var at:=Vector2(cos(phase),sin(phase))*radius+Vector2(0,-24)
        if _spawn_has_clearance(at):
            return at
    push_warning("Aurora cannot find distinct walkable opponent spawn "+str(index))
    # Emergency deterministic location for a malformed/empty terrain.
    # The real 50-opponent QA rejects this if it overlaps another fighter.
    return Vector2(33,-10)


## The 50 physical opponents exist before combat but must start on
## walkable land away from the player's real parachute landing. Only
## reposition rivals during round initialization, before they become
## combat-active, using the original terrain and collision constraints.
## Training and internal small-roster QA retain their historic placements.
func _protect_player_landing_from_spawn_overlap() -> void:
    if (encounter_size!=CLASSIC_BR_PARTICIPANTS or
            not is_instance_valid(operator) or
            not operator.global_position.is_finite()):
        return
    var landing: Vector2=Vector2(operator.global_position.x,
        operator.global_position.z)
    for i in range(_targets.size()):
        var bot: CharacterBody3D=_targets[i]
        if not is_instance_valid(bot) or bot.spawn_coordinates.distance_squared_to(
                landing)>=PLAYER_LANDING_CLEARANCE*PLAYER_LANDING_CLEARANCE:
            continue
        var at: Vector2=_find_clear_away_from_landing(i,landing)
        if not at.is_finite():
            push_error("Aurora no clear BR enemy position away from actual landing "+
                str(i))
            continue
        bot.set_match_spawn(at)


func _find_clear_away_from_landing(index: int,landing: Vector2) -> Vector2:
    var base_angle: float=float(index+53)*2.3999632297
    var origin: Vector2=Vector2(0.0,-24.0)
    for attempt in range(512):
        var angle: float=base_angle+float(attempt)*.61803398875
        var distance: float=21.0+float((index*17+attempt*29)%77)
        var at: Vector2=origin+Vector2.from_angle(angle)*distance
        if (at.distance_squared_to(landing)>=
                PLAYER_LANDING_CLEARANCE*PLAYER_LANDING_CLEARANCE and
                _spawn_has_clearance(at)):
            return at
    return Vector2(INF,INF)


func _ensure_encounter_capacity() -> void:
    var original: Array[Vector2]=[
        Vector2(-47,-10),Vector2(55,-17),Vector2(26,-55),
        Vector2(-35,-48)]
    var needed: int=clampi(encounter_size-1,8,49)
    while _targets.size()<needed:
        var i: int=_targets.size()
        var bot: CharacterBody3D=BOT.new()
        bot.name="AuroraPatrol"+str(i+1)
        bot.terrain=terrain
        bot.operator=operator
        bot.navigation=navigation
        # Nearby eight receive the original skinned character model.
        # Additional bots are real damageable physics agents with distance
        # LOD (the full rig is loaded when within 39m, unloaded beyond 55m).
        bot.set("distance_lod",i>=8)
        bot.spawn_coordinates=original[i-4] if i<8 else _encounter_spawn(i)
        bot.eliminated.connect(_on_bot_eliminated)
        bot.weapon_fired.connect(func(at: Vector3): bot_shot.emit(at))
        bot.foot_contact.connect(bot_foot_contact.emit)
        bot.weapon_fired.connect(_on_bot_weapon_fired.bind(bot))
        bot.shot_trace.connect(_on_bot_trace)
        if navigation:
            navigation.actors.append(bot)
        add_child(bot)
        _targets.append(bot)
    # Internal smaller QA fixtures must not keep agents from an earlier
    # 50-fighter round. This resizing is NOT exposed in the Battle Royale UI.
    while _targets.size()>needed:
        var last: CharacterBody3D=_targets.pop_back()
        if navigation:
            navigation.actors.erase(last)
        last.queue_free()


func active_fighter_count() -> int:
    var count: int=0 if operator.royale_eliminated else 1
    for bot in _targets:
        if is_instance_valid(bot) and bot.health>0:
            count+=1
    return count


func open_training_armory() -> void:
    if sector_battle_active or is_instance_valid(_training_armory):
        return
    _training_armory=TRAINING_ARMORY.new()
    _training_armory.name="AuroraTrainingArmory"
    _training_armory.player=operator
    _training_armory.combat=self
    _training_armory.terrain=terrain
    add_child(_training_armory)


func _close_training_armory() -> void:
    if is_instance_valid(_training_armory):
        _training_armory.close()
    _training_armory=null


func collect_sector_loot(kind: String,quantity: int=-1,
        from_opponent: bool=false) -> bool:
    if operator.royale_eliminated:
        return false
    if not sector_battle_active:
        if (not is_instance_valid(_training_armory) or from_opponent or
                not kind in TRAINING_ARMORY.ITEMS):
            return false
    match kind:
        "medkit":
            var gained: int=1 if quantity<0 else clampi(quantity,0,1)
            if medkits_remaining>=5 or gained<=0:
                return false
            medkits_remaining=mini(medkits_remaining+gained,5)
            hud.set_medkit_count(medkits_remaining)
            hud.impact("RIVAL / BOTIQUIN +1" if from_opponent else
                "BOTIQUIN RECOGIDO +1")
        "ammo_ar":
            var gained: int=45 if quantity<0 else clampi(quantity,0,18)
            gained=mini(gained,maxi(0,_reserve_limit(0)-reserve[0]))
            if gained<=0:
                return false
            reserve[0]+=gained
            hud.impact(("RIVAL / MUNICION AR +%d"%gained) if from_opponent
                else "MUNICION AR RECOGIDA")
        "ammo_awm":
            var gained: int=8 if quantity<0 else clampi(quantity,0,8)
            gained=mini(gained,maxi(0,_reserve_limit(1)-reserve[1]))
            if gained<=0:
                return false
            reserve[1]+=gained
            hud.impact(("RIVAL / MUNICION AWM +%d"%gained) if from_opponent
                else "MUNICION AWM RECOGIDA")
        "cover_charge":
            if cover_charges>=3:
                return false
            cover_charges+=1
            hud.set_aurora_cover_count(cover_charges,cover_cooldown)
            hud.impact("BARRERA AURORA +1")
        "syringe":
            if syringes_remaining>=3:
                return false
            syringes_remaining+=1
            hud.impact("JERINGA RECOGIDA")
        "grenade":
            if grenades_remaining>=MAX_GRENADES:
                return false
            grenades_remaining+=1
            hud.impact("GRANADA RECOGIDA")
        "armor_plate":
            if not operator.equip_armor(75.0):
                return false
            hud.impact("CHALECO AURORA EQUIPADO / +75")
        "vest_1", "vest_2", "vest_3", "helmet_1", "helmet_2", "helmet_3":
            var is_helmet: bool=kind.begins_with("helmet")
            var level: int=int(kind.get_slice("_",1))
            if not operator.equip_protection(is_helmet,level):
                return false
            hud.impact(("%s NIVEL %d EQUIPADO")%[
                "CASCO" if is_helmet else "CHALECO",level])
        "backpack":
            if backpack_level>=1:
                return false
            backpack_level=1
            hud.impact("MOCHILA EQUIPADA / MAYOR CAPACIDAD")
        "weapon_awm":
            if weapon_owned[1]:
                return false
            weapon_owned[1]=true
            if _weapon_visuals:
                _weapon_visuals.set_awm_owned(true)
            hud.impact("AWM RECOGIDA / VISIBLE EN ESPALDA")
        "weapon_scar", "weapon_mp40", "weapon_kriss", "weapon_hk416", "weapon_p90", "weapon_vss":
            if not _collect_expansion_weapon(WEAPONS.pickup_slot(kind)):
                return false
        "ammo_smg":
            if not _owns_smg():
                return false
            var gained: int=mini(30 if quantity<0 else clampi(quantity,0,30),
                _reserve_limit(WEAPONS.MP40)-reserve[WEAPONS.MP40])
            if gained<=0:
                return false
            reserve[WEAPONS.MP40]+=gained
            hud.impact("MUNICIÓN SMG +%d"%gained)
        _:
            return false
    loot_collected+=1
    if from_opponent:
        opponent_caches_collected+=1
    _sync_hud()
    return true


func _collect_expansion_weapon(slot: int) -> bool:
    if slot<WEAPONS.SCAR or slot>=WEAPONS.ENTRIES.size():
        return false
    if (slot<weapon_owned.size() and weapon_owned[slot]) or not _weapon_visuals.add_expansion(slot):
        return false
    var first_smg: bool=WEAPONS.reserve_slot(slot)==WEAPONS.MP40 and not _owns_smg()
    while weapon_owned.size()<=slot:
        weapon_owned.append(false)
        ammo.append(0)
        reserve.append(0)
    weapon_owned[slot]=true
    ammo[slot]=WEAPONS.ENTRIES[slot]["capacity"]
    if first_smg:
        reserve[WEAPONS.MP40]=30
    hud.impact("%s RECOGIDA"%WEAPONS.ENTRIES[slot]["short"])
    return true


func _owns_smg() -> bool:
    # Newly recovered SMGs share the same reserve but keep individual mags.
    for slot in range(WEAPONS.MP40,weapon_owned.size()):
        if weapon_owned[slot] and WEAPONS.reserve_slot(slot)==WEAPONS.MP40:
            return true
    return false


func _reserve_limit(index: int) -> int:
    if index==WEAPONS.MP40:
        return 180 if backpack_level>0 else 90
    return (AWM_RESERVE_BACKPACK if backpack_level>0 else AWM_RESERVE_BASE) if index==1 else (AR_RESERVE_BACKPACK if backpack_level>0 else AR_RESERVE_BASE)


func inventory_snapshot() -> Dictionary:
    var additions: Dictionary={}
    for index in range(WEAPONS.SCAR,weapon_owned.size()):
        if weapon_owned[index]:
            additions[index]={"loaded":ammo[index],"reserve":reserve[WEAPONS.reserve_slot(index)]}
    return {
        "additions":additions,
        "ar_owned":weapon_owned[0],
        "awm_owned":weapon_owned[1],
        "active_weapon":weapon_index,
        "ar_loaded":ammo[0],
        "awm_loaded":ammo[1],
        "ar_reserve":reserve[0],
        "awm_reserve":reserve[1],
        "ar_capacity":_reserve_limit(0),
        "awm_capacity":_reserve_limit(1),
        "medkits":medkits_remaining,
        "syringes":syringes_remaining,
        "grenades":grenades_remaining,
        "covers":cover_charges,
        "backpack":backpack_level,
        "armor":roundi(operator.armor_points),
        "vest_level":operator.vest_level,
        "helmet_level":operator.helmet_level,
        "helmet":roundi(operator.helmet_points),
        "damage_dealt":roundi(damage_dealt),
        "loot_collected":loot_collected,
        "opponent_caches":opponent_caches_collected,
        "shots_fired":shots_fired_total,
        "shots_hit":shots_hit_total,
        "headshots":headshots_total,
        "accuracy":shot_accuracy_percent(),
        "reloads":reloads_completed
    }


## Only actual damage to a living CharacterBody3D counts as a successful hit.
func shot_accuracy_percent() -> int:
    if shots_fired_total<=0:
        return 0
    return clampi(roundi(100.0*float(shots_hit_total)/
        float(shots_fired_total)),0,100)


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
    _bot_tracer_material=StandardMaterial3D.new()
    _bot_tracer_material.albedo_color=Color(.99,.31,.19)
    _bot_tracer_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    for i in range(BOT_TRACER_CAPACITY):
        var visual:=MeshInstance3D.new()
        visual.name="EnemyShotTracer"+str(i)
        visual.mesh=mesh
        visual.material_override=_bot_tracer_material
        visual.visible=false
        visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(visual)
        _bot_tracers.append(visual)
        _bot_tracer_lifetimes.append(0.0)


func _spawn_tracer(from: Vector3,to: Vector3) -> void:
    var span: Vector3=to-from
    if not span.is_finite() or span.length_squared()<=.0001:
        return
    var distance: float=minf(span.length(),TRACER_MAX_LENGTH)
    var visual: MeshInstance3D=_tracers[_tracer_cursor]
    var heading: Vector3=span.normalized()
    var radius: float=.024 if weapon_index==WEAPONS.AWM else .014
    visual.global_transform=Transform3D(Basis(Quaternion(Vector3.UP,heading)) * Basis.from_scale(Vector3(radius,distance,radius)),from+heading*distance*.5)
    visual.material_override=_tracer_materials[1 if weapon_index==WEAPONS.AWM else 0]
    visual.visible=true
    _tracer_lifetimes[_tracer_cursor]=TRACER_LIFETIME
    _tracer_cursor=(_tracer_cursor+1)%TRACER_CAPACITY
    tracer_events+=1


## Red tracer only for an actual bot PhysicsServer shot, never a predicted
## decorative muzzle flash or an imaginary online opponent.
func _on_bot_trace(from: Vector3,to: Vector3) -> void:
    var span: Vector3=to-from
    if (not span.is_finite() or span.length_squared()<=.0001 or
            _bot_tracers.is_empty()):
        return
    var distance: float=minf(span.length(),TRACER_MAX_LENGTH)
    var heading: Vector3=span.normalized()
    var visual: MeshInstance3D=_bot_tracers[_bot_tracer_cursor]
    visual.global_transform=Transform3D(
        Basis(Quaternion(Vector3.UP,heading))*
        Basis.from_scale(Vector3(.011,distance,.011)),
        from+heading*distance*.5)
    visual.visible=true
    _bot_tracer_lifetimes[_bot_tracer_cursor]=TRACER_LIFETIME
    _bot_tracer_cursor=(_bot_tracer_cursor+1)%BOT_TRACER_CAPACITY
    bot_tracer_events+=1


func _sync_hud() -> void:
    var supply: int=reserve[WEAPONS.reserve_slot(weapon_index)]
    var definition: Dictionary=WEAPONS.ENTRIES[weapon_index]
    hud.set_weapon(definition["label"],ammo[weapon_index],supply)
    hud.set_ammo_warning(ammo[weapon_index],supply,definition["capacity"])
    hud.set_armor_status(operator.armor_points,operator.vest_level,
        operator.helmet_points,operator.helmet_level)
    hud.set_inventory_snapshot(inventory_snapshot())


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
        bot.foot_contact.connect(bot_foot_contact.emit)
        bot.weapon_fired.connect(_on_bot_weapon_fired.bind(bot))
        bot.shot_trace.connect(_on_bot_trace)
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
    # Only one REAL CharacterBody3D death may count within an active BR
    # round. Training bots respawn; post-match damage/events must never
    # become player eliminations, wallet payments or phantom loot.
    if (not sector_battle_active or not is_instance_valid(_agent) or
            not _targets.has(_agent) or _agent.health>0.0):
        return
    var id: int=_agent.get_instance_id()
    if _eliminated_actors_this_round.has(id):
        return
    _eliminated_actors_this_round[id]=true
    var credited_to_player: bool=(killer==operator and
        not operator.royale_eliminated)
    bot_eliminated.emit(_agent,killer)
    var victim: String="RIVAL %02d"%maxi(1,_targets.find(_agent)+1)
    var event: String=""
    if credited_to_player:
        event="TU ELIMINASTE "+victim
    elif killer==null:
        event="ZONA ELIMINO "+victim
    elif is_instance_valid(killer) and _targets.has(killer):
        event=("RIVAL %02d"%maxi(1,_targets.find(killer)+1))+" ELIMINO "+victim
    else:
        event="RIVAL ELIMINADO · "+victim
    hud.push_combat_event(event)
    if credited_to_player:
        eliminations=mini(eliminations+1,_targets.size())
        hud.set_eliminations(eliminations)
        if operator.activate_tactical_acceleration():
            hud.impact("LILA / ACELERACION TACTICA")
        else:
            hud.impact("BAJA CONFIRMADA  /  "+str(eliminations))


func _draw_medical_rig() -> void:
    _medical_visual=MEDKIT_VISUAL.new()
    _medical_visual.name="LilaMedicalVisuals"
    add_child(_medical_visual)
    _medical_visual.attach_to_operator(operator)


func _set_medical_presentation(active: bool) -> void:
    if _medical_visual:
        _medical_visual.set_healing(active,_healing_with_syringe)
    if _weapon_visuals:
        _weapon_visuals.set_medical_busy(active)
    if active:
        # Authored upper-body action overlaps the actual physical medic
        # channel; cancellation never awards health or wastes inventory.
        operator.play_weapon_action("heal",_heal_duration)
    else:
        operator.cancel_medical_action()


func _draw_weapon_rig() -> void:
    # AK-74 and AWM each have a real imported GLB. Mount compensates for the
    # female FBX's centimeter-scale parent, then follows the skinned right hand.
    _weapon_visuals=WEAPON_VISUALS.new()
    _weapon_visuals.name="ActiveWeaponVisuals"
    add_child(_weapon_visuals)
    _weapon_visuals.attach_to_player(operator)
    _weapon_visuals.set_awm_owned(weapon_owned[1])
    _weapon_model=_weapon_visuals.ak
    operator.set_equipped_weapon(weapon_index)
    if _weapon_visuals.right_hand_socket==null:
        push_warning("Rigged right-hand attachment unavailable")


func _notification(what: int) -> void:
    if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
        _cancel_healing()
