extends Control
## Original Aurora front-end. Free Fire is UX reference ONLY; no copied layout,
## assets or proprietary game branding. Incomplete service tabs say so.
const SAFE_SCREEN=preload("res://scripts/ui/safe_screen.gd")
const CAMERA_PREFERENCES=preload("res://scripts/persistence/camera_preferences.gd")
const PLAYER_SETTINGS=preload("res://scripts/persistence/player_settings.gd")
const LOBBY_BACKDROP=preload("res://scripts/ui/aurora_lobby_backdrop.gd")
const LOBBY_STAGE=preload("res://scripts/ui/aurora_lobby_stage_3d.gd")
const LOBBY_COMPANION=preload("res://scripts/ui/aurora_robot_companion.gd")
const GAME_PATH: String="res://scenes/Main.tscn"
const SETTINGS_OVERLAY=preload("res://scripts/ui/aurora_settings_overlay.gd")
const MATCH_RECORDS = preload("res://scripts/persistence/offline_match_records.gd")
const COSMETICS=preload("res://scripts/player/aurora_operator_cosmetics.gd")
const LOBBY_MOTION = preload("res://assets/animations/aurora_lobby_motion.tres")
const LOBBY_MOTION_CLIP: StringName=&"aurora_lobby/Motion"
const LOCAL_PLAYER_NAME=preload("res://scripts/persistence/local_player_name.gd")
const FIREBASE_BRIDGE=preload("res://scripts/persistence/aurora_firebase_bridge.gd")
const PERFORMANCE=preload("res://scripts/persistence/aurora_performance_report.gd")
const FLIGHT_DIAGNOSTICS=preload("res://scripts/match/flight_diagnostics.gd")
const STARTUP_DIAG=preload("res://scripts/persistence/scene_startup_diagnostics.gd")
const FLIGHT_SAFETY_MODE=preload("res://scripts/persistence/flight_safety_mode.gd")

signal startup_finished
@export_file("*.tscn") var game_scene_path: String=GAME_PATH

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
var stage: String = "startup"
var _surface: Control
var _page: VBoxContainer
var _entry_glass: Panel
var _entry_mission_caption: Label
var _entry_hero_plate: Panel
var _entry_hero_kicker: Label
var _entry_panel_accent: ColorRect
var _loading_chapter: Label
var _loading_emblem: TextureRect
var _loading_surface_plate: Panel
var _entry_info_panel: PanelContainer
var _header_glass: Panel
var _lobby_backplates: Array[Control]=[]
var _lobby_status_ribbon: PanelContainer
var _lobby_status_caption: Label
var _info: Label
var _game: Node3D
var _primary: Button
var _selected_tab: String = "JUGAR"
var _preview_container: SubViewportContainer
var _preview_avatar: Node3D
var _preview_caption: Label
var _gesture_button: Button
var _operator_controls: Array[Button]=[]
var _preview_zoomed: bool=false
var _preview_frame_tween: Tween
var _preview_turn_tween: Tween
var _preview_skin_applied: String=""
var _offline_records: RefCounted
var _player_name: RefCounted
var _name_entry: LineEdit
var _name_save_button: Button
var _firebase_check_button: Button
var _auth_guest_button: Button
var _auth_google_button: Button
var _account_connection_label: Label
var _lobby_section_title: Label
var _lobby_section_hint: Label
var _lobby_nav: VBoxContainer
var _profile_strip: Label
var _stats_strip: Label
var _currency_strip: Label
var _objective_selector: OptionButton
var _objective_page: String="missions"
var _preview_touch: int=-1
var _preview_mouse_drag: bool=false
var _preview_drag_last: Vector2=Vector2.ZERO
var _preview_resume_spin: float=0.0
var _hud_editor_requested: bool=false
var _hud_editor_origin: String=""
var _settings_modal: CanvasLayer
var _brand_logo: TextureRect
var _match_mode_selector: OptionButton
var _selected_match_mode: String="classic"
var _lobby_mode_heading: Label
var _lobby_mode_caption: Label
var _lobby_mode_status: Label
var _lobby_play_modes: VBoxContainer
var _lobby_detail_scroll: ScrollContainer
var _battle_entry: Button
var _training_entry: Button
var _login_status_label: Label
var _login_google_button: Button
var _login_guest_button: Button
var _login_local_button: Button
var _login_pending_provider: String=""
var _login_waiting_provider: String=""
var _login_timer: Timer
var _login_manage_button: Button
var _bottom_navigation: HBoxContainer
var _left_shortcuts: VBoxContainer
var _social_panel: PanelContainer
var _social_status_label: Label
var _top_account_button: Button
var _top_settings_button: Button
var _top_social_button: Button
var _play_match_card: PanelContainer
var _pass_claim_button: Button
var _pass_progress: ProgressBar
var _shop_selector: OptionButton
var _shop_buy_button: Button
var _shop_equip_button: Button
var _shop_selected_skin: String="aurora_glacier"
var _banner: Label
var _game_scene: PackedScene
var _loading_overlay: ColorRect
var _loading_title: Label
var _loading_detail: Label
var _loading_meter: ProgressBar
var _loading_retry: Button
var _loading_cancel: Button
var _loading_fade: Tween
var _startup_frame_seen: bool=false
var _launch_serial: int=0


func _ready() -> void:
    name = "AuroraFront"
    _preferences=CAMERA_PREFERENCES.new()
    _mobile_options=PLAYER_SETTINGS.new()
    _player_name=LOCAL_PLAYER_NAME.new()
    # Frame cap is a runtime option; imported texture compression remains a build-time choice.
    Engine.max_fps=_mobile_options.fps_limit()
    _save_timer=Timer.new()
    _save_timer.one_shot=true
    _save_timer.wait_time=.4
    _save_timer.timeout.connect(_save_preferences)
    add_child(_save_timer)
    _login_timer=Timer.new()
    _login_timer.name="NativeAuthPolling"
    _login_timer.wait_time=1.2
    _login_timer.one_shot=false
    _login_timer.timeout.connect(_poll_login_state)
    add_child(_login_timer)
    _login_timer.start()
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
    # Original artwork, rasterized once by Godot's SVG importer rather than
    # redrawing a procedural checkerboard and zigzag aurora every frame.
    var arctic_art:=TextureRect.new()
    arctic_art.name="AuroraWinterBaseArtwork"
    arctic_art.texture=load("res://assets/ui/aurora_winter_base.svg")
    arctic_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    arctic_art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    arctic_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
    arctic_art.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _surface.add_child(arctic_art)
    _surface.move_child(arctic_art,1)
    painted.visible=false
    # Native Godot panels remain interactive components, never a screenshot
    # pretending to be the entry or Battle Royale interface.
    _build_entry_shell()
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
    # Build the heavy skinned 3D preview only when the player enters the lobby.
    # Welcome/login no longer owns an unnecessary 3D render target or rig.
    get_viewport().size_changed.connect(_layout_safe)
    _layout_safe.call_deferred()
    _build_loading_overlay()
    _start_bootstrap()


func _process(delta: float) -> void:
    if stage=="startup":
        _poll_bootstrap()
        return
    # Keep the real CC0 rig animated and turnable, without any extra 3D
    # viewport allocations. The full preview is freed before match creation.
    if stage!="lobby" or _preview_avatar==null or not             is_instance_valid(_preview_avatar):
        return
    _preview_resume_spin=maxf(0.0,_preview_resume_spin-delta)
    if _preview_resume_spin<=0.0 and _preview_touch<0 and not _preview_mouse_drag:
        _preview_avatar.rotation.y=wrapf(
            _preview_avatar.rotation.y+delta*.18,-PI,PI)


func _exit_tree() -> void:
    AuroraLobbyMusic.leave_lobby()


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


func _style_primary_action(button: Button) -> void:
    var style:=StyleBoxFlat.new()
    style.bg_color=Color(.98,.69,.12)
    style.border_color=Color(1,.90,.47)
    style.set_border_width_all(2)
    style.set_corner_radius_all(7)
    style.shadow_color=Color(.82,.42,.10,.50)
    style.shadow_size=5
    var hover:=style.duplicate() as StyleBoxFlat
    hover.bg_color=Color(1.0,.82,.27)
    var disabled:=style.duplicate() as StyleBoxFlat
    disabled.bg_color=Color(.15,.21,.27,.90)
    disabled.border_color=Color(.30,.39,.46)
    button.add_theme_stylebox_override("normal",style)
    button.add_theme_stylebox_override("hover",hover)
    button.add_theme_stylebox_override("pressed",hover)
    button.add_theme_stylebox_override("disabled",disabled)
    button.add_theme_color_override("font_color",Color(.05,.09,.13))
    button.add_theme_color_override("font_hover_color",Color(.05,.09,.13))
    button.add_theme_color_override("font_pressed_color",Color(.05,.09,.13))
    button.add_theme_color_override("font_disabled_color",Color(.75,.80,.84))


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


func _make_glass_panel(bg: Color,border: Color,rounding: int=12) -> Panel:
    var panel:=Panel.new()
    var style:=StyleBoxFlat.new()
    style.bg_color=bg
    style.border_color=border
    style.set_border_width_all(1)
    style.set_corner_radius_all(rounding)
    style.shadow_color=Color(0,.015,.04,.45)
    style.shadow_size=6
    panel.add_theme_stylebox_override("panel",style)
    panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
    return panel


func _build_entry_shell() -> void:
    _entry_glass=_make_glass_panel(
        Color(.008,.018,.035,.97),Color(.37,.49,.65,.76),13)
    _entry_glass.name="AuroraEntryGlassPanel"
    _entry_glass.anchor_left=.55
    _entry_glass.anchor_right=.966
    _entry_glass.anchor_top=.109
    _entry_glass.anchor_bottom=.932
    _entry_glass.visible=false
    _surface.add_child(_entry_glass)
    _entry_panel_accent=ColorRect.new()
    _entry_panel_accent.name="AuroraAccessGoldAccent"
    _entry_panel_accent.color=Color(.99,.69,.23,.91)
    _entry_panel_accent.anchor_left=.55
    _entry_panel_accent.anchor_right=.553
    _entry_panel_accent.anchor_top=.18
    _entry_panel_accent.anchor_bottom=.86
    _entry_panel_accent.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _entry_panel_accent.visible=false
    _surface.add_child(_entry_panel_accent)
    _entry_hero_plate=_make_glass_panel(
        Color(.011,.028,.055,.76),Color(.28,.61,.79,.46),10)
    _entry_hero_plate.name="AuroraEntryHeroPanel"
    _entry_hero_plate.anchor_left=.047
    _entry_hero_plate.anchor_right=.510
    _entry_hero_plate.anchor_top=.255
    _entry_hero_plate.anchor_bottom=.775
    _entry_hero_plate.visible=false
    _surface.add_child(_entry_hero_plate)
    _entry_hero_kicker=Label.new()
    _entry_hero_kicker.name="AuroraEntryHeroKicker"
    _entry_hero_kicker.text="01  /  CENTRO DE OPERACIONES   ·   BASE AURORA"
    _entry_hero_kicker.anchor_left=.067
    _entry_hero_kicker.anchor_right=.490
    _entry_hero_kicker.anchor_top=.295
    _entry_hero_kicker.anchor_bottom=.34
    _entry_hero_kicker.add_theme_font_size_override("font_size",12)
    _entry_hero_kicker.add_theme_color_override(
        "font_color",Color(.47,.85,.95))
    _entry_hero_kicker.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _entry_hero_kicker.visible=false
    _surface.add_child(_entry_hero_kicker)
    _entry_mission_caption=Label.new()
    _entry_mission_caption.name="AuroraEntryMissionCaption"
    _entry_mission_caption.text="ÚLTIMA ZONA\nEL DESPLIEGUE EMPIEZA AQUÍ\n\nOPERACIÓN AURORA  /  INVIERNO"
    _entry_mission_caption.anchor_left=.067
    _entry_mission_caption.anchor_right=.494
    _entry_mission_caption.anchor_top=.390
    _entry_mission_caption.anchor_bottom=.717
    _entry_mission_caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _entry_mission_caption.add_theme_font_size_override("font_size",23)
    _entry_mission_caption.add_theme_color_override(
        "font_color",Color(.97,.98,1.0))
    _entry_mission_caption.add_theme_color_override(
        "font_shadow_color",Color(.0,.02,.05,.90))
    _entry_mission_caption.add_theme_constant_override("shadow_offset_y",2)
    _entry_mission_caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _entry_mission_caption.visible=false
    _surface.add_child(_entry_mission_caption)


func _build_loading_overlay() -> void:
    _loading_overlay=ColorRect.new()
    _loading_overlay.name="AuroraLoadingOverlay"
    _loading_overlay.color=Color(.005,.015,.032,.90)
    _loading_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _surface.add_child(_loading_overlay)
    _loading_surface_plate=_make_glass_panel(
        Color(.006,.019,.041,.86),Color(.34,.61,.76,.58),12)
    _loading_surface_plate.name="AuroraLoadingConsolePlate"
    _loading_surface_plate.anchor_left=.18
    _loading_surface_plate.anchor_right=.82
    _loading_surface_plate.anchor_top=.51
    _loading_surface_plate.anchor_bottom=.967
    _loading_overlay.add_child(_loading_surface_plate)
    var stripe:=ColorRect.new()
    stripe.name="AuroraLoadingGoldStripe"
    stripe.color=Color(.95,.66,.22,.90)
    stripe.anchor_left=.22
    stripe.anchor_right=.78
    stripe.anchor_top=.513
    stripe.anchor_bottom=.518
    stripe.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _loading_overlay.add_child(stripe)
    var hero:=CenterContainer.new()
    hero.anchor_right=1
    hero.anchor_top=.047
    # Keep brand and real resource progress in different layers.
    hero.anchor_bottom=.483
    _loading_overlay.add_child(hero)
    var branding:=VBoxContainer.new()
    hero.add_child(branding)
    _loading_chapter=Label.new()
    _loading_chapter.name="AuroraLoadingChapter"
    _loading_chapter.text="A U R O R A   /   P R O T O C O L O   D E   D E S P L I E G U E"
    _loading_chapter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    _loading_chapter.add_theme_font_size_override("font_size",11)
    _loading_chapter.add_theme_color_override(
        "font_color",Color(.53,.79,.91))
    branding.add_child(_loading_chapter)
    _loading_emblem=TextureRect.new()
    _loading_emblem.name="AuroraLoadingIdentityEmblem"
    _loading_emblem.texture=_brand_logo.texture
    _loading_emblem.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    _loading_emblem.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _loading_emblem.custom_minimum_size=Vector2(0,87)
    branding.add_child(_loading_emblem)
    _add_entry_wordmark(branding)

    var content:=VBoxContainer.new()
    content.name="AuroraLoadingActions"
    content.anchor_left=.23
    content.anchor_right=.77
    # The former 0.305-height region was only 132px on 964x434;
    # CANCEL or RETRY could extend beyond the touch-safe screen.
    content.anchor_top=.544
    content.anchor_bottom=.960
    content.alignment=BoxContainer.ALIGNMENT_CENTER
    content.add_theme_constant_override("separation",8)
    _loading_overlay.add_child(content)
    var phase:=Label.new()
    phase.name="AuroraLoadPhase"
    phase.text="SECUENCIA  01 /  VERIFICACIÓN DE RECURSOS"
    phase.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    phase.add_theme_font_size_override("font_size",12)
    phase.add_theme_color_override("font_color",Color(.40,.84,.94))
    content.add_child(phase)
    _loading_title=Label.new()
    _loading_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    _loading_title.add_theme_font_size_override("font_size",21)
    _loading_title.add_theme_color_override(
        "font_color",Color(.98,.95,.86))
    content.add_child(_loading_title)
    _loading_detail=Label.new()
    _loading_detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    _loading_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _loading_detail.add_theme_font_size_override("font_size",14)
    _loading_detail.add_theme_color_override(
        "font_color",Color(.75,.86,.93))
    content.add_child(_loading_detail)
    _loading_meter=ProgressBar.new()
    _loading_meter.name="WorldLoadProgress"
    _loading_meter.custom_minimum_size=Vector2(275,21)
    var track:=StyleBoxFlat.new()
    track.bg_color=Color(.017,.030,.059)
    track.border_color=Color(.33,.68,.83)
    track.set_border_width_all(2)
    track.set_corner_radius_all(4)
    _loading_meter.add_theme_stylebox_override("background",track)
    var fill:=StyleBoxFlat.new()
    fill.bg_color=Color(1.0,.72,.23)
    fill.set_corner_radius_all(4)
    _loading_meter.add_theme_stylebox_override("fill",fill)
    content.add_child(_loading_meter)
    _loading_retry=_button("REINTENTAR",_start_bootstrap,190)
    content.add_child(_loading_retry)
    _loading_cancel=_button("VOLVER AL LOBBY",_return_to_lobby,190)
    content.add_child(_loading_cancel)


func _add_entry_wordmark(container: VBoxContainer) -> void:
    for entry in [["EntryBrandTitle","THEDEMIAN:",37,Color(.97,.98,1.0)],
            ["EntryBrandSubtitle","LAST ZONE",22,Color(1.0,.73,.31)]]:
        var label:=Label.new()
        label.name=entry[0]
        label.text=entry[1]
        label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size",entry[2])
        label.add_theme_color_override("font_color",entry[3])
        label.add_theme_color_override("font_shadow_color",Color(.18,.02,.30))
        label.add_theme_constant_override("shadow_offset_y",3)
        container.add_child(label)


func _show_loading(title: String,detail: String,pending: bool=false) -> void:
    _surface.move_child(_loading_overlay,-1)
    _loading_title.text=title
    _loading_detail.text=detail
    _loading_retry.hide()
    _loading_cancel.hide()
    _loading_meter.show()
    _loading_meter.indeterminate=pending
    _loading_meter.show_percentage=not pending
    _loading_meter.value=0
    if _loading_fade and _loading_fade.is_valid():
        _loading_fade.kill()
    _loading_overlay.show()
    _loading_overlay.modulate.a=.68
    _loading_fade=create_tween()
    _loading_fade.tween_property(_loading_overlay,"modulate:a",1.0,.16)


func _start_bootstrap() -> void:
    stage="startup"
    _startup_frame_seen=false
    _show_loading("CARGANDO RECURSOS","Preparando Base Aurora…")
    if not ResourceLoader.exists(game_scene_path,"PackedScene") or (
            ResourceLoader.load_threaded_request(game_scene_path,"PackedScene")!=OK):
        _startup_failed()


func _poll_bootstrap() -> void:
    # Give the native loading surface a frame even when the scene is cached.
    if not _startup_frame_seen:
        _startup_frame_seen=true
        return
    var progress: Array=[]
    var status:=ResourceLoader.load_threaded_get_status(game_scene_path,progress)
    match status:
        ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            if not progress.is_empty():
                _loading_meter.value=maxf(_loading_meter.value,float(progress[0])*100.0)
        ResourceLoader.THREAD_LOAD_LOADED:
            _game_scene=ResourceLoader.load_threaded_get(game_scene_path) as PackedScene
            if _game_scene==null or not _game_scene.can_instantiate():
                _startup_failed()
                return
            _loading_meter.value=100
            _welcome()
            startup_finished.emit()
        _:
            _startup_failed()


func _startup_failed() -> void:
    stage="startup_failed"
    _loading_detail.text="No se pudo cargar Base Aurora."
    _loading_meter.hide()
    _loading_retry.show()
    startup_finished.emit()


func wait_for_startup() -> void:
    if stage=="startup":
        await startup_finished


func _welcome() -> void:
    # Authentication is an ENTRY flow, never a row of permanent lobby badges.
    # This screen offers actual Firebase providers and a clearly separate
    # LOCAL offline choice. It never labels an unverified ID as official.
    stage="welcome"
    _loading_overlay.hide()
    _entry_glass.visible=true
    _entry_mission_caption.visible=true
    _entry_hero_plate.visible=true
    _entry_hero_kicker.visible=true
    _entry_panel_accent.visible=true
    AuroraLobbyMusic.leave_lobby()
    visible=true
    _login_pending_provider=""
    _login_waiting_provider=""
    _release_preview()
    if _lobby_nav!=null and is_instance_valid(_lobby_nav):
        _lobby_nav.visible=false
    if _left_shortcuts!=null and is_instance_valid(_left_shortcuts):
        _left_shortcuts.visible=false
    for plate in _lobby_backplates:
        if is_instance_valid(plate):
            plate.visible=false
    if _bottom_navigation!=null and is_instance_valid(_bottom_navigation):
        _bottom_navigation.visible=false
    if _social_panel!=null and is_instance_valid(_social_panel):
        _social_panel.visible=false
    if _top_account_button!=null and is_instance_valid(_top_account_button):
        _top_account_button.visible=false
    if _top_settings_button!=null and is_instance_valid(_top_settings_button):
        _top_settings_button.visible=false
    if _top_social_button!=null and is_instance_valid(_top_social_button):
        _top_social_button.visible=false
    if _play_match_card!=null and is_instance_valid(_play_match_card):
        _play_match_card.visible=false
    if _banner!=null and is_instance_valid(_banner):
        _banner.visible=false
    if _lobby_status_ribbon!=null and is_instance_valid(
            _lobby_status_ribbon):
        _lobby_status_ribbon.visible=false
    for item in [_profile_strip,_stats_strip,_currency_strip]:
        if item!=null and is_instance_valid(item):
            item.visible=false
    _page.anchor_left=.585
    _page.anchor_right=.933
    _page.anchor_top=.155
    _page.anchor_bottom=.900
    _page.add_theme_constant_override("separation",6)
    _brand_logo.visible=true
    _brand_logo.anchor_left=.916
    _brand_logo.anchor_right=.963
    _brand_logo.anchor_top=.028
    _brand_logo.anchor_bottom=.109
    _clear_page()
    _add_entry_wordmark(_page)
    var entry_overline:=_label("CENTRO DE ACCESO  /  AUTENTICACIÓN",11)
    entry_overline.name="AuroraEntryAccessOverline"
    entry_overline.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    entry_overline.add_theme_color_override("font_color",Color(.49,.78,.90))
    var space:=Control.new()
    space.mouse_filter=Control.MOUSE_FILTER_IGNORE
    space.size_flags_vertical=Control.SIZE_EXPAND_FILL
    _page.add_child(space)
    # This is live UI and truthful match information, not a static login
    # screenshot or a claim that online play is operational.
    _entry_info_panel=PanelContainer.new()
    _entry_info_panel.name="AuroraMissionBriefing"
    _entry_info_panel.custom_minimum_size=Vector2(0,112)
    _entry_info_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    var briefing_style:=StyleBoxFlat.new()
    briefing_style.bg_color=Color(.036,.070,.102,.93)
    briefing_style.border_color=Color(.25,.66,.80,.72)
    briefing_style.set_border_width_all(1)
    briefing_style.set_corner_radius_all(9)
    briefing_style.content_margin_left=14
    briefing_style.content_margin_right=14
    briefing_style.content_margin_top=11
    briefing_style.content_margin_bottom=10
    _entry_info_panel.add_theme_stylebox_override("panel",briefing_style)
    _page.add_child(_entry_info_panel)
    var information:=VBoxContainer.new()
    information.name="MissionBriefingContent"
    information.add_theme_constant_override("separation",4)
    _entry_info_panel.add_child(information)
    for item in [
        ["PUESTO DE MANDO / AURORA",12,Color(.43,.88,.96)],
        ["BATTLE ROYALE · 50 PARTICIPANTES",17,Color(.98,.81,.48)],
        ["1 operador y 49 rivales IA en la partida local.",13,
            Color(.87,.94,1.0)]
    ]:
        var line:=Label.new()
        line.text=str(item[0])
        line.name="Briefing"+str(information.get_child_count())
        line.add_theme_font_size_override("font_size",int(item[1]))
        line.add_theme_color_override("font_color",item[2])
        line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
        line.mouse_filter=Control.MOUSE_FILTER_IGNORE
        information.add_child(line)
    # Hide the optional briefing on Motorola's 434px landscape height,
    # preserving all three actionable providers and their touch targets.
    _entry_info_panel.visible=_entry_should_show_briefing()
    _login_status_label=_label("COMPROBANDO ACCESO…",12)
    _login_status_label.name="LoginTransportStatus"
    _login_status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _login_status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    _login_status_label.add_theme_color_override("font_color",Color(.95,.81,.49))
    var providers:=VBoxContainer.new()
    providers.name="AccountProviders"
    providers.add_theme_constant_override("separation",6)
    _page.add_child(providers)
    _login_google_button=_button("CONTINUAR CON GOOGLE",
        Callable(self,"_begin_welcome_auth").bind("google"),0)
    _login_google_button.name="WelcomeGoogleSignIn"
    _login_google_button.custom_minimum_size.y=46
    _login_google_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _style_primary_action(_login_google_button)
    _login_guest_button=_button("ENTRAR COMO INVITADO",
        Callable(self,"_begin_welcome_auth").bind("guest"),0)
    _login_guest_button.name="WelcomeGuestSignIn"
    _login_guest_button.custom_minimum_size.y=44
    _login_guest_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    providers.add_child(_login_google_button)
    providers.add_child(_login_guest_button)
    _login_local_button=_button("JUGAR SIN CONEXIÓN",_enter_local_lobby,0)
    _login_local_button.name="EnterButton"
    _login_local_button.custom_minimum_size.y=44
    _login_local_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    providers.add_child(_login_local_button)
    var disclosure:=_label(
        "SIN CONEXIÓN: progreso guardado en este dispositivo.",11)
    disclosure.name="WelcomeLocalStorageDisclosure"
    disclosure.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    disclosure.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    var diag:=_button("DIAGNÓSTICOS DE DESARROLLO",
        Callable(self,"_show_startup_diagnostics"),0)
    diag.name="StartupDiagnosticEntry"
    diag.custom_minimum_size.y=22
    diag.add_theme_font_size_override("font_size",10)
    diag.modulate=Color(.72,.80,.90)
    diag.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _page.add_child(diag)
    _poll_login_state()


func _enter_local_lobby() -> void:
    if stage!="welcome":
        return
    _login_pending_provider=""
    _login_waiting_provider=""
    _show_lobby()


func _begin_welcome_auth(provider: String) -> void:
    if stage!="welcome" or provider not in ["google","guest"] or not _login_waiting_provider.is_empty():
        return
    _login_pending_provider=provider
    _poll_login_state()


func _poll_login_state() -> void:
    if stage!="welcome" or _login_status_label==null or not is_instance_valid(_login_status_label):
        return
    var health: Dictionary=FIREBASE_BRIDGE.status()
    if not bool(health.get("ready",false)):
        _login_status_label.text="ACCESO PENDIENTE · "+_firebase_state_message(
            str(health.get("reason","desconocido")))
        return
    # The SDK may need time to obtain Play Integrity. A user-initiated
    # request is retried only until it was actually submitted; no fake
    # login, no automatic account swapping or repeated Google popups.
    if not _login_pending_provider.is_empty():
        var provider: String=_login_pending_provider
        _login_pending_provider=""
        var attempt: Dictionary=FIREBASE_BRIDGE.request_sign_in(provider)
        if bool(attempt.get("queued",false)):
            _login_waiting_provider=provider
            _login_status_label.text="INICIANDO "+provider.to_upper()+" · CONFIRMANDO CUENTA"
        else:
            _login_status_label.text="NO SE PUDO INICIAR · "+_firebase_state_message(
                str(attempt.get("reason","desconocido")))
        return
    var session: Dictionary=FIREBASE_BRIDGE.session_state()
    var enter: Button=_login_local_button
    if bool(session.get("authenticated",false)):
        _login_waiting_provider=""
        if bool(session.get("identity_confirmed",false)):
            _login_status_label.text="SESIÓN CONFIRMADA · ID "+str(session.get("official_id",""))
        else:
            _login_status_label.text="CUENTA AUTENTICADA · ID PENDIENTE DEL SERVIDOR"
        if enter!=null:
            enter.text="CONTINUAR AL LOBBY"
        return
    if enter!=null:
        enter.text="JUGAR SIN CONEXIÓN"
    if not _login_waiting_provider.is_empty():
        if bool(session.get("pending",false)):
            _login_status_label.text="VALIDANDO CUENTA "+_login_waiting_provider.to_upper()
        else:
            var reason: String=str(session.get("reason",""))
            _login_status_label.text=("ACCESO NO CONFIRMADO · "+_firebase_state_message(reason)
                if not reason.is_empty() else "ESPERANDO CONFIRMACIÓN DE FIREBASE")
            _login_waiting_provider=""
        return
    _login_status_label.text="GOOGLE E INVITADO DISPONIBLES"

func _show_startup_diagnostics() -> void:
    stage="startup_diagnostics"
    _clear_page()
    _page.anchor_left=.26
    _page.anchor_right=.78
    _page.anchor_top=.10
    _page.anchor_bottom=.94
    _label("DIAGNÓSTICOS DE DESARROLLO",21)
    var test_mode: Button=_button(
        "VUELO "+FLIGHT_SAFETY_MODE.label_for(FLIGHT_SAFETY_MODE.current_mode()),
        Callable(self,"_cycle_flight_diagnostic"),350)
    test_mode.name="FlightDiagnosticModeButton"
    _page.add_child(test_mode)
    var startup_button: Button=_button(
        "CARGA "+STARTUP_DIAG.label(),
        Callable(self,"_cycle_scene_load_diagnostic"),350)
    startup_button.name="SceneStartupDiagnosticButton"
    _page.add_child(startup_button)
    var trace: Dictionary=FLIGHT_DIAGNOSTICS.last()
    if not trace.is_empty():
        _label("ÚLTIMO VUELO: "+str(trace.get("phase","desconocido")),12)
        _page.add_child(_button("VER REGISTRO DETALLADO",
            Callable(self,"_show_flight_details"),320))
    var saved: Dictionary=FLIGHT_DIAGNOSTICS.last(true)
    if not saved.is_empty():
        _page.add_child(_button("VER VUELO ANTERIOR",
            Callable(self,"_show_previous_flight_details"),320))
    _page.add_child(_button("VOLVER AL INICIO",
        Callable(self,"_welcome"),250))


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
    _entry_glass.visible=false
    _entry_mission_caption.visible=false
    _entry_hero_plate.visible=false
    _entry_hero_kicker.visible=false
    _entry_panel_accent.visible=false
    _offline_records=MATCH_RECORDS.new()
    var stats: Dictionary=_offline_records.snapshot()
    if _preview_container==null or not is_instance_valid(_preview_container):
        _build_preview()
    stage="lobby"
    _loading_overlay.hide()
    AuroraLobbyMusic.enter_lobby()
    visible=true
    _brand_logo.visible=true
    # Logo stays outside the full-width profile strip and never crosses
    # over player statistics or the rotating 3D character.
    # Prominent original emblem integrated into the left profile header.
    # The V75.112 tiny icon at the far right was almost invisible on phone.
    _brand_logo.anchor_left=.031
    _brand_logo.anchor_right=.094
    _brand_logo.anchor_top=.024
    _brand_logo.anchor_bottom=.117
    # Base Aurora: large real 3D operator at centre; separate commerce,
    # social/match card, full-width top and bottom navigation layers.
    _page.anchor_left=.728
    _page.anchor_right=.965
    _page.anchor_top=.487
    _page.anchor_bottom=.854
    _page.add_theme_constant_override("separation",2)
    # The same live SubViewport is now the whole winter hangar
    # behind the menus. Side bars are native UI placed ABOVE it; never
    # use a still image to fake a usable lobby.
    _preview_container.anchor_left=0.0
    _preview_container.anchor_right=1.0
    _preview_container.anchor_top=0.0
    _preview_container.anchor_bottom=1.0
    _preview_container.visible=true
    _preview_caption.visible=true
    if _gesture_button!=null and is_instance_valid(_gesture_button):
        _gesture_button.visible=true
    for action in _operator_controls:
        if is_instance_valid(action):
            action.visible=true
    _preview_caption.anchor_left=.206
    _preview_caption.anchor_right=.730
    _preview_caption.anchor_top=.819
    _preview_caption.anchor_bottom=.819
    _ensure_lobby_navigation()
    for plate in _lobby_backplates:
        if is_instance_valid(plate):
            plate.visible=true
    _lobby_nav.visible=false
    _left_shortcuts.visible=true
    _bottom_navigation.visible=true
    _top_account_button.visible=true
    _top_settings_button.visible=true
    _top_social_button.visible=true
    _banner.visible=true
    _lobby_status_ribbon.visible=true
    # Three independently clipped headers keep the original brand legible
    # without the coin balance covering Lila, the player record or the emblem.
    _profile_strip.visible=true
    _profile_strip.text="THEDEMIAN: LAST ZONE"
    _stats_strip.visible=true
    _update_identity_strip(stats)
    _currency_strip.visible=true
    _currency_strip.text="MONEDAS %d\nDIAMANTES —"%int(
        stats.get("local_coins",0))
    _preview_touch=-1
    _preview_mouse_drag=false
    _preview_resume_spin=2.0
    if _preview_avatar:
        _preview_avatar.rotation.y=0.0
        _apply_preview_skin(str(
            _offline_records.cosmetic_state()["equipped"]))
    _clear_page()
    _lobby_section_title=_label("BATTLE ROYALE",20)
    _lobby_section_title.name="LobbySectionTitle"
    _lobby_section_title.add_theme_color_override("font_color",Color(.96,.96,.88))
    _lobby_section_hint=_label("BASE AURORA  ·  50 PARTICIPANTES",11)
    _lobby_section_hint.name="LobbySectionHint"
    _lobby_section_hint.add_theme_color_override("font_color",Color(.57,.84,.94))
    _lobby_mode_heading=_label("MODALIDAD DE PARTIDA",13)
    _lobby_mode_heading.add_theme_color_override("font_color",Color(.96,.77,.38))
    _match_mode_selector=OptionButton.new()
    _match_mode_selector.name="MatchModeSelector"
    _match_mode_selector.custom_minimum_size=Vector2(245,32)
    _match_mode_selector.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
    _match_mode_selector.add_item("CLÁSICO · IA LOCAL",0)
    _match_mode_selector.add_item("CLASIFICATORIA · ONLINE PENDIENTE",1)
    _match_mode_selector.add_item("ENTRENAMIENTO · LOCAL",2)
    _match_mode_selector.select(["classic","ranked","training"].find(_selected_match_mode))
    _match_mode_selector.item_selected.connect(_on_match_mode_selected)
    _page.add_child(_match_mode_selector)
    _lobby_play_modes=VBoxContainer.new()
    _lobby_play_modes.name="PlayModes"
    _page.add_child(_lobby_play_modes)
    _battle_entry=_button("INICIAR",Callable(self,"_launch").bind(true),240)
    _battle_entry.name="BattleButton"
    _battle_entry.custom_minimum_size.y=58
    _battle_entry.add_theme_font_size_override("font_size",23)
    _style_primary_action(_battle_entry)
    _lobby_play_modes.add_child(_battle_entry)
    _training_entry=_button("INICIAR ENTRENAMIENTO",Callable(self,"_launch").bind(false),240)
    _training_entry.name="TrainingButton"
    _training_entry.custom_minimum_size.y=49
    _style_primary_action(_training_entry)
    _lobby_play_modes.add_child(_training_entry)
    _lobby_mode_caption=_label("50 PARTICIPANTES · 1 OPERADOR + 49 IA",11)
    _lobby_mode_caption.add_theme_color_override("font_color",Color(.88,.86,.68))
    _lobby_mode_status=_label("",12)
    _lobby_mode_status.name="ModeAvailability"
    # Account actions are now ABOVE the editable local name. Both providers
    # remain visible in Cuenta even when App Check has not finished; gated
    # buttons cannot accidentally fabricate an authenticated identity.
    _account_connection_label=_label("COMPROBANDO FIREBASE...",12)
    _account_connection_label.name="FirebaseConnectionStatus"
    _account_connection_label.add_theme_color_override(
        "font_color",Color(.92,.80,.50))
    _auth_google_button=_button("CONTINUAR CON GOOGLE",
        Callable(self,"_start_native_auth").bind("google"),255)
    _auth_google_button.name="FirebaseGoogleSignInButton"
    _auth_google_button.custom_minimum_size.y=38
    _auth_google_button.add_theme_font_size_override("font_size",15)
    _style_primary_action(_auth_google_button)
    _page.add_child(_auth_google_button)
    _auth_guest_button=_button("ENTRAR COMO INVITADO",
        Callable(self,"_start_native_auth").bind("guest"),255)
    _auth_guest_button.name="FirebaseGuestSignInButton"
    _auth_guest_button.custom_minimum_size.y=36
    _auth_guest_button.add_theme_font_size_override("font_size",14)
    _page.add_child(_auth_guest_button)
    _firebase_check_button=_button("VER ESTADO DE CUENTA / RESPALDO",
        Callable(self,"_check_firebase_connection"),255)
    _firebase_check_button.name="FirebaseConnectionCheckButton"
    _firebase_check_button.custom_minimum_size.y=29
    _firebase_check_button.add_theme_font_size_override("font_size",12)
    _page.add_child(_firebase_check_button)
    _login_manage_button=_button("GESTIONAR ACCESO / CAMBIAR CUENTA",
        Callable(self,"_welcome"),255)
    _login_manage_button.name="OpenAccountSignInScreen"
    _login_manage_button.custom_minimum_size.y=33
    _login_manage_button.add_theme_font_size_override("font_size",12)
    _page.add_child(_login_manage_button)
    # Local profile edit never overwrites the cloud account or invents an ID.
    _name_entry=LineEdit.new()
    _name_entry.name="LocalPlayerNameEntry"
    _name_entry.max_length=16
    _name_entry.placeholder_text="Apodo local (3 a 16 caracteres)"
    _name_entry.text=_player_name.display_name
    _name_entry.custom_minimum_size=Vector2(255,32)
    _name_entry.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
    _page.add_child(_name_entry)
    _name_save_button=_button("GUARDAR APODO LOCAL",
        Callable(self,"_save_player_name"),255)
    _name_save_button.name="SaveLocalPlayerNameButton"
    _name_save_button.custom_minimum_size.y=30
    _name_save_button.add_theme_font_size_override("font_size",12)
    _page.add_child(_name_save_button)
    _objective_selector=OptionButton.new()
    _objective_selector.name="ObjectivesCategorySelector"
    _objective_selector.custom_minimum_size=Vector2(265,35)
    _objective_selector.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
    _objective_selector.add_item("MISIONES",0)
    _objective_selector.add_item("LOGROS",1)
    _objective_selector.add_item("EVENTOS",2)
    _objective_selector.select(["missions","achievements","events"].find(_objective_page))
    _objective_selector.item_selected.connect(_on_objective_category_selected)
    _page.add_child(_objective_selector)
    _pass_progress=ProgressBar.new()
    _pass_progress.name="AuroraFreePassProgress"
    _pass_progress.custom_minimum_size=Vector2(245,16)
    _pass_progress.max_value=MATCH_RECORDS.PASS_TIER_POINTS
    _pass_progress.show_percentage=false
    _page.add_child(_pass_progress)
    _pass_claim_button=_button("RECLAMAR RECOMPENSA LOCAL",
        Callable(self,"_claim_pass_reward"),245)
    _pass_claim_button.name="AuroraFreePassClaim"
    _pass_claim_button.custom_minimum_size.y=37
    _pass_claim_button.add_theme_font_size_override("font_size",14)
    _style_primary_action(_pass_claim_button)
    _page.add_child(_pass_claim_button)
    _shop_selector=OptionButton.new()
    _shop_selector.name="AuroraLocalSkinSelector"
    _shop_selector.custom_minimum_size=Vector2(245,31)
    _shop_selector.add_item("LILA · AURORA ORIGINAL",0)
    _shop_selector.add_item("LILA · AURORA GLACIAL",1)
    _shop_selector.add_item("LILA · AURORA FUEGO",2)
    _shop_selector.select(1)
    _shop_selector.item_selected.connect(_on_shop_skin_selected)
    _page.add_child(_shop_selector)
    _shop_buy_button=_button("COMPRAR TRAJE LOCAL",
        Callable(self,"_buy_local_skin"),245)
    _shop_buy_button.name="AuroraRealSkinPurchase"
    _shop_buy_button.custom_minimum_size.y=34
    _shop_buy_button.add_theme_font_size_override("font_size",13)
    _style_primary_action(_shop_buy_button)
    _page.add_child(_shop_buy_button)
    _shop_equip_button=_button("EQUIPAR TRAJE LOCAL",
        Callable(self,"_equip_local_skin"),245)
    _shop_equip_button.name="AuroraRealSkinEquip"
    _shop_equip_button.custom_minimum_size.y=33
    _shop_equip_button.add_theme_font_size_override("font_size",13)
    _page.add_child(_shop_equip_button)
    # Long account and match history text remains reachable on small screens.
    _lobby_detail_scroll=ScrollContainer.new()
    _lobby_detail_scroll.name="LobbyDetailsScroll"
    _lobby_detail_scroll.custom_minimum_size=Vector2(0,65)
    _lobby_detail_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _lobby_detail_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
    _page.add_child(_lobby_detail_scroll)
    _info=Label.new()
    _info.name="LobbyDetail"
    _info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _info.add_theme_font_size_override("font_size",14)
    _info.add_theme_color_override("font_color",Color(.86,.96,1))
    _info.custom_minimum_size.x=255
    _lobby_detail_scroll.add_child(_info)
    _build_settings()
    _select_tab(_selected_tab)


func _update_identity_strip(stats: Dictionary) -> void:
    if _stats_strip==null or _player_name==null:
        return
    var session: Dictionary=FIREBASE_BRIDGE.session_state()
    if bool(session.get("identity_confirmed",false)):
        var server_name: String=str(session.get("display_name",""))
        _stats_strip.text="%s · ID %s · CUENTA"%[
            server_name if not server_name.is_empty() else "NOMBRE PENDIENTE",
            str(session.get("official_id",""))]
    else:
        _stats_strip.text="%s · %d P · %d V · LOCAL"%[
            _player_name.display_name,int(stats.get("played",0)),
            int(stats.get("wins",0))]


func _save_player_name() -> void:
    if stage!="lobby" or _player_name==null or _name_entry==null:
        return
    var candidate: String=_name_entry.text
    var saved: Error=_player_name.save_name(candidate)
    if saved!=OK:
        _info.text="NOMBRE NO GUARDADO\nUsa entre 3 y 16 caracteres: letras, números, espacios internos o _.\nNo se permiten nombres reservados."
        return
    _name_entry.text=_player_name.display_name
    _update_identity_strip(_offline_records.snapshot())
    _select_tab("CUENTA")


func _firebase_state_message(reason: String) -> String:
    if reason=="android_device_required":
        return "El acceso requiere un dispositivo Android"
    if reason=="android_plugin_missing":
        return "Esta APK no incluye el plugin de acceso"
    if reason.begins_with("plugin_contract_incomplete"):
        return "Plugin detectado, faltan métodos: "+reason.get_slice(":",1)
    if reason=="firebase_configuration_incomplete":
        return "Firebase todavía no se ha inicializado"
    if reason=="app_check_unverified":
        return "App Check pendiente: revisa internet y Google Play"
    return reason.replace("_"," ")


func _check_firebase_connection() -> void:
    if stage!="lobby" or _selected_tab!="CUENTA" or _info==null:
        return
    var state: Dictionary=FIREBASE_BRIDGE.status()
    _sync_lobby_match_mode()
    if not bool(state.get("ready",false)):
        _info.text="FIREBASE / APP CHECK: SIN CONEXIÓN\n"
        _info.text+="Estado: %s\n"%_firebase_state_message(
            str(state.get("reason","desconocido")))
        _info.text+="No se ha iniciado sesión ni asignado ID.\n"
        _info.text+="Google e Invitado estarán disponibles al verificar App Check."
        return
    var session: Dictionary=FIREBASE_BRIDGE.session_state()
    _sync_lobby_match_mode()
    if bool(session.get("identity_confirmed",false)):
        _info.text="FIREBASE AUTH / SESIÓN AUTENTICADA\n"
        _info.text+="ID OFICIAL: %s\n"%str(session.get("official_id",""))
        var server_name: String=str(session.get("display_name",""))
        _info.text+="NOMBRE DE CUENTA: %s\n"%(
            server_name if not server_name.is_empty() else "Pendiente de servidor")
        _info.text+="Proveedor: %s\n"%str(session.get("provider",""))
        _info.text+="Estos datos provienen de callables Firebase. El saldo y las partidas locales NO se sincronizan automáticamente."
        _update_identity_strip(_offline_records.snapshot())
        return
    if bool(session.get("authenticated",false)):
        _info.text="FIREBASE AUTH / SESIÓN ACTIVA\n"
        _info.text+="ID PERMANENTE: PENDIENTE DEL SERVIDOR\n"
        _info.text+="Estado: %s\n"%str(session.get("reason","identity_pending"))
        _info.text+="No se muestran IDs hasta comprobar ensurePlayerIdentity."
        return
    _info.text="PLUGIN FIREBASE ANDROID DETECTADO\n"
    _info.text+="Token App Check disponible; falta autenticar.\n"
    _info.text+="Selecciona Invitado o Google. El backend verificará el token antes de dar un ID."


func _start_native_auth(provider: String) -> void:
    if stage!="lobby" or _selected_tab!="CUENTA":
        return
    var attempt: Dictionary=FIREBASE_BRIDGE.request_sign_in(provider)
    if not bool(attempt.get("queued",false)):
        _info.text="ACCESO NO INICIADO\n"
        _info.text+="Estado: %s\n"%str(attempt.get("reason","bloqueado"))
        _info.text+="No se han modificado UID, perfil ni monedas."
        return
    _info.text="SOLICITUD DE ACCESO ENVIADA\n"
    _info.text+="Proveedor: %s\n"%provider
    _info.text+="La confirmación es asíncrona. Pulsa Verificar Firebase / App Check para consultar la sesión y el ID real."


func _on_objective_category_selected(index: int) -> void:
    if _objective_selector==null:
        return
    match _objective_selector.get_item_id(index):
        0:
            _objective_page="missions"
        1:
            _objective_page="achievements"
        2:
            _objective_page="events"
        _:
            _objective_page="missions"
    _update_objective_details()


## These milestones are displayed from verified saved matches. They are not
## a server event, seasonal quest or purchasable reward.
func _update_objective_details() -> void:
    if _info==null or _offline_records==null:
        return
    var stats: Dictionary=_offline_records.snapshot()
    var played: int=int(stats.get("played",0))
    var wins: int=int(stats.get("wins",0))
    var kills: int=int(stats.get("kills",0))
    match _objective_page:
        "missions":
            _info.text="MISIONES / METAS LOCALES\n"
            _info.text+="Partidas clásicas: %d / 3\n"%mini(played,3)
            _info.text+="Eliminaciones acumuladas: %d / 5\n"%mini(kills,5)
            _info.text+="Victorias: %d / 1\n"%mini(wins,1)
            _info.text+="Los valores se calculan con resultados realmente guardados.\n"
            _info.text+="Las recompensas de misiones online no están habilitadas."
        "achievements":
            _info.text="LOGROS / HISTORIAL REAL\n"
            _info.text+=("Primera partida: COMPLETADO" if played>=1 else
                "Primera partida: PENDIENTE")+"\n"
            _info.text+=("Primera victoria: COMPLETADO" if wins>=1 else
                "Primera victoria: PENDIENTE")+"\n"
            _info.text+=("10 eliminaciones: COMPLETADO" if kills>=10 else
                "10 eliminaciones: %d / 10"%kills)+"\n"
            _info.text+="Sin premios ni trofeos online ficticios."
        "events":
            _info.text="EVENTOS / SIN TEMPORADA ACTIVA\n"
            _info.text+="Los eventos con fechas, objetivos y premios necesitan "
            _info.text+="cuenta, programación y validación del servidor.\n"
            _info.text+="Tus resultados clásicos locales se siguen guardando."
        _:
            _info.text="OBJETIVOS / NO DISPONIBLES"


func _on_match_mode_selected(index: int) -> void:
    if _match_mode_selector==null:
        return
    match _match_mode_selector.get_item_id(index):
        0:
            _selected_match_mode="classic"
        1:
            _selected_match_mode="ranked"
        2:
            _selected_match_mode="training"
        _:
            _selected_match_mode="classic"
    _sync_lobby_match_mode()


func _sync_lobby_match_mode() -> void:
    if stage!="lobby" or _match_mode_selector==null:
        return
    var show_modes: bool=_selected_tab=="JUGAR"
    var show_name: bool=_selected_tab=="CUENTA"
    _name_entry.visible=show_name
    _name_save_button.visible=show_name
    _firebase_check_button.visible=show_name
    _account_connection_label.visible=show_name
    _login_manage_button.visible=show_name
    # Login providers belong only to the dedicated entry/account-change UI.
    _auth_guest_button.visible=false
    _auth_google_button.visible=false
    if show_name:
        var health: Dictionary=FIREBASE_BRIDGE.status()
        var ready: bool=bool(health.get("ready",false))
        _auth_guest_button.disabled=not ready
        _auth_google_button.disabled=not ready
        var message: String=str(health.get("reason","desconocido"))
        _account_connection_label.text=(
            "FIREBASE DISPONIBLE · Gestiona el acceso" if ready else
            "CONEXIÓN PENDIENTE · "+_firebase_state_message(message))
        _account_connection_label.tooltip_text=message
        _auth_google_button.tooltip_text=(
            "Acceder con la cuenta Google" if ready else message)
        _auth_guest_button.tooltip_text=(
            "Crear o recuperar sesión anónima" if ready else message)
    _objective_selector.visible=_selected_tab=="OBJETIVOS"
    _lobby_mode_heading.visible=false
    _match_mode_selector.visible=show_modes
    _lobby_play_modes.visible=show_modes and _selected_match_mode!="ranked"
    _battle_entry.visible=show_modes and _selected_match_mode=="classic"
    _training_entry.visible=show_modes and _selected_match_mode=="training"
    _lobby_mode_caption.visible=show_modes and _selected_match_mode=="classic"
    _pass_progress.visible=_selected_tab=="PASE"
    _pass_claim_button.visible=_selected_tab=="PASE"
    _shop_selector.visible=_selected_tab in ["TIENDA","PERSONAJE"]
    _shop_buy_button.visible=_selected_tab=="TIENDA"
    _shop_equip_button.visible=_selected_tab=="TIENDA"
    _lobby_mode_status.visible=show_modes and _selected_match_mode=="ranked"
    _lobby_detail_scroll.visible=not show_modes and _selected_tab not in ["AJUSTES","PRESET"]
    match _selected_match_mode:
        "classic":
            _lobby_mode_status.text="BR CLÁSICO LOCAL · 50 PARTICIPANTES (1 JUGADOR + 49 IA).\nSin clasificación online."
        "ranked":
            _lobby_mode_status.text="CLASIFICATORIA BLOQUEADA\nRequiere cuentas, servidor autoritativo y anti-trampas."
        "training":
            _lobby_mode_status.text="ENTRENAMIENTO LOCAL · Sin puntos competitivos."
        _:
            _lobby_mode_status.text="Modo no disponible"


func _make_header_label(label_name: String,left: float,right: float,
        font_size: int) -> Label:
    var strip:=Label.new()
    strip.name=label_name
    strip.anchor_left=left
    strip.anchor_right=right
    strip.anchor_top=.035
    strip.anchor_bottom=.035
    strip.offset_bottom=43
    strip.clip_text=true
    strip.add_theme_font_size_override("font_size",font_size)
    strip.add_theme_color_override("font_color",Color(.90,.97,1))
    strip.add_theme_color_override("font_shadow_color",Color(.01,.035,.07))
    strip.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _surface.add_child(strip)
    return strip


func _ensure_lobby_navigation() -> void:
    if _lobby_nav!=null and is_instance_valid(_lobby_nav):
        return
    # A glass header, physically behind real labels/buttons and above
    # the artwork. Previous backplates were inserted BEHIND the SVG,
    # which made UI illegible despite having valid gameplay actions.
    _header_glass=_make_glass_panel(
        Color(.009,.019,.039,.96),Color(.31,.56,.69,.66),9)
    _header_glass.name="AuroraOperationalHeader"
    _header_glass.anchor_left=.018
    _header_glass.anchor_right=.982
    _header_glass.anchor_top=.009
    _header_glass.anchor_bottom=.133
    _surface.add_child(_header_glass)
    _surface.move_child(_header_glass,_page.get_index())
    _lobby_backplates.append(_header_glass)
    _profile_strip=_make_header_label(
        "LocalProfileStrip",.107,.313,14)
    _stats_strip=_make_header_label(
        "LocalStatisticsStrip",.322,.558,12)
    _currency_strip=_make_header_label(
        "LocalCurrencyStrip",.569,.729,11)
    var backplate:=_make_glass_panel(
        Color(.012,.028,.067,.96),Color(.29,.66,.86,.78),10)
    backplate.name="LobbyMenuBackplate"
    backplate.anchor_left=.712
    backplate.anchor_right=.981
    backplate.anchor_top=.154
    backplate.anchor_bottom=.867
    _surface.add_child(backplate)
    _surface.move_child(backplate,_page.get_index())
    _lobby_backplates.append(backplate)
    var navplate:=_make_glass_panel(
        Color(.012,.029,.068,.93),Color(.31,.67,.86,.75),10)
    navplate.name="LobbySidebarBackplate"
    navplate.anchor_left=.017
    navplate.anchor_right=.208
    navplate.anchor_top=.261
    navplate.anchor_bottom=.870
    _surface.add_child(navplate)
    _surface.move_child(navplate,_page.get_index())
    _lobby_backplates.append(navplate)
    _lobby_nav=VBoxContainer.new()
    _lobby_nav.name="LobbyNavigation"
    _lobby_nav.anchor_left=.038
    _lobby_nav.anchor_right=.211
    _lobby_nav.anchor_top=.177
    _lobby_nav.anchor_bottom=.93
    _lobby_nav.add_theme_constant_override("separation",4)
    _surface.add_child(_lobby_nav)
    # A prominent JUGAR entry is always first. Remaining modules have
    # permanent locations, rather than being buried under overlapping UI.
    for tab in ["JUGAR","PERSONAJE","ARMAS","OBJETIVOS","TIENDA","PASE","SOCIAL","CUENTA","AJUSTES"]:
        var tab_name: String=tab
        var button:=_button(tab_name,Callable(self,"_select_tab").bind(tab_name),154)
        button.name="Tab"+tab_name
        var compact: bool=_surface.size.y<620.0
        button.custom_minimum_size=Vector2(154,31 if compact else 42)
        button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        button.add_theme_font_size_override("font_size",13 if compact else 17)
        if tab=="JUGAR":
            _style_primary_action(button)
        _lobby_nav.add_child(button)

    # The previous nine-tab rail remains as the gameplay routing contract,
    # but its redundant giant buttons are hidden. Use the explicit Aurora
    # commerce rail + bottom arsenal shortcuts instead, as in the supplied
    # mobile reference, WITHOUT claiming unavailable online purchases.
    _lobby_nav.visible=false
    _banner=Label.new()
    _banner.name="AuroraOperationBanner"
    _banner.text="BASE AURORA  ◆\nCENTRO DE DESPLIEGUE"
    _banner.anchor_left=.028
    _banner.anchor_right=.211
    _banner.anchor_top=.163
    _banner.anchor_bottom=.254
    _banner.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _banner.add_theme_font_size_override("font_size",14)
    _banner.add_theme_color_override("font_color",Color(.98,.79,.40))
    _banner.add_theme_color_override("font_shadow_color",Color(.02,.06,.10,.95))
    _surface.add_child(_banner)

    _lobby_status_ribbon=PanelContainer.new()
    _lobby_status_ribbon.name="AuroraLiveOperationRibbon"
    # Keep the status plaque to Lila's left; never obscure her face.
    _lobby_status_ribbon.anchor_left=.219
    _lobby_status_ribbon.anchor_right=.446
    _lobby_status_ribbon.anchor_top=.171
    _lobby_status_ribbon.anchor_bottom=.228
    _lobby_status_ribbon.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var operation_style:=StyleBoxFlat.new()
    operation_style.bg_color=Color(.009,.024,.046,.84)
    operation_style.border_color=Color(.20,.62,.76,.66)
    operation_style.border_width_bottom=2
    operation_style.set_corner_radius_all(5)
    operation_style.content_margin_left=13
    operation_style.content_margin_right=11
    _lobby_status_ribbon.add_theme_stylebox_override("panel",operation_style)
    _lobby_status_caption=Label.new()
    _lobby_status_caption.name="AuroraOperationStatus"
    _lobby_status_caption.text="◆  BASE AURORA   /   LOCAL"
    _lobby_status_caption.clip_text=true
    _lobby_status_caption.add_theme_font_size_override("font_size",12)
    _lobby_status_caption.add_theme_color_override(
        "font_color",Color(.76,.91,.98))
    _lobby_status_caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _lobby_status_ribbon.add_child(_lobby_status_caption)
    _lobby_status_ribbon.visible=false
    _surface.add_child(_lobby_status_ribbon)

    _left_shortcuts=VBoxContainer.new()
    _left_shortcuts.name="AuroraCommerceRail"
    _left_shortcuts.anchor_left=.024
    _left_shortcuts.anchor_right=.202
    # Six 40px minimum tap targets + five 3px gaps fit in 964x434.
    _left_shortcuts.anchor_top=.265
    _left_shortcuts.anchor_bottom=.866
    _left_shortcuts.add_theme_constant_override("separation",3)
    _surface.add_child(_left_shortcuts)
    var quick_items: Array[Array]=[
        ["▣ TIENDA","TIENDA",""],
        ["✦ LUCK ROYALE","LUCK",""],
        ["♛ PASE DE BATALLA","PASE",""],
        ["▤ EVENTOS","OBJETIVOS","events"],
        ["☷ MISIONES","OBJETIVOS","missions"],
        ["★ LOGROS","OBJETIVOS","achievements"]
    ]
    for item in quick_items:
        var label: String=str(item[0])
        var target: String=str(item[1])
        var objective: String=str(item[2])
        var button:=_button(label,Callable(self,"_open_lobby_category").bind(
            target,objective),160)
        button.name="Quick"+(objective.to_upper() if not objective.is_empty()
            else target)
        button.custom_minimum_size=Vector2(0,40)
        button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        button.add_theme_font_size_override("font_size",12)
        _style_aurora_tab(button,Color(.35,.70,.91))
        _left_shortcuts.add_child(button)

    _bottom_navigation=HBoxContainer.new()
    _bottom_navigation.name="AuroraBottomNavigation"
    _bottom_navigation.anchor_left=.024
    _bottom_navigation.anchor_right=.975
    _bottom_navigation.anchor_top=.876
    _bottom_navigation.anchor_bottom=.969
    _bottom_navigation.add_theme_constant_override("separation",7)
    _surface.add_child(_bottom_navigation)
    for item in [
        ["JUGAR","JUGAR"],["INVENTARIO","INVENTARIO"],
        ["ARMAS","ARMAS"],["PERSONAJES","PERSONAJE"],
        ["PRESET","PRESET"],["SOCIAL","SOCIAL"]
    ]:
        var target: String=str(item[1])
        var button:=_button(str(item[0]),
            Callable(self,"_select_tab").bind(target),0)
        button.name="Bottom"+target
        button.custom_minimum_size=Vector2(0,30)
        button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        button.add_theme_font_size_override("font_size",12)
        if target=="JUGAR":
            _style_primary_action(button)
        else:
            _style_aurora_tab(button,Color(.30,.63,.83))
        _bottom_navigation.add_child(button)

    _social_panel=PanelContainer.new()
    _social_panel.name="AuroraRealSocialPanel"
    _social_panel.anchor_left=.720
    _social_panel.anchor_right=.974
    _social_panel.anchor_top=.172
    _social_panel.anchor_bottom=.459
    var social_style:=StyleBoxFlat.new()
    social_style.bg_color=Color(.014,.028,.050,.98)
    social_style.border_color=Color(.29,.60,.74)
    social_style.set_border_width_all(1)
    social_style.set_corner_radius_all(9)
    social_style.shadow_color=Color(.01,.02,.04,.40)
    social_style.shadow_size=4
    _social_panel.add_theme_stylebox_override("panel",social_style)
    _surface.add_child(_social_panel)
    var social_content:=VBoxContainer.new()
    social_content.name="SocialContent"
    social_content.add_theme_constant_override("separation",2)
    _social_panel.add_child(social_content)
    var social_title:=Label.new()
    social_title.text="ESCUADRA   /   LOCAL"
    social_title.name="FriendsHeading"
    social_title.add_theme_font_size_override("font_size",13)
    social_title.add_theme_color_override("font_color",Color(.9,.85,1))
    social_content.add_child(social_title)
    _social_status_label=Label.new()
    _social_status_label.name="ActualFriendsStatus"
    _social_status_label.text="01  ●  Operador local\nSin amigos conectados · Online pendiente"
    _social_status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _social_status_label.add_theme_font_size_override("font_size",10)
    _social_status_label.custom_minimum_size.y=29
    _social_status_label.add_theme_color_override("font_color",Color(.75,.8,.85))
    social_content.add_child(_social_status_label)
    var squad_slots:=HBoxContainer.new()
    squad_slots.name="AuroraFourMemberSquad"
    squad_slots.add_theme_constant_override("separation",3)
    social_content.add_child(squad_slots)
    # Slot 01 represents the local profile; 02–04 are clearly empty.
    # Do not fabricate online friends or send non-functional invitations.
    for i in range(4):
        var slot:=PanelContainer.new()
        slot.name="SquadSlot"+str(i+1)
        slot.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        slot.custom_minimum_size.y=23
        var slot_style:=StyleBoxFlat.new()
        slot_style.bg_color=(Color(.11,.20,.26,.94) if i==0 else
            Color(.023,.041,.063,.96))
        slot_style.border_color=(Color(.65,.80,.89,.76) if i==0 else
            Color(.23,.35,.45,.62))
        slot_style.set_border_width_all(1)
        slot_style.set_corner_radius_all(4)
        slot.add_theme_stylebox_override("panel",slot_style)
        var number:=Label.new()
        number.text="%02d %s"%[i+1,"LOCAL" if i==0 else "—"]
        number.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        number.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
        number.add_theme_font_size_override("font_size",9)
        number.add_theme_color_override(
            "font_color",Color(.92,.95,1) if i==0 else
            Color(.54,.64,.74))
        number.mouse_filter=Control.MOUSE_FILTER_IGNORE
        slot.add_child(number)
        squad_slots.add_child(slot)
    var social_open:=_button("GESTIONAR SOCIAL / CLAN",
        Callable(self,"_select_tab").bind("SOCIAL"),0)
    social_open.name="RealSocialEntry"
    social_open.custom_minimum_size=Vector2(0,27)
    social_open.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    social_open.add_theme_font_size_override("font_size",12)
    _style_aurora_tab(social_open,Color(.40,.65,.86))
    social_content.add_child(social_open)

    _play_match_card=PanelContainer.new()
    _play_match_card.name="BattleRoyaleModeCard"
    _play_match_card.anchor_left=.718
    _play_match_card.anchor_right=.977
    _play_match_card.anchor_top=.466
    _play_match_card.anchor_bottom=.867
    _play_match_card.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var match_card_style:=StyleBoxFlat.new()
    match_card_style.bg_color=Color(.013,.023,.039,.98)
    match_card_style.border_color=Color(.93,.64,.22)
    match_card_style.set_border_width_all(2)
    match_card_style.set_corner_radius_all(11)
    match_card_style.shadow_color=Color(.75,.43,.11,.37)
    match_card_style.shadow_size=6
    _play_match_card.add_theme_stylebox_override("panel",match_card_style)
    _surface.add_child(_play_match_card)
    _surface.move_child(_play_match_card,_page.get_index())

    _top_account_button=_button("CUENTA",
        Callable(self,"_select_tab").bind("CUENTA"),0)
    _top_account_button.name="TopAccount"
    _top_account_button.custom_minimum_size=Vector2.ZERO
    _top_account_button.anchor_left=.790
    _top_account_button.anchor_right=.863
    _top_account_button.anchor_top=.025
    _top_account_button.anchor_bottom=.131
    _top_account_button.add_theme_font_size_override("font_size",11)
    _style_aurora_tab(_top_account_button,Color(.53,.39,.87))
    _surface.add_child(_top_account_button)
    _top_settings_button=_button("⚙",
        Callable(self,"_open_settings"),0)
    _top_settings_button.name="TopSettings"
    _top_settings_button.custom_minimum_size=Vector2.ZERO
    _top_settings_button.anchor_left=.875
    _top_settings_button.anchor_right=.926
    _top_settings_button.anchor_top=.025
    _top_settings_button.anchor_bottom=.131
    _top_settings_button.add_theme_font_size_override("font_size",18)
    _style_aurora_tab(_top_settings_button,Color(.53,.39,.87))
    _surface.add_child(_top_settings_button)
    _top_social_button=_button("♙",
        Callable(self,"_select_tab").bind("SOCIAL"),0)
    _top_social_button.name="TopSocial"
    _top_social_button.custom_minimum_size=Vector2.ZERO
    _top_social_button.anchor_left=.730
    _top_social_button.anchor_right=.784
    _top_social_button.anchor_top=.025
    _top_social_button.anchor_bottom=.131
    _top_social_button.add_theme_font_size_override("font_size",17)
    _style_aurora_tab(_top_social_button,Color(.53,.39,.87))
    _surface.add_child(_top_social_button)


func _style_aurora_tab(button: Button,tint: Color) -> void:
    var normal:=StyleBoxFlat.new()
    normal.bg_color=Color(.012,.026,.049,.95)
    normal.border_color=tint.darkened(.28)
    normal.set_border_width_all(1)
    normal.border_width_left=3
    normal.set_corner_radius_all(6)
    var hover:=normal.duplicate() as StyleBoxFlat
    hover.bg_color=Color(.072,.12,.19,.98)
    var pressed:=hover.duplicate() as StyleBoxFlat
    pressed.border_color=Color(.98,.77,.31)
    button.add_theme_stylebox_override("normal",normal)
    button.add_theme_stylebox_override("hover",hover)
    button.add_theme_stylebox_override("pressed",pressed)
    button.add_theme_color_override("font_color",Color(.95,.95,1))
    button.add_theme_color_override("font_hover_color",Color(1,.88,.64))


func _open_lobby_category(tab: String,objective: String="") -> void:
    if not objective.is_empty():
        _objective_page=objective
        if _objective_selector!=null:
            _objective_selector.select(["missions","achievements","events"].find(
                objective))
    _select_tab(tab)


func _select_tab(tab: String) -> void:
    _selected_tab=tab
    if stage!="lobby" or _info==null:
        return
    _settings_panel.visible=tab in ["AJUSTES","PRESET"]
    if _left_shortcuts!=null:
        for button in _left_shortcuts.get_children():
            if button is Button:
                var target: String=button.name.trim_prefix("Quick")
                var active: bool=(target==tab or (tab=="OBJETIVOS" and
                    target==str(_objective_page).to_upper()))
                button.modulate=Color.WHITE if active else Color(.72,.76,.85)
    if _bottom_navigation!=null:
        for button in _bottom_navigation.get_children():
            if button is Button:
                button.modulate=(Color.WHITE if button.name=="Bottom"+tab
                    else Color(.72,.76,.85))
    if _social_panel!=null:
        _social_panel.visible=tab=="JUGAR"
    if _play_match_card!=null:
        _play_match_card.visible=tab=="JUGAR"
    _page.anchor_left=.733
    _page.anchor_right=.962
    _page.anchor_top=.487 if tab=="JUGAR" else .183
    _page.anchor_bottom=.854
    for button in _lobby_nav.get_children():
        if button is Button:
            var selected: bool=button.name=="Tab"+tab
            button.modulate=Color(1,1,1) if selected else Color(.76,.82,.89)
    if _lobby_section_title!=null:
        _lobby_section_title.text=(
            "BATTLE ROYALE" if tab=="JUGAR"
            else "MI CUENTA" if tab=="CUENTA"
            else "CONFIGURACIÓN" if tab in ["AJUSTES","PRESET"]
            else "EVENTOS / MISIONES / LOGROS" if tab=="OBJETIVOS"
            else tab)
        _lobby_section_hint.text=(
            "BASE AURORA · 50 PARTICIPANTES" if tab=="JUGAR"
            else "PERFIL / RESPALDO / ACCESO" if tab=="CUENTA"
            else "CONTROLES / SENSIBILIDAD / HUD" if tab in ["AJUSTES","PRESET"]
            else "BASE AURORA · CENTRO DE OPERACIONES")
    match tab:
        "JUGAR":
            _info.text="BR CLÁSICO · 50 PARTICIPANTES\n1 operador y 49 rivales IA. Pulsa INICIAR para desplegarte.\nCLASIFICATORIA ONLINE: pendiente de servidor."
        "AJUSTES","PRESET":
            _info.text="CÁMARA / PRECISIÓN / HUD\nSensibilidades y controles personalizables guardados en este dispositivo."
        "PERSONAJE":
            var stats: Dictionary=_offline_records.snapshot()
            _info.text="LILA AURORA\nTraje táctico personalizable.\nCAMBIAR VISTA / GIRAR: controles táctiles bajo Lila.\nVISTA 3D: %s · sin compra ni equipamiento."%_shop_selected_skin.to_upper()
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
        "INVENTARIO":
            _info.text="INVENTARIO EN PARTIDA\nArmas, munición, casco y botiquines se recogen físicamente en el Battle Royale.\nTu equipo se consulta desde el HUD del combate.\nNo hay compras ni objetos permanentes inventados."
        "ARMAS":
            _info.text="ARSENAL ACTIVO\nAR-7: mira x2 / x4.\nAWM: mira x8 y cerrojo automático.\nBR: AWM sobre el suelo, en la PLAZA (8, 24).\nENTRENAMIENTO: pulsa ARMA para probarla."
        "OBJETIVOS":
            _update_objective_details()
        "LUCK":
            _info.text="LUCK ROYALE / SIN SORTEOS ACTIVOS\nSolo se habilitarán sorteos con probabilidades publicadas y un catálogo real.\nNo se cobran monedas ni diamantes mientras el servicio esté desconectado."
        "TIENDA":
            _refresh_local_skin_store()
        "PASE":
            _refresh_free_pass()
        "SOCIAL":
            _info.text="AMIGOS Y CLANES\nAún no existe un servidor social autenticado.\nNo hay amigos ficticios, invitaciones simuladas ni chat mundial falso.\nLas partidas locales siguen disponibles."
        "CUENTA":
            var stats: Dictionary=_offline_records.snapshot()
            var health: Dictionary=_offline_records.auto_backup_status()
            var auto_text: String="COPIA AUTOMÁTICA LOCAL: %d partidas verificadas"%int(
                health.get("played",0)) if bool(health.get("in_sync",false)) else (
                "COPIA AUTOMÁTICA LOCAL: pendiente" if not bool(health.get("available",false))
                else "COPIA AUTOMÁTICA LOCAL: desactualizada")
            var session: Dictionary=FIREBASE_BRIDGE.session_state()
            var id_line: String="ID OFICIAL: PENDIENTE DE FIREBASE"
            var name_line: String=_player_name.display_name+" (local)"
            if bool(session.get("identity_confirmed",false)):
                id_line="ID OFICIAL: %s"%str(session.get("official_id",""))
                var remote_name: String=str(session.get("display_name",""))
                name_line=(remote_name+" (Firebase)" if not remote_name.is_empty()
                    else _player_name.display_name+" (local; nombre remoto pendiente)")
            _info.text="Firebase / Perfil\nNOMBRE: %s\n%s\n%s\nGoogle e Invitado se administran en la pantalla de entrada. El apodo y las monedas siguen guardados localmente; no se declara sincronización sin confirmación del servidor."%[
                name_line,id_line,auto_text]
        _:
            _info.text="SECCIÓN NO DISPONIBLE"
    _sync_lobby_match_mode()
    # Real 3D cosmetics are previewed only in the shop/character screens.
    # Leaving both restores the equipped outfit; no purchase is performed.
    if _offline_records!=null and _preview_avatar!=null and (
            is_instance_valid(_preview_avatar)):
        var shown: String=(_shop_selected_skin if tab in ["TIENDA","PERSONAJE"] else
            str(_offline_records.cosmetic_state()["equipped"]))
        _apply_preview_skin(shown)

func _apply_preview_skin(skin: String) -> void:
    if stage!="lobby" or _preview_avatar==null or not (
            is_instance_valid(_preview_avatar)) or (
            _preview_skin_applied==skin):
        return
    if COSMETICS.apply_to_operator(_preview_avatar,skin):
        _preview_skin_applied=skin


func _on_shop_skin_selected(index: int) -> void:
    var ids: Array[String]=["aurora_base","aurora_glacier","aurora_ember"]
    if index>=0 and index<ids.size():
        _shop_selected_skin=ids[index]
    if stage=="lobby" and _selected_tab in ["TIENDA","PERSONAJE"]:
        if _selected_tab=="TIENDA":
            _refresh_local_skin_store()
        else:
            _select_tab("PERSONAJE")
        _apply_preview_skin(_shop_selected_skin)


func _refresh_local_skin_store() -> void:
    if _offline_records==null or _info==null:
        return
    var state: Dictionary=_offline_records.cosmetic_state()
    var skin: String=_shop_selected_skin
    var price: int=int(MATCH_RECORDS.LOCAL_SKINS.get(skin,0))
    var owned: bool=(state["owned"] as Array).has(skin)
    var equipped: bool=str(state["equipped"])==skin
    _info.text="TIENDA AURORA · TRAJES REALES 3D\nVISTA PREVIA: "+skin.to_upper()+" (SIN EQUIPAR)\n"+(
        "MONEDAS LOCALES: %d\n"%int(state["coins"]))+(
        "SELECCIONADO: %s\n"%skin.to_upper())+(
        "PRECIO: %d · %s\n"%[price,
            "COMPRADO" if owned else "NO COMPRADO"])+(
        "EQUIPADO: %s\n"%str(state["equipped"]).to_upper())+(
        "Dos paletas tácticas reales sobre la armadura de Lila. "+
        "Sólo monedas de partidas guardadas. "+
        "Sin pagos, diamantes ni compras en línea.")
    _shop_buy_button.disabled=owned or price<=0 or (
        int(state["coins"])<price)
    _shop_buy_button.text=("COMPRADO" if owned else
        "COMPRAR · %d MONEDAS LOCALES"%price)
    _shop_equip_button.disabled=not owned or equipped
    _shop_equip_button.text=(
        "EQUIPADO" if equipped else "EQUIPAR TRAJE")


func _update_cosmetic_after_transaction() -> void:
    var state: Dictionary=_offline_records.cosmetic_state()
    _currency_strip.text="MONEDAS %d\nDIAMANTES —"%int(
        state["coins"])
    if _preview_avatar!=null and is_instance_valid(_preview_avatar):
        _apply_preview_skin(_shop_selected_skin)
    _refresh_local_skin_store()


func _buy_local_skin() -> void:
    if stage!="lobby" or _selected_tab!="TIENDA":
        return
    if _offline_records.purchase_local_skin(_shop_selected_skin):
        _update_cosmetic_after_transaction()
    else:
        _refresh_local_skin_store()


func _equip_local_skin() -> void:
    if stage!="lobby" or _selected_tab!="TIENDA":
        return
    if _offline_records.equip_local_skin(_shop_selected_skin):
        _update_cosmetic_after_transaction()
    else:
        _refresh_local_skin_store()


func _refresh_free_pass() -> void:
    # Displays earned, verified local match progression. Paid tiers and
    # unverified online entitlements remain disabled.
    if _offline_records==null or _info==null:
        return
    var state: Dictionary=_offline_records.free_pass_state()
    _info.text="OPERACIÓN AURORA · PASE GRATUITO LOCAL\n"+(
        "NIVELES DESBLOQUEADOS: %d / %d\n"%[
            int(state["unlocked"]),int(state["tier_count"])]) + (
        "PUNTOS DE PARTIDAS: %d\n"%int(state["points"])) + (
        "RECOMPENSAS COBRADAS: %d\n"%int(state["claimed"])) + (
        "Juega BR local para progresar. Cada nivel cuesta %d puntos.\n"%(
            MATCH_RECORDS.PASS_TIER_POINTS)) + (
        "Premio real por nivel: %d MONEDAS LOCALES.\n"%int(state["reward"])) + (
        "Sin temporada de pago, diamantes, pase premium ni servidor de rangos.")
    if _pass_progress!=null:
        _pass_progress.value=float(state["progress"])
    if _pass_claim_button!=null:
        var next_tier: int=int(state["next_claimable"])
        _pass_claim_button.disabled=next_tier<=0
        _pass_claim_button.text=("RECLAMAR NIVEL %d · +%d MONEDAS"%[
            next_tier,int(state["reward"])] if next_tier>0
            else "SIN RECOMPENSAS POR RECLAMAR")


func _claim_pass_reward() -> void:
    if stage!="lobby" or _selected_tab!="PASE" or _offline_records==null:
        return
    if not _offline_records.claim_next_pass_reward():
        _refresh_free_pass()
        return
    var stats: Dictionary=_offline_records.snapshot()
    _currency_strip.text="MONEDAS %d\nDIAMANTES —"%int(
        stats.get("local_coins",0))
    _refresh_free_pass()


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
    # Ranked cannot be disguised as an offline match or accrue fictitious RP.
    # Opening the real HUD editor may temporarily enter Training by design.
    if _selected_match_mode=="ranked" and not _hud_editor_requested:
        return
    if not _hud_editor_requested:
        AuroraLobbyMusic.leave_lobby()
    stage="loading"
    FLIGHT_DIAGNOSTICS.checkpoint("active","scene_load",null,
        "frontend_launch_requested",
        "mode="+("battle" if battle else "training")+
        " startup_profile="+str(STARTUP_DIAG.mode()))
    # Unload the 440x600 offscreen character renderer (its own 3D world,
    # lights, rig and textures) before entering a memory-heavy Android match.
    # Hiding it only stopped drawing but retained VRAM/mesh allocations.
    _release_preview()
    _clear_page()
    _show_loading("PREPARANDO PUERTO AURORA","Montando terreno, operador y controles…",true)
    _loading_cancel.show()
    _launch_serial+=1
    call_deferred("_activate_game",battle,_launch_serial)


func _activate_game(battle: bool,serial: int) -> void:
    if stage!="loading" or serial!=_launch_serial:
        return
    # The queued SubViewport is actually freed at the end of the frame,
    # AFTER deferred calls. One frame boundary avoids overlapping both
    # render targets and both animated player rigs during match creation.
    await get_tree().process_frame
    if stage!="loading" or serial!=_launch_serial:
        return
    FLIGHT_DIAGNOSTICS.checkpoint("active","scene_load",null,
        "frontend_scene_instantiate_before",
        "mode="+("battle" if battle else "training"))
    _loading_cancel.hide()
    _game=_game_scene.instantiate() as Node3D
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
    _launch_serial+=1
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
        var sound: Node3D=old.get_node_or_null("AuroraSoundStage")
        if sound!=null:
            sound.set_enabled(false)
        old.get_parent().remove_child(old)
        old.queue_free()
    _hud_editor_requested=false
    _hud_editor_origin=""
    _show_lobby()


func _release_preview() -> void:
    # A hidden SubViewport still retains its render target and imported
    # skinned rig. Queue-free it on logout AND before 3D match creation.
    if _preview_container!=null and is_instance_valid(_preview_container):
        _preview_container.queue_free()
    if _preview_frame_tween!=null and _preview_frame_tween.is_valid():
        _preview_frame_tween.kill()
    if _preview_turn_tween!=null and _preview_turn_tween.is_valid():
        _preview_turn_tween.kill()
    _preview_frame_tween=null
    _preview_turn_tween=null
    for action in _operator_controls:
        if is_instance_valid(action):
            action.queue_free()
    _operator_controls.clear()
    if _gesture_button!=null and is_instance_valid(_gesture_button):
        _gesture_button.queue_free()
    _gesture_button=null
    _preview_zoomed=false
    _preview_skin_applied=""
    if _preview_caption!=null and is_instance_valid(_preview_caption):
        _preview_caption.queue_free()
    _preview_container=null
    _preview_caption=null
    _preview_avatar=null
    _preview_touch=-1
    _preview_mouse_drag=false
    _preview_resume_spin=0.0


func _rotate_operator(step: float) -> void:
    # Turn the same skinned 3D operator with a short actual tween.
    if stage!="lobby" or _preview_avatar==null or not is_instance_valid(
            _preview_avatar):
        return
    if _preview_turn_tween!=null and _preview_turn_tween.is_valid():
        _preview_turn_tween.kill()
    _preview_resume_spin=4.0
    _preview_turn_tween=create_tween()
    _preview_turn_tween.set_trans(Tween.TRANS_CUBIC)
    _preview_turn_tween.set_ease(Tween.EASE_OUT)
    _preview_turn_tween.tween_property(_preview_avatar,"rotation:y",
        _preview_avatar.rotation.y+step*.50,.28)


func _toggle_operator_frame() -> void:
    # Real camera changes; no replacement still-image portrait.
    if stage!="lobby" or _preview_container==null or not is_instance_valid(
            _preview_container):
        return
    var camera: Camera3D=_preview_container.get_node_or_null(
        "PreviewViewport/AuroraCharacterStage/LobbyPortraitCamera") as Camera3D
    if camera==null:
        return
    if _preview_frame_tween!=null and _preview_frame_tween.is_valid():
        _preview_frame_tween.kill()
    _preview_zoomed=not _preview_zoomed
    _preview_resume_spin=3.0
    # Full-body mode fits between the top profile strip and bottom controls.
    # Close-up lifts the lens so Lila's face does not disappear under the header.
    var target_fov: float=45.0 if _preview_zoomed else 54.0
    var target_position: Vector3=(Vector3(-.10,1.48,2.95)
        if _preview_zoomed else Vector3(-.10,1.18,3.07))
    _preview_frame_tween=create_tween()
    _preview_frame_tween.set_parallel(true)
    _preview_frame_tween.set_trans(Tween.TRANS_CUBIC)
    _preview_frame_tween.set_ease(Tween.EASE_OUT)
    _preview_frame_tween.tween_property(camera,"fov",target_fov,.25)
    _preview_frame_tween.tween_property(
        camera,"position",target_position,.25)


func _play_lobby_gesture() -> void:
    if stage!="lobby" or _preview_avatar==null or not is_instance_valid(
            _preview_avatar):
        return
    var animator:=_preview_avatar.find_child(
        "AnimationPlayer",true,false) as AnimationPlayer
    if animator==null or not animator.has_animation(LOBBY_MOTION_CLIP):
        return
    if animator.current_animation==LOBBY_MOTION_CLIP and animator.is_playing():
        return
    _preview_resume_spin=LOBBY_MOTION.length+2.0
    animator.play(LOBBY_MOTION_CLIP,.26)


func _install_lobby_motion(animator: AnimationPlayer) -> void:
    var motion:=LOBBY_MOTION.duplicate() as Animation
    var idle:=animator.get_animation("AuroraIdle")
    # Preserve the neutral leg, pelvis and finger tracks on Lila's podium.
    for i in range(idle.get_track_count()):
        var type: Animation.TrackType=idle.track_get_type(i)
        var path: NodePath=idle.track_get_path(i)
        if type not in [Animation.TYPE_ROTATION_3D,Animation.TYPE_POSITION_3D] or (
                motion.find_track(path,type)>=0 or idle.track_get_key_count(i)==0):
            continue
        var track: int=motion.add_track(type)
        motion.track_set_path(track,path)
        motion.track_insert_key(track,0.0,idle.track_get_key_value(i,0))
    var library:=AnimationLibrary.new()
    library.add_animation(&"Motion",motion)
    animator.add_animation_library(&"aurora_lobby",library)
    var gesture_timer:=Timer.new()
    gesture_timer.name="LobbyGestureTimer"
    animator.add_child(gesture_timer)
    gesture_timer.timeout.connect(func():
        gesture_timer.wait_time=26.0
        if stage=="lobby" and _preview_container and _preview_container.is_visible_in_tree() and (
                animator.current_animation==&"AuroraIdle"):
            animator.play(LOBBY_MOTION_CLIP,.28))
    animator.animation_finished.connect(func(clip: StringName):
        if clip==LOBBY_MOTION_CLIP:
            animator.play(&"AuroraIdle",.28))
    gesture_timer.start(10.0)


func _build_preview() -> void:
    # Real native 3D viewport, not a copied Free Fire character illustration.
    # Shows the actual skinned Lila Aurora v1 tactical kit, built directly
    # into the same GLB used by gameplay. Its CC0 face/hair/base body remain
    # provisional; no unsupported claim of final custom face sculpt.
    _preview_container=SubViewportContainer.new()
    _preview_container.name="AvatarPreview"
    _preview_container.anchor_left=0.0
    _preview_container.anchor_right=1.0
    _preview_container.anchor_top=0.0
    _preview_container.anchor_bottom=1.0
    _preview_container.stretch=true
    _preview_container.mouse_filter=Control.MOUSE_FILTER_PASS
    _preview_container.gui_input.connect(_preview_input)
    _preview_container.visible=false
    _surface.add_child(_preview_container)
    # The live 3D scene must render over the artwork but UNDER
    # the real battle card, commerce/social rails and touch buttons.
    var winter_art: Control=_surface.get_node("AuroraWinterBaseArtwork") as Control
    _surface.move_child(_preview_container,winter_art.get_index()+1)

    var viewport:=SubViewport.new()
    viewport.name="PreviewViewport"
    viewport.size=Vector2i(832,584)
    viewport.own_world_3d=true
    viewport.transparent_bg=true
    viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_PARENT_VISIBLE
    _preview_container.add_child(viewport)
    _layout_safe.call_deferred()
    var stage3d:=Node3D.new()
    stage3d.name="AuroraCharacterStage"
    viewport.add_child(stage3d)
    var hangar:=LOBBY_STAGE.new()
    hangar.name="AuroraReal3DLobbyEnvironment"
    stage3d.add_child(hangar)
    var ambient:=WorldEnvironment.new()
    var env:=Environment.new()
    # Let the 3D operator and companion stand against the winter art.
    env.background_mode=Environment.BG_CLEAR_COLOR
    env.background_color=Color(.016,.021,.048,0.0)
    env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color=Color(.78,.85,.98)
    env.ambient_light_energy=1.13
    ambient.environment=env
    stage3d.add_child(ambient)
    var key:=DirectionalLight3D.new()
    key.rotation_degrees=Vector3(-36,35,0)
    key.light_energy=1.55
    stage3d.add_child(key)
    var rim:=DirectionalLight3D.new()
    rim.rotation_degrees=Vector3(26,-135,0)
    rim.light_color=Color(.49,.75,1.0)
    rim.light_energy=1.13
    stage3d.add_child(rim)
    var camera:=Camera3D.new()
    camera.name="LobbyPortraitCamera"
    # V75.109 CI screenshot showed the operator's head hidden behind the
    # top UI and feet over the bottom rail. A 54-degree vertical FOV fits
    # the 1.96m preview rig inside the usable mobile lobby band.
    camera.position=Vector3(-.10,1.18,3.07)
    camera.fov=54.0
    camera.current=true
    stage3d.add_child(camera)
    camera.look_at(Vector3(-.08,.91,0),Vector3.UP)
    var sentinel: Node3D=LOBBY_COMPANION.new()
    sentinel.name="AuroraSentinelCompanion"
    sentinel.position=Vector3(1.06,-.03,.19)
    sentinel.scale=Vector3.ONE*.69
    stage3d.add_child(sentinel)
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

    if ResourceLoader.exists("res://assets/characters/lila_aurora.glb"):
        var source:=load("res://assets/characters/lila_aurora.glb") as PackedScene
        if source!=null:
            _preview_avatar=source.instantiate() as Node3D
            _preview_skin_applied=""
            _preview_avatar.name="LilaAuroraPreview"
            stage3d.add_child(_preview_avatar)
            _fit_avatar_for_preview(_preview_avatar)
            var anim:=_preview_avatar.find_child("AnimationPlayer",true,false) as AnimationPlayer
            # Lobby has no equipped hand-held rifle. Playing the armed grip
            # without a model made Lila's empty palms look glued together.
            # Use the real relaxed skeletal idle here; the actual match
            # keeps its weapon-ready and ADS animation states.
            if anim and anim.has_animation("AuroraIdle"):
                anim.get_animation("AuroraIdle").loop_mode=Animation.LOOP_LINEAR
                anim.play("AuroraIdle")
                anim.advance(.1)
                _install_lobby_motion(anim)

    var caption:=Label.new()
    caption.name="PreviewDisclosure"
    caption.text="LILA AURORA  /  OPERADOR 01    ↻ GIRAR"
    caption.anchor_left=.29
    caption.anchor_right=.65
    caption.anchor_top=.90
    caption.anchor_bottom=.90
    caption.offset_bottom=22
    caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    caption.add_theme_font_size_override("font_size",13)
    caption.add_theme_color_override("font_color",Color(.62,.84,.96))
    caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
    caption.visible=false
    _surface.add_child(caption)
    _preview_caption=caption
    _gesture_button=_button("GESTO  ▶",_play_lobby_gesture,0)
    _gesture_button.name="LilaLobbyGesture"
    _gesture_button.custom_minimum_size=Vector2.ZERO
    _gesture_button.anchor_left=.554
    _gesture_button.anchor_right=.690
    # At 964x434 these real touch targets are >40px high, not tiny labels.
    _gesture_button.anchor_top=.700
    _gesture_button.anchor_bottom=.804
    _gesture_button.add_theme_font_size_override("font_size",11)
    _style_aurora_tab(_gesture_button,Color(.53,.77,.93))
    _gesture_button.tooltip_text="Reproducir gesto animado de Lila"
    _gesture_button.visible=false
    _surface.add_child(_gesture_button)
    # Dedicated accessible controls supplement swipe rotation. Each control
    # acts on the actual 3D Lila rig/camera, never a background illustration.
    for item in [
        ["LilaTurnLeft","◀",Callable(self,"_rotate_operator").bind(-1.0),.222,.282],
        ["LilaTurnRight","▶",Callable(self,"_rotate_operator").bind(1.0),.289,.349],
        ["LilaCameraFrame","VISTA",Callable(self,"_toggle_operator_frame"),.361,.460]
    ]:
        var action: Button=_button(str(item[1]),item[2],0)
        action.name=str(item[0])
        action.custom_minimum_size=Vector2.ZERO
        action.anchor_left=float(item[3])
        action.anchor_right=float(item[4])
        action.anchor_top=.700
        action.anchor_bottom=.804
        action.add_theme_font_size_override("font_size",11)
        action.tooltip_text=(
            "Girar personaje 3D" if item[0]!="LilaCameraFrame" else
            "Alternar encuadre de cámara real")
        _style_aurora_tab(action,Color(.53,.77,.93))
        action.visible=false
        _surface.add_child(action)
        _operator_controls.append(action)


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
    var factor: float=clampf(1.96/length,.00001,100.0)
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

func _entry_should_show_briefing() -> bool:
    # Landscape handsets (including the Edge 60 Fusion) are much wider
    # than 16:9. Godot canvas_items stretching can preserve a 720px
    # logical viewport on a physically 434px-tall window: logical height
    # alone is not a reliable indication of available touch space.
    var physical: Vector2=Vector2(get_window().size)
    var safe: Rect2=SAFE_SCREEN.rect(get_viewport())
    if physical.y<=0.0:
        return false
    var wide_phone: bool=physical.x/maxf(1.0,physical.y)>=2.0
    return not wide_phone and minf(safe.size.y,physical.y)>=620.0


func _layout_safe() -> void:
    var safe: Rect2=SAFE_SCREEN.rect(get_viewport())
    _surface.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    _surface.position=safe.position
    _surface.size=safe.size
    # Adapt original LZ emblem to usable screen height: large desktop hero
    # but never clip the live progress/actions in 434px Motorola landscape.
    if _loading_emblem!=null and is_instance_valid(_loading_emblem):
        _loading_emblem.custom_minimum_size.y=clampf(
            safe.size.y*.16,69.0,122.0)
    if stage=="welcome" and _entry_info_panel!=null and is_instance_valid(
            _entry_info_panel):
        _entry_info_panel.visible=_entry_should_show_briefing()
    # SubViewportContainer with stretch=true OWNS its SubViewport.size.
    # Never write the child's size manually: Godot ignores that write and
    # warns every frame. Use stretch_shrink to cap the physical pixel count
    # while keeping the full-bleed stage scaled to the screen aspect.
    if _preview_container!=null and is_instance_valid(_preview_container):
        var pixel_count: float=maxf(1.0,safe.size.x*safe.size.y)
        var shrink: int=clampi(ceili(sqrt(pixel_count/520000.0)),1,4)
        if _preview_container.stretch_shrink!=shrink:
            _preview_container.stretch_shrink=shrink
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
