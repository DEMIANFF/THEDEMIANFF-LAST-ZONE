extends Node
## Throttle bone evaluation, never the physics, damage or reload clocks.
## Stagger the first evaluation deadline, not the animation's elapsed time.
var animator: AnimationPlayer
var actor: Node3D
var observer: Node3D
var elapsed: float=0.0
var updates: int=0
var last_interval: float=0.0
var advanced_seconds: float=0.0
var _phase: float=1.0
var _first_evaluation: bool=true

func configure(source: AnimationPlayer,enemy: Node3D,player: Node3D) -> void:
    animator=source
    actor=enemy
    observer=player
    animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    _phase=float(enemy.get_instance_id()%7+1)/7.0
    elapsed=0.0
    _first_evaluation=true
    advanced_seconds=0.0
    updates=0

static func interval_for(distance_m: float,on_screen: bool, camera_fov: float=74.0) -> float:
    if not on_screen:
        return 1.0/10.0
    # Perspective zoom increases apparent size. Never lower the update
    # frequency for a character because the player zoomed in.
    var effective_distance: float=distance_m
    if is_finite(camera_fov) and camera_fov>0.0:
        effective_distance*=minf(1.0,tan(deg_to_rad(clampf(camera_fov,9.0,74.0)*.5))/tan(deg_to_rad(37.0)))
    if effective_distance<=18.0:
        return 0.0
    if effective_distance<=35.0:
        return 1.0/30.0
    return 1.0/15.0

static func body_in_view(camera: Camera3D, position: Vector3) -> bool:
    if camera==null:
        return true
    # Include the upper and lower body at screen edges. A single midpoint
    # can be out of view while the head or legs remain on screen.
    for height in [.25,1.0,1.65]:
        if camera.is_position_in_frustum(position+Vector3.UP*float(height)):
            return true
    return false

func _process(delta: float) -> void:
    if not is_instance_valid(animator) or not animator.active or not animator.is_playing():
        elapsed=0.0
        _first_evaluation=true
        return
    if not is_instance_valid(actor) or not is_instance_valid(observer) or not actor.is_visible_in_tree():
        elapsed=0.0
        _first_evaluation=true
        return
    if not is_finite(delta) or delta<0.0:
        return
    var camera: Camera3D=get_viewport().get_camera_3d()
    var fov: float=camera.fov if camera!=null and camera.projection==Camera3D.PROJECTION_PERSPECTIVE else 74.0
    last_interval=interval_for(actor.global_position.distance_to(observer.global_position),body_in_view(camera,actor.global_position),fov)
    elapsed+=delta
    var deadline: float=last_interval*_phase if _first_evaluation else last_interval
    if elapsed+.00001<deadline:
        return
    animator.advance(elapsed)
    advanced_seconds+=elapsed
    elapsed=0.0
    _first_evaluation=false
    updates+=1
