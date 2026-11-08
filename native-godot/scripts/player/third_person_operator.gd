extends CharacterBody3D
## Native third-person camera and simultaneous touch controls.
## Production character visuals require a reviewed, rigged GLB; no cube placeholder.
const WALK_SPEED: float = 4.6
const RUN_SPEED: float = 7.1
const ACCELERATION: float = 16.0
const GRAVITY: float = 17.5
const LOOK_SENSITIVITY: float = 0.0032
const TOUCH_DEADZONE: float = 0.12

@export var approved_operator_scene: PackedScene

var _yaw: float = 0.0
var _pitch: float = -0.14
var _look_touch: int = -1
var _move_touch: int = -1
var _move_origin: Vector2 = Vector2.ZERO
var _move_axis: Vector2 = Vector2.ZERO
var _camera_pivot: Node3D


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
    _camera_pivot.rotation.x = _pitch

    if approved_operator_scene != null:
        var visual := approved_operator_scene.instantiate()
        visual.name = "ProductionOperator"
        add_child(visual)
    else:
        push_warning("Production operator GLB not assigned. No block character substituted.")


func _physics_process(delta: float) -> void:
    var control := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    if _move_axis.length() > TOUCH_DEADZONE:
        control = _move_axis

    var relative_direction := Vector3(control.x, 0.0, control.y)
    var facing := Basis(Vector3.UP, _yaw)
    var world_direction := (facing * relative_direction).normalized()
    var run_fast := Input.is_action_pressed("run")
    var target_speed := RUN_SPEED if run_fast else WALK_SPEED
    var target_velocity := world_direction * target_speed

    velocity.x = move_toward(velocity.x, target_velocity.x, ACCELERATION * delta)
    velocity.z = move_toward(velocity.z, target_velocity.z, ACCELERATION * delta)
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    elif Input.is_action_just_pressed("jump"):
        velocity.y = 5.4
    else:
        velocity.y = 0.0

    rotation.y = lerp_angle(rotation.y, _yaw, minf(1.0, delta * 15.0))
    move_and_slide()


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
