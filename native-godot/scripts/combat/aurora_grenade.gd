extends Node3D

signal detonated(at: Vector3)

const FUSE_SECONDS: float=1.65
const WORLD_EDGE: float=446.0
var velocity: Vector3
var excluded: RID
var _remaining: float=FUSE_SECONDS
var _spent: bool=false


func _ready() -> void:
    var visual:=MeshInstance3D.new()
    var shell:=SphereMesh.new()
    shell.radius=.105
    shell.height=.24
    shell.radial_segments=9
    shell.rings=4
    visual.mesh=shell
    var paint:=StandardMaterial3D.new()
    paint.albedo_color=Color(.28,.34,.23)
    paint.metallic=.35
    visual.material_override=paint
    visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(visual)


func _physics_process(delta: float) -> void:
    velocity.y-=17.5*delta
    var next: Vector3=global_position+velocity*delta
    if global_position.distance_squared_to(next)>.000001:
        var query:=PhysicsRayQueryParameters3D.create(global_position,next,1,[excluded])
        var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
        if not hit.is_empty():
            var normal: Vector3=hit["normal"]
            next=hit["position"]+normal*.10
            velocity=velocity.bounce(normal)*.43
    global_position=next
    if not next.is_finite() or absf(next.x)>WORLD_EDGE or absf(next.z)>WORLD_EDGE or next.y< -18.0:
        cancel()
        return
    _remaining-=delta
    if _remaining<=0.0:
        _detonate()


func _detonate() -> void:
    if _spent:
        return
    _spent=true
    detonated.emit(global_position)
    cancel()


func cancel() -> void:
    _spent=true
    set_physics_process(false)
    queue_free()
