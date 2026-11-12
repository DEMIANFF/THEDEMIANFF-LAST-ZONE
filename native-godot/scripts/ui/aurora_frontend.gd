extends Control
## Original Aurora front-end. Free Fire is UX reference ONLY; no copied layout,
## assets or proprietary game branding. Incomplete service tabs say so.
const SAFE_SCREEN=preload("res://scripts/ui/safe_screen.gd")
const CAMERA_PREFERENCES=preload("res://scripts/persistence/camera_preferences.gd")
const PLAYER_SETTINGS=preload("res://scripts/persistence/player_settings.gd")
const LOBBY_BACKDROP=preload("res://scripts/ui/aurora_lobby_backdrop.gd")
const LOBBY_STAGE=preload("res://scripts/ui/aurora_lobby_stage_3d.gd")
const GAME = preload("res://scenes/Main.tscn")
const SETTINGS_OVERLAY=preload("res://scripts/ui/aurora_settings_overlay.gd")
const MATCH_RECORDS = preload("res://scripts/persistence/offline_match_records.gd")
const PERFORMANCE=preload("res://scripts/persistence/aurora_performance_report.gd")
const FLIGHT_DIAGNOSTICS=preload("res://scripts/match/flight_diagnostics.gd")
const STARTUP_DIAG=preload("res://scripts/persistence/scene_startup_diagnostics.gd")
const FLIGHT_SAFETY_MODE=preload("res://scripts/persistence/flight_safety_mode.gd")

var _settings_panel: VBoxContainer
var _settings_content: VBoxContainer
var _settings_status: Label
var _scope_sliders: Dictionary={}
var _mobile_options: RefCounted
var _look_slider: HSlider
var _ads_slider: HSlider
var _sfx_slider: HSlider
var _ambience_slider: HSlider
var _graphics_selector: OptionButton
var _preferences: RefCounted
var _save_timer: Timer
var stage: String = "welcome"
var _surface: Control
var _page: VBoxContainer
var _info: Label
var _game: Node3D
var _primary: Button
var _selected_tab: String = "PERSONAJE"
var _preview_container: SubViewportContainer
var _preview_avatar: Node3D
var _preview_caption: Label
var _offline_records: RefCounted
var _lobby_nav: VBoxContainer
var _profile_strip: Label
var _preview_touch: int=-1
var _preview_mouse_drag: bool=false
var _preview_drag_last: Vector2=Vector2.ZERO
var _preview_resume_spin: float=0.0
var _hud_editor_requested: bool=false
var _hud_editor_origin: String=""
var _settings_modal: CanvasLayer
var _brand_logo: TextureRect
var _encounter_count: int=9
var _encounter_selector: OptionButton


func _ready() -> void:
    name = "AuroraFront"
    _preferences=CAMERA_PREFERENCES.new()
    _mobile_options=PLAYER_SETTINGS.new()
    # Frame cap is a runtime option; imported texture compression remains a build-time choice.
    Engine.max_fps=_mobile_options.fps_limit()
    _save_timer=Timer.new()
    _save_timer.one_shot=true
    _save_timer.wait_time=.4
    _save_timer.timeout.connect(_save_preferences)
    add_child(_save_timer)
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter=Control.MOUSE_FILTER_STOP
    _surface=Control.new()
    _surface.name="AuroraMenuSurface"
    _surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _surface.mouse_filter=Control.MOUSE_FILTER_STOP
    add_child(_surface)
    var bg:=ColorRect.new()
    bg.name="AuroraNightBackground"
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color=Color(.018,.038,.082,1)
    bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(bg)
    move_child(bg,0)
    var line:=ColorRect.new()
    line.name="AuroraBlueAccent"
    line.anchor_left=.045
    line.anchor_right=.955
    line.anchor_top=.16
    line.anchor_bottom=.16
    line.offset_bottom=3
    line.color=Color(.12,.73,.92)
    line.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _surface.add_child(line)
    var painted: Control=LOBBY_BACKDROP.new()
    painted.name="OriginalAuroraCoast"
    painted.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _surface.add_child(painted)
    _surface.move_child(painted,0)
    _page=VBoxContainer.new()
    _page.name="Page"
    _page.anchor_left=.07
    _page.anchor_right=.63
    _page.anchor_top=.10
    _page.anchor_bottom=.94
    _page.add_theme_constant_override("separation",8)
    _surface.add_child(_page)
    _brand_logo=TextureRect.new()
    _brand_logo.name="LastZoneAuroraEmblem"
    _brand_logo.texture=load("res://icon.svg")
    _brand_logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    _brand_logo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _brand_logo.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _surface.add_child(_brand_logo)
    _build_preview()
    get_viewport().size_changed.connect(_layout_safe)
    _layout_safe.call_deferred()
    _welcome()


func _process(delta: float) -> void:
    # Keep the real CC0 rig animated and turnable, without any extra 3D
    # viewport allocations. The full preview is freed before match creation.
    if stage!="lobby" or _preview_avatar==null or not             is_instance_valid(_preview_avatar):
        return
    _preview_resume_spin=maxf(0.0,_preview_resume_spin-delta)
    if _preview_resume_spin<=0.0 and _preview_touch<0 and not _preview_mouse_drag:
        _preview_avatar.rotation.y=wrapf(
            _preview_avatar.rotation.y+delta*.18,-PI,PI)


func _preview_input(event: InputEvent) -> void:
    if stage!="lobby" or _preview_avatar==null:
        return
    if event is InputEventScreenTouch:
        var touch:=event as InputEventScreenTouch
        if touch.pressed and not touch.canceled and _preview_touch<0:
            _preview_touch=touch.index
            _preview_drag_last=touch.position
            _preview_resume_spin=2.2
            _preview_container.accept_event()
        elif touch.index==_preview_touch and (not touch.pressed or touch.canceled):
            _preview_touch=-1
            _preview_container.accept_event()
    elif event is InputEventScreenDrag:
        var drag:=event as InputEventScreenDrag
        if drag.index==_preview_touch:
            _preview_avatar.rotation.y=wrapf(
                _preview_avatar.rotation.y+drag.relative.x*.008,-PI,PI)
            _preview_drag_last=drag.position
            _preview_resume_spin=2.2
            _preview_container.accept_event()
    elif event is InputEventMouseButton:
        var mouse:=event as InputEventMouseButton
        if mouse.button_index==MOUSE_BUTTON_LEFT:
            _preview_mouse_drag=mouse.pressed
            _preview_drag_last=mouse.position
            _preview_resume_spin=2.2
            _preview_container.accept_event()
    elif event is InputEventMouseMotion and _preview_mouse_drag:
        var motion:=event as InputEventMouseMotion
        _preview_avatar.rotation.y=wrapf(
            _preview_avatar.rotation.y+motion.relative.x*.008,-PI,PI)
        _preview_drag_last=motion.position
        _preview_resume_spin=2.2
        _preview_container.accept_event()


func _clear_page() -> void:
    if not _save_timer.is_stopped():
        _save_preferences()
    _settings_panel=null
    for node in _page.get_children():
        _page.remove_child(node)
        node.queue_free()


func _label(value: String, font_size: int=24) -> Label:
    var line:=Label.new()
    line.text=value
    line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    line.add_theme_font_size_override("font_size",font_size)
    line.add_theme_color_override("font_color",Color(.86,.96,1))
    line.add_theme_color_override("font_shadow_color",Color(.0,.04,.09))
    _page.add_child(line)
    return line


func _button(value: String, callback: Callable, width: float=260.0) -> Button:
    var button:=Button.new()
    button.text=value
    button.custom_minimum_size=Vector2(width,54)
    button.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
    button.focus_mode=Control.FOCUS_NONE
    button.add_theme_font_size_override("font_size",18)
    var style:=StyleBoxFlat.new()
    style.bg_color=Color(.025,.10,.19,.94)
    style.border_color=Color(.46,.66,.96)
    style.set_border_width_all(2)
    style.set_corner_radius_all(8)
    var pressed:=style.duplicate() as StyleBoxFlat
    pressed.bg_color=Color(.15,.37,.52)
    button.add_theme_stylebox_override("normal",style)
    button.add_theme_stylebox_override("hover",pressed)
    button.add_theme_stylebox_override("pressed",pressed)
    button.pressed.connect(callback)
    return button


func _welcome() -> void:
    stage="welcome"
    visible=true
    if _preview_container:
        _preview_container.visible=false
    if _preview_caption:
        _preview_caption.visible=false
    if _lobby_nav:
        _lobby_nav.visible=false
    if _profile_strip:
        _profile_strip.visible=false
    _page.anchor_left=.07
    _page.anchor_right=.63
    _page.anchor_top=.015
    _page.anchor_bottom=.995
    _page.add_theme_constant_override("separation",5)
    _brand_logo.visible=true
    # Keep emblem in a clean title-side hero area. Previously it covered
    # the diagnostic buttons and character selection at phone resolution.
    _brand_logo.anchor_left=.76
    _brand_logo.anchor_right=.91
    _brand_logo.anchor_top=.12
    _brand_logo.anchor_bottom=.43
    _clear_page()
    _label("THEDEMIAN: LAST ZONE",33)
    _label("PUERTO AURORA  •  EL ÚLTIMO HORIZONTE",20)
    _label("Operación de supervivencia — diagnóstico de desarrollo",14)
    var enter:=_button("ENTRAR",Callable(self,"_show_lobby"))
    enter.name="EnterButton"
    _page.add_child(enter)
    _label("Esta versión prueba partidas offline. El multijugador y las cuentas en Godot todavía no están disponibles.",14)
    var test_mode: Button=_button(
        "VUELO "+FLIGHT_SAFETY_MODE.label_for(FLIGHT_SAFETY_MODE.current_mode()),
        Callable(self,"_cycle_flight_diagnostic"),390)
    test_mode.name="FlightDiagnosticModeButton"
    test_mode.add_theme_font_size_override("font_size",15)
    _page.add_child(test_mode)
    var startup_button: Button=_button(
        "CARGA "+STARTUP_DIAG.label(),
        Callable(self,"_cycle_scene_load_diagnostic"),405)
    startup_button.name="SceneStartupDiagnosticButton"
    startup_button.add_theme_font_size_override("font_size",15)
    _page.add_child(startup_button)
    var trace: Dictionary=FLIGHT_DIAGNOSTICS.last()
    if not trace.is_empty():
        var state: String=str(trace.get("state",""))
        _label(("VUELO ANTERIOR SIN TERMINAR" if state=="active" else "ÚLTIMO VUELO REGISTRADO")+
            " / "+str(trace.get("phase","desconocido")),15)
        _label("Último evento: "+str(trace.get("note",""))+
            " · FPS "+str(trace.get("fps","?"))+
            " · #"+str(trace.get("sequence",0)),13)
        _page.add_child(_button("VER REGISTRO DETALLADO",Callable(self,"_show_flight_details"),295))
    var saved: Dictionary=FLIGHT_DIAGNOSTICS.last(true)
    if not saved.is_empty():
        _page.add_child(_button("VER VUELO INTERRUMPIDO ANTERIOR",
            Callable(self,"_show_previous_flight_details"),350))


func _copy_flight_diagnostics(previous: bool=false) -> void:
    DisplayServer.clipboard_set(FLIGHT_DIAGNOSTICS.report(previous))


func _cycle_scene_load_diagnostic() -> void:
    var next_mode: int=(STARTUP_DIAG.mode()+1)%5
    if STARTUP_DIAG.save(next_mode)!=OK:
        push_warning("Could not save Aurora shared-scene diagnostic mode")
        return
    var button: Button=_page.get_node_or_null("SceneStartupDiagnosticButton") as Button
    if button:
        button.text="CARGA "+STARTUP_DIAG.label()


func _show_previous_flight_details() -> void:
    _show_flight_details(true)


func _copy_previous_flight_diagnostics() -> void:
    _copy_flight_diagnostics(true)


func _show_flight_details(previous: bool=false) -> void:
    stage="flight_diagnostics"
    _clear_page()
    _page.anchor_left=.035
    _page.anchor_right=.965
    _page.anchor_top=.04
    _page.anchor_bottom=.96
    _page.add_theme_constant_override("separation",6)
    _label("CAJA NEGRA / DIAGNÓSTICO DEL VUELO",25)
    _label("Historial guardado (no es un informe nativo de Android).",14)
    var log_view:=TextEdit.new()
    log_view.name="FlightBlackBoxText"
    log_view.editable=false
    log_view.text=FLIGHT_DIAGNOSTICS.report(previous)
    log_view.custom_minimum_size=Vector2(450,220)
    log_view.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    log_view.size_flags_vertical=Control.SIZE_EXPAND_FILL
    log_view.add_theme_font_size_override("font_size",15)
    _page.add_child(log_view)
    _page.add_child(_button("COPIAR INFORME COMPLETO",
        Callable(self,"_copy_previous_flight_diagnostics") if previous else
        Callable(self,"_copy_flight_diagnostics"),295))
    _page.add_child(_button("VOLVER",Callable(self,"_welcome"),175))


func _cycle_flight_diagnostic() -> void:
    var next_mode: int=(FLIGHT_SAFETY_MODE.current_mode()+1)%6
    var error: Error=FLIGHT_SAFETY_MODE.save_mode(next_mode)
    if error!=OK:
        push_warning("Aurora flight diagnostic setting could not be saved: "+str(error))
        return
    var button: Button=_page.get_node_or_null("FlightDiagnosticModeButton") as Button
    if button:
        button.text="VUELO "+FLIGHT_SAFETY_MODE.label_for(next_mode)


func _show_lobby() -> void:
    # Actual on-device results. No invented premium currency, fake friends or fake cloud ID.
    _offline_records=MATCH_RECORDS.new()
    var stats: Dictionary=_offline_records.snapshot()
    if _preview_container==null or not is_instance_valid(_preview_container):
        _build_preview()
    stage="lobby"
    visible=true
    _brand_logo.visible=true
    # Logo stays outside the full-width profile strip and never crosses
    # over player statistics or the rotating 3D character.
    _brand_logo.anchor_left=.909
    _brand_logo.anchor_right=.958
    _brand_logo.anchor_top=.022
    _brand_logo.anchor_bottom=.137
    _page.anchor_left=.67
    _page.anchor_right=.97
    _page.anchor_top=.16
    _page.anchor_bottom=.94
    _page.add_theme_constant_override("separation",8)
    _preview_container.anchor_left=.29
    _preview_container.anchor_right=.65
    _preview_container.anchor_top=.14
    _preview_container.anchor_bottom=.86
    _preview_container.visible=true
    _preview_caption.visible=true
    _preview_caption.anchor_left=.29
    _preview_caption.anchor_right=.65
    _preview_caption.anchor_top=.875
    _preview_caption.anchor_bottom=.875
    _ensure_lobby_navigation()
    _lobby_nav.visible=true
    _profile_strip.visible=true
    _profile_strip.text="THEDEMIAN: LAST ZONE    ·    PUERTO AURORA     |     PERFIL LOCAL     |     %d PARTIDAS    ·    %d VICTORIAS"%[int(stats.get("played",0)),int(stats.get("wins",0))]
    _preview_touch=-1
    _preview_mouse_drag=false
    _preview_resume_spin=2.0
    if _preview_avatar:
        _preview_avatar.rotation.y=0.0
    _clear_page()
    _label("PUERTO AURORA  /  BR",27)
    _label("OPERACIÓN ÚLTIMA ZONA  •  OFFLINE",14)
    var mode_title:=_label("SELECCIONA UN MODO",17)
    mode_title.add_theme_color_override("font_color",Color(.96,.77,.38))
    var modes:=VBoxContainer.new()
    modes.name="PlayModes"
    modes.add_theme_constant_override("separation",8)
    _page.add_child(modes)
    var battle:=_button("INICIAR BATTLE ROYALE",Callable(self,"_launch").bind(true),265)
    battle.name="BattleButton"
    modes.add_child(battle)
    var training:=_button("ENTRENAMIENTO",Callable(self,"_launch").bind(false),245)
    training.name="TrainingButton"
    modes.add_child(training)
    var selector_caption:=_label("PARTICIPANTES LOCALES / SOLO CON IA",14)
    selector_caption.add_theme_color_override("font_color",Color(.88,.86,.68))
    _encounter_selector=OptionButton.new()
    _encounter_selector.name="OfflineEncounterSize"
    _encounter_selector.custom_minimum_size=Vector2(257,38)
    _encounter_selector.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
    _encounter_selector.add_item("9 TOTAL · 1 + 8 IA (estable)",9)
    _encounter_selector.add_item("20 TOTAL · 1 + 19 IA (prueba)",20)
    _encounter_selector.add_item("30 TOTAL · 1 + 29 IA (carga)",30)
    _encounter_selector.select([9,20,30].find(_encounter_count))
    _encounter_selector.item_selected.connect(_on_encounter_selected)
    _page.add_child(_encounter_selector)
    _info=_label("",16)
    _info.name="LobbyDetail"
    _build_settings()
    _select_tab(_selected_tab)


func _on_encounter_selected(index: int) -> void:
    if _encounter_selector==null:
        return
    _encounter_count=_encounter_selector.get_item_id(index)
    if _encounter_count not in [9,20,30]:
        _encounter_count=9
    # These are all OFFLINE AI opponents. Human 20/30 player sessions
    # still require dedicated server authority and replication.
    if _info!=null and stage=="lobby":
        _info.text="SECTOR LOCAL %d · 1 OPERADOR + %d IA\n%s"%[
            _encounter_count,_encounter_count-1,
            "Carga elevada: verifica FPS en Motorola" if _encounter_count>9
            else "Configuración móvil recomendada"]


func _ensure_lobby_navigation() -> void:
    if _lobby_nav!=null and is_instance_valid(_lobby_nav):
        return
    _profile_strip=Label.new()
    _profile_strip.name="LocalProfileStrip"
    _profile_strip.anchor_left=.034
    _profile_strip.anchor_right=.89
    _profile_strip.anchor_top=.035
    _profile_strip.anchor_bottom=.035
    _profile_strip.offset_bottom=43
    _profile_strip.add_theme_font_size_override("font_size",16)
    _profile_strip.add_theme_color_override("font_color",Color(.90,.97,1))
    _profile_strip.add_theme_color_override("font_shadow_color",Color(.01,.035,.07))
    _profile_strip.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _surface.add_child(_profile_strip)
    var backplate:=ColorRect.new()
    backplate.name="LobbyMenuBackplate"
    backplate.anchor_left=.665
    backplate.anchor_right=.978
    backplate.anchor_top=.16
    backplate.anchor_bottom=.945
    backplate.color=Color(.036,.03,.093,.93)
    backplate.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _surface.add_child(backplate)
    _surface.move_child(backplate,1)
    var navplate:=ColorRect.new()
    navplate.name="LobbySidebarBackplate"
    navplate.anchor_left=.028
    navplate.anchor_right=.264
    navplate.anchor_top=.167
    navplate.anchor_bottom=.947
    navplate.color=Color(.023,.045,.096,.88)
    navplate.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _surface.add_child(navplate)
    _surface.move_child(navplate,2)
    _lobby_nav=VBoxContainer.new()
    _lobby_nav.name="LobbyNavigation"
    _lobby_nav.anchor_left=.035
    _lobby_nav.anchor_right=.255
    _lobby_nav.anchor_top=.19
    _lobby_nav.anchor_bottom=.94
    _lobby_nav.add_theme_constant_override("separation",4)
    _surface.add_child(_lobby_nav)
    for tab in ["PERSONAJE","ARMAS","MISIONES","TIENDA","EVENTOS","PASE","SOCIAL","CUENTA","AJUSTES"]:
        var tab_name: String=tab
        var button:=_button(tab_name,Callable(self,"_select_tab").bind(tab_name),176)
        button.name="Tab"+tab_name
        var compact: bool=_surface.size.y<620.0
        button.custom_minimum_size=Vector2(176,30 if compact else 43)
        button.add_theme_font_size_override("font_size",12 if compact else 18)
        _lobby_nav.add_child(button)


func _select_tab(tab: String) -> void:
    _selected_tab=tab
    if stage!="lobby" or _info==null:
        return
    _settings_panel.visible=tab=="AJUSTES"
    for button in _lobby_nav.get_children():
        if button is Button:
            var selected: bool=button.name=="Tab"+tab
            button.modulate=Color(1,.83,.48) if selected else Color.WHITE
    match tab:
        "AJUSTES":
            _info.text="CÁMARA / PRECISIÓN / HUD\nSensibilidades y controles personalizables guardados en este dispositivo."
        "PERSONAJE":
            var stats: Dictionary=_offline_records.snapshot()
            _info.text="OPERADORA / LILA EN DESARROLLO\nModelo 3D provisional."
            _info.text+="\nPARTIDAS %d  •  VICTORIAS %d  •  BAJAS %d"%[int(stats.get("played",0)),int(stats.get("wins",0)),int(stats.get("kills",0))]
            _info.text+="\nRÉCORD %d BAJAS  •  %d S VIVO"%[int(stats.get("best_kills",0)),int(stats.get("longest_survival_seconds",0))]
            var measured: Dictionary=PERFORMANCE.latest()
            if int(measured.get("frames",0))>=3:
                _info.text+="\nFPS REALES: MEDIA %.1f / P10 %.1f"%[
                    float(measured.get("average_fps",0.0)),
                    float(measured.get("low10_fps",0.0))]
                if float(measured.get("median_fps",0.0))>0.0:
                    _info.text+="\nFPS MEDIANA %.1f / P90 %.1f"%[
                        float(measured.get("median_fps",0.0)),
                        float(measured.get("p90_fps",0.0))]
                _info.text+="\nMODO PROBADO: %d PARTICIPANTES"%int(
                    measured.get("participants",0))
                if str(measured.get("render_driver","unknown"))!="unknown":
                    _info.text+="\nMOTOR MEDIDO: %s / %s · 3D %.0f%%"%[
                        str(measured.get("render_method","unknown")).to_upper(),
                        str(measured.get("render_driver","unknown")).to_upper(),
                        float(measured.get("quality_scale",1.0))*100.0]
        "ARMAS":
            _info.text="ARSENAL ACTIVO\nAR-7: mira x2 / x4.\nAWM: mira x8 y cerrojo automático.\nBR: AWM sobre el suelo, en la PLAZA (8, 24).\nENTRENAMIENTO: pulsa ARMA para probarla."
        "MISIONES":
            var stats: Dictionary=_offline_records.snapshot()
            var latest: Array=stats.get("history",[])
            _info.text="REGISTRO REAL / OFFLINE\n%d partidas  •  %d victorias"%[int(stats.get("played",0)),int(stats.get("wins",0))]
            if not latest.is_empty():
                var recent: Dictionary=latest[0]
                _info.text+="\nÚltima: "+("VICTORIA" if recent.get("victory",false) else "DERROTA")
                _info.text+="  •  %d bajas"%int(recent.get("kills",0))
            _info.text+="\nRecompensas de misiones: pendientes."
        "TIENDA":
            _info.text="TIENDA / EN CONSTRUCCIÓN\nSin transacciones, moneda premium ni inventario de compras ficticios."
        "EVENTOS":
            _info.text="EVENTOS / PRÓXIMA ETAPA\nSe activarán cuando haya programación, objetivos y recompensas verificables."
        "PASE":
            _info.text="PASE DE BATALLA / PLANIFICADO\nAún no existen temporadas pagadas ni cobros habilitados."
        "SOCIAL":
            _info.text="SOCIAL / SIN CONEXIÓN\nAmigos, clanes y escuadras necesitan un servicio online real."
        "CUENTA":
            _info.text="CUENTA / GUARDADO LOCAL\nLos resultados se almacenan en este dispositivo. Google y Firebase no están vinculados a Godot."
        _:
            _info.text="SECCIÓN NO DISPONIBLE"

func _launch_hud_editor() -> void:
    if stage!="lobby":
        return
    _hud_editor_requested=true
    _hud_editor_origin="lobby"
    _launch(false)


## The same settings screen opens over lobby, training and live BR.
## It does not replace the scene or reset aircraft, zone or match clock.
func _open_settings() -> void:
    if _settings_modal!=null and is_instance_valid(_settings_modal):
        return
    if stage not in ["lobby","training","battle"]:
        return
    var modal: CanvasLayer=SETTINGS_OVERLAY.new()
    modal.name="AuroraRealSettings"
    modal.set("context_origin",stage)
    modal.set("context_game",_game if stage!="lobby" else null)
    modal.connect("closed",func(): _settings_modal=null)
    modal.connect("hud_editor_requested",_settings_edit_hud)
    _settings_modal=modal
    if stage=="lobby":
        add_child(modal)
    else:
        _game.add_child(modal)


func _settings_edit_hud() -> void:
    if _settings_modal!=null and is_instance_valid(_settings_modal):
        _settings_modal.call("_close")
    if stage=="lobby":
        _launch_hud_editor()
    elif stage in ["training","battle"] and _game!=null:
        var hud: CanvasLayer=_game.get_node("TrainingHUD")
        hud.call_deferred("open_hud_editor")


func _on_lobby_hud_editor_closed() -> void:
    if _hud_editor_origin!="lobby":
        return
    _hud_editor_origin=""
    # The HUD was edited in a paused real scene, not a fake preview.
    # The owning lobby is restored, instead of stranding the player in
    # a training session that they never explicitly started.
    call_deferred("_finish_lobby_hud_return")


func _finish_lobby_hud_return() -> void:
    if stage=="training" and _game!=null:
        _return_to_lobby()


func _launch(battle: bool) -> void:
    if stage!="lobby":
        return
    stage="loading"
    FLIGHT_DIAGNOSTICS.checkpoint("active","scene_load",null,
        "frontend_launch_requested",
        "mode="+("battle" if battle else "training")+
        " startup_profile="+str(STARTUP_DIAG.mode()))
    # Unload the 440x600 offscreen character renderer (its own 3D world,
    # lights, rig and textures) before entering a memory-heavy Android match.
    # Hiding it only stopped drawing but retained VRAM/mesh allocations.
    if _preview_container and is_instance_valid(_preview_container):
        _preview_container.queue_free()
    if _preview_caption and is_instance_valid(_preview_caption):
        _preview_caption.queue_free()
    _preview_container=null
    _preview_caption=null
    _preview_avatar=null
    _clear_page()
    _label("PREPARANDO PUERTO AURORA",27)
    _label("Cargando terreno, colisiones, personaje, armas y patrullas...",18)
    call_deferred("_activate_game",battle)


func _activate_game(battle: bool) -> void:
    if stage!="loading":
        return
    # The queued SubViewport is actually freed at the end of the frame,
    # AFTER deferred calls. One frame boundary avoids overlapping both
    # render targets and both animated player rigs during match creation.
    await get_tree().process_frame
    if stage!="loading":
        return
    FLIGHT_DIAGNOSTICS.checkpoint("active","scene_load",null,
        "frontend_scene_instantiate_before",
        "mode="+("battle" if battle else "training"))
    _game=GAME.instantiate() as Node3D
    _game.name="ActiveAuroraGame"
    FLIGHT_DIAGNOSTICS.checkpoint("active","scene_load",null,
        "frontend_scene_enter_tree_before")
    # add_child invokes Main._ready synchronously. The Main script places
    # durable checkpoints around every major resource-heavy subsystem.
    get_parent().add_child(_game)
    var player: CharacterBody3D=_game.get_node("Operator") as CharacterBody3D
    FLIGHT_DIAGNOSTICS.checkpoint("active","scene_load",player,
        "frontend_scene_enter_tree_after")
    var hud:=_game.get_node("TrainingHUD") as CanvasLayer
    hud.leave_to_lobby_requested.connect(_return_to_lobby)
    hud.connect("settings_requested",_open_settings)
    hud.connect("hud_editor_closed",_on_lobby_hud_editor_closed)
    visible=false
    stage="battle" if battle else "training"
    if battle:
        var combat: Node3D=_game.get_node("CombatRange")
        combat.call("set_encounter_size",_encounter_count)
        var match_director: Node3D=_game.get_node("AuroraSectorMatch")
        FLIGHT_DIAGNOSTICS.checkpoint("active","scene_load",player,
            "battle_aircraft_begin_before")
        match_director.begin_aircraft_phase()
    else:
        FLIGHT_DIAGNOSTICS.checkpoint("active","training",player,
            "training_entered",
            "startup_profile="+str(STARTUP_DIAG.mode()))
        if _hud_editor_requested:
            _hud_editor_requested=false
            # The editor acts on the REAL TrainingHUD. It opens after
            # Main._ready and the old 3D lobby viewport have been released.
            hud.call_deferred("open_hud_editor")
    # This confirmation is written after a visible 3D frame, not after
    # merely enqueuing the world. A missing confirmation is not a GPU proof.
    # Headless QA never submits drawable frames; a stale one-shot callback
    # otherwise remains connected when Training is started repeatedly.
    if DisplayServer.get_name()!="headless" and not RenderingServer.frame_post_draw.is_connected(
        _on_first_world_frame_post_draw):
        RenderingServer.frame_post_draw.connect(
            _on_first_world_frame_post_draw,CONNECT_ONE_SHOT)


func _on_first_world_frame_post_draw() -> void:
    # Avoid disk writes from a render-server event. Defer to idle main loop.
    call_deferred("_record_first_world_frame")


func _record_first_world_frame() -> void:
    if _game==null or not is_instance_valid(_game) or not _game.is_inside_tree():
        return
    var player: CharacterBody3D=_game.get_node_or_null("Operator") as CharacterBody3D
    var phase: String="training" if stage=="training" else "aircraft"
    FLIGHT_DIAGNOSTICS.checkpoint("active",phase,player,
        "shared_scene_first_frame_rendered",
        "startup_profile="+str(STARTUP_DIAG.mode()))


func _return_to_lobby() -> void:
    if _game!=null and is_instance_valid(_game):
        var director: Node3D=_game.get_node("AuroraSectorMatch")
        if not director.retry_result():
            return
        var flight: Node3D=director.get("_flight") as Node3D
        if flight!=null and str(flight.get("phase")) in ["aircraft","freefall","parachute","touchdown_pending"]:
            FLIGHT_DIAGNOSTICS.checkpoint("aborted",str(flight.get("phase")),_game.get_node("Operator"),"returned_to_lobby")
        elif stage=="training":
            FLIGHT_DIAGNOSTICS.checkpoint("completed","training",_game.get_node("Operator"),
                "training_returned_to_lobby")
        var old: Node3D=_game
        _game=null
        old.get_parent().remove_child(old)
        old.queue_free()
    _hud_editor_requested=false
    _hud_editor_origin=""
    _show_lobby()


func _build_preview() -> void:
    # Real native 3D viewport, not a copied Free Fire character illustration.
    # Shows the current TEMPORARY CC0 operator. Final original Lila requires
    # separately authored mesh, UVs, hair, original outfit and refined rig.
    _preview_container=SubViewportContainer.new()
    _preview_container.name="AvatarPreview"
    _preview_container.anchor_left=.29
    _preview_container.anchor_right=.65
    _preview_container.anchor_top=.19
    _preview_container.anchor_bottom=.89
    _preview_container.stretch=true
    _preview_container.mouse_filter=Control.MOUSE_FILTER_STOP
    _preview_container.gui_input.connect(_preview_input)
    _preview_container.visible=false
    _surface.add_child(_preview_container)

    var viewport:=SubViewport.new()
    viewport.name="PreviewViewport"
    viewport.size=Vector2i(440,600)
    viewport.own_world_3d=true
    viewport.transparent_bg=true
    viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_PARENT_VISIBLE
    _preview_container.add_child(viewport)
    var stage3d:=Node3D.new()
    stage3d.name="AuroraCharacterStage"
    viewport.add_child(stage3d)
    var hangar:=LOBBY_STAGE.new()
    hangar.name="AuroraReal3DLobbyEnvironment"
    stage3d.add_child(hangar)
    var ambient:=WorldEnvironment.new()
    var env:=Environment.new()
    env.background_mode=Environment.BG_COLOR
    env.background_color=Color(.025,.06,.095)
    env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color=Color(.55,.72,.91)
    env.ambient_light_energy=.85
    ambient.environment=env
    stage3d.add_child(ambient)
    var key:=DirectionalLight3D.new()
    key.rotation_degrees=Vector3(-36,35,0)
    key.light_energy=1.25
    stage3d.add_child(key)
    var rim:=DirectionalLight3D.new()
    rim.rotation_degrees=Vector3(26,-135,0)
    rim.light_color=Color(.36,.75,1)
    rim.light_energy=.85
    stage3d.add_child(rim)
    var camera:=Camera3D.new()
    camera.name="LobbyPortraitCamera"
    camera.position=Vector3(0,1.22,3.45)
    camera.fov=39
    camera.current=true
    stage3d.add_child(camera)
    camera.look_at(Vector3(0,.88,0),Vector3.UP)
    var podium:=MeshInstance3D.new()
    podium.name="PortraitPlatform"
    var disk:=CylinderMesh.new()
    disk.top_radius=1.0
    disk.bottom_radius=1.08
    disk.height=.09
    podium.mesh=disk
    podium.position.y=-.055
    var metal:=StandardMaterial3D.new()
    metal.albedo_color=Color(.045,.22,.32)
    metal.metallic=.65
    metal.roughness=.25
    podium.material_override=metal
    stage3d.add_child(podium)

    if ResourceLoader.exists("res://assets/characters/aurora_operator.glb"):
        var source:=load("res://assets/characters/aurora_operator.glb") as PackedScene
        if source!=null:
            _preview_avatar=source.instantiate() as Node3D
            _preview_avatar.name="ProvisionalRig3D"
            stage3d.add_child(_preview_avatar)
            _fit_avatar_for_preview(_preview_avatar)
            var anim:=_preview_avatar.find_child("AnimationPlayer",true,false) as AnimationPlayer
            # Lobby has no equipped hand-held rifle. Playing the armed grip
            # without a model made Lila's empty palms look glued together.
            # Use the real relaxed skeletal idle here; the actual match
            # keeps its weapon-ready and ADS animation states.
            if anim and anim.has_animation("AuroraIdle"):
                anim.play("AuroraIdle")
                anim.advance(.1)

    var caption:=Label.new()
    caption.name="PreviewDisclosure"
    caption.text="LILA  •  MODELO 3D PROVISIONAL   ↻ DESLIZA PARA GIRAR"
    caption.anchor_left=.29
    caption.anchor_right=.65
    caption.anchor_top=.90
    caption.anchor_bottom=.90
    caption.offset_bottom=35
    caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    caption.add_theme_font_size_override("font_size",13)
    caption.add_theme_color_override("font_color",Color(.62,.84,.96))
    caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
    caption.visible=false
    _surface.add_child(caption)
    _preview_caption=caption


func _fit_avatar_for_preview(visual: Node3D) -> void:
    var min_y: float=INF
    var max_y: float=-INF
    var min_z: float=INF
    var max_z: float=-INF
    for item in visual.find_children("*","MeshInstance3D",true,false):
        var mesh:=item as MeshInstance3D
        var aabb:=mesh.get_aabb()
        for i in range(8):
            var vertex: Vector3=visual.to_local(mesh.to_global(aabb.get_endpoint(i)))
            min_y=minf(min_y,vertex.y)
            max_y=maxf(max_y,vertex.y)
            min_z=minf(min_z,vertex.z)
            max_z=maxf(max_z,vertex.z)
    if not is_finite(min_y) or not is_finite(max_y) or not is_finite(max_z):
        return
    var is_z_up: bool=(max_z-min_z)>(max_y-min_y)*1.22
    var length: float=(max_z-min_z) if is_z_up else (max_y-min_y)
    if length<=.001:
        return
    var factor: float=clampf(1.76/length,.00001,100.0)
    visual.scale=Vector3.ONE*factor
    if is_z_up:
        visual.rotation.x=PI*.5
        visual.position.y=max_z*factor
    else:
        visual.position.y=-min_y*factor
    # Unlike TPS gameplay, the lobby preview faces the viewer.
    visual.rotation.y=0.0


func _game_active() -> bool:
    return _game!=null and is_instance_valid(_game)

func _layout_safe() -> void:
    var safe: Rect2=SAFE_SCREEN.rect(get_viewport())
    _surface.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    _surface.position=safe.position
    _surface.size=safe.size
    # Nine tabs must fit a 434px-tall Motorola landscape viewport.
    if _lobby_nav!=null and is_instance_valid(_lobby_nav):
        var compact: bool=safe.size.y<620.0
        for button in _lobby_nav.get_children():
            if button is Button:
                button.custom_minimum_size.y=30.0 if compact else 43.0
                button.add_theme_font_size_override(
                    "font_size",12 if compact else 18)


func _build_settings() -> void:
    _settings_panel=VBoxContainer.new()
    _settings_panel.name="CameraSettings"
    _settings_panel.add_theme_constant_override("separation",4)
    _page.add_child(_settings_panel)
    var hud_edit_button:=_button("EDITAR CONTROLES / HUD",
        Callable(self,"_launch_hud_editor"),235)
    hud_edit_button.name="EditHUDEntry"
    hud_edit_button.custom_minimum_size.y=40
    hud_edit_button.add_theme_font_size_override("font_size",14)
    _settings_panel.add_child(hud_edit_button)
    var settings_entry:=_button("AJUSTES COMPLETOS",
        Callable(self,"_open_settings"),235)
    settings_entry.name="FullSettingsEntry"
    settings_entry.custom_minimum_size.y=39
    _settings_panel.add_child(settings_entry)
    # A scrollable control section avoids hiding mobile HUD buttons or running
    # past the screen edge when a phone uses 16:9 or a taller aspect ratio.
    var settings_scroll:=ScrollContainer.new()
    settings_scroll.name="MobileSettingsScroll"
    settings_scroll.custom_minimum_size=Vector2(0,170)
    settings_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
    _settings_panel.add_child(settings_scroll)
    _settings_content=VBoxContainer.new()
    _settings_content.add_theme_constant_override("separation",3)
    _settings_content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    settings_scroll.add_child(_settings_content)
    _look_slider=_sensitivity_slider("Giro panorámico",_preferences.look)
    _ads_slider=_sensitivity_slider("Miras ADS",_preferences.ads)
    _scope_sliders.clear()
    var scope_labels: Dictionary={
        "red_dot":"Punto rojo",
        "scope_2x":"Mira 2x",
        "scope_4x":"Mira 4x",
        "scope_8x":"AWM 8x"
    }
    for key in ["red_dot","scope_2x","scope_4x","scope_8x"]:
        _scope_sliders[key]=_scope_slider(str(scope_labels[key]),
            float(_mobile_options.sensitivity[key]))
    var audio_cfg:=ConfigFile.new()
    audio_cfg.load("user://aurora_audio.cfg")
    _sfx_slider=_volume_slider("Efectos",float(audio_cfg.get_value("audio","effects",.75)))
    _ambience_slider=_volume_slider("Ambiente",float(audio_cfg.get_value("audio","ambience",.55)))
    var graphics_row:=HBoxContainer.new()
    _settings_content.add_child(graphics_row)
    var graphics_label:=Label.new()
    graphics_label.text="Límite de FPS"
    graphics_label.custom_minimum_size.x=145
    graphics_row.add_child(graphics_label)
    _graphics_selector=OptionButton.new()
    _graphics_selector.name="GraphicsPresetFPS"
    _graphics_selector.add_item("Baja / 30 FPS")
    _graphics_selector.add_item("Media / 45 FPS")
    _graphics_selector.add_item("Alta / 60 FPS")
    _graphics_selector.add_item("Ultra / 90 FPS")
    _graphics_selector.add_item("Extrema / 120 FPS")
    _graphics_selector.select(PLAYER_SETTINGS.GRAPHICS_PRESETS.find(
        _mobile_options.graphics_preset))
    _graphics_selector.custom_minimum_size=Vector2(112,37)
    _graphics_selector.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _graphics_selector.item_selected.connect(func(_selected: int): _save_timer.start())
    graphics_row.add_child(_graphics_selector)
    var refresh_label:=Label.new()
    refresh_label.name="ActualScreenRefreshRate"
    var hz: float=DisplayServer.screen_get_refresh_rate()
    refresh_label.text="Pantalla %.0f Hz"%hz if hz>0.0 else "Hz no detectados"
    refresh_label.clip_text=true
    refresh_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    refresh_label.add_theme_font_size_override("font_size",12)
    _settings_content.add_child(refresh_label)
    _settings_status=Label.new()
    _settings_status.text="Ajustes recuperados del respaldo" if _preferences.recovered or _mobile_options.recovered else "Se guardan en este dispositivo"
    _settings_status.add_theme_font_size_override("font_size",14)
    _settings_panel.add_child(_settings_status)
    _settings_panel.visible=false


func _sensitivity_slider(title: String,value: float) -> HSlider:
    var row:=HBoxContainer.new()
    _settings_content.add_child(row)
    var label:=Label.new()
    label.custom_minimum_size.x=145
    label.text=title+"  %.2fx"%value
    row.add_child(label)
    var slider:=HSlider.new()
    slider.min_value=.35
    slider.max_value=2.0
    slider.step=.05
    slider.value=value
    slider.custom_minimum_size=Vector2(112,37)
    slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    row.add_child(slider)
    slider.value_changed.connect(func(next: float):
        label.text=title+"  %.2fx"%next
        _save_timer.start())
    return slider


func _scope_slider(title: String,value: float) -> HSlider:
    var row:=HBoxContainer.new()
    _settings_content.add_child(row)
    var label:=Label.new()
    label.custom_minimum_size.x=145
    label.text=title+"  %d"%roundi(value)
    row.add_child(label)
    var slider:=HSlider.new()
    slider.min_value=0.0
    slider.max_value=200.0
    slider.step=1.0
    slider.value=value
    slider.custom_minimum_size=Vector2(112,37)
    slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    row.add_child(slider)
    slider.value_changed.connect(func(next: float):
        label.text=title+"  %d"%roundi(next)
        _save_timer.start())
    return slider


func _volume_slider(title: String,level: float) -> HSlider:
    var row:=HBoxContainer.new()
    _settings_content.add_child(row)
    var label:=Label.new()
    label.custom_minimum_size.x=145
    label.text=title+"  %d%%"%roundi(level*100.0)
    row.add_child(label)
    var slider:=HSlider.new()
    slider.min_value=0.0
    slider.max_value=1.0
    slider.step=.05
    slider.value=level
    slider.custom_minimum_size=Vector2(112,37)
    slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    row.add_child(slider)
    slider.value_changed.connect(func(next: float):
        label.text=title+"  %d%%"%roundi(next*100.0)
        _save_timer.start())
    return slider


func _save_preferences() -> void:
    _save_timer.stop()
    if not is_instance_valid(_look_slider) or not is_instance_valid(_ads_slider):
        return
    var result: Error=_preferences.save(_look_slider.value,_ads_slider.value)
    var scope_values: Dictionary={
        "general":_look_slider.value*100.0,
        "ads":_ads_slider.value*100.0
    }
    for key in _scope_sliders:
        if is_instance_valid(_scope_sliders[key]):
            scope_values[key]=_scope_sliders[key].value
    var scope_result: Error=_mobile_options.save_sensitivity(scope_values)
    var graphics_result: Error=ERR_INVALID_PARAMETER
    if is_instance_valid(_graphics_selector):
        var preset_names: Array[String]=PLAYER_SETTINGS.GRAPHICS_PRESETS
        var selected_index: int=_graphics_selector.selected
        if selected_index>=0 and selected_index<preset_names.size():
            graphics_result=_mobile_options.save_graphics(preset_names[selected_index])
            if graphics_result==OK:
                Engine.max_fps=_mobile_options.fps_limit()
    var audio_cfg:=ConfigFile.new()
    audio_cfg.load("user://aurora_audio.cfg")
    audio_cfg.set_value("audio","effects",_sfx_slider.value)
    audio_cfg.set_value("audio","ambience",_ambience_slider.value)
    var audio_result: Error=audio_cfg.save("user://aurora_audio.cfg")
    _settings_status.text="Ajustes guardados" if result==OK and scope_result==OK and graphics_result==OK and audio_result==OK else "No se pudieron guardar todos los ajustes"
