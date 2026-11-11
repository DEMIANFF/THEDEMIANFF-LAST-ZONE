extends CharacterBody3D
## Native third-person camera and simultaneous touch controls.
## Production character visuals require a reviewed, rigged GLB; no cube placeholder.
const WALK_SPEED: float = 4.6
const RUN_SPEED: float = 7.1
const ACCELERATION: float = 16.0
const GRAVITY: float = 17.5
const LOOK_SENSITIVITY: float = 0.0032
const ANIMATION_CONTROLLER=preload("res://scripts/player/operator_animation.gd")
const CAMERA_PREFERENCES=preload("res://scripts/persistence/camera_preferences.gd")
const PLAYER_SETTINGS=preload("res://scripts/persistence/player_settings.gd")
const FLIGHT_DIAGNOSTICS=preload("res://scripts/match/flight_diagnostics.gd")
const TOUCH_DEADZONE: float = 0.12

signal training_health_changed(value: float)
signal player_eliminated
signal player_damaged(amount: float)
signal landed_from_airdrop
signal crouch_state_changed(active: bool)
signal footstep(on_stone: bool)
signal jumped
signal grounded_impact(on_stone: bool)
@export var approved_operator_scene: PackedScene
var training_health: float = 100.0
var battle_royale_active: bool = false
var royale_eliminated: bool = false
var round_finished: bool = false
var respawn_point: Vector3 = Vector3.ZERO
var training_knockouts: int = 0
var _training_immunity: float = 0.0
var _sprint_touch: bool = false
var _jump_requested: bool = false

var look_multiplier: float=1.0
var ads_multiplier: float=1.0
var _scope_sensitivity: Dictionary={}
var _camera_collision_shape:=SphereShape3D.new()
var _camera_collision_query:=PhysicsShapeQueryParameters3D.new()
var _yaw: float = 0.0
var _pitch: float = -0.14
# Additive recoil kick; does not overwrite user-selected aiming pitch.
var _recoil_pitch: float = 0.0
var _desired_yaw: float = 0.0
var _desired_pitch: float = -0.14
var _look_touch: int = -1
var _move_touch: int = -1
var _move_origin: Vector2 = Vector2.ZERO
var _move_axis: Vector2 = Vector2.ZERO
var _camera_pivot: Node3D
var _camera: Camera3D
var _avatar: Node3D
var _animation_controller: Node
var _landing_seconds: float=0.0
var _footstep_distance: float=0.0
var _ground_locomotion: String="Idle"
var _animator: AnimationPlayer
var _current_clip: String = ""
var _weapon_index: int=0
var _combat_action: String=""
var _combat_action_seconds: float=0.0
var air_mode: String="ground"
var _parachute_visual: Node3D
var _first_canopy_step_probe: bool=false
var _ads_active: bool = false
var _ads_zoom: float = 1.0
var _fire_held: bool = false
var _crouching: bool = false
var _normal_visual_scale: Vector3 = Vector3.ONE
var _normal_visual_y: float = 0.0


func _ready() -> void:
    _ensure_keyboard_actions()
    var preferences:=CAMERA_PREFERENCES.new()
    look_multiplier=preferences.look
    ads_multiplier=preferences.ads
    # New unified settings migrate the old camera file without deleting it.
    var options:=PLAYER_SETTINGS.new()
    look_multiplier=options.multiplier("general")
    ads_multiplier=options.multiplier("ads")
    _scope_sensitivity={
        "red_dot":options.multiplier("red_dot"),
        "scope_2x":options.multiplier("scope_2x"),
        "scope_4x":options.multiplier("scope_4x"),
        "scope_8x":options.multiplier("scope_8x")
    }
    _camera_collision_shape.radius=.20
    _camera_collision_query.shape=_camera_collision_shape
    _camera_collision_query.exclude=[get_rid()]
    _camera_collision_query.collision_mask=1

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
        if _animator:
            _animation_controller=ANIMATION_CONTROLLER.new()
            add_child(_animation_controller)
            _animation_controller.setup(_animator)
        _play_matching_animation("AuroraArmedIdle")
    else:
        push_warning("CC0 female operator GLB not yet generated. No cube character substituted.")
    # Build the actual canopy meshes and materials once during scene load,
    # *not* in the Android render/physics transition during freefall.
    _create_parachute()
    _parachute_visual.visible=false


func _physics_process(delta: float) -> void:
    if air_mode!="ground":
        _air_step(delta)
        return
    if royale_eliminated or round_finished:
        velocity=Vector3.ZERO
        return
    _training_immunity=maxf(0.0,_training_immunity-delta)
    var control := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    if _move_axis.length() > 0.0:
        control = _move_axis

    # Delta-time camera smoothing avoids abrupt yaw/pitch changes on quick swipes.
    var smooth: float = 1.0 - exp(-delta * 19.0)
    _yaw = rotate_toward(_yaw, _desired_yaw, minf(absf(angle_difference(_yaw,_desired_yaw))*smooth,delta*7.5))
    _recover_recoil(delta)
    _pitch = lerpf(_pitch, clampf(_desired_pitch + _recoil_pitch, -0.55, 0.62), smooth)
    _camera_pivot.rotation.x = _pitch
    var relative_direction := Vector3(control.x, 0.0, control.y)
    var facing := Basis(Vector3.UP, _yaw)
    var world_direction := (facing * relative_direction).limit_length(1.0)
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
        jumped.emit()
    else:
        velocity.y = 0.0

    # Camera yaw is independent of the player body while freely looking around.
    # On forward motion, the body faces movement; on ADS/fire it faces the reticle.
    var move_strength: float = world_direction.length_squared()
    if _ads_active or _fire_held:
        rotation.y = lerp_angle(rotation.y, _yaw, 1.0 - exp(-delta * 14.0))
    elif move_strength > 0.002:
        var move_yaw: float = atan2(-world_direction.x, -world_direction.z)
        rotation.y = lerp_angle(rotation.y, move_yaw, 1.0 - exp(-delta * 13.0))
    _camera_pivot.rotation.y = wrapf(_yaw - rotation.y, -PI, PI)
    _camera_pivot.rotation.x = _pitch
    var falling_speed: float=velocity.y
    var was_on_floor: bool=is_on_floor()
    var before_move: Vector3=global_position
    move_and_slide()
    var actual_speed: float=Vector2(global_position.x-before_move.x,global_position.z-before_move.z).length()/maxf(.001,delta)
    if is_on_floor() and actual_speed>1.2 and move_strength>.05:
        var stride: float=_step_stride(actual_speed,_crouching)
        if _footstep_distance<=0.0:
            # Do not wait a complete stride on the initial move input.
            _footstep_distance=stride*.60
        _footstep_distance+=actual_speed*delta
        if _footstep_distance>=stride:
            footstep.emit(_on_stone_footing())
            _footstep_distance=fmod(_footstep_distance,stride)
    else:
        _footstep_distance=0.0
    _landing_seconds=maxf(0.0,_landing_seconds-delta)
    if not was_on_floor and is_on_floor() and falling_speed< -2.0:
        _landing_seconds=.28
        if falling_speed< -4.5:
            grounded_impact.emit(_on_stone_footing())

    if _camera:
        var desired_fov: float = clampf(74.0 / _ads_zoom, 9.0, 74.0) if _ads_active else 74.0
        _camera.fov = lerpf(_camera.fov, desired_fov, 1.0 - exp(-delta * 11.0))
        var desired_distance: float = 1.15 if _ads_active and _ads_zoom >= 6.0 else 3.65 if _ads_active else 4.6
        var preferred_shoulder: float=.16 if _ads_active and _ads_zoom>=6.0 else .38
        # Probe the PREFERRED shoulder, not only the currently relocated
        # camera. Otherwise moving to a free centerline clears the probe and
        # immediately forces the camera into the wall again (oscillation).
        var preferred_clearance: float=_collision_safe_camera_distance(desired_distance,preferred_shoulder)
        var shoulder_target: float=preferred_shoulder
        if preferred_clearance<1.60 and desired_distance>1.60:
            var centered: float=_collision_safe_camera_distance(desired_distance,0.0)
            if centered>preferred_clearance+.32:
                shoulder_target=0.0
            else:
                var opposite: float=_collision_safe_camera_distance(desired_distance,-.22)
                if opposite>preferred_clearance+.64:
                    shoulder_target=-.22
        _camera.position.x=lerpf(_camera.position.x,shoulder_target,
            1.0-exp(-delta*11.0))
        var safe_distance: float=preferred_clearance
        if absf(_camera.position.x-preferred_shoulder)>.008:
            safe_distance=_collision_safe_camera_distance(desired_distance,_camera.position.x)
        # Contract immediately to stay outside collisions; expand with
        # controlled smoothing so opening a door never snaps the viewpoint.
        _camera.position.z=minf(safe_distance,
            lerpf(_camera.position.z,safe_distance,1.0-exp(-delta*15.0)))
        if _avatar:
            # Use the CAMERA'S ACTUAL position, not the future safe target:
            # otherwise the avatar can pop into view while still within 1 m.
            _avatar.visible=_camera.position.z>1.50 and not (_ads_active and _ads_zoom>=6.0)
    if _animator:
        _combat_action_seconds=maxf(0.0,_combat_action_seconds-delta)
        if _combat_action_seconds<=0.0:
            _combat_action=""
        var speed: float=Vector2(velocity.x,velocity.z).length()
        var locomotion: String=_select_locomotion(speed)
        var clip: String="AuroraArmed"+locomotion
        if _crouching:
            clip="AuroraCrouchWalk" if speed>=.75 else "AuroraCrouch"
        elif not is_on_floor():
            clip="AuroraJump"
        if _ads_active and not _crouching and speed<1.0:
            clip="AuroraAimAWM" if _weapon_index==1 else "AuroraAim"
        if _landing_seconds>0.0 and speed<1.0 and not _crouching:
            clip="AuroraLand"
        if clip!=_current_clip:
            _play_matching_animation(clip)


func _step_stride(speed: float,crouching: bool=false) -> float:
    # Actual horizontal distance between footfalls, not time intervals.
    # A slow crouch must never generate running cadence. This avoids
    # desynchronising sound when sprint stamina / joystick input changes.
    if crouching:
        return 1.02
    return lerpf(1.78,2.35,clampf((speed-WALK_SPEED)/
        (RUN_SPEED-WALK_SPEED),0.0,1.0))


func _on_stone_footing() -> bool:
    # Actual floor collider has priority for interiors and barricades;
    # paved streets are visual terrain overlays rather than physics solids.
    for index in range(get_slide_collision_count()):
        var collision: KinematicCollision3D=get_slide_collision(index)
        if collision.get_normal().y<=.6:
            continue
        var collider: Object=collision.get_collider()
        if collider is Node:
            var surface: String=(collider as Node).name.to_lower()
            if "floor" in surface or "deck" in surface or "ramp" in surface or \
                "foundation" in surface or "porch" in surface or "landing" in surface:
                return true
    var pos: Vector3=global_position
    return pos.x>=-28.0 and pos.x<=81.0 and pos.z>=6.0 and pos.z<=74.0


func _select_locomotion(speed: float) -> String:
    # Hysteresis eliminates repeated Walk/Run/Idle clip restarts around a
    # threshold when sliding, strafe-aiming or moving on sloped ground.
    # Weapon upper-body one-shots remain in their independent blend layer.
    if not is_finite(speed):
        return _ground_locomotion
    var v: float=maxf(0.0,speed)
    if _ground_locomotion=="Run":
        if v>=5.05:
            return "Run"
        _ground_locomotion="Walk" if v>=.65 else "Idle"
    elif _ground_locomotion=="Walk":
        if v>=5.85:
            _ground_locomotion="Run"
        elif v<.55:
            _ground_locomotion="Idle"
    else:
        if v>=5.85:
            _ground_locomotion="Run"
        elif v>=1.05:
            _ground_locomotion="Walk"
    return _ground_locomotion


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
    reset_controls()
    round_finished=false
    royale_eliminated=false
    _apply_crouch(false)
    air_mode="aircraft"
    velocity=Vector3.ZERO
    _ads_active=false
    _recoil_pitch=0.0
    _jump_requested=false
    _current_clip=""
    _fire_held=false
    _training_immunity=999.0
    if _avatar:
        _avatar.visible=false
    if _parachute_visual:
        _parachute_visual.visible=false


func begin_freefall(inherited_velocity: Vector3=Vector3.ZERO) -> void:
    if air_mode!="aircraft":
        return
    air_mode="freefall"
    velocity=Vector3(inherited_velocity.x,-4.0,inherited_velocity.z)
    _current_clip=""
    if _avatar:
        _avatar.visible=true


func deploy_parachute() -> void:
    if air_mode!="freefall":
        return
    air_mode="parachute"
    _first_canopy_step_probe=false
    # The meshes already exist from _ready(). Only their visibility changes
    # in the deferred pass; native resources are not allocated in mid-air.
    call_deferred("_commit_parachute_visual")
    _current_clip=""


func _commit_parachute_visual() -> void:
    if air_mode!="parachute" or not is_inside_tree():
        return
    FLIGHT_DIAGNOSTICS.checkpoint("active","parachute",self,"canopy_visual_before")
    if _parachute_visual:
        _parachute_visual.visible=true
    FLIGHT_DIAGNOSTICS.checkpoint("active","parachute",self,"canopy_visual_enabled")


func _air_step(delta: float) -> void:
    # The operator runs its own physics callback; it may run BEFORE the
    # deployment director's first_parachute_physics_tick checkpoint.
    var first_canopy_step: bool=air_mode=="parachute" and not _first_canopy_step_probe
    if first_canopy_step:
        _first_canopy_step_probe=true
        FLIGHT_DIAGNOSTICS.checkpoint("active","parachute",self,"operator_first_tick_enter")
    var alpha: float=1.0-exp(-delta*16.0)
    _yaw=rotate_toward(_yaw,_desired_yaw,minf(absf(angle_difference(_yaw,_desired_yaw))*alpha,delta*7.5))
    _pitch=lerpf(_pitch,_desired_pitch,alpha)
    _camera_pivot.rotation.y=wrapf(_yaw-rotation.y,-PI,PI)
    _camera_pivot.rotation.x=_pitch
    if _camera:
        var camera_distance: float=7.1 if air_mode=="aircraft" else 6.4
        # V75.18 isolation: do not query PhysicsServer cast_motion during
        # parachute either. The previous build re-enabled that query exactly
        # at canopy_deployed, the last checkpoint before the Android exit.
        # Ground mode still has full obstacle-aware camera collision.
        var safe_distance: float=camera_distance
        _camera.position.z=minf(safe_distance,lerpf(_camera.position.z,safe_distance,alpha))
        _camera.position.x=lerpf(_camera.position.x,.35,alpha)
        _camera.fov=lerpf(_camera.fov,76.0,alpha)
    if air_mode=="aircraft":
        velocity=Vector3.ZERO
        return

    var axis: Vector2=Input.get_vector("move_left","move_right","move_forward","move_backward")
    if _move_axis.length()>0.0:
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
    if first_canopy_step:
        FLIGHT_DIAGNOSTICS.checkpoint("active","parachute",self,"operator_before_move_and_slide")
    move_and_slide()
    if first_canopy_step:
        FLIGHT_DIAGNOSTICS.checkpoint("active","parachute",self,"operator_after_move_and_slide")
    _camera_pivot.rotation.y=wrapf(_yaw-rotation.y,-PI,PI)
    if _animator:
        var clip: String="AuroraFreefall" if air_mode=="freefall" else "AuroraParachute"
        if _current_clip!=clip:
            if first_canopy_step:
                FLIGHT_DIAGNOSTICS.checkpoint("active","parachute",self,"operator_before_canopy_animation")
            _play_matching_animation(clip)
            if first_canopy_step:
                FLIGHT_DIAGNOSTICS.checkpoint("active","parachute",self,"operator_after_canopy_animation")
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


func receive_training_hit(amount: float, environmental: bool=false) -> void:
    if amount<=0 or royale_eliminated or round_finished or (not environmental and _training_immunity>0):
        return
    training_health=maxf(0.0,training_health-amount)
    training_health_changed.emit(training_health)
    player_damaged.emit(amount)
    if _animation_controller and _combat_action_seconds<=.24:
        _animation_controller.action("AuroraHit",.22)
    if not environmental:
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


func end_sector_battle() -> void:
    round_finished=true
    velocity=Vector3.ZERO
    reset_controls()


func begin_sector_battle(from_airdrop: bool=false) -> void:
    reset_controls()
    round_finished=false
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
    if royale_eliminated or round_finished:
        return
    if amount<=0:
        return
    training_health=minf(100.0,training_health+amount)
    training_health_changed.emit(training_health)


func set_touch_move_axis(direction: Vector2) -> void:
    var strength: float=direction.length()
    _move_axis=Vector2.ZERO
    if direction.is_finite() and strength>TOUCH_DEADZONE and not round_finished and not royale_eliminated:
        _move_axis=direction.normalized()*clampf((strength-TOUCH_DEADZONE)/(1.0-TOUCH_DEADZONE),0.0,1.0)


func set_touch_run(active: bool) -> void:
    _sprint_touch=active and can_act()


func touch_jump() -> void:
    if can_act():
        _jump_requested=true


func set_ads(ads: bool, zoom: float) -> void:
    _ads_active = ads
    _ads_zoom = clampf(zoom, 1.0, 8.0)
    _current_clip=""


func set_equipped_weapon(index: int) -> void:
    _weapon_index=clampi(index,0,1)
    _current_clip=""
    _combat_action=""
    _combat_action_seconds=0.0
    if _animation_controller:
        _animation_controller.cancel_action()


func play_weapon_action(action: String, seconds: float) -> void:
    var requested: String=""
    match action:
        "fire":
            requested="AuroraFire"
        "reload":
            requested="AuroraReloadAWM" if _weapon_index==1 else "AuroraReloadAR"
        _:
            return
    _combat_action=requested
    _combat_action_seconds=maxf(0.05,seconds)
    if _animation_controller:
        _animation_controller.action(requested,seconds)


func set_firing(active: bool) -> void:
    _fire_held = active


func set_crouch(active: bool) -> void:
    if not can_act():
        return
    if _crouching==active:
        return
    if not active and not _can_stand():
        # Refuse to stretch collision into an overhead obstacle.
        crouch_state_changed.emit(true)
        return
    _apply_crouch(active)


func _apply_crouch(active: bool) -> void:
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


func _collision_safe_camera_distance(requested: float,shoulder_x: float=.38) -> float:
    if not is_inside_tree():
        return requested
    var shoulder: Vector3=Vector3(shoulder_x,_camera.position.y,0)
    var query:=_camera_collision_query
    query.transform=Transform3D(Basis(),_camera_pivot.to_global(shoulder))
    query.motion=_camera_pivot.global_basis.z*requested
    query.exclude=[get_rid()]
    query.collision_mask=1
    var space:=get_world_3d().direct_space_state
    if not space.intersect_shape(query,1).is_empty():
        return 0.0
    var fractions: PackedFloat32Array=space.cast_motion(query)
    return maxf(0.0,requested*fractions[0]-.05)


func apply_recoil(amount: float) -> void:
    # Positive X-pitch raises the sight. Preserve the manual aim, so long
    # bursts never drag the crosshair away indefinitely.
    if is_finite(amount) and amount>0.0:
        _recoil_pitch=minf(_recoil_pitch+amount,0.09)


func _recover_recoil(delta: float) -> void:
    _recoil_pitch=move_toward(_recoil_pitch,0.0,maxf(0.0,delta)*(0.22 if _ads_active else 0.32))


func _play_matching_animation(requested: String) -> void:
    if _animator == null:
        return
    if _animation_controller:
        _animation_controller.play(requested)
        _current_clip=requested
        return
    var animations: PackedStringArray = _animator.get_animation_list()
    if _current_clip == "":
        print("AURORA_AVAILABLE_ANIMATIONS ",animations)
    for name in animations:
        if name.to_lower()==requested.to_lower():
            var animation: Animation=_animator.get_animation(name)
            if name!="AuroraFire" and name!="AuroraJump" and name!="AuroraReloadAWM":
                animation.loop_mode=Animation.LOOP_LINEAR
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
    if royale_eliminated or round_finished:
        return
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        var viewport_width := get_viewport().get_visible_rect().size.x
        if touch.pressed and not touch.canceled:
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
    var hud:=get_parent().get_node_or_null("TrainingHUD")
    return hud!=null and hud.is_action_at(at)


func _touch_over_run_button(at: Vector2) -> bool:
    # The HUD's CORRER button lives on the left half of the screen. It must
    # not steal the unique movement pointer when held alongside the joystick.
    var v: Vector2=get_viewport().get_visible_rect().size
    var center:=Vector2(v.x*.11,v.y*.61)
    return absf(at.x-center.x)<=45.0 and absf(at.y-center.y)<=35.0


func _turn_camera(delta: Vector2, from_fire: bool=false) -> void:
    if not delta.is_finite():
        return
    var limited: Vector2 = delta
    # Precision slowdown in sights, but keep 360-degree continuous yaw.
    var zoom_factor: float = 1.0
    if _ads_active:
        zoom_factor = 0.22 if _ads_zoom >= 6.0 else 0.48 if _ads_zoom >= 4.0 else 0.70
    var drag_factor: float = 0.92 if from_fire else 1.0
    var scope_scale: float=1.0
    if _ads_active:
        var scope_key: String="scope_8x" if _ads_zoom>=6.0 else "scope_4x" if _ads_zoom>=3.8 else "scope_2x" if _ads_zoom>=1.5 else "red_dot"
        scope_scale=float(_scope_sensitivity.get(scope_key,1.0))
    var touch_scale: float=LOOK_SENSITIVITY*look_multiplier*(ads_multiplier if _ads_active else 1.0)*zoom_factor*drag_factor*scope_scale
    _desired_yaw -= limited.x * touch_scale
    _desired_pitch = clampf(_desired_pitch - limited.y * touch_scale, -0.55, 0.62)


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


func can_act() -> bool:
    return air_mode=="ground" and not royale_eliminated and not round_finished


func reset_controls() -> void:
    _move_axis=Vector2.ZERO
    _look_touch=-1
    _sprint_touch=false
    _jump_requested=false
    _fire_held=false
    _ads_active=false
    _recoil_pitch=0.0
    _combat_action=""
    _combat_action_seconds=0.0
    if _animation_controller:
        _animation_controller.cancel_action()


func _notification(what: int) -> void:
    if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
        reset_controls()
