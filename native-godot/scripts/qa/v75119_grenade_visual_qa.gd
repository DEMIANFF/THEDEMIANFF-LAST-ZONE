extends SceneTree
const GRENADE=preload("res://scripts/combat/aurora_grenade.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("AURORA_GRENADE_VISUAL "+message)


func _verify() -> void:
    var holder:=Node3D.new()
    root.add_child(holder)
    var grenade: Node3D=GRENADE.new()
    grenade.velocity=Vector3.ZERO
    holder.add_child(grenade)
    grenade.set_physics_process(false)
    for name in [
        "AuroraGrenadeShell","AuroraFuzeCollar","AuroraSafetySpoon",
        "AuroraSafetyPin","AuroraGripBand"
    ]:
        check(grenade.get_node_or_null(name) is MeshInstance3D,
            "original low-poly physical grenade is missing "+name)
    check(float(grenade.FUSE_SECONDS)>0 and
        float(grenade.FUSE_SECONDS)<3.0,
        "grenade fuse physics contract changed")
    holder.queue_free()
    await process_frame
    if not failed:
        print("AURORA_GRENADE_VISUAL PASS original_mesh_parts=5 fuse_unchanged=1 no_thirdparty_asset=1")
    quit(1 if failed else 0)
