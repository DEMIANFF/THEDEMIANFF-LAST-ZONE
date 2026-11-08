extends Control
## Original Aurora front-end. Free Fire is UX reference ONLY; no copied layout,
## assets or proprietary game branding. Incomplete service tabs say so.
const GAME = preload("res://scenes/Main.tscn")

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


func _ready() -> void:
    name = "AuroraFront"
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
    _surface.add_child(bg)
    var line:=ColorRect.new()
    line.name="AuroraBlueAccent"
    line.anchor_left=.045
    line.anchor_right=.955
    line.anchor_top=.18
    line.anchor_bottom=.18
    line.offset_bottom=3
    line.color=Color(.12,.73,.92)
    line.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _surface.add_child(line)
    _page=VBoxContainer.new()
    _page.name="Page"
    _page.anchor_left=.07
    _page.anchor_right=.63
    _page.anchor_top=.20
    _page.anchor_bottom=.94
    _page.add_theme_constant_override("separation",14)
    _surface.add_child(_page)
    _build_preview()
    _welcome()


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


func _button(value: String, callback: Callable, width: float=260.0) -> Button:
    var button:=Button.new()
    button.text=value
    button.custom_minimum_size=Vector2(width,54)
    button.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
    button.focus_mode=Control.FOCUS_NONE
    button.add_theme_font_size_override("font_size",18)
    var style:=StyleBoxFlat.new()
    style.bg_color=Color(.075,.23,.37,.96)
    style.border_color=Color(.36,.80,.98)
    style.set_border_width_all(2)
    style.set_corner_radius_all(12)
    var pressed:=style.duplicate() as StyleBoxFlat
    pressed.bg_color=Color(.17,.44,.56)
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
    _clear_page()
    _label("THEDEMIANFF   /   LAST ZONE",33)
    _label("AURORA  •  EL ÚLTIMO HORIZONTE",20)
    _label("Operación de supervivencia — edición de desarrollo",16)
    var enter:=_button("ENTRAR",Callable(self,"_show_lobby"))
    enter.name="EnterButton"
    _page.add_child(enter)
    _label("Esta versión prueba partidas offline. El multijugador y las cuentas en Godot todavía no están disponibles.",14)


func _show_lobby() -> void:
    stage="lobby"
    visible=true
    if _preview_container:
        _preview_container.visible=true
    if _preview_caption:
        _preview_caption.visible=true
    _clear_page()
    _label("AURORA / CENTRO DE OPERACIONES",29)
    _label("Modo: entrenamiento o combate de sector (9 participantes simulados)",17)
    var actions:=HBoxContainer.new()
    actions.name="PlayModes"
    actions.add_theme_constant_override("separation",16)
    _page.add_child(actions)
    var training:=_button("ENTRENAMIENTO",Callable(self,"_launch").bind(false),246)
    training.name="TrainingButton"
    actions.add_child(training)
    var battle:=_button("BATTLE ROYALE · SECTOR",Callable(self,"_launch").bind(true),335)
    battle.name="BattleButton"
    actions.add_child(battle)

    var tabs:=HBoxContainer.new()
    tabs.name="LobbyTabs"
    tabs.add_theme_constant_override("separation",8)
    _page.add_child(tabs)
    for tab in ["PERSONAJE","ARMAS","MISIONES","TIENDA","CUENTA"]:
        var tab_name: String=tab
        var b:=_button(tab_name,Callable(self,"_select_tab").bind(tab_name),155)
        b.name="Tab"+tab_name
        b.custom_minimum_size=Vector2(135,46)
        tabs.add_child(b)
    _info=_label("",18)
    _select_tab(_selected_tab)
    _label("Progreso e inventario de la antigua V70 NO se transfieren a esta demostración.",14)


func _select_tab(tab: String) -> void:
    _selected_tab=tab
    if stage!="lobby" or _info==null:
        return
    match tab:
        "PERSONAJE":
            _info.text="OPERADORA  /  LILA EN DESARROLLO\nModelo de entrenamiento provisional. Rig facial, cabello y equipamiento final pendientes."
        "ARMAS":
            _info.text="ARSENAL  /  AK-74 + AWM\nAR: x2/x4. AWM: x8, cinco cartuchos y cerrojo automático de 0,5 s."
        "MISIONES":
            _info.text="MISIONES  /  PRÓXIMA ETAPA\nLas recompensas y objetivos persistentes aún no están implementados."
        "TIENDA":
            _info.text="TIENDA  /  NO DISPONIBLE\nSin compras ni moneda simulada. Integración futura."
        "CUENTA":
            _info.text="CUENTA  /  SIN CONEXIÓN\nGoogle, invitado y Firebase de la versión principal no están integrados en este cliente."
        _:
            _info.text="SECCIÓN NO DISPONIBLE"


func _launch(battle: bool) -> void:
    if stage!="lobby":
        return
    stage="loading"
    _clear_page()
    _label("PREPARANDO PUERTO AURORA",27)
    _label("Cargando terreno, colisiones, personaje, armas y patrullas...",18)
    call_deferred("_activate_game",battle)


func _activate_game(battle: bool) -> void:
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
    _preview_container.anchor_left=.655
    _preview_container.anchor_right=.96
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
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
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
    camera.look_at(Vector3(0,.88,0),Vector3.UP)
    camera.current=true
    stage3d.add_child(camera)
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
    caption.anchor_left=.65
    caption.anchor_right=.99
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
