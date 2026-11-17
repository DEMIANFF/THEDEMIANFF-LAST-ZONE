extends SceneTree
## Regression for eight real coastal villas: two closed convex roof slopes
## per building, with visual roofing preserved and no triangle mesh physics.
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool, reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75124_ROOF "+reason)

func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var quarter: Node3D=game.get_node("PuertoAuroraCoastalQuarter")
    var player: CharacterBody3D=game.get_node("Operator")
    var combat: Node3D=game.get_node("CombatRange")
    for enemy in combat._targets:
        enemy.set_physics_process(false)
    player.set_physics_process(false)
    await physics_frame
    var roof_count: int=0
    for i in range(quarter.HOUSE_COUNT):
        var house: Node3D=quarter.get_node("AuroraCoastalVilla"+str(i))
        var roof: StaticBody3D=house.get_node("WalkableRoofCollision")
        var visual: MeshInstance3D=house.get_node("TerracottaGableRoof")
        check(visual.mesh!=null,"villa "+str(i)+" lost its roof visual")
        var gable: MeshInstance3D=house.get_node("SealedVillaGableWalls")
        check(gable.mesh!=null and gable.mesh.get_surface_count()==1,
            "villa "+str(i)+" has an open front/rear gable")
        check(roof.get_child_count()==2,"villa "+str(i)+" must have two roof slabs")
        for slab in roof.get_children():
            check(slab is CollisionShape3D and slab.shape is ConvexPolygonShape3D,
                "villa "+str(i)+" has a non-convex roof collider")
            if slab is CollisionShape3D and slab.shape is ConvexPolygonShape3D:
                check(slab.shape.points.size()==8,"roof slab lacks closed corners")
                roof_count+=1
    check(roof_count==quarter.HOUSE_COUNT*2,"missing walkable convex roof surfaces")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75124_ROOF PASS villas=8 convex_slabs=16 visual_roofs=8")
    quit(1 if failed else 0)
