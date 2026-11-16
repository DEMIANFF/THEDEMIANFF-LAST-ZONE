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
    print("V75114_POLAR_DEBUG mountain_mesh_count=",peaks.size())
    check(peaks.size()==44,
        "22 distinct ridges need exactly 44 stone/frost meshes")
    var min_triangles: int=999999
    var min_peak_y: float=INF
    var frost: int=0
    var rock: int=0
    for node in peaks:
        var item: MeshInstance3D=node as MeshInstance3D
        check(item.mesh!=null and item.mesh.get_surface_count()==1,
            "a real polar mountain mesh/surface is missing")
        if item.mesh==null or item.mesh.get_surface_count()==0:
            continue
        var arrays: Array=item.mesh.surface_get_arrays(0)
        var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
        check(vertices.size()==81,
            "natural ridge must consist of 9 sectors and 27 facets")
        min_triangles=mini(min_triangles,int(vertices.size()/3))
        var highest: float=-INF
        for vertex in vertices:
            highest=maxf(highest,vertex.y)
        min_peak_y=minf(min_peak_y,highest)
        var surface: StandardMaterial3D=item.material_override as StandardMaterial3D
        check(surface!=null and surface.roughness>=.84,
            "polar rock/ice remains physically rough")
        if surface!=null:
            check(surface.albedo_color.get_luminance()<.65,
                "oversaturated bright-white mountain crown returned")
            if surface.albedo_color.r>=.3:
                frost+=1
            else:
                rock+=1
    print("V75114_POLAR_DIAGNOSTIC triangles_min=",min_triangles,
        " highest_min=",min_peak_y,
        " rock=",rock," frost=",frost)
    check(min_triangles>=27 and min_peak_y>.4 and
        rock==22 and frost==22,
        "mesh quality or rock/frost pairing failed: triangles="+
        str(min_triangles)+" min_y="+str(min_peak_y)+
        " rock="+str(rock)+" frost="+str(frost))
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
        print("V75114_NATURAL_POLAR_STAGE PASS peaks=44 "+
            "facets_per_mesh=27 rocks=22 frost=22 animated_radar=1")
    quit(1 if failed else 0)
