extends Control
## Original Puerto Aurora tactical cartography, built from the SAME physical
## terrain heightfield as gameplay. It never uses another game's map textures.
## Map: drag/pinch/zoom, waypoint, player, safe zone, aircraft route, POIs.
signal waypoint_changed(world_point: Vector2)
const FLIGHT=preload("res://scripts/match/airdrop_sequence.gd")
const WORLD_HALF: float=225.0
const ZONE_CENTER: Vector2=Vector2(0,-24)
const POINTS: Array[Vector2]=[
    Vector2(18,-8),Vector2(-19,-29),Vector2(46,-36),Vector2(-48,22),
    Vector2(-4,42),Vector2(19,43),Vector2(43,41),Vector2(62,28),
    Vector2(-22,66),Vector2(26,68),Vector2(-55,60),Vector2(68,48)]
const NAMES: Array[String]=[
    "CENTRO","HELIOS","METEO","VORTEX",
    "COSTA OESTE","PLAZA","MIRADOR","ESTE",
    "FAROS","NORTE","MUELLE","COLINA"]
const SAVE_PATH: String="user://aurora_map_waypoint.cfg"
const AWM_POSITION: Vector2=Vector2(8,24)
const MAP_SAMPLES: int=160
const LANDMARK_POSITIONS: Array[Vector2]=[
    Vector2(18,-8),Vector2(-19,-29),Vector2(46,-36),
    Vector2(-48,22),Vector2(5,53),Vector2(-54,56),
    Vector2(64,43)]
const LANDMARK_NAMES: Array[String]=[
    "CENTRO","HELIOS","METEO","VORTEX",
    "PUERTO AURORA","MUELLE","MIRADOR"]
var player: CharacterBody3D
var terrain: StaticBody3D
var director: Node3D
var waypoint: Vector2=Vector2(INF,INF)
var zoom: float=1.0
var pan: Vector2=Vector2.ZERO
var _drag_touch: int=-1
var _last_pointer: Vector2
var _touches: Dictionary={}
var _touch_starts: Dictionary={}
var _mouse_press_origin: Vector2=Vector2.ZERO
var _redraw_seconds: float=0.0
var _follow_player: bool=true
var _control_panel: VBoxContainer
var _terrain_texture: ImageTexture


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
    _terrain_texture=null
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
    var delta: float=Vector2(player.global_position.x,player.global_position.z).distance_to(waypoint)
    zoom=clampf(450.0/maxf(170.0,delta*1.5),1.0,4.0)
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
            _touch_starts[touch.index]=touch.position
            _drag_touch=touch.index
            _last_pointer=touch.position
            accept_event()
        elif not touch.pressed and _touches.has(touch.index):
            var start: Vector2=_touch_starts.get(touch.index,touch.position)
            _touches.erase(touch.index)
            _touch_starts.erase(touch.index)
            if _drag_touch==touch.index:
                _drag_touch=-1
                if rect.has_point(touch.position) and touch.position.distance_to(start)<12.0:
                    mark(unproject(touch.position))
            accept_event()
    elif event is InputEventScreenDrag:
        var drag:=event as InputEventScreenDrag
        if _touches.has(drag.index):
            var previous: Vector2=_touches[drag.index]
            var old_positions: Array=_touches.values()
            var old_separation: float=0.0
            if old_positions.size()==2:
                var old_a: Vector2=old_positions[0]
                var old_b: Vector2=old_positions[1]
                old_separation=old_a.distance_to(old_b)
            _touches[drag.index]=drag.position
            if _touches.size()==2:
                var fingers: Array=_touches.values()
                var first: Vector2=fingers[0]
                var second: Vector2=fingers[1]
                var separation: float=first.distance_to(second)
                if separation>15.0 and old_separation>15.0:
                    zoom=clampf(zoom*separation/old_separation,1.0,4.0)
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
                _mouse_press_origin=mouse.position
                _last_pointer=mouse.position
                accept_event()
            elif mouse.button_index==MOUSE_BUTTON_LEFT and not mouse.pressed:
                if mouse.position.distance_to(_mouse_press_origin)<12.0:
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


func _ensure_terrain_texture() -> void:
    if _terrain_texture!=null or not is_instance_valid(terrain):
        return
    # A cached, real 160x160 heightfield replaces the old 35x35 blocks.
    # Sampling occurs only once per loaded island, not every HUD frame.
    var image:=Image.create(MAP_SAMPLES,MAP_SAMPLES,false,Image.FORMAT_RGBA8)
    var sea: float=float(terrain.get("sea_level"))
    for z in range(MAP_SAMPLES):
        for x in range(MAP_SAMPLES):
            var world_x: float=-WORLD_HALF+(float(x)+.5)*450.0/MAP_SAMPLES
            var world_z: float=-WORLD_HALF+(float(z)+.5)*450.0/MAP_SAMPLES
            var h: float=float(terrain.call("height_at",world_x,world_z))
            var color: Color=Color(.025,.16,.26)
            if h>sea+.3:
                color=Color(.20,.34,.28).lerp(Color(.47,.43,.32),
                    clampf((h-8.0)/44.0,0.0,1.0))
                if h<sea+3.0:
                    color=color.lerp(Color(.73,.65,.46),
                        clampf(1.0-(h-sea)/3.0,0.0,1.0))
                if h>35.0:
                    color=color.lerp(Color(.72,.78,.78),
                        clampf((h-35.0)/28.0,0.0,1.0))
            elif h>sea-1.0:
                color=Color(.10,.44,.51)
            image.set_pixel(x,z,color)
    _terrain_texture=ImageTexture.create_from_image(image)


func _draw_path(world_points: Array[Vector2],tint: Color,width: float) -> void:
    var points:=PackedVector2Array()
    for at in world_points:
        points.append(project(at))
    if points.size()>=2:
        draw_polyline(points,Color(.017,.10,.14,.85),width+3.0,true)
        draw_polyline(points,tint,width,true)


func _draw_landmark(at: Vector2,title: String,boxes: Array[Rect2],
        rect: Rect2,font: Font) -> void:
    var p: Vector2=project(at)
    if not rect.grow(-7.0).has_point(p):
        return
    draw_circle(p,5.0,Color(1,.86,.48))
    var label_width: float=float(title.length())*7.0+9.0
    var label_size:=Vector2(label_width,18)
    var offsets: Array[Vector2]=[
        Vector2(9,-21),Vector2(-label_width-9,-21),
        Vector2(9,3),Vector2(-label_width-9,3)]
    for displacement in offsets:
        var candidate:=Rect2(p+displacement,label_size)
        if not rect.grow(-5.0).encloses(candidate):
            continue
        var collision: bool=false
        for occupied in boxes:
            if occupied.grow(4).intersects(candidate):
                collision=true
                break
        if collision:
            continue
        draw_rect(candidate,Color(.016,.067,.094,.87))
        draw_string(font,candidate.position+Vector2(5,14),title,
            HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(.97,.95,.83))
        boxes.append(candidate)
        return


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO,size),Color(.012,.033,.067,.975))
    var rect: Rect2=_map_rect()
    draw_rect(rect,Color(.025,.14,.24),true)
    _ensure_terrain_texture()
    if _terrain_texture!=null:
        var src_span: float=float(MAP_SAMPLES)/zoom
        var src_origin: Vector2=Vector2(
            (pan.x+WORLD_HALF)*MAP_SAMPLES/450.0-src_span*.5,
            (pan.y+WORLD_HALF)*MAP_SAMPLES/450.0-src_span*.5)
        draw_texture_rect_region(_terrain_texture,rect,
            Rect2(src_origin,Vector2.ONE*src_span))
    # The roads connect real named districts, not fictional map screenshots.
    _draw_path([Vector2(-48,22),Vector2(-26,2),Vector2(4,4),
        Vector2(26,20),Vector2(48,41),Vector2(68,48)],
        Color(.76,.66,.44,.8),5.0)
    _draw_path([Vector2(-55,60),Vector2(-22,66),Vector2(5,50),
        Vector2(19,43),Vector2(43,41),Vector2(68,48)],
        Color(.73,.69,.49,.80),4.0)
    _draw_path([Vector2(4,4),Vector2(18,-8),
        Vector2(46,-36),Vector2(53,-61)],
        Color(.71,.60,.43,.70),3.0)
    for n in range(-4,5):
        var grid_x: float=float(n)*50.0
        var a:=project(Vector2(grid_x,-WORLD_HALF))
        var b:=project(Vector2(grid_x,WORLD_HALF))
        draw_line(a,b,Color(.75,.85,.91,.10),1)
        var c:=project(Vector2(-WORLD_HALF,grid_x))
        var d:=project(Vector2(WORLD_HALF,grid_x))
        draw_line(c,d,Color(.75,.85,.91,.10),1)
    var font: Font=get_theme_default_font()
    for point in POINTS:
        var parcel: Vector2=project(point)
        if rect.grow(-8).has_point(parcel):
            draw_rect(Rect2(parcel-Vector2(3,3),Vector2(6,6)),
                Color(.94,.92,.72))
    # Labels are laid out against occupied bounding boxes. Clustered
    # houses stay represented as footprints instead of unreadable names.
    var occupied: Array[Rect2]=[]
    for i in range(LANDMARK_POSITIONS.size()):
        _draw_landmark(LANDMARK_POSITIONS[i],LANDMARK_NAMES[i],
            occupied,rect,font)
    # This is the actual AWM area in sector_director.gd, not a fake icon.
    var sniper: Vector2=project(AWM_POSITION)
    if rect.grow(-12).has_point(sniper):
        draw_circle(sniper,9.0,Color(1,.61,.09))
        draw_arc(sniper,13,0,TAU,32,Color(1,.85,.22),2.0)
        var name_rect:=Rect2(sniper+Vector2(13,1),Vector2(57,18))
        if rect.grow(-8).encloses(name_rect):
            draw_rect(name_rect,Color(.23,.105,.02,.94))
            draw_string(font,name_rect.position+Vector2(6,14),"AWM",
                HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(1,.95,.75))
    if is_instance_valid(director):
        var center: Vector2=ZONE_CENTER
        var rad: float=float(director.get("radius"))/_meters_per_pixel(rect)
        draw_arc(project(center),rad,0,TAU,120,Color(.35,.95,1.0,.92),3.0,true)
        var flight: Node3D=director.get("_flight") as Node3D
        if flight!=null and str(flight.get("phase"))=="aircraft":
            var start:=project(Vector2(0,FLIGHT.ROUTE_START_Z))
            var end:=project(Vector2(0,FLIGHT.ROUTE_END_Z))
            draw_dashed_line(start,end,Color(1.0,.81,.34),3.0,8.0)
            var plane_pos: Vector3=player.global_position
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
