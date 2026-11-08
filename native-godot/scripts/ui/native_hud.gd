extends CanvasLayer
## Transparent native touch HUD for the first Aurora training slice.
## Every button emits a real gameplay action; no decorative fake multiplayer.
signal fire_pressed
signal fire_released
signal fire_aim_changed(relative: Vector2)
signal crouch_pressed
signal aim_pressed
signal reload_pressed
signal weapon_pressed
signal run_pressed
signal run_released
signal jump_pressed
signal movement_axis_changed(value: Vector2)
const VIRTUAL_PAD = preload("res://scripts/ui/virtual_joystick.gd")
const DIRECTIONAL_FIRE = preload("res://scripts/ui/directional_fire_pad.gd")
const TACTICAL_RETICLE = preload("res://scripts/ui/scope_reticle.gd")

var _weapon: Label
var _ammo: Label
var _status: Label
var _fps: Label
var _hit: Label
var _health_label: Label
var _hint: Label
var _hit_timer: float = 0.0
var _fps_clock: float = 0.0
var _ads: bool = false
var _run_latched: bool = false
var _run_button: Button
var _crouch_button: Button
var _aim_button: Button
var _crouching: bool = false
var _reticle: Control


func _ready() -> void:
    var root := Control.new()
    root.name = "AuroraTacticalOverlay"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    var header := PanelContainer.new()
    header.name = "AuroraHeader"
    header.anchor_left = .01
    header.anchor_right = .46
    header.anchor_top = .025
    header.anchor_bottom = .025
    header.offset_top = 0
    header.offset_bottom = 54
    header.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var header_box := StyleBoxFlat.new()
    header_box.bg_color = Color(.025,.09,.14,.84)
    header_box.border_width_bottom = 2
    header_box.border_color = Color(.28,.78,.78)
    header.add_theme_stylebox_override("panel",header_box)
    root.add_child(header)

    _status = Label.new()
    _status.text = "THEDEMIANFF / AURORA     ENTRENAMIENTO NATIVO"
    _status.add_theme_font_size_override("font_size",15)
    _status.add_theme_color_override("font_color",Color(.83,.95,.98))
    _status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    header.add_child(_status)

    _weapon = _text(root, "AR-7  /  ASALTO",.76,.085,21,Color(.90,.96,1),HORIZONTAL_ALIGNMENT_RIGHT)
    _ammo = _text(root, "30 / 180",.79,.137,22,Color(1,.79,.49),HORIZONTAL_ALIGNMENT_RIGHT)
    _fps = _text(root,"FPS —",.865,.028,13,Color(.67,.94,.81),HORIZONTAL_ALIGNMENT_RIGHT)
    _health_label = _text(root,"SALUD 100 / 100",.018,.095,16,Color(.71,.98,.82),HORIZONTAL_ALIGNMENT_LEFT)

    _reticle = TACTICAL_RETICLE.new()
    _reticle.name = "AimReticle"
    _reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _reticle.mouse_filter=Control.MOUSE_FILTER_IGNORE
    root.add_child(_reticle)
    _hint = _text(root,"ARRASTRA PARA GIRAR  ·  IZQUIERDA PARA MOVER",.23,.94,12,Color(.68,.86,.90),HORIZONTAL_ALIGNMENT_CENTER)
    _hit = _text(root,"",.36,.375,21,Color(1,.80,.41),HORIZONTAL_ALIGNMENT_CENTER)

    var fire_pad: Control = DIRECTIONAL_FIRE.new()
    fire_pad.name="DirectionalFirePad"
    fire_pad.anchor_left=.905
    fire_pad.anchor_right=.905
    fire_pad.anchor_top=.70
    fire_pad.anchor_bottom=.70
    fire_pad.offset_left=-86
    fire_pad.offset_right=86
    fire_pad.offset_top=-86
    fire_pad.offset_bottom=86
    root.add_child(fire_pad)
    fire_pad.pressed.connect(_fire_down)
    fire_pad.released.connect(_fire_up)
    fire_pad.look_dragged.connect(func(delta: Vector2): fire_aim_changed.emit(delta))
    _aim_button=_button(root,"MIRA",.778,.66,74,62,Color(.12,.39,.49),_aim_down)
    _button(root,"RECARGA",.790,.80,81,59,Color(.14,.30,.37),_reload_down)
    _button(root,"ARMA",.905,.87,79,59,Color(.19,.35,.41),_weapon_down)
    _run_button=_button(root,"CORRER",.11,.61,82,57,Color(.09,.30,.36),_run_down,_run_up)
    _button(root,"SALTAR",.685,.82,76,54,Color(.12,.34,.41),_jump_down)
    _crouch_button=_button(root,"AGACHAR",.68,.70,80,53,Color(.16,.30,.36),_crouch_down)
    var pad: Control=VIRTUAL_PAD.new()
    pad.name="MovePad"
    pad.anchor_left=.05
    pad.anchor_right=.05
    pad.anchor_top=.66
    pad.anchor_bottom=.66
    pad.offset_left=0
    pad.offset_right=245
    pad.offset_top=0
    pad.offset_bottom=215
    root.add_child(pad)
    pad.connect("vector_changed",func(axis: Vector2): movement_axis_changed.emit(axis))


func _text(parent: Control,value: String,x: float,y: float,size: int,color: Color,align: HorizontalAlignment) -> Label:
    var l := Label.new()
    l.text=value
    l.anchor_left=x
    l.anchor_right=x+.18
    l.anchor_top=y
    l.anchor_bottom=y
    l.offset_right=10
    l.offset_bottom=50
    l.horizontal_alignment=align
    l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    l.add_theme_font_size_override("font_size",size)
    l.add_theme_color_override("font_color",color)
    l.add_theme_color_override("font_shadow_color",Color.BLACK)
    l.add_theme_constant_override("shadow_offset_x",1)
    l.add_theme_constant_override("shadow_offset_y",2)
    l.mouse_filter=Control.MOUSE_FILTER_IGNORE
    parent.add_child(l)
    return l


func _button(root: Control,label: String,x: float,y: float,w: float,h: float,color: Color,down: Callable,up: Callable=Callable()) -> Button:
    var button := Button.new()
    button.name=label
    button.text=label
    button.anchor_left=x
    button.anchor_right=x
    button.anchor_top=y
    button.anchor_bottom=y
    button.offset_left=-w*.5
    button.offset_right=w*.5
    button.offset_top=-h*.5
    button.offset_bottom=h*.5
    button.focus_mode=Control.FOCUS_NONE
    button.add_theme_font_size_override("font_size",15)
    var normal:=StyleBoxFlat.new()
    normal.bg_color=Color(color.r,color.g,color.b,.82)
    normal.border_color=Color(.74,.89,.94,.86)
    normal.set_border_width_all(2)
    normal.set_corner_radius_all(int(minf(w,h)*.27))
    var pressed:=normal.duplicate() as StyleBoxFlat
    pressed.bg_color=color.lightened(.19)
    button.add_theme_stylebox_override("normal",normal)
    button.add_theme_stylebox_override("hover",normal)
    button.add_theme_stylebox_override("pressed",pressed)
    button.button_down.connect(down)
    if up.is_valid():
        button.button_up.connect(up)
    root.add_child(button)
    return button


func _fire_down() -> void:
    fire_pressed.emit()


func _fire_up() -> void:
    fire_released.emit()


func _aim_down() -> void:
    aim_pressed.emit()


func _reload_down() -> void:
    reload_pressed.emit()


func _weapon_down() -> void:
    weapon_pressed.emit()


func _run_down() -> void:
    # Tap-to-toggle sprint: a player can run using one left-side finger.
    _run_latched = not _run_latched
    if _run_latched:
        run_pressed.emit()
    else:
        run_released.emit()
    if _run_button:
        _run_button.text = "CORRIENDO" if _run_latched else "CORRER"


func _run_up() -> void:
    pass  # Releasing the sprint button must not deactivate sprint.


func _jump_down() -> void:
    jump_pressed.emit()


func _crouch_down() -> void:
    _crouching = not _crouching
    crouch_pressed.emit()
    if _crouch_button:
        _crouch_button.text="LEVANTAR" if _crouching else "AGACHAR"


func set_health(value: float) -> void:
    if _health_label:
        _health_label.text="SALUD "+str(roundi(value))+" / 100"
        _health_label.add_theme_color_override("font_color",Color(.98,.45,.38) if value<30.0 else Color(.71,.98,.82))


func set_weapon(name: String,loaded: int,reserve: int) -> void:
    if _weapon:
        _weapon.text=name
    if _ammo:
        _ammo.text=str(loaded)+" / "+str(reserve)


func set_aim(active: bool,scope: String,zoom: float=1.0) -> void:
    _ads=active
    if _reticle:
        _reticle.set_zoom(zoom if active else 1.0)
    if _aim_button:
        _aim_button.text = ("8X" if zoom >= 6.0 else "4X" if zoom >= 3.8 else "2X") if active else "MIRA"
    if _hint:
        _hint.text=scope+"  ·  FUEGO Y ARRASTRA PARA PRECISION" if active else "CÁMARA LIBRE  ·  ARRASTRA FUEGO PARA APUNTAR"


func impact(message: String) -> void:
    if _hit:
        _hit.text=message
        _hit_timer=.9


func _process(delta: float) -> void:
    _fps_clock-=delta
    if _fps_clock<=0:
        _fps_clock=.6
        if _fps:
            _fps.text=str(Engine.get_frames_per_second())+" FPS"
    if _hit_timer>0:
        _hit_timer=maxf(0,_hit_timer-delta)
        if _hit_timer==0 and _hit:
            _hit.text=""
