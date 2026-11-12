extends SceneTree
## Real world-physics regression, not screenshot-only geometry acceptance.
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")


func check(value: bool, message: String) -> void:
    if not value:
        failed=true
        push_error("V756_COASTAL_QUARTER "+message)


func _verify() -> void:
    var scene: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(scene)
    await physics_frame
    await physics_frame
    var district: Node3D=scene.get_node("PuertoAuroraSector")
    var town: Node3D=scene.get_node("PuertoAuroraCoastalQuarter")
    check(int(town.buildings_built)==town.HOUSE_COUNT,"houses not generated")
    check(int(town.accessible_entries)==town.HOUSE_COUNT,"entrances missing")
    check(int(town.tile_instances)>=1000,"curved roof tile instancing missing")
    check(int(town.collision_bodies)>35,"physical covers/roofs missing")
    check(town.navigation_points.size()>20,"no new AI navigation")
    check(town.furnished_interiors==town.HOUSE_COUNT and
        town.interior_supply_spots.size()==town.HOUSE_COUNT,
        "coastal rooms need real furnishing and pickup-floor anchors")
    check(town.cover_points.size()>=8,"no new cover")
    check(district.navigation_points.size()>town.navigation_points.size(),
        "new 3D houses not connected to navigation seed list")
    var space:=scene.get_world_3d().direct_space_state
    var checked_doors: int=0
    var checked_walls: int=0
    var checked_roofs: int=0
    for index in range(4):
        var house: Node3D=town.get_node("AuroraCoastalVilla"+str(index))
        var width: float=11.2 if index==0 else 10.8 if index==1 else 11.3 if index==2 else 9.6
        var depth: float=8.0 if index==0 else 8.4 if index==1 else 8.3 if index==2 else 7.7
        check(house.get_node_or_null("WalkableRoofCollision")!=null,
            "roof collider not created "+str(index))
        check(house.get_node_or_null("TraversableDoorRamp")!=null,
            "ramp not created "+str(index))
        var tiles: MultiMeshInstance3D=house.get_node("InstancedCurvedTerracottaTiles")
        check(tiles.multimesh.instance_count>180,"roof lacks modeled tile detail")
        var door_line:=PhysicsRayQueryParameters3D.create(
            house.to_global(Vector3(0,1.6,depth*.5+3.0)),
            house.to_global(Vector3(0,1.6,0)))
        var door_hit:=space.intersect_ray(door_line)
        check(door_hit.is_empty(),"door blocked by unseen wall "+str(index))
        if door_hit.is_empty():
            checked_doors+=1
        var wall_line:=PhysicsRayQueryParameters3D.create(
            house.to_global(Vector3(width*.5+2.0,1.5,0)),
            house.to_global(Vector3(0,1.5,0)))
        if not space.intersect_ray(wall_line).is_empty():
            checked_walls+=1
        var roof_line:=PhysicsRayQueryParameters3D.create(
            house.to_global(Vector3(0,13.0,0)),
            house.to_global(Vector3(0,4.6,0)))
        if not space.intersect_ray(roof_line).is_empty():
            checked_roofs+=1
    check(checked_doors==4,"not all entrances open")
    check(checked_walls==4,"bullets can pass through modeled walls")
    check(checked_roofs==4,"no physical roof surfaces")
    # Walk a CharacterBody through each ramp and doorway without jumping:
    # a ray through an aperture alone is not sufficient gameplay acceptance.
    var operator=scene.get_node("Operator")
    var terrain=scene.get_node("AuroraTerrain")
    for bot in scene.get_node("CombatRange")._targets:
        bot.set_physics_process(false)
    var visited: int=0
    for index in range(4):
        var house: Node3D=town.get_node("AuroraCoastalVilla"+str(index))
        var depth: float=8.0 if index==0 else 8.4 if index==1 else 8.3 if index==2 else 7.7
        var approach: Vector3=house.to_global(Vector3(0,0,depth*.5+8.1))
        operator.global_position=Vector3(approach.x,terrain.height_at(approach.x,approach.z)+.16,approach.z)
        operator.velocity=Vector3.ZERO
        operator.rotation.y=house.rotation.y
        operator._yaw=house.rotation.y
        operator._desired_yaw=house.rotation.y
        operator.set_touch_move_axis(Vector2.UP)
        for frame in range(230):
            await physics_frame
        operator.set_touch_move_axis(Vector2.ZERO)
        var local: Vector3=house.to_local(operator.global_position)
        check(local.z<depth*.5-1.1,"player blocked by modeled entrance "+str(index)+" pos="+str(local))
        if local.z<depth*.5-1.1:
            visited+=1
    check(visited==4,"not every house was physically enterable")

    var hud=scene.get_node("TrainingHUD")
    check(hud._reticle!=null,"combat scope missing")
    hud.set_aim(true,"AWM",8.0)
    check(hud._reticle.zoom>=8.0,"AWM scope unavailable in new scene")
    print("V756_COASTAL_QUARTER PASS houses=",town.buildings_built,
        " walked_through=",visited,
        " doors=",checked_doors," walls=",checked_walls,
        " roofs=",checked_roofs," curved_tiles=",town.tile_instances,
        " solid_bodies=",town.collision_bodies,
        " nav_points=",town.navigation_points.size(),
        " cover_points=",town.cover_points.size())
    quit(1 if failed else 0)
