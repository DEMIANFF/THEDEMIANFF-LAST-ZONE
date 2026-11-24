extends SceneTree
## V75.181: compare the actual physical world's nearest resources to BOTH
## navigation UIs. The oldest loot must never hide a closer newer kill.
const SECTOR=preload("res://scripts/match/sector_director.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V75181_NEAREST_LOOT_NAV "+message)

func _verify() -> void:
    root.size=Vector2i(964,434)
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var player: CharacterBody3D=game.get_node("Operator")
    var combat: Node3D=game.get_node("CombatRange")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var radar: Control=game.get_node(
        "TrainingHUD/AuroraTacticalOverlay/AuroraTrainingRadar")
    var tactical: Control=hud.get("_map_overlay") as Control
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)

    var base:=Vector2(player.global_position.x,player.global_position.z)
    # Use real physical Area3D loot, newest nearest to the player.
    # These are actual collision items at terrain height, not fake data.
    var far_to_near: Array[int]=[43,35,27,19,13,9,7,5]
    var physical: Array[Area3D]=[]
    for i in range(far_to_near.size()):
        var at: Vector2=base+Vector2(far_to_near[i],0.0)
        director._make_pickup(at,"ammo_ar","V75181PhysicalLoot%d"%i,
            NAN,true,7)
        var item: Area3D=director.get_node(
            "V75181PhysicalLoot%d"%i) as Area3D
        physical.append(item)
        check(item!=null and item.from_opponent and
            item.quantity==7 and not item.collected,
            "test failed to create actual 3D ammo cache from a rival")
    var expected_4: Array[Vector2]=[]
    var expected_6: Array[Vector2]=[]
    for dist in [5,7,9,13]:
        expected_4.append(base+Vector2(dist,0.0))
    for dist in [5,7,9,13,19,27]:
        expected_6.append(base+Vector2(dist,0.0))
    var actual_4: Array[Vector2]=director.nearby_opponent_supply_points(
        base,50.0,4)
    var actual_6: Array[Vector2]=director.nearby_opponent_supply_points(
        base,70.0,6)
    check(actual_4==expected_4 and actual_6==expected_6,
        "oldest remote caches won marker slots over nearest real ammo")
    check(radar.call("_nearby_supply_markers")==expected_4 and
        tactical.call("_live_local_cache_markers")==expected_6,
        "minimap and expanded map do not share nearest-physical priority")
    physical[7].collected=true
    physical[7].queue_free()
    var next_nearest: Array[Vector2]=director.nearby_opponent_supply_points(
        base,50.0,4)
    check(next_nearest==[
        base+Vector2(7,0),base+Vector2(9,0),
        base+Vector2(13,0),base+Vector2(19,0)],
        "a picked-up 3D item remained on minimap or blocked new loot")

    # Real 3D noncollectible death shells: three NEAREST, not three
    # earliest in their spawn list, regardless of chronological order.
    for metres in [42,32,24,16,10,6]:
        director._spawn_empty_opponent_marker(Vector3(
            base.x+float(metres),player.global_position.y,
            base.y),"SIN OBJETOS")
    var closest_empty: Array[Vector2]=[
        base+Vector2(6,0),base+Vector2(10,0),
        base+Vector2(16,0)]
    check(director.nearby_empty_death_crates(base)==closest_empty and
        radar.call("nearby_empty_death_crates")==closest_empty and
        tactical.call("_live_empty_death_crates")==closest_empty,
        "old empty death shells hide a new nearby real empty marker")
    check(director.nearby_opponent_supply_points(base,50.0,0).is_empty()
        and director.nearby_empty_death_crates(base,48.0,0).is_empty()
        and director.nearby_opponent_supply_points(
            base+Vector2(200,0),10.0,4).is_empty(),
        "zero-budget or far-away match leaked false cache locations")

    # The designer-requested yellow minimap tether is removed; only
    # the truthful waypoint indicator/edge arrow persists when walking.
    radar.set_waypoint(base+Vector2(20,0))
    var marker: Dictionary=radar.call("_waypoint_marker",
        radar.call("_radar_center"),
        radar.call("_radar_radius"),radar.call("_detail_range"))
    check(not marker.is_empty() and not bool(
        marker.get("outside",true)),
        "removing yellow route trail also destroyed exact waypoint pin")
    if FileAccess.file_exists("res://scripts/ui/aurora_training_radar.gd"):
        var fh:=FileAccess.open("res://scripts/ui/aurora_training_radar.gd",
            FileAccess.READ)
        var source: String=fh.get_as_text()
        check(not source.contains("draw_line(center,dot,"),
            "yellow center-to-waypoint tether returned to local radar")
    radar.set_waypoint(Vector2(INF,INF))

    director._finish(false)
    check(director.nearby_opponent_supply_points(base).is_empty()
        and director.nearby_empty_death_crates(base).is_empty(),
        "late inventory or empty shells leaked into ended match")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75181_NEAREST_LOOT_NAV PASS real_3D_loot=8 "+
            "nearest_ammo4=1 nearest_tactical6=1 collected=1 "+
            "nearest_empty3=1 no_yellow_tether=1 cleanup=1")
    quit(1 if failed else 0)
