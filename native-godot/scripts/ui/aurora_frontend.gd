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
    _page.anchor_right=.93
    _page.anchor_top=.20
    _page.anchor_bottom=.94
    _page.add_theme_constant_override("separation",14)
    _surface.add_child(_page)
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


func _game_active() -> bool:
    return _game!=null and is_instance_valid(_game)
