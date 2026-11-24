extends Control
const TERRAIN_SCALE=preload("res://scripts/world/island_terrain.gd")
const AIRDROP=preload("res://scripts/match/airdrop_sequence.gd")
## Training: real opponent positions. Battle Royale: NO omniscient opponent
## positions; only short-lived acoustic pings from actual enemy gunshots.
## All current/future storm circles continue using authoritative zone geometry.

var player: CharacterBody3D
var opponents: Array[CharacterBody3D]=[]
var _tick: float=0.0
var _zone_enabled: bool=false
var _zone_world_center: Vector2=Vector2.ZERO
var _zone_radius: float=90.0
var _next_zone_enabled: bool=false
var _next_zone_center: Vector2=Vector2.ZERO
var _next_zone_radius: float=90.0
var rotate_with_camera: bool=true
# Reuse the actual terrain-derived cartography of the full tactical map.
var map_texture: Texture2D
var _zone_label: Label
var _waypoint: Vector2=Vector2(INF,INF)
const GUNFIRE_HEARING_RANGE: float=42.0
const GUNFIRE_PING_SECONDS: float=3.0
const GUNFIRE_MERGE_DISTANCE: float=6.0
const MAX_GUNFIRE_PINGS: int=8
const MAP_DISC_SIDES: int=64
# Player may recover nearby physical death crates; unlike enemy contacts
# these are existing world items, not wallhack positions of living bots.
const MAX_MINIMAP_CACHES: int=4
const MINIMAP_CACHE_RANGE: float=50.0
var _sector_director: Node3D
var _battle_mode: bool=false
var _gunfire_pings: Array[Dictionary]=[]
# Radar is anchored to the physical operator, not the widening zone ring.
# Cached pose allows responsive navigation while idle frames stay cheap.
const GROUND_DETAIL_METRES: float=80.0
const CANOPY_DETAIL_METRES: float=110.0
const AIRCRAFT_DETAIL_METRES: float=145.0
var _last_radar_position: Vector2=Vector2(INF,INF)
var _last_radar_yaw: float=INF


func _ready() -> void:
    name="AuroraTrainingRadar"
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    # The first 245m safe-zone ring used to bleed out of the minimap and
    # cover adjacent HUD controls. Clip ALL map content to its actual hitbox.
    clip_contents=true
    var heading:=Label.new()
    heading.text="PUERTO AURORA"
    heading.position=Vector2(8,3)
    # Phone-sized radar: avoid a clipped single 200px line over the map.
    heading.custom_minimum_size=Vector2(142,25)
    heading.add_theme_font_size_override("font_size",10)
    heading.add_theme_color_override("font_color",Color(.79,.95,.96))
    heading.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(heading)
    _zone_label=heading
    queue_redraw()


func set_sources(player_character: CharacterBody3D, enemies: Array[CharacterBody3D]) -> void:
    player=player_character
    opponents=enemies.duplicate()
    queue_redraw()


func set_sector_director(match_director: Node3D) -> void:
    _sector_director=match_director
    queue_redraw()


## Query only currently live Area3D pickups from the sector director.
## On match end or return to training, this must be empty even if a stale
## CanvasItem still exists for a frame.
func _nearby_supply_markers() -> Array[Vector2]:
    if (not _battle_mode or not is_instance_valid(player) or
            not is_instance_valid(_sector_director) or
            player.royale_eliminated):
        return []
    return _sector_director.nearby_opponent_supply_points(
        Vector2(player.global_position.x,player.global_position.z),
        MINIMAP_CACHE_RANGE,MAX_MINIMAP_CACHES)


## Read only nearby, uncollected real-world resources. Never invent cars
## when optional original Toyota/BMW model assets are not installed.
func nearby_physical_resources() -> Array[Dictionary]:
    if (not _battle_mode or not is_instance_valid(player) or
            not is_instance_valid(_sector_director) or
            player.royale_eliminated):
        return []
    return _sector_director.nearby_world_pickups(
        Vector2(player.global_position.x,player.global_position.z),48.0,5)


## The local radar displays only actual sealed 3D caches still on the
## ground and no cache locations after opening or when out of battle.
func nearby_sealed_lockers() -> Array[Vector2]:
    if (not _battle_mode or not is_instance_valid(player) or
            not is_instance_valid(_sector_director) or
            player.royale_eliminated):
        return []
    return _sector_director.nearby_unopened_supply_lockers(
        Vector2(player.global_position.x,player.global_position.z),48.0)


func nearby_physical_vehicles() -> Array[Vector2]:
    if (not _battle_mode or not is_instance_valid(player) or
            not is_instance_valid(_sector_director) or
            player.royale_eliminated):
        return []
    return _sector_director.nearby_real_vehicles(
        Vector2(player.global_position.x,player.global_position.z),65.0,2)


## At most three REAL physics projectiles, visible only in an active BR
## and only inside 32 m of the player. Same data source as the large map.
func nearby_live_grenade_hazards() -> Array:
    if (not _battle_mode or not is_instance_valid(player) or
            player.royale_eliminated or not is_instance_valid(_sector_director)
            or str(_sector_director.get("mode"))!="sector_battle" or
            bool(_sector_director.get("match_ended"))):
        return []
    var battle: Node3D=_sector_director.get("combat") as Node3D
    if battle==null:
        return []
    return battle.call("nearby_live_grenade_hazards",
        Vector2(player.global_position.x,player.global_position.z),32.0,3)


func set_battle_mode(enabled: bool) -> void:
    _battle_mode=enabled
    clear_gunfire()
    if not enabled:
        # Training and a newly entered lobby must not inherit the previous
        # match's last circle or its obsolete future-circle marker.
        _zone_enabled=false
        _next_zone_enabled=false
    _refresh_zone_label()
    queue_redraw()


func clear_gunfire() -> void:
    _gunfire_pings.clear()
    queue_redraw()


func note_enemy_gunfire(at: Vector3) -> void:
    # A 3D muzzle event is not a line-of-sight target lock or perfect radar.
    # Ignore silent rivals, dead players and remote firefights beyond hearing.
    if (not _battle_mode or not at.is_finite() or
            not is_instance_valid(player) or player.royale_eliminated):
        return
    var position: Vector2=Vector2(at.x,at.z)
    var listener: Vector2=Vector2(player.global_position.x,player.global_position.z)
    if position.distance_squared_to(listener)>GUNFIRE_HEARING_RANGE*GUNFIRE_HEARING_RANGE:
        return
    for i in range(_gunfire_pings.size()):
        var prior: Vector2=_gunfire_pings[i]["position"]
        if prior.distance_squared_to(position)<GUNFIRE_MERGE_DISTANCE*GUNFIRE_MERGE_DISTANCE:
            # A new shot refreshes its last-known sound location; the ping
            # does not follow the bot when it moves in silence.
            _gunfire_pings[i]={"position":position,"remaining":GUNFIRE_PING_SECONDS}
            queue_redraw()
            return
    if _gunfire_pings.size()>=MAX_GUNFIRE_PINGS:
        _gunfire_pings.pop_front()
    _gunfire_pings.append({"position":position,"remaining":GUNFIRE_PING_SECONDS})
    queue_redraw()


func set_waypoint(at: Vector2) -> void:
    _waypoint=at
    queue_redraw()


## Single real target reading, shared by the radar and the mobile HUD.
## Direction is relative to the actual player camera yaw, not the bot AI,
## a fabricated landing site, or an independent full-map coordinate space.
func landing_waypoint_guidance() -> Dictionary:
    if (not _battle_mode or not _waypoint.is_finite() or
            not is_instance_valid(player) or player.royale_eliminated or
            not is_instance_valid(_sector_director) or
            bool(_sector_director.get("match_ended"))):
        return {}
    var listener:=Vector2(player.global_position.x,player.global_position.z)
    var delta: Vector2=_waypoint-listener
    var distance: float=delta.length()
    var camera_degrees: float=rad_to_deg(float(player.get("_yaw")))
    var world_bearing: float=rad_to_deg(atan2(delta.x,-delta.y))
    # Godot +Y camera yaw turns its forward -Z toward WEST. A destination
    # world-bearing east (+90) is directly ahead when camera yaw is -90.
    return {
        "world":_waypoint,
        "distance_m":distance,
        "relative_degrees":wrapf(world_bearing+camera_degrees,-180.0,180.0)
    }


func set_zone(center: Vector2,radius: float) -> void:
    _zone_enabled=true
    _zone_world_center=center
    _zone_radius=maxf(.35,radius)
    _refresh_zone_label()
    queue_redraw()


func set_next_zone(center: Vector2,radius: float) -> void:
    _next_zone_enabled=true
    _next_zone_center=center
    _next_zone_radius=maxf(.35,radius)
    _refresh_zone_label()
    queue_redraw()


func clear_next_zone() -> void:
    _next_zone_enabled=false
    # No fifth circle exists after the last scheduled phase. Keep the
    # disabled internal snapshot coherent with the actual damage circle;
    # do not retain an obsolete 3m/12m target from the preceding phase.
    _next_zone_center=_zone_world_center
    _next_zone_radius=_zone_radius
    _refresh_zone_label()
    queue_redraw()



## The overtime radius genuinely shrinks below one metre. Preserve the
## precision of that final hazard instead of labeling 0.75 m as 1 m.
func _format_zone_radius(radius: float) -> String:
    if radius<2.0:
        return "%.2f"%radius
    return "%d"%roundi(radius)


func _refresh_zone_label() -> void:
    if not is_instance_valid(_zone_label):
        return
    var caption: String="PUERTO AURORA"
    if _zone_enabled:
        caption="ZONA %s m"%_format_zone_radius(_zone_radius)
        if _next_zone_enabled:
            # Use two readable rows instead of overflowing the 156px radar.
            caption+="\nPRÓX %s m"%_format_zone_radius(_next_zone_radius)
    if _zone_label.text!=caption:
        _zone_label.text=caption


## Legacy whole-ring coverage diagnostic for the full overview; the
## navigable combat radar has its OWN stable local detail range so the
## actual map does not shrink when a distant safe zone is 245 m wide.
func _world_range() -> float:
    if not _zone_enabled or not is_instance_valid(player):
        return 60.0
    var at: Vector2=Vector2(player.global_position.x,player.global_position.z)
    var farthest: float=_zone_radius+at.distance_to(_zone_world_center)
    if _next_zone_enabled:
        farthest=maxf(farthest,_next_zone_radius+
            at.distance_to(_next_zone_center))
    return maxf(60.0,farthest*1.10)


func ring_coverage() -> Dictionary:
    # Diagnostics: values under 1 fit entirely inside the circular radar.
    var world_range: float=_world_range()
    if not _zone_enabled or not is_instance_valid(player):
        return {"current":0.0,"next":0.0}
    var at: Vector2=Vector2(player.global_position.x,player.global_position.z)
    return {"current":(_zone_radius+at.distance_to(
        _zone_world_center))/world_range,
        "next":((_next_zone_radius+at.distance_to(_next_zone_center))/
            world_range if _next_zone_enabled else 0.0)}



## Exact world-to-texture pixel projection shared by camera-up radar and
## rotating view. The source is Aurora's physical heightfield, never a
## screenshot or a manually moved second map.
## A local navigation scale must not fluctuate from 80 to 350 metres
## when a remote ring changes size. The full tactical map remains the
## authoritative whole-island overview; this is the player-centred radar.
func _detail_range() -> float:
    if not is_instance_valid(player):
        return GROUND_DETAIL_METRES
    match str(player.get("air_mode")):
        "aircraft", "freefall":
            return AIRCRAFT_DETAIL_METRES
        "parachute":
            return CANOPY_DETAIL_METRES
    return GROUND_DETAIL_METRES


func _radar_center() -> Vector2:
    return size*.5


func _radar_radius() -> float:
    return minf(size.x*.45,size.y*.43)


func _radar_yaw() -> float:
    if not is_instance_valid(player) or not rotate_with_camera:
        return 0.0
    return float(player.get("_yaw"))


## Godot's positive yaw turns the forward (-Z) camera to world WEST.
## To keep camera-forward at screen TOP, world X/Z deltas must rotate by
## +yaw, NOT -yaw. One transform serves the terrain, compass and loot.
func _world_to_radar(at: Vector2,center: Vector2,
        radius: float,world_range: float) -> Vector2:
    if not is_instance_valid(player) or radius<=0.0 or world_range<=0.0:
        return center
    var listener:=Vector2(player.global_position.x,player.global_position.z)
    return center+(at-listener).rotated(_radar_yaw())*(radius/world_range)


func _radar_to_world(pixel: Vector2,center: Vector2,
        radius: float,world_range: float) -> Vector2:
    if not is_instance_valid(player) or radius<=0.0 or world_range<=0.0:
        return Vector2(INF,INF)
    var listener:=Vector2(player.global_position.x,player.global_position.z)
    return listener+(pixel-center).rotated(-_radar_yaw())*(
        world_range/radius)


func _player_screen_forward() -> Vector2:
    if not is_instance_valid(player):
        return Vector2.UP
    var yaw: float=float(player.get("_yaw"))
    var physical_forward:=Vector2(-sin(yaw),-cos(yaw))
    return physical_forward.rotated(_radar_yaw()).normalized()


func _terrain_uv(world: Vector2) -> Vector2:
    # CanvasItem.draw_polygon uses normalized [0,1] texture UVs, not
    # pixel coordinates. Values outside this range represent ocean/off-island
    # and are clamped by the texture sampler.
    var half_extent: float=TERRAIN_SCALE.HALF_EXTENT
    return (world+Vector2.ONE*half_extent)/(half_extent*2.0)


func _terrain_pixel(world: Vector2,texture_size: Vector2) -> Vector2:
    return _terrain_uv(world)*texture_size


func _draw_terrain_disc(center: Vector2,screen_radius: float,
        world_range: float,yaw: float) -> void:
    if map_texture==null or not is_instance_valid(player) or screen_radius<1.0:
        return
    var world: Vector2=Vector2(player.global_position.x,player.global_position.z)
    var points:=PackedVector2Array()
    var uvs:=PackedVector2Array()
    # Draw one convex 64-sided disc instead of a square texture under a
    # circular bezel. Normalized UVs preserve the same projection used
    # for zone rings and world markers; no extra Viewport or per-frame image.
    for i in range(MAP_DISC_SIDES):
        var radial: Vector2=Vector2.from_angle(
            TAU*float(i)/float(MAP_DISC_SIDES))*screen_radius
        points.append(center+radial)
        var terrain_at: Vector2=world+radial.rotated(-yaw)*(
            world_range/screen_radius)
        uvs.append(_terrain_uv(terrain_at))
    draw_polygon(points,PackedColorArray([Color(1,1,1,.85)]),uvs,map_texture)


func _process(delta: float) -> void:
    # Fixed upper bound: even all 49 rivals firing cannot grow the radar
    # history or repeatedly allocate hundreds of map markers.
    for i in range(_gunfire_pings.size()-1,-1,-1):
        var ping: Dictionary=_gunfire_pings[i]
        ping["remaining"]=float(ping["remaining"])-maxf(0.0,delta)
        if float(ping["remaining"])<=0.0:
            _gunfire_pings.remove_at(i)
        else:
            _gunfire_pings[i]=ping
    _tick+=delta
    # At rest retain the original 5 Hz redraw budget. While moving or
    # turning, repaint up to 25 Hz to avoid 200 ms map input latency.
    var moving: bool=false
    if is_instance_valid(player):
        var where:=Vector2(player.global_position.x,player.global_position.z)
        var heading: float=_radar_yaw()
        moving=(where.distance_squared_to(_last_radar_position)>.16 or
            not is_finite(_last_radar_yaw) or
            absf(angle_difference(_last_radar_yaw,heading))>.025)
        if (_tick>=.20 or (moving and _tick>=.04)):
            _last_radar_position=where
            _last_radar_yaw=heading
            _tick=0.0
            queue_redraw()
    elif _tick>=.20:
        _tick=0.0
        queue_redraw()


## World-space aircraft line projected through the SAME radar orientation
## and terrain range as the zone rings. Only visible while physically flying,
## never a decorative line in training or an already-landed BR.
func aircraft_route_pixels() -> PackedVector2Array:
    var points:=PackedVector2Array()
    if (not _battle_mode or not is_instance_valid(player) or
            not is_instance_valid(_sector_director)):
        return points
    var flight: Node3D=_sector_director.get("_flight") as Node3D
    if flight==null or str(flight.get("phase"))!="aircraft":
        return points
    var center: Vector2=_radar_center()
    var radius: float=_radar_radius()
    var world_range: float=_detail_range()
    if radius<1.0 or world_range<=.001:
        return points
    for z in [AIRDROP.ROUTE_START_Z,AIRDROP.ROUTE_END_Z]:
        points.append(_world_to_radar(Vector2(0.0,z),
            center,radius,world_range))
    return points


## Only draw safe-zone boundary segments that really intersect the
## local circular radar. The rest stays on the full tactical map; a
## distant 245 m ring may never wash over a tiny 80 m combat minimap.
func _draw_zone_in_local_disc(world_center: Vector2,world_radius: float,
        center: Vector2,radius: float,world_range: float,
        tint: Color,width: float) -> void:
    if world_radius<=0.0 or radius<=2.0 or world_range<=0.0:
        return
    var projected: Vector2=_world_to_radar(
        world_center,center,radius,world_range)
    var projected_radius: float=world_radius*radius/world_range
    var center_distance: float=projected.distance_to(center)
    var clip_radius: float=radius-2.0
    if center_distance>projected_radius+clip_radius or (
            projected_radius>center_distance+clip_radius):
        return
    var segments: int=clampi(ceili(TAU*projected_radius/4.5),72,192)
    var previous: Vector2=projected+Vector2(projected_radius,0.0)
    for i in range(1,segments+1):
        var angle: float=TAU*float(i)/float(segments)
        var current: Vector2=projected+Vector2.from_angle(angle)*projected_radius
        if (previous.distance_squared_to(center)<=clip_radius*clip_radius and
                current.distance_squared_to(center)<=clip_radius*clip_radius):
            draw_line(previous,current,tint,width,true)
        previous=current


## Never shrink an in-range destination by 10 px: its ground
## coordinate must align with the terrain and every physical loot icon.
## Only out-of-range marks clamp to the circular bezel as direction cues.
func _waypoint_marker(center: Vector2,radius: float,
        world_range: float) -> Dictionary:
    if not _waypoint.is_finite() or not is_instance_valid(player) or (
            radius<=11.0 or world_range<=0.0):
        return {}
    var exact: Vector2=_world_to_radar(_waypoint,
        center,radius,world_range)
    var relative: Vector2=exact-center
    var outside: bool=relative.length()>radius-11.0
    var player_at:=Vector2(player.global_position.x,player.global_position.z)
    return {"at":center+relative.limit_length(radius-11.0),
        "outside":outside,"distance_m":player_at.distance_to(_waypoint)}


func _draw_navigation_compass(center: Vector2,radius: float,
        world_range: float) -> void:
    var yaw: float=_radar_yaw()
    var font: Font=get_theme_default_font()
    var labels: Array[String]=["N","E","S","O"]
    var world_axes: Array[Vector2]=[
        Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]
    for i in range(world_axes.size()):
        var offset: Vector2=world_axes[i].rotated(yaw)*(radius-13.0)
        var color: Color=Color(1.0,.79,.35) if i==0 else Color(.80,.92,.97)
        draw_string(font,center+offset+Vector2(-4,4),labels[i],
            HORIZONTAL_ALIGNMENT_LEFT,-1,11,color)
    # Contrast helps the player's actual centre survive snowy map tiles.
    draw_circle(center,9.0,Color(.017,.058,.08,.98))
    draw_arc(center,9.8,0,TAU,24,Color(.80,.97,1.0,.94),1.4,true)
    var facing: Vector2=_player_screen_forward()
    var lateral:=Vector2(-facing.y,facing.x)
    var tip:=PackedVector2Array([
        center+facing*12.0,
        center-facing*6.0+lateral*5.5,
        center-facing*6.0-lateral*5.5])
    draw_colored_polygon(tip,Color(1.0,1.0,.95))
    # Orientation is already given by the white player arrow. Do not
    # draw an extra yellow motion trail over the moving minimap.
    draw_string(font,Vector2(7.0,size.y-6.0),
        "RADIO %d m"%roundi(world_range),
        HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(.96,.98,.93))


func _draw() -> void:
    var rect: Rect2=Rect2(Vector2.ZERO,size)
    draw_rect(rect,Color(.025,.09,.13,.77))
    draw_rect(rect,Color(.30,.73,.81,.85),false,1.6)
    var center: Vector2=_radar_center()
    var radius: float=_radar_radius()
    if player==null or not is_instance_valid(player):
        draw_arc(center,radius,0,TAU,52,Color(.34,.67,.72,.62),1.2,true)
        return
    var yaw: float=_radar_yaw()
    var world_range: float=_detail_range()
    _draw_terrain_disc(center,radius,world_range,yaw)
    # The route is a real aircraft flight segment; the full tactical map
    # already uses these same endpoints. Do not add an extra map button.
    var flight_line: PackedVector2Array=aircraft_route_pixels()
    if flight_line.size()==2:
        draw_line(flight_line[0],flight_line[1],
            Color(1.0,.82,.34,.92),2.4,true)
        draw_circle(flight_line[1],3.0,Color(1.0,.78,.26,.96))
    draw_arc(center,radius,0,TAU,52,Color(.41,.89,.95,.86),1.9,true)
    draw_arc(center,radius*.5,0,TAU,52,Color(.75,.91,.92,.27),1.0,true)
    draw_line(center+Vector2(-radius,0),center+Vector2(radius,0),Color(.28,.50,.55,.32),1.0)
    draw_line(center+Vector2(0,-radius),center+Vector2(0,radius),Color(.28,.50,.55,.32),1.0)
    # Compass/player pointer are drawn LAST so world icons cannot obscure
    # the actual actor location or the movement direction.
    if _zone_enabled:
        _draw_zone_in_local_disc(_zone_world_center,_zone_radius,
            center,radius,world_range,Color(.42,.97,1.0,.91),2.7)
    if _next_zone_enabled:
        # The next ring is physical zone geometry, not an independently
        # scaled circle that obscures the local buildings or player.
        _draw_zone_in_local_disc(_next_zone_center,_next_zone_radius,
            center,radius,world_range,Color(.99,.79,.37,.85),1.6)
    if _waypoint.is_finite():
        var waypoint_icon: Dictionary=_waypoint_marker(
            center,radius,world_range)
        if not waypoint_icon.is_empty():
            var dot: Vector2=waypoint_icon["at"]
            if _battle_mode:
                var opacity: float=.56 if player.air_mode!="ground" else .29
                draw_line(center,dot,Color(1.0,.71,.16,opacity),1.5,true)
            if bool(waypoint_icon["outside"]):
                # Point outward to a REAL marked destination beyond 80m,
                # never draw it at an invented in-range terrain coordinate.
                var bearing: Vector2=(dot-center).normalized()
                var wing:=Vector2(-bearing.y,bearing.x)
                var arrow:=PackedVector2Array([
                    dot+bearing*5.0,
                    dot-bearing*6.0+wing*4.0,
                    dot-bearing*6.0-wing*4.0])
                draw_colored_polygon(arrow,Color(1.0,.82,.31))
            else:
                draw_circle(dot,5.3,Color(1.0,.73,.15))
                draw_arc(dot,8.0,0,TAU,28,Color(1.0,.90,.42),1.6)
    if _battle_mode:
        # Resource dots use real Area3D collision items, not a second
        # simulated loot map. Yellow=ammo, red=medical, blue=equipment.
        var physical_listener:=Vector2(
            player.global_position.x,player.global_position.z)
        for resource in nearby_physical_resources():
            var relative: Vector2=(resource["at"] as Vector2)-physical_listener
            var dot: Vector2=center+relative.rotated(yaw)*(
                radius/world_range)
            if dot.distance_to(center)>radius-6.0:
                continue
            var kind: String=str(resource["kind"])
            var tint: Color=(Color(.99,.42,.42) if kind=="medkit"
                or kind=="syringe" else Color(.44,.79,1.0)
                if kind.begins_with("vest") or kind.begins_with("helmet")
                or kind.begins_with("backpack") else Color(1.0,.83,.33))
            draw_circle(dot,3.3,tint)
            draw_arc(dot,5.0,0,TAU,16,Color(.02,.12,.17,.95),1.0)
        # Interactable supply lockers use a distinct gold diamond; unlike
        # individual pickups, these require an actual press and raycast.
        for locker_at in nearby_sealed_lockers():
            var relative: Vector2=locker_at-physical_listener
            var dot: Vector2=center+relative.rotated(yaw)*(
                radius/world_range)
            if dot.distance_to(center)>radius-7.0:
                continue
            draw_colored_polygon(PackedVector2Array([
                dot+Vector2(0,-5.5),dot+Vector2(5.5,0),
                dot+Vector2(0,5.5),dot+Vector2(-5.5,0)]),
                Color(.98,.67,.25,.96))
        # A grenade danger icon is grounded in a live, fuse-burning
        # Node3D. It is never an enemy wallhack or a persistent map ping.
        for hazard in nearby_live_grenade_hazards():
            var relative: Vector2=(hazard["at"] as Vector2)-physical_listener
            var dot: Vector2=center+relative.rotated(yaw)*(
                radius/world_range)
            if dot.distance_to(center)>radius-8.0:
                continue
            draw_circle(dot,5.2,Color(1.0,.24,.14,.94))
            draw_arc(dot,8.2,0,TAU,22,Color(1.0,.72,.34,.94),1.7)
        for at in nearby_physical_vehicles():
            var relative: Vector2=at-physical_listener
            var dot: Vector2=center+relative.rotated(yaw)*(
                radius/world_range)
            if dot.distance_to(center)>radius-7.0:
                continue
            draw_rect(Rect2(dot-Vector2(4,2.5),Vector2(8,5)),
                Color(.72,.93,1.0),true)
        # Existing physical caches, NOT the living rivals, are eligible
        # for a tiny, bounded supply icon near the listener. The match
        # director filters dead/collected/remote objects for us.
        var listener: Vector2=Vector2(
            player.global_position.x,player.global_position.z)
        for cache_at in _nearby_supply_markers():
            var relative: Vector2=cache_at-listener
            var dot: Vector2=center+relative.rotated(yaw)*(
                radius/world_range)
            if dot.distance_to(center)>radius-6.0:
                continue
            var bounds:=Rect2(dot-Vector2(3.5,3.5),Vector2(7,7))
            draw_rect(bounds,Color(.06,.23,.20,.94),true)
            draw_rect(bounds,Color(.64,.99,.73),false,1.1)
        # Acoustic contacts are SOUND BEARINGS, not precise enemy dots.
        # A shot's saved location becomes false as soon as the shooter
        # moves. Show the last audible direction on the radar rim instead
        # of implying the bot is still at a fixed coordinate.
        for ping in _gunfire_pings:
            var last_heard: Vector2=ping["position"]
            var relative: Vector2=last_heard-Vector2(
                player.global_position.x,player.global_position.z)
            if (relative.length_squared()>.001 and
                    relative.length_squared()<=
                    GUNFIRE_HEARING_RANGE*GUNFIRE_HEARING_RANGE):
                var heading: Vector2=relative.rotated(yaw).normalized()
                var angle: float=heading.angle()
                var alpha: float=clampf(float(ping["remaining"])/
                    GUNFIRE_PING_SECONDS,0.0,1.0)
                draw_arc(center,radius-4.0,angle-.13,angle+.13,9,
                    Color(1.0,.46,.23,alpha),3.2,true)
        _draw_navigation_compass(center,radius,world_range)
        return
    for bot in opponents:
        if not is_instance_valid(bot) or not bot.visible:
            continue
        var relative:=Vector2(bot.global_position.x-player.global_position.x,
                              bot.global_position.z-player.global_position.z)
        if relative.length()>world_range:
            continue
        var dot: Vector2=center+relative.rotated(yaw)*(radius/world_range)
        draw_circle(dot,5.3,Color(.98,.41,.27))
        draw_arc(dot,8.0,0,TAU,12,Color(1.0,.80,.63,.6),1.0)
    _draw_navigation_compass(center,radius,world_range)
