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
signal settings_requested
signal hud_editor_closed
const SAFE_SCREEN=preload("res://scripts/ui/safe_screen.gd")
const VIRTUAL_PAD = preload("res://scripts/ui/virtual_joystick.gd")
const DIRECTIONAL_FIRE = preload("res://scripts/ui/directional_fire_pad.gd")
const TACTICAL_RETICLE = preload("res://scripts/ui/scope_reticle.gd")
const TRAINING_RADAR = preload("res://scripts/ui/aurora_training_radar.gd")
const TACTICAL_MAP=preload("res://scripts/ui/aurora_tactical_map.gd")
const HUD_LAYOUT=preload("res://scripts/persistence/hud_layout.gd")
const HUD_EDITOR=preload("res://scripts/ui/hud_edit_surface.gd")

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
var _heal_progress_bar: ProgressBar
var _heal_channel_active: bool=false
var _cover_button: Button
var _cover_charges: int=0
var _cover_cooldown: float=0.0
var _training_radar: Control
var _map_button: Button
var _map_overlay: Control
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
var _settings_button: Button
var _inventory_button: Button
var _inventory_panel: PanelContainer
var _inventory_label: Label
var air_stage: String="ground"
var _hud_layout: RefCounted
var _hud_editor: Control
var _hud_editor_label: Label
var _vibration_enabled: bool=false
var _hud_editing: bool=false
var _hud_selected: String=""


func _ready() -> void:
    _hud_layout=HUD_LAYOUT.new()
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
    _status.text = "THEDEMIAN: LAST ZONE / AURORA     ENTRENAMIENTO NATIVO"
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
    # The progress bar is a child of the editable medkit button, so it
    # follows the player's saved HUD placement, scaling and transparency.
    _heal_progress_bar=ProgressBar.new()
    _heal_progress_bar.name="AuroraFirstAidProgress"
    _heal_progress_bar.position=Vector2(5,66)
    _heal_progress_bar.size=Vector2(68,7)
    _heal_progress_bar.min_value=0.0
    _heal_progress_bar.max_value=100.0
    _heal_progress_bar.value=0.0
    _heal_progress_bar.show_percentage=false
    _heal_progress_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _heal_progress_bar.visible=false
    var first_aid_track:=StyleBoxFlat.new()
    first_aid_track.bg_color=Color(.06,.11,.09,.88)
    var first_aid_fill:=StyleBoxFlat.new()
    first_aid_fill.bg_color=Color(.34,.91,.63,.98)
    _heal_progress_bar.add_theme_stylebox_override("background",first_aid_track)
    _heal_progress_bar.add_theme_stylebox_override("fill",first_aid_fill)
    _medkit_button.add_child(_heal_progress_bar)
    _cover_button=_button(root,"BARRERA 0",.52,.68,96,55,Color(.13,.53,.68),_cover_down)
    _cover_button.visible=false
    _cover_button.disabled=true
    _exit_button=_button(root,"LOBBY",.936,.255,95,46,Color(.13,.27,.43),_return_lobby)
    _settings_button=_button(root,"AJUSTES",.85,.255,78,78,
        Color(.16,.34,.44),func(): settings_requested.emit())
    _inventory_button=_button(root,"MOCHILA",.75,.255,105,46,
        Color(.17,.35,.41),_toggle_inventory)
    _inventory_button.disabled=true
    _map_button=_button(root,"MAPA",.19,.22,70,70,
        Color(.11,.39,.53),_toggle_map)
    _inventory_panel=PanelContainer.new()
    _inventory_panel.name="RealMatchInventory"
    _inventory_panel.visible=false
    _inventory_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var inventory_skin:=StyleBoxFlat.new()
    inventory_skin.bg_color=Color(.025,.075,.11,.95)
    inventory_skin.border_color=Color(.25,.76,.86,.91)
    inventory_skin.set_border_width_all(2)
    inventory_skin.set_corner_radius_all(10)
    _inventory_panel.add_theme_stylebox_override("panel",inventory_skin)
    root.add_child(_inventory_panel)
    _inventory_label=Label.new()
    _inventory_label.name="RealInventoryContents"
    _inventory_label.add_theme_font_size_override("font_size",13)
    _inventory_label.add_theme_color_override("font_color",Color(.87,.96,.98))
    _inventory_label.text="INVENTARIO / SIN PARTIDA"
    _inventory_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _inventory_panel.add_child(_inventory_label)
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
    _build_hud_editor(root)
    _map_overlay=TACTICAL_MAP.new()
    _map_overlay.visible=false
    root.add_child(_map_overlay)
    _map_overlay.connect("waypoint_changed",func(point: Vector2):
        _training_radar.call("set_waypoint",point))
    _training_radar.call("set_waypoint",_map_overlay.get("waypoint"))
    apply_ui_settings()
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
    button.add_theme_font_size_override("font_size",12 if label.length()>6 else 15)
    var normal:=StyleBoxFlat.new()
    normal.bg_color=Color(color.r*.78,color.g*.76,color.b*.80,.88)
    normal.border_color=Color(.37,.76,.94,.86)
    normal.set_border_width_all(2)
    # Circular gameplay actions, not rounded rectangles. Non-gameplay BR
    # launch remains rectangular. Style radius is not enough on its own:
    # _layout also assigns genuinely square hit rectangles to every action.
    normal.set_corner_radius_all(100 if label!="INICIAR BR" else 12)
    normal.shadow_color=Color(0,0,0,.22)
    normal.shadow_size=3
    var pressed:=normal.duplicate() as StyleBoxFlat
    pressed.bg_color=color.lightened(.19)
    button.add_theme_stylebox_override("normal",normal)
    button.add_theme_stylebox_override("hover",normal)
    button.add_theme_stylebox_override("disabled",normal)
    button.add_theme_stylebox_override("pressed",pressed)
    button.button_down.connect(down)
    if up.is_valid():
        button.button_up.connect(up)
    root.add_child(button)
    return button


func _toggle_map() -> void:
    if _hud_editing or _map_overlay==null:
        return
    _map_overlay.visible=not _map_overlay.visible
    if _map_overlay.visible:
        _map_overlay.queue_redraw()


func set_tactical_map_sources(character: CharacterBody3D,world: StaticBody3D,
        match_director: Node3D) -> void:
    if _map_overlay!=null:
        _map_overlay.call("set_sources",character,world,match_director)


func apply_ui_settings() -> void:
    var cfg:=ConfigFile.new()
    cfg.load("user://aurora_ui_options.cfg")
    _vibration_enabled=bool(cfg.get_value("ui","vibration",false))
    if _fps:
        _fps.visible=bool(cfg.get_value("ui","show_fps",true))
    if _training_radar:
        _training_radar.set("rotate_with_camera",bool(cfg.get_value(
            "ui","radar_rotation",true)))
        _training_radar.queue_redraw()


func reload_hud_layout() -> void:
    _hud_layout=HUD_LAYOUT.new()
    if is_node_ready():
        _layout()


func _return_lobby() -> void:
    leave_to_lobby_requested.emit()


func set_air_stage(value: String) -> void:
    reset_controls()
    air_stage=value
    var airborne: bool=value!="ground"
    var overlay: Control=get_node("AuroraTacticalOverlay") as Control
    # Combat UI is irrelevant while riding the aircraft or descending.
    if _inventory_panel:
        _inventory_panel.visible=false
    for name in ["DirectionalFirePad","MIRA","RECARGA","ARMA","AGACHAR","CURAR 2","CORRER","BARRERA 0","MOCHILA"]:
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
    if _vibration_enabled and OS.has_feature("mobile"):
        Input.vibrate_handheld(10)
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


func cancel_sprint() -> void:
    # Fire, match transition or focus loss can cancel sprint externally.
    # The HUD state must never disagree with the real player movement mode.
    if _run_latched:
        _run_latched=false
        if _run_button:
            _run_button.text="CORRER"
        run_released.emit()


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


func _toggle_inventory() -> void:
    if air_stage!="ground" or _inventory_button.disabled:
        return
    _inventory_panel.visible=not _inventory_panel.visible


func set_inventory_snapshot(items: Dictionary) -> void:
    if _inventory_label==null:
        return
    var ar: String="AR-7 %d/%d (max %d)"%[
        int(items.get("ar_loaded",0)),int(items.get("ar_reserve",0)),
        int(items.get("ar_capacity",0))]
    var awm: String="AWM %d/%d (max %d)"%[
        int(items.get("awm_loaded",0)),int(items.get("awm_reserve",0)),
        int(items.get("awm_capacity",0))] if bool(items.get("awm_owned",false)) else "AWM: ENCUENTRA EL ARMA"
    _inventory_label.text=(
        "EQUIPO AURORA / %s\n"%("MOCHILA NIVEL 1" if int(items.get("backpack",0))>0 else "SIN MOCHILA")
        +ar+"\n"+awm+"\n"
        +"CHALECO %d/75  |  BOTIQUINES %d  |  BARRERAS %d"%[
            int(items.get("armor",0)),int(items.get("medkits",0)),
            int(items.get("covers",0))])


func set_medkit_count(count: int) -> void:
    if _medkit_button and not _heal_channel_active:
        _medkit_button.text="CURAR "+str(count)


## Render a real interrupted or completed medkit channel. This control
## remains attached to the user's persisted HUD medkit position.
func set_heal_channel(active: bool,seconds_left: float,total_seconds: float,
        medkits: int) -> void:
    _heal_channel_active=active
    if _medkit_button:
        _medkit_button.text="CANCELAR" if active else "CURAR "+str(medkits)
    if _heal_progress_bar:
        _heal_progress_bar.visible=active
        _heal_progress_bar.value=100.0*(1.0-clampf(
            seconds_left/maxf(.001,total_seconds),0.0,1.0))


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
    _place(_map_button,Rect2(origin+Vector2(201,103),Vector2(76,76)))
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
    _place(_exit_button,Rect2(origin+Vector2(w-107,108),Vector2(78,78)))
    _place(_settings_button,Rect2(origin+Vector2(w-194,108),Vector2(78,78)))
    _place(_inventory_button,Rect2(origin+Vector2(w-281,108),Vector2(78,78)))
    _place(_inventory_panel,Rect2(origin+Vector2(w-410,164),Vector2(290,127)))
    _place(_hint,Rect2(origin+Vector2(w*.5-210,h-32),Vector2(420,24)))
    _hint.add_theme_font_size_override("font_size",11)
    _place(_hit,Rect2(origin+Vector2(w*.5-300,128),Vector2(600,50)))
    _hit.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _place(root.get_node("MovePad"),Rect2(origin+Vector2(40,h-235),Vector2(210,210)))
    _place(_run_button,Rect2(origin+Vector2(96,h-341),Vector2(90,90)))
    _place(root.get_node("DirectionalFirePad"),Rect2(origin+Vector2(w-172,h-257),Vector2(144,144)))
    _place(_aim_button,Rect2(origin+Vector2(w-310,h-285),Vector2(86,86)))
    _place(root.get_node("RECARGA"),Rect2(origin+Vector2(w-314,h-186),Vector2(76,76)))
    _place(root.get_node("ARMA"),Rect2(origin+Vector2(w-230,h-106),Vector2(76,76)))
    _place(_crouch_button,Rect2(origin+Vector2(w-421,h-190),Vector2(78,78)))
    _place(_medkit_button,Rect2(origin+Vector2(w-421,h-99),Vector2(78,78)))
    _place(_cover_button,Rect2(origin+Vector2(w-421,h-284),Vector2(78,78)))
    _jump_button.custom_minimum_size=Vector2.ZERO
    var jump_rect:=Rect2(origin+Vector2(w-121,h-112),Vector2(92,92))
    if air_stage!="ground":
        jump_rect=Rect2(origin+Vector2(w-220,h-118),Vector2(190,64))
    _place(_jump_button,jump_rect)
    # Always reset to the factory coordinates before applying persisted
    # normalized overrides, including on every display/orientation resize.
    for id in HUD_LAYOUT.IDS:
        var control: Control=root.get_node_or_null(id) as Control
        if control==null:
            continue
        control.scale=Vector2.ONE
        control.modulate.a=1.0
    if air_stage=="ground":
        for id in HUD_LAYOUT.IDS:
            var target: Control=root.get_node_or_null(id) as Control
            var item: Dictionary=_hud_layout.get_item(id)
            if target==null or item.is_empty():
                continue
            var factor: float=float(item["scale"])
            var new_size: Vector2=target.size*factor
            var norm: Vector2=item["center"]
            var target_center: Vector2=origin+norm*safe.size
            target_center=target_center.clamp(origin+new_size*.5,
                safe.end-new_size*.5)
            target.position=target_center-new_size*.5
            target.scale=Vector2.ONE*factor
            target.modulate.a=float(item["alpha"])
    if _hud_editing and _hud_editor:
        _hud_editor.queue_redraw()



## Touch HUD personalization is a real paused 3D training session, not a
## fake settings preview. Weapon, movement, camera and audio are not replaced.
func _build_hud_editor(root: Control) -> void:
    _hud_editor=HUD_EDITOR.new()
    _hud_editor.set("hud",self)
    _hud_editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _hud_editor.visible=false
    root.add_child(_hud_editor)
    var toolbar:=PanelContainer.new()
    toolbar.name="HudEditorToolbar"
    toolbar.anchor_left=.16
    toolbar.anchor_right=.84
    toolbar.anchor_top=.025
    toolbar.anchor_bottom=.025
    toolbar.offset_bottom=130
    var style:=StyleBoxFlat.new()
    style.bg_color=Color(.015,.07,.12,.98)
    style.border_color=Color(.25,.77,.93)
    style.set_border_width_all(2)
    style.set_corner_radius_all(10)
    toolbar.add_theme_stylebox_override("panel",style)
    _hud_editor.add_child(toolbar)
    var vbox:=VBoxContainer.new()
    vbox.add_theme_constant_override("separation",4)
    toolbar.add_child(vbox)
    _hud_editor_label=Label.new()
    _hud_editor_label.name="SelectedHudControl"
    _hud_editor_label.text="EDITAR HUD  •  Toca y arrastra un control"
    _hud_editor_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    _hud_editor_label.add_theme_font_size_override("font_size",15)
    vbox.add_child(_hud_editor_label)
    var row:=GridContainer.new()
    row.columns=4
    row.add_theme_constant_override("h_separation",5)
    row.add_theme_constant_override("v_separation",3)
    vbox.add_child(row)
    _hud_editor_button(row,"TAMAÑO -",_hud_edit_adjust.bind(-.08,0.0))
    _hud_editor_button(row,"TAMAÑO +",_hud_edit_adjust.bind(.08,0.0))
    _hud_editor_button(row,"OPACIDAD -",_hud_edit_adjust.bind(0.0,-.10))
    _hud_editor_button(row,"OPACIDAD +",_hud_edit_adjust.bind(0.0,.10))
    _hud_editor_button(row,"GUARDAR",_hud_edit_save)
    _hud_editor_button(row,"RESTAURAR",_hud_edit_restore)
    _hud_editor_button(row,"CERRAR",_hud_edit_close)
    _hud_editor_button(row,"AYUDA",_hud_edit_help)


func _hud_editor_button(parent: Control,title: String,handler: Callable) -> void:
    var button:=Button.new()
    button.name="Editor"+title
    button.text=title
    button.focus_mode=Control.FOCUS_NONE
    button.custom_minimum_size=Vector2(111,35)
    button.add_theme_font_size_override("font_size",12)
    parent.add_child(button)
    button.pressed.connect(handler)


func open_hud_editor() -> void:
    if air_stage!="ground" or _hud_editing:
        return
    reset_controls()
    if _map_overlay:
        _map_overlay.visible=false
    _hud_editing=true
    _hud_selected=""
    _hud_editor.visible=true
    _hud_editor.call("reset_pointer")
    _hud_editor_label.text="EDITAR HUD  •  Toca y arrastra un control"
    process_mode=Node.PROCESS_MODE_ALWAYS
    get_tree().paused=true
    _hud_editor.queue_redraw()


func hud_editor_target(id: String) -> Control:
    if not HUD_LAYOUT.IDS.has(id):
        return null
    return get_node_or_null("AuroraTacticalOverlay/"+id) as Control


func hud_editor_selected(id: String) -> void:
    _hud_selected=id
    if _hud_editor_label:
        _hud_editor_label.text=("CONTROL: "+id+"  •  Arrastra / ajusta" if id!="" else
            "EDITAR HUD  •  Toca un control para seleccionarlo")


func _hud_edit_value(id: String) -> Dictionary:
    var current: Dictionary=_hud_layout.get_item(id)
    if not current.is_empty():
        return current
    var target: Control=hud_editor_target(id)
    var safe: Rect2=SAFE_SCREEN.rect(get_viewport())
    return {
        "center":(target.get_global_rect().get_center()-safe.position)/safe.size,
        "scale":target.scale.x,
        "alpha":target.modulate.a
    }


func hud_editor_move(id: String,canvas_center: Vector2) -> void:
    if not _hud_editing:
        return
    var item: Dictionary=_hud_edit_value(id)
    var safe: Rect2=SAFE_SCREEN.rect(get_viewport())
    var control: Control=hud_editor_target(id)
    if control==null:
        return
    var scaled: Vector2=control.size*float(item["scale"])
    var center: Vector2=canvas_center.clamp(safe.position+scaled*.5,
        safe.end-scaled*.5)
    var norm: Vector2=(center-safe.position)/safe.size
    if _hud_layout.set_item(id,norm,float(item["scale"]),
            float(item["alpha"]))==OK:
        _layout()


func _hud_edit_adjust(scale_step: float,alpha_step: float) -> void:
    if _hud_selected=="":
        return
    var item: Dictionary=_hud_edit_value(_hud_selected)
    var factor: float=clampf(float(item["scale"])+scale_step,
        HUD_LAYOUT.MIN_SCALE,HUD_LAYOUT.MAX_SCALE)
    var alpha: float=clampf(float(item["alpha"])+alpha_step,
        HUD_LAYOUT.MIN_ALPHA,1.0)
    if _hud_layout.set_item(_hud_selected,item["center"],factor,alpha)==OK:
        _layout()


func _hud_edit_help() -> void:
    _hud_editor_label.text="Arrastra, ajusta, GUARDA y luego CIERRA"


func _hud_edit_save() -> void:
    var result: Error=_hud_layout.save()
    if result!=OK:
        _hud_editor_label.text="ERROR AL GUARDAR HUD: "+str(result)
        return
    _hud_editor_label.text="HUD GUARDADO  •  Cerrar para volver"


func _hud_edit_restore() -> void:
    var result: Error=_hud_layout.restore_defaults()
    if result!=OK:
        _hud_editor_label.text="ERROR AL RESTAURAR: "+str(result)
        return
    _hud_selected=""
    _hud_editor.call("reset_pointer")
    _hud_editor_label.text="HUD ORIGINAL RESTAURADO"
    _layout()


func _hud_edit_close() -> void:
    if not _hud_editing:
        return
    _hud_editing=false
    _hud_selected=""
    _hud_editor.visible=false
    _hud_editor.call("reset_pointer")
    # Discard only unsaved edits, preserve the last validated disk layout.
    _hud_layout=HUD_LAYOUT.new()
    _layout()
    get_tree().paused=false
    process_mode=Node.PROCESS_MODE_INHERIT
    hud_editor_closed.emit()


func _exit_tree() -> void:
    if _hud_editing:
        get_tree().paused=false
        _hud_editing=false


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
    if _inventory_panel:
        _inventory_panel.visible=false
    cancel_sprint()
    if _run_button:
        _run_button.text="CORRER"


func set_match_controls(enabled: bool) -> void:
    var root: Control=get_node("AuroraTacticalOverlay")
    for control in root.get_children():
        if control is Button and control!=_battle_button and control!=_exit_button and control!=_settings_button:
            control.disabled=not enabled
    root.get_node("MovePad").visible=enabled
    root.get_node("DirectionalFirePad").visible=enabled
    _cover_button.visible=enabled and air_stage=="ground"
    _cover_button.disabled=not enabled or _cover_charges<=0 or _cover_cooldown>0.0
    if _inventory_button:
        _inventory_button.disabled=not enabled or air_stage!="ground"
    if not enabled and _inventory_panel:
        _inventory_panel.visible=false


func _notification(what: int) -> void:
    if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
        reset_controls()
