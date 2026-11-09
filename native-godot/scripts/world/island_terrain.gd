extends StaticBody3D
## Irregular continuous archipelago elevation. Not a cube, grid of houses or square island.
const CELLS: int = 96
const HALF_EXTENT: float = 225.0
const HEIGHT_STEP: float = (HALF_EXTENT * 2.0) / float(CELLS)

var sea_level: float = -2.8
var _height_samples:=PackedFloat32Array()
var _noise: FastNoiseLite = FastNoiseLite.new()


func _init() -> void:
    _noise.seed = 171204
    _noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    _noise.frequency = 0.011
    _noise.fractal_type = FastNoiseLite.FRACTAL_FBM
    _noise.fractal_octaves = 4
    for iz in range(CELLS+1):
        for ix in range(CELLS+1):
            _height_samples.append(_elevation(-HALF_EXTENT+ix*HEIGHT_STEP,-HALF_EXTENT+iz*HEIGHT_STEP))


func height_at(x: float, z: float) -> float:
    # Match the actual triangle collider, not the continuous noise function
    # between 4.6875 m vertices. The old estimate left ramps/loot floating.
    if absf(x)>HALF_EXTENT or absf(z)>HALF_EXTENT:
        return _elevation(x,z)
    var gx: float=(x+HALF_EXTENT)/HEIGHT_STEP
    var gz: float=(z+HALF_EXTENT)/HEIGHT_STEP
    var ix: int=clampi(int(floor(gx)),0,CELLS-1)
    var iz: int=clampi(int(floor(gz)),0,CELLS-1)
    var u: float=gx-ix
    var v: float=gz-iz
    var index: int=iz*(CELLS+1)+ix
    var a: float=_height_samples[index]
    var b: float=_height_samples[index+1]
    var c: float=_height_samples[index+CELLS+1]
    var d: float=_height_samples[index+CELLS+2]
    return a+(b-a)*u+(c-a)*v if u+v<=1.0 else d+(c-d)*(1.0-u)+(b-d)*(1.0-v)


const COAST_SHELF_ELEVATION: float=7.0
const LEGACY_CENTERS: Array[Vector2]=[
    Vector2(18,-8),Vector2(-19,-29),Vector2(46,-36),Vector2(-48,22)
]


func _smooth_ramp(at: float, low: float, high: float) -> float:
    var t: float=clampf((at-low)/(high-low),0.0,1.0)
    return t*t*(3.0-2.0*t)


func _coastal_shelf_weight(x: float,z: float) -> float:
    # Only the new eastern coastal residential strip. The old exploration
    # sector and its corner approach stay on their proven V75.6 heightfield.
    var south_end: float=lerpf(18.0,8.5,
        clampf((x-20.0)/25.0,0.0,1.0))
    var south: float=_smooth_ramp(z,south_end-12.0,south_end)
    var west: float=_smooth_ramp(x,-35.0,-16.0)
    var east: float=1.0-_smooth_ramp(x,81.0,106.0)
    var north: float=1.0-_smooth_ramp(z,76.0,107.0)
    var protection: float=1.0
    for center in LEGACY_CENTERS:
        # The old walls, 8-m door approaches and graph loops are not graded.
        protection*= _smooth_ramp(Vector2(x,z).distance_to(center),25.0,29.0)
    return south*west*east*north*protection


func _wilderness_height(x: float, z: float) -> float:
    var main := 1.0 - Vector2(x * 0.92, z * 1.11).length() / 173.0
    var bay := 1.0 - Vector2((x - 121.0) * 1.22, z + 52.0).length() / 70.0
    var sanctuary := 1.0 - Vector2(x + 113.0, (z - 102.0) * 1.18).length() / 68.0
    var shape: float = maxf(main, maxf(bay, sanctuary))
    var coast: float = shape + _noise.get_noise_2d(x * 1.45, z * 1.45) * 0.18
    var elevation: float = pow(maxf(coast, 0.0), 1.65) * 21.0
    var hills: float = _noise.get_noise_2d(x * 2.6 + 53.0, z * 2.6) * 5.6
    return coast * 5.0 + elevation + hills * clampf(coast * 2.0, 0.0, 1.0) - 3.0



func _elevation(x: float,z: float) -> float:
    var old_world: float=_wilderness_height(x,z)
    return lerpf(old_world,COAST_SHELF_ELEVATION,_coastal_shelf_weight(x,z))

func _ready() -> void:
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var colors := PackedColorArray()
    var uvs := PackedVector2Array()
    var indices := PackedInt32Array()
    var grid_width := CELLS + 1

    for z_index in range(grid_width):
        for x_index in range(grid_width):
            var x := -HALF_EXTENT + float(x_index) * HEIGHT_STEP
            var z := -HALF_EXTENT + float(z_index) * HEIGHT_STEP
            var y := height_at(x, z)
            vertices.append(Vector3(x, y, z))
            var gradient_x := height_at(x - HEIGHT_STEP, z) - height_at(x + HEIGHT_STEP, z)
            var gradient_z := height_at(x, z - HEIGHT_STEP) - height_at(x, z + HEIGHT_STEP)
            var normal := Vector3(gradient_x, 2.0 * HEIGHT_STEP, gradient_z).normalized()
            normals.append(normal)
            var rock := Color(0.35, 0.45, 0.49)
            var snow := Color(0.79, 0.88, 0.90)
            var upper_snow := clampf((y + 1.0) / 23.0, 0.0, 1.0)
            var slope_rock := clampf((0.83 - normal.y) * 3.7, 0.0, 1.0)
            var coastal := clampf((y - sea_level - 0.5) / 5.0, 0.0, 1.0)
            var coastal_color := Color(0.46, 0.55, 0.55).lerp(rock, coastal)
            var natural := coastal_color.lerp(snow, upper_snow * (1.0 - slope_rock))
            colors.append(natural)
            uvs.append(Vector2(float(x_index) / float(CELLS), float(z_index) / float(CELLS)))

    for z_index in range(CELLS):
        for x_index in range(CELLS):
            var index := z_index * grid_width + x_index
            indices.append_array(PackedInt32Array([index, index + 1, index + grid_width]))
            indices.append_array(PackedInt32Array([index + 1, index + grid_width + 1, index + grid_width]))

    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices

    var surface := ArrayMesh.new()
    surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var terrain_material := StandardMaterial3D.new()
    terrain_material.albedo_color = Color.WHITE
    terrain_material.vertex_color_use_as_albedo = true
    terrain_material.roughness = 0.9
    terrain_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Visualize terrain from both sides during collision QA.
    surface.surface_set_material(0, terrain_material)

    var geometry := MeshInstance3D.new()
    geometry.name = "ContinuousIslandSurface"
    geometry.mesh = surface
    add_child(geometry)

    var collider := CollisionShape3D.new()
    collider.name = "HeightfieldCollision"
    collider.shape = surface.create_trimesh_shape()
    add_child(collider)
