extends Node3D
## Lightweight physically placed circular hazard indicator following actual terrain.
## Server-style elimination logic remains owned by sector_director.gd.

const SEGMENTS: int = 88

var terrain: StaticBody3D
var world_center: Vector2=Vector2.ZERO
var safe_radius: float=90.0
var _surface: MeshInstance3D


func _ready() -> void:
    _surface=MeshInstance3D.new()
    _surface.name="SectorBoundaryMesh"
    _surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_surface)
    set_safe_radius(safe_radius,true)


func set_safe_radius(value: float,force: bool=false) -> void:
    var new_radius: float=maxf(3.0,value)
    if not force and absf(new_radius-safe_radius)<.4:
        return
    safe_radius=new_radius
    if _surface==null:
        return
    var vertices:=PackedVector3Array()
    var colors:=PackedColorArray()
    var indices:=PackedInt32Array()
    var line: Color=Color(.30,.88,.96,.73)
    var wall_bottom: Color=Color(.19,.64,.90,.26)
    var wall_top: Color=Color(.25,.79,.92,.01)
    for i in range(SEGMENTS):
        var angle_1: float=TAU*float(i)/float(SEGMENTS)
        var angle_2: float=TAU*float(i+1)/float(SEGMENTS)
        var ca:=Vector2(cos(angle_1),sin(angle_1))
        var cb:=Vector2(cos(angle_2),sin(angle_2))
        var world_a:=world_center+ca*safe_radius
        var world_b:=world_center+cb*safe_radius
        var a:=Vector3(world_a.x,terrain.height_at(world_a.x,world_a.y)+.65,world_a.y)
        var b:=Vector3(world_b.x,terrain.height_at(world_b.x,world_b.y)+.65,world_b.y)
        # Solid 0.5m luminous ground ring (paired triangles).
        _quad(vertices,colors,indices,a,a-ca_to_3d(ca)*.52,b-ca_to_3d(cb)*.52,b,line,line,line,line)
        # Atmospheric boundary. No obstacle collider: hazard affects health, not
        # physical locomotion.
        _quad(vertices,colors,indices,a,b,b+Vector3.UP*8.0,a+Vector3.UP*8.0,wall_bottom,wall_bottom,wall_top,wall_top)
    var arrays: Array=[]
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX]=vertices
    arrays[Mesh.ARRAY_COLOR]=colors
    arrays[Mesh.ARRAY_INDEX]=indices
    var mesh:=ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    var material:=StandardMaterial3D.new()
    material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    material.cull_mode=BaseMaterial3D.CULL_DISABLED
    material.vertex_color_use_as_albedo=true
    material.albedo_color=Color.WHITE
    material.emission_enabled=true
    material.emission=Color(.10,.30,.38)
    material.emission_energy_multiplier=.35
    mesh.surface_set_material(0,material)
    _surface.mesh=mesh


func ca_to_3d(value: Vector2) -> Vector3:
    return Vector3(value.x,0,value.y)


func _quad(verts: PackedVector3Array, shades: PackedColorArray, tris: PackedInt32Array,
        a: Vector3,b: Vector3,c: Vector3,d: Vector3,
        ca: Color,cb: Color,cc: Color,cd: Color) -> void:
    var base: int=verts.size()
    verts.append_array(PackedVector3Array([a,b,c,d]))
    shades.append_array(PackedColorArray([ca,cb,cc,cd]))
    tris.append_array(PackedInt32Array([base,base+1,base+2,base,base+2,base+3]))
