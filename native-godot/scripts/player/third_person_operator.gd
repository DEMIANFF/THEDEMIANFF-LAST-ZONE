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
signal player_eliminated
signal player_damaged(amount: float)
signal landed_from_airdrop
signal crouch_state_changed(active: bool)
@export var approved_operator_scene: PackedScene
var training_health: float = 100.0
var battle_royale_active: bool = false
var royale_eliminated: bool = false
var respawn_point: Vector3 = Vector3.ZERO
var training_knockouts: int = 0
var _training_immunity: float = 0.0
var _sprint_touch: bool = false
var _jump_requested: bool = false

var _yaw: float = 0.0
var _pitch: float = -0.14
var _desired_yaw: float = 0.0
var _desired_pitch: float = -0.14
var _look_touch: int = -1
var _move_touch: int = -1
var _move_origin: Vector2 = Vector2.ZERO
var _move_axis: Vector2 = Vector2.ZERO
var _camera_pivot: Node3D
var _camera: Camera3D
var _avatar: Node3D
var _animator: AnimationPlayer
var _current_clip: String = ""
var _weapon_index: int=0
var _combat_action: String=""
var _combat_action_seconds: float=0.0
var air_mode: String="ground"
var _parachute_visual: Node3D
var _ads_active: bool = false
var _ads_zoom: float = 1.0
var _fire_held: bool = false
var _crouching: bool = false
var _normal_visual_scale: Vector3 = Vector3.ONE
var _normal_visual_y: float = 0.0


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
        _normal_visual_scale = _avatar.scale
        _normal_visual_y = _avatar.position.y
        _animator = _avatar.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
        if _animator == null:
            _animator = _avatar.find_child("AnimationPlayer", true, false) as AnimationPlayer
        _play_matching_animation("AuroraArmedIdle")
    else:
        push_warning("CC0 female operator GLB not yet generated. No cube character substituted.")


func _physics_process(delta: float) -> void:
    if air_mode!="ground":
        _air_step(delta)
        return
    if royale_eliminated:
        velocity=Vector3.ZERO
        return
    _training_immunity=maxf(0.0,_training_immunity-delta)
    var control := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    if _move_axis.length() > TOUCH_DEADZONE:
        control = _move_axis

    # Delta-time camera smoothing avoids abrupt yaw/pitch changes on quick swipes.
    var smooth: float = 1.0 - exp(-delta * 19.0)
    _yaw = lerp_angle(_yaw, _desired_yaw, smooth)
    _pitch = lerpf(_pitch, _desired_pitch, smooth)
    _camera_pivot.rotation.x = _pitch
    var relative_direction := Vector3(control.x, 0.0, control.y)
    var facing := Basis(Vector3.UP, _yaw)
    var world_direction := (facing * relative_direction).normalized()
    var run_fast := (Input.is_action_pressed("run") or _sprint_touch) and not _crouching
    var target_speed: float = WALK_SPEED
    if _crouching:
        target_speed = WALK_SPEED * .52
    elif run_fast:
        target_speed = RUN_SPEED
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

    # Camera yaw is independent of the player body while freely looking around.
    # On forward motion, the body faces movement; on ADS/fire it faces the reticle.
    var move_strength: float = world_direction.length_squared()
    if move_strength > 0.002:
        var move_yaw: float = atan2(-world_direction.x, -world_direction.z)
        rotation.y = lerp_angle(rotation.y, move_yaw, 1.0 - exp(-delta * 13.0))
    elif _ads_active or _fire_held:
        rotation.y = lerp_angle(rotation.y, _yaw, 1.0 - exp(-delta * 14.0))
    _camera_pivot.rotation.y = wrapf(_yaw - rotation.y, -PI, PI)
    _camera_pivot.rotation.x = _pitch
    move_and_slide()

    if _camera:
        var desired_fov: float = clampf(74.0 / _ads_zoom, 9.0, 74.0) if _ads_active else 74.0
        _camera.fov = lerpf(_camera.fov, desired_fov, 1.0 - exp(-delta * 11.0))
        var desired_distance: float = 1.15 if _ads_active and _ads_zoom >= 6.0 else 3.65 if _ads_active else 4.6
        var safe_distance: float = _collision_safe_camera_distance(desired_distance)
        _camera.position.z = lerpf(_camera.position.z, safe_distance, 1.0 - exp(-delta * 15.0))
        _camera.position.x = lerpf(_camera.position.x, .16 if _ads_active and _ads_zoom >= 6.0 else .38, 1.0 - exp(-delta * 11.0))
        if _avatar:
            _avatar.visible = not (_ads_active and _ads_zoom >= 6.0)
    if _animator:
        _combat_action_seconds=maxf(0.0,_combat_action_seconds-delta)
        if _combat_action_seconds<=0.0:
            _combat_action=""
        var speed: float=Vector2(velocity.x,velocity.z).length()
        var locomotion: String="Run" if speed>=5.5 else "Walk" if speed>=1.0 else "Idle"
        var clip: String="AuroraArmed"+locomotion
        if _crouching:
            clip="AuroraCrouchWalk" if speed>=.75 else "AuroraCrouch"
        elif not is_on_floor():
            clip="AuroraJump"
        if _ads_active:
            clip="AuroraAimAWM" if _weapon_index==1 else "AuroraAim"
        if _combat_action!="":
            clip=_combat_action
        if clip!=_current_clip:
            _play_matching_animation(clip)


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
    # Source CC0 rig faces the lens (+Z) after FBX conversion. Rotate to canonical
    # Godot combat forward (-Z) so the TPS camera shows the character's back.
    visual.rotation.y = wrapf(visual.rotation.y + PI, -PI, PI)
    print("AURORA_MODEL_FIT y_range=",original_y_height," z_range=",original_z_length," width=",max_x-min_x," z_up=",z_up," scale=",factor," tps_forward_adjusted=true")


func begin_aircraft() -> void:
    air_mode="aircraft"
    velocity=Vector3.ZERO
    _ads_active=false
    _jump_requested=false
    _current_clip=""
    _fire_held=false
    _training_immunity=999.0
    if _avatar:
        _avatar.visible=false
    if _parachute_visual:
        _parachute_visual.visible=false


func begin_freefall() -> void:
    if air_mode!="aircraft":
        return
    air_mode="freefall"
    velocity=Vector3(0,-4.0,0)
    _current_clip=""
    if _avatar:
        _avatar.visible=true


func deploy_parachute() -> void:
    if air_mode!="freefall":
        return
    air_mode="parachute"
    _create_parachute()
    _parachute_visual.visible=true
    _current_clip=""


func _air_step(delta: float) -> void:
    var alpha: float=1.0-exp(-delta*16.0)
    _yaw=lerp_angle(_yaw,_desired_yaw,alpha)
    _pitch=lerpf(_pitch,_desired_pitch,alpha)
    _camera_pivot.rotation.y=wrapf(_yaw-rotation.y,-PI,PI)
    _camera_pivot.rotation.x=_pitch
    if _camera:
        var camera_distance: float=7.1 if air_mode=="aircraft" else 6.4
        _camera.position.z=lerpf(_camera.position.z,camera_distance,alpha)
        _camera.position.x=lerpf(_camera.position.x,.35,alpha)
        _camera.fov=lerpf(_camera.fov,76.0,alpha)
    if air_mode=="aircraft":
        velocity=Vector3.ZERO
        return

    var axis: Vector2=Input.get_vector("move_left","move_right","move_forward","move_backward")
    if _move_axis.length()>TOUCH_DEADZONE:
        axis=_move_axis
    var steering: Vector3=Basis(Vector3.UP,_yaw)*Vector3(axis.x,0,axis.y)
    var speed: float=8.5 if air_mode=="freefall" else 5.7
    var target: Vector3=steering.limit_length(1.0)*speed
    velocity.x=move_toward(velocity.x,target.x,delta*10.0)
    velocity.z=move_toward(velocity.z,target.z,delta*10.0)
    if air_mode=="freefall":
        velocity.y=maxf(-26.0,velocity.y-GRAVITY*1.20*delta)
    else:
        velocity.y=move_toward(velocity.y,-5.6,delta*35.0)
    if steering.length_squared()>.02:
        rotation.y=lerp_angle(rotation.y,atan2(-steering.x,-steering.z),alpha)
    move_and_slide()
    if _animator:
        var clip: String="AuroraFreefall" if air_mode=="freefall" else "AuroraParachute"
        if _current_clip!=clip:
            _play_matching_animation(clip)
    if is_on_floor():
        air_mode="ground"
        velocity=Vector3.ZERO
        if _parachute_visual:
            _parachute_visual.visible=false
        _current_clip=""
        landed_from_airdrop.emit()


func _create_parachute() -> void:
    if _parachute_visual!=null:
        return
    _parachute_visual=Node3D.new()
    _parachute_visual.name="AuroraParachute"
    add_child(_parachute_visual)
    var canopy:=MeshInstance3D.new()
    canopy.name="ParachuteCanopy"
    var canopy_mesh:=CylinderMesh.new()
    canopy_mesh.top_radius=.20
    canopy_mesh.bottom_radius=2.25
    canopy_mesh.height=.65
    canopy_mesh.radial_segments=20
    canopy.mesh=canopy_mesh
    canopy.position.y=4.9
    var material:=StandardMaterial3D.new()
    material.albedo_color=Color(.24,.65,.84)
    material.roughness=.72
    canopy.material_override=material
    _parachute_visual.add_child(canopy)
    for angle in [0.0,PI*.5,PI,PI*1.5]:
        var endpoint:=Vector3(cos(angle)*1.85,4.55,sin(angle)*1.85)
        var start:=Vector3(cos(angle)*.18,1.5,sin(angle)*.18)
        var diff:=endpoint-start
        var cord:=MeshInstance3D.new()
        cord.name="SuspensionLine"
        var cord_mesh:=CylinderMesh.new()
        cord_mesh.top_radius=.012
        cord_mesh.bottom_radius=.012
        cord_mesh.height=diff.length()
        cord.mesh=cord_mesh
        cord.position=(start+endpoint)*.5
        cord.quaternion=Quaternion(Vector3.UP,diff.normalized())
        _parachute_visual.add_child(cord)


func receive_training_hit(amount: float) -> void:
    if amount<=0 or _training_immunity>0:
        return
    training_health=maxf(0.0,training_health-amount)
    training_health_changed.emit(training_health)
    player_damaged.emit(amount)
    _training_immunity=.42
    if training_health<=0:
        if battle_royale_active:
            royale_eliminated=true
            velocity=Vector3.ZERO
            set_firing(false)
            player_eliminated.emit()
            return
        training_knockouts+=1
        training_health=100.0
        _training_immunity=3.0
        velocity=Vector3.ZERO
        global_position=respawn_point
        training_health_changed.emit(training_health)


func begin_sector_battle(from_airdrop: bool=false) -> void:
    battle_royale_active = true
    royale_eliminated = false
    training_health = 100.0
    velocity=Vector3.ZERO
    if from_airdrop:
        respawn_point=global_position
    else:
        global_position=respawn_point
    _training_immunity=2.0
    set_firing(false)
    set_touch_move_axis(Vector2.ZERO)
    training_health_changed.emit(training_health)


func receive_training_heal(amount: float) -> void:
    if royale_eliminated:
        return
    if amount<=0:
        return
    training_health=minf(100.0,training_health+amount)
    training_health_changed.emit(training_health)


func set_touch_move_axis(direction: Vector2) -> void:
    _move_axis=direction.limit_length(1.0)


func set_touch_run(active: bool) -> void:
    _sprint_touch=active


func touch_jump() -> void:
    if air_mode=="ground":
        _jump_requested=true


func set_ads(ads: bool, zoom: float) -> void:
    _ads_active = ads
    _ads_zoom = clampf(zoom, 1.0, 8.0)
    _current_clip=""


func set_equipped_weapon(index: int) -> void:
    _weapon_index=clampi(index,0,1)
    _current_clip=""


func play_weapon_action(action: String, seconds: float) -> void:
    var requested: String=""
    match action:
        "fire":
            requested="AuroraFire"
        "reload":
            requested="AuroraReloadAWM" if _weapon_index==1 else "AuroraArmedIdle"
        _:
            return
    _combat_action=requested
    _combat_action_seconds=maxf(0.05,seconds)
    _play_matching_animation(requested)


func set_firing(active: bool) -> void:
    _fire_held = active


func set_crouch(active: bool) -> void:
    if _crouching==active:
        return
    if not active and not _can_stand():
        # Refuse to stretch collision into an overhead obstacle.
        crouch_state_changed.emit(true)
        return
    _crouching=active
    var collider:=get_node_or_null("CapsuleCollider") as CollisionShape3D
    if collider:
        var capsule:=collider.shape as CapsuleShape3D
        if capsule:
            capsule.height=1.22 if active else 1.82
        collider.position.y=.62 if active else .92
    _camera_pivot.position.y=1.13 if active else 1.55
    if _avatar:
        # Mesh must never be artificially squashed to mimic crouching.
        # Properly authored AuroraCrouch/AuroraCrouchWalk clips move joints.
        _avatar.scale=_normal_visual_scale
        _avatar.position.y=_normal_visual_y
    _current_clip=""
    crouch_state_changed.emit(_crouching)


func _can_stand() -> bool:
    if not is_inside_tree():
        return true
    var shape:=CapsuleShape3D.new()
    shape.radius=.38
    shape.height=1.82
    var query:=PhysicsShapeQueryParameters3D.new()
    query.shape=shape
    query.transform=Transform3D(Basis(),global_position+Vector3.UP*.92)
    query.collision_mask=collision_mask
    query.exclude=[get_rid()]
    var contacts: Array[Dictionary]=get_world_3d().direct_space_state.intersect_shape(query,2)
    return contacts.is_empty()


func fire_aim_delta(delta: Vector2) -> void:
    _turn_camera(delta, true)


func get_view_camera() -> Camera3D:
    return _camera


func _collision_safe_camera_distance(requested: float) -> float:
    if not is_inside_tree():
        return requested
    var eye: Vector3 = _camera_pivot.global_position
    var offset: Vector3 = Vector3(.38, .18, requested)
    var desired: Vector3 = _camera_pivot.to_global(offset)
    var ray := PhysicsRayQueryParameters3D.create(eye, desired)
    ray.exclude = [get_rid()]
    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
    if hit.is_empty():
        return requested
    var length: float = eye.distance_to(desired)
    var hit_distance: float = eye.distance_to(hit.position)
    return clampf(requested * hit_distance / maxf(.01, length) - .23, .55, requested)


func apply_recoil(amount: float) -> void:
    _desired_pitch = clampf(_desired_pitch - amount, -0.55, 0.62)


func _play_matching_animation(requested: String) -> void:
    if _animator == null:
        return
    var animations: PackedStringArray = _animator.get_animation_list()
    if _current_clip == "":
        print("AURORA_AVAILABLE_ANIMATIONS ",animations)
    for name in animations:
        if name.to_lower()==requested.to_lower():
            _animator.play(name,.14)
            if _current_clip=="":
                _animator.advance(.15)
            _current_clip=name
            return
    if requested.to_lower().begins_with("auroraarmed"):
        var fallback: String=requested.replace("Armed","")
        for name in animations:
            if name.to_lower()==fallback.to_lower():
                _animator.play(name,.14)
                _current_clip=requested
                return
    if _current_clip=="":
        push_warning("Missing required authored clip "+requested+" in "+str(animations))
    if _current_clip == "":
        push_warning("No matching Aurora animation for "+requested+" in "+str(animations))


## Touch input must be captured BEFORE GUI dispatch: buttons and overlays may
## consume ScreenDrag so _unhandled_input never sees joystick movement.
func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        var viewport_width := get_viewport().get_visible_rect().size.x
        if touch.pressed:
            if touch.position.x >= viewport_width * 0.48 and _look_touch == -1 and not _touch_over_action_buttons(touch.position):
                _look_touch = touch.index
            # Left-side touch is owned by MovePad._gui_input.
        else:
            if touch.index == _look_touch:
                _look_touch = -1
            # Movement release comes from GUI joystick signal.
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == _look_touch:
            _turn_camera(drag.relative)
        # Left-side drag is captured by the independent GUI joystick.
    elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        _turn_camera((event as InputEventMouseMotion).relative)
    elif event is InputEventMouseButton:
        var mouse := event as InputEventMouseButton
        if mouse.button_index == MOUSE_BUTTON_RIGHT:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mouse.pressed else Input.MOUSE_MODE_VISIBLE


func _touch_over_action_buttons(at: Vector2) -> bool:
    # A fire/reload/jump/ADS press must not also become a camera-look finger.
    var area: Vector2=get_viewport().get_visible_rect().size
    var positions := [
        Vector4(.905,.70,182.0,172.0),
        Vector4(.778,.66,74.0,62.0),
        Vector4(.790,.80,81.0,59.0),
        Vector4(.905,.87,79.0,59.0),
        Vector4(.685,.82,76.0,54.0)]
    for b in positions:
        var x: float=area.x*b.x
        var y: float=area.y*b.y
        if absf(at.x-x)<=b.z*.58 and absf(at.y-y)<=b.w*.58:
            return true
    return false


func _touch_over_run_button(at: Vector2) -> bool:
    # The HUD's CORRER button lives on the left half of the screen. It must
    # not steal the unique movement pointer when held alongside the joystick.
    var v: Vector2=get_viewport().get_visible_rect().size
    var center:=Vector2(v.x*.11,v.y*.61)
    return absf(at.x-center.x)<=45.0 and absf(at.y-center.y)<=35.0


func _turn_camera(delta: Vector2, from_fire: bool=false) -> void:
    if not delta.is_finite():
        return
    var limited: Vector2 = delta.limit_length(74.0)
    # Precision slowdown in sights, but keep 360-degree continuous yaw.
    var zoom_factor: float = 1.0
    if _ads_active:
        zoom_factor = 0.22 if _ads_zoom >= 6.0 else 0.48 if _ads_zoom >= 4.0 else 0.70
    var drag_factor: float = 0.92 if from_fire else 1.0
    _desired_yaw -= limited.x * LOOK_SENSITIVITY * zoom_factor * drag_factor
    _desired_pitch = clampf(_desired_pitch - limited.y * LOOK_SENSITIVITY * zoom_factor * drag_factor, -0.55, 0.62)


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
