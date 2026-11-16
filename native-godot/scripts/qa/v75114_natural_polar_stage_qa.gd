extends SceneTree
## V75.114: inspect real Godot 3D mesh buffers, not cosmetic screenshot claims.
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75114_NATURAL_POLAR_STAGE "+reason)


func _verify() -> void:
    var stage: Node3D=(load(
        "res://scripts/ui/aurora_lobby_stage_3d.gd") as GDScript).new()
    root.add_child(stage)
    await process_frame
    # Generated mountains are direct scene children with explicit names.
    # Do not rely on find_children wildcard rules for auto-numbered Nodes.
    var peaks: Array[MeshInstance3D]=[]
    for candidate in stage.get_children():
        if candidate is MeshInstance3D and str(candidate.name).begins_with(
                "AuroraSnowPeak"):
            peaks.append(candidate as MeshInstance3D)
    check(peaks.size()==3,"the range must use near, middle and far terrain layers")
    var triangles: int=0
    var previous_near_edge: float=INF
    for node in peaks:
        var item: MeshInstance3D=node as MeshInstance3D
        check(item.mesh!=null and item.mesh.get_surface_count()==1,
            "a real polar mountain mesh/surface is missing")
        if item.mesh==null or item.mesh.get_surface_count()==0:
            continue
        var arrays: Array=item.mesh.surface_get_arrays(0)
        var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
        var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
        var coverage: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
        var bounds:=item.mesh.get_aabb()
        triangles+=floori(indices.size()/3.0)
        check(vertices.size()>1000 and indices.size()>vertices.size()
            and bounds.size.y>4.0 and bounds.size.z>10.0,
            "missing indexed ridges or terrain depth")
        var has_rock:=false
        var has_snow:=false
        for color in coverage:
            has_rock=has_rock or color.r<.10
            has_snow=has_snow or color.r>.68
        var surface:=item.material_override as ShaderMaterial
        check(has_rock and has_snow and surface!=null and
            surface.shader.resource_path.ends_with("aurora_polar_terrain.gdshader"),
            "terrain must blend the exposed rock and snowy slope material")
        check(bounds.end.z<previous_near_edge,
            "mountains are not arranged in successive depth layers")
        previous_near_edge=bounds.end.z
    check(triangles<=12000 and triangles>=8000,
        "polar terrain triangle budget exceeded or mesh detail is missing")
    check(stage.find_child("AuroraRunwayCentralSpine",true,false)!=null and
        stage.find_child("AuroraHangarRear",true,false)!=null and
        stage.find_child("PolarAuroraCurtain",true,false)!=null,
        "production stage lost its runway, hangar or polar atmosphere")
    var rotor: Node3D=stage.get("_radar_rotor") as Node3D
    var angle_before: float=rotor.rotation.y
    stage.call("_process",1.0/30.0)
    check(rotor.rotation.y!=angle_before,
        "actual 3D radar animation stopped")
    stage.queue_free()
    await process_frame
    if not failed:
        print("V75114_NATURAL_POLAR_STAGE PASS layers=3 triangles=%d animated_radar=1"
            %triangles)
    quit(1 if failed else 0)
