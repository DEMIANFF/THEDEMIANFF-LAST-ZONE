extends VehicleBody3D
## Actual four-wheel Godot suspension and traction around user-submitted cars.
## Never substitute a cube/textured fake: this node is only spawned when
## the real source GLB is staged privately and imported successfully.
const SOURCE_FILES: Dictionary={
    "Toyota":"res://assets/vehicles/aurora_v3_private/AuroraToyotaOriginal.glb",
    "BMW":"res://assets/vehicles/aurora_v3_private/AuroraBMWOriginal.glb"
}
const TARGET_LENGTHS: Dictionary={"Toyota":5.0,"BMW":4.8}
const SAFE_ENTRY_RADIUS: float=3.35
const MAX_FORWARD_MPS: float=25.0
const MAX_REVERSE_MPS: float=7.0
const ENGINE_FORCE: float=1700.0
const STEER_MAX: float=.52
const WHEEL_RADIUS: float=.39
const WHEELBASE_HALF: float=1.43
const TRACK_HALF: float=.84
var variant: String="Toyota"
var driver: CharacterBody3D
var terrain: StaticBody3D
var _source_visual: Node3D
var _last_drive_axis: Vector2=Vector2.ZERO
var _speed_kmh: float=0.0
var _model_ready: bool=false


static func source_available(kind: String) -> bool:
    if not SOURCE_FILES.has(kind):
        return false
    return ResourceLoader.exists(str(SOURCE_FILES[kind]),"PackedScene")


func _ready() -> void:
    if not source_available(variant):
        push_error("The authentic Aurora vehicle model is not installed: "+variant)
        queue_free()
        return
    mass=1250.0 if variant=="Toyota" else 1450.0
    linear_damp=.24
    angular_damp=1.1
    center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
    center_of_mass=Vector3(0,-.42,0)
    collision_layer=1
    collision_mask=1
    name="AuroraDriveable"+variant
    _build_chassis()
    _build_wheels()
    _model_ready=_load_authentic_source()
    if not _model_ready:
        push_error("Aurora real vehicle source has no valid visual geometry: "+variant)
        queue_free()
        return
    # Parked physics are activated only when a player physically enters.
    freeze=true
    sleeping=true


func _build_chassis() -> void:
    var hull:=CollisionShape3D.new()
    hull.name="AuroraRigidChassisCollision"
    var body:=BoxShape3D.new()
    body.size=Vector3(2.10,1.15,4.45)
    hull.shape=body
    hull.position.y=-.06
    add_child(hull)


func _build_wheels() -> void:
    for front in [true,false]:
        for side in [-1.0,1.0]:
            var wheel:=VehicleWheel3D.new()
            wheel.name=("Front" if front else "Rear")+(
                "Right" if side>0 else "Left")+"Wheel"
            wheel.position=Vector3(side*TRACK_HALF,-.50,
                -WHEELBASE_HALF if front else WHEELBASE_HALF)
            wheel.wheel_radius=WHEEL_RADIUS
            wheel.wheel_rest_length=.35
            wheel.suspension_stiffness=25.0
            wheel.suspension_max_force=8000.0
            wheel.suspension_travel=.24
            wheel.damping_compression=.65
            wheel.damping_relaxation=.78
            wheel.wheel_friction_slip=3.4
            wheel.use_as_steering=front
            wheel.use_as_traction=not front
            add_child(wheel)


func _load_authentic_source() -> bool:
    var scene: PackedScene=load(str(SOURCE_FILES[variant])) as PackedScene
    if scene==null:
        return false
    var model: Node3D=scene.instantiate() as Node3D
    if model==null:
        return false
    model.name="Original"+variant+"UserModel"
    add_child(model)
    var low:=Vector3(INF,INF,INF)
    var high:=Vector3(-INF,-INF,-INF)
    var count: int=0
    for item in model.find_children("*","MeshInstance3D",true,false):
        var mesh: MeshInstance3D=item as MeshInstance3D
        if mesh.mesh==null:
            continue
        count+=1
        var bounds: AABB=mesh.get_aabb()
        for corner in range(8):
            var point: Vector3=model.to_local(
                mesh.to_global(bounds.get_endpoint(corner)))
            low=low.min(point)
            high=high.max(point)
        mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var size: Vector3=high-low
    if count<=0 or not size.is_finite() or size.z<.001:
        model.queue_free()
        return false
    # Measured source geometry: Toyota ~8.05m long, BMW ~23.67 source units.
    # Keep proper geometry and materials; normalize only model's visual parent.
    var scale_factor: float=clampf(
        float(TARGET_LENGTHS[variant])/maxf(size.x,size.z),.05,5.0)
    model.scale=Vector3.ONE*scale_factor
    model.position=-(low+size*.5)*scale_factor+Vector3(0,-.25,0)
    _source_visual=model
    print("AURORA_REAL_DRIVABLE source=",variant," meshes=",count,
        " normalized_length_m=",maxf(size.x,size.z)*scale_factor,
        " vehicle_wheels_physical=4")
    return true


func _physics_process(delta: float) -> void:
    if not _model_ready or freeze:
        return
    _speed_kmh=linear_velocity.length()*3.6
    if driver==null or not is_instance_valid(driver):
        engine_force=0.0
        steering=move_toward(steering,0.0,delta*1.5)
        brake=14.0
        return
    var axis: Vector2=driver._move_axis
    if axis.length()<.10:
        axis=Input.get_vector("move_left","move_right","move_forward","move_backward")
    _last_drive_axis=axis.limit_length(1.0)
    var forward: float=-_last_drive_axis.y
    var speed: float=linear_velocity.length()
    var steer_sensitivity: float=STEER_MAX/(1.0+speed*.065)
    steering=move_toward(steering,
        -_last_drive_axis.x*steer_sensitivity,delta*1.45)
    var longitudinal: float=linear_velocity.dot(-global_basis.z)
    if forward<-.15 and longitudinal>3.0:
        engine_force=0.0
        brake=32.0*absf(forward)
    elif forward>.15 and longitudinal< -2.0:
        engine_force=0.0
        brake=32.0*absf(forward)
    else:
        brake=12.0 if absf(forward)<.12 else 0.0
        if forward>.15 and longitudinal<MAX_FORWARD_MPS:
            engine_force=move_toward(engine_force,
                ENGINE_FORCE*forward,delta*3500.0)
        elif forward<-.15 and longitudinal> -MAX_REVERSE_MPS:
            engine_force=move_toward(engine_force,
                ENGINE_FORCE*forward*.43,delta*3500.0)
        else:
            engine_force=0.0


func speed_kmh() -> float:
    return _speed_kmh


func can_enter(player: CharacterBody3D) -> bool:
    return _model_ready and driver==null and player!=null and (
        player.global_position.distance_to(global_position)<=SAFE_ENTRY_RADIUS and
        linear_velocity.length()<2.0 and not player.royale_eliminated)


func enter(player: CharacterBody3D) -> bool:
    if not can_enter(player):
        return false
    driver=player
    freeze=false
    sleeping=false
    brake=0.0
    return true


func leave() -> void:
    driver=null
    engine_force=0.0
    brake=24.0


func exit_position(player: CharacterBody3D) -> Vector3:
    if player==null or terrain==null or not is_instance_valid(terrain):
        return Vector3(INF,INF,INF)
    var capsule:=CapsuleShape3D.new()
    capsule.radius=.34
    capsule.height=1.80
    for local in [Vector3(-2.20,0,0),Vector3(2.20,0,0),
                  Vector3(0,0,2.95)]:
        var world: Vector3=to_global(local)
        var ground_y: float=float(terrain.height_at(world.x,world.z))
        if not is_finite(ground_y) or absf(ground_y-global_position.y)>2.8:
            continue
        var proposed:=Vector3(world.x,ground_y+.15,world.z)
        var query:=PhysicsShapeQueryParameters3D.new()
        query.shape=capsule
        query.transform=Transform3D(Basis(),proposed+Vector3.UP*.90)
        query.exclude=[get_rid(),player.get_rid()]
        query.collision_mask=1
        if get_world_3d().direct_space_state.intersect_shape(query,4).is_empty():
            return proposed
    return Vector3(INF,INF,INF)
