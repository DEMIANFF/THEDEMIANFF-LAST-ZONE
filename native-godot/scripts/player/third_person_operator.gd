extends CharacterBody3D
## Native third-person camera and simultaneous touch controls.
## Production character visuals require a reviewed, rigged GLB; no cube placeholder.
const WALK_SPEED: float = 4.6
const RUN_SPEED: float = 7.1
const ACCELERATION: float = 16.0
const GRAVITY: float = 17.5
const LOOK_SENSITIVITY: float = 0.0032
const ANIMATION_CONTROLLER=preload("res://scripts/player/operator_animation.gd")
const BODY_CONTACT=preload("res://scripts/player/operator_body_contact.gd")
const GROUND_CONTACT=preload("res://scripts/player/aurora_operator_contact_shadow.gd")
const BACKPACK_VISUAL=preload("res://scripts/player/aurora_backpack_visual.gd")
const LOCAL_PLAYER_RECORDS=preload("res://scripts/persistence/offline_match_records.gd")
const COSMETICS=preload("res://scripts/player/aurora_operator_cosmetics.gd")
const CAMERA_PREFERENCES=preload("res://scripts/persistence/camera_preferences.gd")
const PLAYER_SETTINGS=preload("res://scripts/persistence/player_settings.gd")
const FLIGHT_DIAGNOSTICS=preload("res://scripts/match/flight_diagnostics.gd")
const FLIGHT_SAFETY_MODE=preload("res://scripts/persistence/flight_safety_mode.gd")
const TOUCH_DEADZONE: float = 0.12
# A single lost Android drag frame must not cause a sudden 180-degree flip.
# Valid large deliberate swipes still accumulate across successive events.
const CAMERA_MAX_SWIPE_PIXELS: float = 160.0
const JUMP_BUFFER_SECONDS: float = 0.14
# Ground-control improvement: coyote jump and buffered taps work across
# 30/60/120 Hz physics without introducing a second/midair jump.
const COYOTE_JUMP_SECONDS: float = 0.11
const JUMP_VELOCITY: float = 5.4
const GROUND_STOP_DECELERATION: float = 21.0
const GROUND_TURN_ACCELERATION: float = 19.0
const AIR_CONTROL_ACCELERATION: float = 9.0
# Lila's approved "Aceleración Táctica": temporary mobility after a
# physically confirmed player kill, not by timers or fictional rewards.
const LILA_ACCELERATION_SECONDS: float=4.0
const LILA_ACCELERATION_MULTIPLIER: float=1.20
const MAX_REPORTED_MOTION_SPEED: float = RUN_SPEED * LILA_ACCELERATION_MULTIPLIER

signal training_health_changed(value: float)
signal armor_changed(value: float)
signal player_eliminated
signal player_damaged(amount: float)
## Position provided only when an actual ray-hit enemy attacks.
signal incoming_fire(attacker_world_position: Vector3)
signal landed_from_airdrop
signal crouch_state_changed(active: bool)
signal footstep(on_stone: bool)
signal foot_contact(on_stone: bool,running: bool)
signal jumped
signal grounded_impact(on_stone: bool)
signal sprint_cancelled
signal tactical_acceleration_activated(duration: float)
@export var approved_operator_scene: PackedScene
const MAX_HEALTH: float = 200.0
var training_health: float = MAX_HEALTH
# Armor absorbs direct combat damage but not radiation outside the ring.
var armor_points: float=0.0
var vest_level: int=0
var helmet_level: int=0
var helmet_points: float=0.0
var tactical_acceleration_remaining: float=0.0
const MAX_ARMOR: float=75.0
var battle_royale_active: bool = false
var royale_eliminated: bool = false
var round_finished: bool = false
var respawn_point: Vector3 = Vector3.ZERO
var training_knockouts: int = 0
var _training_immunity: float = 0.0
var _sprint_touch: bool = false
# Real vehicle state is optional and uses the existing mobile joystick.
var _vehicle_ride: AuroraDriveableVehicle
var _vehicle_saved_collision_mask: int=1
var _jump_requested: bool = false
var _jump_buffer_seconds: float = 0.0
var _coyote_seconds: float = 0.0
var measured_ground_speed: float = 0.0
var _camera_height_target: float = 1.55

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
var _ground_contact: MeshInstance3D
var _animation_controller: Node
var _body_contact: SkeletonModifier3D
var _landing_seconds: float=0.0
var _footstep_distance: float=0.0
var _foot_contacts=preload("res://scripts/animation/aurora_foot_contacts.gd").new()
var _ground_locomotion: String="Idle"
var _animator: AnimationPlayer
var _current_clip: String = ""
# AnimationTree state mutations are committed after the active physics callback.
var _queued_air_clip: String=""
var _queued_air_phase: String=""
const WEAPONS=preload("res://scripts/combat/aurora_weapon_catalog.gd")
var _weapon_index: int=0
var _combat_action: String=""
var _combat_action_seconds: float=0.0
# Only confirmed world-space hits set this visible reaction history;
# the health/armor bookkeeping and authoritative damage stay unchanged.
var last_hit_reaction: String=""
var hit_reactions_shown: int=0
var air_mode: String="ground"
var _parachute_visual: Node3D
var _first_canopy_step_probe: bool=false
var _first_freefall_step_probe: bool=false
var _first_freefall_animation_probe: bool=false
var _freefall_avatar_reveal_pending: bool=false
var _freefall_render_probe_pending: bool=false
var _canopy_render_probe_pending: bool=false
# Exposed for native A/B tests, loaded from the welcome screen before match.
var canopy_diagnostic_mode: int=0
var _ads_active: bool = false
var _ads_zoom: float = 1.0
var _fire_held: bool = false
var _crouching: bool = false
var _normal_visual_scale: Vector3 = Vector3.ONE
var _normal_visual_y: float = 0.0
var _protection_visual: Node3D
var _backpack_visual: Node3D


# Framing-only values: do not change collision capsule, Lila's scale,
# movement, reticle ballistics, aircraft or parachute camera contracts.
const GROUND_CAMERA_DISTANCE: float=3.80
const ADS_CAMERA_DISTANCE: float=3.15

func _ready() -> void:
    canopy_diagnostic_mode=FLIGHT_SAFETY_MODE.current_mode()
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
    # Conservative near-plane proxy: the old 20 cm probe could slip
    # through the actual .43 m crystal facets at an oblique camera angle.
    _camera_collision_shape.radius=.30
    _camera_collision_query.shape=_camera_collision_shape
    _camera_collision_query.exclude=[get_rid()]
    _camera_collision_query.collision_mask=1

    # Retain floor contact while crossing the two convex halves of a gabled
    # roof, uneven thresholds and downhill ground. Snap applies only when
    # descending, so an upward jump is not pulled back onto the roof.
    # A small safety margin also prevents the 1.82m capsule from catching
    # precisely at adjoining static collider edges after parachute landing.
    floor_snap_length=0.28
    safe_margin=0.015

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
    # Actual V75.151 964x434 captures showed an undersized player silhouette.
    camera.position = Vector3(.38, .18, GROUND_CAMERA_DISTANCE)
    camera.fov = 74.0
    # The island fits inside 450m each axis; 680m covers the diagonal
    # flight views while rejecting invisible far geometry. A safe 8cm
    # near clip improves depth precision on mobile 24-bit z buffers
    # without clipping the 4.6m third-person shoulder camera.
    camera.near=.08
    camera.far=680.0
    camera.current = true
    _camera_pivot.add_child(camera)
    _camera = camera
    _camera_pivot.rotation.x = _pitch
    # An independent, physical, two-triangle contact decal. No extra skeletal
    # bones, no fake geometry on Lila, no impact on actual raycasts or loot.
    _ground_contact=GROUND_CONTACT.new() as MeshInstance3D
    add_child(_ground_contact)

    var operator_scene: PackedScene = approved_operator_scene
    if operator_scene == null and ResourceLoader.exists("res://assets/characters/lila_aurora.glb"):
        operator_scene = load("res://assets/characters/lila_aurora.glb") as PackedScene
    if operator_scene != null:
        _avatar = operator_scene.instantiate() as Node3D
        _avatar.name = "AuroraFemaleRiggedOperator"
        add_child(_avatar)
        fit_operator_visual(_avatar)
        # Actual purchased palette is loaded from the same verified offline
        # journal as match rewards. No texture swapping during physics.
        var cosmetic: Dictionary=LOCAL_PLAYER_RECORDS.new().cosmetic_state()
        COSMETICS.apply_to_operator(_avatar,str(
            cosmetic.get("equipped","aurora_base")))
        _normal_visual_scale = _avatar.scale
        _normal_visual_y = _avatar.position.y
        _animator = _avatar.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
        if _animator == null:
            _animator = _avatar.find_child("AnimationPlayer", true, false) as AnimationPlayer
        if _animator:
            _animation_controller=ANIMATION_CONTROLLER.new()
            add_child(_animation_controller)
            _animation_controller.setup(_animator)
        var skeleton:=_avatar.find_child("Skeleton3D",true,false) as Skeleton3D
        if skeleton!=null and skeleton.find_bone("LeftUpLeg")>=0:
            _body_contact=BODY_CONTACT.new()
            _body_contact.name="LilaBodyContact"
            skeleton.add_child(_body_contact)
            _body_contact.bind_player(self)
        _play_matching_animation("AuroraArmedIdle")
    else:
        push_warning("Lila Aurora character asset could not be loaded.")
    # Build the actual canopy meshes and materials once during scene load,
    # *not* in the Android render/physics transition during freefall.
    _create_parachute()
    _parachute_visual.visible=false


func _process(_delta: float) -> void:
    # Draw only when physics confirms contact. Flight, high zoom, riding a car,
    # elimination and the lobby never create a misleading floating footprint.
    if _ground_contact!=null:
        _ground_contact.visible=(air_mode=="ground" and is_on_floor() and
            not royale_eliminated and not round_finished and
            not (_vehicle_ride!=null and is_instance_valid(_vehicle_ride)))


func _physics_process(delta: float) -> void:
    if _vehicle_ride!=null:
        if not is_instance_valid(_vehicle_ride) or royale_eliminated or round_finished:
            force_vehicle_exit()
        else:
            _advance_vehicle_rider(delta)
            return
    if air_mode!="ground":
        _foot_contacts.advance(&"",0.0,0.0,delta)
        _air_step(delta)
        return
    if royale_eliminated or round_finished:
        _foot_contacts.advance(&"",0.0,0.0,delta)
        velocity=Vector3.ZERO
        return
    _training_immunity=maxf(0.0,_training_immunity-delta)
    tactical_acceleration_remaining=maxf(0.0,
        tactical_acceleration_remaining-delta)
    # A jump pressed in midair may be buffered briefly near touchdown, but
    # never kept indefinitely to trigger a surprise second jump on landing.
    _jump_buffer_seconds=maxf(0.0,_jump_buffer_seconds-delta)
    if Input.is_action_just_pressed("jump"):
        # Keyboard and touch share the exact same buffered jump path.
        _jump_requested=true
        _jump_buffer_seconds=JUMP_BUFFER_SECONDS
    if _jump_buffer_seconds<=0.0:
        _jump_requested=false
    var control := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    if _move_axis.length() > 0.0:
        control = _move_axis

    # Delta-time camera smoothing avoids abrupt yaw/pitch changes on quick swipes.
    var smooth: float = 1.0 - exp(-delta * 19.0)
    _yaw = wrapf(rotate_toward(_yaw, _desired_yaw,
        minf(absf(angle_difference(_yaw,_desired_yaw))*smooth,delta*8.5)),-PI,PI)
    _recover_recoil(delta)
    _pitch = lerpf(_pitch, clampf(_desired_pitch + _recoil_pitch, -0.55, 0.62), smooth)
    _camera_pivot.rotation.x = _pitch
    # Eye level follows skeletal crouch smoothly while collision changes
    # immediately. No camera pop when standing up below a doorway.
    _camera_pivot.position.y=lerpf(_camera_pivot.position.y,
        _camera_height_target,1.0-exp(-delta*13.0))
    var relative_direction := Vector3(control.x, 0.0, control.y)
    var facing := Basis(Vector3.UP, _yaw)
    var world_direction := (facing * relative_direction).limit_length(1.0)
    var run_fast := (Input.is_action_pressed("run") or _sprint_touch) and         not _crouching and not _fire_held and not _ads_active
    var target_speed: float = WALK_SPEED
    if _crouching:
        target_speed = WALK_SPEED * .52
    elif run_fast:
        target_speed = RUN_SPEED
    # A physical elimination briefly increases actual walk/run mobility.
    # Crouching, ADS and held fire never gain a hidden speed advantage.
    if not _crouching and not _ads_active and not _fire_held:
        target_speed*=tactical_acceleration_scale(
            tactical_acceleration_remaining)
    var target_velocity := world_direction * target_speed

    var was_grounded: bool=is_on_floor()
    _coyote_seconds=(COYOTE_JUMP_SECONDS if was_grounded else
        maxf(0.0,_coyote_seconds-delta))
    var horizontal_velocity:=Vector3(velocity.x,0.0,velocity.z)
    var accel: float=ACCELERATION
    if not was_grounded:
        accel=AIR_CONTROL_ACCELERATION
    elif world_direction.length_squared()<.002:
        accel=GROUND_STOP_DECELERATION
    elif horizontal_velocity.dot(target_velocity)<-.35:
        accel=GROUND_TURN_ACCELERATION
    velocity.x = move_toward(velocity.x, target_velocity.x, accel * delta)
    velocity.z = move_toward(velocity.z, target_velocity.z, accel * delta)
    if _jump_requested and _jump_buffer_seconds>0.0 and (
            was_grounded or _coyote_seconds>0.0) and not _crouching:
        velocity.y=JUMP_VELOCITY
        _coyote_seconds=0.0
        _jump_requested=false
        _jump_buffer_seconds=0.0
        jumped.emit()
    elif not was_grounded:
        velocity.y-=GRAVITY*delta
    else:
        velocity.y=0.0

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
    # Use real displacement AFTER collision resolution. Previous gait
    # animation used desired velocity, which animated running on the spot
    # when a house doorway or movable cover blocked the player.
    var actual_speed: float=measured_motion_speed(
        global_position-before_move,delta) 
    measured_ground_speed=actual_speed
    var moving_on_ground: bool=is_on_floor() and actual_speed>1.2 and move_strength>.05
    if moving_on_ground:
        _footstep_distance=fmod(_footstep_distance+actual_speed*delta,
            _step_stride(actual_speed,_crouching))
    else:
        _footstep_distance=0.0
    _landing_seconds=maxf(0.0,_landing_seconds-delta)
    if not was_on_floor and is_on_floor() and falling_speed< -2.0:
        _landing_seconds=.28
        if falling_speed< -4.5:
            grounded_impact.emit(_on_stone_footing())

    if _camera:
        # Slightly closer physical shoulder framing retains peripheral vision;
        # ADS and 8x scope use their own distances and FOV.
        var desired_fov: float = clampf(74.0 / _ads_zoom, 9.0, 74.0) if _ads_active else (77.0 if run_fast and move_strength>.25 else 74.0)
        _camera.fov = lerpf(_camera.fov, desired_fov, 1.0 - exp(-delta * 11.0))
        var desired_distance: float=(1.15 if _ads_active and _ads_zoom>=6.0
            else ADS_CAMERA_DISTANCE if _ads_active
            else GROUND_CAMERA_DISTANCE)
        var preferred_shoulder: float=.16 if _ads_active and _ads_zoom>=6.0 else .38
        # Probe the PREFERRED shoulder, not only the currently relocated
        # camera. Otherwise moving to a free centerline clears the probe and
        # immediately forces the camera into the wall again (oscillation).
        var preferred_clearance: float=_collision_safe_camera_distance(
            desired_distance,preferred_shoulder)
        var shoulder_target: float=preferred_shoulder
        # The old test picked the centre as soon as it was slightly
        # clearer, WITHOUT checking a completely free opposite shoulder.
        # On the player's phone this could force the camera to sit in a
        # blue ice pillar while Lila disappeared below 1.50 m distance.
        if preferred_clearance<desired_distance-.35 and desired_distance>1.60:
            var center_clearance: float=_collision_safe_camera_distance(
                desired_distance,0.0)
            var far_shoulder: float=-.22 if _ads_active else -.38
            var opposite_clearance: float=_collision_safe_camera_distance(
                desired_distance,far_shoulder)
            var best_clearance: float=preferred_clearance
            if center_clearance>best_clearance+.25:
                best_clearance=center_clearance
                shoulder_target=0.0
            if opposite_clearance>best_clearance+.25:
                shoulder_target=far_shoulder
        # Transition quickly AWAY from nearby crystals; return to the
        # normal right shoulder smoothly when no object obstructs view.
        var shoulder_speed: float=22.0 if preferred_clearance<1.60 else 11.0
        _camera.position.x=lerpf(_camera.position.x,shoulder_target,
            1.0-exp(-delta*shoulder_speed))
        # Recheck the CURRENT moving camera axis, never the unoccupied
        # target axis; collision remains authoritative during transitions.
        var safe_distance: float=_collision_safe_camera_distance(
            desired_distance,_camera.position.x)
        # Contract immediately to stay outside collisions; expand with
        # controlled smoothing so opening a door never snaps the viewpoint.
        _camera.position.z=minf(safe_distance,
            lerpf(_camera.position.z,safe_distance,1.0-exp(-delta*15.0)))
        if _avatar:
            # Use the CAMERA'S ACTUAL position, not the future safe target:
            # otherwise the avatar can pop into view while still within 1 m.
            _avatar.visible=_camera.position.z>1.50 and not (_ads_active and _ads_zoom>=6.0)
    # Non-root-motion strafe lean keeps Lila's armed gait visually responsive
    # to diagonal input while preserving capsule physics and aim direction.
    if _avatar:
        var lateral: float=global_basis.x.dot(world_direction)
        var lean: float=clampf(-lateral*.065,-.065,.065) if is_on_floor() and not _crouching else 0.0
        _avatar.rotation.z=lerpf(_avatar.rotation.z,lean,1.0-exp(-delta*12.0))
    if _animator:
        _combat_action_seconds=maxf(0.0,_combat_action_seconds-delta)
        if _combat_action_seconds<=0.0:
            _combat_action=""
        var speed: float=actual_speed
        var locomotion: String=_select_locomotion(speed)
        if _animation_controller:
            _animation_controller.set_gait_speed(speed,
                RUN_SPEED if locomotion=="Run" else WALK_SPEED if locomotion=="Walk" else 1.0)
        var clip: String="AuroraArmed"+locomotion
        # Real post-collision motion, projected into Lila's facing space:
        # ADS/backwards/strafe steps stay under the independently animated
        # rifle grip. No camera-linked avatar sliding or fake root motion.
        if (_ads_active or _fire_held) and is_on_floor() and not _crouching:
            var physical_motion: Vector3=(global_position-before_move)/maxf(delta,.001)
            var relative_motion: Vector3=global_basis.inverse()*Vector3(
                physical_motion.x,0.0,physical_motion.z)
            var tactical: String=tactical_gait_clip(relative_motion,
                actual_speed,true)
            if not tactical.is_empty():
                clip=tactical
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
    if moving_on_ground and _animation_controller and _animation_controller.playback:
        var playback: AnimationNodeStateMachinePlayback=_animation_controller.playback
        var gait: StringName=playback.get_current_node()
        if _foot_contacts.advance(gait,playback.get_current_play_position(),
                playback.get_current_length(),delta):
            var stone: bool=_on_stone_footing()
            footstep.emit(stone)
            foot_contact.emit(stone,gait==&"AuroraArmedRun")
    else:
        _foot_contacts.advance(&"",0.0,0.0,delta)


## Select animation from physics-resolved displacement in the character's
## local facing frame, NOT the touch joystick alone. A sideways shove into
## a solid wall thus cannot play a strafing run while standing still.
static func tactical_gait_clip(local_motion: Vector3,actual_speed: float,
        aiming: bool) -> String:
    if not aiming or not local_motion.is_finite() or not is_finite(actual_speed):
        return ""
    if actual_speed<.75:
        return ""
    var lateral: float=absf(local_motion.x)
    var forward: float=absf(local_motion.z)
    if lateral>forward*.78 and lateral>1.0:
        return "AuroraArmedStrafeLeft" if local_motion.x<0.0 else (
            "AuroraArmedStrafeRight")
    if local_motion.z>1.0 and local_motion.z>lateral*.78:
        return "AuroraArmedBackpedal"
    return ""


## Bounded actual metres/second, never a desired target speed or an
## animation-only approximation. Prevents teleport/slope penetration spikes
## from playing 8x gait and creating footsteps in an immovable doorway.
static func measured_motion_speed(displacement: Vector3,delta: float) -> float:
    if not displacement.is_finite() or not is_finite(delta) or delta<=0.0:
        return 0.0
    var horizontal: float=Vector2(displacement.x,displacement.z).length()
    return clampf(horizontal/delta,0.0,MAX_REPORTED_MOTION_SPEED)


func _step_stride(speed: float,crouching: bool=false) -> float:
    # Actual horizontal distance between footfalls, not time intervals.
    # A slow crouch must never generate running cadence. This avoids
    # desynchronising sound when sprint stamina / joystick input changes.
    if crouching:
        return 1.02
    return lerpf(1.78,2.35,clampf((speed-WALK_SPEED)/
        (RUN_SPEED-WALK_SPEED),0.0,1.0))


func _on_stone_footing() -> bool:
    return _foot_contacts.stone_footing(self)


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
    _queued_air_clip=""
    _queued_air_phase=""
    _first_freefall_step_probe=false
    _first_freefall_animation_probe=false
    _freefall_avatar_reveal_pending=false
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
    _queued_air_clip=""
    _queued_air_phase=""
    _first_freefall_step_probe=false
    _first_freefall_animation_probe=false
    _freefall_avatar_reveal_pending=_avatar!=null and not \
        FLIGHT_SAFETY_MODE.skip_freefall_avatar(canopy_diagnostic_mode)
    velocity=Vector3(inherited_velocity.x,-4.0,inherited_velocity.z)
    _current_clip=""
    if _avatar:
        # Keep the aircraft-hidden rig off the GPU for one real freefall
        # physics step. Reveal it after move_and_slide() has completed, then
        # blend the skeletal animation after the first rendered avatar frame.
        _avatar.visible=false
        FLIGHT_DIAGNOSTICS.checkpoint("active","freefall",self,
            "freefall_avatar_reveal_queued",
            "pending="+str(_freefall_avatar_reveal_pending)+
            " mode="+str(canopy_diagnostic_mode))


func deploy_parachute() -> void:
    if air_mode!="freefall":
        return
    FLIGHT_DIAGNOSTICS.checkpoint("active","parachute",self,"actor_canopy_mode_before",
        "from="+air_mode+" anim="+_current_clip)
    air_mode="parachute"
    _queued_air_clip=""
    _queued_air_phase=""
    _freefall_avatar_reveal_pending=false
    if _avatar:
        _avatar.visible=true
    _first_canopy_step_probe=false
    # Do not clear a still-connected signal on repeated deploy attempts.
    # Only an actual frame or a later explicit disconnect may clear it.
    # The meshes already exist from _ready(). Only their visibility changes
    # in the deferred pass; native resources are not allocated in mid-air.
    call_deferred("_commit_parachute_visual")
    _current_clip=""
    FLIGHT_DIAGNOSTICS.checkpoint("active","parachute",self,"actor_canopy_mode_after",
        "mode="+str(canopy_diagnostic_mode)+" avatar="+str(_avatar!=null))


func _commit_parachute_visual() -> void:
    if air_mode!="parachute" or not is_inside_tree():
        return
    FLIGHT_DIAGNOSTICS.checkpoint("active","parachute",self,"canopy_visual_before")
    if _parachute_visual and not FLIGHT_SAFETY_MODE.skip_canopy_mesh(canopy_diagnostic_mode):
        _parachute_visual.visible=true
        FLIGHT_DIAGNOSTICS.checkpoint("active","parachute",self,"canopy_visual_enabled",
            "mesh_children="+str(_parachute_visual.get_child_count()))
        _watch_canopy_first_render()
    else:
        FLIGHT_DIAGNOSTICS.checkpoint("active","parachute",self,"canopy_visual_skipped_diagnostic")


func _watch_canopy_first_render() -> void:
    # Native Android GPU errors cannot be caught by GDScript. This one-shot
    # marker tells us whether a rendered frame completed after enabling the
    # canopy mesh. It is intentionally absent in headless QA.
    if not is_inside_tree() or DisplayServer.get_name()=="headless":
        return
    # Repeated canopy opens in the same scene must never connect a callable
    # twice while the renderer has not yet emitted its next frame.
    if _canopy_render_probe_pending or RenderingServer.frame_post_draw.is_connected(
        _on_canopy_frame_post_draw):
        return
    _canopy_render_probe_pending=true
    RenderingServer.frame_post_draw.connect(_on_canopy_frame_post_draw,CONNECT_ONE_SHOT)


func _on_canopy_frame_post_draw() -> void:
    # Do not write files from a RenderingServer callback.
    call_deferred("_record_canopy_render_finished")


func _record_canopy_render_finished() -> void:
    if not is_inside_tree() or air_mode!="parachute":
        return
    _canopy_render_probe_pending=false
    FLIGHT_DIAGNOSTICS.checkpoint("active","parachute",self,
        "canopy_first_frame_rendered",
        "frame="+str(Engine.get_process_frames())+
        " mesh="+str(_parachute_visual!=null and _parachute_visual.visible)+
        " clip="+_current_clip)


func _commit_freefall_avatar_reveal() -> void:
    if not is_inside_tree() or air_mode!="freefall" or \
        not _freefall_avatar_reveal_pending:
        return
    _freefall_avatar_reveal_pending=false
    FLIGHT_DIAGNOSTICS.checkpoint("active","freefall",self,
        "freefall_avatar_reveal_before")
    if _avatar:
        _avatar.visible=true
    FLIGHT_DIAGNOSTICS.checkpoint("active","freefall",self,
        "freefall_tick_avatar_visibility_set",
        "mesh_visible="+str(_avatar!=null and _avatar.visible)+
        " mode="+str(canopy_diagnostic_mode))
    _watch_freefall_first_render()


func _watch_freefall_first_render() -> void:
    if DisplayServer.get_name()=="headless" or not is_inside_tree():
        return
    if _freefall_render_probe_pending or RenderingServer.frame_post_draw.is_connected(
        _on_freefall_frame_post_draw):
        return
    _freefall_render_probe_pending=true
    RenderingServer.frame_post_draw.connect(_on_freefall_frame_post_draw,CONNECT_ONE_SHOT)


func _on_freefall_frame_post_draw() -> void:
    call_deferred("_record_freefall_render_completed")


func _record_freefall_render_completed() -> void:
    _freefall_render_probe_pending=false
    if not is_inside_tree() or air_mode!="freefall":
        return
    FLIGHT_DIAGNOSTICS.checkpoint("active","freefall",self,
        "freefall_tick_first_render_completed",
        "avatar="+str(_avatar!=null and _avatar.visible)+
        " clip="+_current_clip)


func _air_step(delta: float) -> void:
    # Dedicated first-freefall probes capture the first actor callback after
    # jump_committed, which was the exact last Motorola breadcrumb.
    var first_freefall_step: bool=air_mode=="freefall" and not _first_freefall_step_probe
    if first_freefall_step:
        _first_freefall_step_probe=true
        FLIGHT_DIAGNOSTICS.checkpoint("active","freefall",self,
            "freefall_tick_actor_enter",
            "dt="+str(snappedf(delta,0.001))+
            " mode="+str(canopy_diagnostic_mode)+
            " avatar="+str(_avatar!=null and _avatar.visible))
    # The operator runs its own physics callback; it may run BEFORE the
    # deployment director's first_parachute_physics_tick checkpoint.
    var first_canopy_step: bool=air_mode=="parachute" and not _first_canopy_step_probe
    if first_canopy_step:
        _first_canopy_step_probe=true
        FLIGHT_DIAGNOSTICS.checkpoint("active","parachute",self,"operator_first_tick_enter",
            "dt="+str(snappedf(delta,0.001))+
            " mode="+str(canopy_diagnostic_mode)+
            " anim="+_current_clip+
            " mesh="+str(_parachute_visual!=null and _parachute_visual.visible))
    var alpha: float=1.0-exp(-delta*16.0)
    _yaw=wrapf(rotate_toward(_yaw,_desired_yaw,
        minf(absf(angle_difference(_yaw,_desired_yaw))*alpha,delta*8.5)),-PI,PI)
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
    if first_freefall_step:
        FLIGHT_DIAGNOSTICS.checkpoint("active","freefall",self,"freefall_tick_after_camera",
            "pitch="+str(_pitch)+" z="+str(_camera.position.z if _camera else -1.0))
    if first_canopy_step:
        FLIGHT_DIAGNOSTICS.checkpoint("active","parachute",self,"operator_after_camera",
            "camera_z="+str(_camera.position.z if _camera else -1.0)+
            " pitch="+str(_pitch))
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
    if first_freefall_step:
        FLIGHT_DIAGNOSTICS.checkpoint("active","freefall",self,"freefall_tick_before_move_and_slide",
            "fall_speed="+str(snappedf(velocity.y,0.01)))
    if first_canopy_step:
        FLIGHT_DIAGNOSTICS.checkpoint("active","parachute",self,"operator_before_move_and_slide",
            "fall_speed="+str(snappedf(velocity.y,0.01)))
    # move_and_slide() resolves vertical velocity to zero on contact, so
    # capture the real descent speed BEFORE the collision solver runs.
    var touchdown_speed_before_collision: float=velocity.y
    move_and_slide()
    if first_freefall_step:
        FLIGHT_DIAGNOSTICS.checkpoint("active","freefall",self,"freefall_tick_after_move_and_slide",
            "collisions="+str(get_slide_collision_count()))
        if _freefall_avatar_reveal_pending:
            call_deferred("_commit_freefall_avatar_reveal")
    if first_canopy_step:
        FLIGHT_DIAGNOSTICS.checkpoint("active","parachute",self,"operator_after_move_and_slide",
            "ground="+str(is_on_floor())+" collisions="+str(get_slide_collision_count()))
    _camera_pivot.rotation.y=wrapf(_yaw-rotation.y,-PI,PI)
    # A first freefall physics tick and the first visible skinned render
    # must finish before the visual animation state machine can transition.
    # MODE 5 intentionally keeps the rig hidden while testing the physics.
    var allow_air_animation: bool=air_mode!="freefall" or (
        not _freefall_avatar_reveal_pending and
        not _freefall_render_probe_pending and
        not first_freefall_step)
    if _animator and allow_air_animation:
        var clip: String="AuroraFreefall" if air_mode=="freefall" or (
            air_mode=="parachute" and FLIGHT_SAFETY_MODE.skip_canopy_animation(canopy_diagnostic_mode)
        ) else "AuroraParachute"
        if air_mode=="freefall" and FLIGHT_SAFETY_MODE.skip_freefall_animation(canopy_diagnostic_mode):
            clip="AuroraArmedIdle"
        if _current_clip!=clip and (_queued_air_clip!=clip or _queued_air_phase!=air_mode):
            var first_animation: bool=air_mode=="freefall" and not _first_freefall_animation_probe
            if first_animation:
                _first_freefall_animation_probe=true
                FLIGHT_DIAGNOSTICS.checkpoint("active","freefall",self,
                    "freefall_tick_before_animation","requested="+clip)
            if first_canopy_step:
                FLIGHT_DIAGNOSTICS.checkpoint("active","parachute",self,"operator_before_canopy_animation",
                    "requested="+clip+" current="+_current_clip)
            # Do not travel AnimationTree's skeletal state machine inside
            # CharacterBody3D.move_and_slide()'s physics callback. This keeps
            # real airborne animations while avoiding an in-step rig mutation.
            _queued_air_clip=clip
            _queued_air_phase=air_mode
            call_deferred("_commit_air_clip",clip,air_mode,first_animation,first_canopy_step)
    if is_on_floor():
        # Touchdown previously discarded the entire landing state. Preserve
        # the genuine surface impact so Lila plays AuroraLand and the landing
        # sound fires once, including a touchdown on a coastal roof.
        air_mode="ground"
        _queued_air_clip=""
        _queued_air_phase=""
        velocity=Vector3.ZERO
        if _parachute_visual:
            _parachute_visual.visible=false
        _current_clip=""
        if touchdown_speed_before_collision < -2.0:
            _landing_seconds=.28
            if touchdown_speed_before_collision < -4.5:
                grounded_impact.emit(_on_stone_footing())
        landed_from_airdrop.emit()


func _commit_air_clip(clip: String, expected_phase: String,
        first_freefall: bool, first_canopy: bool) -> void:
    # A queued freefall clip must not run after the parachute opens or after
    # touchdown. Newer requests supersede older ones without reallocating
    # the skinned actor or disabling any movement/animation feature.
    if not is_inside_tree() or air_mode!=expected_phase or \
        _queued_air_clip!=clip or _queued_air_phase!=expected_phase:
        return
    _queued_air_clip=""
    _queued_air_phase=""
    _play_matching_animation(clip)
    if first_freefall:
        FLIGHT_DIAGNOSTICS.checkpoint("active","freefall",self,
            "freefall_tick_after_animation","selected="+_current_clip)
    if first_canopy:
        FLIGHT_DIAGNOSTICS.checkpoint("active","parachute",self,
            "operator_after_canopy_animation","selected="+_current_clip)


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
    var lila_rig: bool=_avatar!=null and _avatar.scene_file_path.ends_with("/lila_aurora.glb")
    for angle in [0.0,PI*.5,PI,PI*1.5]:
        # Two prewarmed cords per hand, ending near the canopy clip's raised wrists.
        if lila_rig:
            angle+=PI*.25
        var endpoint:=Vector3(cos(angle)*1.85,4.55,sin(angle)*1.85)
        var start:=Vector3(cos(angle)*.18,1.5,sin(angle)*.18)
        if lila_rig:
            start=Vector3(signf(endpoint.x)*.27,1.64,-.13)
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


func receive_training_hit(amount: float, environmental: bool=false,
        attacker_world_position: Vector3=Vector3(INF,INF,INF),
        contact: Vector3=Vector3(INF,INF,INF)) -> void:
    if amount<=0 or royale_eliminated or round_finished or (not environmental and _training_immunity>0):
        return
    var health_damage: float=amount
    if not environmental:
        var height: float=contact.y-global_position.y
        var upper_body: bool=helmet_level>0 and contact.is_finite() and (
            height>=(.98 if _crouching else 1.43) and height<=(1.26 if _crouching else 1.82))
        var available: float=helmet_points if upper_body else armor_points
        var absorbed: float=minf(available,amount*.65)
        if absorbed>0.0:
            if upper_body:
                helmet_points-=absorbed
            else:
                armor_points-=absorbed
            armor_changed.emit(armor_points)
            health_damage-=absorbed
    training_health=maxf(0.0,training_health-health_damage)
    training_health_changed.emit(training_health)
    player_damaged.emit(health_damage)
    if not environmental and attacker_world_position.is_finite():
        incoming_fire.emit(attacker_world_position)
    if _animation_controller and _combat_action_seconds<=.24:
        # Incoming-fire direction is transformed into body-local coordinates.
        # Environmental damage or an unknown attacker keeps the old generic
        # reaction and never invents an enemy or a player hit.
        var reaction: String=directional_hit_clip(attacker_world_position,
            global_position,global_basis) if not environmental else "AuroraHit"
        _animation_controller.action(reaction,.28)
        last_hit_reaction=reaction
        hit_reactions_shown+=1
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
        training_health=MAX_HEALTH
        _training_immunity=3.0
        velocity=Vector3.ZERO
        global_position=respawn_point
        training_health_changed.emit(training_health)


## Convert a CONFIRMED impact's world-space origin into a skeletal action.
## -Z is Lila's front, +Z is behind; X is left/right in her facing frame.
## No movement/camera rotation or damage multipliers occur here.
static func directional_hit_clip(from_world: Vector3,position: Vector3,
        facing: Basis) -> String:
    if (not from_world.is_finite() or not position.is_finite() or
            not facing.is_finite()):
        return "AuroraHit"
    var toward: Vector3=facing.inverse()*(from_world-position)
    if not toward.is_finite() or toward.length_squared()<.01:
        return "AuroraHit"
    if absf(toward.x)>absf(toward.z):
        return "AuroraHitLeft" if toward.x<0.0 else "AuroraHitRight"
    return "AuroraHitFront" if toward.z<0.0 else "AuroraHitBack"


## No armor persistence across separate offline matches: supplies must be
## acquired in the world. Environmental damage intentionally bypasses armor.
func equip_armor(points: float=75.0) -> bool:
    if not battle_royale_active or royale_eliminated or round_finished:
        return false
    if points<=0.0 or armor_points>=MAX_ARMOR:
        return false
    armor_points=minf(MAX_ARMOR,armor_points+points)
    vest_level=3
    _sync_protection_visual()
    armor_changed.emit(armor_points)
    return true


func equip_protection(is_helmet: bool,level: int) -> bool:
    if not battle_royale_active or royale_eliminated or round_finished or level<1 or level>3:
        return false
    var current_level: int=helmet_level if is_helmet else vest_level
    var points: float=helmet_points if is_helmet else armor_points
    var capacity: float=float(level*(15 if is_helmet else 25))
    if level<current_level or (level==current_level and points>=capacity):
        return false
    if is_helmet:
        helmet_level=level
        helmet_points=capacity
    else:
        vest_level=level
        armor_points=capacity
    _sync_protection_visual()
    armor_changed.emit(armor_points)
    return true


func _sync_protection_visual() -> void:
    if _protection_visual==null and _avatar!=null and (helmet_level>0 or vest_level>0):
        _protection_visual=preload("res://scripts/player/aurora_protection_visual.gd").new()
        add_child(_protection_visual)
        _protection_visual.attach(_avatar)
    if _protection_visual!=null:
        _protection_visual.apply_levels(helmet_level,vest_level)


## Inventory owns the backpack level; this is visual-only and appears
## on Lila's real Spine bone after collecting the world pickup.
func set_backpack_visual_level(level: int) -> void:
    if _avatar==null:
        return
    if _backpack_visual==null and level>0:
        var gear_path: String=(
            "res://assets/gear/aurora_v3_private/AuroraMilitaryBackpackPrivate.glb")
        if ResourceLoader.exists(gear_path,"PackedScene"):
            _backpack_visual=BACKPACK_VISUAL.new()
            add_child(_backpack_visual)
            _backpack_visual.attach(_avatar)
    if _backpack_visual:
        _backpack_visual.apply_level(level)


func end_sector_battle() -> void:
    force_vehicle_exit()
    round_finished=true
    tactical_acceleration_remaining=0.0
    velocity=Vector3.ZERO
    reset_controls()


func begin_sector_battle(from_airdrop: bool=false) -> void:
    force_vehicle_exit()
    reset_controls()
    tactical_acceleration_remaining=0.0
    round_finished=false
    battle_royale_active = true
    royale_eliminated = false
    training_health = MAX_HEALTH
    armor_points=0.0
    vest_level=0
    helmet_level=0
    helmet_points=0.0
    _sync_protection_visual()
    armor_changed.emit(armor_points)
    velocity=Vector3.ZERO
    if from_airdrop:
        respawn_point=global_position
    else:
        global_position=respawn_point
    _training_immunity=2.0
    set_firing(false)
    set_touch_move_axis(Vector2.ZERO)
    # BR is a fresh physical match: Lila must not retain a running, aiming
    # or injury pose from the previous round while controls are reset.
    # Flight/parachute transitions keep their own animation lifecycle.
    if air_mode=="ground" and _animation_controller:
        _animation_controller.reset_ground_pose()
        _current_clip="AuroraArmedIdle"
    training_health_changed.emit(training_health)


func receive_training_heal(amount: float) -> void:
    if royale_eliminated or round_finished:
        return
    if amount<=0:
        return
    training_health=minf(MAX_HEALTH,training_health+amount)
    training_health_changed.emit(training_health)


func set_touch_move_axis(direction: Vector2) -> void:
    var strength: float=direction.length()
    _move_axis=Vector2.ZERO
    if direction.is_finite() and strength>TOUCH_DEADZONE and not round_finished and not royale_eliminated:
        _move_axis=direction.normalized()*clampf((strength-TOUCH_DEADZONE)/(1.0-TOUCH_DEADZONE),0.0,1.0)


## Bounded speed boost; applies to actual CharacterBody target velocity.
## All shots, damage, collision checks and player stats remain authoritative.
static func tactical_acceleration_scale(seconds: float) -> float:
    if not is_finite(seconds) or seconds<=0.0:
        return 1.0
    return LILA_ACCELERATION_MULTIPLIER


func activate_tactical_acceleration() -> bool:
    if not battle_royale_active or not can_act():
        return false
    tactical_acceleration_remaining=LILA_ACCELERATION_SECONDS
    tactical_acceleration_activated.emit(tactical_acceleration_remaining)
    return true


func set_touch_run(active: bool) -> void:
    # Do not silently re-latch sprint while the player holds a scoped view.
    _sprint_touch=active and can_act() and not _ads_active and not _crouching


func touch_jump() -> void:
    if can_act():
        _jump_requested=true
        _jump_buffer_seconds=JUMP_BUFFER_SECONDS


func set_ads(ads: bool, zoom: float) -> void:
    _ads_active = ads
    _ads_zoom = clampf(zoom, 1.0, 8.0)
    if ads and _sprint_touch:
        _sprint_touch=false
        sprint_cancelled.emit()
    _current_clip=""


func set_equipped_weapon(index: int) -> void:
    _weapon_index=clampi(index,WEAPONS.AR,WEAPONS.ENTRIES.size()-1)
    _current_clip=""
    _combat_action=""
    _combat_action_seconds=0.0
    if _animation_controller:
        _animation_controller.cancel_action()


func play_weapon_action(action: String, seconds: float) -> void:
    var requested: String=""
    match action:
        "fire":
            requested="AuroraFireAWM" if _weapon_index==1 else "AuroraFire"
        "reload":
            match _weapon_index:
                WEAPONS.MP40: requested="AuroraReloadMP40"
                WEAPONS.AWM: requested="AuroraReloadAWM"
                _: requested="AuroraReloadAR"
        "heal":
            requested="AuroraHeal"
        "equip":
            requested="AuroraEquip"
        _:
            return
    if _animator==null or not _animator.has_animation(requested):
        return
    _combat_action=requested
    _combat_action_seconds=maxf(0.05,seconds)
    if _animation_controller:
        _animation_controller.action(requested,seconds)


func cancel_reload_action() -> void:
    if not _combat_action.begins_with("AuroraReload"):
        return
    _combat_action=""
    _combat_action_seconds=0.0
    if _animation_controller:
        _animation_controller.cancel_action()


func cancel_medical_action() -> void:
    # Do not cancel a gun animation or reset the character's locomotion
    # when this is called by unrelated lifecycle transitions.
    if _combat_action!="AuroraHeal":
        return
    _combat_action=""
    _combat_action_seconds=0.0
    if _animation_controller:
        _animation_controller.cancel_action()


func set_firing(active: bool) -> void:
    _fire_held = active
    # Shooting cancels sprint, rather than silently re-accelerating when the
    # player releases fire. Keep the run HUD toggle synchronized.
    if active and _sprint_touch:
        _sprint_touch=false
        sprint_cancelled.emit()


func set_crouch(active: bool) -> void:
    if not can_act():
        return
    if _crouching==active:
        return
    if not active and not _can_stand():
        # Refuse to stretch collision into an overhead obstacle.
        crouch_state_changed.emit(true)
        return
    if active and _sprint_touch:
        _sprint_touch=false
        sprint_cancelled.emit()
    _apply_crouch(active)


func _apply_crouch(active: bool) -> void:
    _crouching=active
    var collider:=get_node_or_null("CapsuleCollider") as CollisionShape3D
    if collider:
        var capsule:=collider.shape as CapsuleShape3D
        if capsule:
            capsule.height=1.22 if active else 1.82
        collider.position.y=.62 if active else .92
    _camera_height_target=1.13 if active else 1.55
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


## The operator rides inside a real VehicleBody3D chassis. The gameplay
## CharacterBody is moved with the seat, retains health and hit reactions,
## while the existing camera is the only active third-person view.
func begin_vehicle_ride(car: AuroraDriveableVehicle) -> bool:
    if car==null or _vehicle_ride!=null or not can_act():
        return false
    if not car.enter(self):
        return false
    reset_controls()
    _vehicle_ride=car
    _vehicle_saved_collision_mask=collision_mask
    collision_mask=0  # operator no longer moves by kinematic collisions
    add_collision_exception_with(car)
    car.add_collision_exception_with(self)
    velocity=Vector3.ZERO
    _yaw=car.rotation.y
    _desired_yaw=_yaw
    rotation.y=_yaw
    if _avatar:
        _avatar.hide()
    return true


func _advance_vehicle_rider(delta: float) -> void:
    if _vehicle_ride==null or not is_instance_valid(_vehicle_ride):
        return
    var car: AuroraDriveableVehicle=_vehicle_ride
    # Ride simulation must not pause damage immunity, buffs or recoil timers.
    _training_immunity=maxf(0.0,_training_immunity-delta)
    tactical_acceleration_remaining=maxf(0.0,
        tactical_acceleration_remaining-delta)
    _recoil_pitch=move_toward(_recoil_pitch,0.0,delta*.32)
    global_position=car.to_global(Vector3(0,-.06,.18))
    rotation.y=car.global_rotation.y
    velocity=Vector3.ZERO
    measured_ground_speed=0.0
    _footstep_distance=0.0
    _pitch=lerpf(_pitch,clampf(_desired_pitch,-.55,.42),
        1.0-exp(-delta*10.0))
    _yaw=lerp_angle(_yaw,_desired_yaw,1.0-exp(-delta*10.0))
    _camera_pivot.rotation=Vector3(_pitch,
        wrapf(_yaw-rotation.y,-PI,PI),0)
    _camera_pivot.position.y=1.7
    if _camera:
        _camera.fov=lerpf(_camera.fov,77.0,1.0-exp(-delta*10.0))
        var distance: float=_collision_safe_camera_distance(6.0,.20)
        _camera.position.x=.20
        _camera.position.z=clampf(distance,.18,6.0)
    # A source driving animation is still needed before a seated operator
    # can be rendered faithfully. Do not pose Lila as a standing gunner.


func vehicle_ride_active() -> bool:
    return _vehicle_ride!=null and is_instance_valid(_vehicle_ride)


func force_vehicle_exit(at: Vector3=Vector3(INF,INF,INF)) -> void:
    if _vehicle_ride==null:
        return
    var old: AuroraDriveableVehicle=_vehicle_ride
    _vehicle_ride=null
    collision_mask=_vehicle_saved_collision_mask
    if is_instance_valid(old):
        remove_collision_exception_with(old)
        old.remove_collision_exception_with(self)
        old.leave()
    if at.is_finite():
        global_position=at
    velocity=Vector3.ZERO
    _sprint_touch=false
    if _avatar:
        _avatar.show()
    _current_clip=""
    _play_matching_animation("AuroraArmedIdle")


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
    if _vehicle_ride!=null and is_instance_valid(_vehicle_ride):
        query.exclude.append(_vehicle_ride.get_rid())
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
    var limited: Vector2 = delta.limit_length(CAMERA_MAX_SWIPE_PIXELS)
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
    _desired_yaw = wrapf(_desired_yaw-limited.x*touch_scale,-PI,PI)
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
    return air_mode=="ground" and not royale_eliminated and not round_finished and (
        _vehicle_ride==null)


func reset_controls() -> void:
    _move_axis=Vector2.ZERO
    _look_touch=-1
    _sprint_touch=false
    _jump_requested=false
    _jump_buffer_seconds=0.0
    _coyote_seconds=0.0
    measured_ground_speed=0.0
    _fire_held=false
    _ads_active=false
    _recoil_pitch=0.0
    _combat_action=""
    _combat_action_seconds=0.0
    last_hit_reaction=""
    hit_reactions_shown=0
    if _animation_controller:
        _animation_controller.cancel_action()


func _notification(what: int) -> void:
    if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
        reset_controls()
