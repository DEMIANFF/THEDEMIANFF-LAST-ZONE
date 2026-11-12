extends CharacterBody3D
const STARTUP_DIAG=preload("res://scripts/persistence/scene_startup_diagnostics.gd")
## Aurora V73 offline training opponent: rigged glTF visual, bounded ray-LOS,
## grounded patrol and actual damage. This is not a networked human player.
signal eliminated(agent: CharacterBody3D, killer: Node3D)
signal weapon_fired(world_position: Vector3)

const WALK_SPEED: float = 1.85
const CHASE_SPEED: float = 2.45
const SIGHT_RANGE: float = 31.0
const SHOOT_RANGE: float = 21.0
const HEARING_RANGE: float = 42.0
const GRAVITY: float = 17.5

var navigation: Node3D
var behavior: String="patrol"
var shots_fired: int=0
var shots_hit: int=0
var heard_shots: int=0
var _random:=RandomNumberGenerator.new()
var _movement_probe:=KinematicCollision3D.new()
var _route:=PackedVector3Array()
var _route_goal:=Vector3(INF,INF,INF)
var _route_clock: float=0.0
var _cover_clock: float=0.0
var _suppression_seconds: float=0.0
var _last_attacker: Node3D
var _cover_point:=Vector3(INF,INF,INF)
var terrain: StaticBody3D
var operator: CharacterBody3D
var spawn_coordinates: Vector2 = Vector2.ZERO
var health: float = 100.0
var sector_battle: bool = false
var respawn_enabled: bool = true
var _foes: Array[CharacterBody3D] = []
var _target_actor: CharacterBody3D
var _anchor: Vector3
var _idle_phase: float = 0.0
var _sense_clock: float = 0.0
var _attack_clock: float = 1.3
var _target_visible: bool = false
var _last_seen: Vector3 = Vector3.ZERO
var _alert_time: float = 0.0
var _dead_time: float = 0.0
var _rig: Node3D
var _animation: AnimationPlayer
var _clip: String = ""
var safe_center: Vector2=Vector2.ZERO
var safe_radius: float=INF
var _avoid_side: float=1.0
## Mobile-only visual LOD. Agents remain real damageable CharacterBody3D
## enemies with their own AI and collisions at every distance.
var distance_lod: bool=false
var _lod_body: MeshInstance3D
var _lod_clock: float=0.0
var _lod_pending: bool=false


func _ready() -> void:
    add_to_group("training_target")
    _random.seed=7503+int(absf(spawn_coordinates.x)*31+absf(spawn_coordinates.y)*17)
    var marker := Label3D.new()
    marker.name = "TrainingTargetMarker"
    marker.text = "ENEMIGO IA"
    marker.font_size = 42
    marker.pixel_size = .006
    marker.position = Vector3(0, 2.25, 0)
    marker.modulate = Color(1.0, .52, .32)
    marker.no_depth_test = false
    add_child(marker)
    _anchor = Vector3(spawn_coordinates.x, terrain.height_at(spawn_coordinates.x,spawn_coordinates.y)+.15, spawn_coordinates.y)
    global_position = _anchor
    _idle_phase = float(get_instance_id()%41)*.31
    _avoid_side=1.0 if get_instance_id()%2==0 else -1.0

    var shape := CollisionShape3D.new()
    shape.name = "OpponentCollider"
    var capsule := CapsuleShape3D.new()
    capsule.radius = .37
    capsule.height = 1.74
    shape.shape = capsule
    shape.position.y=.88
    add_child(shape)

    if distance_lod:
        _create_lod_visual()
    else:
        _create_full_rig()


func _create_lod_visual() -> void:
    _lod_body=MeshInstance3D.new()
    _lod_body.name="DistantEnemyVisual"
    var shape:=CapsuleMesh.new()
    shape.radius=.33
    shape.height=1.68
    shape.radial_segments=8
    shape.rings=4
    _lod_body.mesh=shape
    _lod_body.position.y=.87
    var material:=StandardMaterial3D.new()
    material.albedo_color=Color(.10,.23,.34)
    material.roughness=.89
    _lod_body.material_override=material
    _lod_body.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_lod_body)


func _create_full_rig() -> void:
    if _rig!=null or STARTUP_DIAG.without_enemy_rigs():
        return
    if not ResourceLoader.exists("res://assets/characters/aurora_operator.glb"):
        return
    var source:=load("res://assets/characters/aurora_operator.glb") as PackedScene
    _rig=source.instantiate() as Node3D
    _rig.name="OpponentRig"
    add_child(_rig)
    if operator.has_method("fit_operator_visual"):
        operator.fit_operator_visual(_rig)
    _animation=_rig.find_child("AnimationPlayer",true,false) as AnimationPlayer
    if _animation:
        _animation.play("AuroraIdle")
        _animation.advance(.16)


func _set_full_visual(closer: bool) -> void:
    _lod_pending=false
    if not is_inside_tree():
        return
    if closer:
        _create_full_rig()
    elif _rig!=null:
        _rig.queue_free()
        _rig=null
        _animation=null
        _clip=""
    if _lod_body!=null:
        _lod_body.visible=_rig==null


func _update_distance_lod(dt: float) -> void:
    if not distance_lod or not sector_battle or not is_instance_valid(operator):
        return
    _lod_clock-=dt
    if _lod_clock>0.0:
        return
    _lod_clock=.55+float(get_instance_id()%7)*.045
    var distance_sq: float=global_position.distance_squared_to(operator.global_position)
    var wants_full: bool=distance_sq<39.0*39.0 if _rig==null else distance_sq<56.0*56.0
    if not _lod_pending and wants_full!=(_rig!=null):
        _lod_pending=true
        call_deferred("_set_full_visual",wants_full)


func _physics_process(dt: float) -> void:
    _update_distance_lod(dt)
    # Distant bots update in staggered frames to limit path and physics
    # cost. They are still active agents, may shoot each other and take
    # damage; no simulated eliminations or fictitious "players".
    if distance_lod and sector_battle and is_instance_valid(operator) and             global_position.distance_squared_to(operator.global_position)>75.0*75.0:
        if Engine.get_physics_frames()%3!=get_instance_id()%3:
            return
        dt=minf(dt*3.0,.125)
    if health<=0:
        _dead_time-=dt
        if _dead_time<=0:
            _respawn()
        return
    _route_clock-=dt
    _cover_clock-=dt
    _suppression_seconds=maxf(0.0,_suppression_seconds-dt)
    _sense_clock-=dt
    _attack_clock-=dt
    _alert_time=maxf(0.0,_alert_time-dt)
    if _sense_clock<=0:
        _sense_clock=.22+float(get_instance_id()%5)*.025
        _sense_player()

    var target: CharacterBody3D = _target_actor if _target_visible and is_instance_valid(_target_actor) else operator
    var delta_to_player: Vector3=target.global_position-global_position
    delta_to_player.y=0
    var distance: float=delta_to_player.length()
    var destination: Vector3
    var target_speed: float=WALK_SPEED
    if _target_visible and distance < SIGHT_RANGE:
        _last_seen=target.global_position
        _alert_time=2.9
    behavior="patrol"
    if _alert_time>0:
        behavior="pursuit"
        var flank: Vector3=Vector3(-delta_to_player.z,0,delta_to_player.x).normalized()
        destination=_last_seen+flank*sin(_idle_phase)*2.2
        target_speed=CHASE_SPEED
    else:
        _idle_phase+=dt*.31
        destination=_anchor+Vector3(cos(_idle_phase)*4.0,0,sin(_idle_phase)*4.0)

    if (health<=45.0 or (health<=70.0 and _suppression_seconds>0.0)) and _alert_time>0 and navigation and navigation.available:
        if _cover_clock<=0:
            _cover_point=navigation.find_cover(global_position,_last_seen)
            _cover_clock=4.0
        if _cover_point.is_finite() and _cover_clock>1.0:
            destination=_cover_point
            behavior="cover"
    if sector_battle and Vector2(global_position.x,global_position.z).distance_to(safe_center)>safe_radius-4.0:
        behavior="zone_escape"
        destination=Vector3(safe_center.x,global_position.y,safe_center.y)
        target_speed=CHASE_SPEED
    if navigation and navigation.available:
        if _route_clock<=0 and (destination.distance_squared_to(_route_goal)>6.25 or _route.is_empty()):
            _route=navigation.route(global_position,destination)
            _route_goal=destination
            _route_clock=.9+float(get_instance_id()%4)*.07
        while not _route.is_empty() and Vector2(_route[0].x-global_position.x,_route[0].z-global_position.z).length()<.65:
            _route.remove_at(0)
        if not _route.is_empty():
            destination=_route[0]
    var direction: Vector3=destination-global_position
    direction.y=0
    if direction.length()>.75:
        var heading: Vector3=direction.normalized()
        if _blocked_ahead(heading):
            for angle in [PI/3,PI/2,PI*2/3,PI]:
                var candidate: Vector3=heading.rotated(Vector3.UP,angle*_avoid_side)
                if not _blocked_ahead(candidate):
                    heading=candidate
                    break
        var step: Vector3=heading*target_speed
        velocity.x=move_toward(velocity.x,step.x,9.0*dt)
        velocity.z=move_toward(velocity.z,step.z,9.0*dt)
        rotation.y=lerp_angle(rotation.y,atan2(-heading.x,-heading.z),minf(1.0,dt*7.0))
    else:
        velocity.x=move_toward(velocity.x,0.0,8.0*dt)
        velocity.z=move_toward(velocity.z,0.0,8.0*dt)
    velocity.y-=GRAVITY*dt
    move_and_slide()

    if _target_visible and distance<SHOOT_RANGE and _attack_clock<=0 and _has_line_of_fire(_target_actor):
        _attack_clock=1.0+float(get_instance_id()%4)*.18
        _fire_at_target(_target_actor)
    if _animation:
        var action: String="AuroraWalk" if Vector2(velocity.x,velocity.z).length()>.8 else "AuroraIdle"
        if action!=_clip:
            _animation.play(action,.18)
            _clip=action


func _sense_player() -> void:
    _target_visible=false
    _target_actor=null
    var closest: CharacterBody3D=null
    var best: float=SIGHT_RANGE
    var choices: Array[CharacterBody3D]=[operator]
    if sector_battle:
        choices.append_array(_foes)
    for foe in choices:
        if foe==self or not is_instance_valid(foe):
            continue
        if foe==operator and operator.royale_eliminated:
            continue
        if foe!=operator and foe.health<=0:
            continue
        var distance: float=global_position.distance_to(foe.global_position)
        if distance < best:
            if _has_line_of_fire(foe):
                closest=foe
                best=distance
    if closest != null:
        _target_visible=true
        _target_actor=closest


## Perception of audible gunfire is not visual detection. Move toward the
## last noise source, then use ordinary LOS checks before shooting.
func hear_gunshot(at: Vector3, originator: Node3D) -> void:
    if not sector_battle or health<=0 or originator==self or not at.is_finite():
        return
    if global_position.distance_squared_to(at)>HEARING_RANGE*HEARING_RANGE:
        return
    if _target_visible and is_instance_valid(_target_actor):
        # An enemy already in sight takes priority over an unconfirmed sound.
        return
    _last_seen=at
    _alert_time=maxf(_alert_time,4.5)
    _sense_clock=minf(_sense_clock,.10)
    _route_clock=0.0
    _route.clear()
    _route_goal=Vector3(INF,INF,INF)
    heard_shots+=1


func configure_sector_battle(actors: Array[CharacterBody3D]) -> void:
    sector_battle=true
    respawn_enabled=false
    _foes=actors.duplicate()
    health=100.0
    visible=true
    var collider:=get_node_or_null("OpponentCollider") as CollisionShape3D
    if collider:
        collider.set_deferred("disabled",false)
    set_physics_process(true)
    velocity=Vector3.ZERO
    global_position=_anchor
    _target_visible=false
    _target_actor=null
    _attack_clock=1.3
    _alert_time=0.0
    _suppression_seconds=0.0
    _last_attacker=null
    heard_shots=0
    _last_seen=Vector3.ZERO
    _route.clear()
    _route_clock=0.0
    _route_goal=Vector3(INF,INF,INF)
    _cover_point=Vector3(INF,INF,INF)
    _cover_clock=0.0


func take_training_damage(damage: float,attacker: Node3D=null) -> bool:
    if health<=0:
        return false
    health=maxf(0,health-damage)
    if is_instance_valid(attacker):
        _last_attacker=attacker
        _last_seen=attacker.global_position
        _suppression_seconds=5.0
        # Enter cover planning at most once per incident; the existing
        # route budget still bounds PhysicsServer queries on Motorola.
        _cover_clock=0.0
    elif is_instance_valid(_target_actor):
        _last_seen=_target_actor.global_position
    _alert_time=5.5
    if health<=0:
        _dead_time=7.0
        visible=false
        var collider:=get_node_or_null("OpponentCollider") as CollisionShape3D
        if collider:
            collider.set_deferred("disabled",true)
        set_physics_process(false)
        if respawn_enabled:
            # Keep original training respawn; BR eliminates permanently.
            get_tree().create_timer(_dead_time).timeout.connect(_respawn)
        eliminated.emit(self,attacker)
        return true
    return false


func _respawn() -> void:
    if not respawn_enabled:
        return
    health=100
    global_position=_anchor
    visible=true
    var collider:=get_node_or_null("OpponentCollider") as CollisionShape3D
    if collider:
        collider.set_deferred("disabled",false)
    velocity=Vector3.ZERO
    _alert_time=0
    _suppression_seconds=0.0
    _last_attacker=null
    _target_visible=false
    _dead_time=0
    set_physics_process(true)

func _has_line_of_fire(foe: CharacterBody3D) -> bool:
    if not is_instance_valid(foe):
        return false
    var ray:=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*1.35,foe.global_position+Vector3.UP*1.0)
    ray.exclude=[get_rid()]
    var obstacle: Object=get_world_3d().direct_space_state.intersect_ray(ray).get("collider")
    # Bots may suppress and dismantle deployed cover instead of shooting
    # magically through it. Buildings and permanent terrain still block LOS.
    return obstacle==foe or (obstacle is StaticBody3D and
        (obstacle as StaticBody3D).is_in_group("aurora_deployable_cover"))


func _fire_at_target(foe: CharacterBody3D) -> void:
    if not is_instance_valid(foe):
        return
    shots_fired+=1
    weapon_fired.emit(global_position)
    var distance: float=global_position.distance_to(foe.global_position)
    var spread: float=clampf(distance/SHOOT_RANGE,0.0,1.0)*.52
    var sideways: Vector3=(foe.global_position-global_position).cross(Vector3.UP).normalized()
    var endpoint: Vector3=foe.global_position+Vector3.UP*(1.0+_random.randf_range(-spread*.6,spread*.6))+sideways*_random.randf_range(-spread,spread)
    var ray:=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*1.35,endpoint)
    ray.exclude=[get_rid()]
    var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
    var actor: Object=hit.get("collider")
    if actor==operator and not operator.royale_eliminated:
        operator.receive_training_hit(5.0)
        shots_hit+=1
    elif actor is CharacterBody3D and actor.is_in_group("training_target") and actor.health>0:
        actor.take_training_damage(22.0,self)
        shots_hit+=1
    elif actor is StaticBody3D and actor.is_in_group("aurora_deployable_cover"):
        actor.call("take_damage",12.0)


func _blocked_ahead(direction: Vector3) -> bool:
    var collision:=_movement_probe
    if not test_move(global_transform,direction,collision):
        return false
    # Sloped floor contact is expected. Treating it as a wall made avoidance
    # turn away from valid uphill paths on the island.
    for i in range(collision.get_collision_count()):
        if collision.get_normal(i).y<.65:
            return true
    return false
