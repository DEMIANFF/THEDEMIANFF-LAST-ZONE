extends Node3D
## Mobile-minded GPU instanced Aurora forest and ice formations.
## Clearly a small sector art pass; no false 8-km landscape claim.

var terrain: StaticBody3D
const RESIDENTIAL=preload("res://scripts/world/coastal_residential_layout.gd")
const PINE_TARGET: int = 162
const ICE_TARGET: int = 88
# Decorate the four walkable 675m-world frontier peninsulas separately.
# The existing MultiMesh per material keeps GPU draw calls bounded.
const FRONTIER_SITES: Array[Vector2]=[
    Vector2(197,23),Vector2(-15,-198),
    Vector2(-194,65),Vector2(5,208)]
const FRONTIER_PINE_COUNT: int=12
const FRONTIER_ICE_COUNT: int=6
const MAX_PHYSICAL_PINES: int=22+4*FRONTIER_PINE_COUNT


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
    for n in range(1050):
        if locations.size()>=PINE_TARGET:
            break
        var x: float=rng.randf_range(-258.0,258.0)
        var z: float=rng.randf_range(-258.0,258.0)
        var p:=Vector2(x,z)
        if p.length()<29.0:
            continue
        if Vector2(x-80.0,z-80.0).length()<20.0:
            continue
        if x>-52.0 and x<89.0 and z>7.0 and z<86.0:
            continue  # Preserve the existing coastal streets.
        if RESIDENTIAL.grading_weight(x,z)>.05:
            continue  # Updated houses/ramps are not tree or collision sites.
        var y: float=terrain.height_at(x,z)
        if y<=terrain.sea_level+1.8:
            continue
        locations.append(Vector3(x,y,z))
        rotations.append(rng.randf_range(-PI,PI))
        sizes.append(rng.randf_range(.67,1.31))

    _append_frontier_instances(locations,rotations,sizes,FRONTIER_PINE_COUNT,false)

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
        var p: Vector3=locations[i]
        var at_frontier: bool=false
        for site in FRONTIER_SITES:
            if Vector2(p.x,p.z).distance_to(site)<17.0:
                at_frontier=true
                break
        # Original near-town solids remain capped; frontier trees need
        # real trunks so physical players and 49 bots cannot walk through.
        if at_frontier:
            if solid>=MAX_PHYSICAL_PINES:
                continue
        elif solid>=22 or Vector2(p.x,p.z).length()>97.0:
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
    for i in range(690):
        if locations.size()>=ICE_TARGET:
            break
        var x: float=rng.randf_range(-255.0,255.0)
        var z: float=rng.randf_range(-255.0,255.0)
        if Vector2(x,z).length()<38.0:
            continue
        if x>-52.0 and x<89.0 and z>7.0 and z<86.0:
            continue  # Retain the existing clean old streets.
        if RESIDENTIAL.grading_weight(x,z)>.05:
            continue  # Never grow crystals through a relocated residence.
        var y: float=terrain.height_at(x,z)
        if y<=terrain.sea_level+2.5:
            continue
        locations.append(Vector3(x,y,z))
        rotations.append(rng.randf_range(-PI,PI))
        sizes.append(rng.randf_range(.55,2.1))
    _append_frontier_instances(locations,rotations,sizes,FRONTIER_ICE_COUNT,true)
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


## Extend the original town scatter into the four actual physical border
## sectors; deterministic fixed budgets prevent unbounded draw calls.
func _append_frontier_instances(places: Array[Vector3],
        orientations: Array[float],sizes: Array[float],
        per_site: int,ice: bool) -> void:
    var rng:=RandomNumberGenerator.new()
    rng.seed=151124 if ice else 151125
    for site in FRONTIER_SITES:
        var planted: int=0
        for attempt in range(150):
            if planted>=per_site:
                break
            var angle: float=rng.randf_range(-PI,PI)
            var radius: float=rng.randf_range(2.0,12.5)
            var x: float=site.x+cos(angle)*radius
            var z: float=site.y+sin(angle)*radius
            if RESIDENTIAL.grading_weight(x,z)>.05:
                continue
            var y: float=terrain.height_at(x,z)
            if y<terrain.sea_level+(2.5 if ice else 1.8):
                continue
            # Skip cliff faces: tree trunks belong on usable terrain.
            if (absf(terrain.height_at(x+1.0,z)-y)>1.4 or
                    absf(terrain.height_at(x,z+1.0)-y)>1.4):
                continue
            places.append(Vector3(x,y,z))
            orientations.append(rng.randf_range(-PI,PI))
            sizes.append(rng.randf_range(.60,1.55) if ice else
                rng.randf_range(.72,1.25))
            planted+=1


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
    _sign("SIERRA ESTE",FRONTIER_SITES[0],Color(.73,.89,.97))
    _sign("SUR HELADO",FRONTIER_SITES[1],Color(.78,.92,1.0))
    _sign("VALLE OESTE",FRONTIER_SITES[2],Color(.60,.94,.88))
    _sign("PASO NORTE",FRONTIER_SITES[3],Color(.85,.91,1.0))


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
