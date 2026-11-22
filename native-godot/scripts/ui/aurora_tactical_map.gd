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
# At whole-island zoom, show only real district centres and outer POIs.
# Smaller landmarks become individually readable at zoom >= 1.75.
const OVERVIEW_LABEL_INDICES: Array[int]=[0,4,5,7,8,9,10]
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
var _touch_gesture_multitouch: bool=false
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
    _control_panel.anchor_top=.05
    _control_panel.anchor_bottom=.95
    _control_panel.add_theme_constant_override("separation",4)
    add_child(_control_panel)
    _action("✕",func(): visible=false)
    _action("ZOOM +",func(): _zoom_at(1.32))
    _action("ZOOM −",func(): _zoom_at(1.0/1.32))
    _action("SEGUIR",func(): _follow())
    _action("QUITAR MARCA",_clear_waypoint)
    _action("RUTA",_route)
    # "NORTE ARRIBA" duplicated SEGUIR: the Aurora map is already north-up.
    # Remove the redundant row to give the remaining buttons touch-safe height.


func _notification(what: int) -> void:
    if what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
        # Closing the tactical overlay can interrupt an active Android
        # gesture. Never carry stale touch IDs into the next map opening.
        _touches.clear()
        _touch_starts.clear()
        _drag_touch=-1
        _touch_gesture_multitouch=false


func _action(title: String,handler: Callable) -> void:
    var btn:=Button.new()
    btn.name="MapAction"+str(_control_panel.get_child_count())
    btn.text=title
    btn.focus_mode=Control.FOCUS_NONE
    btn.custom_minimum_size=Vector2(108,58)
    btn.add_theme_font_size_override("font_size",14)
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
    if _follow_player and is_instance_valid(player):
        pan=Vector2(player.global_position.x,player.global_position.z)
    _clamp_pan_to_terrain()
    queue_redraw()


func _process(dt: float) -> void:
    if not visible:
        return
    _redraw_seconds-=dt
    if _redraw_seconds<=0.0:
        _redraw_seconds=.20
        if _follow_player and is_instance_valid(player):
            pan=Vector2(player.global_position.x,player.global_position.z)
        _clamp_pan_to_terrain()
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


## At zoom 1 the entire physical island is visible, so the only valid pan
## centre is world origin. At zoom 8, the camera may follow a moving player,
## but never into repeated/off-island heightfield pixels.
func _clamp_pan_to_terrain() -> void:
    var visible_half: float=WORLD_HALF/maxf(1.0,zoom)
    var limit: float=maxf(0.0,WORLD_HALF-visible_half)
    pan=pan.clamp(Vector2.ONE*-limit,Vector2.ONE*limit)


func _zoom_at(factor: float) -> void:
    # The toolbar zooms around the cartographic centre. It preserves
    # SEGUIR mode, unlike an explicit exploratory touch/pinch gesture.
    zoom=clampf(zoom*factor,1.0,8.0)
    _clamp_pan_to_terrain()
    queue_redraw()


func _zoom_at_point(factor: float,screen_point: Vector2) -> void:
    # Preserve the world coordinate underneath the two fingers or mouse
    # pointer, avoiding the map jumping to a different district on zoom.
    var rect: Rect2=_map_rect()
    if not rect.has_point(screen_point) or not is_finite(factor) or factor<=0.0:
        return
    var grounded_anchor: Vector2=unproject(screen_point)
    zoom=clampf(zoom*factor,1.0,8.0)
    pan=grounded_anchor-(screen_point-rect.get_center())*_meters_per_pixel(rect)
    _follow_player=false
    # Clamp only if holding the anchor would expose off-island pixels.
    _clamp_pan_to_terrain()
    queue_redraw()


func _follow() -> void:
    _follow_player=true
    if is_instance_valid(player):
        pan=Vector2(player.global_position.x,player.global_position.z)
    _clamp_pan_to_terrain()
    queue_redraw()


func _route() -> void:
    if not is_instance_valid(player) or not waypoint.is_finite():
        return
    _follow_player=false
    pan=(Vector2(player.global_position.x,player.global_position.z)+waypoint)*.5
    var delta: float=Vector2(player.global_position.x,player.global_position.z).distance_to(waypoint)
    zoom=clampf((WORLD_HALF*2.0)/maxf(170.0,delta*1.5),1.0,8.0)
    _clamp_pan_to_terrain()
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
        if touch.pressed and not touch.canceled and rect.has_point(touch.position):
            if _touches.is_empty():
                _touch_gesture_multitouch=false
            _touches[touch.index]=touch.position
            _touch_starts[touch.index]=touch.position
            if _touches.size()>1:
                # Once a pinch has begun, neither finger may place a
                # waypoint merely by being lifted inside the map pane.
                _touch_gesture_multitouch=true
            _drag_touch=touch.index
            _last_pointer=touch.position
            accept_event()
        elif (not touch.pressed or touch.canceled) and _touches.has(touch.index):
            var start: Vector2=_touch_starts.get(touch.index,touch.position)
            var was_active: bool=_drag_touch==touch.index
            var can_place: bool=(was_active and not _touch_gesture_multitouch
                and _touches.size()==1 and not touch.canceled
                and rect.has_point(touch.position)
                and touch.position.distance_to(start)<12.0)
            _touches.erase(touch.index)
            _touch_starts.erase(touch.index)
            if was_active:
                _drag_touch=-1
            if _touches.is_empty():
                _touch_gesture_multitouch=false
            if can_place:
                mark(unproject(touch.position))
            accept_event()
    elif event is InputEventScreenDrag:
        var drag:=event as InputEventScreenDrag
        if _touches.has(drag.index):
            var previous: Vector2=_touches[drag.index]
            var old_positions: Array=_touches.values()
            var old_separation: float=0.0
            var previous_mid: Vector2=Vector2.ZERO
            if old_positions.size()==2:
                var old_a: Vector2=old_positions[0]
                var old_b: Vector2=old_positions[1]
                old_separation=old_a.distance_to(old_b)
                previous_mid=(old_a+old_b)*.5
            _touches[drag.index]=drag.position
            if _touches.size()==2:
                var fingers: Array=_touches.values()
                var first: Vector2=fingers[0]
                var second: Vector2=fingers[1]
                var separation: float=first.distance_to(second)
                # Translation follows the fingers, not the player. The
                # subsequent anchored zoom retains the point under the
                # midpoint of the pinch without dragging off the island.
                var current_mid: Vector2=(first+second)*.5
                pan-=(current_mid-previous_mid)*_meters_per_pixel(rect)
                _follow_player=false
                if separation>15.0 and old_separation>15.0:
                    var inset: Rect2=rect.grow(-1.0)
                    _zoom_at_point(separation/old_separation,
                        current_mid.clamp(inset.position,inset.end))
            else:
                pan-=drag.relative*_meters_per_pixel(rect)
                _follow_player=false
            _clamp_pan_to_terrain()
            _last_pointer=drag.position
            queue_redraw()
            accept_event()
    elif event is InputEventMouseButton:
        var mouse:=event as InputEventMouseButton
        # Release anywhere on the fullscreen tactical overlay, otherwise
        # a drag ending beside the map can keep panning after mouse-up.
        if mouse.button_index==MOUSE_BUTTON_LEFT and not mouse.pressed:
            if _drag_touch==0:
                if (rect.has_point(mouse.position) and
                        mouse.position.distance_to(_mouse_press_origin)<12.0):
                    mark(unproject(mouse.position))
                _drag_touch=-1
                accept_event()
        elif rect.has_point(mouse.position):
            if mouse.button_index==MOUSE_BUTTON_WHEEL_UP and mouse.pressed:
                _zoom_at_point(1.25,mouse.position)
                accept_event()
            elif mouse.button_index==MOUSE_BUTTON_WHEEL_DOWN and mouse.pressed:
                _zoom_at_point(.8,mouse.position)
                accept_event()
            elif mouse.button_index==MOUSE_BUTTON_LEFT and mouse.pressed:
                _drag_touch=0
                _mouse_press_origin=mouse.position
                _last_pointer=mouse.position
                accept_event()
    elif event is InputEventMouseMotion and _drag_touch==0:
        var motion:=event as InputEventMouseMotion
        pan-=motion.relative*_meters_per_pixel(rect)
        _follow_player=false
        _clamp_pan_to_terrain()
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



func _draw_clipped_dashed_map_line(from: Vector2,to: Vector2,
        rect: Rect2,tint: Color,width: float,dash: float) -> void:
    # Preserve the aircraft's dotted route even where it crosses a map edge.
    for section in _clipped_map_segments(PackedVector2Array([from,to]),rect):
        for i in range(section.size()-1):
            draw_dashed_line(section[i],section[i+1],tint,width,dash)


func _draw_path(world_points: Array[Vector2],tint: Color,width: float) -> void:
    var points:=PackedVector2Array()
    for at in world_points:
        points.append(project(at))
    _draw_clipped_map_line(points,_map_rect(),tint,width,true)


## Keep the original physical POI locations while preventing dozens of
## illegible names around the central town at minimum map zoom.
func _show_landmark_label(index: int) -> bool:
    return (index>=0 and index<LANDMARK_NAMES.size() and
        (zoom>=1.75 or index in OVERVIEW_LABEL_INDICES))


func _draw_landmark(at: Vector2,title: String,boxes: Array[Rect2],
        rect: Rect2,font: Font) -> void:
    var p: Vector2=project(at)
    if not rect.grow(-7.0).has_point(p):
        return
    draw_circle(p,5.0,Color(1,.86,.48))
    # Measure the actual glyph widths, not title.length(): Spanish
    # accented names and longer place names must avoid other real POIs.
    var label_width: float=ceilf(font.get_string_size(
        title,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x)+12.0
    var label_size:=Vector2(label_width,21)
    var offsets: Array[Vector2]=[
        Vector2(9,-24),Vector2(-label_width-9,-24),
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
        draw_string(font,candidate.position+Vector2(6,15),title,
            HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(.97,.95,.83))
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


## UI-safe touch instructions share the map pane with the physical
## scale bar. Nothing is printed over the gameplay buttons below the map.
## Keep the actual player and chosen waypoint navigable after pinch-pan.
## This is a pointer to their real off-screen world coordinates, NOT a
## replacement or relocated marker. No enemies are revealed by this helper.
func _edge_map_anchor(world_at: Vector2,safe_rect: Rect2) -> Dictionary:
    var pixel: Vector2=project(world_at)
    if not pixel.is_finite() or safe_rect.size.x<=20.0 or safe_rect.size.y<=20.0:
        return {}
    if safe_rect.has_point(pixel):
        return {"inside":true,"at":pixel,"direction":Vector2.ZERO}
    var inset: Rect2=safe_rect.grow(-7.0)
    var center: Vector2=inset.get_center()
    var delta: Vector2=pixel-center
    var fraction_x: float=INF
    var fraction_y: float=INF
    if absf(delta.x)>.0001:
        fraction_x=((inset.end.x if delta.x>0.0 else inset.position.x)
            -center.x)/delta.x
    if absf(delta.y)>.0001:
        fraction_y=((inset.end.y if delta.y>0.0 else inset.position.y)
            -center.y)/delta.y
    var fraction: float=minf(fraction_x,fraction_y)
    if not is_finite(fraction):
        return {}
    return {"inside":false,"at":center+delta*fraction,
        "direction":delta.normalized()}


func _draw_edge_map_marker(world_at: Vector2,safe_rect: Rect2,
        tint: Color,legend: String,font: Font) -> void:
    var marker: Dictionary=_edge_map_anchor(world_at,safe_rect)
    if marker.is_empty() or bool(marker["inside"]):
        return
    var at: Vector2=marker["at"]
    var direction: Vector2=marker["direction"]
    var tangent:=Vector2(-direction.y,direction.x)
    var triangle:=PackedVector2Array([
        at+direction*6.0,
        at-direction*7.0+tangent*5.5,
        at-direction*7.0-tangent*5.5])
    draw_colored_polygon(triangle,tint)
    # The label remains wholly in the cartography pane; the live world and
    # adjacent HUD controls must never receive an overhanging callout.
    var label_width: float=float(legend.length())*7.0+7.0
    var origin:=Vector2(
        clampf(at.x-direction.x*23.0-label_width*.5,
            safe_rect.position.x+4.0,safe_rect.end.x-label_width-4.0),
        clampf(at.y-direction.y*23.0+5.0,
            safe_rect.position.y+16.0,safe_rect.end.y-5.0))
    draw_rect(Rect2(origin-Vector2(3.0,12.0),
        Vector2(label_width+4.0,16.0)),Color(.018,.045,.072,.90))
    draw_string(font,origin,legend,HORIZONTAL_ALIGNMENT_LEFT,
        -1,12,tint)


func _map_footer_rect(rect: Rect2) -> Rect2:
    return Rect2(
        Vector2(rect.position.x+96.0,rect.end.y-25.0),
        Vector2(maxf(28.0,rect.size.x-109.0),19.0))


## The AWM icon is real inventory information, not a permanently
## painted image. Once the player collects the actual weapon Area3D, the
## map must stop promising another gun at that spot.
func _live_awm_pickup() -> Area3D:
    if (not is_instance_valid(director) or
            str(director.get("mode"))!="sector_battle" or
            bool(director.get("match_ended"))):
        return null
    var pickup: Area3D=director.get_node_or_null(
        "AuroraAWMWeaponPickup") as Area3D
    if (not is_instance_valid(pickup) or pickup.collected or
            pickup.is_queued_for_deletion() or
            pickup.pickup_type!="weapon_awm"):
        return null
    return pickup


## Tactical scans never expose all supplies island-wide. A compact
## 65-metre budget shows only currently existing, collectible physics.
func _live_world_resources() -> Array[Dictionary]:
    if (not is_instance_valid(player) or not is_instance_valid(director) or
            player.royale_eliminated):
        return []
    return director.nearby_world_pickups(
        Vector2(player.global_position.x,player.global_position.z),65.0,8)


## The full tactical map only plots the same finite real grenade
## projectiles as the circular minimap. The map does not expose enemies.
func _live_active_grenades() -> Array:
    if (not is_instance_valid(player) or player.royale_eliminated or
            not is_instance_valid(director) or
            str(director.get("mode"))!="sector_battle" or
            bool(director.get("match_ended"))):
        return []
    var battle: Node3D=director.get("combat") as Node3D
    if battle==null:
        return []
    return battle.call("nearby_live_grenade_hazards",
        Vector2(player.global_position.x,player.global_position.z),32.0,3)


func _live_vehicles() -> Array[Vector2]:
    if (not is_instance_valid(player) or not is_instance_valid(director) or
            player.royale_eliminated):
        return []
    return director.nearby_real_vehicles(
        Vector2(player.global_position.x,player.global_position.z),95.0,2)


func _live_local_cache_markers() -> Array[Vector2]:
    if not is_instance_valid(player) or not is_instance_valid(director):
        return []
    return director.nearby_opponent_supply_points(
        Vector2(player.global_position.x,player.global_position.z),70.0,6)


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
    # Prioritise the real AWM loot marker before district labels: otherwise
    # nearby names cover its pickup position and hide the last-mile target.
    # Reserve its occupied area so collision-aware POI labels move aside.
    var occupied: Array[Rect2]=[]
    var live_awm: Area3D=_live_awm_pickup()
    if live_awm!=null:
        var actual_weapon:=Vector2(
            live_awm.global_position.x,live_awm.global_position.z)
        var sniper: Vector2=project(actual_weapon)
        if rect.grow(-12).has_point(sniper):
            draw_circle(sniper,9.0,Color(1,.61,.09))
            draw_arc(sniper,13,0,TAU,32,Color(1,.85,.22),2.0)
            occupied.append(Rect2(sniper-Vector2(13,13),Vector2(26,26)))
            var name_rect:=Rect2(sniper+Vector2(13,1),Vector2(57,18))
            if rect.grow(-8).encloses(name_rect):
                draw_rect(name_rect,Color(.23,.105,.02,.94))
                draw_string(font,name_rect.position+Vector2(6,14),"AWM",
                    HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(1,.95,.75))
                occupied.append(name_rect)
    # Genuine nearby pickups are listed with their original world locations.
    # No decorative inventory or third-party map art is rendered.
    var nearby_supplies: Array[Dictionary]=_live_world_resources()
    for item in nearby_supplies:
        var pixel: Vector2=project(item["at"] as Vector2)
        if not rect.grow(-11).has_point(pixel):
            continue
        var kind: String=str(item["kind"])
        var tint: Color=(Color(.98,.43,.46) if kind in ["medkit","syringe"]
            else Color(.41,.81,1.0) if kind.begins_with("vest") or
            kind.begins_with("helmet") or kind.begins_with("backpack")
            else Color(1.0,.82,.35))
        draw_circle(pixel,5.0,tint)
        draw_arc(pixel,7.0,0,TAU,18,Color(.02,.11,.14,.94),1.1)
    # Temporary red hazard markers follow actual fuse-burning projectiles.
    # They are clipped to the cartography pane, never drawn over HUD buttons.
    for hazard in _live_active_grenades():
        var pixel: Vector2=project(hazard["at"] as Vector2)
        if rect.grow(-11).has_point(pixel):
            draw_circle(pixel,7.0,Color(.95,.22,.12,.92))
            draw_arc(pixel,10.0,0,TAU,24,Color(1.0,.74,.34),1.8)
            draw_string(font,pixel+Vector2(-2.5,4.0),"!",
                HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(1.0,.99,.87))
    # Cars are displayed only when their actual original source, four
    # physics wheels and mesh have been instantiated in the match.
    for vehicle_at in _live_vehicles():
        var pixel: Vector2=project(vehicle_at)
        if rect.grow(-13).has_point(pixel):
            draw_rect(Rect2(pixel-Vector2(6,4),Vector2(12,8)),
                Color(.08,.22,.28,.95),true)
            draw_rect(Rect2(pixel-Vector2(6,4),Vector2(12,8)),
                Color(.63,.93,1.0),false,1.5)
    # A compact square means physical, recoverable enemy supply within
    # 70 metres of the player; do not plot every unobserved kill on the island.
    # Maximum six icons is bounded for the 49-opponent mobile roster.
    for cache_at in _live_local_cache_markers():
        var cache_pixel: Vector2=project(cache_at)
        if rect.grow(-12).has_point(cache_pixel):
            var bounds:=Rect2(cache_pixel-Vector2(5,5),Vector2(10,10))
            draw_rect(bounds,Color(.04,.19,.23,.94),true)
            draw_rect(bounds,Color(.62,.97,.72),false,1.5)
            draw_line(cache_pixel+Vector2(-2,0),
                cache_pixel+Vector2(2,0),Color(.91,1,.86),1.2)
    # All real houses remain on the 256px terrain texture. Additional POI
    # names appear only after pinch/zoom, not all piled on the city centre.
    for i in range(LANDMARK_POSITIONS.size()):
        if _show_landmark_label(i):
            _draw_landmark(LANDMARK_POSITIONS[i],LANDMARK_NAMES[i],
                occupied,rect,font)
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
            _draw_clipped_dashed_map_line(start,end,rect,
                Color(1.0,.81,.34),3.0,8.0)
            if is_instance_valid(player):
                var plane_pos: Vector3=player.global_position
                var plane_dot: Vector2=project(Vector2(plane_pos.x,plane_pos.z))
                if rect.grow(-9.0).has_point(plane_dot):
                    draw_circle(plane_dot,8.0,Color(1,.84,.19))
    if is_instance_valid(player):
        var player_world:=Vector2(
            player.global_position.x,player.global_position.z)
        var p: Vector2=project(player_world)
        # A manual map pan must not make the player's reference vanish.
        # Draw a real-position edge arrow only when off-screen.
        var safe_rect: Rect2=rect.grow(-14.0)
        if safe_rect.has_point(p):
            draw_circle(p,7.5,Color(.96,.99,1))
            draw_arc(p,11,0,TAU,30,Color(.06,.87,.98),2.0)
        else:
            _draw_edge_map_marker(player_world,safe_rect,
                Color(.43,.96,1.0),"JUGADOR",font)
        if waypoint.is_finite():
            var target: Vector2=project(waypoint)
            _draw_clipped_map_line(PackedVector2Array([p,target]),
                rect,Color(1,.76,.22,.8),2.0)
            var meters: int=roundi(player_world.distance_to(waypoint))
            if safe_rect.has_point(target):
                draw_circle(target,8.0,Color(1,.62,.13))
                var label: String=str(meters)+" m"
                var width: float=float(label.length())*9.0
                var label_x: float=clampf(target.x+10.0,
                    rect.position.x+8.0,rect.end.x-width-7.0)
                var label_y: float=clampf(target.y,
                    rect.position.y+16.0,rect.end.y-7.0)
                draw_string(font,Vector2(label_x,label_y),label,
                    HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(1.0,.86,.48))
            else:
                _draw_edge_map_marker(waypoint,safe_rect,
                    Color(1.0,.82,.30),"MARCA %d m"%meters,font)
    draw_rect(rect,Color(.38,.83,.94),false,2.0)
    if is_instance_valid(director) and (
            str(director.get("mode"))=="sector_battle" and
            not bool(director.get("match_ended"))):
        # Label the exact same ring values used to apply storm damage.
        # Compact fixed-size legend is confined to the map's top-right.
        var legend_pos: Vector2=Vector2(rect.end.x-162.0,rect.position.y+7.0)
        draw_rect(Rect2(legend_pos,Vector2(155,40)),
            Color(.013,.064,.105,.84))
        var current_radius: float=float(director.get("radius"))
        var display_radius: String=("%.2f"%current_radius
            if current_radius<2.0 else "%d"%roundi(current_radius))
        draw_string(font,legend_pos+Vector2(8,15),
            "ACTUAL %s m"%display_radius,
            HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(.49,.96,1))
        var planned: Dictionary=director.call("next_zone_preview")
        if bool(planned.get("active",false)):
            var planned_radius: float=float(planned["radius"])
            var planned_text: String=("%.2f"%planned_radius
                if planned_radius<2.0 else "%d"%roundi(planned_radius))
            draw_string(font,legend_pos+Vector2(8,32),
                "SIGUIENTE %s m"%planned_text,
                HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(1,.83,.46))
        else:
            draw_string(font,legend_pos+Vector2(8,32),
                "CIERRE FINAL",
                HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(1,.83,.46))
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
    # The old instructions at 97% viewport height overlapped mobile HUD
    # hints below the map. Keep guidance INSIDE the map's lower border,
    # to the right of the (independently drawn) actual 100 m scale bar.
    var help_rect: Rect2=_map_footer_rect(rect)
    draw_rect(help_rect,Color(.012,.037,.057,.88))
    draw_string(font,help_rect.position+Vector2(7.0,14.0),
        "TOCA MARCA · ARRASTRA · PELLIZCA",
        HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(.83,.95,.98))
