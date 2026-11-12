extends Control
## Original Puerto Aurora tactical cartography, built from the SAME physical
## terrain heightfield as gameplay. It never uses another game's map textures.
## Map: drag/pinch/zoom, waypoint, player, safe zone, aircraft route, POIs.
signal waypoint_changed(world_point: Vector2)
const FLIGHT=preload("res://scripts/match/airdrop_sequence.gd")
const WORLD_HALF: float=225.0
const POINTS: Array[Vector2]=[
    Vector2(18,-8),Vector2(-19,-29),Vector2(46,-36),Vector2(-48,22),
    Vector2(-4,42),Vector2(19,43),Vector2(43,41),Vector2(62,28),
    Vector2(-22,66),Vector2(26,68),Vector2(-55,60),Vector2(68,48)]
const NAMES: Array[String]=[
    "CENTRO","HELIOS","METEO","VORTEX",
    "COSTA OESTE","PLAZA","MIRADOR","ESTE",
    "FAROS","NORTE","MUELLE","COLINA"]
const SAVE_PATH: String="user://aurora_map_waypoint.cfg"
var player: CharacterBody3D
var terrain: StaticBody3D
var director: Node3D
var waypoint: Vector2=Vector2(INF,INF)
var zoom: float=1.0
var pan: Vector2=Vector2.ZERO
var _drag_touch: int=-1
var _last_pointer: Vector2
var _touches: Dictionary={}
var _redraw_seconds: float=0.0
var _follow_player: bool=true
var _control_panel: VBoxContainer


func _ready() -> void:
    name="AuroraFullTacticalMap"
    mouse_filter=Control.MOUSE_FILTER_STOP
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var saved:=ConfigFile.new()
    if saved.load(SAVE_PATH)==OK:
        var x: float=float(saved.get_value("waypoint","x",INF))
        var z: float=float(saved.get_value("waypoint","z",INF))
        if is_finite(x) and is_finite(z) and absf(x)<=WORLD_HALF and absf(z)<=WORLD_HALF:
            waypoint=Vector2(x,z)
    _control_panel=VBoxContainer.new()
    _control_panel.name="MapActions"
    _control_panel.anchor_left=.81
    _control_panel.anchor_right=.99
    _control_panel.anchor_top=.09
    _control_panel.anchor_bottom=.90
    _control_panel.add_theme_constant_override("separation",7)
    add_child(_control_panel)
    _action("CERRAR MAPA",func(): visible=false)
    _action("ZOOM +",func(): _zoom_at(1.32))
    _action("ZOOM −",func(): _zoom_at(1.0/1.32))
    _action("SEGUIR",func(): _follow())
    _action("QUITAR MARCA",_clear_waypoint)
    _action("RUTA",_route)
    _action("NORTE ARRIBA",func(): _follow())


func _action(title: String,handler: Callable) -> void:
    var btn:=Button.new()
    btn.name="MapAction"+str(_control_panel.get_child_count())
    btn.text=title
    btn.focus_mode=Control.FOCUS_NONE
    btn.custom_minimum_size=Vector2(124,52)
    btn.add_theme_font_size_override("font_size",15)
    var style:=StyleBoxFlat.new()
    style.bg_color=Color(.016,.094,.146,.96)
    style.border_color=Color(.27,.84,.92)
    style.set_border_width_all(2)
    style.set_corner_radius_all(7)
    btn.add_theme_stylebox_override("normal",style)
    _control_panel.add_child(btn)
    btn.pressed.connect(handler)


func set_sources(character: CharacterBody3D,world: StaticBody3D,match_director: Node3D) -> void:
    player=character
    terrain=world
    director=match_director
    if _follow_player and player:
        pan=Vector2(player.global_position.x,player.global_position.z)
    queue_redraw()


func _process(dt: float) -> void:
    if not visible:
        return
    _redraw_seconds-=dt
    if _redraw_seconds<=0.0:
        _redraw_seconds=.20
        if _follow_player and is_instance_valid(player):
            pan=Vector2(player.global_position.x,player.global_position.z)
        queue_redraw()


func _map_rect() -> Rect2:
    var height: float=size.y*.88
    return Rect2(Vector2(size.x*.06,size.y*.055),
        Vector2(minf(size.x*.73,height),height))


func _meters_per_pixel(rect: Rect2) -> float:
    return (WORLD_HALF*2.0)/(rect.size.x*zoom)


func project(world: Vector2) -> Vector2:
    var rect: Rect2=_map_rect()
    return rect.get_center()+(world-pan)/_meters_per_pixel(rect)


func unproject(screen_point: Vector2) -> Vector2:
    var rect: Rect2=_map_rect()
    return pan+(screen_point-rect.get_center())*_meters_per_pixel(rect)


func _zoom_at(factor: float) -> void:
    zoom=clampf(zoom*factor,1.0,4.0)
    queue_redraw()


func _follow() -> void:
    _follow_player=true
    if is_instance_valid(player):
        pan=Vector2(player.global_position.x,player.global_position.z)
    queue_redraw()


func _route() -> void:
    if not is_instance_valid(player) or not waypoint.is_finite():
        return
    _follow_player=false
    pan=(Vector2(player.global_position.x,player.global_position.z)+waypoint)*.5
    zoom=clampf(zoom,1.0,2.0)
    queue_redraw()


func mark(at: Vector2) -> void:
    if not at.is_finite():
        return
    waypoint=at.clamp(Vector2.ONE*-WORLD_HALF,Vector2.ONE*WORLD_HALF)
    var cfg:=ConfigFile.new()
    cfg.set_value("waypoint","x",waypoint.x)
    cfg.set_value("waypoint","z",waypoint.y)
    cfg.save(SAVE_PATH)
    waypoint_changed.emit(waypoint)
    queue_redraw()


func _clear_waypoint() -> void:
    waypoint=Vector2(INF,INF)
    DirAccess.remove_absolute(SAVE_PATH)
    waypoint_changed.emit(waypoint)
    queue_redraw()


func _gui_input(event: InputEvent) -> void:
    var rect: Rect2=_map_rect()
    if event is InputEventScreenTouch:
        var touch:=event as InputEventScreenTouch
        if touch.pressed and rect.has_point(touch.position):
            _touches[touch.index]=touch.position
            _drag_touch=touch.index
            _last_pointer=touch.position
            accept_event()
        elif not touch.pressed and _touches.has(touch.index):
            _touches.erase(touch.index)
            if _drag_touch==touch.index:
                _drag_touch=-1
                if rect.has_point(touch.position) and touch.position.distance_to(_last_pointer)<12.0:
                    mark(unproject(touch.position))
            accept_event()
    elif event is InputEventScreenDrag:
        var drag:=event as InputEventScreenDrag
        if _touches.has(drag.index):
            var previous: Vector2=_touches[drag.index]
            _touches[drag.index]=drag.position
            if _touches.size()==2:
                var fingers: Array=_touches.values()
                var separation: float=(fingers[0] as Vector2).distance_to(fingers[1])
                if separation>15.0:
                    zoom=clampf(zoom*(1.0+drag.relative.length()*.003*signf(
                        separation-(previous as Vector2).distance_to(fingers[0]))),1.0,4.0)
            else:
                pan-=drag.relative*_meters_per_pixel(rect)
                _follow_player=false
            _last_pointer=drag.position
            queue_redraw()
            accept_event()
    elif event is InputEventMouseButton:
        var mouse:=event as InputEventMouseButton
        if rect.has_point(mouse.position):
            if mouse.button_index==MOUSE_BUTTON_WHEEL_UP and mouse.pressed:
                _zoom_at(1.25)
                accept_event()
            elif mouse.button_index==MOUSE_BUTTON_WHEEL_DOWN and mouse.pressed:
                _zoom_at(.8)
                accept_event()
            elif mouse.button_index==MOUSE_BUTTON_LEFT and mouse.pressed:
                _drag_touch=0
                _last_pointer=mouse.position
                accept_event()
            elif mouse.button_index==MOUSE_BUTTON_LEFT and not mouse.pressed:
                if mouse.position.distance_to(_last_pointer)<12.0:
                    mark(unproject(mouse.position))
                _drag_touch=-1
                accept_event()
    elif event is InputEventMouseMotion and _drag_touch==0:
        var motion:=event as InputEventMouseMotion
        pan-=motion.relative*_meters_per_pixel(rect)
        _follow_player=false
        _last_pointer=motion.position
        queue_redraw()
        accept_event()


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO,size),Color(.012,.033,.067,.975))
    var rect: Rect2=_map_rect()
    draw_rect(rect,Color(.025,.14,.24),true)
    if is_instance_valid(terrain):
        var tiles: int=35
        var pixel: float=rect.size.x/float(tiles)
        for row in range(tiles):
            for column in range(tiles):
                var pos: Vector2=rect.position+Vector2(column+.5,row+.5)*pixel
                var world: Vector2=unproject(pos)
                var y: float=terrain.height_at(world.x,world.y)
                var tone: Color=Color(.035,.20,.30)
                if y>terrain.sea_level+1.0:
                    tone=Color(.19,.32,.28).lerp(Color(.47,.43,.34),
                        clampf((y-4.0)/45.0,0.0,1.0))
                if y>32:
                    tone=tone.lerp(Color(.68,.74,.75),clampf((y-32)/24.0,0.0,1.0))
                draw_rect(Rect2(rect.position+Vector2(column,row)*pixel,
                    Vector2(pixel+.4,pixel+.4)),tone)
    for n in range(-4,5):
        var grid_x: float=float(n)*50.0
        var a:=project(Vector2(grid_x,-WORLD_HALF))
        var b:=project(Vector2(grid_x,WORLD_HALF))
        draw_line(a,b,Color(.75,.85,.91,.10),1)
        var c:=project(Vector2(-WORLD_HALF,grid_x))
        var d:=project(Vector2(WORLD_HALF,grid_x))
        draw_line(c,d,Color(.75,.85,.91,.10),1)
    var font: Font=get_theme_default_font()
    for i in range(POINTS.size()):
        var at:=project(POINTS[i])
        if rect.grow(-10).has_point(at):
            draw_circle(at,4.7,Color(1.0,.83,.44))
            draw_string(font,at+Vector2(7,-7),NAMES[i],
                HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(.97,.94,.77))
    if is_instance_valid(director):
        var center: Vector2=director.CENTER
        var rad: float=float(director.radius)/_meters_per_pixel(rect)
        draw_arc(project(center),rad,0,TAU,120,Color(.35,.95,1.0,.92),3.0,true)
        var flight: Node3D=director.get("_flight") as Node3D
        if flight!=null and str(flight.get("phase"))=="aircraft":
            var start:=project(Vector2(0,FLIGHT.ROUTE_START_Z))
            var end:=project(Vector2(0,FLIGHT.ROUTE_END_Z))
            draw_dashed_line(start,end,Color(1.0,.81,.34),3.0,8.0)
            var plane_pos: Vector3=flight.player.global_position
            draw_circle(project(Vector2(plane_pos.x,plane_pos.z)),8.0,Color(1,.84,.19))
    if is_instance_valid(player):
        var p:=project(Vector2(player.global_position.x,player.global_position.z))
        draw_circle(p,7.5,Color(.96,.99,1))
        draw_arc(p,11,0,TAU,30,Color(.06,.87,.98),2.0)
        if waypoint.is_finite():
            var target:=project(waypoint)
            draw_line(p,target,Color(1,.76,.22,.8),2)
            draw_circle(target,8.0,Color(1,.62,.13))
            var meters: int=roundi(Vector2(player.global_position.x,
                player.global_position.z).distance_to(waypoint))
            draw_string(font,target+Vector2(10,0),str(meters)+" m",
                HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(1.0,.86,.48))
    draw_rect(rect,Color(.38,.83,.94),false,2.0)
    draw_string(font,Vector2(size.x*.06,size.y*.04),
        "PUERTO AURORA  /  MAPA TÁCTICO ORIGINAL",
        HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color(.94,.97,1))
    draw_string(font,Vector2(size.x*.82,size.y*.94),
        "TOCA PARA MARCAR · ARRASTRA · AMPLÍA",
        HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(.75,.92,.98))
