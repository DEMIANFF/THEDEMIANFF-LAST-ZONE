extends Node
## Throttle only bone evaluation. The original mesh, AI, hitboxes, reload
## timers and damage remain unchanged. Each step advances ALL elapsed time.
var animator: AnimationPlayer
var actor: Node3D
var observer: Node3D
var elapsed: float=0.0
var updates: int=0
var last_interval: float=0.0

func configure(source: AnimationPlayer,enemy: Node3D,player: Node3D) -> void:
    animator=source
    actor=enemy
    observer=player
    animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    # Spread evaluation across frames instead of updating all fourteen
    # leased rigs on the same render frame.
    elapsed=float(enemy.get_instance_id()%7)/210.0

static func interval_for(distance_m: float,on_screen: bool) -> float:
    if not on_screen:
        return 1.0/10.0
    if distance_m<=18.0:
        return 0.0
    if distance_m<=35.0:
        return 1.0/30.0
    return 1.0/15.0

func _process(delta: float) -> void:
    if not is_instance_valid(animator) or not animator.active or not animator.is_playing():
        elapsed=0.0
        return
    if not is_instance_valid(observer) or not actor.is_visible_in_tree():
        elapsed=0.0
        return
    var camera: Camera3D=get_viewport().get_camera_3d()
    var on_screen: bool=camera==null or camera.is_position_in_frustum(actor.global_position+Vector3.UP)
    last_interval=interval_for(actor.global_position.distance_to(observer.global_position),on_screen)
    elapsed+=delta
    if elapsed+.00001<last_interval:
        return
    animator.advance(elapsed)
    elapsed=0.0
    updates+=1
