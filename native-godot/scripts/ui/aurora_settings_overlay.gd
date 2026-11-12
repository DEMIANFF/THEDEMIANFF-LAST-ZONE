extends CanvasLayer
## Real shared settings overlay for lobby, training, and Battle Royale.
## Preserves the same live scene while paused; no fake network/account toggles.
signal closed
signal hud_editor_requested
const PLAYER_SETTINGS=preload("res://scripts/persistence/player_settings.gd")
const HUD_LAYOUT=preload("res://scripts/persistence/hud_layout.gd")
const RENDER_BUDGET=preload("res://scripts/render/aurora_render_budget.gd")
const UI_PATH: String="user://aurora_ui_options.cfg"
const AUDIO_PATH: String="user://aurora_audio.cfg"
const BACKUP_PATH: String="user://aurora_local_settings_export.cfg"

var context_game: Node3D
var context_origin: String="lobby"
var _options: RefCounted
var _audio: ConfigFile
var _ui: ConfigFile
var _content: VBoxContainer
var _status: Label
var _category: String="PARTIDA"
var _subcategory: String="HUD"
var _closing: bool=false


func _ready() -> void:
    process_mode=Node.PROCESS_MODE_ALWAYS
    layer=150
    _options=PLAYER_SETTINGS.new()
    _audio=ConfigFile.new()
    _audio.load(AUDIO_PATH)
    _ui=ConfigFile.new()
    _ui.load(UI_PATH)
    var backdrop:=ColorRect.new()
    backdrop.name="SettingsScrim"
    backdrop.color=Color(.014,.012,.025,.97)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter=Control.MOUSE_FILTER_STOP
    add_child(backdrop)
    var panel:=PanelContainer.new()
    panel.name="SettingsWindow"
    panel.anchor_left=.045
    panel.anchor_right=.955
    panel.anchor_top=.04
    panel.anchor_bottom=.965
    var skin:=StyleBoxFlat.new()
    skin.bg_color=Color(.075,.065,.088,.98)
    skin.border_color=Color(.80,.53,.16)
    skin.set_border_width_all(2)
    skin.set_corner_radius_all(9)
    panel.add_theme_stylebox_override("panel",skin)
    add_child(panel)
    var main:=VBoxContainer.new()
    main.add_theme_constant_override("separation",8)
    panel.add_child(main)
    var title:=HBoxContainer.new()
    main.add_child(title)
    var heading:=Label.new()
    heading.text="AURORA  /  AJUSTES       ·       "+context_origin.to_upper()
    heading.add_theme_font_size_override("font_size",23)
    heading.add_theme_color_override("font_color",Color(1,.78,.38))
    heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    title.add_child(heading)
    _make_button(title,"CERRAR  ×",_close)
    var columns:=HBoxContainer.new()
    columns.size_flags_vertical=Control.SIZE_EXPAND_FILL
    columns.add_theme_constant_override("separation",16)
    main.add_child(columns)
    var sidebar:=VBoxContainer.new()
    sidebar.custom_minimum_size.x=210
    sidebar.add_theme_constant_override("separation",6)
    columns.add_child(sidebar)
    for category in ["PARTIDA","PANTALLA","SONIDO","GRABACIÓN","NOTIFICACIÓN","CUENTA"]:
        var current: String=category
        _make_button(sidebar,category,func(): _show_category(current))
    var scroll:=ScrollContainer.new()
    scroll.name="SettingsScroll"
    scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
    columns.add_child(scroll)
    _content=VBoxContainer.new()
    _content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _content.add_theme_constant_override("separation",9)
    scroll.add_child(_content)
    _status=Label.new()
    _status.text="Ajustes locales persistentes · la partida permanece en pausa"
    _status.add_theme_font_size_override("font_size",13)
    _status.add_theme_color_override("font_color",Color(.74,.85,.89))
    main.add_child(_status)
    _show_category("PARTIDA")
    get_tree().paused=true


func _make_button(parent: Node,text_value: String,pressed: Callable) -> Button:
    var button:=Button.new()
    button.text=text_value
    button.focus_mode=Control.FOCUS_NONE
    button.custom_minimum_size=Vector2(160,42)
    button.add_theme_font_size_override("font_size",15)
    var style:=StyleBoxFlat.new()
    style.bg_color=Color(.16,.14,.19,.98)
    style.border_color=Color(.44,.43,.48,.9)
    style.set_border_width_all(1)
    style.set_corner_radius_all(5)
    button.add_theme_stylebox_override("normal",style)
    button.add_theme_stylebox_override("hover",style)
    var pressed_style:=style.duplicate() as StyleBoxFlat
    pressed_style.bg_color=Color(.38,.26,.13)
    button.add_theme_stylebox_override("pressed",pressed_style)
    parent.add_child(button)
    button.pressed.connect(pressed)
    return button


func _heading(value: String) -> void:
    var label:=Label.new()
    label.text=value
    label.add_theme_font_size_override("font_size",18)
    label.add_theme_color_override("font_color",Color(1,.75,.30))
    _content.add_child(label)


func _info(value: String) -> void:
    var label:=Label.new()
    label.text=value
    label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size",14)
    label.add_theme_color_override("font_color",Color(.84,.89,.91))
    _content.add_child(label)


func _show_category(category: String) -> void:
    _category=category
    for previous in _content.get_children():
        _content.remove_child(previous)
        previous.queue_free()
    match category:
        "PARTIDA":
            _heading("DURANTE LAS PARTIDAS")
            var sections:=HBoxContainer.new()
            sections.add_theme_constant_override("separation",4)
            _content.add_child(sections)
            for tab in ["HUD","CONTROLES","INFORMACIÓN","SENSIBILIDAD","VIBRACIÓN"]:
                var selected: String=tab
                var btn:=_make_button(sections,tab,func(): _show_subcategory(selected))
                btn.custom_minimum_size=Vector2(100,42)
            _populate_subcategory()
        "PANTALLA":
            _screen_page()
        "SONIDO":
            _sound_page()
        "GRABACIÓN":
            _heading("GRABACIÓN")
            _info("La grabación de partidas requiere integración Android. En esta compilación no hay grabador interno; utiliza la grabación de pantalla del dispositivo.")
        "NOTIFICACIÓN":
            _heading("NOTIFICACIONES LOCALES")
            _info("Los avisos de daño, munición y zona siguen activos durante el combate. Las notificaciones de amistades y eventos online no están disponibles en este modo offline.")
            _toggle("Mostrar contador de FPS","show_fps",true)
        "CUENTA":
            _account_page()


func _show_subcategory(tab: String) -> void:
    _subcategory=tab
    _show_category("PARTIDA")


func _populate_subcategory() -> void:
    match _subcategory:
        "HUD":
            _heading("HUD / CUATRO DISEÑOS GUARDADOS")
            _info("Selecciona un espacio y edita posiciones, tamaños y opacidad de los botones reales. El HUD 1 conserva tu diseño anterior.")
            var preset:=OptionButton.new()
            preset.name="HUDPresetSelector"
            for index in range(1,5):
                preset.add_item("HUD "+str(index),index)
            preset.select(HUD_LAYOUT.selected_preset()-1)
            preset.item_selected.connect(_select_hud_preset)
            _content.add_child(preset)
            var edit:=_make_button(_content,"PERSONALIZAR HUD",func(): hud_editor_requested.emit())
            edit.name="EditCurrentHud"
            _info("Al cerrar el editor vuelves exactamente al lobby, entrenamiento o partida desde donde lo abriste.")
        "CONTROLES":
            _heading("CONTROLES TÁCTILES REALES")
            _info("Joystick analógico izquierdo · correr alternable · arrastrar para disparar y apuntar · salto, agacharse, recarga, mochila y barrera. El editor permite mover cada botón y guardar su escala.")
            _make_button(_content,"EDITAR POSICIÓN DE CONTROLES",func(): hud_editor_requested.emit())
        "INFORMACIÓN":
            _heading("INFORMACIÓN DE PARTIDA")
            if context_game!=null:
                var director: Node3D=context_game.get_node_or_null("AuroraSectorMatch")
                if director!=null:
                    _info("Modo actual: "+str(director.get("mode"))+"  ·  Tiempo: "+str(int(director.get("elapsed")))+" s")
                    _info("Radio zona: "+str(roundi(float(director.get("radius"))))+" m")
            else:
                _info("Lobby: ningún combate iniciado. El editor de HUD no registra partidas ni consumos.")
            _info("Modo offline · 1 jugador y 8 bots. No se muestran escuadras online simuladas.")
        "SENSIBILIDAD":
            _heading("SENSIBILIDAD DE CÁMARA Y MIRAS")
            for item in [
                ["general","General"],["red_dot","Punto rojo"],
                ["scope_2x","Mira 2x"],["scope_4x","Mira 4x"],
                ["scope_8x","Francotirador AWM x8"],["ads","Arrastre ADS"]]:
                _sensitivity_row(str(item[0]),str(item[1]))
        "VIBRACIÓN":
            _heading("RESPUESTA HÁPTICA")
            _toggle("Vibración breve al disparar","vibration",false)
            _info("Solo funcionará si Android y el dispositivo permiten vibración.")


func _sensitivity_row(key: String,title: String) -> void:
    var box:=HBoxContainer.new()
    _content.add_child(box)
    var label:=Label.new()
    label.text=title+"  "+str(roundi(float(_options.sensitivity[key])))
    label.custom_minimum_size.x=205
    box.add_child(label)
    var slider:=HSlider.new()
    slider.name="Sensitivity_"+key
    slider.min_value=0
    slider.max_value=200
    slider.step=1
    slider.value=float(_options.sensitivity[key])
    slider.custom_minimum_size=Vector2(140,38)
    slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    box.add_child(slider)
    slider.value_changed.connect(func(value: float):
        label.text=title+"  "+str(roundi(value))
        var error: Error=_options.save_sensitivity({key:value})
        if error==OK:
            _update_live_player()
            _status.text="Sensibilidad guardada: "+title
        else:
            _status.text="ERROR: sensibilidad no guardada")


func _update_live_player() -> void:
    if context_game==null:
        return
    var player: CharacterBody3D=context_game.get_node_or_null("Operator") as CharacterBody3D
    if player==null:
        return
    player.set("look_multiplier",_options.multiplier("general"))
    player.set("ads_multiplier",_options.multiplier("ads"))
    var sensitivities: Dictionary=player.get("_scope_sensitivity")
    for scope in ["red_dot","scope_2x","scope_4x","scope_8x"]:
        sensitivities[scope]=_options.multiplier(scope)
    player.set("_scope_sensitivity",sensitivities)


func _screen_page() -> void:
    _heading("PANTALLA / RENDIMIENTO")
    # Read the ACTIVE driver, not a requested renderer. A device may fall
    # back from Vulkan to OpenGL if its driver rejects the Mobile backend.
    var method: String=RenderingServer.get_current_rendering_method()
    var driver: String=RenderingServer.get_current_rendering_driver_name()
    _info("MOTOR GRÁFICO REAL: "+method.to_upper()+" / "+driver.to_upper()+
        "\nEl límite FPS es una preferencia; los FPS medidos dependen de la GPU y la IA.")
    # Capture actual Godot and Android GPU counters, not a guessed speedup.
    if context_game!=null:
        var budget_node: Node=context_game.get_node_or_null("AuroraRenderBudget")
        if budget_node!=null:
            var measured: Dictionary=budget_node.call("snapshot")
            if float(measured.get("fps",0.0))>0.0:
                var diagnostic: String="FPS %.1f / OBJETIVO %.0f / PANEL %.0f Hz"%[
                    float(measured.get("fps",0.0)),
                    float(measured.get("target_fps",60.0)),
                    float(measured.get("refresh_hz",0.0))]
                diagnostic+="\nCPU %.1f ms / FRAME %.1f ms / %s"%[
                    float(measured.get("cpu_ms",0.0)),
                    float(measured.get("frame_ms",0.0)),
                    str(measured.get("bottleneck","NOT_SAMPLED"))]
                diagnostic+="\nDRAWS %d / OBJETOS %d / 3D %.0f%%"%[
                    int(measured.get("draw_calls",0)),
                    int(measured.get("objects",0)),
                    float(measured.get("scale",1.0))*100.0]
                _info(diagnostic)
    var graphics:=OptionButton.new()
    graphics.name="GraphicsSelector"
    for key in PLAYER_SETTINGS.GRAPHICS_PRESETS:
        graphics.add_item(key.to_upper()+" / "+str(PLAYER_SETTINGS.GRAPHICS_FPS[key])+" FPS")
    graphics.select(PLAYER_SETTINGS.GRAPHICS_PRESETS.find(_options.graphics_preset))
    graphics.item_selected.connect(func(index: int):
        var key: String=PLAYER_SETTINGS.GRAPHICS_PRESETS[index]
        var code: Error=_options.save_graphics(key)
        if code==OK:
            Engine.max_fps=_options.fps_limit()
            _status.text="Límite FPS guardado: "+str(Engine.max_fps)
        else:
            _status.text="ERROR al guardar FPS")
    _content.add_child(graphics)
    _heading("CALIDAD DE RENDER 3D / MOTOROLA")
    _info("AUTO reduce coste de render cuando caen los FPS sin saturación CPU. "
        +"Respeta la tasa física de 60/90/120 Hz. "
        +"La cámara, controles y HUD mantienen resolución nativa. "
        +"Para 20/30 rivales prueba primero EQUILIBRADO.")
    var quality:=OptionButton.new()
    quality.name="AuroraRenderQuality"
    for profile in RENDER_BUDGET.PROFILES:
        quality.add_item(profile)
    quality.select(RENDER_BUDGET.PROFILES.find(RENDER_BUDGET.read_profile()))
    quality.item_selected.connect(func(index: int):
        var selected: String=RENDER_BUDGET.PROFILES[index]
        var result: Error=RENDER_BUDGET.save_profile(selected)
        if result!=OK:
            _status.text="ERROR al guardar calidad 3D"
            return
        if context_game!=null:
            var budget: Node=context_game.get_node_or_null("AuroraRenderBudget")
            if budget:
                budget.call("select_profile",selected)
        _status.text="Calidad 3D: "+selected)
    _content.add_child(quality)
    _toggle("Mostrar FPS en partida","show_fps",true)
    _toggle("Minimapa giratorio","radar_rotation",true)
    _info("Texturas HD y efectos avanzados dependen de perfiles de exportación específicos; no se activan filtros inexistentes con este menú.")


func _volume_slider(title: String,key: String,default_value: float,bus: String) -> void:
    var row:=HBoxContainer.new()
    _content.add_child(row)
    var label:=Label.new()
    label.text=title
    label.custom_minimum_size.x=196
    row.add_child(label)
    var slider:=HSlider.new()
    slider.name="Audio_"+key
    slider.min_value=0
    slider.max_value=100
    slider.step=1
    slider.value=float(_audio.get_value("audio",key,default_value))*100.0
    slider.custom_minimum_size=Vector2(140,36)
    slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    row.add_child(slider)
    var numeric:=Label.new()
    numeric.text=str(roundi(slider.value))
    row.add_child(numeric)
    slider.value_changed.connect(func(value: float):
        numeric.text=str(roundi(value))
        _audio.set_value("audio",key,value/100.0)
        var code: Error=_audio.save(AUDIO_PATH)
        if code==OK:
            _apply_live_audio(bus,value/100.0)
            _status.text="Audio guardado: "+title
        else:
            _status.text="ERROR: audio no guardado")


func _apply_live_audio(bus: String,level: float) -> void:
    if context_game==null:
        return
    var sound: Node3D=context_game.get_node_or_null("AuroraSoundStage")
    if sound!=null:
        sound.call("set_mix",bus,level)


func _sound_page() -> void:
    _heading("AUDIO DEL JUEGO")
    _volume_slider("Sonido de combate","effects",.75,"AuroraSFX")
    _volume_slider("Ambiente","ambience",.55,"AuroraAmbience")
    _info("Música: no existe aún una pista musical licenciada/original en el cliente nativo. Las voces de personajes y emotes son futuras funciones; no se activan opciones simuladas.")
    _heading("CHAT DE VOZ Y MENSAJES")
    _info("Chat de voz requiere multijugador y permisos de micrófono. Esta versión es offline.")
    _make_button(_content,"MENSAJE RÁPIDO LOCAL",_quick_message)


func _quick_message() -> void:
    if context_game!=null:
        var hud: CanvasLayer=context_game.get_node_or_null("TrainingHUD")
        if hud!=null:
            hud.call("impact","MENSAJE LOCAL / ENEMIGOS CERCA")
    _status.text="Mensaje local mostrado; no hay red ni voz activa"


func _toggle(label_text: String,key: String,initial: bool) -> void:
    var row:=CheckButton.new()
    row.text=label_text
    row.name="Toggle_"+key
    row.button_pressed=bool(_ui.get_value("ui",key,initial))
    _content.add_child(row)
    row.toggled.connect(func(enabled: bool):
        _ui.set_value("ui",key,enabled)
        var code: Error=_ui.save(UI_PATH)
        if code==OK:
            _apply_live_ui()
            _status.text="Preferencia guardada: "+label_text
        else:
            _status.text="ERROR al guardar preferencia")


func _apply_live_ui() -> void:
    if context_game==null:
        return
    var hud: CanvasLayer=context_game.get_node_or_null("TrainingHUD")
    if hud!=null:
        hud.call("apply_ui_settings")


func _select_hud_preset(index: int) -> void:
    var code: Error=HUD_LAYOUT.choose_preset(index+1)
    if code!=OK:
        _status.text="ERROR al cambiar espacio HUD"
        return
    if context_game!=null:
        var hud: CanvasLayer=context_game.get_node_or_null("TrainingHUD")
        if hud!=null:
            hud.call("reload_hud_layout")
    _status.text="HUD "+str(index+1)+" seleccionado y guardado"


func _account_page() -> void:
    _heading("CUENTA Y BÁSICO / AURORA")
    _info("Estado: perfil local de la vista nativa. La autenticación Google/Firebase de Android anterior no está vinculada a este cliente Godot. No se simula un inicio de sesión.")
    _heading("IDIOMA")
    _info("Español (Colombia). Otros idiomas requieren traducciones verificadas.")
    _heading("HERRAMIENTAS LOCALES")
    _make_button(_content,"DESCARGAR / GUARDAR AJUSTES",_backup_local_settings)
    _make_button(_content,"CARGAR AJUSTES GUARDADOS",_restore_local_settings)
    _heading("VISIBILIDAD Y SEGURIDAD")
    _info("Espectadores, privacidad de clasificación, amigos y gestión de cuentas online estarán disponibles cuando exista el servicio multijugador.")
    _info("No hay botones de desvincular, borrar cuenta o iniciar sesión ficticios. Los datos existentes de Firebase no se modifican.")


func _backup_local_settings() -> void:
    var cfg:=ConfigFile.new()
    for key in PLAYER_SETTINGS.CAMERA_KEYS:
        cfg.set_value("sensibilidad",key,float(_options.sensitivity[key]))
    cfg.set_value("graficos","preset",_options.graphics_preset)
    for key in ["effects","ambience"]:
        cfg.set_value("audio",key,float(_audio.get_value("audio",key,.75)))
    for key in ["show_fps","radar_rotation","vibration"]:
        cfg.set_value("ui",key,bool(_ui.get_value("ui",key,key!="vibration")))
    cfg.set_value("hud","preset",HUD_LAYOUT.selected_preset())
    var result: Error=cfg.save(BACKUP_PATH)
    _status.text="Ajustes exportados al almacenamiento privado del juego" if result==OK else "ERROR al exportar ajustes"


func _restore_local_settings() -> void:
    var cfg:=ConfigFile.new()
    if cfg.load(BACKUP_PATH)!=OK:
        _status.text="No existe una exportación local válida"
        return
    var values: Dictionary={}
    for key in PLAYER_SETTINGS.CAMERA_KEYS:
        var raw: Variant=cfg.get_value("sensibilidad",key,null)
        if not (raw is int or raw is float) or float(raw)<0.0 or float(raw)>200.0:
            _status.text="Respaldo inválido: no se aplicó"
            return
        values[key]=float(raw)
    var preset: String=str(cfg.get_value("graficos","preset",""))
    var slot: int=int(cfg.get_value("hud","preset",0))
    if not PLAYER_SETTINGS.GRAPHICS_PRESETS.has(preset) or slot<1 or slot>4:
        _status.text="Respaldo incompatible: no se aplicó"
        return
    if _options.save_sensitivity(values)!=OK or _options.save_graphics(preset)!=OK:
        _status.text="No se pudieron recuperar los ajustes"
        return
    for key in ["effects","ambience"]:
        var value: float=clampf(float(cfg.get_value("audio",key,.75)),0.0,1.0)
        _audio.set_value("audio",key,value)
    _audio.save(AUDIO_PATH)
    _apply_live_audio("AuroraSFX",float(_audio.get_value("audio","effects",.75)))
    _apply_live_audio("AuroraAmbience",float(_audio.get_value("audio","ambience",.55)))
    for key in ["show_fps","radar_rotation","vibration"]:
        _ui.set_value("ui",key,bool(cfg.get_value("ui",key,key!="vibration")))
    _ui.save(UI_PATH)
    HUD_LAYOUT.choose_preset(slot)
    Engine.max_fps=_options.fps_limit()
    _apply_live_ui()
    _update_live_player()
    if context_game!=null:
        var hud: CanvasLayer=context_game.get_node_or_null("TrainingHUD")
        if hud!=null:
            hud.call("reload_hud_layout")
    _status.text="Ajustes recuperados del respaldo local"


func _close() -> void:
    _closing=true
    get_tree().paused=false
    closed.emit()
    queue_free()


func _exit_tree() -> void:
    # Never leave the real Battle Royale permanently paused on navigation
    # away from an interrupted settings session.
    if not _closing and get_tree().paused:
        get_tree().paused=false
