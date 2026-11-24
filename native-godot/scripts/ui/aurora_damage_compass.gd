extends Control
## Short-lived 360-degree hit bearing, from a real incoming-fire 3D point.
## Does NOT reveal silent bots, predict positions or add map wallhacks.
const DISPLAY_SECONDS: float=1.15
var _direction: Vector2=Vector2.UP
var _remaining: float=0.0


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter=Control.MOUSE_FILTER_IGNORE


func register_real_hit(local_direction: Vector2) -> void:
    if not local_direction.is_finite() or (
            local_direction.length_squared()<.0001):
        return
    _direction=local_direction.normalized()
    _remaining=DISPLAY_SECONDS
    visible=true
    queue_redraw()


func _process(delta: float) -> void:
    if _remaining<=0.0:
        if visible:
            visible=false
        return
    _remaining=maxf(0.0,_remaining-maxf(delta,0.0))
    queue_redraw()


func _draw() -> void:
    if _remaining<=0.0:
        return
    var center: Vector2=size*.5
    if not center.is_finite() or center.x<=0.0 or center.y<=0.0:
        return
    var alpha: float=clampf(_remaining/DISPLAY_SECONDS,0.0,1.0)
    var heading: float=_direction.angle()
    var radius: float=minf(91.0,minf(size.x,size.y)*.24)
    # 18° of urgent direction is readable without obscuring the crosshair
    # or replacing the minimap with a fictional enemy location.
    draw_arc(center,radius,heading-.16,heading+.16,13,
        Color(1.0,.24,.18,alpha*.92),7.0,true)
    draw_arc(center,radius-10.0,heading-.11,heading+.11,11,
        Color(1.0,.74,.40,alpha*.7),2.3,true)
