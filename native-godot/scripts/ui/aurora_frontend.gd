extends Control
## Original Aurora front-end. Free Fire is UX reference ONLY; no copied layout,
## assets or proprietary game branding. Incomplete service tabs say so.
const SAFE_SCREEN=preload("res://scripts/ui/safe_screen.gd")
const CAMERA_PREFERENCES=preload("res://scripts/persistence/camera_preferences.gd")
const PLAYER_SETTINGS=preload("res://scripts/persistence/player_settings.gd")
const LOBBY_BACKDROP=preload("res://scripts/ui/aurora_lobby_backdrop.gd")
const GAME = preload("res://scenes/Main.tscn")
const MATCH_RECORDS = preload("res://scripts/persistence/offline_match_records.gd")
const FLIGHT_DIAGNOSTICS=preload("res://scripts/match/flight_diagnostics.gd")

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
    _page.add_theme_constant_override("separation",12)
    _surface.add_child(_page)
    _build_preview()
    get_viewport().size_changed.connect(_layout_safe)
    _layout_safe.call_deferred()
    _welcome()


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
    style.border_color=Color(.20,.71,.89)
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
    _page.anchor_top=.10
    _page.anchor_bottom=.94
    _clear_page()
    _label("THEDEMIANFF   /   LAST ZONE",33)
    _label("AURORA  •  EL ÚLTIMO HORIZONTE",20)
    _label("Operación de supervivencia — edición de desarrollo",16)
    var enter:=_button("ENTRAR",Callable(self,"_show_lobby"))
    enter.name="EnterButton"
    _page.add_child(enter)
    _label("Esta versión prueba partidas offline. El multijugador y las cuentas en Godot todavía no están disponibles.",14)
    var trace: Dictionary=FLIGHT_DIAGNOSTICS.last()
    if str(trace.get("state",""))=="active":
        _label("VUELO ANTERIOR INTERRUMPIDO  /  "+str(trace.get("phase","desconocido")),15)
        _label("Último registro: "+str(trace.get("note",""))+"  ·  FPS "+str(trace.get("fps","?")),13)
        _page.add_child(_button("COPIAR DATOS DEL VUELO",Callable(self,"_copy_flight_diagnostics"),270))


func _copy_flight_diagnostics() -> void:
    DisplayServer.clipboard_set(FLIGHT_DIAGNOSTICS.report())


func _show_lobby() -> void:
    # Actual on-device results. No invented premium currency, fake friends or fake cloud ID.
    _offline_records=MATCH_RECORDS.new()
    var stats: Dictionary=_offline_records.snapshot()
    if _preview_container==null or not is_instance_valid(_preview_container):
        _build_preview()
    stage="lobby"
    visible=true
    _page.anchor_left=.67
    _page.anchor_right=.97
    _page.anchor_top=.18
    _page.anchor_bottom=.92
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
    _profile_strip.text="THEDEMIANFF  /  LAST ZONE     •     PERFIL LOCAL     •     %d PARTIDAS     •     %d VICTORIAS"%[int(stats.get("played",0)),int(stats.get("wins",0))]
    _clear_page()
    _label("BASE AURORA",29)
    _label("OPERACIÓN ÚLTIMA ZONA",16)
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
    _label("SECTOR OFFLINE  •  1 JUGADOR + 8 BOTS",13)
    _info=_label("",16)
    _info.name="LobbyDetail"
    _build_settings()
    _select_tab(_selected_tab)


func _ensure_lobby_navigation() -> void:
    if _lobby_nav!=null and is_instance_valid(_lobby_nav):
        return
    _profile_strip=Label.new()
    _profile_strip.name="LocalProfileStrip"
    _profile_strip.anchor_left=.034
    _profile_strip.anchor_right=.95
    _profile_strip.anchor_top=.035
    _profile_strip.anchor_bottom=.035
    _profile_strip.offset_bottom=43
    _profile_strip.add_theme_font_size_override("font_size",16)
    _profile_strip.add_theme_color_override("font_color",Color(.90,.97,1))
    _profile_strip.add_theme_color_override("font_shadow_color",Color(.01,.035,.07))
    _profile_strip.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _surface.add_child(_profile_strip)
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
        button.custom_minimum_size=Vector2(176,43)
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
            _info.text="CÁMARA / PRECISIÓN\nSensibilidad de giro y ADS guardadas en el dispositivo."
        "PERSONAJE":
            var stats: Dictionary=_offline_records.snapshot()
            _info.text="OPERADORA / LILA EN DESARROLLO\nModelo 3D provisional."
            _info.text+="\nPARTIDAS %d  •  VICTORIAS %d  •  BAJAS %d"%[int(stats.get("played",0)),int(stats.get("wins",0)),int(stats.get("kills",0))]
            _info.text+="\nRÉCORD %d BAJAS  •  %d S VIVO"%[int(stats.get("best_kills",0)),int(stats.get("longest_survival_seconds",0))]
        "ARMAS":
            _info.text="ARSENAL DISPONIBLE\nAK-74: x2 / x4\nAWM: x8 y recarga de cerrojo.\nLas armas se usan dentro de la partida."
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

func _launch(battle: bool) -> void:
    if stage!="lobby":
        return
    stage="loading"
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
    _game=GAME.instantiate() as Node3D
    _game.name="ActiveAuroraGame"
    get_parent().add_child(_game)
    var hud:=_game.get_node("TrainingHUD") as CanvasLayer
    hud.leave_to_lobby_requested.connect(_return_to_lobby)
    visible=false
    stage="battle" if battle else "training"
    if battle:
        var match_director: Node3D=_game.get_node("AuroraSectorMatch")
        match_director.begin_aircraft_phase()


func _return_to_lobby() -> void:
    if _game!=null and is_instance_valid(_game):
        if not _game.get_node("AuroraSectorMatch").retry_result():
            return
        var old: Node3D=_game
        _game=null
        old.get_parent().remove_child(old)
        old.queue_free()
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
    _preview_container.mouse_filter=Control.MOUSE_FILTER_IGNORE
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
            if anim and anim.has_animation("AuroraArmedIdle"):
                anim.play("AuroraArmedIdle")
                anim.advance(.1)

    var caption:=Label.new()
    caption.name="PreviewDisclosure"
    caption.text="OPERADORA 3D PROVISIONAL  ·  LILA EN DESARROLLO"
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


func _build_settings() -> void:
    _settings_panel=VBoxContainer.new()
    _settings_panel.name="CameraSettings"
    _settings_panel.add_theme_constant_override("separation",4)
    _page.add_child(_settings_panel)
    # A scrollable control section avoids hiding mobile HUD buttons or running
    # past the screen edge when a phone uses 16:9 or a taller aspect ratio.
    var settings_scroll:=ScrollContainer.new()
    settings_scroll.name="MobileSettingsScroll"
    settings_scroll.custom_minimum_size=Vector2(0,210)
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
    _graphics_selector.select(["baja","media","alta"].find(_mobile_options.graphics_preset))
    _graphics_selector.custom_minimum_size=Vector2(112,37)
    _graphics_selector.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _graphics_selector.item_selected.connect(func(_selected: int): _save_timer.start())
    graphics_row.add_child(_graphics_selector)
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
        var preset_names: Array[String]=["baja","media","alta"]
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
