extends Control
## Original shoot-and-drag control for mobile TPS.
## The finger owning the fire control aims while firing; separate from free
## right-side look and independent left-side movement.
signal pressed
signal released
signal look_dragged(relative: Vector2)

const RADIUS: float = 64.0
var _finger: int = -1
var _mouse: bool = false
var _last_point: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO


func _ready() -> void:
    name = "DirectionalFirePad"
    mouse_filter = Control.MOUSE_FILTER_STOP
    focus_mode = Control.FOCUS_NONE
    queue_redraw()


func _draw() -> void:
    var center: Vector2 = size * 0.5
    var glow: Color = Color(.90, .35, .20, .30 if _finger < 0 and not _mouse else .57)
    draw_circle(center, RADIUS, Color(.20,.05,.045,.45))
    draw_circle(center, RADIUS - 8.0, glow)
    draw_arc(center, RADIUS, 0, TAU, 60, Color(1,.83,.76,.94), 3.0, true)
    var at: Vector2 = center + _knob
    draw_circle(at, 29.0, Color(1.0,.79,.70,.77))
    draw_line(at + Vector2(-14,0), at + Vector2(14,0), Color(.20,.08,.06), 2.5)
    draw_line(at + Vector2(0,-14), at + Vector2(0,14), Color(.20,.08,.06), 2.5)
    draw_circle(at, 4.0, Color(.20,.08,.06))
    if _finger >= 0 or _mouse:
        draw_arc(at, 38, .1, TAU-.1, 36, Color(1,.97,.83,.9), 2.0)


func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed and not touch.canceled and _finger == -1:
            _finger = touch.index
            _last_point = touch.position
            _knob = Vector2.ZERO
            pressed.emit()
            accept_event()
            queue_redraw()
        elif (not touch.pressed or touch.canceled) and touch.index == _finger:
            _finger = -1
            _knob = Vector2.ZERO
            released.emit()
            accept_event()
            queue_redraw()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == _finger:
            var diff: Vector2 = drag.position - _last_point
            _last_point = drag.position
            _knob = (drag.position - size * .5).limit_length(24.0)
            if diff.length_squared() > .01:
                look_dragged.emit(diff)
            accept_event()
            queue_redraw()
    elif event is InputEventMouseButton:
        var mouse := event as InputEventMouseButton
        if mouse.button_index == MOUSE_BUTTON_LEFT:
            if mouse.pressed and not _mouse:
                _mouse = true
                _last_point = mouse.position
                _knob = Vector2.ZERO
                pressed.emit()
            elif not mouse.pressed and _mouse:
                _mouse = false
                _knob = Vector2.ZERO
                released.emit()
            accept_event()
            queue_redraw()
    elif event is InputEventMouseMotion and _mouse:
        var motion := event as InputEventMouseMotion
        var delta: Vector2 = motion.position - _last_point
        _last_point = motion.position
        _knob = (motion.position - size * .5).limit_length(24.0)
        if delta.length_squared() > .01:
            look_dragged.emit(delta)
        accept_event()
        queue_redraw()


func get_fire_held() -> bool:
    return _finger >= 0 or _mouse


func reset() -> void:
    _finger=-1
    _mouse=false
    _knob=Vector2.ZERO
    released.emit()
    queue_redraw()

func _notification(what: int) -> void:
    if what==NOTIFICATION_APPLICATION_FOCUS_OUT or (what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
        reset()
