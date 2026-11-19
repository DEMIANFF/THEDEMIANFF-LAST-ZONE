extends SceneTree
## 675m terrain: four newly connected peninsulas with real physics geometry.
const TERRAIN=preload("res://scripts/world/island_terrain.gd")
const TACTICAL_MAP=preload("res://scripts/ui/aurora_tactical_map.gd")
const DIRECTOR=preload("res://scripts/match/sector_director.gd")
const COMBAT=preload("res://scripts/combat/training_combat.gd")
const NATURE=preload("res://scripts/world/aurora_nature.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75125_EXPANDED_WORLD "+reason)

func _verify() -> void:
    check(TERRAIN.CELLS==144 and TERRAIN.HALF_EXTENT==337.5 and
        absf(TERRAIN.HEIGHT_STEP-4.6875)<.00001,
        "terrain size or preserved original sample spacing regressed")
    check(TACTICAL_MAP.WORLD_HALF==TERRAIN.HALF_EXTENT,
        "full map still crops the new outer terrain")
    check(DIRECTOR.INITIAL_RADIUS==205.0 and
        DIRECTOR.PHASE_RADII.size()==5 and
        COMBAT.CLASSIC_BR_PARTICIPANTS==50,
        "match ring or combat roster does not fit expanded island")
    var terrain: StaticBody3D=TERRAIN.new()
    terrain.name="ExpandedRealIsland"
    terrain.collision_layer=3
    root.add_child(terrain)
    await physics_frame
    var space:=terrain.get_world_3d().direct_space_state
    var frontiers: Array[Vector2]=[
        Vector2(197,23),Vector2(-15,-198),
        Vector2(-194,65),Vector2(5,208)]
    for p in frontiers:
        var y: float=terrain.height_at(p.x,p.y)
        check(y>terrain.sea_level+5.0,
            "new frontier is underwater "+str(p)+" y="+str(y))
        var ray:=PhysicsRayQueryParameters3D.create(
            Vector3(p.x,y+25.0,p.y),Vector3(p.x,y-10.0,p.y))
        ray.collision_mask=3
        var hit: Dictionary=space.intersect_ray(ray)
        check(hit.get("collider")==terrain and
            absf((hit.get("position",Vector3.ZERO) as Vector3).y-y)<.08,
            "new terrain has no matching physical triangles "+str(p))
    var tactical_map: Control=TACTICAL_MAP.new()
    root.add_child(tactical_map)
    tactical_map.size=Vector2(1024,600)
    for p in frontiers:
        var projected: Vector2=tactical_map.project(p)
        check(tactical_map.unproject(projected).distance_to(p)<.01,
            "new full-screen map cannot locate a frontier "+str(p))
    tactical_map.terrain=terrain
    tactical_map._ensure_terrain_texture()
    check(tactical_map._terrain_texture!=null,
        "expanded physical island has no tactical map texture")
    # The newly playable peninsulas also need real scenery and collidable
    # tree trunks, not only empty triangles on an expanded minimap.
    var nature: Node3D=NATURE.new()
    nature.terrain=terrain
    root.add_child(nature)
    var pines:=nature.get_node_or_null("AuroraPineTrunks") as MultiMeshInstance3D
    var crystals:=nature.get_node_or_null("LuminescentIceCrystals") as MultiMeshInstance3D
    check(pines!=null and crystals!=null,
        "expanded frontier terrain lost its instanced 3D scenery")
    if pines!=null and crystals!=null:
        var forest: MultiMesh=pines.multimesh
        var ice: MultiMesh=crystals.multimesh
        check(forest.instance_count<=NATURE.PINE_TARGET+
                NATURE.FRONTIER_SITES.size()*NATURE.FRONTIER_PINE_COUNT and
            ice.instance_count<=NATURE.ICE_TARGET+
                NATURE.FRONTIER_SITES.size()*NATURE.FRONTIER_ICE_COUNT,
            "frontier vegetation exceeded mobile GPU instance budgets")
        for site in NATURE.FRONTIER_SITES:
            var nearby_pines: int=0
            var nearby_ice: int=0
            for i in range(forest.instance_count):
                var p: Vector3=forest.get_instance_transform(i).origin
                if Vector2(p.x,p.z).distance_to(site)<17.0:
                    nearby_pines+=1
            for i in range(ice.instance_count):
                var p: Vector3=ice.get_instance_transform(i).origin
                if Vector2(p.x,p.z).distance_to(site)<17.0:
                    nearby_ice+=1
            check(nearby_pines>=4 and nearby_ice>=2,
                "walkable outer peninsula remains barren "+str(site))
    var solid_pines: int=0
    for child in nature.get_children():
        if child is StaticBody3D and child.name.begins_with("AuroraPineSolid"):
            solid_pines+=1
            check(child.get_child(0) is CollisionShape3D,
                "expanded island pine is non-solid despite physical name")
    check(solid_pines>=30 and solid_pines<=NATURE.MAX_PHYSICAL_PINES,
        "new forest lacks physical trunks or exceeds mobile collider budget")
    nature.queue_free()
    tactical_map.queue_free()
    terrain.queue_free()
    await process_frame
    if not failed:
        print("V75125_EXPANDED_WORLD PASS 675_m_extent=1 144_cells=1 "+
            "physics_frontiers=4 map_projection=1 frontier_forest=1 "+
            "physical_trees=1 first_ring=205 players=50")
    quit(1 if failed else 0)
