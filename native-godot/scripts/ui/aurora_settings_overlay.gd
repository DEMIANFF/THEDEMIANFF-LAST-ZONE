extends CanvasLayer
## Real shared settings overlay for lobby, training, and Battle Royale.
## Preserves the same live scene while paused; no fake network/account toggles.
signal closed
signal hud_editor_requested
const PLAYER_SETTINGS=preload("res://scripts/persistence/player_settings.gd")
const HUD_LAYOUT=preload("res://scripts/persistence/hud_layout.gd")
const MATCH_RECORDS=preload("res://scripts/persistence/offline_match_records.gd")
const LOCAL_PROFILE_EXPORT=preload("res://scripts/persistence/local_profile_export.gd")
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
var _category_buttons: Dictionary={}
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
    backdrop.color=Color(.008,.018,.040,.94)
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
    skin.bg_color=Color(.019,.036,.078,.98)
    skin.border_color=Color(.30,.73,.92)
    skin.set_border_width_all(2)
    skin.set_corner_radius_all(12)
    skin.shadow_color=Color(.0,.0,.0,.46)
    skin.shadow_size=5
    panel.add_theme_stylebox_override("panel",skin)
    add_child(panel)
    var padding:=MarginContainer.new()
    padding.name="AuroraSettingsSafeMargin"
    padding.add_theme_constant_override("margin_left",12)
    padding.add_theme_constant_override("margin_right",12)
    padding.add_theme_constant_override("margin_top",10)
    padding.add_theme_constant_override("margin_bottom",10)
    panel.add_child(padding)
    var main:=VBoxContainer.new()
    main.add_theme_constant_override("separation",8)
    padding.add_child(main)
    var title:=HBoxContainer.new()
    main.add_child(title)
    var heading:=Label.new()
    heading.text="THEDEMIAN  /  AJUSTES    ·    "+context_origin.to_upper()
    heading.add_theme_font_size_override("font_size",23)
    heading.add_theme_color_override("font_color",Color(.98,.82,.42))
    heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    title.add_child(heading)
    _make_button(title,"CERRAR  ×",_close)
    var columns:=HBoxContainer.new()
    columns.size_flags_vertical=Control.SIZE_EXPAND_FILL
    columns.add_theme_constant_override("separation",16)
    main.add_child(columns)
    var sidebar:=VBoxContainer.new()
    sidebar.custom_minimum_size.x=181
    sidebar.add_theme_constant_override("separation",6)
    columns.add_child(sidebar)
    for category in ["PARTIDA","PANTALLA","SONIDO","CUENTA"]:
        var current: String=category
        var tab:=_make_button(sidebar,category,func(): _show_category(current))
        if category=="PARTIDA":
            tab.text="HUD / CONTROLES"
        tab.name="AuroraCategory"+current
        tab.tooltip_text="Abrir configuración de "+current.to_lower()
        _category_buttons[current]=tab
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
    style.bg_color=Color(.045,.070,.128,.98)
    style.border_color=Color(.27,.42,.65,.9)
    style.set_border_width_all(1)
    style.set_corner_radius_all(5)
    button.add_theme_stylebox_override("normal",style)
    button.add_theme_stylebox_override("hover",style)
    var pressed_style:=style.duplicate() as StyleBoxFlat
    pressed_style.bg_color=Color(.16,.23,.34)
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
    for key in _category_buttons:
        var button: Button=_category_buttons[key] as Button
        if button==null:
            continue
        var selected: bool=str(key)==category
        button.modulate=Color.WHITE if selected else Color(.71,.79,.89)
        button.add_theme_color_override("font_color",
            Color(1,.83,.49) if selected else Color(.86,.93,1))
    for previous in _content.get_children():
        _content.remove_child(previous)
        previous.queue_free()
    match category:
        "PARTIDA":
            _heading("DURANTE LAS PARTIDAS")
            var sections:=HBoxContainer.new()
            sections.add_theme_constant_override("separation",4)
            _content.add_child(sections)
            for tab in ["HUD","SENSIBILIDAD","VIBRACIÓN","INFORMACIÓN"]:
                var selected: String=tab
                var btn:=_make_button(sections,tab,func(): _show_subcategory(selected))
                btn.custom_minimum_size=Vector2(100,42)
            _populate_subcategory()
        "PANTALLA":
            _screen_page()
        "SONIDO":
            _sound_page()
        "CUENTA":
            _account_page()


func _show_subcategory(tab: String) -> void:
    # Older internal calls still reach the canonical HUD editor, but no
    # duplicate CONTROLES tab or second button is displayed.
    _subcategory="HUD" if tab=="CONTROLES" else tab
    _show_category("PARTIDA")


func _populate_subcategory() -> void:
    match _subcategory:
        "HUD":
            _heading("HUD / CUATRO DISEÑOS GUARDADOS")
            _info("Elige un HUD y personaliza posición, tamaño y opacidad. Tus cuatro diseños se guardan por separado.")
            var preset:=OptionButton.new()
            preset.name="HUDPresetSelector"
            for index in range(1,5):
                preset.add_item("HUD "+str(index),index)
            preset.select(HUD_LAYOUT.selected_preset()-1)
            preset.item_selected.connect(_select_hud_preset)
            _content.add_child(preset)
            var aurora_layout:=_make_button(_content,
                "APLICAR HUD AURORA / ESPACIO 4",_use_aurora_reference)
            aurora_layout.name="ApplyAuroraHudReference"
            aurora_layout.tooltip_text="Distribución táctil Aurora: joystick izquierdo, disparo a la derecha y controles separados. Nunca sustituye los espacios 1-3."
            var edit:=_make_button(_content,"PERSONALIZAR HUD",func(): hud_editor_requested.emit())
            edit.name="EditCurrentHud"
            _info("Al cerrar el editor vuelves exactamente al lobby, entrenamiento o partida desde donde lo abriste.")
        "INFORMACIÓN":
            _heading("INFORMACIÓN DE PARTIDA")
            if context_game!=null:
                var director: Node3D=context_game.get_node_or_null("AuroraSectorMatch")
                if director!=null:
                    _info("Modo actual: "+str(director.get("mode"))+"  ·  Tiempo: "+str(int(director.get("elapsed")))+" s")
                    _info("Radio zona: "+str(roundi(float(director.get("radius"))))+" m")
            else:
                _info("Lobby: ningún combate iniciado. El editor de HUD no registra partidas ni consumos.")
            # Do not repeat the obsolete V75.20 8-bot training count.
            # Classic BR has 1 human + 49 real offline IA at match start;
            # training is separate and must not claim a 50-body roster.
            var in_br: bool=false
            var current_fighters: int=0
            if context_game!=null:
                var match_director: Node3D=context_game.get_node_or_null(
                    "AuroraSectorMatch")
                in_br=(match_director!=null and
                    str(match_director.get("mode"))=="sector_battle")
                if in_br:
                    var battle: Node3D=context_game.get_node_or_null(
                        "CombatRange")
                    if battle!=null:
                        current_fighters=int(battle.call(
                            "active_fighter_count"))
            if context_game==null:
                _info("CLÁSICO LOCAL: 50 PARTICIPANTES al comenzar (1 jugador + 49 IA). Entrenamiento separado. No hay escuadras online simuladas.")
            elif in_br:
                _info("BR CLÁSICO LOCAL: 50 PARTICIPANTES al comenzar (1 jugador + 49 IA). Supervivientes actuales: %d. Sin emparejamiento online."%current_fighters)
            else:
                _info("ENTRENAMIENTO LOCAL: controles y disparo de prueba. No es una partida clasificatoria ni un servidor online.")
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
                diagnostic+="\nGPU %s / RENDER CPU %.1f ms / FÍSICA %.1f ms"%[
                    ("%.1f ms"%float(measured.get("gpu_render_ms",0.0))
                        if bool(measured.get("gpu_timing_available",false)) else "sin dato"),
                    float(measured.get("render_cpu_ms",0.0)),
                    float(measured.get("physics_ms",0.0))]
                diagnostic+="\nTRIÁNGULOS %d / VRAM %.0f MB / RIVALES ANIMADOS %d"%[
                    int(measured.get("triangles",0)),float(measured.get("video_memory_mb",0.0)),
                    int(measured.get("active_enemy_rigs",0))]
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
    _info("AUTO ajusta el render 3D según la carga gráfica. "
        +"El HUD conserva resolución nativa y el límite de FPS no garantiza "
        +"el rendimiento medido en partidas locales de 50 participantes.")
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
    _heading("ESCALA DE RESOLUCIÓN 3D")
    _info("Ajuste manual para el mundo 3D de la partida. "
        +"No cambia el tamaño del HUD ni mueve tus cuatro diseños guardados. "
        +"Elige entre 65% y 100%; aplicar una escala menor no garantiza más FPS.")
    var scale_label:=Label.new()
    scale_label.name="AuroraCustom3DScaleValue"
    scale_label.text="ESCALA 3D %d%%"%roundi(
        RENDER_BUDGET.read_custom_scale()*100.0)
    _content.add_child(scale_label)
    var scale_slider:=HSlider.new()
    scale_slider.name="AuroraCustom3DScale"
    scale_slider.min_value=65.0
    scale_slider.max_value=100.0
    scale_slider.step=5.0
    scale_slider.value=RENDER_BUDGET.read_custom_scale()*100.0
    scale_slider.custom_minimum_size=Vector2(230,40)
    scale_slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    scale_slider.value_changed.connect(func(value: float):
        scale_label.text="ESCALA 3D %d%%"%roundi(value))
    # Save on drag release: no per-frame ConfigFile writes on Android.
    scale_slider.drag_ended.connect(func(changed: bool):
        if not changed:
            return
        var value: float=scale_slider.value/100.0
        var budget: Node=context_game.get_node_or_null(
            "AuroraRenderBudget") if context_game!=null else null
        var result: Error=(
            budget.call("select_custom_scale",value)
            if budget!=null else RENDER_BUDGET.save_custom_scale(value))
        if result!=OK:
            _status.text="ERROR al guardar escala 3D"
            return
        quality.select(RENDER_BUDGET.PROFILES.find("PERSONALIZADO"))
        _status.text="Escala 3D guardada: %d%% · HUD intacto"%roundi(
            RENDER_BUDGET.read_custom_scale()*100.0))
    _content.add_child(scale_slider)
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
    if bus=="Music":
        AuroraLobbyMusic.set_mix(level)
        return
    if context_game==null:
        return
    var sound: Node3D=context_game.get_node_or_null("AuroraSoundStage")
    if sound!=null:
        sound.call("set_mix",bus,level)


func _sound_page() -> void:
    _heading("AUDIO DEL JUEGO")
    _volume_slider("Sonido de combate","effects",.75,"AuroraSFX")
    _volume_slider("Ambiente","ambience",.55,"AuroraAmbience")
    _volume_slider("Pasos","steps",.70,"AuroraSteps")
    _volume_slider("Música del lobby","music",.55,"Music")
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


func _use_aurora_reference() -> void:
    # Install only in empty slot 4. Existing user edits in that slot survive.
    var layout: RefCounted=HUD_LAYOUT.new(HUD_LAYOUT.slot_path(4))
    if layout.controls.is_empty():
        var created: Error=layout.install_aurora_reference()
        if created!=OK:
            _status.text="ERROR al guardar diseño Aurora: "+str(created)
            return
    var result: Error=HUD_LAYOUT.choose_preset(4)
    if result!=OK:
        _status.text="ERROR al seleccionar espacio HUD 4"
        return
    if context_game!=null:
        var hud: CanvasLayer=context_game.get_node_or_null("TrainingHUD")
        if hud!=null:
            hud.call("reload_hud_layout")
    _show_subcategory("HUD")
    _status.text="HUD AURORA activado en espacio 4 · diseño editable y persistente"


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
    _heading("AUTORRESPALDO DE PARTIDAS")
    var backup= MATCH_RECORDS.new()
    var state: Dictionary=backup.auto_backup_status()
    _info("Copia local: %d partidas. Estado: %s"%[
        int(state.get("played",0)),
        "ACTUALIZADA" if bool(state.get("in_sync",false)) else "SIN ACTUALIZAR"])
    _info("Se crea después de un resultado guardado y ayuda ante archivos dañados. "
        +"No sobrevive a desinstalación; no es una copia Firebase.")
    _make_button(_content,"VERIFICAR / ACTUALIZAR RESPALDO LOCAL",
        _refresh_local_profile_backup)
    _heading("PAQUETE DE PROGRESO LOCAL (PREPARACIÓN FIREBASE)")
    _info("Genera un archivo privado versionado con partidas reales. "
        +"Excluye monedas y diamantes y no se envía a Internet. "
        +"La copia sigue dentro del juego y se pierde al desinstalar.")
    _make_button(_content,"GENERAR PAQUETE LOCAL VERIFICADO",
        _export_profile_snapshot)
    _make_button(_content,"COMPROBAR PAQUETE DE PROGRESO",
        _verify_profile_snapshot)
    _heading("VISIBILIDAD Y SEGURIDAD")
    _info("Espectadores, privacidad de clasificación, amigos y gestión de cuentas online estarán disponibles cuando exista el servicio multijugador.")
    _info("No hay botones de desvincular, borrar cuenta o iniciar sesión ficticios. Los datos existentes de Firebase no se modifican.")


func _refresh_local_profile_backup() -> void:
    var backup= MATCH_RECORDS.new()
    if not backup.refresh_auto_backup():
        _status.text="No hay un perfil guardado válido para copiar"
        return
    var state: Dictionary=backup.auto_backup_status()
    _status.text="Copia local verificada: %d partidas"%int(
        state.get("played",0)) if bool(state.get("in_sync",false)) else (
        "No se pudo comprobar la copia local")


func _export_profile_snapshot() -> void:
    var result: Dictionary=LOCAL_PROFILE_EXPORT.create()
    if bool(result.get("valid",false)):
        _status.text="Paquete local verificado: %d partidas. Sin subir a Firebase."%int(
            result.get("played",0))
    else:
        _status.text="No se pudo generar el paquete local: "+str(
            result.get("reason","error"))


func _verify_profile_snapshot() -> void:
    var result: Dictionary=LOCAL_PROFILE_EXPORT.inspect()
    if bool(result.get("valid",false)):
        _status.text="Paquete local válido: %d partidas. Sin respaldo remoto."%int(
            result.get("played",0))
    else:
        _status.text="Paquete local no verificado: "+str(
            result.get("reason","error"))


func _backup_local_settings() -> void:
    var cfg:=ConfigFile.new()
    for key in PLAYER_SETTINGS.CAMERA_KEYS:
        cfg.set_value("sensibilidad",key,float(_options.sensitivity[key]))
    cfg.set_value("graficos","preset",_options.graphics_preset)
    var audio_defaults: Dictionary={"effects":.75,"ambience":.55,"steps":.70,"music":.55}
    for key in audio_defaults:
        cfg.set_value("audio",key,float(_audio.get_value("audio",key,audio_defaults[key])))
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
    # Old backups did not carry independent step/music controls.
    for key in ["steps","music"]:
        if cfg.has_section_key("audio",key):
            _audio.set_value("audio",key,clampf(float(cfg.get_value("audio",key)),0.0,1.0))
    _audio.save(AUDIO_PATH)
    _apply_live_audio("AuroraSFX",float(_audio.get_value("audio","effects",.75)))
    _apply_live_audio("AuroraAmbience",float(_audio.get_value("audio","ambience",.55)))
    _apply_live_audio("AuroraSteps",float(_audio.get_value("audio","steps",.70)))
    _apply_live_audio("Music",float(_audio.get_value("audio","music",.55)))
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
