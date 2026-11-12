extends SceneTree
## Native Godot acceptance for the *real* V75.28 geometry, loot collection,
## timed shrinking zone, and post-update player traversal on physical ramps.
## It is not a claim of on-device Motorola acceptance.
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(value: bool,reason: String) -> void:
    if not value:
        failed=true
        push_error("V7528_COASTAL_BR "+reason)


func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var coastal: Node3D=game.get_node("PuertoAuroraCoastalQuarter")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var player: CharacterBody3D=game.get_node("Operator")
    var combat: Node3D=game.get_node("CombatRange")
    for enemy in combat._targets:
        enemy.set_physics_process(false)
    await physics_frame
    await physics_frame

    check(coastal.buildings_built==6 and coastal.furnished_interiors==6,
        "six houses were not created with authentic collidable interiors")
    check(coastal.interior_supply_spots.size()==6,
        "missing exact interior floor surface coordinates")
    check(coastal.cargo_caches_built==2,
        "coastal expansion changed existing proven freight caches")

    var tested_open_doors: int=0
    var walked_new_houses: int=0
    var space:=game.get_world_3d().direct_space_state
    for index in [4,5]:
        var house: Node3D=coastal.get_node("AuroraCoastalVilla"+str(index))
        var depth: float=8.3 if index==4 else 8.4
        var door_ray:=PhysicsRayQueryParameters3D.create(
            house.to_global(Vector3(0,1.55,depth*.5+2.6)),
            house.to_global(Vector3(0,1.55,-.45)))
        if space.intersect_ray(door_ray).is_empty():
            tested_open_doors+=1
        check(house.get_node_or_null("RoomWorkbench0Solid")!=null and
            house.get_node_or_null("RoomWorkbench2Solid")!=null,
            "new house is missing physical interior furniture")
        check(house.get_node_or_null("TraversableDoorRamp")!=null,
            "new house does not have a physical entry ramp")
        var approach: Vector3=house.to_global(Vector3(0,0,depth*.5+8.1))
        player.global_position=Vector3(approach.x,
            terrain.height_at(approach.x,approach.z)+.16,approach.z)
        player.velocity=Vector3.ZERO
        player.rotation.y=house.rotation.y
        player._yaw=house.rotation.y
        player._desired_yaw=house.rotation.y
        player.set_touch_move_axis(Vector2.UP)
        for frame in range(230):
            await physics_frame
        player.set_touch_move_axis(Vector2.ZERO)
        var inside: Vector3=house.to_local(player.global_position)
        if inside.z<depth*.5-1.1:
            walked_new_houses+=1
        check(inside.z<depth*.5-1.1,
            "new house "+str(index)+" is not actually traversable "+str(inside))
    check(tested_open_doors==2,"wall collision still blocks an added doorway")
    check(walked_new_houses==2,"player could not walk into both new houses")

    # Test four continuous phases and each deliberate preparation/closure
    # interval without waiting through a real five-minute battle.
    var previous: float=director.INITIAL_RADIUS
    var last_phase: int=0
    for second in range(0,281,7):
        var state: Dictionary=director.zone_state_at(float(second))
        var current: float=float(state["radius"])
        var stage: int=int(state["phase"])
        check(current<=previous+.0001 and current>=director.FINAL_RADIUS-.001,
            "zone radius reversed or breached minimum at "+str(second))
        check(stage>=last_phase and stage<=4,
            "zone stage regressed or exceeded four phases")
        last_phase=stage
        previous=current
    for phase in range(4):
        var entry: Dictionary=director.zone_state_at(float(phase)*70.0)
        var hold: Dictionary=director.zone_state_at(float(phase)*70.0+9.0)
        var close: Dictionary=director.zone_state_at(float(phase)*70.0+64.0)
        check(int(entry["phase"])==phase and
            is_equal_approx(float(entry["radius"]),float(hold["radius"])),
            "zone preparation hold missing at phase "+str(phase+1))
        check(float(close["radius"])<float(hold["radius"]),
            "zone did not physically contract during phase "+str(phase+1))
    var finished: Dictionary=director.zone_state_at(280.0)
    check(int(finished["phase"])==4 and
        is_equal_approx(float(finished["radius"]),director.FINAL_RADIUS),
        "last safe zone radius or terminal phase incorrect")

    player.global_position=Vector3(0,terrain.height_at(0,-24)+.16,-24)
    player.velocity=Vector3.ZERO
    director.start_sector_battle()
    await physics_frame
    check(director.mode=="sector_battle" and
        director.get_loot_remaining()==22,
        "real match did not start with 16 outdoor + 6 indoor pickups")
    for enemy in combat._targets:
        enemy.set_physics_process(false)
    var pickup: Area3D=director.get_node("AuroraInteriorLoot1")
    var anchor: Vector3=coastal.interior_supply_spots[0]
    check(is_equal_approx(pickup.global_position.y,anchor.y+1.08),
        "indoor loot floats on terrain or is buried below the house floor")
    var before: int=combat.medkits_remaining
    player.global_position=Vector3(anchor.x,anchor.y+.16,anchor.z)
    player.velocity=Vector3.ZERO
    await physics_frame
    await physics_frame
    pickup._collect(player)
    check(pickup.collected and combat.medkits_remaining==before+1 and
        director.get_loot_remaining()==21,
        "entering a real home cannot collect the indoor medkit")
    if not failed:
        print("V7528_COASTAL_BR PASS extra houses walked=",walked_new_houses,
            " furnished=",coastal.furnished_interiors,
            " indoor_pickups=",coastal.interior_supply_spots.size(),
            " battle_pickups=22 phases=4")
    quit(1 if failed else 0)
