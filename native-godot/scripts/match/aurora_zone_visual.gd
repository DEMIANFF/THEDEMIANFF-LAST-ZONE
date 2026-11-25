extends Node3D
## Lightweight physically placed circular hazard indicator following actual terrain.
## Server-style elimination logic remains owned by sector_director.gd.

const SEGMENTS: int = 88

var terrain: StaticBody3D
var world_center: Vector2=Vector2.ZERO
var safe_radius: float=90.0
var _surface: MeshInstance3D
var _directions:=PackedVector2Array()
var _colors:=PackedColorArray()
var _indices:=PackedInt32Array()
var _boundary_material: StandardMaterial3D
var last_height_samples: int=0
var mesh_rebuilds: int=0


func _ready() -> void:
    _surface=MeshInstance3D.new()
    _surface.name="SectorBoundaryMesh"
    _surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_surface)
    _prepare_static_geometry()
    set_zone_state(world_center,safe_radius,true)


func set_safe_radius(value: float,force: bool=false) -> void:
    set_zone_state(world_center,value,force)


func set_zone_state(center: Vector2,value: float,force: bool=false) -> void:
    # The visible ring and dangerous radius MUST have the same sub-1m
    # overtime radius; a fixed minimum of 3m misled players at match end.
    var new_radius: float=maxf(.35,value)
    if (not force and absf(new_radius-safe_radius)<.32 and
            center.distance_squared_to(world_center)<.12):
        return
    world_center=center
    safe_radius=new_radius
    if _surface==null:
        return
    # Sample each shared perimeter point once. Adjacent quads use the
    # identical terrain height instead of making two queries per segment.
    var perimeter:=PackedVector3Array()
    perimeter.resize(SEGMENTS)
    last_height_samples=0
    for i in range(SEGMENTS):
        var at: Vector2=world_center+_directions[i]*safe_radius
        perimeter[i]=Vector3(at.x,terrain.height_at(at.x,at.y)+.65,at.y)
        last_height_samples+=1
    var vertices:=PackedVector3Array()
    vertices.resize(SEGMENTS*8)
    var rim_width: float=minf(.52,safe_radius*.32)
    for i in range(SEGMENTS):
        var next: int=(i+1)%SEGMENTS
        var a: Vector3=perimeter[i]
        var b: Vector3=perimeter[next]
        var base: int=i*8
        vertices[base]=a
        vertices[base+1]=a-ca_to_3d(_directions[i])*rim_width
        vertices[base+2]=b-ca_to_3d(_directions[next])*rim_width
        vertices[base+3]=b
        vertices[base+4]=a
        vertices[base+5]=b
        vertices[base+6]=b+Vector3.UP*8.0
        vertices[base+7]=a+Vector3.UP*8.0
    var arrays: Array=[]
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX]=vertices
    arrays[Mesh.ARRAY_COLOR]=_colors
    arrays[Mesh.ARRAY_INDEX]=_indices
    var mesh:=ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    mesh.surface_set_material(0,_boundary_material)
    _surface.mesh=mesh
    mesh_rebuilds+=1


func _prepare_static_geometry() -> void:
    _directions.resize(SEGMENTS)
    _colors.resize(SEGMENTS*8)
    _indices.resize(SEGMENTS*12)
    var line: Color=Color(.30,.88,.96,.73)
    var wall_bottom: Color=Color(.19,.64,.90,.26)
    var wall_top: Color=Color(.25,.79,.92,.01)
    for i in range(SEGMENTS):
        var angle: float=TAU*float(i)/float(SEGMENTS)
        _directions[i]=Vector2(cos(angle),sin(angle))
        var v: int=i*8
        for k in range(4):
            _colors[v+k]=line
        _colors[v+4]=wall_bottom
        _colors[v+5]=wall_bottom
        _colors[v+6]=wall_top
        _colors[v+7]=wall_top
        for quad in range(2):
            var base: int=v+quad*4
            var index: int=i*12+quad*6
            _indices[index]=base
            _indices[index+1]=base+1
            _indices[index+2]=base+2
            _indices[index+3]=base
            _indices[index+4]=base+2
            _indices[index+5]=base+3
    _boundary_material=StandardMaterial3D.new()
    _boundary_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    _boundary_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    _boundary_material.cull_mode=BaseMaterial3D.CULL_DISABLED
    _boundary_material.vertex_color_use_as_albedo=true
    _boundary_material.albedo_color=Color.WHITE
    _boundary_material.emission_enabled=true
    _boundary_material.emission=Color(.10,.30,.38)
    _boundary_material.emission_energy_multiplier=.35


func ca_to_3d(value: Vector2) -> Vector3:
    return Vector3(value.x,0,value.y)

