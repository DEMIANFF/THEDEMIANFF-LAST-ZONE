extends CanvasLayer
## Transparent native touch HUD for the first Aurora training slice.
## Every button emits a real gameplay action; no decorative fake multiplayer.
signal fire_pressed
signal fire_released
signal fire_aim_changed(relative: Vector2)
signal crouch_pressed
signal heal_pressed
signal aurora_cover_pressed
signal aim_pressed
signal reload_pressed
signal weapon_pressed
signal run_pressed
signal run_released
signal jump_pressed
signal movement_axis_changed(value: Vector2)
signal start_battle_requested
signal leave_to_lobby_requested
const SAFE_SCREEN=preload("res://scripts/ui/safe_screen.gd")
const VIRTUAL_PAD = preload("res://scripts/ui/virtual_joystick.gd")
const DIRECTIONAL_FIRE = preload("res://scripts/ui/directional_fire_pad.gd")
const TACTICAL_RETICLE = preload("res://scripts/ui/scope_reticle.gd")
const TRAINING_RADAR = preload("res://scripts/ui/aurora_training_radar.gd")

var _weapon: Label
var _ammo: Label
var _status: Label
var _fps: Label
var _compass: Label
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
var _medkit_button: Button
var _cover_button: Button
var _cover_charges: int=0
var _cover_cooldown: float=0.0
var _training_radar: Control
var _crouching: bool = false
var _reticle: Control
var _battle_button: Button
var _battle_status: Label
var _eliminations_label: Label
var _health_meter: ProgressBar
var _damage_flash: ColorRect
var _result_window: PanelContainer
var _result_text: Label
var _jump_button: Button
var _exit_button: Button
var air_stage: String="ground"


func _ready() -> void:
    var root := Control.new()
    root.name = "AuroraTacticalOverlay"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    _damage_flash=ColorRect.new()
    _damage_flash.name="DamageFlash"
    _damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _damage_flash.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _damage_flash.color=Color(.80,.12,.10,0.0)
    root.add_child(_damage_flash)

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
    header_box.border_color = Color(.37,.72,.98)
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
    _compass=_text(root,"N 000°",.45,.025,18,Color(.87,.97,1),HORIZONTAL_ALIGNMENT_CENTER)
    _compass.name="CameraHeading"
    _eliminations_label=_text(root,"BAJAS 0",.72,.027,16,Color(.99,.63,.55),HORIZONTAL_ALIGNMENT_LEFT)
    _health_label = _text(root,"SALUD 100 / 100",.018,.095,16,Color(.71,.98,.82),HORIZONTAL_ALIGNMENT_LEFT)
    _health_meter=ProgressBar.new()
    _health_meter.name="PlayerHealthMeter"
    _health_meter.anchor_left=.02
    _health_meter.anchor_right=.02
    _health_meter.anchor_top=.152
    _health_meter.anchor_bottom=.152
    _health_meter.offset_left=0
    _health_meter.offset_right=180
    _health_meter.offset_top=0
    _health_meter.offset_bottom=12
    _health_meter.show_percentage=false
    _health_meter.value=100
    _health_meter.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var health_bg:=StyleBoxFlat.new()
    health_bg.bg_color=Color(.07,.12,.14,.91)
    var health_fill:=StyleBoxFlat.new()
    health_fill.bg_color=Color(.27,.78,.58,.93)
    _health_meter.add_theme_stylebox_override("background",health_bg)
    _health_meter.add_theme_stylebox_override("fill",health_fill)
    root.add_child(_health_meter)
    _battle_button=_button(root,"INICIAR BR",.63,.035,139,52,Color(.25,.39,.49),_battle_down)
    _battle_status=_text(root,"ENTRENAMIENTO",.46,.125,15,Color(.98,.85,.61),HORIZONTAL_ALIGNMENT_CENTER)

    _training_radar=TRAINING_RADAR.new()
    _training_radar.anchor_left=.017
    _training_radar.anchor_right=.017
    _training_radar.anchor_top=.175
    _training_radar.anchor_bottom=.175
    _training_radar.offset_left=0
    _training_radar.offset_right=178
    _training_radar.offset_top=0
    _training_radar.offset_bottom=162
    root.add_child(_training_radar)

    _result_window=PanelContainer.new()
    _result_window.name="SectorMatchResult"
    _result_window.anchor_left=.32
    _result_window.anchor_right=.68
    _result_window.anchor_top=.30
    _result_window.anchor_bottom=.63
    _result_window.visible=false
    _result_window.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var end_bg:=StyleBoxFlat.new()
    end_bg.bg_color=Color(.035,.095,.17,.91)
    end_bg.border_color=Color(.51,.88,.97)
    end_bg.set_border_width_all(2)
    end_bg.set_corner_radius_all(15)
    _result_window.add_theme_stylebox_override("panel",end_bg)
    root.add_child(_result_window)
    _result_text=Label.new()
    _result_text.name="MatchResultsText"
    _result_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    _result_text.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    _result_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _result_text.add_theme_font_size_override("font_size",23)
    _result_text.add_theme_color_override("font_color",Color(.91,.98,1.0))
    _result_window.add_child(_result_text)

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
    _jump_button=_button(root,"SALTAR",.685,.82,76,54,Color(.12,.34,.41),_jump_down)
    _crouch_button=_button(root,"AGACHAR",.68,.70,80,53,Color(.16,.30,.36),_crouch_down)
    _medkit_button=_button(root,"CURAR 2",.575,.855,84,56,Color(.20,.36,.29),_heal_down)
    _cover_button=_button(root,"BARRERA 0",.52,.68,96,55,Color(.13,.53,.68),_cover_down)
    _cover_button.visible=false
    _cover_button.disabled=true
    _exit_button=_button(root,"LOBBY",.936,.255,95,46,Color(.13,.27,.43),_return_lobby)
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
    get_viewport().size_changed.connect(_layout)
    _layout.call_deferred()


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
    normal.bg_color=Color(color.r*.78,color.g*.76,color.b*.80,.88)
    normal.border_color=Color(.37,.76,.94,.86)
    normal.set_border_width_all(2)
    normal.set_corner_radius_all(int(minf(w,h)*.35))
    normal.shadow_color=Color(0,0,0,.22)
    normal.shadow_size=3
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


func _return_lobby() -> void:
    leave_to_lobby_requested.emit()


func set_air_stage(value: String) -> void:
    reset_controls()
    air_stage=value
    var airborne: bool=value!="ground"
    var overlay: Control=get_node("AuroraTacticalOverlay") as Control
    # Combat UI is irrelevant while riding the aircraft or descending.
    for name in ["DirectionalFirePad","MIRA","RECARGA","ARMA","AGACHAR","CURAR 2","CORRER","BARRERA 0"]:
        var control: Control=overlay.get_node_or_null(name) as Control
        if control:
            control.visible=not airborne
    var pad: Control=overlay.get_node_or_null("MovePad") as Control
    if pad:
        pad.visible=value!="aircraft"
    if _reticle:
        _reticle.visible=not airborne
    for indicator in [_weapon,_ammo,_eliminations_label,_health_label,_health_meter,_training_radar]:
        if indicator:
            indicator.visible=not airborne
    if _jump_button:
        _jump_button.text="SALTAR DEL AVIÓN" if value=="aircraft" else "PARACAÍDAS" if value=="freefall" else "SALTAR"
        _jump_button.custom_minimum_size=Vector2(140,58) if airborne else Vector2.ZERO
        _jump_button.visible=value!="parachute"
        _jump_button.disabled=value=="parachute"
    if _battle_button:
        _battle_button.disabled=airborne or _battle_button.text=="EN PARTIDA"
    if _status and airborne:
        _status.text="AURORA / "+("RUTA AÉREA" if value=="aircraft" else "CAÍDA LIBRE" if value=="freefall" else "ATERRIZAJE")
    _layout()
    if _hint and airborne:
        _hint.text="CONTROLA LA CÁMARA" if value=="aircraft" else "JOYSTICK PARA DIRIGIR"


func _battle_down() -> void:
    start_battle_requested.emit()


func set_eliminations(kills: int) -> void:
    if _eliminations_label:
        _eliminations_label.text="BAJAS "+str(kills)


func show_damage_feedback(amount: float) -> void:
    if _damage_flash:
        _damage_flash.color.a=clampf(amount/80.0,.12,.25)


func clear_match_result() -> void:
    if _result_window:
        _result_window.visible=false


func show_match_result(victory: bool,kills: int,seconds_alive: int) -> void:
    if not _result_window or not _result_text:
        return
    var summary: String="VICTORIA AURORA" if victory else "ELIMINADA"
    var minutes: String=str(int(seconds_alive/60)).pad_zeros(2)
    var seconds: String=str(seconds_alive%60).pad_zeros(2)
    _result_text.text=summary+"\nBAJAS: "+str(kills)+"  |  TIEMPO: "+minutes+":"+seconds+"\nPULSA REINICIAR BR"
    _result_window.visible=true


func set_sector_zone(center: Vector2,radius: float) -> void:
    if _training_radar:
        _training_radar.call("set_zone",center,radius)


func set_battle_button(label: String) -> void:
    if _battle_button:
        _battle_button.text=label
        _battle_button.disabled=label=="EN PARTIDA"
        _battle_button.visible=label in ["INICIAR BR","REINICIAR BR"]


func set_sector_state(status: String, alive: int, safe_radius: float, elapsed_seconds: int) -> void:
    if _battle_status:
        _battle_status.text=status+"  |  "+str(alive)+" VIVOS  |  "+str(roundi(safe_radius))+"m  |  "+str(int(elapsed_seconds/60)).pad_zeros(2)+":"+str(elapsed_seconds%60).pad_zeros(2)
    if _status:
        _status.text="THEDEMIANFF / AURORA     "+status


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


func _heal_down() -> void:
    heal_pressed.emit()


func _cover_down() -> void:
    aurora_cover_pressed.emit()


func set_aurora_cover_count(charges: int,cooldown: float=0.0) -> void:
    _cover_charges=maxi(0,charges)
    _cover_cooldown=maxf(0.0,cooldown)
    if _cover_button:
        _cover_button.text="BARRERA %d"%_cover_charges
        _cover_button.disabled=_cover_charges<=0 or _cover_cooldown>0.0 or air_stage!="ground"


func set_medkit_count(count: int) -> void:
    if _medkit_button:
        _medkit_button.text="CURAR "+str(count)


func set_training_radar_sources(character: CharacterBody3D, enemies: Array[CharacterBody3D]) -> void:
    if _training_radar:
        _training_radar.call("set_sources",character,enemies)


func _crouch_down() -> void:
    # Actual CharacterBody clearance decides whether standing is allowed.
    crouch_pressed.emit()


func set_crouch_state(active: bool) -> void:
    _crouching=active
    if _crouch_button:
        _crouch_button.text="LEVANTAR" if active else "AGACHAR"


func set_health(value: float) -> void:
    if _health_meter:
        _health_meter.value=clampf(value,0.0,100.0)
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
    if _damage_flash and _damage_flash.color.a>0:
        _damage_flash.color.a=maxf(0.0,_damage_flash.color.a-delta*.38)
    _fps_clock-=delta
    if _fps_clock<=0:
        _fps_clock=.6
        if _fps:
            _fps.text=str(Engine.get_frames_per_second())+" FPS"
        _refresh_heading()
    if _hit_timer>0:
        _hit_timer=maxf(0,_hit_timer-delta)
        if _hit_timer==0 and _hit:
            _hit.text=""

func _refresh_heading() -> void:
    if _compass==null or _training_radar==null:
        return
    var actor: CharacterBody3D=_training_radar.get("player") as CharacterBody3D
    if actor==null or not is_instance_valid(actor):
        _compass.text="AURORA  •  N"
        return
    # Third-person yaw is clockwise from the world -Z heading.
    var degrees: int=posmod(int(round(rad_to_deg(float(actor.get("_yaw"))))),360)
    var names: Array[String]=["N","NE","E","SE","S","SO","O","NO"]
    var quadrant: int=int(round(float(degrees)/45.0))%8
    _compass.text=names[quadrant]+"  %03d°"%degrees


func _place(control: Control, rect: Rect2) -> void:
    control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    control.position=rect.position
    control.size=rect.size


func _layout() -> void:
    var root: Control=get_node("AuroraTacticalOverlay")
    var safe: Rect2=SAFE_SCREEN.rect(get_viewport())
    var origin: Vector2=safe.position
    var w: float=safe.size.x
    var h: float=safe.size.y
    root.get_node("AuroraHeader").visible=false
    _place(_training_radar,Rect2(origin+Vector2(24,62),Vector2(156,142)))
    _place(_health_label,Rect2(origin+Vector2(w*.5-85,h-91),Vector2(170,28)))
    _health_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    _place(_health_meter,Rect2(origin+Vector2(w*.5-85,h-61),Vector2(170,12)))
    _place(_weapon,Rect2(origin+Vector2(w-260,16),Vector2(230,30)))
    _place(_ammo,Rect2(origin+Vector2(w-210,48),Vector2(180,32)))
    _place(_fps,Rect2(origin+Vector2(24,211),Vector2(96,24)))
    _place(_eliminations_label,Rect2(origin+Vector2(w-360,24),Vector2(90,24)))
    _place(_compass,Rect2(origin+Vector2(w*.5-75,6),Vector2(150,28)))
    _place(_battle_status,Rect2(origin+Vector2(w*.5-220,37),Vector2(440,30)))
    _place(_battle_button,Rect2(origin+Vector2(w*.5-90,64),Vector2(180,46)))
    _place(_exit_button,Rect2(origin+Vector2(w-118,112),Vector2(92,44)))
    _place(_hint,Rect2(origin+Vector2(w*.5-210,h-32),Vector2(420,24)))
    _hint.add_theme_font_size_override("font_size",11)
    _place(_hit,Rect2(origin+Vector2(w*.5-300,128),Vector2(600,50)))
    _hit.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _place(root.get_node("MovePad"),Rect2(origin+Vector2(40,h-235),Vector2(210,210)))
    _place(_run_button,Rect2(origin+Vector2(90,h-294),Vector2(110,52)))
    _place(root.get_node("DirectionalFirePad"),Rect2(origin+Vector2(w-172,h-257),Vector2(144,144)))
    _place(_aim_button,Rect2(origin+Vector2(w-300,h-260),Vector2(82,60)))
    _place(root.get_node("RECARGA"),Rect2(origin+Vector2(w-310,h-175),Vector2(86,58)))
    _place(root.get_node("ARMA"),Rect2(origin+Vector2(w-235,h-107),Vector2(86,58)))
    _place(_crouch_button,Rect2(origin+Vector2(w-422,h-180),Vector2(92,56)))
    _place(_medkit_button,Rect2(origin+Vector2(w-422,h-107),Vector2(92,56)))
    _place(_cover_button,Rect2(origin+Vector2(w-422,h-259),Vector2(92,56)))
    _jump_button.custom_minimum_size=Vector2.ZERO
    var jump_rect:=Rect2(origin+Vector2(w-135,h-107),Vector2(100,58))
    if air_stage!="ground":
        jump_rect=Rect2(origin+Vector2(w-220,h-118),Vector2(190,64))
    _place(_jump_button,jump_rect)


func is_action_at(point: Vector2) -> bool:
    var root: Control=get_node("AuroraTacticalOverlay")
    for control in root.get_children():
        if control is Control and control.is_visible_in_tree() and control.mouse_filter!=Control.MOUSE_FILTER_IGNORE and control.get_global_rect().has_point(point):
            return true
    return false


func reset_controls() -> void:
    var root: Control=get_node("AuroraTacticalOverlay")
    root.get_node("MovePad").reset()
    root.get_node("DirectionalFirePad").reset()
    _run_latched=false
    _run_button.text="CORRER"
    run_released.emit()


func set_match_controls(enabled: bool) -> void:
    var root: Control=get_node("AuroraTacticalOverlay")
    for control in root.get_children():
        if control is Button and control!=_battle_button and control!=_exit_button:
            control.disabled=not enabled
    root.get_node("MovePad").visible=enabled
    root.get_node("DirectionalFirePad").visible=enabled
    _cover_button.visible=enabled and air_stage=="ground"
    _cover_button.disabled=not enabled or _cover_charges<=0 or _cover_cooldown>0.0


func _notification(what: int) -> void:
    if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
        reset_controls()
