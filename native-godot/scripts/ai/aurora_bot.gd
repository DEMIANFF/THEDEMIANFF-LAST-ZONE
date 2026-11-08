extends CharacterBody3D
## Aurora V73 offline training opponent: rigged glTF visual, bounded ray-LOS,
## grounded patrol and actual damage. This is not a networked human player.
signal eliminated(agent: CharacterBody3D)

const WALK_SPEED: float = 1.85
const CHASE_SPEED: float = 2.45
const SIGHT_RANGE: float = 31.0
const SHOOT_RANGE: float = 21.0
const GRAVITY: float = 17.5

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


func _ready() -> void:
    add_to_group("training_target")
    var marker := Label3D.new()
    marker.name = "TrainingTargetMarker"
    marker.text = "ENEMIGO IA"
    marker.font_size = 42
    marker.pixel_size = .006
    marker.position = Vector3(0, 2.25, 0)
    marker.modulate = Color(1.0, .52, .32)
    marker.no_depth_test = true
    add_child(marker)
    _anchor = Vector3(spawn_coordinates.x, terrain.height_at(spawn_coordinates.x,spawn_coordinates.y)+.15, spawn_coordinates.y)
    global_position = _anchor
    _idle_phase = float(get_instance_id()%41)*.31

    var shape := CollisionShape3D.new()
    shape.name = "OpponentCollider"
    var capsule := CapsuleShape3D.new()
    capsule.radius = .37
    capsule.height = 1.74
    shape.shape = capsule
    shape.position.y=.88
    add_child(shape)

    if ResourceLoader.exists("res://assets/characters/aurora_operator.glb"):
        var source := load("res://assets/characters/aurora_operator.glb") as PackedScene
        _rig = source.instantiate() as Node3D
        _rig.name="OpponentRig"
        add_child(_rig)
        # Same approved FBX coordinate-to-metre correction as player.
        if operator.has_method("fit_operator_visual"):
            operator.fit_operator_visual(_rig)
        _animation = _rig.find_child("AnimationPlayer",true,false) as AnimationPlayer
        if _animation:
            _animation.play("AuroraIdle")
            _animation.advance(.16)


func _physics_process(dt: float) -> void:
    if health<=0:
        _dead_time-=dt
        if _dead_time<=0:
            _respawn()
        return
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
    if _alert_time>0:
        var flank: Vector3=Vector3(-delta_to_player.z,0,delta_to_player.x).normalized()
        destination=_last_seen+flank*sin(_idle_phase)*2.2
        target_speed=CHASE_SPEED
    else:
        _idle_phase+=dt*.31
        destination=_anchor+Vector3(cos(_idle_phase)*4.0,0,sin(_idle_phase)*4.0)

    var direction: Vector3=destination-global_position
    direction.y=0
    if direction.length()>.75:
        var step: Vector3=direction.normalized()*target_speed
        velocity.x=move_toward(velocity.x,step.x,9.0*dt)
        velocity.z=move_toward(velocity.z,step.z,9.0*dt)
        rotation.y=lerp_angle(rotation.y,atan2(-direction.x,-direction.z),minf(1.0,dt*7.0))
    else:
        velocity.x=move_toward(velocity.x,0.0,8.0*dt)
        velocity.z=move_toward(velocity.z,0.0,8.0*dt)
    velocity.y-=GRAVITY*dt
    move_and_slide()

    if _target_visible and distance<SHOOT_RANGE and _attack_clock<=0:
        _attack_clock=1.0+float(get_instance_id()%4)*.18
        if _target_actor==operator:
            if not operator.royale_eliminated:
                operator.receive_training_hit(5.0)
        elif is_instance_valid(_target_actor) and _target_actor.health>0:
            _target_actor.take_training_damage(22.0)
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
            var source: Vector3=global_position+Vector3.UP*1.35
            var endpoint: Vector3=foe.global_position+Vector3.UP*1.14
            var ray:=PhysicsRayQueryParameters3D.create(source,endpoint)
            ray.exclude=[get_rid()]
            var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(ray)
            if hit.get("collider")==foe:
                closest=foe
                best=distance
    if closest != null:
        _target_visible=true
        _target_actor=closest


func configure_sector_battle(actors: Array[CharacterBody3D]) -> void:
    sector_battle=true
    respawn_enabled=false
    _foes=actors.duplicate()
    health=100.0
    visible=true
    set_physics_process(true)
    velocity=Vector3.ZERO
    global_position=_anchor
    _target_visible=false
    _target_actor=null
    _attack_clock=1.3
    _alert_time=0.0


func take_training_damage(damage: float) -> bool:
    if health<=0:
        return false
    health=maxf(0,health-damage)
    _last_seen=operator.global_position if _target_actor==null else _target_actor.global_position
    _alert_time=5.5
    if health<=0:
        _dead_time=7.0
        visible=false
        set_physics_process(false)
        if respawn_enabled:
            # Keep original training respawn; BR eliminates permanently.
            get_tree().create_timer(_dead_time).timeout.connect(_respawn)
        eliminated.emit(self)
        return true
    return false


func _respawn() -> void:
    if not respawn_enabled:
        return
    health=100
    global_position=_anchor
    visible=true
    velocity=Vector3.ZERO
    _alert_time=0
    _target_visible=false
    _dead_time=0
    set_physics_process(true)
