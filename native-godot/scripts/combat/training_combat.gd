extends Node3D
## Offline native weapons training only. Real rays, ammo counts and impact bodies.
const AR_DAMAGE: int=26
const AWM_DAMAGE: int=115
const AWM_BOLT_SECONDS: float=.50
const BOT = preload("res://scripts/ai/aurora_bot.gd")
const WEAPON_VISUALS = preload("res://scripts/combat/weapon_visuals.gd")

var operator: CharacterBody3D
var hud: CanvasLayer
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
var tracer_events: int = 0


func _ready() -> void:
    hud.fire_pressed.connect(_on_fire_pressed)
    hud.fire_released.connect(_on_fire_released)
    hud.aim_pressed.connect(_on_aim)
    hud.reload_pressed.connect(_on_reload)
    hud.weapon_pressed.connect(_on_weapon)
    hud.fire_aim_changed.connect(operator.fire_aim_delta)
    hud.heal_pressed.connect(_on_heal)
    _make_targets()
    _draw_weapon_rig()
    _sync_hud()
    hud.set_medkit_count(medkits_remaining)


func _process(dt: float) -> void:
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
    if operator.royale_eliminated:
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


func _on_reload() -> void:
    if reload_timer>0:
        return
    var cap: int=5 if weapon_index==1 else 30
    if ammo[weapon_index]>=cap or reserve[weapon_index]<=0:
        hud.impact("SIN NECESIDAD DE RECARGA")
        return
    reload_timer=3.1 if weapon_index==1 else 1.55
    operator.play_weapon_action("reload",.65)
    hud.impact("RECARGANDO")


func _shoot() -> void:
    if operator.royale_eliminated or cooldown>0 or reload_timer>0:
        return
    if ammo[weapon_index]<=0:
        _on_reload()
        return
    ammo[weapon_index]-=1
    cooldown=AWM_BOLT_SECONDS if weapon_index==1 else .105
    _sync_hud()
    operator.apply_recoil(.02 if weapon_index==1 else .005)
    if weapon_index==1:
        operator.play_weapon_action("fire",.24)
    var camera:=operator.get_view_camera() as Camera3D
    if camera==null:
        return
    # Fire down the exact centre of the active camera so the rendered sight
    # and weapon ray have the same optical axis at every zoom level.
    var screen_center: Vector2 = camera.get_viewport().get_visible_rect().size*.5
    var from: Vector3=camera.project_ray_origin(screen_center)
    var direction: Vector3=camera.project_ray_normal(screen_center)
    var query:=PhysicsRayQueryParameters3D.create(from,from+direction*250)
    query.exclude=[operator.get_rid()]
    var hit: Dictionary=operator.get_world_3d().direct_space_state.intersect_ray(query)
    var endpoint: Vector3=hit.get("position",from+direction*37.0)
    _spawn_tracer(from,endpoint)
    if hit.is_empty():
        return
    var body=hit.get("collider")
    if body is CharacterBody3D and body.is_in_group("training_target"):
        var eliminated: bool=body.take_training_damage(float(AWM_DAMAGE if weapon_index==1 else AR_DAMAGE),operator)
        hud.impact("ENEMIGO NEUTRALIZADO" if eliminated else "IMPACTO CONFIRMADO")


func begin_sector_battle() -> void:
    sector_battle_active=true
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
        bot.spawn_coordinates=additional_spawns[i-4]
        bot.eliminated.connect(_on_bot_eliminated)
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
            medkits_remaining=mini(medkits_remaining+1,5)
            hud.set_medkit_count(medkits_remaining)
            hud.impact("BOTIQUIN RECOGIDO +1")
        "ammo_ar":
            reserve[0]+=45
            hud.impact("MUNICION AR +45")
        "ammo_awm":
            reserve[1]+=8
            hud.impact("MUNICION AWM +8")
        _:
            return false
    _sync_hud()
    return true


func _spawn_tracer(from: Vector3,to: Vector3) -> void:
    # A very short-lived hitscan indicator. The actual damage still comes
    # exclusively from the camera-aligned raycast, not this visible cylinder.
    var start: Vector3=operator.global_position+Vector3.UP*1.48
    var target: Vector3=to
    var distance: float=start.distance_to(target)
    if distance>.15:
        var visual:=MeshInstance3D.new()
        visual.name="BulletTracerV74"
        var projectile:=CylinderMesh.new()
        projectile.top_radius=.014 if weapon_index==0 else .024
        projectile.bottom_radius=projectile.top_radius
        projectile.height=minf(distance,90.0)
        projectile.radial_segments=6
        visual.mesh=projectile
        var material:=StandardMaterial3D.new()
        material.albedo_color=Color(.98,.83,.56) if weapon_index==0 else Color(.65,.82,.99)
        material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
        material.emission_enabled=true
        material.emission=material.albedo_color
        material.emission_energy_multiplier=1.3
        visual.material_override=material
        var heading: Vector3=(target-start).normalized()
        visual.position=start+heading*projectile.height*.5
        visual.quaternion=Quaternion(Vector3.UP,heading)
        visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(visual)
        tracer_events+=1
        get_tree().create_timer(.11).timeout.connect(func():
            if is_instance_valid(visual):
                visual.queue_free()
        )


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
        add_child(bot)
        _targets.append(bot)


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
