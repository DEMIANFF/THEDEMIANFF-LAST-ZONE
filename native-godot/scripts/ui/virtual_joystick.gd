extends Control
## First-class multi-touch joystick: owns its own GUI finger independently of sprint/fire.
signal vector_changed(value: Vector2)

const RADIUS: float=68.0
var _finger: int=-1
var _mouse: bool=false
var _axis: Vector2=Vector2.ZERO
var _origin: Vector2=Vector2.ZERO

func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_STOP
    _origin=size*.5
    queue_redraw()

func _draw() -> void:
    var center: Vector2=_origin if _finger>=0 or _mouse else size*.5
    draw_circle(center,RADIUS,Color(.06,.22,.30,.35))
    draw_arc(center,RADIUS,0.0,TAU,48,Color(.7,.94,1,.85),2.0,true)
    var knob: Vector2=center+_axis*RADIUS*.67
    draw_circle(knob,29.0,Color(.15,.60,.72,.55))
    draw_arc(knob,29.0,0.0,TAU,40,Color(.90,.98,1,.90),2.0,true)

func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch:=event as InputEventScreenTouch
        if touch.pressed and not touch.canceled and _finger==-1:
            _finger=touch.index
            _origin=touch.position.clamp(Vector2.ONE*RADIUS,
                size-Vector2.ONE*RADIUS)
            _set_axis(touch.position)
            accept_event()
        elif (not touch.pressed or touch.canceled) and touch.index==_finger:
            _finger=-1
            _origin=size*.5
            _set_axis(_origin)
            accept_event()
    elif event is InputEventScreenDrag:
        var drag:=event as InputEventScreenDrag
        if drag.index==_finger:
            _set_axis(drag.position)
            accept_event()
    elif event is InputEventMouseButton:
        var mouse:=event as InputEventMouseButton
        if mouse.button_index==MOUSE_BUTTON_LEFT:
            _mouse=mouse.pressed
            _origin=mouse.position.clamp(Vector2.ONE*RADIUS,
                size-Vector2.ONE*RADIUS) if mouse.pressed else size*.5
            _set_axis(mouse.position if mouse.pressed else _origin)
            accept_event()
    elif event is InputEventMouseMotion and _mouse:
        _set_axis((event as InputEventMouseMotion).position)
        accept_event()

func _set_axis(point: Vector2) -> void:
    var v: Vector2=((point-_origin)/RADIUS).limit_length(1.0)
    _axis=v if v.length()>.11 else Vector2.ZERO
    vector_changed.emit(_axis)
    queue_redraw()


func reset() -> void:
    _finger=-1
    _mouse=false
    _origin=size*.5
    _set_axis(_origin)


func _input(event: InputEvent) -> void:
    # Android may deliver the end of a drag outside the joystick's rectangle.
    # Ensure the owned movement finger cannot remain stuck after release.
    if event is InputEventScreenTouch:
        var touch:=event as InputEventScreenTouch
        if touch.index==_finger and (not touch.pressed or touch.canceled):
            _finger=-1
            _origin=size*.5
            _set_axis(_origin)

func _notification(what: int) -> void:
    if what==NOTIFICATION_APPLICATION_FOCUS_OUT or (what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
        reset()
