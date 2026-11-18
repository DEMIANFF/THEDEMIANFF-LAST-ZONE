extends SceneTree
## V75.124: coastal ground must support the real houses while providing
## walkable, smooth approaches rather than an 8m cliff around every lot.
## Terrain is isolated to raycast its actual heightfield, not nearby roofs.
const TERRAIN=preload("res://scripts/world/island_terrain.gd")
const RESIDENTIAL=preload("res://scripts/world/coastal_residential_layout.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75124_TERRAIN_ACCESS "+reason)

func _verify() -> void:
    var terrain: StaticBody3D=TERRAIN.new()
    terrain.name="TerrainAccessQA"
    terrain.collision_layer=3
    root.add_child(terrain)
    await physics_frame
    await physics_frame
    check(RESIDENTIAL.PAD_BLEND_WIDTH>=20.0,
        "villa platforms have a sharp short approach blend")
    var space:=terrain.get_world_3d().direct_space_state
    var directions: Array[Vector2]=[
        Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,
        Vector2(1,1).normalized(),Vector2(-1,1).normalized(),
        Vector2(1,-1).normalized(),Vector2(-1,-1).normalized()]
    var rays: int=0
    var max_graded_slope: float=0.0
    for index in range(RESIDENTIAL.HOUSE_COUNT):
        var site: Vector4=RESIDENTIAL.SITES[index]
        var center:=Vector2(site.x,site.y)
        check(absf(terrain.height_at(center.x,center.y)-
            RESIDENTIAL.PAD_HEIGHT)<.08,
            "villa "+str(index)+" has an unsupported foundation")
        for direction in directions:
            var previous_y: float=NAN
            var previous_weight: float=0.0
            for step_index in range(21):
                var distance: float=float(step_index)*2.0
                var at: Vector2=center+direction*distance
                var ground: float=terrain.height_at(at.x,at.y)
                var weight: float=RESIDENTIAL.grading_weight(at.x,at.y)
                var ray:=PhysicsRayQueryParameters3D.create(
                    Vector3(at.x,ground+18.0,at.y),
                    Vector3(at.x,ground-18.0,at.y))
                ray.collision_mask=3
                var hit: Dictionary=space.intersect_ray(ray)
                check(not hit.is_empty() and hit.get("collider")==terrain,
                    "terrain missing under villa "+str(index)+" offset "+str(distance))
                if not hit.is_empty() and hit.get("collider")==terrain:
                    check(absf((hit["position"] as Vector3).y-ground)<.08,
                        "visual/physics ground height mismatch near villa "+str(index))
                    rays+=1
                if is_finite(previous_y) and weight>.35 and previous_weight>.35:
                    var slope: float=absf(ground-previous_y)/2.0
                    max_graded_slope=maxf(max_graded_slope,slope)
                    check(slope<.95,
                        "unwalkable graded ditch/cliff at villa "+str(index)+
                        " offset "+str(distance)+" grade="+str(slope))
                previous_y=ground
                previous_weight=weight
    # Four-neighbor slope graph across the real sampled mesh. From the
    # coastal village a walking-grade route must reach the inland high ground
    # without crossing water or depending on infinite jump spam.
    var start:=Vector2i(
        roundi((RESIDENTIAL.SITES[1].x+TERRAIN.HALF_EXTENT)/TERRAIN.HEIGHT_STEP),
        roundi((RESIDENTIAL.SITES[1].y+TERRAIN.HALF_EXTENT)/TERRAIN.HEIGHT_STEP))
    var inland:=Vector2i(int(TERRAIN.CELLS/2),int(TERRAIN.CELLS/2))
    var queue: Array[Vector2i]=[start]
    var seen: Dictionary={}
    seen[start]=true
    var head: int=0
    var mountain_route: bool=false
    var reachable_peak: float=RESIDENTIAL.PAD_HEIGHT
    var cardinal: Array[Vector2i]=[
        Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]
    while head<queue.size():
        var cell: Vector2i=queue[head]
        head+=1
        var x: float=-TERRAIN.HALF_EXTENT+float(cell.x)*TERRAIN.HEIGHT_STEP
        var z: float=-TERRAIN.HALF_EXTENT+float(cell.y)*TERRAIN.HEIGHT_STEP
        var y: float=terrain.height_at(x,z)
        reachable_peak=maxf(reachable_peak,y)
        if cell==inland:
            mountain_route=true
            break
        for step in cardinal:
            var next: Vector2i=cell+step
            if next.x<0 or next.x>TERRAIN.CELLS or next.y<0 or next.y>TERRAIN.CELLS:
                continue
            if seen.has(next):
                continue
            var nx: float=-TERRAIN.HALF_EXTENT+float(next.x)*TERRAIN.HEIGHT_STEP
            var nz: float=-TERRAIN.HALF_EXTENT+float(next.y)*TERRAIN.HEIGHT_STEP
            var ny: float=terrain.height_at(nx,nz)
            if ny<0.0 or absf(ny-y)>TERRAIN.HEIGHT_STEP*.85:
                continue
            seen[next]=true
            queue.append(next)
    check(mountain_route,
        "no continuous walking-grade route from coastal homes to inland mountain")
    check(terrain.height_at(0,0)>RESIDENTIAL.PAD_HEIGHT+6.0,
        "terrain smoothing flattened the entire mountain instead of retaining high ground")
    for old in TERRAIN.LEGACY_CENTERS:
        check(absf(terrain._elevation(old.x,old.y)-
            terrain._wilderness_height(old.x,old.y))<.001,
            "grading changed the protected original town "+str(old))
    terrain.queue_free()
    await process_frame
    if not failed:
        print("V75124_TERRAIN_ACCESS PASS homes=",RESIDENTIAL.HOUSE_COUNT,
            " collider_rays=",rays," max_graded_slope=",max_graded_slope,
            " blend_width=",RESIDENTIAL.PAD_BLEND_WIDTH,
            " mountain_route=",mountain_route," visited=",seen.size())
    quit(1 if failed else 0)
