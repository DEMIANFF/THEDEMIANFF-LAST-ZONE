extends Area3D
## Touchable actual 3D ammo/medkit cache. Triggered by CharacterBody3D proximity.

var pickup_type: String = "ammo_ar"
var player: CharacterBody3D
var combat: Node3D
var terrain: StaticBody3D
var world_spot: Vector2=Vector2.ZERO
var collected: bool=false
var _visual: Node3D
var _phase: float=0.0
var _pickup_clock: float=0.0

func _ready() -> void:
    monitoring=true
    monitorable=true
    collision_layer=0
    collision_mask=1
    global_position=Vector3(world_spot.x,terrain.height_at(world_spot.x,world_spot.y)+1.08,world_spot.y)
    var sphere:=SphereShape3D.new()
    sphere.radius=1.65
    var shape:=CollisionShape3D.new()
    shape.name="LootPickupRange"
    shape.shape=sphere
    add_child(shape)
    _visual=Node3D.new()
    _visual.name="SupplyCacheVisual"
    add_child(_visual)
    var item:=MeshInstance3D.new()
    item.name="AuroraSupplyPod"
    var mesh:=SphereMesh.new()
    mesh.radius=.48
    mesh.height=.82
    mesh.radial_segments=12
    mesh.rings=5
    item.mesh=mesh
    var material:=StandardMaterial3D.new()
    material.metallic=.52
    material.roughness=.31
    material.albedo_color=Color(.18,.79,.75) if pickup_type=="medkit" else Color(.89,.66,.21) if pickup_type=="ammo_ar" else Color(.56,.43,.95)
    material.emission_enabled=true
    material.emission=material.albedo_color
    material.emission_energy_multiplier=.55
    item.material_override=material
    _visual.add_child(item)
    var ring:=MeshInstance3D.new()
    ring.name="SupplyBeacon"
    var ring_mesh:=CylinderMesh.new()
    ring_mesh.top_radius=.59
    ring_mesh.bottom_radius=.59
    ring_mesh.height=.055
    ring_mesh.radial_segments=14
    ring.mesh=ring_mesh
    ring.position.y=-.48
    ring.material_override=material
    _visual.add_child(ring)
    var floating_name:=Label3D.new()
    floating_name.name="SupplyLabel"
    floating_name.text="BOTIQUIN" if pickup_type=="medkit" else "MUNICION AR" if pickup_type=="ammo_ar" else "MUNICION AWM"
    floating_name.font_size=38
    floating_name.pixel_size=.005
    floating_name.position.y=.94
    floating_name.modulate=Color(.85,.99,1.0)
    floating_name.no_depth_test=false
    _visual.add_child(floating_name)
    body_entered.connect(_collect)


func _process(delta: float) -> void:
    if collected:
        return
    _pickup_clock-=delta
    if _pickup_clock<=0:
        _pickup_clock=.3
        if global_position.distance_to(player.global_position+Vector3.UP)<1.65:
            _collect(player)
    _phase+=delta
    _visual.position.y=sin(_phase*2.6)*.17
    _visual.rotation.y+=delta*.95


func _collect(body: Node3D) -> void:
    if collected or body!=player:
        return
    var ray:=PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP,global_position)
    ray.exclude=[player.get_rid()]
    if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
        return
    if combat.collect_sector_loot(pickup_type):
        collected=true
        set_deferred("monitoring",false)
        _visual.visible=false
        queue_free()
