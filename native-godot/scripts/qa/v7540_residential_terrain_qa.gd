extends SceneTree
## Regression for V75.40: the eight real houses must touch the SAME flat
## physical terrain triangles their render geometry, ramps and AI stand on.
## Fails if mountain interpolation leaves any floor/corner suspended.
const RESIDENTIAL=preload("res://scripts/world/coastal_residential_layout.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7540_TERRAIN "+reason)


func _verify() -> void:
    var scene: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(scene)
    var terrain: StaticBody3D=scene.get_node("AuroraTerrain")
    var coastal: Node3D=scene.get_node("PuertoAuroraCoastalQuarter")
    var director: Node3D=scene.get_node("AuroraSectorMatch")
    var combat: Node3D=scene.get_node("CombatRange")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    await physics_frame

    check(RESIDENTIAL.HOUSE_COUNT==8 and coastal.HOUSE_COUNT==8 and
        coastal.buildings_built==8 and coastal.accessible_entries==8,
        "shared site count and constructed/collidable house count disagree")
    var worst_surface_gap: float=0.0
    var worst_pad_variation: float=0.0
    var verified_entries: int=0
    for index in range(RESIDENTIAL.HOUSE_COUNT):
        var site: Vector4=RESIDENTIAL.SITES[index]
        var house: Node3D=coastal.get_node("AuroraCoastalVilla"+str(index))
        check(is_equal_approx(house.position.x,site.x) and
            is_equal_approx(house.position.z,site.y) and
            is_equal_approx(house.rotation.y,RESIDENTIAL.YAWS[index]),
            "house "+str(index)+" no longer shares terrain site's coordinates")
        var floor: StaticBody3D=house.get_node("WalkableInteriorFloorSolid")
        var body: CollisionShape3D=floor.get_node("CollisionShape3D")
        check(body.shape is BoxShape3D,"house "+str(index)+
            " lost its physical interior floor")
        var base: float=house.global_position.y
        var center_ground: float=terrain.height_at(site.x,site.y)
        worst_surface_gap=maxf(worst_surface_gap,absf(base-center_ground))
        check(absf(base-center_ground)<=.08,
            "house "+str(index)+" foundation hovers "+str(base-center_ground)+"m")
        # Verify all floor corners and the complete 7.5m entrance ramp.
        # Each sampling point uses the real rotated 3D world coordinates.
        var high: float=-INF
        var low: float=INF
        for x in [-site.z*.5,0.0,site.z*.5]:
            for z in [-site.w*.5,0.0,site.w*.5,
                    site.w*.5+4.0,site.w*.5+7.5]:
                var position: Vector3=house.to_global(Vector3(x,0,z))
                var actual: float=terrain.height_at(position.x,position.z)
                high=maxf(high,actual)
                low=minf(low,actual)
                check(absf(actual-RESIDENTIAL.PAD_HEIGHT)<.08,
                    "house "+str(index)+" stands on sloping/non-flat land "+
                    str(Vector2(position.x,position.z))+" ground="+str(actual))
        worst_pad_variation=maxf(worst_pad_variation,high-low)
        check(high-low<.08,
            "house "+str(index)+" floor or approach crosses a hillside")
        var ramp: StaticBody3D=house.get_node("TraversableDoorRamp")
        var ramp_collider: CollisionShape3D=ramp.get_node("CollisionShape3D")
        check(ramp_collider.shape is ConvexPolygonShape3D,
            "house "+str(index)+" entrance ramp lost its convex physics")
        var far: Vector3=house.to_global(Vector3(0,0,site.w*.5+7.5))
        var ramp_shape: ConvexPolygonShape3D=ramp_collider.shape
        # Read actual hull vertices to validate the rotated ramp endpoint.
        var end_top: float=-INF
        for vertex in ramp_shape.points:
            if absf(vertex.z-(site.w*.5+7.5))<.01:
                end_top=maxf(end_top,vertex.y)
        check(is_finite(end_top) and
            absf(base+end_top-terrain.height_at(far.x,far.z))<.08,
            "rotated ramp "+str(index)+" does not meet the ground")
        var entrance: Vector2=RESIDENTIAL.entrance_world(index,7.5)
        var distance: float=entrance.distance_to(director.CENTER)
        check(distance<director.INITIAL_RADIUS,
            "house "+str(index)+" relocated outside opening safe zone")
        verified_entries+=1
    # The older four buildings and the distant mountains retain their
    # original terrain, collision shapes and navigable approach grades.
    for legacy in [Vector2(18,-8),Vector2(-19,-29),
            Vector2(46,-36),Vector2(-48,22)]:
        check(absf(terrain._elevation(legacy.x,legacy.y)-
            terrain._wilderness_height(legacy.x,legacy.y))<.001,
            "residential grading changed protected legacy lot "+str(legacy))
    for wilderness in [Vector2(-154,-133),Vector2(164,146)]:
        check(absf(terrain._elevation(wilderness.x,wilderness.y)-
            terrain._wilderness_height(wilderness.x,wilderness.y))<.001,
            "residential grading flattened wilderness mountains")
    check(verified_entries==8 and worst_surface_gap<=.08 and
        worst_pad_variation<=.08,
        "not all houses are fully supported by a level, real terrain mesh")
    if not failed:
        print("V7540_TERRAIN PASS houses=8 rotated_ramps=8 "+
            "foundation_gap=",worst_surface_gap,
            " max_pad_variation=",worst_pad_variation,
            " protected_old_sector=4 wilderness_hills=2")
    quit(1 if failed else 0)
