extends Control
## Fullscreen touch/mouse edit layer; prevents underlying fire/joystick events.
## The live game is paused while the editor is visible. This Control and its
## toolbar continue processing through their parent CanvasLayer.
var hud: CanvasLayer
var selected: String=""
var _finger: int=-1
var _mouse_down: bool=false
var _drag_offset: Vector2=Vector2.ZERO


func _ready() -> void:
    name="HudEditorSurface"
    mouse_filter=Control.MOUSE_FILTER_STOP
    focus_mode=Control.FOCUS_NONE


func _draw() -> void:
    if hud==null or not is_instance_valid(hud):
        return
    for id in hud.HUD_LAYOUT.IDS:
        var target: Control=hud.hud_editor_target(id)
        if target==null or not target.visible:
            continue
        var rect: Rect2=target.get_global_rect()
        var local: Rect2=Rect2(rect.position-global_position,rect.size)
        draw_rect(local.grow(3.0),
            Color(.96,.79,.30,.96) if id==selected else Color(.37,.82,.98,.70),
            false,3.0 if id==selected else 1.5)


func _pick(at: Vector2) -> String:
    if hud==null:
        return ""
    var ids: Array[String]=hud.HUD_LAYOUT.IDS.duplicate()
    ids.reverse()
    for id in ids:
        var target: Control=hud.hud_editor_target(id)
        if target!=null and target.visible and target.get_global_rect().grow(7.0).has_point(at):
            return id
    return ""


func _begin(at: Vector2) -> void:
    selected=_pick(at)
    if hud!=null:
        hud.hud_editor_selected(selected)
    if selected!="":
        var target: Control=hud.hud_editor_target(selected)
        _drag_offset=target.get_global_rect().get_center()-at
    queue_redraw()


func _move(at: Vector2) -> void:
    if selected=="" or hud==null:
        return
    hud.hud_editor_move(selected,at+_drag_offset)
    queue_redraw()


func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch:=event as InputEventScreenTouch
        if touch.pressed and not touch.canceled and _finger<0:
            _finger=touch.index
            _begin(touch.position+global_position)
            accept_event()
        elif (not touch.pressed or touch.canceled) and touch.index==_finger:
            _finger=-1
            accept_event()
    elif event is InputEventScreenDrag:
        var drag:=event as InputEventScreenDrag
        if drag.index==_finger:
            _move(drag.position+global_position)
            accept_event()
    elif event is InputEventMouseButton:
        var mouse:=event as InputEventMouseButton
        if mouse.button_index==MOUSE_BUTTON_LEFT:
            _mouse_down=mouse.pressed
            if mouse.pressed:
                _begin(mouse.position+global_position)
            accept_event()
    elif event is InputEventMouseMotion and _mouse_down:
        _move((event as InputEventMouseMotion).position+global_position)
        accept_event()


func reset_pointer() -> void:
    _finger=-1
    _mouse_down=false
    selected=""
    queue_redraw()
