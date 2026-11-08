extends CharacterBody3D
## Native third-person camera and simultaneous touch controls.
## Production character visuals require a reviewed, rigged GLB; no cube placeholder.
const WALK_SPEED: float = 4.6
const RUN_SPEED: float = 7.1
const ACCELERATION: float = 16.0
const GRAVITY: float = 17.5
const LOOK_SENSITIVITY: float = 0.0032
const TOUCH_DEADZONE: float = 0.12

signal training_health_changed(value: float)
@export var approved_operator_scene: PackedScene
var training_health: float = 100.0
var respawn_point: Vector3 = Vector3.ZERO
var training_knockouts: int = 0
var _training_immunity: float = 0.0
var _sprint_touch: bool = false
var _jump_requested: bool = false

var _yaw: float = 0.0
var _pitch: float = -0.14
var _look_touch: int = -1
var _move_touch: int = -1
var _move_origin: Vector2 = Vector2.ZERO
var _move_axis: Vector2 = Vector2.ZERO
var _camera_pivot: Node3D
var _camera: Camera3D
var _avatar: Node3D
var _animator: AnimationPlayer
var _current_clip: String = ""
var _ads_active: bool = false
var _ads_zoom: float = 1.0


func _ready() -> void:
    _ensure_keyboard_actions()

    var capsule := CollisionShape3D.new()
    capsule.name = "CapsuleCollider"
    var shape := CapsuleShape3D.new()
    shape.radius = 0.38
    shape.height = 1.82
    capsule.shape = shape
    capsule.position.y = 0.92
    add_child(capsule)

    _camera_pivot = Node3D.new()
    _camera_pivot.name = "CameraPivot"
    _camera_pivot.position.y = 1.55
    add_child(_camera_pivot)

    var camera := Camera3D.new()
    camera.name = "ThirdPersonCamera"
    camera.position = Vector3(0.4, 0.18, 4.6)
    camera.fov = 74.0
    camera.current = true
    _camera_pivot.add_child(camera)
    _camera = camera
    _camera_pivot.rotation.x = _pitch

    var operator_scene: PackedScene = approved_operator_scene
    if operator_scene == null and ResourceLoader.exists("res://assets/characters/aurora_operator.glb"):
        operator_scene = load("res://assets/characters/aurora_operator.glb") as PackedScene
    if operator_scene != null:
        _avatar = operator_scene.instantiate() as Node3D
        _avatar.name = "AuroraFemaleRiggedOperator"
        add_child(_avatar)
        fit_operator_visual(_avatar)
        _animator = _avatar.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
        if _animator == null:
            _animator = _avatar.find_child("AnimationPlayer", true, false) as AnimationPlayer
        _play_matching_animation("idle")
    else:
        push_warning("CC0 female operator GLB not yet generated. No cube character substituted.")


func _physics_process(delta: float) -> void:
    _training_immunity=maxf(0.0,_training_immunity-delta)
    var control := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    if _move_axis.length() > TOUCH_DEADZONE:
        control = _move_axis

    var relative_direction := Vector3(control.x, 0.0, control.y)
    var facing := Basis(Vector3.UP, _yaw)
    var world_direction := (facing * relative_direction).normalized()
    var run_fast := Input.is_action_pressed("run") or _sprint_touch
    var target_speed := RUN_SPEED if run_fast else WALK_SPEED
    var target_velocity := world_direction * target_speed

    velocity.x = move_toward(velocity.x, target_velocity.x, ACCELERATION * delta)
    velocity.z = move_toward(velocity.z, target_velocity.z, ACCELERATION * delta)
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    elif Input.is_action_just_pressed("jump") or _jump_requested:
        velocity.y = 5.4
        _jump_requested = false
    else:
        velocity.y = 0.0

    rotation.y = lerp_angle(rotation.y, _yaw, minf(1.0, delta * 15.0))
    move_and_slide()

    if _camera:
        var desired_fov: float = clampf(74.0 / _ads_zoom, 9.0, 74.0) if _ads_active else 74.0
        _camera.fov = lerpf(_camera.fov, desired_fov, 1.0 - exp(-delta * 11.0))
        var desired_distance: float = 2.15 if _ads_active else 4.6
        _camera.position.z = lerpf(_camera.position.z, desired_distance, 1.0 - exp(-delta * 9.0))
        _camera.position.x = lerpf(_camera.position.x, .26 if _ads_active else .4, 1.0 - exp(-delta * 9.0))
    if _animator:
        var speed: float = Vector2(velocity.x, velocity.z).length()
        var state: String = "run" if speed >= 5.5 else "walk" if speed >= 1.0 else "idle"
        if state != _current_clip:
            _play_matching_animation(state)


func fit_operator_visual(visual: Node3D) -> void:
    # Imported FBX rigs may measure in centimetres; bound actual transformed
    # mesh geometry and fit the visible body to the 1.82m native collider.
    var min_y: float = INF
    var max_y: float = -INF
    var min_x: float = INF
    var max_x: float = -INF
    var min_z: float = INF
    var max_z: float = -INF
    for child in visual.find_children("*", "MeshInstance3D", true, false):
        var part := child as MeshInstance3D
        var bounds: AABB = part.get_aabb()
        for endpoint in range(8):
            var vertex: Vector3 = visual.to_local(part.to_global(bounds.get_endpoint(endpoint)))
            min_y = minf(min_y,vertex.y)
            max_y = maxf(max_y,vertex.y)
            min_x = minf(min_x,vertex.x)
            max_x = maxf(max_x,vertex.x)
            min_z = minf(min_z,vertex.z)
            max_z = maxf(max_z,vertex.z)
    if not is_finite(min_y) or not is_finite(max_y) or max_y-min_y < .01:
        push_warning("Aurora model AABB unavailable")
        return
    # This CC0 FBX rig arrives on Z-up in Godot. Determine that from its
    # geometry extents, then rotate the *whole* skinned visual + animations.
    var original_y_height: float = max_y-min_y
    var original_z_length: float = max_z-min_z
    var z_up: bool = original_z_length > original_y_height*1.22
    var height: float = original_z_length if z_up else original_y_height
    var factor: float = clampf(1.76/height,.00001,100.0)
    visual.scale=Vector3.ONE*factor
    if z_up:
        visual.rotation.x = PI*.5
        visual.position.y = max_z*factor
    else:
        visual.position.y = -min_y*factor
    print("AURORA_MODEL_FIT y_range=",original_y_height," z_range=",original_z_length," width=",max_x-min_x," z_up=",z_up," scale=",factor)


func receive_training_hit(amount: float) -> void:
    if amount<=0 or _training_immunity>0:
        return
    training_health=maxf(0.0,training_health-amount)
    training_health_changed.emit(training_health)
    _training_immunity=.42
    if training_health<=0:
        training_knockouts+=1
        training_health=100.0
        _training_immunity=3.0
        velocity=Vector3.ZERO
        global_position=respawn_point
        training_health_changed.emit(training_health)


func set_touch_run(active: bool) -> void:
    _sprint_touch=active


func touch_jump() -> void:
    _jump_requested=true


func set_ads(ads: bool, zoom: float) -> void:
    _ads_active = ads
    _ads_zoom = clampf(zoom,1.0,8.0)


func apply_recoil(amount: float) -> void:
    _pitch = clampf(_pitch - amount,-0.68,0.75)
    _camera_pivot.rotation.x = _pitch


func _play_matching_animation(requested: String) -> void:
    if _animator == null:
        return
    var animations: PackedStringArray = _animator.get_animation_list()
    if _current_clip == "":
        print("AURORA_AVAILABLE_ANIMATIONS ",animations)
    for name in animations:
        if name.to_lower().contains(requested):
            _animator.play(name,0.16)
            if _current_clip == "":
                _animator.advance(.24)  # Bake initial pose before first camera frame.
            _current_clip=requested
            return
    if _current_clip == "":
        push_warning("No matching Aurora animation for "+requested+" in "+str(animations))


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        var viewport_width := get_viewport().get_visible_rect().size.x
        if touch.pressed:
            if touch.position.x >= viewport_width * 0.48 and _look_touch == -1:
                _look_touch = touch.index
            elif touch.position.x < viewport_width * 0.48 and _move_touch == -1:
                _move_touch = touch.index
                _move_origin = touch.position
        else:
            if touch.index == _look_touch:
                _look_touch = -1
            if touch.index == _move_touch:
                _move_touch = -1
                _move_axis = Vector2.ZERO
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == _look_touch:
            _turn_camera(drag.relative)
        elif drag.index == _move_touch:
            _move_axis = ((drag.position - _move_origin) / 75.0).limit_length(1.0)
    elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        _turn_camera((event as InputEventMouseMotion).relative)
    elif event is InputEventMouseButton:
        var mouse := event as InputEventMouseButton
        if mouse.button_index == MOUSE_BUTTON_RIGHT:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mouse.pressed else Input.MOUSE_MODE_VISIBLE


func _turn_camera(delta: Vector2) -> void:
    if not delta.is_finite():
        return
    var limited := delta.limit_length(64.0)
    _yaw -= limited.x * LOOK_SENSITIVITY
    _pitch = clampf(_pitch - limited.y * LOOK_SENSITIVITY, -0.68, 0.75)
    _camera_pivot.rotation.x = _pitch


func _ensure_keyboard_actions() -> void:
    var mapping := {
        "move_left": KEY_A,
        "move_right": KEY_D,
        "move_forward": KEY_W,
        "move_backward": KEY_S,
        "run": KEY_SHIFT,
        "jump": KEY_SPACE
    }
    for action in mapping.keys():
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        var key := InputEventKey.new()
        key.physical_keycode = mapping[action]
        if not InputMap.action_has_event(action, key):
            InputMap.action_add_event(action, key)
