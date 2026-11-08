extends Node3D
## Mobile-minded GPU instanced Aurora forest and ice formations.
## Clearly a small sector art pass; no false 8-km landscape claim.

var terrain: StaticBody3D
const PINE_TARGET: int = 110
const ICE_TARGET: int = 62


func _ready() -> void:
    _add_trees()
    _add_ice_spires()
    _place_sector_signs()


func _add_trees() -> void:
    var rng:=RandomNumberGenerator.new()
    rng.seed=745902
    var locations: Array[Vector3]=[]
    var rotations: Array[float]=[]
    var sizes: Array[float]=[]
    for n in range(550):
        if locations.size()>=PINE_TARGET:
            break
        var x: float=rng.randf_range(-154.0,154.0)
        var z: float=rng.randf_range(-152.0,152.0)
        var p:=Vector2(x,z)
        if p.length()<29.0:
            continue
        if Vector2(x-80.0,z-80.0).length()<20.0:
            continue
        var y: float=terrain.height_at(x,z)
        if y<=terrain.sea_level+1.8:
            continue
        locations.append(Vector3(x,y,z))
        rotations.append(rng.randf_range(-PI,PI))
        sizes.append(rng.randf_range(.67,1.31))

    var bark:=CylinderMesh.new()
    bark.top_radius=.14
    bark.bottom_radius=.24
    bark.height=2.7
    bark.radial_segments=7
    var material_bark:=StandardMaterial3D.new()
    material_bark.albedo_color=Color(.17,.22,.23)
    material_bark.roughness=.93
    bark.material=material_bark

    var crown:=CylinderMesh.new()
    crown.top_radius=.05
    crown.bottom_radius=1.34
    crown.height=5.0
    crown.radial_segments=7
    crown.rings=1
    var foliage:=StandardMaterial3D.new()
    foliage.albedo_color=Color(.065,.23,.27)
    foliage.roughness=.87
    foliage.emission_enabled=true
    foliage.emission=Color(.025,.21,.23)
    foliage.emission_energy_multiplier=.18
    crown.material=foliage

    _instance_mesh("AuroraPineTrunks",bark,locations,rotations,sizes,1.35)
    _instance_mesh("AuroraPineCrowns",crown,locations,rotations,sizes,4.0)

    # Solid trunks in reachable sector: player and bots cannot pass through
    # nearby trees. Distant scatter remains cheap non-collision scenery.
    var solid: int=0
    for i in range(locations.size()):
        if solid>=22:
            break
        var p: Vector3=locations[i]
        if Vector2(p.x,p.z).length()>97.0:
            continue
        var body:=StaticBody3D.new()
        body.name="AuroraPineSolid"+str(i)
        body.position=p
        var collider:=CollisionShape3D.new()
        var capsule:=CapsuleShape3D.new()
        capsule.radius=.24*sizes[i]
        capsule.height=2.6*sizes[i]
        collider.shape=capsule
        collider.position.y=1.35*sizes[i]
        body.add_child(collider)
        add_child(body)
        solid+=1


func _add_ice_spires() -> void:
    var rng:=RandomNumberGenerator.new()
    rng.seed=190142
    var locations: Array[Vector3]=[]
    var rotations: Array[float]=[]
    var sizes: Array[float]=[]
    for i in range(390):
        if locations.size()>=ICE_TARGET:
            break
        var x: float=rng.randf_range(-160.0,160.0)
        var z: float=rng.randf_range(-155.0,155.0)
        if Vector2(x,z).length()<38.0:
            continue
        var y: float=terrain.height_at(x,z)
        if y<=terrain.sea_level+2.5:
            continue
        locations.append(Vector3(x,y,z))
        rotations.append(rng.randf_range(-PI,PI))
        sizes.append(rng.randf_range(.55,2.1))
    var crystal:=CylinderMesh.new()
    crystal.radial_segments=5
    crystal.top_radius=.0
    crystal.bottom_radius=.74
    crystal.height=3.2
    var ice:=StandardMaterial3D.new()
    ice.albedo_color=Color(.43,.79,.88)
    ice.roughness=.23
    ice.metallic=.12
    ice.emission_enabled=true
    ice.emission=Color(.11,.42,.61)
    ice.emission_energy_multiplier=.45
    crystal.material=ice
    _instance_mesh("LuminescentIceCrystals",crystal,locations,rotations,sizes,1.6)


func _instance_mesh(title: String,mesh: Mesh,places: Array[Vector3],orientations: Array[float],sizes: Array[float],vertical: float) -> void:
    if places.is_empty():
        return
    var gpu:=MultiMesh.new()
    gpu.transform_format=MultiMesh.TRANSFORM_3D
    gpu.mesh=mesh
    gpu.instance_count=places.size()
    for i in range(places.size()):
        var scale: float=sizes[i]
        var basis:=Basis(Vector3.UP,orientations[i]).scaled(Vector3.ONE*scale)
        var center: Vector3=places[i]+Vector3(0,vertical*scale,0)
        gpu.set_instance_transform(i,Transform3D(basis,center))
    var draw:=MultiMeshInstance3D.new()
    draw.name=title
    draw.multimesh=gpu
    draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(draw)


func _place_sector_signs() -> void:
    _sign("PUERTO AURORA",Vector2(-8,-32),Color(.59,.92,.98))
    _sign("BOSQUE LUMINICO / SECTOR",Vector2(105,87),Color(.57,.97,.79))
    _sign("GLACIAR ESPEJO / SECTOR",Vector2(-118,94),Color(.74,.93,1.0))


func _sign(label: String,at: Vector2,color: Color) -> void:
    var marker:=Label3D.new()
    marker.name=label.replace(" ","_").replace("/","_")
    marker.text=label
    marker.position=Vector3(at.x,terrain.height_at(at.x,at.y)+6.0,at.y)
    marker.font_size=48
    marker.pixel_size=.007
    marker.outline_size=8
    marker.modulate=color
    marker.no_depth_test=false
    add_child(marker)
