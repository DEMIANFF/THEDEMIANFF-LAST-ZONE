extends Control
const TERRAIN_SCALE=preload("res://scripts/world/island_terrain.gd")
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
var _battle_mode: bool=false
var _gunfire_pings: Array[Dictionary]=[]


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
    _refresh_zone_label()
    queue_redraw()



func _refresh_zone_label() -> void:
    if not is_instance_valid(_zone_label):
        return
    var caption: String="PUERTO AURORA"
    if _zone_enabled:
        caption="ZONA %d m"%roundi(_zone_radius)
        if _next_zone_enabled:
            # Use two readable rows instead of overflowing the 156px radar.
            caption+="\nPRÓX %d m"%roundi(_next_zone_radius)
    if _zone_label.text!=caption:
        _zone_label.text=caption


## A fixed 130 m radar made the 245 m opening circle disappear. Fit both
## real rings around the player (including moving centres), with a 10% margin.
## No fabricated zone position or independent hazard simulation.
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
        var terrain_at: Vector2=world+radial.rotated(yaw)*(
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
    if _tick>=.2:
        _tick=0
        queue_redraw()


func _draw() -> void:
    var rect: Rect2=Rect2(Vector2.ZERO,size)
    draw_rect(rect,Color(.025,.09,.13,.77))
    draw_rect(rect,Color(.30,.73,.81,.85),false,1.6)
    var center: Vector2=Vector2(size.x*.5,size.y*.55)
    var radius: float=minf(size.x*.45,size.y*.43)
    if player==null or not is_instance_valid(player):
        draw_arc(center,radius,0,TAU,52,Color(.34,.67,.72,.62),1.2,true)
        return
    var yaw: float=float(player.get("_yaw")) if rotate_with_camera else 0.0
    var world_range: float=_world_range()
    _draw_terrain_disc(center,radius,world_range,yaw)
    draw_arc(center,radius,0,TAU,52,Color(.41,.89,.95,.86),1.9,true)
    draw_arc(center,radius*.5,0,TAU,52,Color(.75,.91,.92,.27),1.0,true)
    draw_line(center+Vector2(-radius,0),center+Vector2(radius,0),Color(.28,.50,.55,.32),1.0)
    draw_line(center+Vector2(0,-radius),center+Vector2(0,radius),Color(.28,.50,.55,.32),1.0)
    var arrow:=PackedVector2Array([center+Vector2(0,-8),center+Vector2(-5,6),center+Vector2(5,6)])
    draw_colored_polygon(arrow,Color(.75,.99,1.0))
    if _zone_enabled:
        var offset: Vector2=_zone_world_center-Vector2(player.global_position.x,player.global_position.z)
        var screen_position: Vector2=center+offset.rotated(-yaw)*(radius/world_range)
        var mapped_radius: float=_zone_radius*radius/world_range
        draw_arc(screen_position,mapped_radius,0,TAU,72,Color(.42,.97,1.0,.91),2.7,true)
    if _next_zone_enabled:
        # A subtle planned-ring marker is essential when the safe-zone
        # center moves; the player sees WHERE to rotate, not a random
        # unseen moving hazard. The marker uses exact geometry, not fake
        # target coordinates or a second selectable match option.
        var next_offset: Vector2=_next_zone_center-Vector2(
            player.global_position.x,player.global_position.z)
        var next_position: Vector2=center+next_offset.rotated(-yaw)*(
            radius/world_range)
        var planned_radius: float=_next_zone_radius*radius/world_range
        draw_arc(next_position,maxf(.4,planned_radius),0,TAU,60,
            Color(.99,.79,.37,.85),1.6,true)
        draw_circle(next_position,2.0,Color(.99,.79,.37,.8))
    if _waypoint.is_finite():
        var position: Vector2=Vector2(player.global_position.x,player.global_position.z)
        var waypoint_delta: Vector2=(_waypoint-position).rotated(-yaw)
        var dot: Vector2=center+waypoint_delta.limit_length(world_range)*radius/world_range
        draw_circle(dot,6.0,Color(1.0,.73,.15))
        draw_arc(dot,8.5,0,TAU,28,Color(1.0,.90,.42),1.6)
    if _battle_mode:
        # In BR, do NOT draw physical bot locations directly. The radar
        # never tracks an unseen body behind buildings; only recent real
        # gunshot locations may appear as a fading acoustic indicator.
        for ping in _gunfire_pings:
            var last_heard: Vector2=ping["position"]
            var relative: Vector2=last_heard-Vector2(
                player.global_position.x,player.global_position.z)
            if relative.length_squared()>GUNFIRE_HEARING_RANGE*GUNFIRE_HEARING_RANGE:
                continue
            var dot: Vector2=center+relative.rotated(-yaw)*(radius/world_range)
            var alpha: float=clampf(float(ping["remaining"])/
                GUNFIRE_PING_SECONDS,0.0,1.0)
            draw_arc(dot,7.0,0,TAU,22,Color(1.0,.53,.25,alpha),1.8,true)
            draw_circle(dot,2.5,Color(1.0,.65,.34,alpha*.9))
        return
    for bot in opponents:
        if not is_instance_valid(bot) or not bot.visible:
            continue
        var relative:=Vector2(bot.global_position.x-player.global_position.x,
                              bot.global_position.z-player.global_position.z)
        if relative.length()>world_range:
            continue
        var dot: Vector2=center+relative.rotated(-yaw)*(radius/world_range)
        draw_circle(dot,5.3,Color(.98,.41,.27))
        draw_arc(dot,8.0,0,TAU,12,Color(1.0,.80,.63,.6),1.0)
