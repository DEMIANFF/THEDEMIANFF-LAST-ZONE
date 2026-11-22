extends SceneTree
## V75.160 real Main.tscn regression for user videos 181823 / 181824.
## Verifies world geometry, 512px shared map, north-up player heading,
## right-side tactical navigation, zoom and minimap physical projection.
const MAP_SOURCE=preload("res://scripts/ui/aurora_tactical_map.gd")
const FOOTPRINTS=preload("res://scripts/world/aurora_map_footprints.gd")
const RESIDENTIAL=preload("res://scripts/world/coastal_residential_layout.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(valid: bool,why: String) -> void:
    if not valid:
        failed=true
        push_error("V75160_LIVE_CARTOGRAPHY "+why)


func _verify() -> void:
    root.size=Vector2i(964,434)
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get_node("Operator")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var radar: Control=hud.get_node(
        "AuroraTacticalOverlay/AuroraTrainingRadar")
    var tactical: Control=hud.get_node(
        "AuroraTacticalOverlay/AuroraFullTacticalMap")
    var district: Node3D=game.get_node("PuertoAuroraSector")
    var coast: Node3D=game.get_node_or_null("PuertoAuroraCoastalQuarter")
    var world: StaticBody3D=game.get_node("AuroraTerrain")
    var combat: Node3D=game.get_node("CombatRange")
    for bot in combat._targets:
        bot.set_physics_process(false)
    player.set_physics_process(false)
    await process_frame
    check(tactical!=null and radar!=null and coast!=null and world!=null,
        "playable map and physical 3D district/quarter missing")
    if tactical==null or radar==null:
        quit(1)
        return
    var tex: ImageTexture=tactical.get("_terrain_texture") as ImageTexture
    check(tex!=null and MAP_SOURCE.MAP_SAMPLES==512 and
        tex.get_width()==512 and tex.get_height()==512 and
        radar.get("map_texture")==tex,
        "the 512px exact same terrain texture is not used on both maps")
    if tex==null:
        quit(1)
        return
    var pixels: Image=tex.get_image()
    for building in FOOTPRINTS.DISTRICT_BUILDINGS:
        var physical: Node3D=district.get_node_or_null(
            str(building["name"]).replace(" ","_")) as Node3D
        var at: Vector2=building["at"]
        check(physical!=null and
            Vector2(physical.global_position.x,physical.global_position.z).distance_to(at)<.01,
            "real 3D roof and map coordinate differ: "+str(building["name"]))
        var pixel: Vector2=tactical.call("_terrain_pixel",at)
        var ix: int=clampi(roundi(pixel.x),0,511)
        var iz: int=clampi(roundi(pixel.y),0,511)
        check(pixels.get_pixel(ix,iz).r>.46,
            "building "+str(building["name"])+" not painted in real cartography")
    check(FOOTPRINTS.DISTRICT_ROADS.size()==4 and
        FOOTPRINTS.COASTAL_PLAZAS.size()==3 and
        FOOTPRINTS.FREIGHT_CACHES.size()==2 and
        RESIDENTIAL.SITES.size()==8,
        "physical district roads/plazas/caches or houses missing")
    for site in RESIDENTIAL.SITES:
        var at: Vector2=Vector2(site.x,site.y)
        var pixel: Vector2=tactical.call("_terrain_pixel",at)
        check(pixels.get_pixel(clampi(roundi(pixel.x),0,511),
            clampi(roundi(pixel.y),0,511)).r>.46,
            "a real coastal house footprint is invisible at map scale")
    for plaza in FOOTPRINTS.COASTAL_PLAZAS:
        var pixel: Vector2=tactical.call("_terrain_pixel",plaza["center"])
        check(pixels.get_pixel(clampi(roundi(pixel.x),0,511),
            clampi(roundi(pixel.y),0,511)).r>.42,
            "physical coastal promenade lacks walkable map footprint")
    # Tactical map is actually on the right; it leaves sufficient live
    # physical world visible to the left of the map at Motorola resolution.
    var map_rect: Rect2=tactical.call("_map_rect")
    check(map_rect.position.x>=320.0 and
        map_rect.end.x<=tactical.size.x*.78 and
        absf(map_rect.size.x-map_rect.size.y)<17.0,
        "tactical map still obscures centre combat or isn't square")
    check(float(tactical.get("zoom"))>=2.0 and
        float(tactical.get("zoom"))<=3.0,
        "default view cannot show local street/roof navigation")
    tactical.visible=true
    tactical.call("_follow")
    var location:=Vector2(21.0,33.0)
    player.global_position=Vector3(location.x,
        world.height_at(location.x,location.y)+1.0,location.y)
    player.velocity=Vector3(3.0,0.0,0.0)
    tactical.call("_process",.20)
    var following: Vector2=tactical.get("pan")
    var p: Vector2=tactical.call("project",location)
    check(following.distance_to(location)<.02 and
        p.distance_to(map_rect.get_center())<.02,
        "follow mode fails to center the actual 3D player in local view")
    player.set("_yaw",0.0)
    var north: Vector2=tactical.call("_map_player_forward")
    player.set("_yaw",-PI*.5)
    var east: Vector2=tactical.call("_map_player_forward")
    player.set("_yaw",PI*.5)
    var west: Vector2=tactical.call("_map_player_forward")
    player.set("_yaw",PI)
    var south: Vector2=tactical.call("_map_player_forward")
    check(north.distance_to(Vector2.UP)<.01 and
        east.distance_to(Vector2.RIGHT)<.01 and
        west.distance_to(Vector2.LEFT)<.01 and
        south.distance_to(Vector2.DOWN)<.01,
        "north-up real player arrow and Godot yaw are inconsistent")
    player.set("_yaw",0.0)
    var near: Vector2=location+Vector2(10.0,0.0)
    var radar_center: Vector2=radar.call("_radar_center")
    var radius: float=radar.call("_radar_radius")
    var range_m: float=radar.call("_detail_range")
    var dot: Vector2=radar.call("_world_to_radar",near,
        radar_center,radius,range_m)
    check(dot.x>radar_center.x+3.0 and
        radar.call("_radar_to_world",dot,radar_center,radius,range_m).distance_to(near)<.01,
        "moving east in real map doesn't move local terrain correctly")
    tactical.set("zoom",1.0)
    tactical.call("_clamp_pan_to_terrain")
    check((tactical.get("pan") as Vector2).length()<.01,
        "full-island overview exposes repeated outside terrain")
    tactical.set("zoom",2.4)
    tactical.call("_follow")
    check((tactical.get("pan") as Vector2).distance_to(location)<.01,
        "return to detailed location after island overview failed")
    tactical.visible=false
    game.queue_free()
    await process_frame
    if not failed:
        print("V75160_LIVE_CARTOGRAPHY PASS phone=964x434 "+
            "terrain_texture=512 shared_with_minimap=1 roofs=12 "+
            "real_roads=4 plazas=3 cargo=2 right_pane=1 "+
            "local_zoom=2.4 follow=physical world_to_radar=1 "+
            "heading_N_E_S_W=4 overview=1 motorola_device_test=NO")
    quit(1 if failed else 0)
