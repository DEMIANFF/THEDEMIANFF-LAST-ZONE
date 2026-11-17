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
    visual.name="AuroraGrenadeShell"
    add_child(visual)
    # Original low-poly game prop: actual spoon, fuze/collar and safety ring.
    # The supplied CC BY-ND grenade model remains outside all releases until
    # its distribution rights are independently resolved. Physics is unchanged.
    _build_original_grenade_detail()


func _detail(mesh: Mesh,display: String,at: Vector3,
        rot: Vector3,material: StandardMaterial3D) -> void:
    var part:=MeshInstance3D.new()
    part.name=display
    part.mesh=mesh
    part.position=at
    part.rotation=rot
    part.material_override=material
    part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(part)


func _build_original_grenade_detail() -> void:
    var steel:=StandardMaterial3D.new()
    steel.albedo_color=Color(.21,.24,.21)
    steel.metallic=.48
    steel.roughness=.38
    var band:=StandardMaterial3D.new()
    band.albedo_color=Color(.15,.18,.15)
    band.metallic=.2
    band.roughness=.71
    var neck:=CylinderMesh.new()
    neck.top_radius=.054
    neck.bottom_radius=.073
    neck.height=.058
    neck.radial_segments=10
    _detail(neck,"AuroraFuzeCollar",Vector3(0,.130,0),Vector3.ZERO,steel)
    var lever:=BoxMesh.new()
    lever.size=Vector3(.025,.195,.065)
    _detail(lever,"AuroraSafetySpoon",Vector3(.079,.057,0),
        Vector3(0,0,-.16),steel)
    var pin:=TorusMesh.new()
    pin.inner_radius=.023
    pin.outer_radius=.036
    pin.rings=9
    pin.ring_segments=11
    _detail(pin,"AuroraSafetyPin",Vector3(.085,.174,.01),
        Vector3(PI*.5,0,0),steel)
    var seam:=CylinderMesh.new()
    seam.top_radius=.105
    seam.bottom_radius=.105
    seam.height=.017
    seam.radial_segments=12
    _detail(seam,"AuroraGripBand",Vector3(0,-.018,0),Vector3.ZERO,band)


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
