extends Control
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
var _waypoint: Vector2=Vector2(INF,INF)
const GUNFIRE_HEARING_RANGE: float=42.0
const GUNFIRE_PING_SECONDS: float=3.0
const GUNFIRE_MERGE_DISTANCE: float=6.0
const MAX_GUNFIRE_PINGS: int=8
var _battle_mode: bool=false
var _gunfire_pings: Array[Dictionary]=[]


func _ready() -> void:
    name="AuroraTrainingRadar"
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    var heading:=Label.new()
    heading.text="RADAR AURORA · 60 m"
    heading.position=Vector2(9,3)
    heading.add_theme_font_size_override("font_size",12)
    heading.add_theme_color_override("font_color",Color(.79,.95,.96))
    heading.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(heading)
    queue_redraw()


func set_sources(player_character: CharacterBody3D, enemies: Array[CharacterBody3D]) -> void:
    player=player_character
    opponents=enemies.duplicate()
    queue_redraw()


func set_battle_mode(enabled: bool) -> void:
    _battle_mode=enabled
    clear_gunfire()
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
    queue_redraw()


func set_next_zone(center: Vector2,radius: float) -> void:
    _next_zone_enabled=true
    _next_zone_center=center
    _next_zone_radius=maxf(.35,radius)
    queue_redraw()


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
    var center: Vector2=Vector2(size.x*.5,size.y*.57)
    var radius: float=minf(size.x*.40,size.y*.36)
    draw_arc(center,radius,0,TAU,52,Color(.34,.67,.72,.62),1.2,true)
    draw_arc(center,radius*.5,0,TAU,52,Color(.30,.61,.69,.31),1.0,true)
    draw_line(center+Vector2(-radius,0),center+Vector2(radius,0),Color(.28,.50,.55,.37),1.0)
    draw_line(center+Vector2(0,-radius),center+Vector2(0,radius),Color(.28,.50,.55,.37),1.0)
    var arrow:=PackedVector2Array([center+Vector2(0,-8),center+Vector2(-5,6),center+Vector2(5,6)])
    draw_colored_polygon(arrow,Color(.75,.99,1.0))
    if player==null or not is_instance_valid(player):
        return
    var yaw: float=float(player.get("_yaw")) if rotate_with_camera else 0.0
    var world_range: float=130.0 if _zone_enabled else 60.0
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
