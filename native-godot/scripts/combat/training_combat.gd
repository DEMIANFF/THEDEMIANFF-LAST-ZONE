extends Node3D
## Offline native weapons training only. Real rays, ammo counts and impact bodies.
const AR_DAMAGE: int=26
const AWM_DAMAGE: int=115
const AWM_BOLT_SECONDS: float=.50
const BOT = preload("res://scripts/ai/aurora_bot.gd")

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
var _weapon_model: Node3D
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
    if _weapon_model:
        _weapon_model.visible=weapon_index==0  # AK visual only until original AWM model is ready.
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
        var eliminated: bool=body.take_training_damage(float(AWM_DAMAGE if weapon_index==1 else AR_DAMAGE))
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
    if _weapon_model:
        _weapon_model.visible=true
    hud.set_training_radar_sources(operator,_targets)
    hud.set_aim(false,"MIRA LIBRE",1.0)
    hud.set_medkit_count(medkits_remaining)
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


func _on_bot_eliminated(_agent: CharacterBody3D) -> void:
    eliminations+=1
    hud.impact("BAJA CONFIRMADA  /  "+str(eliminations))


func _draw_weapon_rig() -> void:
    # Reuse an actual AK-74 glTF model already included in this user's repo,
    # rather than rendering the old three-cylinder proxy rifle.
    const PATH: String="res://assets/weapons/ak74-tactical.glb"
    if not ResourceLoader.exists(PATH):
        push_warning("AK-74 mesh not installed: suppress placeholder geometry")
        return
    var source:=load(PATH) as PackedScene
    if source == null:
        return
    _weapon_model=source.instantiate() as Node3D
    _weapon_model.name="AK74TacticalVisual"
    var mount:=Node3D.new()
    mount.name="ShoulderWeaponMount"
    var skeleton: Skeleton3D = null
    var rig := operator.get_node_or_null("AuroraFemaleRiggedOperator")
    if rig:
        skeleton = rig.find_child("Skeleton3D",true,false) as Skeleton3D
    var right_hand_bone: String=""
    if skeleton:
        for bone_id in range(skeleton.get_bone_count()):
            var bname: String=skeleton.get_bone_name(bone_id)
            if bname.to_lower().ends_with("righthand"):
                right_hand_bone=bname
                break
    if skeleton and right_hand_bone != "":
        var socket := BoneAttachment3D.new()
        socket.name="RightHandWeaponSocket"
        socket.bone_name=right_hand_bone
        skeleton.add_child(socket)
        socket.add_child(mount)
        mount.position=Vector3(0,-.11,-.18)
        mount.rotation=Vector3(-.12,0,PI*.5)
        print("AK74_ATTACHMENT_TO_HAND ",right_hand_bone)
    else:
        # No fake claim of hand-attachment when an imported asset lacks a hand.
        operator.add_child(mount)
        mount.position=Vector3(.37,1.22,-.34)
        push_warning("AK-74 could not attach to rig hand: temporary torso mount")
    mount.add_child(_weapon_model)

    var small: Vector3=Vector3(INF,INF,INF)
    var large: Vector3=Vector3(-INF,-INF,-INF)
    for candidate in _weapon_model.find_children("*","MeshInstance3D",true,false):
        var mesh:=candidate as MeshInstance3D
        var aabb: AABB=mesh.get_aabb()
        for i in range(8):
            var v: Vector3=_weapon_model.to_local(mesh.to_global(aabb.get_endpoint(i)))
            small=small.min(v)
            large=large.max(v)
    var size: Vector3=large-small
    var length: float=maxf(size.x,maxf(size.y,size.z))
    if not is_finite(length) or length<=.0001:
        push_warning("AK mesh has no usable bounds")
        _weapon_model.visible=false
        return
    var factor: float=clampf(1.06/length,.00001,100.0)
    var rot:=Vector3.ZERO
    if size.x>size.y and size.x>size.z:
        rot.y=PI*.5
    elif size.y>size.z:
        rot.x=-PI*.5
    else:
        rot.y=PI
    _weapon_model.rotation=rot
    _weapon_model.scale=Vector3.ONE*factor
    _weapon_model.position=-(_weapon_model.quaternion*(small+size*.5))*factor
    print("AURORA_REAL_AK74 fitted length=",length," scale=",factor," axis_extents=",size)
