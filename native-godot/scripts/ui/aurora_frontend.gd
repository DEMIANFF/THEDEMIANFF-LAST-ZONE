extends Control
## Original Aurora front-end. Free Fire is UX reference ONLY; no copied layout,
## assets or proprietary game branding. Incomplete service tabs say so.
const SAFE_SCREEN=preload("res://scripts/ui/safe_screen.gd")
const PLAYER_SETTINGS=preload("res://scripts/persistence/player_settings.gd")
const LOBBY_BACKDROP=preload("res://scripts/ui/aurora_lobby_backdrop.gd")
const LOBBY_STAGE=preload("res://scripts/ui/aurora_lobby_stage_3d.gd")
const LOBBY_RESOLUTION=preload("res://scripts/ui/aurora_lobby_resolution.gd")
const RENDER_QUALITY=preload("res://scripts/render/aurora_render_budget.gd")
const LOBBY_COMPANION=preload("res://scripts/ui/aurora_robot_companion.gd")
const GAME_PATH: String="res://scenes/Main.tscn"
const SETTINGS_OVERLAY=preload("res://scripts/ui/aurora_settings_overlay.gd")
const MATCH_RECORDS = preload("res://scripts/persistence/offline_match_records.gd")
const COSMETICS=preload("res://scripts/player/aurora_operator_cosmetics.gd")
const LOBBY_MOTION = preload("res://assets/animations/aurora_lobby_motion.tres")
const LOBBY_MOTION_CLIP: StringName=&"aurora_lobby/Motion"
const MALE_PREVIEW=preload("res://scripts/player/aurora_mixamo_male_preview.gd")
const LOCAL_PLAYER_NAME=preload("res://scripts/persistence/local_player_name.gd")
const FIREBASE_BRIDGE=preload("res://scripts/persistence/aurora_firebase_bridge.gd")
const WEAPON_CATALOG=preload("res://scripts/combat/aurora_weapon_catalog.gd")
const WEAPON_FAMILIES=preload("res://scripts/combat/aurora_weapon_families.gd")
const EQUIPMENT_FAMILIES=preload("res://scripts/combat/aurora_equipment_families.gd")
const WEAPON_VISUALS=preload("res://scripts/combat/weapon_visuals.gd")
const PERFORMANCE=preload("res://scripts/persistence/aurora_performance_report.gd")
const FLIGHT_DIAGNOSTICS=preload("res://scripts/match/flight_diagnostics.gd")
const STARTUP_DIAG=preload("res://scripts/persistence/scene_startup_diagnostics.gd")
const FLIGHT_SAFETY_MODE=preload("res://scripts/persistence/flight_safety_mode.gd")
const DISPLAY_FONT=preload("res://assets/ui/fonts/BarlowCondensed-Bold.ttf")
const LOBBY_ICON_ATLAS=preload("res://assets/ui/aurora_lobby_navigation.svg")
const AIRFIELD_SKY=preload("res://assets/ui/aurora_night_sky.gdshader")
const LOBBY_OPERATOR_SURFACE=preload("res://assets/characters/lila_lobby_surface.gdshader")
const PORTRAIT_LIGHT_LAYER: int=2
# Original Aurora hints. No copyrighted in-game tips, false lobby rewards,
# fake network status or simulated progress bar increments.
const LOADING_TIPS: Dictionary={
    "startup":[
        "Consejo Aurora: calibra la sensibilidad antes de combatir.",
        "El minimapa se puede tocar para abrir el mapa táctico.",
        "Los ajustes gráficos modifican el render 3D, no tu HUD."
    ],
    "battle":[
        "Busca casco, chaleco y botiquines antes del primer cierre.",
        "La zona segura se contrae en cuatro fases durante el combate.",
        "Planifica tu aterrizaje: evita la zona abierta sin cobertura.",
        "Los suministros que recojas afectan tu inventario real."
    ],
    "training":[
        "Practica el retroceso y el cambio de armas en entrenamiento.",
        "Ajusta la sensibilidad de cada mira desde Configuración.",
        "Prueba distintas distancias y coberturas antes del BR."
    ],
    "hud_editor":[
        "Arrastra los controles y ajusta su tamaño y transparencia.",
        "Tu diseño HUD se guarda sin alterar la cuenta del jugador.",
        "Al guardar desde el lobby, regresarás al lobby."
    ]
}
const LOADING_TIP_INTERVAL: float=6.0

signal startup_finished
@export_file("*.tscn") var game_scene_path: String=GAME_PATH

var _mobile_options: RefCounted
var stage: String = "startup"
var _surface: Control
var _arctic_art: TextureRect
var _page: VBoxContainer
var _entry_glass: Panel
var _entry_mission_caption: Label
var _entry_hero_plate: Panel
var _entry_hero_kicker: Label
var _entry_panel_accent: ColorRect
var _loading_chapter: Label
var _loading_accent_stripe: ColorRect
var _loading_heartbeat: Tween
var _loading_emblem: TextureRect
var _loading_surface_plate: Panel
var _loading_actions: VBoxContainer
var _entry_info_panel: PanelContainer
var _header_glass: Panel
var _lobby_backplates: Array[Control]=[]
var _lobby_menu_backplate: Control
var _lobby_status_ribbon: PanelContainer
var _lobby_status_caption: Label
var _lobby_match_facts: HBoxContainer
var _lobby_compact_intel: PanelContainer
var _info: Label
var _game: Node3D
var _primary: Button
var _selected_tab: String = "JUGAR"
var _preview_container: SubViewportContainer
var _preview_avatar: Node3D
var _preview_weapon: Node3D
var _preview_weapon_slot: int=-1
var _armory_fill_light: OmniLight3D
var _armory_inspection_backdrop: Node3D
var _armory_matte_material: StandardMaterial3D
var _preview_caption: Label
var _gesture_button: Button
var _emote_wheel: PanelContainer
var _preview_press_origin: Vector2=Vector2.ZERO
var _preview_tap_dragged: bool=false
var _auto_resume_on_entry: bool=false
var _profile_overlay: Control
var _profile_name_label: Label
var _profile_id_label: Label
var _profile_session_label: Label
var _profile_stat_labels: Array[Label]=[]
var _operator_controls: Array[Button]=[]
var _preview_zoomed: bool=false
var _preview_frame_tween: Tween
var _preview_turn_tween: Tween
var _preview_skin_applied: String=""
var _preview_male_active: bool=false
var _preview_male_motion_index: int=0
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
var _objective_selector: TabBar
var _objective_page: String="missions"
var _objectives_progress_panel: VBoxContainer
var _objectives_progress_rows: Array[Dictionary]=[]
var _preview_touch: int=-1
var _preview_mouse_drag: bool=false
var _preview_drag_last: Vector2=Vector2.ZERO
var _preview_resume_spin: float=0.0
var _hud_editor_requested: bool=false
var _hud_editor_origin: String=""
var _settings_modal: CanvasLayer
var _brand_logo: TextureRect
var _match_mode_selector: OptionButton
var _mode_gallery_entry: Button
var _mode_gallery_overlay: Control
var _mode_gallery_cards: Dictionary={}
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
var _login_signout_button: Button
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
var _shop_gallery_entry: Button
var _shop_gallery_overlay: Control
var _shop_gallery_cards: Dictionary={}
var _shop_gallery_balance: Label
var _shop_gallery_status: Label
var _shop_gallery_buy: Button
var _shop_gallery_equip: Button
var _operator_selector: OptionButton
var _shop_buy_button: Button
var _shop_equip_button: Button
var _shop_selected_skin: String="aurora_glacier"
var _armory_list: ItemList
var _armory_category_selector: OptionButton
var _armory_category: int=0
var _armory_selected_slot: int=0
# A lobby catalogue choice changes the actual training armory order only.
# Never grant an uncollected BR weapon or persist a fictitious entitlement.
var _requested_training_weapon_slot: int=-1
var _armory_test_button: Button
var _equipment_selector: OptionButton
var _equipment_category_selector: OptionButton
var _equipment_category: int=0
var _equipment_selected: int=0
var _banner: Label
var _game_scene: PackedScene
var _loading_overlay: ColorRect
var _loading_title: Label
var _loading_detail: Label
var _loading_meter: ProgressBar
var _loading_tip_label: Label
var _loading_tip_context: String="startup"
var _loading_tip_index: int=0
var _loading_tip_clock: float=0.0
var _loading_retry: Button
var _loading_cancel: Button
var _loading_fade: Tween
var _startup_frame_seen: bool=false
var _launch_serial: int=0


func _ready() -> void:
    name = "AuroraFront"
    _mobile_options=PLAYER_SETTINGS.new()
    _player_name=LOCAL_PLAYER_NAME.new()
    # Frame cap is a runtime option; imported texture compression remains a build-time choice.
    Engine.max_fps=_mobile_options.fps_limit()
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
    var painted: Control=LOBBY_BACKDROP.new()
    painted.name="OriginalAuroraCoast"
    painted.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _surface.add_child(painted)
    _surface.move_child(painted,0)
    # The loading and sign-in illustration stays outside the lobby world.
    _arctic_art=TextureRect.new()
    _arctic_art.name="AuroraWinterBaseArtwork"
    _arctic_art.texture=load("res://assets/ui/aurora_polar_airfield.jpg")
    _arctic_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _arctic_art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    _arctic_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
    _arctic_art.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _surface.add_child(_arctic_art)
    _surface.move_child(_arctic_art,1)
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
    if _loading_overlay!=null and _loading_overlay.visible and (
            stage=="startup" or stage=="loading"):
        _tick_loading_tip(delta)
    if stage=="startup":
        _poll_bootstrap()
        return
    # Keep the real CC0 rig animated and turnable, without any extra 3D
    # viewport allocations. The full preview is freed before match creation.
    if stage!="lobby":
        return
    var subject: Node3D=(_preview_weapon if _selected_tab=="ARMAS" and
        is_instance_valid(_preview_weapon) else _preview_avatar)
    if subject==null or not is_instance_valid(subject):
        return
    _preview_resume_spin=maxf(0.0,_preview_resume_spin-delta)
    if _preview_resume_spin<=0.0 and _preview_touch<0 and not _preview_mouse_drag and (
            _emote_wheel==null or not _emote_wheel.visible):
        subject.rotation.y=wrapf(subject.rotation.y+delta*.18,-PI,PI)


func _exit_tree() -> void:
    AuroraLobbyMusic.leave_lobby()


func _preview_input(event: InputEvent) -> void:
    if stage!="lobby" or _preview_avatar==null:
        return
    var subject: Node3D=(_preview_weapon if _selected_tab=="ARMAS" and
        is_instance_valid(_preview_weapon) else _preview_avatar)
    if subject==null:
        return
    if event is InputEventScreenTouch:
        var touch:=event as InputEventScreenTouch
        if touch.pressed and not touch.canceled and _preview_touch<0:
            _preview_touch=touch.index
            _preview_press_origin=touch.position
            _preview_drag_last=touch.position
            _preview_tap_dragged=false
            _preview_resume_spin=2.2
            _preview_container.accept_event()
        elif touch.index==_preview_touch and (not touch.pressed or touch.canceled):
            var is_tap: bool=(not touch.canceled and not _preview_tap_dragged and
                touch.position.distance_to(_preview_press_origin)<14.0)
            _preview_touch=-1
            if is_tap and _preview_hit_character(touch.position):
                _toggle_character_emotes()
            _preview_container.accept_event()
    elif event is InputEventScreenDrag:
        var drag:=event as InputEventScreenDrag
        if drag.index==_preview_touch:
            if drag.position.distance_to(_preview_press_origin)>12.0:
                _preview_tap_dragged=true
                _close_character_emotes()
            subject.rotation.y=wrapf(
                subject.rotation.y+drag.relative.x*.008,-PI,PI)
            _preview_drag_last=drag.position
            _preview_resume_spin=2.2
            _preview_container.accept_event()
    elif event is InputEventMouseButton:
        var mouse:=event as InputEventMouseButton
        if mouse.button_index==MOUSE_BUTTON_LEFT:
            var point: Vector2=mouse.position
            if mouse.pressed:
                _preview_press_origin=point
                _preview_tap_dragged=false
            elif not _preview_tap_dragged and (
                    point.distance_to(_preview_press_origin)<14.0) and (
                    _preview_hit_character(point)):
                _toggle_character_emotes()
            _preview_mouse_drag=mouse.pressed
            _preview_drag_last=point
            _preview_resume_spin=2.2
            _preview_container.accept_event()
    elif event is InputEventMouseMotion and _preview_mouse_drag:
        var motion:=event as InputEventMouseMotion
        if motion.position.distance_to(_preview_press_origin)>12.0:
            _preview_tap_dragged=true
            _close_character_emotes()
        subject.rotation.y=wrapf(
            subject.rotation.y+motion.relative.x*.008,-PI,PI)
        _preview_drag_last=motion.position
        _preview_resume_spin=2.2


## The imported skinned GLB has bind-pose AABBs, not the character's
## rendered silhouette. Those old bounds can project onto the hangar/right
## rail despite Lila actually standing at the center of the portrait.
## Use her authored 1.96m preview frame (see _fit_avatar_for_preview)
## and the live portrait camera instead; only run when a tap is released.
## This deliberately excludes the podium, companion and distant scenery.
func _portrait_character_hit_rect() -> Rect2:
    if _preview_container==null or _preview_avatar==null or (
            not is_instance_valid(_preview_avatar) or
            not _preview_avatar.is_visible_in_tree()):
        return Rect2()
    var viewport: SubViewport=_preview_container.get_node_or_null(
        "PreviewViewport") as SubViewport
    if viewport==null or viewport.size.x<=0 or viewport.size.y<=0:
        return Rect2()
    var camera: Camera3D=viewport.get_node_or_null(
        "AuroraCharacterStage/LobbyPortraitCamera") as Camera3D
    if camera==null:
        return Rect2()
    # Never use stage or Sentinel meshes as a proxy for Lila.
    var body: MeshInstance3D=_preview_avatar.find_child(
        "Lila_Aurora_Mesh",true,false) as MeshInstance3D
    if body==null or body.mesh==null or not body.is_visible_in_tree():
        return Rect2()
    var center_world:=Vector3(
        _preview_avatar.global_position.x,0.98,
        _preview_avatar.global_position.z)
    var head_world:=Vector3(center_world.x,1.87,center_world.z)
    var feet_world:=Vector3(center_world.x,0.10,center_world.z)
    if camera.is_position_behind(center_world) or (
            camera.is_position_behind(head_world) or
            camera.is_position_behind(feet_world)):
        return Rect2()
    var canvas: Vector2=_preview_container.size
    if canvas.x<=0.0 or canvas.y<=0.0:
        return Rect2()
    var scale:=Vector2(
        canvas.x/float(viewport.size.x),
        canvas.y/float(viewport.size.y))
    var center: Vector2=camera.unproject_position(center_world)*scale
    var head: Vector2=camera.unproject_position(head_world)*scale
    var feet: Vector2=camera.unproject_position(feet_world)*scale
    if not center.is_finite() or not head.is_finite() or not feet.is_finite():
        return Rect2()
    # Screen-space body capsule envelope: narrow enough to exclude robot
    # and airfield, broad enough for head, torso and mobile finger padding.
    var projected_height: float=absf(feet.y-head.y)
    # The imported operator's shoulders are far narrower than her height;
    # 21% of the *entire canvas height* was admitting right-side scenery.
    # Size the finger-safe torso region from the PROJECTED operator height.
    var half_width: float=clampf(
        projected_height*.19,25.0,canvas.x*.085)
    var margin: float=clampf(projected_height*.035,6.0,12.0)
    var top: float=minf(head.y,feet.y)-margin
    var bottom: float=maxf(head.y,feet.y)+margin
    var rect:=Rect2(
        Vector2(center.x-half_width,top),
        Vector2(half_width*2.0,bottom-top))
    return rect.intersection(Rect2(Vector2.ZERO,canvas))


func _preview_hit_character(point: Vector2) -> bool:
    if stage!="lobby" or _preview_container==null or (
            _selected_tab not in ["JUGAR","PERSONAJE"]):
        return false
    var silhouette: Rect2=_portrait_character_hit_rect()
    return silhouette.has_area() and silhouette.has_point(point)


func _toggle_character_emotes() -> void:
    if _emote_wheel==null or not is_instance_valid(_emote_wheel):
        return
    if _preview_male_active:
        return
    _emote_wheel.visible=not _emote_wheel.visible
    _preview_resume_spin=4.0


func _close_character_emotes() -> void:
    if _emote_wheel!=null and is_instance_valid(_emote_wheel):
        _emote_wheel.hide()


func _play_selected_character_emote() -> void:
    _close_character_emotes()
    _play_lobby_gesture()


func _clear_page() -> void:
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
    style.bg_color=Color(.99,.72,.13)
    style.border_color=Color(1,.90,.47)
    style.set_border_width_all(2)
    style.set_corner_radius_all(7)
    style.shadow_color=Color(.82,.42,.10,.32)
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
    button.add_theme_font_size_override("font_size",18)
    var focus:=StyleBoxFlat.new()
    focus.bg_color=Color.TRANSPARENT
    focus.border_color=Color(.78,.91,1)
    focus.set_border_width_all(2)
    focus.set_corner_radius_all(7)
    focus.set_expand_margin_all(2)
    button.add_theme_stylebox_override("focus",focus)
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


## Twelve original outline icons share one tiny imported SVG texture.
## Atlas regions prevent repeated texture uploads in the Android lobby.
func _reference_lobby_icon(index: int) -> Texture2D:
    var tile:=AtlasTexture.new()
    tile.atlas=LOBBY_ICON_ATLAS
    tile.region=Rect2(0.0,float(clampi(index,0,11))*32.0,32.0,32.0)
    return tile


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
        Color(.027,.045,.074,.94),Color(.45,.58,.69,.60),10)
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
        Color(.009,.019,.032,.76),Color(.35,.52,.68,.40),7)
    _entry_hero_plate.name="AuroraEntryHeroPanel"
    _entry_hero_plate.anchor_left=.047
    _entry_hero_plate.anchor_right=.450
    _entry_hero_plate.anchor_top=.706
    _entry_hero_plate.anchor_bottom=.912
    _entry_hero_plate.visible=false
    _surface.add_child(_entry_hero_plate)
    _entry_hero_kicker=Label.new()
    _entry_hero_kicker.name="AuroraEntryHeroKicker"
    _entry_hero_kicker.text="BASE AURORA"
    _entry_hero_kicker.anchor_left=.067
    _entry_hero_kicker.anchor_right=.431
    _entry_hero_kicker.anchor_top=.732
    _entry_hero_kicker.anchor_bottom=.781
    _entry_hero_kicker.add_theme_font_size_override("font_size",18)
    _entry_hero_kicker.add_theme_color_override(
        "font_color",Color(.47,.85,.95))
    _entry_hero_kicker.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _entry_hero_kicker.visible=false
    _surface.add_child(_entry_hero_kicker)
    _entry_mission_caption=Label.new()
    _entry_mission_caption.name="AuroraEntryMissionCaption"
    _entry_mission_caption.text="ÚLTIMA ZONA"
    _entry_mission_caption.anchor_left=.067
    _entry_mission_caption.anchor_right=.431
    _entry_mission_caption.anchor_top=.778
    _entry_mission_caption.anchor_bottom=.895
    _entry_mission_caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _entry_mission_caption.add_theme_font_override("font",DISPLAY_FONT)
    _entry_mission_caption.add_theme_font_size_override("font_size",54)
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
    _loading_overlay.color=Color(.006,.015,.033,.16)
    # Actual modal input blocker; a one-shot set_input_as_handled() does not
    # stop future taps on underlying navigation or the 3D avatar.
    _loading_overlay.mouse_filter=Control.MOUSE_FILTER_STOP
    _loading_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _surface.add_child(_loading_overlay)
    _loading_surface_plate=_make_glass_panel(
        Color(.012,.023,.045,.75),Color(.39,.58,.72,.47),9)
    _loading_surface_plate.name="AuroraLoadingConsolePlate"
    _loading_surface_plate.anchor_left=.18
    _loading_surface_plate.anchor_right=.82
    _loading_surface_plate.anchor_bottom=.958
    _loading_overlay.add_child(_loading_surface_plate)
    _loading_accent_stripe=ColorRect.new()
    _loading_accent_stripe.name="AuroraLoadingGoldStripe"
    _loading_accent_stripe.color=Color(.95,.66,.22,.90)
    _loading_accent_stripe.anchor_left=.22
    _loading_accent_stripe.anchor_right=.78
    _loading_accent_stripe.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _loading_overlay.add_child(_loading_accent_stripe)
    var hero:=CenterContainer.new()
    hero.name="AuroraLoadingBrandHero"
    hero.anchor_right=1
    hero.anchor_top=.115
    # Keep brand and real resource progress in different layers.
    hero.anchor_bottom=.607
    _loading_overlay.add_child(hero)
    var branding:=VBoxContainer.new()
    hero.add_child(branding)
    _loading_chapter=Label.new()
    _loading_chapter.name="AuroraLoadingChapter"
    _loading_chapter.text="BASE AURORA"
    _loading_chapter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    _loading_chapter.add_theme_font_size_override("font_size",18)
    _loading_chapter.add_theme_color_override(
        "font_color",Color(.53,.79,.91))
    branding.add_child(_loading_chapter)
    _loading_emblem=TextureRect.new()
    _loading_emblem.name="AuroraLoadingIdentityEmblem"
    _loading_emblem.texture=_brand_logo.texture
    _loading_emblem.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    _loading_emblem.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _loading_emblem.custom_minimum_size=Vector2(0,100)
    branding.add_child(_loading_emblem)
    _add_entry_wordmark(branding,61,31)

    var content:=VBoxContainer.new()
    _loading_actions=content
    content.name="AuroraLoadingActions"
    content.anchor_left=.23
    content.anchor_right=.77
    content.anchor_bottom=.944
    content.alignment=BoxContainer.ALIGNMENT_CENTER
    content.add_theme_constant_override("separation",5)
    _loading_overlay.add_child(content)
    _loading_title=Label.new()
    _loading_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    _loading_title.add_theme_font_override("font",DISPLAY_FONT)
    _loading_title.add_theme_font_size_override("font_size",24)
    _loading_title.add_theme_color_override(
        "font_color",Color(.98,.95,.86))
    content.add_child(_loading_title)
    _loading_detail=Label.new()
    _loading_detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    _loading_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _loading_detail.add_theme_font_size_override("font_size",16)
    _loading_detail.add_theme_color_override(
        "font_color",Color(.75,.86,.93))
    content.add_child(_loading_detail)
    _loading_meter=ProgressBar.new()
    _loading_meter.name="WorldLoadProgress"
    _loading_meter.custom_minimum_size=Vector2(275,16)
    _loading_meter.add_theme_font_size_override("font_size",14)
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
    # Separate advice layer: the loading actions keep their existing 44px+
    # phone touch targets even when CANCEL and RETRY are displayed.
    _loading_tip_label=Label.new()
    _loading_tip_label.name="AuroraLoadingAdvice"
    _loading_tip_label.anchor_left=.115
    _loading_tip_label.anchor_right=.885
    _loading_tip_label.anchor_top=.632
    _loading_tip_label.anchor_bottom=.706
    _loading_tip_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    _loading_tip_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    _loading_tip_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _loading_tip_label.add_theme_font_size_override("font_size",14)
    _loading_tip_label.add_theme_color_override(
        "font_color",Color(.86,.93,.97))
    _loading_tip_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _loading_overlay.add_child(_loading_tip_label)
    _loading_retry=_button("REINTENTAR",_start_bootstrap,190)
    _loading_retry.custom_minimum_size.y=68
    _loading_retry.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
    content.add_child(_loading_retry)
    _loading_cancel=_button("VOLVER AL LOBBY",_return_to_lobby,190)
    _loading_cancel.custom_minimum_size.y=68
    _loading_cancel.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
    content.add_child(_loading_cancel)
    _loading_retry.visibility_changed.connect(_layout_loading_actions)
    _loading_cancel.visibility_changed.connect(_layout_loading_actions)
    _layout_loading_actions()


func _layout_loading_actions() -> void:
    var top: float=.656 if _loading_retry.visible or _loading_cancel.visible else .722
    _loading_surface_plate.anchor_top=top
    _loading_accent_stripe.anchor_top=top
    _loading_accent_stripe.anchor_bottom=top+.004
    _loading_actions.anchor_top=top+.014
    # The advice line does not steal room from the loading meter/cancel
    # buttons on 964x434. Compress only the title artwork above it.
    var hero: Control=_loading_overlay.get_node_or_null(
        "AuroraLoadingBrandHero") as Control
    if hero!=null:
        hero.anchor_bottom=.550 if _loading_retry.visible or (
            _loading_cancel.visible) else .607
    if _loading_tip_label!=null:
        _loading_tip_label.anchor_top=.562 if _loading_retry.visible or (
            _loading_cancel.visible) else .632
        _loading_tip_label.anchor_bottom=.643 if _loading_retry.visible or (
            _loading_cancel.visible) else .706


static func loading_tip_for(context: String,index: int) -> String:
    var tips: Array=LOADING_TIPS.get(context,LOADING_TIPS["startup"])
    if tips.is_empty():
        return ""
    return str(tips[posmod(index,tips.size())])


func _set_loading_tip_context(context: String) -> void:
    _loading_tip_context=context if LOADING_TIPS.has(context) else "startup"
    _loading_tip_index=0
    _loading_tip_clock=0.0
    if _loading_tip_label!=null:
        _loading_tip_label.text=loading_tip_for(_loading_tip_context,0)


func _tick_loading_tip(delta: float) -> void:
    if not is_finite(delta) or delta<=0.0 or _loading_tip_label==null:
        return
    _loading_tip_clock+=minf(delta,1.0)
    if _loading_tip_clock>=LOADING_TIP_INTERVAL:
        _loading_tip_clock=fmod(_loading_tip_clock,LOADING_TIP_INTERVAL)
        _loading_tip_index+=1
        _loading_tip_label.text=loading_tip_for(
            _loading_tip_context,_loading_tip_index)


func _add_entry_wordmark(container: VBoxContainer,title_size:=54,subtitle_size:=32) -> void:
    for entry in [["EntryBrandTitle","THEDEMIAN:",title_size,Color(.97,.98,1.0)],
            ["EntryBrandSubtitle","LAST ZONE",subtitle_size,Color(1.0,.79,.41)]]:
        var label:=Label.new()
        label.name=entry[0]
        label.text=entry[1]
        label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_override("font",DISPLAY_FONT)
        label.add_theme_font_size_override("font_size",entry[2])
        label.add_theme_color_override("font_color",entry[3])
        label.add_theme_color_override("font_shadow_color",Color(.02,.04,.08,.96))
        label.add_theme_color_override("font_outline_color",Color(.02,.04,.08,.80))
        label.add_theme_constant_override("outline_size",2)
        label.add_theme_constant_override("shadow_offset_y",3)
        container.add_child(label)


func _show_loading(title: String,detail: String,pending: bool=false) -> void:
    _arctic_art.show()
    _surface.move_child(_loading_overlay,-1)
    _loading_title.text=title
    _loading_detail.text=detail
    _loading_retry.hide()
    _loading_cancel.hide()
    _loading_meter.show()
    _loading_meter.indeterminate=pending
    _loading_meter.show_percentage=not pending
    _loading_meter.value=0
    _set_loading_tip_context("startup" if stage=="startup" else "battle")
    if _loading_fade and _loading_fade.is_valid():
        _loading_fade.kill()
    _loading_overlay.show()
    _loading_overlay.modulate.a=.92
    _loading_fade=create_tween()
    _loading_fade.tween_property(_loading_overlay,"modulate:a",1.0,.16)
    # A restrained real-time UI pulse, not simulated load progress.
    # The progress bar still follows ResourceLoader's actual thread state.
    _stop_loading_heartbeat()
    _loading_heartbeat=create_tween().set_loops()
    _loading_heartbeat.tween_property(
        _loading_accent_stripe,"modulate:a",.46,1.3).set_trans(
        Tween.TRANS_SINE)
    _loading_heartbeat.parallel().tween_property(
        _loading_chapter,"modulate:a",.58,1.3)
    _loading_heartbeat.tween_property(
        _loading_accent_stripe,"modulate:a",1.0,1.3).set_trans(
        Tween.TRANS_SINE)
    _loading_heartbeat.parallel().tween_property(
        _loading_chapter,"modulate:a",1.0,1.3)


func _stop_loading_heartbeat() -> void:
    if _loading_heartbeat!=null and _loading_heartbeat.is_valid():
        _loading_heartbeat.kill()
    _loading_heartbeat=null
    if _loading_accent_stripe!=null:
        _loading_accent_stripe.modulate.a=1.0
    if _loading_chapter!=null:
        _loading_chapter.modulate.a=1.0


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
            if not progress.is_empty() and is_finite(float(progress[0])):
                # Report ONLY the actual threaded ResourceLoader status.
                # World instantiation has separate indeterminate feedback.
                var ratio: float=clampf(float(progress[0]),0.0,1.0)
                _loading_meter.value=maxf(_loading_meter.value,ratio*100.0)
                _loading_detail.text="RECURSOS LOCALES: %d%%"%roundi(
                    _loading_meter.value)
        ResourceLoader.THREAD_LOAD_LOADED:
            _game_scene=ResourceLoader.load_threaded_get(game_scene_path) as PackedScene
            if _game_scene==null or not _game_scene.can_instantiate():
                _startup_failed()
                return
            _loading_meter.value=100
            # Auto-resume only a VALID retained native session after the
            # resource loader reaches 100%; never create a new guest
            # account or simulate Google authentication at startup.
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
    _auto_resume_on_entry=(stage=="startup")
    stage="welcome"
    if _profile_overlay!=null:
        _profile_overlay.hide()
    if _emote_wheel!=null:
        _emote_wheel.hide()
    _arctic_art.show()
    _stop_loading_heartbeat()
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
    if is_instance_valid(_mode_gallery_entry):
        _mode_gallery_entry.visible=false
    if is_instance_valid(_mode_gallery_overlay):
        _mode_gallery_overlay.visible=false
    if is_instance_valid(_shop_gallery_overlay):
        _shop_gallery_overlay.visible=false
    if is_instance_valid(_page):
        _page.visible=true
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
    if _lobby_compact_intel!=null and is_instance_valid(_lobby_compact_intel):
        _lobby_compact_intel.visible=false
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
    _page.anchor_top=.141
    _page.anchor_bottom=.903
    _page.add_theme_constant_override("separation",6)
    _brand_logo.visible=true
    # Intro emblem belongs beside Aurora's cinematic title, not as a
    # tiny detached badge floating in the far-right sign-in buttons.
    _brand_logo.anchor_left=.061
    _brand_logo.anchor_right=.157
    _brand_logo.anchor_top=.105
    _brand_logo.anchor_bottom=.296
    _clear_page()
    _add_entry_wordmark(_page)
    var entry_overline:=_label("ACCESO",16)
    entry_overline.name="AuroraEntryAccessOverline"
    entry_overline.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    entry_overline.add_theme_color_override("font_color",Color(.49,.78,.90))
    # Compact 434px login must reserve its height for the three real
    # providers. Decorative overline and diagnostics are optional.
    var compact_entry: bool=minf(_surface.size.y,
        float(get_window().size.y))<560.0
    entry_overline.visible=not compact_entry
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
    _login_status_label=_label("COMPROBANDO ACCESO…",16)
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
    _login_google_button.custom_minimum_size.y=72 if compact_entry else 54
    _login_google_button.add_theme_font_size_override("font_size",22)
    _login_google_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _style_primary_action(_login_google_button)
    _login_guest_button=_button("ENTRAR COMO INVITADO",
        Callable(self,"_begin_welcome_auth").bind("guest"),0)
    _login_guest_button.name="WelcomeGuestSignIn"
    _login_guest_button.custom_minimum_size.y=72 if compact_entry else 54
    _login_guest_button.add_theme_font_size_override("font_size",22)
    _login_guest_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    providers.add_child(_login_google_button)
    providers.add_child(_login_guest_button)
    _login_local_button=_button("JUGAR SIN CONEXIÓN",_enter_local_lobby,0)
    _login_local_button.name="EnterButton"
    _login_local_button.custom_minimum_size.y=72 if compact_entry else 54
    _login_local_button.add_theme_font_size_override("font_size",22)
    _login_local_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    providers.add_child(_login_local_button)
    var disclosure:=_label(
        "SIN CONEXIÓN: progreso guardado en este dispositivo.",16)
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
    diag.visible=not compact_entry
    # Balance the large vertical region above sign-in on landscape phones.
    # Without this flex item, every spare pixel was above the providers.
    var bottom_space:=Control.new()
    bottom_space.name="AuroraEntryBottomBreathingRoom"
    bottom_space.mouse_filter=Control.MOUSE_FILTER_IGNORE
    bottom_space.size_flags_vertical=Control.SIZE_EXPAND_FILL
    _page.add_child(bottom_space)
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
    _auto_resume_on_entry=false
    _poll_login_state()


## This policy can be regression-tested off-device. The caller supplies
## session_state() from the real native Firebase bridge, which fails closed
## when App Check, Android plugin, provider or server identity are invalid.
static func _can_resume_native_session(session: Dictionary,from_startup: bool,
        initiated_login: bool) -> bool:
    return bool(session.get("authenticated",false)) and not bool(
        session.get("pending",false)) and (
        from_startup or initiated_login)


## Isolated so QA checks pending->confirmed transitions using a fake
## Dictionary without spoofing the real Firebase SDK. Runtime always calls
## this with the actual getSessionState() from the Android plugin.
func _resume_native_session_if_ready(session: Dictionary) -> bool:
    if not _can_resume_native_session(session,_auto_resume_on_entry,
            not _login_waiting_provider.is_empty()):
        return false
    _auto_resume_on_entry=false
    _login_waiting_provider=""
    call_deferred("_show_lobby")
    return true


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
        if bool(session.get("identity_confirmed",false)):
            _login_status_label.text="SESIÓN CONFIRMADA · ID "+str(session.get("official_id",""))
        else:
            _login_status_label.text="CUENTA AUTENTICADA · ID PENDIENTE DEL SERVIDOR"
        if enter!=null:
            enter.text="CONTINUAR AL LOBBY"
        # Preserve the explicit sign-in intent WHILE Firebase/App Check is
        # resolving. V75.171 accidentally cleared _login_waiting_provider
        # before checking it, so fresh Google/Guest login could never enter.
        _resume_native_session_if_ready(session)
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
    _arctic_art.hide()
    _stop_loading_heartbeat()
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
    _page.anchor_left=.735
    _page.anchor_right=.961
    _page.anchor_top=.386
    # The original .763 reserved 160+ empty pixels below INICIAR.
    # Fit the ONE mode selector and its actual play button instead.
    _page.anchor_bottom=.562
    _page.add_theme_constant_override("separation",2)
    # The same live SubViewport is now the whole winter hangar
    # behind the menus. Side bars are native UI placed ABOVE it; never
    # use a still image to fake a usable lobby.
    _preview_container.anchor_left=0.0
    _preview_container.anchor_right=1.0
    _preview_container.anchor_top=0.0
    _preview_container.anchor_bottom=1.0
    _preview_container.visible=true
    # Swiping the character already rotates her. The old left/right/
    # VISTA/GESTO/nameplate strip obscured the character's boots.
    # Tap Lila to open the REAL emote menu instead.
    _preview_caption.visible=false
    if _gesture_button!=null and is_instance_valid(_gesture_button):
        _gesture_button.visible=false
    for action in _operator_controls:
        if is_instance_valid(action):
            action.visible=(action.name=="AuroraMalePreviewSelector" and
                _selected_tab=="PERSONAJE")
    if _emote_wheel!=null:
        _emote_wheel.hide()
    _ensure_lobby_navigation()
    for plate in _lobby_backplates:
        if is_instance_valid(plate):
            plate.visible=true
    _lobby_nav.visible=false
    _left_shortcuts.visible=true
    _bottom_navigation.visible=true
    if is_instance_valid(_mode_gallery_overlay):
        _mode_gallery_overlay.visible=false
    if is_instance_valid(_shop_gallery_overlay):
        _shop_gallery_overlay.visible=false
    if is_instance_valid(_page):
        _page.visible=true
    _top_account_button.visible=true
    _top_settings_button.visible=true
    # Footer SOCIAL is the one navigation entry; hide the duplicate header action.
    _top_social_button.visible=false
    _banner.visible=true
    # Mode/participant status already occupies the right BR card.
    # Eliminate the tiny duplicate strip next to Lila's platform.
    _lobby_status_ribbon.visible=false
    # Three independently clipped headers keep the original brand legible
    # without the coin balance covering Lila, the player record or the emblem.
    _profile_strip.visible=true
    _profile_strip.text="THEDEMIAN: LAST ZONE"
    _stats_strip.visible=false
    _currency_strip.visible=true
    _currency_strip.text="MONEDAS %d\nDIAMANTES —"%int(
        stats.get("local_coins",0))
    _currency_strip.tooltip_text=(
        "No existe un saldo premium confirmado; no se inventan diamantes.")
    _update_identity_strip(stats)
    if _profile_overlay!=null:
        _profile_overlay.hide()
    _preview_touch=-1
    _preview_mouse_drag=false
    _preview_resume_spin=2.0
    if _preview_avatar:
        _preview_avatar.rotation.y=0.0
        if not _preview_male_active:
            _apply_preview_skin(str(
                _offline_records.cosmetic_state()["equipped"]))
    _clear_page()
    _lobby_section_title=_label("",23)
    _lobby_section_title.add_theme_font_override("font",DISPLAY_FONT)
    _lobby_section_title.name="LobbySectionTitle"
    _lobby_section_title.add_theme_color_override("font_color",Color(.96,.96,.88))
    _lobby_section_hint=_label("",13)
    _lobby_section_hint.name="LobbySectionHint"
    _lobby_section_hint.add_theme_color_override("font_color",Color(.57,.84,.94))
    _lobby_mode_heading=_label("MODALIDAD DE PARTIDA",13)
    _lobby_mode_heading.add_theme_color_override("font_color",Color(.96,.77,.38))
    _match_mode_selector=OptionButton.new()
    _match_mode_selector.name="MatchModeSelector"
    _match_mode_selector.accessibility_name="Modalidad de partida · selector único"
    _match_mode_selector.tooltip_text="Seleccionar modo de juego (solo aquí)"
    _match_mode_selector.custom_minimum_size.y=49
    _match_mode_selector.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _match_mode_selector.fit_to_longest_item=false
    _match_mode_selector.clip_text=true
    _match_mode_selector.add_theme_font_size_override("font_size",18)
    _match_mode_selector.add_item("CLÁSICO",0)
    _match_mode_selector.add_item("CLASIFICATORIA",1)
    _match_mode_selector.add_item("ENTRENAMIENTO",2)
    _match_mode_selector.select(["classic","ranked","training"].find(_selected_match_mode))
    _match_mode_selector.item_selected.connect(_on_match_mode_selected)
    _page.add_child(_match_mode_selector)
    _lobby_play_modes=VBoxContainer.new()
    _lobby_play_modes.name="PlayModes"
    _page.add_child(_lobby_play_modes)
    _battle_entry=_button("INICIAR",Callable(self,"_launch").bind(true),0)
    _battle_entry.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _battle_entry.name="BattleButton"
    _battle_entry.custom_minimum_size.y=65
    _battle_entry.add_theme_font_override("font",DISPLAY_FONT)
    _battle_entry.add_theme_font_size_override("font_size",27)
    _style_primary_action(_battle_entry)
    _lobby_play_modes.add_child(_battle_entry)
    _training_entry=_button("INICIAR",Callable(self,"_launch").bind(false),0)
    _training_entry.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _training_entry.name="TrainingButton"
    _training_entry.custom_minimum_size.y=65
    _style_primary_action(_training_entry)
    _lobby_play_modes.add_child(_training_entry)
    _lobby_mode_caption=_label("",12)
    _lobby_mode_caption.add_theme_color_override("font_color",Color(.88,.86,.68))
    # Three real match facts occupy the previously empty desktop card, while
    # staying hidden on the Edge 60 Fusion's compact landscape viewport.
    _lobby_match_facts=HBoxContainer.new()
    _lobby_match_facts.name="AuroraMatchOperationalFacts"
    _lobby_match_facts.add_theme_constant_override("separation",4)
    _page.add_child(_lobby_match_facts)
    # V75.171: no duplicate 50-player/zone/AI tiles below INICIAR.
    # Keep the lightweight empty container for legacy script references;
    # the backend's 50-player rules remain unchanged.
    _lobby_match_facts.visible=false
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
    _login_signout_button=_button("CERRAR SESIÓN",
        Callable(self,"_sign_out_native_session"),255)
    _login_signout_button.name="RealFirebaseSignOut"
    _login_signout_button.custom_minimum_size.y=35
    _login_signout_button.add_theme_font_size_override("font_size",13)
    _page.add_child(_login_signout_button)
    _login_signout_button.visible=false
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
    _objective_selector=TabBar.new()
    _objective_selector.name="ObjectivesCategorySelector"
    _objective_selector.custom_minimum_size=Vector2(0,35)
    _objective_selector.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _objective_selector.clip_tabs=false
    _objective_selector.add_tab("MISIONES")
    _objective_selector.add_tab("LOGROS")
    _objective_selector.current_tab=1 if _objective_page=="achievements" else 0
    _objective_selector.tab_changed.connect(_on_objective_category_selected)
    _page.add_child(_objective_selector)
    # These bars are read-only projections of the signed local match ledger.
    # No new reward, entitlement, rank, claim or remote account is created.
    _objectives_progress_panel=VBoxContainer.new()
    _objectives_progress_panel.name="AuroraLocalObjectiveProgress"
    _objectives_progress_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    # Readable progress rows at 964x434: thin default ProgressBars previously
    # looked like a set of separators, not meaningful match goals.
    _objectives_progress_panel.add_theme_constant_override("separation",8)
    _page.add_child(_objectives_progress_panel)
    for index in range(3):
        var line:=VBoxContainer.new()
        line.name="LocalObjectiveRow%d"%index
        line.add_theme_constant_override("separation",3)
        line.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        _objectives_progress_panel.add_child(line)
        var caption:=Label.new()
        caption.name="LocalObjectiveCaption%d"%index
        caption.add_theme_font_size_override("font_size",15)
        caption.add_theme_color_override("font_color",Color(.85,.95,1.0))
        caption.clip_text=true
        line.add_child(caption)
        var gauge:=ProgressBar.new()
        gauge.name="LocalObjectiveGauge%d"%index
        gauge.custom_minimum_size=Vector2(0,22)
        gauge.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        gauge.show_percentage=false
        var track:=StyleBoxFlat.new()
        track.bg_color=Color(.07,.13,.19,1)
        track.border_color=Color(.32,.51,.64,.93)
        track.set_border_width_all(1)
        track.set_corner_radius_all(4)
        gauge.add_theme_stylebox_override("background",track)
        var fill:=StyleBoxFlat.new()
        fill.bg_color=Color(.27,.81,.85,1)
        fill.set_corner_radius_all(4)
        gauge.add_theme_stylebox_override("fill",fill)
        line.add_child(gauge)
        _objectives_progress_rows.append({"label":caption,"bar":gauge})
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
    # Pick the actual imported 3D actor, without claiming CH02 is a
    # combat-ready operator. Missing licensed sources stay unavailable.
    _operator_selector=OptionButton.new()
    _operator_selector.name="AuroraOperatorPreviewSelector"
    _operator_selector.custom_minimum_size=Vector2(245,36)
    _operator_selector.fit_to_longest_item=false
    _operator_selector.clip_text=true
    _operator_selector.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _operator_selector.add_theme_font_size_override("font_size",13)
    _operator_selector.add_item("LILA AURORA · JUGABLE",0)
    _operator_selector.add_item("CH02 · SOLO VISTA 3D",1)
    _operator_selector.set_item_disabled(1,not MALE_PREVIEW.source_available())
    _operator_selector.select(1 if _preview_male_active else 0)
    _operator_selector.item_selected.connect(_on_operator_selected)
    _page.add_child(_operator_selector)
    _shop_selector=OptionButton.new()
    _shop_selector.name="AuroraLocalSkinSelector"
    _shop_selector.custom_minimum_size=Vector2(245,31)
    _shop_selector.add_item("LILA · AURORA ORIGINAL",0)
    _shop_selector.add_item("LILA · AURORA GLACIAL",1)
    _shop_selector.add_item("LILA · AURORA FUEGO",2)
    _shop_selector.select(1)
    _shop_selector.item_selected.connect(_on_shop_skin_selected)
    _page.add_child(_shop_selector)
    _shop_gallery_entry=_button("EXPLORAR TRAJES AURORA",
        Callable(self,"_open_skin_gallery"),245)
    _shop_gallery_entry.name="AuroraSkinCatalogEntry"
    _shop_gallery_entry.custom_minimum_size.y=34
    _shop_gallery_entry.add_theme_font_size_override("font_size",13)
    _style_aurora_tab(_shop_gallery_entry,Color(.89,.68,.32))
    _page.add_child(_shop_gallery_entry)
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
    # A source-of-truth weapon-family selector, based on the actual existing
    # combat catalog rather than invented weapons or skins. Category numbers
    # are navigation only; saved weapon slot IDs remain exactly unchanged.
    _armory_category_selector=OptionButton.new()
    _armory_category_selector.name="AuroraWeaponFamilySelector"
    _armory_category_selector.custom_minimum_size=Vector2(245,35)
    _armory_category_selector.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _armory_category_selector.fit_to_longest_item=false
    _armory_category_selector.clip_text=true
    _armory_category_selector.add_theme_font_size_override("font_size",13)
    for family in range(WEAPON_FAMILIES.LABELS.size()):
        var count: int=WEAPON_FAMILIES.slots_for_family(family).size()
        _armory_category_selector.add_item(
            "%s  (%d)"%[WEAPON_FAMILIES.LABELS[family],count],family)
    _armory_category_selector.select(_armory_category)
    _armory_category_selector.item_selected.connect(_on_armory_category_selected)
    _page.add_child(_armory_category_selector)
    _armory_list=ItemList.new()
    _armory_list.name="AuroraWeaponCatalogList"
    _armory_list.custom_minimum_size=Vector2(245,156)
    _armory_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _armory_list.select_mode=ItemList.SELECT_SINGLE
    _armory_list.item_selected.connect(_on_armory_slot_selected)
    _page.add_child(_armory_list)
    _refresh_armory_catalog()
    _armory_test_button=_button("PROBAR EN ENTRENAMIENTO",_open_weapon_training,245)
    _armory_test_button.name="AuroraWeaponTrainingEntry"
    _armory_test_button.custom_minimum_size.y=32
    _armory_test_button.add_theme_font_size_override("font_size",13)
    _page.add_child(_armory_test_button)
    # Armor and supplies are acquired during a match, never silently owned
    # merely because the player opened the local lobby.
    # The lobby only INSPECTS actual gear. Match pickups and inventory live
    # in the game scene; changing this selector cannot grant any supplies.
    _equipment_category_selector=OptionButton.new()
    _equipment_category_selector.name="AuroraEquipmentFamilySelector"
    _equipment_category_selector.custom_minimum_size=Vector2(245,35)
    _equipment_category_selector.fit_to_longest_item=false
    _equipment_category_selector.clip_text=true
    _equipment_category_selector.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    for category in range(EQUIPMENT_FAMILIES.LABELS.size()):
        _equipment_category_selector.add_item(
            "%s  (%d)"%[EQUIPMENT_FAMILIES.LABELS[category],
                EQUIPMENT_FAMILIES.slots_for_category(category).size()],
            category)
    _equipment_category_selector.select(_equipment_category)
    _equipment_category_selector.item_selected.connect(
        _on_equipment_category_selected)
    _page.add_child(_equipment_category_selector)
    _equipment_selector=OptionButton.new()
    _equipment_selector.name="AuroraEquipmentCatalog"
    _equipment_selector.custom_minimum_size=Vector2(245,35)
    _equipment_selector.fit_to_longest_item=false
    _equipment_selector.clip_text=true
    _equipment_selector.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _equipment_selector.item_selected.connect(_on_equipment_selected)
    _page.add_child(_equipment_selector)
    _refresh_equipment_catalog()
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
    # Only AuroraRealSettings owns HUD, sensitivity, FPS, and audio.
    _select_tab(_selected_tab)


func _update_identity_strip(stats: Dictionary) -> void:
    if _player_name==null:
        return
    var session: Dictionary=FIREBASE_BRIDGE.session_state()
    var confirmed: bool=bool(session.get("identity_confirmed",false))
    var player_name: String=(str(session.get("display_name",""))
        if confirmed else _player_name.display_name)
    if player_name.is_empty():
        player_name=_player_name.display_name
    # V75.171: the original "OPERADOR LOCAL 0 P 0 V" floating text is
    # replaced by ONE actionable profile at the far left of the header.
    if _top_account_button!=null and is_instance_valid(_top_account_button):
        _top_account_button.text=player_name
        _top_account_button.tooltip_text="ABRIR PERFIL · "+(
            "ID "+str(session.get("official_id","")) if confirmed
            else "partidas locales verificadas")
    if _stats_strip!=null:
        _stats_strip.text=""
        _stats_strip.visible=false


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


func _sign_out_native_session() -> void:
    if stage!="lobby" or _selected_tab!="CUENTA":
        return
    var result: Dictionary=FIREBASE_BRIDGE.request_sign_out()
    if not bool(result.get("signed_out",false)):
        _info.text="NO SE PUDO CERRAR SESIÓN\n"+str(
            result.get("reason","sin confirmación del SDK"))
        _sync_lobby_match_mode()
        return
    # The official Firebase provider is actually logged out. Keep the
    # local match journal intact; changing accounts cannot erase progress.
    _auto_resume_on_entry=false
    _welcome()


func _on_objective_category_selected(index: int) -> void:
    if _objective_selector==null:
        return
    if index not in [0,1]:
        return
    _objective_page="achievements" if index==1 else "missions"
    _update_objective_details()


## The three visual progress bars come ONLY from the immutable snapshot of
## the current local match journal. The objectives are informational, not
## monetary claims, seasonal quests or server leaderboards.
func _update_objective_progress(played: int,kills: int,wins: int) -> void:
    if not is_instance_valid(_objectives_progress_panel):
        return
    var definitions: Array=[]
    if _objective_page=="missions":
        definitions=[
            ["PARTIDAS CLÁSICAS",played,3],
            ["ELIMINACIONES",kills,5],
            ["VICTORIAS",wins,1]]
    elif _objective_page=="achievements":
        definitions=[
            ["PRIMERA PARTIDA",played,1],
            ["PRIMERA VICTORIA",wins,1],
            ["10 ELIMINACIONES",kills,10]]
    _objectives_progress_panel.visible=(
        _selected_tab=="OBJETIVOS" and not definitions.is_empty())
    if definitions.is_empty():
        return
    for index in range(mini(_objectives_progress_rows.size(),definitions.size())):
        var item: Array=definitions[index]
        var current: int=maxi(0,int(item[1]))
        var target: int=maxi(1,int(item[2]))
        var label: Label=_objectives_progress_rows[index]["label"] as Label
        var bar: ProgressBar=_objectives_progress_rows[index]["bar"] as ProgressBar
        var done: bool=current>=target
        label.text="%s  %d / %d%s"%[
            str(item[0]),mini(current,target),target,
            "  ·  LISTO" if done else ""]
        label.add_theme_color_override("font_color",
            Color(1.0,.89,.62) if done else Color(.85,.95,1.0))
        var paint: StyleBoxFlat=bar.get_theme_stylebox("fill") as StyleBoxFlat
        if paint!=null:
            paint.bg_color=(
                Color(1.0,.75,.32,1.0) if done else Color(.27,.81,.85,1.0))
        bar.max_value=target
        bar.value=mini(current,target)


## These milestones are displayed from verified saved matches. They are not
## a server event, seasonal quest or purchasable reward.
func _update_objective_details() -> void:
    if _info==null or _offline_records==null:
        return
    var stats: Dictionary=_offline_records.snapshot()
    var played: int=int(stats.get("played",0))
    var wins: int=int(stats.get("wins",0))
    var kills: int=int(stats.get("kills",0))
    _update_objective_progress(played,kills,wins)
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
    if _mode_gallery_overlay!=null and _mode_gallery_overlay.visible:
        _refresh_mode_gallery_cards()


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
    _login_signout_button.visible=(show_name and bool(
        FIREBASE_BRIDGE.session_state().get("authenticated",false)))
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
    _objective_selector.visible=_selected_tab=="OBJETIVOS" and _objective_page!="events"
    if is_instance_valid(_objectives_progress_panel):
        _objectives_progress_panel.visible=(
            _selected_tab=="OBJETIVOS" and _objective_page!="events")
    _lobby_mode_heading.visible=false
    _lobby_section_title.visible=not show_modes
    _lobby_section_hint.visible=not show_modes
    _match_mode_selector.visible=show_modes
    _lobby_play_modes.visible=show_modes and _selected_match_mode!="ranked"
    _battle_entry.visible=show_modes and _selected_match_mode=="classic"
    _training_entry.visible=show_modes and _selected_match_mode=="training"
    _lobby_mode_caption.visible=false
    _lobby_match_facts.visible=false
    if _lobby_compact_intel!=null:
        _lobby_compact_intel.visible=false
    _pass_progress.visible=_selected_tab=="PASE"
    _pass_claim_button.visible=_selected_tab=="PASE"
    _shop_selector.visible=_selected_tab in ["TIENDA","PERSONAJE"] and not (
        _selected_tab=="PERSONAJE" and _preview_male_active)
    _shop_gallery_entry.visible=_selected_tab=="TIENDA"
    _operator_selector.visible=_selected_tab=="PERSONAJE"
    _shop_buy_button.visible=_selected_tab=="TIENDA"
    _shop_equip_button.visible=_selected_tab=="TIENDA"
    _armory_list.visible=_selected_tab=="ARMAS"
    _armory_category_selector.visible=_selected_tab=="ARMAS"
    _armory_test_button.visible=_selected_tab=="ARMAS"
    _equipment_selector.visible=_selected_tab=="INVENTARIO"
    _equipment_category_selector.visible=_selected_tab=="INVENTARIO"
    _lobby_mode_status.visible=show_modes and _selected_match_mode=="ranked"
    _lobby_detail_scroll.visible=not show_modes and _selected_tab!="AJUSTES"
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
        Color(.009,.020,.036,.89),Color(.31,.59,.69,.62),9)
    _header_glass.name="AuroraOperationalHeader"
    _header_glass.anchor_left=.018
    _header_glass.anchor_right=.982
    _header_glass.anchor_top=.006
    _header_glass.anchor_bottom=.141
    _surface.add_child(_header_glass)
    _surface.move_child(_header_glass,_page.get_index())
    _lobby_backplates.append(_header_glass)
    # Original cyan slash is a physical UI ColorRect, not a flattened mockup.
    var brand_slash:=ColorRect.new()
    brand_slash.name="AuroraBrandSlash"
    brand_slash.color=Color(.12,.94,1.0,.98)
    brand_slash.anchor_left=.014
    brand_slash.anchor_right=.020
    brand_slash.anchor_top=.28
    brand_slash.anchor_bottom=.78
    brand_slash.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _header_glass.add_child(brand_slash)
    _profile_strip=_make_header_label(
        "LocalProfileStrip",.278,.562,20)
    _profile_strip.add_theme_font_override("font",DISPLAY_FONT)
    _stats_strip=_make_header_label(
        "LocalStatisticsStrip",.562,.563,1)
    _stats_strip.visible=false
    _currency_strip=_make_header_label(
        "LocalCurrencyStrip",.575,.865,20)
    # Both the squad and the compact mode card carry their own glass.
    # The older full-height black rail was covering the hangar for no
    # functional reason; remove it entirely instead of hiding it with alpha.
    _lobby_menu_backplate=null
    var navplate:=_make_glass_panel(
        Color(.006,.016,.032,.68),Color(.27,.67,.84,.58),10)
    navplate.name="LobbySidebarBackplate"
    navplate.anchor_left=.017
    navplate.anchor_right=.208
    navplate.anchor_top=.261
    navplate.anchor_bottom=.870
    _surface.add_child(navplate)
    _surface.move_child(navplate,_page.get_index())
    _lobby_backplates.append(navplate)
    # Continuous lower glass rail: the old five floating rectangles visually
    # cut the stage floor and lacked the clean baseline of the reference.
    var footer_plate:=_make_glass_panel(
        Color(.007,.015,.028,.82),Color(.19,.66,.86,.58),4)
    footer_plate.name="AuroraPremiumFooterGlass"
    footer_plate.anchor_left=.011
    footer_plate.anchor_right=.989
    footer_plate.anchor_top=.865
    footer_plate.anchor_bottom=.990
    _surface.add_child(footer_plate)
    _surface.move_child(footer_plate,_page.get_index())
    _lobby_backplates.append(footer_plate)
    _lobby_nav=VBoxContainer.new()
    _lobby_nav.name="LobbyNavigation"
    _lobby_nav.anchor_left=.038
    _lobby_nav.anchor_right=.211
    _lobby_nav.anchor_top=.177
    _lobby_nav.anchor_bottom=.93
    _lobby_nav.add_theme_constant_override("separation",4)
    _surface.add_child(_lobby_nav)
    # The old nine-button navigation was hidden but still allocated nine
    # duplicate buttons, icons and callbacks on every lobby entry. Retain
    # only the zero-cost container for old layout callers; the functional
    # six commerce + five footer buttons are now the sole navigation.
    _lobby_nav.visible=false
    _banner=Label.new()
    _banner.name="AuroraOperationBanner"
    _banner.text="╱  AURORA"
    _banner.anchor_left=.028
    _banner.anchor_right=.211
    _banner.anchor_top=.169
    _banner.anchor_bottom=.252
    _banner.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _banner.add_theme_font_override("font",DISPLAY_FONT)
    _banner.add_theme_font_size_override("font_size",21)
    _banner.add_theme_color_override("font_color",Color(.98,.79,.40))
    _banner.add_theme_color_override("font_shadow_color",Color(.02,.06,.10,.95))
    _surface.add_child(_banner)

    _lobby_status_ribbon=PanelContainer.new()
    _lobby_status_ribbon.name="AuroraLiveOperationRibbon"
    # Group the local mode status with the operator controls.
    _lobby_status_ribbon.anchor_left=.219
    _lobby_status_ribbon.anchor_right=.354
    _lobby_status_ribbon.anchor_top=.817
    _lobby_status_ribbon.anchor_bottom=.866
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
    _lobby_status_caption.text="PARTIDA LOCAL"
    _lobby_status_caption.clip_text=true
    _lobby_status_caption.add_theme_font_size_override("font_size",14)
    _lobby_status_caption.add_theme_color_override(
        "font_color",Color(.76,.91,.98))
    _lobby_status_caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _lobby_status_ribbon.add_child(_lobby_status_caption)
    _lobby_status_ribbon.visible=false
    _surface.add_child(_lobby_status_ribbon)

    _left_shortcuts=VBoxContainer.new()
    _left_shortcuts.name="AuroraCommerceRail"
    _left_shortcuts.anchor_left=.025
    _left_shortcuts.anchor_right=.201
    # Four compact actions; missions and achievements share one page.
    _left_shortcuts.anchor_top=.265
    _left_shortcuts.anchor_bottom=.860
    _left_shortcuts.add_theme_constant_override("separation",3)
    _surface.add_child(_left_shortcuts)
    var quick_items: Array[Array]=[
        ["TIENDA","TIENDA","",5],
        ["PASE ROYALE","PASE","",6],
        # JUGAR is already the primary footer action; no second shortcut.
        ["EVENTOS","OBJETIVOS","events",8],
        ["MISIONES / LOGROS","OBJETIVOS","missions",9]
    ]
    for item in quick_items:
        var label: String=str(item[0])
        var target: String=str(item[1])
        var objective: String=str(item[2])
        var button:=_button(label,Callable(self,"_open_lobby_category").bind(
            target,objective),160)
        button.name="Quick"+(objective.to_upper() if not objective.is_empty()
            else target)
        button.icon=_reference_lobby_icon(int(item[3]))
        button.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT
        button.add_theme_constant_override("h_separation",5)
        button.custom_minimum_size=Vector2(0,40)
        button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        button.add_theme_font_override("font",DISPLAY_FONT)
        button.add_theme_font_size_override("font_size",16 if objective=="missions" else 22)
        _style_aurora_tab(button,Color(.35,.70,.91))
        button.size_flags_vertical=Control.SIZE_EXPAND_FILL
        _left_shortcuts.add_child(button)

    _bottom_navigation=HBoxContainer.new()
    _bottom_navigation.name="AuroraBottomNavigation"
    _bottom_navigation.anchor_left=.023
    _bottom_navigation.anchor_right=.977
    _bottom_navigation.anchor_top=.879
    _bottom_navigation.anchor_bottom=.974
    _bottom_navigation.add_theme_constant_override("separation",7)
    _surface.add_child(_bottom_navigation)
    for item in [
        ["JUGAR","JUGAR",0],["INVENTARIO","INVENTARIO",1],
        ["ARMAS","ARMAS",2],["PERSONAJES","PERSONAJE",3],
        ["SOCIAL","SOCIAL",4]
    ]:
        var target: String=str(item[1])
        var button:=_button(str(item[0]),
            Callable(self,"_select_tab").bind(target),0)
        button.name="Bottom"+target
        button.icon=_reference_lobby_icon(int(item[2]))
        button.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT
        button.add_theme_constant_override("h_separation",7)
        button.custom_minimum_size=Vector2(0,30)
        button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        button.add_theme_font_override("font",DISPLAY_FONT)
        button.add_theme_font_size_override("font_size",22)
        # The selected tab is styled after _select_tab(), never hard-code a
        # permanent golden JUGAR button on other screens like ARMAS.
        _style_aurora_tab(button,Color(.30,.63,.83))
        _bottom_navigation.add_child(button)

    _social_panel=PanelContainer.new()
    _social_panel.name="AuroraRealSocialPanel"
    _social_panel.anchor_left=.720
    _social_panel.anchor_right=.974
    _social_panel.anchor_top=.158
    _social_panel.anchor_bottom=.340
    var social_style:=StyleBoxFlat.new()
    social_style.bg_color=Color(.008,.022,.042,.84)
    social_style.border_color=Color(.29,.74,.83,.68)
    social_style.set_border_width_all(1)
    social_style.set_corner_radius_all(9)
    social_style.shadow_color=Color(.01,.02,.04,.40)
    social_style.shadow_size=4
    social_style.content_margin_left=5
    social_style.content_margin_right=5
    social_style.content_margin_top=3
    social_style.content_margin_bottom=3
    _social_panel.add_theme_stylebox_override("panel",social_style)
    _surface.add_child(_social_panel)
    var social_content:=VBoxContainer.new()
    social_content.name="SocialContent"
    social_content.add_theme_constant_override("separation",2)
    _social_panel.add_child(social_content)
    var social_title:=Label.new()
    social_title.text="ESCUADRA"
    social_title.name="FriendsHeading"
    social_title.add_theme_font_override("font",DISPLAY_FONT)
    social_title.add_theme_font_size_override("font_size",19)
    social_title.add_theme_color_override("font_color",Color(.9,.85,1))
    social_content.add_child(social_title)
    _social_status_label=Label.new()
    _social_status_label.name="ActualFriendsStatus"
    _social_status_label.text="LOCAL · SIN AMIGOS EN LÍNEA"
    _social_status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _social_status_label.add_theme_font_size_override("font_size",13)
    _social_status_label.custom_minimum_size.y=16
    _social_status_label.add_theme_color_override("font_color",Color(.75,.8,.85))
    social_content.add_child(_social_status_label)
    var squad_slots:=HBoxContainer.new()
    squad_slots.name="AuroraFourMemberSquad"
    squad_slots.add_theme_constant_override("separation",3)
    squad_slots.size_flags_vertical=Control.SIZE_EXPAND_FILL
    social_content.add_child(squad_slots)
    # Slot 01 represents the local profile; 02–04 are clearly empty.
    # Do not fabricate online friends or send non-functional invitations.
    for i in range(4):
        var slot:=PanelContainer.new()
        slot.name="SquadSlot"+str(i+1)
        slot.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        slot.custom_minimum_size.y=28
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
        number.add_theme_font_size_override("font_size",15)
        number.add_theme_color_override(
            "font_color",Color(.92,.95,1) if i==0 else
            Color(.54,.64,.74))
        number.mouse_filter=Control.MOUSE_FILTER_IGNORE
        slot.add_child(number)
        squad_slots.add_child(slot)

    _play_match_card=PanelContainer.new()
    _play_match_card.name="BattleRoyaleModeCard"
    _play_match_card.anchor_left=.718
    _play_match_card.anchor_right=.977
    _play_match_card.anchor_top=.351
    _play_match_card.anchor_bottom=.580
    _play_match_card.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var match_card_style:=StyleBoxFlat.new()
    match_card_style.bg_color=Color(.008,.020,.038,.88)
    match_card_style.border_color=Color(1.0,.71,.19)
    match_card_style.set_border_width_all(2)
    match_card_style.set_corner_radius_all(11)
    match_card_style.shadow_color=Color(.75,.43,.11,.22)
    match_card_style.shadow_size=3
    _play_match_card.add_theme_stylebox_override("panel",match_card_style)
    _surface.add_child(_play_match_card)
    _surface.move_child(_play_match_card,_page.get_index())
    # Compact phone: fill the lower blank half of the match card with
    # truthful local battle information, without moving the START button.
    # Desktop uses the three native match fact tiles in the detail column.
    _lobby_compact_intel=PanelContainer.new()
    _lobby_compact_intel.name="AuroraCompactMatchBrief"
    _lobby_compact_intel.anchor_left=.727
    _lobby_compact_intel.anchor_right=.970
    # Keep this 28px strip BELOW the original INICIAR bounds at
    # ~304-341 px on 964x434. The previous .744 anchor would overlap
    # the button and interfere with touch.
    _lobby_compact_intel.anchor_top=.783
    _lobby_compact_intel.anchor_bottom=.863
    _lobby_compact_intel.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var intel_style:=StyleBoxFlat.new()
    intel_style.bg_color=Color(.026,.052,.076,.94)
    intel_style.border_color=Color(.28,.56,.65,.65)
    intel_style.set_border_width_all(1)
    intel_style.set_corner_radius_all(5)
    intel_style.content_margin_left=6
    intel_style.content_margin_right=5
    intel_style.content_margin_top=3
    intel_style.content_margin_bottom=2
    _lobby_compact_intel.add_theme_stylebox_override("panel",intel_style)
    var intel_text:=Label.new()
    intel_text.name="CompactBattleInformation"
    intel_text.text="PUERTO AURORA  /  SOLO LOCAL\n50 PARTICIPANTES  ·  ZONA: 4 FASES"
    intel_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    intel_text.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    intel_text.add_theme_font_size_override("font_size",14)
    intel_text.add_theme_color_override(
        "font_color",Color(.82,.91,.94))
    intel_text.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _lobby_compact_intel.add_child(intel_text)
    _lobby_compact_intel.visible=false
    _surface.add_child(_lobby_compact_intel)

    _top_account_button=_button("PERFIL",
        Callable(self,"_open_player_profile"),0)
    _top_account_button.name="TopAccount"
    _top_account_button.custom_minimum_size=Vector2.ZERO
    _top_account_button.anchor_left=.099
    _top_account_button.anchor_right=.264
    _top_account_button.anchor_top=.025
    _top_account_button.anchor_bottom=.131
    _top_account_button.add_theme_font_size_override("font_size",20)
    _top_account_button.tooltip_text="Abrir perfil y estadísticas de partidas reales"
    _top_account_button.accessibility_name="Abrir perfil de jugador"
    _style_aurora_tab(_top_account_button,Color(.53,.39,.87))
    _surface.add_child(_top_account_button)
    _top_settings_button=_button("",
        Callable(self,"_open_settings"),0)
    _top_settings_button.icon=_reference_lobby_icon(11)
    _top_settings_button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
    _top_settings_button.name="TopSettings"
    _top_settings_button.custom_minimum_size=Vector2.ZERO
    _top_settings_button.anchor_left=.920
    _top_settings_button.anchor_right=.975
    _top_settings_button.anchor_top=.025
    _top_settings_button.anchor_bottom=.131
    _top_settings_button.add_theme_font_size_override("font_size",24)
    _top_settings_button.tooltip_text="AJUSTES · controles, HUD y sensibilidad"
    _top_settings_button.accessibility_name="Ajustes de partida y editor HUD"
    _style_aurora_tab(_top_settings_button,Color(.53,.39,.87))
    _surface.add_child(_top_settings_button)
    _top_social_button=_button("",
        Callable(self,"_select_tab").bind("SOCIAL"),0)
    _top_social_button.icon=_reference_lobby_icon(4)
    _top_social_button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
    _top_social_button.name="TopSocial"
    _top_social_button.custom_minimum_size=Vector2.ZERO
    _top_social_button.anchor_left=.747
    _top_social_button.anchor_right=.808
    _top_social_button.anchor_top=.025
    _top_social_button.anchor_bottom=.131
    _top_social_button.add_theme_font_size_override("font_size",24)
    _top_social_button.tooltip_text="Escuadra y amistades"
    _top_social_button.accessibility_name="Escuadra y amistades"
    _style_aurora_tab(_top_social_button,Color(.53,.39,.87))
    _surface.add_child(_top_social_button)
    # There is only ONE mode selector, inside the right Battle Royale card.
    # Do not instantiate obsolete floating MODOS, PRESET or profile widgets.
    _build_player_profile()
    _build_skin_gallery()


## V75.131: the original Aurora mode gallery uses only the existing,
## working gameplay routes. Ranked is a disclosure, not fake matchmaking.
func _build_mode_gallery() -> void:
    _mode_gallery_entry=_button("☷ MODOS",Callable(self,"_open_mode_gallery"),0)
    _mode_gallery_entry.name="AuroraModeGalleryEntry"
    _mode_gallery_entry.accessibility_name="Elegir modalidad de partida"
    _mode_gallery_entry.anchor_left=.219
    _mode_gallery_entry.anchor_right=.357
    _mode_gallery_entry.anchor_top=.290
    _mode_gallery_entry.anchor_bottom=.394
    _mode_gallery_entry.custom_minimum_size=Vector2.ZERO
    _mode_gallery_entry.add_theme_font_size_override("font_size",17)
    _mode_gallery_entry.tooltip_text="Abre las modalidades reales del juego"
    _style_aurora_tab(_mode_gallery_entry,Color(.96,.70,.32))
    _surface.add_child(_mode_gallery_entry)

    _mode_gallery_overlay=Control.new()
    _mode_gallery_overlay.name="AuroraModeGalleryOverlay"
    _mode_gallery_overlay.set_anchors_and_offsets_preset(
        Control.PRESET_FULL_RECT)
    _mode_gallery_overlay.mouse_filter=Control.MOUSE_FILTER_STOP
    _mode_gallery_overlay.visible=false
    _surface.add_child(_mode_gallery_overlay)
    var dim:=ColorRect.new()
    dim.name="ModeGalleryDim"
    dim.color=Color(.009,.022,.043,.91)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter=Control.MOUSE_FILTER_STOP
    _mode_gallery_overlay.add_child(dim)

    var panel:=PanelContainer.new()
    panel.name="ModeGalleryPanel"
    panel.anchor_left=.085
    panel.anchor_right=.915
    panel.anchor_top=.15
    panel.anchor_bottom=.85
    panel.mouse_filter=Control.MOUSE_FILTER_STOP
    var panel_style:=StyleBoxFlat.new()
    panel_style.bg_color=Color(.020,.039,.064,.99)
    panel_style.border_color=Color(.43,.70,.83,.92)
    panel_style.set_border_width_all(2)
    panel_style.set_corner_radius_all(12)
    panel_style.content_margin_left=12
    panel_style.content_margin_right=12
    panel_style.content_margin_top=10
    panel_style.content_margin_bottom=10
    panel.add_theme_stylebox_override("panel",panel_style)
    _mode_gallery_overlay.add_child(panel)

    var content:=VBoxContainer.new()
    content.name="ModeGalleryContent"
    content.add_theme_constant_override("separation",6)
    panel.add_child(content)
    var heading:=Label.new()
    heading.name="ModeGalleryHeading"
    heading.text="ELEGIR MODO  /  BASE AURORA"
    heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size",25)
    heading.add_theme_color_override(
        "font_color",Color(.98,.81,.47))
    content.add_child(heading)
    var notice:=Label.new()
    notice.name="ModeGalleryNotice"
    notice.text="Partidas locales reales. Online requiere servidores y cuentas."
    notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    notice.add_theme_font_size_override("font_size",14)
    notice.add_theme_color_override(
        "font_color",Color(.82,.91,.97))
    content.add_child(notice)
    var cards:=HBoxContainer.new()
    cards.name="ModeGalleryCards"
    cards.size_flags_vertical=Control.SIZE_EXPAND_FILL
    cards.add_theme_constant_override("separation",9)
    content.add_child(cards)
    for data in [
        ["classic","BR CLÁSICO\n50 PARTICIPANTES\n1 JUGADOR + 49 IA"],
        ["training","ENTRENAMIENTO\nPRACTICAR ARMAS\nSOLO LOCAL"],
        ["ranked","CLASIFICATORIA\nBLOQUEADA\nSERVIDOR PENDIENTE"]
    ]:
        var mode: String=str(data[0])
        var card:=_button(str(data[1]),
            Callable(self,"_choose_mode_gallery").bind(mode),0)
        card.name="ModeCard"+mode.capitalize()
        card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        card.size_flags_vertical=Control.SIZE_EXPAND_FILL
        card.custom_minimum_size=Vector2(0,94)
        card.add_theme_font_size_override("font_size",21)
        card.tooltip_text=(
            "Clasificatoria no disponible: requiere servidores reales" if
            mode=="ranked" else
            "Seleccionar modo local "+mode)
        cards.add_child(card)
        _mode_gallery_cards[mode]=card
    var close:=_button("VOLVER AL LOBBY",
        Callable(self,"_close_mode_gallery"),0)
    close.name="CloseModeGallery"
    # 434px physical screen can scale Godot's logical layout by ~0.6.
    # Require ~45 actual touch pixels for the modal exit affordance.
    close.custom_minimum_size=Vector2(0,76)
    close.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    close.add_theme_font_size_override("font_size",15)
    _style_aurora_tab(close,Color(.45,.71,.83))
    content.add_child(close)


func _open_mode_gallery() -> void:
    if stage!="lobby" or _selected_tab!="JUGAR" or (
            not is_instance_valid(_mode_gallery_overlay)):
        return
    _refresh_mode_gallery_cards()
    _mode_gallery_overlay.visible=true


func _close_mode_gallery() -> void:
    if is_instance_valid(_mode_gallery_overlay):
        _mode_gallery_overlay.visible=false


func _choose_mode_gallery(mode: String) -> void:
    if (stage!="lobby" or _selected_tab!="JUGAR" or
            not is_instance_valid(_mode_gallery_overlay) or
            not _mode_gallery_overlay.visible):
        return
    var options: Array[String]=["classic","ranked","training"]
    var index: int=options.find(mode)
    if index<0:
        return
    _match_mode_selector.select(index)
    _on_match_mode_selected(index)
    _close_mode_gallery()


func _refresh_mode_gallery_cards() -> void:
    for mode in _mode_gallery_cards:
        var card: Button=_mode_gallery_cards[mode] as Button
        if card==null:
            continue
        var selected: bool=str(mode)==_selected_match_mode
        card.set_meta("aurora_selected_mode",selected)
        if selected and mode!="ranked":
            _style_primary_action(card)
        else:
            _style_aurora_tab(card,Color(.46,.68,.86) if mode!="ranked"
                else Color(.55,.44,.44))
            card.modulate=(Color(.85,.87,.91) if mode=="ranked"
                else Color.WHITE)
        if selected and mode!="ranked":
            card.modulate=Color.WHITE


## Three real authored Lila palettes, backed by the offline profile
## ledger. No premium purchases or invented ownership.
func _build_skin_gallery() -> void:
    _shop_gallery_cards.clear()
    _shop_gallery_overlay=Control.new()
    _shop_gallery_overlay.name="AuroraSkinGalleryOverlay"
    _shop_gallery_overlay.set_anchors_and_offsets_preset(
        Control.PRESET_FULL_RECT)
    _shop_gallery_overlay.mouse_filter=Control.MOUSE_FILTER_STOP
    _shop_gallery_overlay.visible=false
    _surface.add_child(_shop_gallery_overlay)

    var shade:=ColorRect.new()
    shade.name="SkinGalleryBackdrop"
    # Keep Lila's actual 3D model visible during outfit inspection.
    # A heavy fullscreen scrim made the character disappear on Motorola.
    shade.color=Color(.005,.014,.027,.22)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter=Control.MOUSE_FILTER_STOP
    _shop_gallery_overlay.add_child(shade)

    # Left drawer covers the sidebar, not the center-stage real 3D Lila
    # preview at 964x434. This deliberately avoids the operator portrait
    # (the previous right drawer obscured most of Lila's body).
    var panel:=PanelContainer.new()
    panel.name="AuroraSkinGalleryPanel"
    panel.anchor_left=.018
    panel.anchor_right=.393
    panel.anchor_top=.095
    panel.anchor_bottom=.91
    var panel_style:=StyleBoxFlat.new()
    panel_style.bg_color=Color(.018,.037,.064,.99)
    panel_style.border_color=Color(.41,.72,.82,.91)
    panel_style.set_border_width_all(2)
    panel_style.set_corner_radius_all(10)
    panel_style.content_margin_left=12
    panel_style.content_margin_right=12
    panel_style.content_margin_top=8
    panel_style.content_margin_bottom=8
    panel.add_theme_stylebox_override("panel",panel_style)
    _shop_gallery_overlay.add_child(panel)
    var content:=VBoxContainer.new()
    content.name="SkinGalleryContent"
    content.add_theme_constant_override("separation",4)
    panel.add_child(content)
    var title:=Label.new()
    title.name="SkinGalleryHeading"
    title.text="TIENDA AURORA  /  TRAJES DE LILA"
    title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size",21)
    title.add_theme_color_override("font_color",Color(.98,.81,.45))
    content.add_child(title)
    _shop_gallery_balance=Label.new()
    _shop_gallery_balance.name="SkinGalleryLocalBalance"
    _shop_gallery_balance.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    _shop_gallery_balance.add_theme_font_size_override("font_size",14)
    _shop_gallery_balance.add_theme_color_override(
        "font_color",Color(.81,.93,.98))
    content.add_child(_shop_gallery_balance)
    var cards:=VBoxContainer.new()
    cards.name="SkinGalleryCards"
    cards.add_theme_constant_override("separation",5)
    cards.size_flags_vertical=Control.SIZE_EXPAND_FILL
    content.add_child(cards)
    for skin in ["aurora_base","aurora_glacier","aurora_ember"]:
        var card:=_button("",Callable(self,
            "_choose_skin_gallery").bind(skin),0)
        card.name="SkinCard"+skin
        card.custom_minimum_size=Vector2(0,48)
        card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        card.size_flags_vertical=Control.SIZE_EXPAND_FILL
        card.add_theme_font_size_override("font_size",16)
        cards.add_child(card)
        _shop_gallery_cards[skin]=card
    _shop_gallery_status=Label.new()
    _shop_gallery_status.name="SkinGallerySelectionStatus"
    _shop_gallery_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    _shop_gallery_status.add_theme_font_size_override("font_size",13)
    _shop_gallery_status.add_theme_color_override(
        "font_color",Color(.89,.94,.96))
    content.add_child(_shop_gallery_status)
    var actions:=HBoxContainer.new()
    actions.name="SkinGalleryRealActions"
    actions.add_theme_constant_override("separation",7)
    content.add_child(actions)
    _shop_gallery_buy=_button("COMPRAR",
        Callable(self,"_buy_local_skin"),0)
    _shop_gallery_buy.name="SkinGalleryBuy"
    _shop_gallery_buy.custom_minimum_size.y=42
    _shop_gallery_buy.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _shop_gallery_buy.add_theme_font_size_override("font_size",13)
    _style_primary_action(_shop_gallery_buy)
    actions.add_child(_shop_gallery_buy)
    _shop_gallery_equip=_button("EQUIPAR",
        Callable(self,"_equip_local_skin"),0)
    _shop_gallery_equip.name="SkinGalleryEquip"
    _shop_gallery_equip.custom_minimum_size.y=42
    _shop_gallery_equip.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _shop_gallery_equip.add_theme_font_size_override("font_size",13)
    _style_aurora_tab(_shop_gallery_equip,Color(.44,.76,.86))
    actions.add_child(_shop_gallery_equip)
    var close:=_button("VOLVER A LA TIENDA",
        Callable(self,"_close_skin_gallery"),0)
    close.name="CloseSkinGallery"
    close.custom_minimum_size=Vector2(0,42)
    close.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    close.add_theme_font_size_override("font_size",14)
    _style_aurora_tab(close,Color(.45,.68,.84))
    content.add_child(close)


func _open_skin_gallery() -> void:
    if stage!="lobby" or _selected_tab!="TIENDA" or (
            not is_instance_valid(_shop_gallery_overlay)):
        return
    _refresh_skin_gallery()
    # The older TIENDA inspector and purchase controls are inside Page.
    # Hide them while the live drawer is open: otherwise both UI layers
    # remain visible, and can suggest two separate purchase actions.
    if is_instance_valid(_page):
        _page.visible=false
    # The right-hand glass backplate is owned by the old shop inspector.
    # Without this toggle it becomes a large, empty black card beside Lila.
    if is_instance_valid(_lobby_menu_backplate):
        _lobby_menu_backplate.visible=false
    _shop_gallery_overlay.visible=true


func _close_skin_gallery() -> void:
    if is_instance_valid(_shop_gallery_overlay):
        _shop_gallery_overlay.visible=false
    # Page is also used for login and all other lobby sections. Restore
    # it on close, on tab changes and before transitioning to welcome.
    if is_instance_valid(_page):
        _page.visible=true
    if stage=="lobby" and is_instance_valid(_lobby_menu_backplate):
        _lobby_menu_backplate.visible=true


func _choose_skin_gallery(skin: String) -> void:
    if stage!="lobby" or _selected_tab!="TIENDA" or (
            not is_instance_valid(_shop_gallery_overlay)) or (
            not _shop_gallery_overlay.visible):
        return
    var ids: Array[String]=["aurora_base","aurora_glacier","aurora_ember"]
    var index: int=ids.find(skin)
    if index<0:
        return
    _on_shop_skin_selected(index)


func _refresh_skin_gallery() -> void:
    if _offline_records==null or _shop_gallery_cards.is_empty():
        return
    var ledger: Dictionary=_offline_records.cosmetic_state()
    var owned: Array=ledger["owned"] as Array
    var equipped: String=str(ledger["equipped"])
    var credits: int=int(ledger["coins"])
    if is_instance_valid(_shop_gallery_balance):
        _shop_gallery_balance.text="MONEDAS LOCALES: %d  ·  SIN PAGOS"%credits
    for skin in _shop_gallery_cards:
        var card: Button=_shop_gallery_cards[skin] as Button
        var price: int=int(MATCH_RECORDS.LOCAL_SKINS.get(str(skin),0))
        var has_skin: bool=owned.has(str(skin))
        var selected: bool=str(skin)==_shop_selected_skin
        var label: String=(
            "AURORA ORIGINAL" if skin=="aurora_base" else
            "AURORA GLACIAL" if skin=="aurora_glacier" else
            "AURORA FUEGO")
        card.text="%s   ·   %s"%[
            label,"EQUIPADO" if skin==equipped else
            "ADQUIRIDO" if has_skin else "%d MONEDAS"%price]
        card.set_meta("aurora_selected_skin",selected)
        if selected:
            _style_primary_action(card)
        else:
            _style_aurora_tab(card,Color(.36,.60,.78))
    var selected_price: int=int(MATCH_RECORDS.LOCAL_SKINS.get(
        _shop_selected_skin,0))
    var is_owned: bool=owned.has(_shop_selected_skin)
    var is_equipped: bool=equipped==_shop_selected_skin
    if is_instance_valid(_shop_gallery_status):
        _shop_gallery_status.text=(
            "VISTA 3D · COMPRA PERMANENTE LOCAL" if not is_owned else
            "YA EQUIPADO" if is_equipped else
            "ADQUIRIDO · PUEDES EQUIPARLO")
    if is_instance_valid(_shop_gallery_buy):
        _shop_gallery_buy.disabled=is_owned or selected_price<=0 or (
            credits<selected_price)
        _shop_gallery_buy.text=(
            "COMPRADO" if is_owned else
            "SIN MONEDAS" if credits<selected_price else
            "COMPRAR · %d"%selected_price)
    if is_instance_valid(_shop_gallery_equip):
        _shop_gallery_equip.disabled=not is_owned or is_equipped
        _shop_gallery_equip.text=(
            "EQUIPADO" if is_equipped else
            "EQUIPAR" if is_owned else "NO ADQUIRIDO")


func _style_aurora_tab(button: Button,tint: Color) -> void:
    var normal:=StyleBoxFlat.new()
    normal.bg_color=Color(.014,.030,.054,.83)
    normal.border_color=tint.darkened(.22)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(6)
    normal.shadow_color=Color(.015,.045,.080,.23)
    normal.shadow_size=2
    var hover:=normal.duplicate() as StyleBoxFlat
    hover.bg_color=Color(.072,.12,.19,.98)
    var pressed:=hover.duplicate() as StyleBoxFlat
    pressed.border_color=Color(.98,.77,.31)
    button.add_theme_stylebox_override("normal",normal)
    button.add_theme_stylebox_override("hover",hover)
    button.add_theme_stylebox_override("pressed",pressed)
    button.add_theme_color_override("font_color",Color(.95,.95,1))
    button.add_theme_color_override("font_hover_color",Color(1,.88,.64))
    button.add_theme_color_override("font_pressed_color",Color(1,.93,.77))
    button.add_theme_color_override("icon_normal_color",Color(.91,.96,1.0))
    button.add_theme_color_override("icon_hover_color",Color(1.0,.98,.84))


## Bottom navigation indicates the currently open module, not a persistent
## gold play action. The actual INICIAR button is handled separately.
func _style_bottom_navigation_active(tab: String) -> void:
    if _bottom_navigation==null:
        return
    for child in _bottom_navigation.get_children():
        var button: Button=child as Button
        if button==null:
            continue
        var active: bool=button.name=="Bottom"+tab
        button.set_meta("aurora_active",active)
        if active and tab=="JUGAR":
            _style_primary_action(button)
        elif active:
            var selected:=StyleBoxFlat.new()
            selected.bg_color=Color(.13,.20,.29,.99)
            selected.border_color=Color(.98,.79,.34)
            selected.set_border_width_all(2)
            selected.border_width_bottom=3
            selected.set_corner_radius_all(6)
            var hover:=selected.duplicate() as StyleBoxFlat
            hover.bg_color=Color(.20,.29,.39,1.0)
            button.add_theme_stylebox_override("normal",selected)
            button.add_theme_stylebox_override("hover",hover)
            button.add_theme_stylebox_override("pressed",hover)
            button.add_theme_color_override("font_color",Color(1,.92,.73))
            button.add_theme_color_override("font_hover_color",Color(1,.94,.78))
            button.add_theme_color_override("font_pressed_color",Color(1,.94,.78))
        else:
            _style_aurora_tab(button,Color(.30,.63,.83))
            button.add_theme_color_override("font_pressed_color",Color(.95,.95,1))
        button.modulate=Color.WHITE if active else Color(.84,.88,.94)


## Real offline performance and optionally server-confirmed identity.
## Accessible at top LEFT. No invented battle rank, UID, premium balance or
## pretend online friends are displayed.
func _build_player_profile() -> void:
    if _profile_overlay!=null and is_instance_valid(_profile_overlay):
        return
    _profile_overlay=Control.new()
    _profile_overlay.name="AuroraVerifiedProfileOverlay"
    _profile_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _profile_overlay.mouse_filter=Control.MOUSE_FILTER_STOP
    _surface.add_child(_profile_overlay)
    var scrim:=ColorRect.new()
    scrim.name="ProfileScrim"
    scrim.color=Color(.005,.012,.033,.85)
    scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scrim.mouse_filter=Control.MOUSE_FILTER_STOP
    _profile_overlay.add_child(scrim)
    var panel:=PanelContainer.new()
    panel.name="RealPlayerProfilePanel"
    panel.anchor_left=.145
    panel.anchor_right=.855
    panel.anchor_top=.130
    panel.anchor_bottom=.862
    var style:=StyleBoxFlat.new()
    style.bg_color=Color(.015,.029,.057,.98)
    style.border_color=Color(.36,.78,.93,.88)
    style.set_border_width_all(2)
    style.set_corner_radius_all(12)
    style.content_margin_left=18
    style.content_margin_right=18
    style.content_margin_top=11
    style.content_margin_bottom=12
    panel.add_theme_stylebox_override("panel",style)
    _profile_overlay.add_child(panel)
    var column:=VBoxContainer.new()
    column.name="VerifiedPlayerData"
    column.add_theme_constant_override("separation",5)
    panel.add_child(column)
    var titlebar:=HBoxContainer.new()
    column.add_child(titlebar)
    var title:=Label.new()
    title.text="MI PERFIL"
    title.name="RealProfileTitle"
    title.add_theme_font_override("font",DISPLAY_FONT)
    title.add_theme_font_size_override("font_size",26)
    title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    titlebar.add_child(title)
    var close:=_button("CERRAR",Callable(self,"_close_player_profile"),0)
    close.name="CloseRealProfile"
    close.custom_minimum_size=Vector2(125,35)
    titlebar.add_child(close)
    _profile_name_label=Label.new()
    _profile_name_label.name="VerifiedProfileName"
    _profile_name_label.add_theme_font_override("font",DISPLAY_FONT)
    _profile_name_label.add_theme_font_size_override("font_size",23)
    column.add_child(_profile_name_label)
    _profile_id_label=Label.new()
    _profile_id_label.name="VerifiedProfileId"
    _profile_id_label.add_theme_font_size_override("font_size",14)
    _profile_id_label.add_theme_color_override(
        "font_color",Color(.67,.86,.98))
    column.add_child(_profile_id_label)
    var stats:=HBoxContainer.new()
    stats.name="ActualMatchStats"
    stats.add_theme_constant_override("separation",8)
    column.add_child(stats)
    for name in ["PARTIDAS","VICTORIAS","ELIMINACIONES"]:
        var tile:=PanelContainer.new()
        tile.name="RealStat"+name
        tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        tile.custom_minimum_size.y=68
        var tile_style:=StyleBoxFlat.new()
        tile_style.bg_color=Color(.051,.094,.144,.83)
        tile_style.border_color=Color(.22,.56,.70,.58)
        tile_style.set_border_width_all(1)
        tile_style.set_corner_radius_all(7)
        tile.add_theme_stylebox_override("panel",tile_style)
        stats.add_child(tile)
        var tile_column:=VBoxContainer.new()
        tile.add_child(tile_column)
        var value:=Label.new()
        value.name="StatValue"
        value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        value.add_theme_font_size_override("font_size",23)
        value.add_theme_color_override(
            "font_color",Color(1.0,.79,.32))
        tile_column.add_child(value)
        _profile_stat_labels.append(value)
        var caption:=Label.new()
        caption.text=name
        caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        caption.add_theme_font_size_override("font_size",13)
        tile_column.add_child(caption)
    _profile_session_label=Label.new()
    _profile_session_label.name="VerifiedProfileConnection"
    _profile_session_label.add_theme_font_size_override("font_size",14)
    _profile_session_label.add_theme_color_override(
        "font_color",Color(.65,.83,.92))
    column.add_child(_profile_session_label)
    var action:=_button("CUENTA Y RESPALDO",
        Callable(self,"_open_profile_account"),0)
    action.name="ManageProfileAccount"
    action.custom_minimum_size.y=37
    action.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _style_aurora_tab(action,Color(.40,.78,.90))
    column.add_child(action)
    _profile_overlay.hide()


func _refresh_player_profile() -> void:
    if _profile_overlay==null or _offline_records==null:
        return
    var saved: Dictionary=_offline_records.snapshot()
    var session: Dictionary=FIREBASE_BRIDGE.session_state()
    var confirmed: bool=bool(session.get("identity_confirmed",false))
    var display: String=str(session.get("display_name","")) if confirmed else ""
    if display.is_empty():
        display=_player_name.display_name
    _profile_name_label.text=display
    _profile_id_label.text=("ID %s · IDENTIDAD CONFIRMADA"%[
        str(session.get("official_id",""))] if confirmed
        else "PERFIL LOCAL · SIN ID EN LÍNEA CONFIRMADO")
    var values: Array[int]=[
        int(saved.get("played",0)),int(saved.get("wins",0)),
        int(saved.get("kills",0))]
    for i in range(mini(_profile_stat_labels.size(),values.size())):
        _profile_stat_labels[i].text=str(values[i])
    _profile_session_label.text=(
        "Sesión autenticada: "+str(session.get("provider","")).to_upper()
        if bool(session.get("authenticated",false)) else
        "Progreso local verificado en este dispositivo")


func _open_player_profile() -> void:
    if stage!="lobby" or _profile_overlay==null:
        return
    _refresh_player_profile()
    _profile_overlay.show()


func _close_player_profile() -> void:
    if _profile_overlay!=null:
        _profile_overlay.hide()


func _open_profile_account() -> void:
    _close_player_profile()
    _select_tab("CUENTA")


func _open_lobby_category(tab: String,objective: String="") -> void:
    if not objective.is_empty():
        _objective_page=objective
        if _objective_selector!=null and objective!="events":
            _objective_selector.current_tab=1 if objective=="achievements" else 0
    _select_tab(tab)


func _select_tab(tab: String) -> void:
    # Legacy PRESET and AJUSTES routes both open one canonical overlay.
    # Neither creates another HUD/CONTROLES settings panel in the lobby.
    if tab in ["PRESET","AJUSTES"]:
        _open_settings()
        return
    _selected_tab=tab
    if stage!="lobby" or _info==null:
        return
    if tab!="JUGAR":
        _close_mode_gallery()
    if tab!="TIENDA":
        _close_skin_gallery()
    if _left_shortcuts!=null:
        for button in _left_shortcuts.get_children():
            if button is Button:
                var target: String=button.name.trim_prefix("Quick")
                var active: bool=(target==tab or (tab=="OBJETIVOS" and
                    (target==str(_objective_page).to_upper() or
                     (target=="MISSIONS" and _objective_page=="achievements"))))
                button.modulate=Color.WHITE if active else Color(.72,.76,.85)
    _style_bottom_navigation_active(tab)
    if _social_panel!=null:
        _social_panel.visible=tab=="JUGAR"
    if _play_match_card!=null:
        _play_match_card.visible=tab=="JUGAR"
    if _lobby_compact_intel!=null:
        _lobby_compact_intel.visible=false
    _page.anchor_left=.735
    _page.anchor_right=.961
    _page.anchor_top=.386 if tab=="JUGAR" else .183
    _page.anchor_bottom=.562 if tab=="JUGAR" else .860
    for button in _lobby_nav.get_children():
        if button is Button:
            var selected: bool=button.name=="Tab"+tab
            button.modulate=Color(1,1,1) if selected else Color(.76,.82,.89)
    if _lobby_section_title!=null:
        _lobby_section_title.text=(
            "" if tab=="JUGAR"
            else "MI CUENTA" if tab=="CUENTA"
            else "CONFIGURACIÓN" if tab=="AJUSTES"
            else ("EVENTOS" if _objective_page=="events" else "MISIONES / LOGROS") if tab=="OBJETIVOS"
            else tab)
        _lobby_section_hint.text=(
            "" if tab=="JUGAR"
            else "PERFIL / RESPALDO / ACCESO" if tab=="CUENTA"
            else "CONTROLES / SENSIBILIDAD / HUD" if tab=="AJUSTES"
            else "BASE AURORA · CENTRO DE OPERACIONES")
    match tab:
        "JUGAR":
            _info.text="BR CLÁSICO · 50 PARTICIPANTES\n1 operador y 49 rivales IA. Pulsa INICIAR para desplegarte.\nCLASIFICATORIA ONLINE: pendiente de servidor."
        "AJUSTES":
            _info.text="CÁMARA / PRECISIÓN / HUD\nSensibilidades y controles personalizables guardados en este dispositivo."
        "PERSONAJE":
            var stats: Dictionary=_offline_records.snapshot()
            _info.text=(
                "OPERADOR MASCULINO / VISTA 3D\nModelo Ch02 original con CAMINAR, TROTAR y SALTAR.\nCombate masculino pendiente de clips de disparo/recarga."
                if _preview_male_active else
                "LILA AURORA\nTraje táctico personalizable.\nCAMBIAR VISTA / GIRAR: controles táctiles bajo Lila.\nVISTA 3D: %s · sin compra ni equipamiento."%_shop_selected_skin.to_upper())
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
            _update_equipment_details()
        "ARMAS":
            _update_armory_details()
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
    if _operator_selector!=null:
        _operator_selector.select(1 if _preview_male_active else 0)
    _sync_armory_visual()
    # Real 3D cosmetics are previewed only in the shop/character screens.
    # Leaving both restores the equipped outfit; no purchase is performed.
    if _offline_records!=null and _preview_avatar!=null and (
            is_instance_valid(_preview_avatar)):
        var shown: String=(_shop_selected_skin if tab in ["TIENDA","PERSONAJE"] else
            str(_offline_records.cosmetic_state()["equipped"]))
        _apply_preview_skin(shown)

## Filtered row indices are not weapon slot IDs. Item metadata always holds
## the original catalog slot, so saves, BR loot and training never get remapped.
func _refresh_armory_catalog() -> void:
    if _armory_list==null:
        return
    var filtered: Array[int]=WEAPON_FAMILIES.slots_for_family(_armory_category)
    _armory_selected_slot=WEAPON_FAMILIES.selected_slot_for_family(
        _armory_category,_armory_selected_slot)
    _armory_list.clear()
    for slot in filtered:
        var weapon: Dictionary=WEAPON_CATALOG.ENTRIES[slot]
        var available: bool=_armory_has_model(slot)
        var row: int=_armory_list.item_count
        _armory_list.add_item("%s  ·  %s"%[
            "KRISS VECTOR" if slot==WEAPON_CATALOG.KRISS else str(weapon["short"]),
            "MODELO LISTO" if available else "GLB PENDIENTE"])
        _armory_list.set_item_metadata(row,slot)
        if slot==_armory_selected_slot:
            _armory_list.select(row)
    _armory_list.ensure_current_is_visible()


func _on_armory_category_selected(index: int) -> void:
    if _armory_category_selector==null:
        return
    _armory_category=_armory_category_selector.get_item_id(index)
    _refresh_armory_catalog()
    if stage=="lobby" and _selected_tab=="ARMAS":
        _update_armory_details()
        _sync_armory_visual()


func _on_armory_slot_selected(row: int) -> void:
    if _armory_list==null or row<0 or row>=_armory_list.item_count:
        return
    var slot: int=int(_armory_list.get_item_metadata(row))
    if slot<0 or slot>=WEAPON_CATALOG.ENTRIES.size():
        return
    _armory_selected_slot=slot
    if stage=="lobby" and _selected_tab=="ARMAS":
        _update_armory_details()
        _sync_armory_visual()


func _armory_has_model(slot: int) -> bool:
    var path: String=_armory_model_path(slot)
    return not path.is_empty() and ResourceLoader.exists(path,"PackedScene")


## Reuse the existing Aurora 3D SubViewport instead of allocating a
## separate renderer for the armory. Show only genuine imported weapon GLBs.
## Missing licensed sources remain unavailable: never substitute a fake model.
func _armory_model_path(slot: int) -> String:
    if slot==WEAPON_CATALOG.AR:
        return WEAPON_VISUALS.AK_PATH
    if slot==WEAPON_CATALOG.AWM:
        return WEAPON_VISUALS.AWM_PATH
    if slot>=0 and slot<WEAPON_CATALOG.ENTRIES.size():
        return str(WEAPON_CATALOG.ENTRIES[slot].get("asset",""))
    return ""



## The imported GLBs do not agree on their longitudinal/up axes.
## Derive a level showroom pose from the original mesh bounds rather than
## applying a generic 10-degree bank (which made MP40/AWM/AR-7 point upward).
## This is lobby-only: gameplay rig, muzzle and socket transforms are untouched.
func _armory_level_pose(extent: Vector3) -> Dictionary:
    var long_axis: Vector3=Vector3.RIGHT
    var source_up: Vector3=Vector3.UP
    if extent.y>=extent.x and extent.y>=extent.z:
        long_axis=Vector3.UP
        source_up=Vector3.BACK if extent.z>=extent.x else Vector3.RIGHT
    elif extent.z>=extent.x:
        long_axis=Vector3.BACK
        source_up=Vector3.UP if extent.y>=extent.x else Vector3.RIGHT
    else:
        source_up=Vector3.UP if extent.y>=extent.z else Vector3.BACK
    # Bring the longitudinal model axis onto showroom X, and roll its
    # second-largest axis upright. This preserves level barrels independently
    # of source GLB up-axis, while keeping a shallow three-quarter yaw.
    var aim: Quaternion=Quaternion(long_axis,Vector3.RIGHT)
    var spun_up: Vector3=aim*source_up
    var level: Quaternion=Quaternion(Vector3.RIGHT,
        -atan2(spun_up.z,spun_up.y))
    var hero: Quaternion=Quaternion(Vector3.UP,deg_to_rad(-16.0))
    return {"rotation":hero*level*aim,"long_axis":long_axis,
        "source_up":source_up}


func _clear_weapon_preview() -> void:
    if _preview_weapon!=null and is_instance_valid(_preview_weapon):
        if _preview_weapon.get_parent()!=null:
            _preview_weapon.get_parent().remove_child(_preview_weapon)
        _preview_weapon.queue_free()
    _preview_weapon=null
    _preview_weapon_slot=-1


func _sync_armory_visual() -> void:
    if stage!="lobby" or _preview_container==null or not is_instance_valid(
            _preview_container):
        return
    var in_armory: bool=_selected_tab=="ARMAS"
    if is_instance_valid(_armory_fill_light):
        _armory_fill_light.visible=in_armory
    if is_instance_valid(_armory_inspection_backdrop):
        _armory_inspection_backdrop.visible=in_armory
    if not in_armory:
        _clear_weapon_preview()
        if _preview_avatar!=null and is_instance_valid(_preview_avatar):
            _preview_avatar.visible=true
        if _preview_caption!=null and is_instance_valid(_preview_caption):
            _preview_caption.text=("CH02 MIXAMO / VISTA PREVIA" if
                _preview_male_active else "LILA AURORA / OPERADORA")
        if _gesture_button!=null and is_instance_valid(_gesture_button):
            _gesture_button.visible=true
        for action in _operator_controls:
            if is_instance_valid(action):
                action.visible=true
        return
    # In ARMAS the center of the 3D stage belongs to the selected rifle;
    # Lila and her gesture controls return when navigating to another tab.
    if _gesture_button!=null and is_instance_valid(_gesture_button):
        _gesture_button.visible=false
    for action in _operator_controls:
        if is_instance_valid(action):
            action.visible=false
    if (_preview_weapon_slot==_armory_selected_slot and
            _preview_weapon!=null and is_instance_valid(_preview_weapon)):
        return
    _clear_weapon_preview()
    var spec: Dictionary=WEAPON_CATALOG.ENTRIES[_armory_selected_slot]
    # The original SCAR's gunmetal receiver is dark gray. Against the
    # navy inspection panel it was still nearly invisible in actual CI PNGs.
    # Change ONLY the lobby backdrop, never its original GLB material.
    if is_instance_valid(_armory_matte_material):
        _armory_matte_material.albedo_color=(
            Color(.37,.46,.55,.94)
            if _armory_selected_slot==WEAPON_CATALOG.SCAR
            else Color(.085,.135,.19,.89))
    var path: String=_armory_model_path(_armory_selected_slot)
    if path.is_empty() or not ResourceLoader.exists(path,"PackedScene"):
        if _preview_avatar!=null and is_instance_valid(_preview_avatar):
            _preview_avatar.visible=true
        if _preview_caption!=null:
            _preview_caption.text="MODELO 3D PENDIENTE / "+str(spec["short"])
        return
    var source: PackedScene=load(path) as PackedScene
    if source==null:
        return
    var stage3d: Node3D=_preview_container.get_node_or_null(
        "PreviewViewport/AuroraCharacterStage") as Node3D
    if stage3d==null:
        return
    var pivot:=Node3D.new()
    pivot.name="AuroraSelectedWeaponPreview"
    pivot.position=Vector3(0,.98,.12)
    stage3d.add_child(pivot)
    var visual: Node3D=source.instantiate() as Node3D
    if visual==null:
        pivot.queue_free()
        return
    visual.name="SelectedOriginalWeaponGLB"
    pivot.add_child(visual)
    var low:=Vector3(INF,INF,INF)
    var high:=Vector3(-INF,-INF,-INF)
    var meshes: int=0
    for node in visual.find_children("*","MeshInstance3D",true,false):
        var part: MeshInstance3D=node as MeshInstance3D
        if part.mesh==null:
            continue
        meshes+=1
        part.layers|=PORTRAIT_LIGHT_LAYER
        var bounds: AABB=part.get_aabb()
        for corner in range(8):
            var point: Vector3=visual.to_local(part.to_global(
                bounds.get_endpoint(corner)))
            low=low.min(point)
            high=high.max(point)
    var extent: Vector3=high-low
    var length: float=maxf(extent.x,maxf(extent.y,extent.z))
    if meshes==0 or not extent.is_finite() or not is_finite(length) or length<=.0001:
        pivot.queue_free()
        if _preview_caption!=null:
            _preview_caption.text="GEOMETRÍA NO DISPONIBLE / "+str(spec["short"])
        return
    var display_pose: Dictionary=_armory_level_pose(extent)
    visual.quaternion=display_pose["rotation"]
    # Geometry-based axis metadata lets QA verify screen-space levelness
    # without relying on a particular source asset's Euler angles.
    visual.set_meta("armory_long_axis",display_pose["long_axis"])
    visual.set_meta("armory_up_axis",display_pose["source_up"])
    var scale_factor: float=clampf(1.80/length,.00001,100.0)
    var source_center: Vector3=(low+high)*.5
    visual.scale=Vector3.ONE*scale_factor
    visual.position=-(visual.quaternion*source_center)*scale_factor
    _preview_weapon=pivot
    _preview_weapon_slot=_armory_selected_slot
    if _preview_avatar!=null and is_instance_valid(_preview_avatar):
        _preview_avatar.visible=false
    if _preview_caption!=null:
        _preview_caption.text=str(spec["short"])+"  ·  VISTA 3D 360°"
    _preview_resume_spin=1.0


func _update_armory_details() -> void:
    if _info==null:
        return
    var weapon: Dictionary=WEAPON_CATALOG.ENTRIES[_armory_selected_slot]
    var available: bool=_armory_has_model(_armory_selected_slot)
    if _armory_test_button!=null:
        _armory_test_button.disabled=not available
        _armory_test_button.tooltip_text=(
            "La selección aparecerá al comienzo de la armería física." if available else
            "Modelo 3D no instalado: prueba deshabilitada hasta importar el GLB.")
    var magazine: String=("SIN MUNICIÓN" if bool(weapon.get("melee",false))
        else "CARGADOR: %d"%int(weapon["capacity"]))
    var cadence: float=maxf(.001,float(weapon["cadence"]))
    var critical: float=float(weapon["critical"])
    var family: String=WEAPON_FAMILIES.family_title(_armory_selected_slot)
    _info.text=("ARSENAL AURORA  ·  %s\n"
        +"%s  /  ID DE CATÁLOGO %d\n"
        +"DAÑO BASE %.0f  ·  CRÍTICO ×%.2f\n"
        +"CADENCIA %.1f DISPAROS/S  ·  RECARGA %.2f S\n"
        +"%s  ·  RETROCESO %.3f\n"
        +"%s\n")%[
        family,str(weapon["label"]),_armory_selected_slot,
        float(weapon["damage"]),critical,1.0/cadence,
        float(weapon["reload"]),magazine,float(weapon["recoil"]),
        "MODELO 3D AUTORIZADO INSTALADO" if available else
        "MODELO 3D PENDIENTE · NO DISPONIBLE"]
    # AWM exists as a physical local BR pickup, independent of whether an
    # optional training model has been imported. Keep its map position
    # discoverable no matter which catalog entry the user is browsing.
    _info.text+="\nAWM EN BR LOCAL: PLAZA (8, 24). Busca la baliza RECOGER AWM.\n"
    _info.text+=("PRUEBA: tu selección aparece primero en la armería física de Entrenamiento.\n"+
        "Debes recogerla; el catálogo no concede armas ni desbloqueos." if available else
        "\nSIN MODELO INSTALADO: esta arma requiere su GLB autorizado antes de poder probarla.")


func _open_weapon_training() -> void:
    if stage!="lobby" or _selected_tab!="ARMAS":
        return
    var selected: Dictionary=WEAPON_CATALOG.ENTRIES[_armory_selected_slot]
    var asset: String=str(selected.get("asset",""))
    if not asset.is_empty() and not ResourceLoader.exists(asset,"PackedScene"):
        _update_armory_details()
        return
    _requested_training_weapon_slot=_armory_selected_slot
    _selected_match_mode="training"
    _launch(false)


func _refresh_equipment_catalog() -> void:
    if _equipment_selector==null:
        return
    var slots: Array[int]=EQUIPMENT_FAMILIES.slots_for_category(
        _equipment_category)
    _equipment_selected=EQUIPMENT_FAMILIES.select_slot(
        _equipment_category,_equipment_selected)
    _equipment_selector.clear()
    for slot in slots:
        # The item ID IS the original BR equipment ID, not a filtered row.
        _equipment_selector.add_item(
            EQUIPMENT_FAMILIES.ITEM_NAMES[slot],slot)
        if slot==_equipment_selected:
            _equipment_selector.select(_equipment_selector.item_count-1)


func _on_equipment_category_selected(index: int) -> void:
    if _equipment_category_selector==null:
        return
    _equipment_category=_equipment_category_selector.get_item_id(index)
    _refresh_equipment_catalog()
    if stage=="lobby" and _selected_tab=="INVENTARIO":
        _update_equipment_details()


func _on_equipment_selected(index: int) -> void:
    if _equipment_selector==null or index<0 or (
            index>=_equipment_selector.item_count):
        return
    var slot: int=_equipment_selector.get_item_id(index)
    if slot<0 or slot>=EQUIPMENT_FAMILIES.ITEM_NAMES.size():
        return
    _equipment_selected=slot
    if stage=="lobby" and _selected_tab=="INVENTARIO":
        _update_equipment_details()


func _update_equipment_details() -> void:
    if _info==null:
        return
    var selected: int=clampi(_equipment_selected,0,
        EQUIPMENT_FAMILIES.ITEM_NAMES.size()-1)
    var category: String=EQUIPMENT_FAMILIES.family_for_slot(selected)
    _info.text="INVENTARIO EN PARTIDA · %s  ·  %d / %d\n%s\n\n"%[
        category,selected+1,EQUIPMENT_FAMILIES.ITEM_NAMES.size(),
        EQUIPMENT_FAMILIES.DESCRIPTIONS[selected]]
    _info.text+=("Este catálogo explica objetos del Battle Royale. El inventario "+
        "real y el equipo disponible se consultan en el HUD durante cada partida; "+
        "abrir esta sección no otorga objetos ni inventa compras.")


func _apply_preview_skin(skin: String) -> void:
    if stage!="lobby" or _preview_avatar==null or not (
            is_instance_valid(_preview_avatar)) or _preview_male_active or (
            _preview_skin_applied==skin):
        return
    if COSMETICS.apply_to_operator(_preview_avatar,skin):
        _preview_skin_applied=skin
        var body:=_preview_avatar.find_child("Lila_Aurora_Mesh",true,false) as MeshInstance3D
        body.material_override=null
        if skin==COSMETICS.ORIGINAL_SKIN:
            var material:=body.mesh.surface_get_material(0) as StandardMaterial3D
            if material!=null and material.albedo_texture!=null:
                var portrait:=ShaderMaterial.new()
                portrait.shader=LOBBY_OPERATOR_SURFACE
                portrait.set_shader_parameter("source_albedo",material.albedo_texture)
                body.material_override=portrait


## The character selector switches real imported previews; this does not
## replace the playable battle operator or create online character ownership.
func _on_operator_selected(index: int) -> void:
    if _operator_selector==null or stage!="lobby" or (
            _selected_tab!="PERSONAJE"):
        return
    var target_male: bool=_operator_selector.get_item_id(index)==1
    if target_male!=_preview_male_active:
        _toggle_mixamo_preview()
    _operator_selector.select(1 if _preview_male_active else 0)


func _on_shop_skin_selected(index: int) -> void:
    var ids: Array[String]=["aurora_base","aurora_glacier","aurora_ember"]
    if index>=0 and index<ids.size():
        _shop_selected_skin=ids[index]
        if is_instance_valid(_shop_selector):
            _shop_selector.select(index)
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
    _refresh_skin_gallery()


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
    _close_mode_gallery()
    _close_skin_gallery()
    if is_instance_valid(_mode_gallery_entry):
        _mode_gallery_entry.visible=false
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
    _set_loading_tip_context(
        "hud_editor" if _hud_editor_requested else
        "battle" if battle else "training")
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
    _loading_detail.text="Instanciando escena real: terreno, IA, operador y HUD…"
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
    # The real HUD editor can be hosted in a temporary Training scene.
    # Persisting a lobby-origin edit must return to the lobby automatically.
    hud.set("return_to_lobby_on_save",_hud_editor_requested and _hud_editor_origin=="lobby")
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
        else:
            var combat: Node3D=_game.get_node("CombatRange")
            combat.open_training_armory(_requested_training_weapon_slot)
            _requested_training_weapon_slot=-1
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
    _requested_training_weapon_slot=-1
    _show_lobby()


func _release_preview() -> void:
    _clear_weapon_preview()
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
    if _emote_wheel!=null and is_instance_valid(_emote_wheel):
        _emote_wheel.queue_free()
    _emote_wheel=null
    _preview_zoomed=false
    _preview_skin_applied=""
    _preview_male_active=false
    _preview_male_motion_index=0
    if _preview_caption!=null and is_instance_valid(_preview_caption):
        _preview_caption.queue_free()
    _preview_container=null
    _preview_caption=null
    _preview_avatar=null
    _preview_touch=-1
    _preview_mouse_drag=false
    _preview_tap_dragged=false
    _preview_resume_spin=0.0


## An actual optional FBX-derived GLB in the existing live 3D viewport.
## Lila remains the combat operator until the male receives authored gun
## firing, reload and medical animations; never silently enable a T-pose BR.
func _toggle_mixamo_preview() -> void:
    if stage!="lobby" or _preview_container==null:
        return
    var scene3d: Node3D=_preview_container.get_node_or_null(
        "PreviewViewport/AuroraCharacterStage") as Node3D
    if scene3d==null:
        return
    var next_male: bool=not _preview_male_active
    var incoming: Node3D=null
    if next_male:
        incoming=MALE_PREVIEW.instantiate_valid_preview()
        if incoming==null:
            if _info:
                _info.text="Modelo Ch02 no importado o clips de locomoción incompletos."
            return
        incoming.name="AuroraMaleMixamoPreview"
    else:
        var path: String="res://assets/characters/lila_aurora.glb"
        if ResourceLoader.exists(path,"PackedScene"):
            var scene: PackedScene=load(path) as PackedScene
            if scene:
                incoming=scene.instantiate() as Node3D
        if incoming==null:
            return
        incoming.name="LilaAuroraPreview"
    if _preview_avatar!=null and is_instance_valid(_preview_avatar):
        _preview_avatar.visible=false
        _preview_avatar.queue_free()
    scene3d.add_child(incoming)
    _preview_avatar=incoming
    _preview_male_active=next_male
    if _operator_selector!=null and is_instance_valid(_operator_selector):
        _operator_selector.select(1 if next_male else 0)
    _preview_male_motion_index=0
    _preview_resume_spin=2.0
    _preview_skin_applied=""
    _fit_avatar_for_preview(incoming)
    for node in incoming.find_children("*","MeshInstance3D",true,false):
        (node as MeshInstance3D).layers|=PORTRAIT_LIGHT_LAYER
    if next_male:
        MALE_PREVIEW.play_original_motion(incoming,"AuroraArmedWalk")
    else:
        var player: AnimationPlayer=incoming.find_child(
            "*AnimationPlayer*",true,false) as AnimationPlayer
        if player and player.has_animation("AuroraIdle"):
            player.play("AuroraIdle")
            _install_lobby_motion(player)
        if _offline_records:
            _apply_preview_skin(str(
                _offline_records.cosmetic_state()["equipped"]))
    if _preview_caption:
        _preview_caption.text=("CH02 MIXAMO / VISTA PREVIA"
            if next_male else "LILA AURORA / OPERADORA")
    if _gesture_button:
        _gesture_button.text=("MOVIMIENTO ▶" if next_male else "GESTO ▶")
    for button in _operator_controls:
        if is_instance_valid(button) and button.name=="AuroraMalePreviewSelector":
            button.text=("LILA" if next_male else "CH02")
    if _selected_tab=="PERSONAJE":
        _select_tab("PERSONAJE")


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
        if _preview_zoomed else Vector3(-.10,1.18,3.58))
    _preview_frame_tween=create_tween()
    _preview_frame_tween.set_parallel(true)
    _preview_frame_tween.set_trans(Tween.TRANS_CUBIC)
    _preview_frame_tween.set_ease(Tween.EASE_OUT)
    _preview_frame_tween.tween_property(camera,"fov",target_fov,.25)
    _preview_frame_tween.tween_property(
        camera,"position",target_position,.25)


func _on_mixamo_preview_motion_finished(_clip: StringName) -> void:
    if _preview_male_active and _preview_avatar!=null and (
            is_instance_valid(_preview_avatar)):
        MALE_PREVIEW.play_original_motion(_preview_avatar,"AuroraArmedWalk")


func _play_lobby_gesture() -> void:
    if stage!="lobby" or _preview_avatar==null or not is_instance_valid(
            _preview_avatar):
        return
    if _preview_male_active:
        _preview_male_motion_index=(_preview_male_motion_index+1)%3
        var clip: String=[
            "AuroraArmedWalk","AuroraArmedRun","AuroraJump"
        ][_preview_male_motion_index]
        var subject: Node3D=_preview_avatar
        if MALE_PREVIEW.play_original_motion(subject,clip):
            _preview_resume_spin=3.0
            if clip=="AuroraJump":
                var source_player: AnimationPlayer=subject.find_child(
                    "*AnimationPlayer*",true,false) as AnimationPlayer
                if source_player:
                    source_player.animation_finished.connect(
                        Callable(self,"_on_mixamo_preview_motion_finished"),
                        CONNECT_ONE_SHOT)
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
    _surface.move_child(_preview_container,_arctic_art.get_index()+1)

    var viewport:=SubViewport.new()
    viewport.name="PreviewViewport"
    viewport.size=Vector2i(832,584)
    viewport.own_world_3d=true
    viewport.transparent_bg=false
    viewport.msaa_3d=Viewport.MSAA_2X
    viewport.positional_shadow_atlas_size=512
    viewport.positional_shadow_atlas_quad_0=Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1
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
    ambient.name="AuroraAirfieldAtmosphere"
    var env:=Environment.new()
    var sky_material:=ShaderMaterial.new()
    sky_material.shader=AIRFIELD_SKY
    var sky:=Sky.new()
    sky.sky_material=sky_material
    sky.radiance_size=Sky.RADIANCE_SIZE_64
    env.background_mode=Environment.BG_SKY
    env.sky=sky
    env.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
    env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    # Soft sky fill keeps the lilac hair and cool fabric readable under
    # the warm portrait key and blue edge light.
    env.ambient_light_color=Color(.63,.74,.93)
    env.ambient_light_energy=.52
    env.ambient_light_sky_contribution=0.0
    env.fog_enabled=true
    env.fog_light_color=Color(.17,.27,.43)
    env.fog_density=.0045
    env.fog_sky_affect=0.0
    ambient.environment=env
    stage3d.add_child(ambient)
    var key:=DirectionalLight3D.new()
    key.name="AuroraPortraitKey"
    key.rotation_degrees=Vector3(-40,31,0)
    key.light_color=Color(1.0,.94,.89)
    key.light_energy=1.04
    stage3d.add_child(key)
    var rim:=DirectionalLight3D.new()
    rim.name="AuroraPortraitRim"
    rim.rotation_degrees=Vector3(-22,-138,0)
    rim.light_color=Color(.51,.69,1.0)
    rim.light_energy=.68
    stage3d.add_child(rim)
    # Keep the operator's contact shadow in the lobby's small positional atlas.
    var portrait_spot:=SpotLight3D.new()
    portrait_spot.name="AuroraPortraitSpot"
    portrait_spot.position=Vector3(-1.04,2.68,1.45)
    portrait_spot.light_color=Color(1.0,.89,.78)
    portrait_spot.light_energy=.34
    portrait_spot.spot_range=4.25
    portrait_spot.spot_angle=37.0
    portrait_spot.light_cull_mask=PORTRAIT_LIGHT_LAYER
    portrait_spot.shadow_caster_mask=PORTRAIT_LIGHT_LAYER
    portrait_spot.shadow_enabled=true
    stage3d.add_child(portrait_spot)
    portrait_spot.look_at(Vector3(0,.62,-.15),Vector3.UP)
    # The SCAR and scoped AWM lost nearly all edge contrast against the
    # dark aircraft hangar in the actual 964x434 CI screenshots. An armory-
    # only fill illuminates imported GLB meshes, not the whole island/lobby.
    _armory_fill_light=OmniLight3D.new()
    _armory_fill_light.name="AuroraArmoryWeaponFill"
    _armory_fill_light.position=Vector3(-.42,1.50,1.72)
    _armory_fill_light.light_color=Color(1.0,.90,.77)
    _armory_fill_light.light_energy=1.28
    _armory_fill_light.omni_range=3.25
    _armory_fill_light.light_cull_mask=PORTRAIT_LIGHT_LAYER
    _armory_fill_light.shadow_enabled=false
    _armory_fill_light.visible=false
    stage3d.add_child(_armory_fill_light)
    # Imported metal receivers and scoped silhouettes disappeared against
    # the snow/ramp background in the 964x434 Godot capture, even after fill
    # lighting. A small matte, framed 3D inspection panel sits BEHIND the
    # real rifle geometry. It is lobby-only and never enters match scenes.
    _armory_inspection_backdrop=Node3D.new()
    _armory_inspection_backdrop.name="AuroraArmoryInspectionBackdrop"
    _armory_inspection_backdrop.position=Vector3(0.0,1.04,-.52)
    _armory_inspection_backdrop.visible=false
    stage3d.add_child(_armory_inspection_backdrop)
    var outer:=MeshInstance3D.new()
    outer.name="InspectionEdge"
    var edge_mesh:=QuadMesh.new()
    edge_mesh.size=Vector2(2.48,1.06)
    outer.mesh=edge_mesh
    var edge_finish:=StandardMaterial3D.new()
    edge_finish.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    edge_finish.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    edge_finish.albedo_color=Color(.20,.53,.62,.80)
    edge_finish.cull_mode=BaseMaterial3D.CULL_DISABLED
    outer.material_override=edge_finish
    outer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _armory_inspection_backdrop.add_child(outer)
    var inner:=MeshInstance3D.new()
    inner.name="InspectionMatte"
    var matte_mesh:=QuadMesh.new()
    matte_mesh.size=Vector2(2.43,1.01)
    inner.mesh=matte_mesh
    inner.position.z=.006
    var matte_finish:=StandardMaterial3D.new()
    matte_finish.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    matte_finish.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    matte_finish.albedo_color=Color(.085,.135,.19,.89)
    matte_finish.cull_mode=BaseMaterial3D.CULL_DISABLED
    inner.material_override=matte_finish
    _armory_matte_material=matte_finish
    inner.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _armory_inspection_backdrop.add_child(inner)
    var camera:=Camera3D.new()
    camera.name="LobbyPortraitCamera"
    # V75.109 CI screenshot showed the operator's head hidden behind the
    # top UI and feet over the bottom rail. A 54-degree vertical FOV fits
    # the 1.96m preview rig inside the usable mobile lobby band.
    camera.position=Vector3(-.10,1.18,3.58)
    camera.fov=54.0
    camera.current=true
    stage3d.add_child(camera)
    camera.look_at(Vector3(-.08,.81,0),Vector3.UP)
    var sentinel: Node3D=LOBBY_COMPANION.new()
    sentinel.name="AuroraSentinelCompanion"
    sentinel.position=Vector3(.83,-.09,-.68)
    sentinel.scale=Vector3.ONE*.65
    stage3d.add_child(sentinel)
    var podium:=MeshInstance3D.new()
    podium.name="PortraitPlatform"
    var disk:=CylinderMesh.new()
    disk.top_radius=.77
    disk.bottom_radius=.82
    disk.height=.074
    podium.mesh=disk
    podium.position.y=-.050
    podium.layers|=PORTRAIT_LIGHT_LAYER
    podium.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var metal:=StandardMaterial3D.new()
    metal.albedo_color=Color(.14,.185,.238)
    metal.metallic=.43
    metal.roughness=.58
    podium.material_override=metal
    stage3d.add_child(podium)
    # A second real machined metal tier gives the base visible thickness.
    var plinth:=MeshInstance3D.new()
    plinth.name="AuroraPortraitPodiumPlinth"
    var plinth_mesh:=CylinderMesh.new()
    plinth_mesh.top_radius=.81
    plinth_mesh.bottom_radius=.875
    plinth_mesh.height=.12
    plinth_mesh.radial_segments=48
    plinth.mesh=plinth_mesh
    plinth.position.y=-.135
    plinth.material_override=metal
    plinth.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    stage3d.add_child(plinth)

    # Reuse the same tiny 64px contact mask as the physical in-match
    # operator, not a blurred screenshot or a second shadow map.
    var contact: MeshInstance3D=preload(
        "res://scripts/player/aurora_operator_contact_shadow.gd").new()
    stage3d.add_child(contact)
    contact.name="AuroraLobbyBootsContact"
    contact.position.y=.005
    contact.call("set_physical_contact",true)
    # Original 3D podium illumination — the supplied reference has
    # concentric cyan/violet light, not a flat painted circle. These are
    # two tiny unshadowed static ring meshes, lobby-only and GPU-cheap.
    for ring_index in range(2):
        var ring:=MeshInstance3D.new()
        ring.name="AuroraPortraitPodiumRing"+str(ring_index)
        var torus:=TorusMesh.new()
        torus.inner_radius=.695 if ring_index==0 else .790
        torus.outer_radius=.725 if ring_index==0 else .816
        torus.rings=24
        torus.ring_segments=10
        ring.mesh=torus
        ring.position.y=.002 if ring_index==0 else -.031
        var glow:=StandardMaterial3D.new()
        glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
        glow.albedo_color=(Color(.09,.83,1.0) if ring_index==0
            else Color(.48,.33,.96))
        glow.emission_enabled=true
        glow.emission=glow.albedo_color
        glow.emission_energy_multiplier=2.1 if ring_index==0 else 1.35
        glow.roughness=.35
        ring.material_override=glow
        ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        stage3d.add_child(ring)

    if ResourceLoader.exists("res://assets/characters/lila_aurora.glb"):
        var source:=load("res://assets/characters/lila_aurora.glb") as PackedScene
        if source!=null:
            _preview_avatar=source.instantiate() as Node3D
            _preview_skin_applied=""
            _preview_avatar.name="LilaAuroraPreview"
            stage3d.add_child(_preview_avatar)
            _fit_avatar_for_preview(_preview_avatar)
            for node in _preview_avatar.find_children("*","MeshInstance3D",true,false):
                (node as MeshInstance3D).layers|=PORTRAIT_LIGHT_LAYER
            var anim:=_preview_avatar.find_child("AnimationPlayer",true,false) as AnimationPlayer
            # Lobby has no equipped hand-held rifle. Playing the armed grip
            # without a model made Lila's empty palms look glued together.
            # Use the real relaxed skeletal idle here; the actual match
            # keeps its weapon-ready and ADS animation states.
            if anim and anim.has_animation("AuroraIdle"):
                anim.get_animation("AuroraIdle").loop_mode=Animation.LOOP_LINEAR
                anim.play("AuroraIdle")
                anim.advance(.36)
                _install_lobby_motion(anim)

    var caption:=Label.new()
    caption.name="PreviewDisclosure"
    caption.text="LILA AURORA  /  OPERADORA"
    caption.anchor_left=.341
    caption.anchor_right=.548
    caption.anchor_top=.777
    caption.anchor_bottom=.847
    caption.offset_bottom=0
    caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    caption.add_theme_font_override("font",DISPLAY_FONT)
    caption.add_theme_font_size_override("font_size",18)
    caption.add_theme_color_override("font_color",Color(.75,.88,.97))
    caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
    caption.visible=false
    # No dedicated GESTO, arrows or VISTA controls. The character is
    # already rotated by a swipe and a tap opens the true in-engine emote.
    # Existing animation remains the only selectable action until more
    # authored, licensed emote clips are available.
    _surface.add_child(caption)
    _preview_caption=caption
    _emote_wheel=PanelContainer.new()
    _emote_wheel.name="AuroraCharacterEmoteWheel"
    _emote_wheel.anchor_left=.338
    _emote_wheel.anchor_right=.605
    _emote_wheel.anchor_top=.315
    _emote_wheel.anchor_bottom=.725
    _emote_wheel.mouse_filter=Control.MOUSE_FILTER_STOP
    var wheel_style:=StyleBoxFlat.new()
    wheel_style.bg_color=Color(.008,.020,.043,.93)
    wheel_style.border_color=Color(.27,.84,.94,.83)
    wheel_style.set_border_width_all(2)
    # Circular chooser, not a new permanent button over the operator.
    wheel_style.set_corner_radius_all(76)
    wheel_style.content_margin_left=14
    wheel_style.content_margin_right=14
    wheel_style.content_margin_top=9
    wheel_style.content_margin_bottom=9
    _emote_wheel.add_theme_stylebox_override("panel",wheel_style)
    _surface.add_child(_emote_wheel)
    var wheel_content:=VBoxContainer.new()
    wheel_content.add_theme_constant_override("separation",8)
    _emote_wheel.add_child(wheel_content)
    var heading:=Label.new()
    heading.name="EmoteHeading"
    heading.text="EMOTES"
    heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_override("font",DISPLAY_FONT)
    heading.add_theme_font_size_override("font_size",22)
    wheel_content.add_child(heading)
    var emote:=_button("MOVIMIENTO AURORA",
        Callable(self,"_play_selected_character_emote"),0)
    emote.name="AuroraAvailableCharacterEmote"
    emote.custom_minimum_size.y=42
    emote.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _style_primary_action(emote)
    wheel_content.add_child(emote)
    var close_emote:=_button("CERRAR",
        Callable(self,"_close_character_emotes"),0)
    close_emote.name="CloseCharacterEmotes"
    close_emote.custom_minimum_size.y=37
    close_emote.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _style_aurora_tab(close_emote,Color(.35,.75,.88))
    wheel_content.add_child(close_emote)
    _emote_wheel.hide()
    if MALE_PREVIEW.source_available():
        # Private-source male selector occupies the gap between rotate/frame
        # and gesture. It is absent from APKs without a checked male GLB.
        var male_button: Button=_button("CH02",
            Callable(self,"_toggle_mixamo_preview"),0)
        male_button.name="AuroraMalePreviewSelector"
        male_button.anchor_left=.472
        male_button.anchor_right=.542
        male_button.anchor_top=.673
        male_button.anchor_bottom=.752
        male_button.add_theme_font_size_override("font_size",16)
        male_button.tooltip_text="Vista previa del operador masculino. No habilita combate."
        male_button.accessibility_name=male_button.tooltip_text
        _style_aurora_tab(male_button,Color(.53,.77,.93))
        male_button.visible=false
        _surface.add_child(male_button)
        _operator_controls.append(male_button)


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
    # Small landscape canvases require room for the real 49px selector
    # and 65px INICIAR; keep both interactive controls inside the card.
    if stage=="lobby" and is_instance_valid(_play_match_card):
        var short_canvas: bool=safe.size.y<560.0
        _play_match_card.anchor_bottom=.710 if short_canvas else .580
        if _selected_tab=="JUGAR":
            _page.anchor_bottom=.687 if short_canvas else .562
            # Godot's VBox may inherit the wider minimum width of an
            # unrelated page child; keep the actual START action inside
            # the visible gold-bordered BR card at 964x434 and 1280x720.
            var available: float=maxf(165.0,minf(250.0,
                _play_match_card.size.x-38.0))
            # The OptionButton is a separate child of Page; constraining
            # only the INICIAR VBox left the selector wider than the gold
            # card on compact 964x434 Android landscape.
            if _match_mode_selector!=null and is_instance_valid(
                    _match_mode_selector):
                _match_mode_selector.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
                _match_mode_selector.custom_minimum_size.x=available
            if _lobby_play_modes!=null and is_instance_valid(
                    _lobby_play_modes):
                _lobby_play_modes.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
                _lobby_play_modes.custom_minimum_size.x=available
                for action in [_battle_entry,_training_entry]:
                    if is_instance_valid(action):
                        action.custom_minimum_size.x=0.0
                        action.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    # Adapt original LZ emblem to usable screen height: large desktop hero
    # but never clip the live progress/actions in 434px Motorola landscape.
    if _loading_emblem!=null and is_instance_valid(_loading_emblem):
        _loading_emblem.custom_minimum_size.y=clampf(
            safe.size.y*.16,69.0,122.0)
    if stage=="lobby" and _lobby_match_facts!=null and is_instance_valid(
            _lobby_match_facts):
        _lobby_match_facts.visible=false
    if stage=="lobby" and _lobby_compact_intel!=null and is_instance_valid(
            _lobby_compact_intel):
        _lobby_compact_intel.visible=false
    if stage=="welcome" and _entry_info_panel!=null and is_instance_valid(
            _entry_info_panel):
        _entry_info_panel.visible=_entry_should_show_briefing()
        var compact_entry: bool=minf(safe.size.y,
            float(get_window().size.y))<560.0
        for provider in [_login_google_button,_login_guest_button,_login_local_button]:
            provider.custom_minimum_size.y=72 if compact_entry else 54
        var overline: Control=_page.get_node_or_null(
            "AuroraEntryAccessOverline") as Control
        var diagnostics: Control=_page.get_node_or_null(
            "StartupDiagnosticEntry") as Control
        if overline!=null:
            overline.visible=not compact_entry
        if diagnostics!=null:
            diagnostics.visible=not compact_entry
    # V75.166: keep the operator/hangar rendered at native resolution
    # through 1280x720 on the normal profile. The previous hardcoded
    # 520k-pixel limit reduced the 3D image to 640x360, then magnified it,
    # producing blur in real 1280x720 GitHub capture evidence.
    # SubViewportContainer (stretch=true) owns SubViewport.size; changing
    # the child's size directly is unsafe and creates warning spam.
    # Only the 3D viewport is scaled; actual buttons/text stay native.
    if _preview_container!=null and is_instance_valid(_preview_container):
        var quality: String=RENDER_QUALITY.read_profile()
        var shrink: int=LOBBY_RESOLUTION.shrink_for_size(
            safe.size,quality)
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

