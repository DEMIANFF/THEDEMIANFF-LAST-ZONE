extends SceneTree
## Unit geometry only: does not replace inspection of actual user GLBs.
const CATALOG=preload("res://scripts/combat/aurora_weapon_catalog.gd")
const VISUALS=preload("res://scripts/combat/weapon_visuals.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool, message: String) -> void:
    if not ok:
        failed=true
        push_error("AURORA_OPTIONAL_VISUAL "+message)


func _extents_of(visual: Node3D) -> Vector3:
    var smallest:=Vector3(INF,INF,INF)
    var largest:=Vector3(-INF,-INF,-INF)
    for item in visual.find_children("*","MeshInstance3D",true,false):
        var mesh: MeshInstance3D=item as MeshInstance3D
        var bounds: AABB=mesh.get_aabb()
        for i in range(8):
            var point: Vector3=mesh.to_global(bounds.get_endpoint(i))
            smallest=smallest.min(point)
            largest=largest.max(point)
    return largest-smallest


func _verify() -> void:
    var holder:=Node3D.new()
    holder.name="OptionalGeometryUnitFixture"
    root.add_child(holder)
    for info in [
        {"slot":CATALOG.HK416,"raw":86.63,"target":1.10},
        {"slot":CATALOG.P90,"raw":1234.55,"target":.76},
        {"slot":CATALOG.VSS,"raw":.893,"target":1.05}
    ]:
        var slot: int=info["slot"]
        var raw_length: float=info["raw"]
        var target: float=info["target"]
        var visual:=Node3D.new()
        visual.name="GeometryUnitFixture"+str(slot)
        holder.add_child(visual)
        var box:=BoxMesh.new()
        box.size=(Vector3(raw_length,raw_length*.22,raw_length*.10)
            if slot!=CATALOG.VSS else
            Vector3(raw_length*.10,raw_length*.18,raw_length))
        var part:=MeshInstance3D.new()
        part.mesh=box
        visual.add_child(part)
        VISUALS.calibrate_expansion(visual,slot)
        var span: Vector3=_extents_of(visual)
        var measured: float=maxf(span.x,maxf(span.y,span.z))
        check(is_finite(measured) and absf(measured-target)<.04,
            "source-unit normalization failed slot "+str(slot)+
            " actual="+str(measured))
        check(visual.find_child("SupportGrip",true,false) is Node3D and
            visual.find_child("Muzzle",true,false) is Node3D,
            "real hand and projectile attachment markers missing")
        visual.queue_free()
    holder.queue_free()
    await process_frame
    if not failed:
        print("AURORA_V2_OPTIONAL_VISUAL PASS synthetic_unit_fixtures=3 "+
            "source_geometry_imports_not_claimed=1")
    quit(1 if failed else 0)
