extends RefCounted
## Private original-source equipment GLBs. Existing game mechanics remain
## authoritative; do not spawn third-party meshes in public APK by default.
const ROOT: String="res://assets/gear/aurora_v3_private/"
const BACKPACK: String=ROOT+"AuroraMilitaryBackpackPrivate.glb"
const HELMET: String=ROOT+"AuroraHelmetHeadsetPrivate.glb"
const VEST: String=ROOT+"AuroraTacticalCarrierPrivate.glb"
const MEDKIT: String=ROOT+"AuroraFirstAidPrivate.glb"


static func mount_optional(parent: Node3D,path: String,longest_m: float,
        desired_center: Vector3=Vector3.ZERO,
        euler: Vector3=Vector3.ZERO) -> Node3D:
    if parent==null or longest_m<=0.0 or not ResourceLoader.exists(
            path,"PackedScene"):
        return null
    var scene: PackedScene=load(path) as PackedScene
    if scene==null:
        return null
    var instance: Node3D=scene.instantiate() as Node3D
    if instance==null:
        return null
    parent.add_child(instance)
    instance.rotation=euler
    var lo:=Vector3(INF,INF,INF)
    var hi:=Vector3(-INF,-INF,-INF)
    var count: int=0
    for node in instance.find_children("*","MeshInstance3D",true,false):
        var mesh: MeshInstance3D=node as MeshInstance3D
        if mesh.mesh==null:
            continue
        count+=1
        var bound: AABB=mesh.get_aabb()
        for point in range(8):
            var at: Vector3=instance.to_local(
                mesh.to_global(bound.get_endpoint(point)))
            lo=lo.min(at)
            hi=hi.max(at)
        mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var ext: Vector3=hi-lo
    var length: float=maxf(ext.x,maxf(ext.y,ext.z))
    if count==0 or not ext.is_finite() or not is_finite(length) or length<.0001:
        instance.queue_free()
        push_warning("Invalid private equipment mesh; Aurora fallback retained: "+path)
        return null
    var factor: float=clampf(longest_m/length,.0001,100.0)
    instance.scale=Vector3.ONE*factor
    instance.position=desired_center-(instance.quaternion*((lo+hi)*.5))*factor
    return instance
