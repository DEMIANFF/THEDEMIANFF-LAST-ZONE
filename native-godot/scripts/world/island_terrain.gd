extends StaticBody3D
## Irregular continuous archipelago elevation. Not a cube, grid of houses or square island.
const CELLS: int = 96
const HALF_EXTENT: float = 225.0
const HEIGHT_STEP: float = (HALF_EXTENT * 2.0) / float(CELLS)

var sea_level: float = -2.8
var _noise: FastNoiseLite = FastNoiseLite.new()


func _init() -> void:
    _noise.seed = 171204
    _noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    _noise.frequency = 0.011
    _noise.fractal_type = FastNoiseLite.FRACTAL_FBM
    _noise.fractal_octaves = 4


func height_at(x: float, z: float) -> float:
    var main := 1.0 - Vector2(x * 0.92, z * 1.11).length() / 173.0
    var bay := 1.0 - Vector2((x - 121.0) * 1.22, z + 52.0).length() / 70.0
    var sanctuary := 1.0 - Vector2(x + 113.0, (z - 102.0) * 1.18).length() / 68.0
    var shape: float = maxf(main, maxf(bay, sanctuary))
    var coast: float = shape + _noise.get_noise_2d(x * 1.45, z * 1.45) * 0.18
    var elevation: float = pow(maxf(coast, 0.0), 1.65) * 21.0
    var hills: float = _noise.get_noise_2d(x * 2.6 + 53.0, z * 2.6) * 5.6
    return coast * 5.0 + elevation + hills * clampf(coast * 2.0, 0.0, 1.0) - 3.0


func _ready() -> void:
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
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
            normals.append(Vector3(gradient_x, 2.0 * HEIGHT_STEP, gradient_z).normalized())
            uvs.append(Vector2(float(x_index) / float(CELLS), float(z_index) / float(CELLS)))

    for z_index in range(CELLS):
        for x_index in range(CELLS):
            var index := z_index * grid_width + x_index
            indices.append_array(PackedInt32Array([index, index + grid_width, index + 1]))
            indices.append_array(PackedInt32Array([index + 1, index + grid_width, index + grid_width + 1]))

    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices

    var surface := ArrayMesh.new()
    surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var terrain_material := StandardMaterial3D.new()
    terrain_material.albedo_color = Color(0.67, 0.77, 0.79)
    terrain_material.roughness = 0.9
    surface.surface_set_material(0, terrain_material)

    var geometry := MeshInstance3D.new()
    geometry.name = "ContinuousIslandSurface"
    geometry.mesh = surface
    add_child(geometry)

    var collider := CollisionShape3D.new()
    collider.name = "HeightfieldCollision"
    collider.shape = surface.create_trimesh_shape()
    add_child(collider)
