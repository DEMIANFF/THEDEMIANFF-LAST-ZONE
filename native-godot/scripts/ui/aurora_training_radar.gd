extends Control
## True in-scene training radar, not a fabricated battle-royale network minimap.
## Shows only physical spawned opponents within 60 metres.

var player: CharacterBody3D
var opponents: Array[CharacterBody3D]=[]
var _tick: float=0.0
var _zone_enabled: bool=false
var _zone_world_center: Vector2=Vector2.ZERO
var _zone_radius: float=90.0
var rotate_with_camera: bool=true
var _waypoint: Vector2=Vector2(INF,INF)


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


func set_waypoint(at: Vector2) -> void:
    _waypoint=at
    queue_redraw()


func set_zone(center: Vector2,radius: float) -> void:
    _zone_enabled=true
    _zone_world_center=center
    _zone_radius=maxf(3.0,radius)
    queue_redraw()


func _process(delta: float) -> void:
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
    if _waypoint.is_finite():
        var position: Vector2=Vector2(player.global_position.x,player.global_position.z)
        var waypoint_delta: Vector2=(_waypoint-position).rotated(-yaw)
        var dot: Vector2=center+waypoint_delta.limit_length(world_range)*radius/world_range
        draw_circle(dot,6.0,Color(1.0,.73,.15))
        draw_arc(dot,8.5,0,TAU,28,Color(1.0,.90,.42),1.6)
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
