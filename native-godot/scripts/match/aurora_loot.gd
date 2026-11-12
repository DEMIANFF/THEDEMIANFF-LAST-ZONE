extends Area3D
## Touchable actual 3D ammo/medkit cache. Triggered by CharacterBody3D proximity.

var pickup_type: String = "ammo_ar"
var player: CharacterBody3D
var combat: Node3D
var terrain: StaticBody3D
var world_spot: Vector2=Vector2.ZERO
# A valid override is the top surface of an elevated walkable house floor.
# Exterior loot uses the terrain mesh exactly as before.
var surface_height_override: float=NAN
var collected: bool=false
var _visual: Node3D
var _phase: float=0.0
var _pickup_clock: float=0.0

func _ready() -> void:
    monitoring=true
    monitorable=true
    collision_layer=0
    collision_mask=1
    var surface_y: float=surface_height_override if is_finite(surface_height_override) else         terrain.height_at(world_spot.x,world_spot.y)
    # Pod center is 0.50m above the real support surface (floor/terrain).
    # The previous 1.08m offset detached pickups from indoor floors, and
    # made loot appear misplaced from a third-person camera.
    global_position=Vector3(world_spot.x,surface_y+.50,world_spot.y)
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
    match pickup_type:
        "medkit": material.albedo_color=Color(.18,.79,.75)
        "ammo_ar": material.albedo_color=Color(.89,.66,.21)
        "cover_charge": material.albedo_color=Color(.26,.71,.97)
        "armor_plate": material.albedo_color=Color(.32,.84,.52)
        "backpack": material.albedo_color=Color(.93,.51,.23)
        "weapon_awm": material.albedo_color=Color(.98,.34,.40)
        _: material.albedo_color=Color(.56,.43,.95)
    material.emission_enabled=true
    material.emission=material.albedo_color
    material.emission_energy_multiplier=.55
    item.material_override=material
    _visual.add_child(item)
    if pickup_type=="weapon_awm":
        # Use the actual authored sniper GLB, not a decorative placeholder.
        item.visible=not _add_ground_weapon_visual()
    var ring:=MeshInstance3D.new()
    ring.name="SupplyBeacon"
    var ring_mesh:=CylinderMesh.new()
    ring_mesh.top_radius=.59
    ring_mesh.bottom_radius=.59
    ring_mesh.height=.055
    ring_mesh.radial_segments=14
    ring.mesh=ring_mesh
    ring.position.y=-.41
    ring.material_override=material
    _visual.add_child(ring)
    var floating_name:=Label3D.new()
    floating_name.name="SupplyLabel"
    match pickup_type:
        "medkit": floating_name.text="BOTIQUIN"
        "ammo_ar": floating_name.text="MUNICION AR"
        "cover_charge": floating_name.text="BARRERA +1"
        "armor_plate": floating_name.text="CHALECO AURORA"
        "backpack": floating_name.text="MOCHILA TACTICA"
        "weapon_awm": floating_name.text="RECOGER AWM"
        _: floating_name.text="MUNICION AWM"
    floating_name.font_size=44 if pickup_type=="weapon_awm" else 38
    floating_name.pixel_size=.005
    floating_name.position.y=1.72 if pickup_type=="weapon_awm" else .94
    floating_name.modulate=Color(1,.89,.48) if pickup_type=="weapon_awm"         else Color(.85,.99,1.0)
    floating_name.no_depth_test=pickup_type=="weapon_awm"
    _visual.add_child(floating_name)
    if pickup_type=="weapon_awm":
        # Distinct amber navigation column at the real weapon pickup:
        # players can spot it among other loot from ground-level camera.
        var beam:=MeshInstance3D.new()
        beam.name="AWMWorldBeacon"
        var pillar:=CylinderMesh.new()
        pillar.top_radius=.055
        pillar.bottom_radius=.055
        pillar.height=5.4
        pillar.radial_segments=8
        beam.mesh=pillar
        beam.position.y=2.5
        var lamp:=StandardMaterial3D.new()
        lamp.albedo_color=Color(1,.68,.12,.48)
        lamp.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
        lamp.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
        lamp.emission_enabled=true
        lamp.emission=Color(1,.64,.09)
        lamp.emission_energy_multiplier=1.5
        beam.material_override=lamp
        _visual.add_child(beam)
    body_entered.connect(_collect)


func _add_ground_weapon_visual() -> bool:
    var path: String="res://assets/weapons/aurora_awm.glb"
    if not ResourceLoader.exists(path):
        return false
    var packed:=load(path) as PackedScene
    if packed==null:
        return false
    var rifle:=packed.instantiate() as Node3D
    rifle.name="PickupAWMModel"
    _visual.add_child(rifle)
    var lower:=Vector3(INF,INF,INF)
    var upper:=Vector3(-INF,-INF,-INF)
    for node in rifle.find_children("*","MeshInstance3D",true,false):
        var part:=node as MeshInstance3D
        var bounds: AABB=part.get_aabb()
        for corner in range(8):
            var vertex: Vector3=rifle.to_local(part.to_global(bounds.get_endpoint(corner)))
            lower=lower.min(vertex)
            upper=upper.max(vertex)
    var extent: Vector3=upper-lower
    var length: float=maxf(extent.x,maxf(extent.y,extent.z))
    if not is_finite(length) or length<.0001:
        rifle.queue_free()
        return false
    rifle.scale=Vector3.ONE*clampf(1.30/length,.0001,100.0)
    if extent.x>extent.y and extent.x>extent.z:
        rifle.rotation.y=PI*.5
    elif extent.y>extent.z:
        rifle.rotation.x=-PI*.5
    rifle.position.y=.10
    return true


func _process(delta: float) -> void:
    if collected:
        return
    _pickup_clock-=delta
    if _pickup_clock<=0:
        _pickup_clock=.3
        if global_position.distance_to(player.global_position+Vector3.UP)<1.65:
            _collect(player)
    _phase+=delta
    _visual.position.y=sin(_phase*2.6)*.045
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
