extends Control
## Original Puerto Aurora tactical cartography, built from the SAME physical
## terrain heightfield as gameplay. It never uses another game's map textures.
## Map: drag/pinch/zoom, waypoint, player, safe zone, aircraft route, POIs.
signal waypoint_changed(world_point: Vector2)
const FLIGHT=preload("res://scripts/match/airdrop_sequence.gd")
const TERRAIN_SCALE=preload("res://scripts/world/island_terrain.gd")
const RESIDENTIAL=preload("res://scripts/world/coastal_residential_layout.gd")
const WORLD_HALF: float=TERRAIN_SCALE.HALF_EXTENT
const ZONE_CENTER: Vector2=Vector2(0,-24)
const POINTS: Array[Vector2]=[
    Vector2(18,-8),Vector2(-19,-29),Vector2(46,-36),Vector2(-48,22),
    Vector2(-4,42),Vector2(19,43),Vector2(43,41),Vector2(62,28),
    Vector2(-22,66),Vector2(26,68),Vector2(-55,60),Vector2(68,48),
    Vector2(197,23),Vector2(-15,-198),Vector2(-194,65),Vector2(5,208)]
const NAMES: Array[String]=[
    "CENTRO","HELIOS","METEO","VORTEX",
    "COSTA OESTE","PLAZA","MIRADOR","ESTE",
    "FAROS","NORTE","MUELLE","COLINA",
    "FRONTERA ESTE","SUR HELADO","VALLE OESTE","PASO NORTE"]
const SAVE_PATH: String="user://aurora_map_waypoint.cfg"
const AWM_POSITION: Vector2=Vector2(8,24)
const MAP_SAMPLES: int=256
const LANDMARK_POSITIONS: Array[Vector2]=[
    Vector2(18,-8),Vector2(-19,-29),Vector2(46,-36),
    Vector2(-48,22),Vector2(5,53),Vector2(-54,56),
    Vector2(64,43),Vector2(197,23),Vector2(-15,-198),
    Vector2(-194,65),Vector2(5,208)]
const LANDMARK_NAMES: Array[String]=[
    "CENTRO","HELIOS","METEO","VORTEX",
    "PUERTO AURORA","MUELLE","MIRADOR",
    "SIERRA ESTE","SUR HELADO","VALLE OESTE","PASO NORTE"]
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
    # Keep gameplay visible on the left, as in the supplied BR references.
    # Compact action column remains touch-safe on 964x434 Motorola screens.
    _control_panel.anchor_left=.78
    _control_panel.anchor_right=.985
    _control_panel.anchor_top=.10
    _control_panel.anchor_bottom=.90
    _control_panel.add_theme_constant_override("separation",4)
    add_child(_control_panel)
    _action("✕",func(): visible=false)
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
    btn.custom_minimum_size=Vector2(108,36)
    btn.add_theme_font_size_override("font_size",12)
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
    return Rect2(Vector2(size.x*.255,size.y*.065),
        Vector2(minf(size.x*.505,height*1.16),height))


func _meters_per_pixel(rect: Rect2) -> float:
    return (WORLD_HALF*2.0)/(rect.size.x*zoom)


func project(world: Vector2) -> Vector2:
    var rect: Rect2=_map_rect()
    return rect.get_center()+(world-pan)/_meters_per_pixel(rect)


func unproject(screen_point: Vector2) -> Vector2:
    var rect: Rect2=_map_rect()
    return pan+(screen_point-rect.get_center())*_meters_per_pixel(rect)


func _zoom_at(factor: float) -> void:
    zoom=clampf(zoom*factor,1.0,8.0)
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
    zoom=clampf((WORLD_HALF*2.0)/maxf(170.0,delta*1.5),1.0,8.0)
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
                    zoom=clampf(zoom*separation/old_separation,1.0,8.0)
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


func _terrain_pixel(at: Vector2) -> Vector2:
    return (at+Vector2.ONE*WORLD_HALF)*float(MAP_SAMPLES)/(WORLD_HALF*2.0)


func _paint_road(image: Image,heights: PackedFloat32Array,
        points: Array[Vector2],sea: float) -> void:
    # The original navigable-sector connections are painted ONCE into the
    # shared heightfield image: they also appear in the small minimap.
    # No 3D geometry, collision or new per-frame allocations.
    for segment in range(points.size()-1):
        var first: Vector2=_terrain_pixel(points[segment])
        var last: Vector2=_terrain_pixel(points[segment+1])
        var steps: int=maxi(1,ceili(first.distance_to(last)*1.5))
        for n in range(steps+1):
            var p: Vector2=first.lerp(last,float(n)/float(steps))
            for dz in range(-2,3):
                for dx in range(-2,3):
                    var px: int=roundi(p.x)+dx
                    var pz: int=roundi(p.y)+dz
                    if px<0 or pz<0 or px>=MAP_SAMPLES or pz>=MAP_SAMPLES:
                        continue
                    if heights[pz*MAP_SAMPLES+px]<=sea+.75:
                        continue
                    var edge: bool=abs(dx)==2 or abs(dz)==2
                    image.set_pixel(px,pz,Color(.19,.24,.25) if edge else
                        Color(.81,.74,.56))


func _paint_house(image: Image,heights: PackedFloat32Array,
        center: Vector2,span: Vector2,sea: float) -> void:
    # Use actual house footprint coordinates, not fictional copied icons.
    var point: Vector2=_terrain_pixel(center)
    var half_width: int=maxi(2,roundi(span.x*MAP_SAMPLES/(WORLD_HALF*4.0)))
    var half_depth: int=maxi(2,roundi(span.y*MAP_SAMPLES/(WORLD_HALF*4.0)))
    for dz in range(-half_depth-1,half_depth+2):
        for dx in range(-half_width-1,half_width+2):
            var px: int=roundi(point.x)+dx
            var pz: int=roundi(point.y)+dz
            if px<0 or pz<0 or px>=MAP_SAMPLES or pz>=MAP_SAMPLES:
                continue
            if heights[pz*MAP_SAMPLES+px]<=sea+.30:
                continue
            var edge: bool=abs(dx)>half_width or abs(dz)>half_depth
            image.set_pixel(px,pz,Color(.09,.16,.19) if edge else
                Color(.79,.84,.81))


func _ensure_terrain_texture() -> void:
    if _terrain_texture!=null or not is_instance_valid(terrain):
        return
    # The cache is generated once per terrain on the CPU. Two-pass relief,
    # 8m contour bands, beaches, navigable roads and the REAL house footprints
    # replace the old bare circle/160px map. Never recompute during gameplay.
    var heights:=PackedFloat32Array()
    heights.resize(MAP_SAMPLES*MAP_SAMPLES)
    var sea: float=float(terrain.get("sea_level"))
    for z in range(MAP_SAMPLES):
        for x in range(MAP_SAMPLES):
            var wx: float=-WORLD_HALF+(float(x)+.5)*WORLD_HALF*2.0/MAP_SAMPLES
            var wz: float=-WORLD_HALF+(float(z)+.5)*WORLD_HALF*2.0/MAP_SAMPLES
            heights[z*MAP_SAMPLES+x]=float(terrain.call("height_at",wx,wz))
    var image:=Image.create(MAP_SAMPLES,MAP_SAMPLES,false,Image.FORMAT_RGBA8)
    for z in range(MAP_SAMPLES):
        for x in range(MAP_SAMPLES):
            var index: int=z*MAP_SAMPLES+x
            var h: float=heights[index]
            var color: Color=Color(.035,.17,.24)
            if h<=sea+.15:
                color=Color(.025,.12,.20).lerp(Color(.12,.39,.46),
                    clampf((h-(sea-7.0))/8.0,0.0,1.0))
            elif h<sea+3.5:
                color=Color(.67,.65,.48).lerp(Color(.37,.51,.42),
                    clampf((h-sea)/3.5,0.0,1.0))
            elif h<28.0:
                color=Color(.29,.47,.39).lerp(Color(.24,.33,.38),
                    clampf((h-8.0)/30.0,0.0,1.0))
            else:
                color=Color(.40,.48,.53).lerp(Color(.83,.89,.90),
                    clampf((h-28.0)/25.0,0.0,1.0))
            if h>sea+.4:
                var west: float=heights[z*MAP_SAMPLES+maxi(0,x-1)]
                var east: float=heights[z*MAP_SAMPLES+mini(MAP_SAMPLES-1,x+1)]
                var north: float=heights[maxi(0,z-1)*MAP_SAMPLES+x]
                var south: float=heights[mini(MAP_SAMPLES-1,z+1)*MAP_SAMPLES+x]
                var light: float=clampf((west-east+north-south)*.055,-.19,.19)
                color=(color.lightened(light) if light>=0.0 else
                    color.darkened(-light))
                if floori(h/8.0)!=floori(west/8.0) or floori(h/8.0)!=floori(north/8.0):
                    color=color.darkened(.20)
            image.set_pixel(x,z,color)
    _paint_road(image,heights,[Vector2(-48,22),Vector2(-26,2),
        Vector2(4,4),Vector2(26,20),Vector2(48,41),Vector2(68,48)],sea)
    _paint_road(image,heights,[Vector2(-55,60),Vector2(-22,66),
        Vector2(5,50),Vector2(19,43),Vector2(43,41),Vector2(68,48)],sea)
    _paint_road(image,heights,[Vector2(4,4),Vector2(18,-8),
        Vector2(46,-36),Vector2(53,-61)],sea)
    for i in range(RESIDENTIAL.SITES.size()):
        var site: Vector4=RESIDENTIAL.SITES[i]
        _paint_house(image,heights,Vector2(site.x,site.y),
            Vector2(site.z,site.w),sea)
    for historic in TERRAIN_SCALE.LEGACY_LOTS:
        _paint_house(image,heights,Vector2(historic.x,historic.y),
            Vector2(historic.z,historic.w),sea)
    _terrain_texture=ImageTexture.create_from_image(image)

## Every overlay feature is clipped to the cartography pane. The live world
## remains visible outside it, so roads/grid/rings must never paint over HUD.
func _map_clip_polygon(rect: Rect2) -> PackedVector2Array:
    return PackedVector2Array([
        rect.position,Vector2(rect.end.x,rect.position.y),
        rect.end,Vector2(rect.position.x,rect.end.y)])


func _clipped_map_segments(points: PackedVector2Array,
        rect: Rect2) -> Array[PackedVector2Array]:
    if points.size()<2 or rect.size.x<=4.0 or rect.size.y<=4.0:
        return []
    return Geometry2D.intersect_polyline_with_polygon(
        points,_map_clip_polygon(rect.grow(-2.0)))


func _draw_clipped_map_line(points: PackedVector2Array,rect: Rect2,
        tint: Color,width: float,outline: bool=false) -> void:
    for section in _clipped_map_segments(points,rect):
        if section.size()<2:
            continue
        if outline:
            draw_polyline(section,Color(.017,.10,.14,.85),
                width+3.0,true)
        draw_polyline(section,tint,width,true)


func _draw_path(world_points: Array[Vector2],tint: Color,width: float) -> void:
    var points:=PackedVector2Array()
    for at in world_points:
        points.append(project(at))
    _draw_clipped_map_line(points,_map_rect(),tint,width,true)


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



## A tactical ring can be larger than the map pane or move off its edges.
## Clip its actual world-space circle to the map rectangle, never drawing
## cyan/gold storm arcs over the live match or action buttons beside the pane.
func _draw_clipped_zone_outline(world_center: Vector2,world_radius: float,
        rect: Rect2,tint: Color,line_width: float) -> void:
    if not world_center.is_finite() or not is_finite(world_radius) or world_radius<=0.0:
        return
    var pixel_radius: float=world_radius/_meters_per_pixel(rect)
    var origin: Vector2=project(world_center)
    var segments: int=clampi(ceili(pixel_radius*.75),96,256)
    var ring:=PackedVector2Array()
    for step in range(segments+1):
        var angle: float=TAU*float(step)/float(segments)
        ring.append(origin+Vector2.from_angle(angle)*pixel_radius)
    _draw_clipped_map_line(ring,rect,tint,line_width)


func _draw() -> void:
    # See-through overlay: player can still see the live match behind it.
    draw_rect(Rect2(Vector2.ZERO,size),Color(.012,.033,.067,.60))
    var rect: Rect2=_map_rect()
    draw_rect(rect,Color(.025,.14,.24),true)
    _ensure_terrain_texture()
    if _terrain_texture!=null:
        var src_span: float=float(MAP_SAMPLES)/zoom
        var src_origin: Vector2=Vector2(
            (pan.x+WORLD_HALF)*MAP_SAMPLES/(WORLD_HALF*2.0)-src_span*.5,
            (pan.y+WORLD_HALF)*MAP_SAMPLES/(WORLD_HALF*2.0)-src_span*.5)
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
        _draw_clipped_map_line(PackedVector2Array([a,b]),rect,
            Color(.75,.85,.91,.10),1.0)
        var c:=project(Vector2(-WORLD_HALF,grid_x))
        var d:=project(Vector2(WORLD_HALF,grid_x))
        _draw_clipped_map_line(PackedVector2Array([c,d]),rect,
            Color(.75,.85,.91,.10),1.0)
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
        # Both overlays track the same zone director driving physical damage.
        # Gold is the NEXT destination; cyan is the current contracting ring.
        if str(director.get("mode"))=="sector_battle" and not bool(
                director.get("match_ended")):
            var current_center: Vector2=director.get("zone_center") as Vector2
            var current_radius: float=float(director.get("radius"))
            _draw_clipped_zone_outline(current_center,current_radius,rect,
                Color(.35,.95,1.0,.97),3.0)
            var preview: Dictionary=director.call("next_zone_preview")
            if bool(preview.get("active",false)):
                _draw_clipped_zone_outline(preview["center"],
                    float(preview["radius"]),rect,Color(1.0,.78,.32,.87),2.0)
        var flight: Node3D=director.get("_flight") as Node3D
        if flight!=null and str(flight.get("phase"))=="aircraft":
            var start:=project(Vector2(0,FLIGHT.ROUTE_START_Z))
            var end:=project(Vector2(0,FLIGHT.ROUTE_END_Z))
            _draw_clipped_map_line(PackedVector2Array([start,end]),
                rect,Color(1.0,.81,.34),2.0)
            var plane_pos: Vector3=player.global_position
            draw_circle(project(Vector2(plane_pos.x,plane_pos.z)),8.0,Color(1,.84,.19))
    if is_instance_valid(player):
        var p:=project(Vector2(player.global_position.x,player.global_position.z))
        draw_circle(p,7.5,Color(.96,.99,1))
        draw_arc(p,11,0,TAU,30,Color(.06,.87,.98),2.0)
        if waypoint.is_finite():
            var target:=project(waypoint)
            _draw_clipped_map_line(PackedVector2Array([p,target]),
                rect,Color(1,.76,.22,.8),2.0)
            draw_circle(target,8.0,Color(1,.62,.13))
            var meters: int=roundi(Vector2(player.global_position.x,
                player.global_position.z).distance_to(waypoint))
            draw_string(font,target+Vector2(10,0),str(meters)+" m",
                HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(1.0,.86,.48))
    draw_rect(rect,Color(.38,.83,.94),false,2.0)
    # Chart orientation and scale remain grounded in the real island metres.
    var scale_m: float=100.0
    var max_scale_width: float=maxf(14.0,rect.size.x-30.0)
    # Prevent the scale bar from extending into the HUD at 8x map zoom.
    while scale_m/_meters_per_pixel(rect)>max_scale_width:
        scale_m*=.5
    var scale_pixels: float=scale_m/_meters_per_pixel(rect)
    var bottom: Vector2=Vector2(rect.position.x+14,rect.end.y-15)
    draw_line(bottom,bottom+Vector2(scale_pixels,0),Color(.96,.95,.77),2.0)
    draw_line(bottom+Vector2(0,-4),bottom+Vector2(0,4),Color(.96,.95,.77),2.0)
    draw_line(bottom+Vector2(scale_pixels,-4),
        bottom+Vector2(scale_pixels,4),Color(.96,.95,.77),2.0)
    draw_string(font,bottom+Vector2(3,-6),"%d m"%roundi(scale_m),
        HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(.96,.95,.77))
    draw_string(font,rect.position+Vector2(12,19),"N ↑",
        HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(.94,.98,1.0))
    draw_string(font,Vector2(size.x*.26,size.y*.05),
        "PUERTO AURORA  /  MAPA TÁCTICO",
        HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color(.94,.97,1))
    draw_string(font,Vector2(size.x*.30,size.y*.97),
        "TOCA PARA MARCAR · ARRASTRA · PELLIZCA PARA AMPLIAR",
        HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(.75,.92,.98))
