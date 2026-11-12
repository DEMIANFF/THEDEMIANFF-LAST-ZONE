extends StaticBody3D
## Irregular continuous archipelago elevation. Not a cube, grid of houses or square island.
const CELLS: int = 96
const RESIDENTIAL=preload("res://scripts/world/coastal_residential_layout.gd")
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
# Coordinates and true footprints of the original district buildings.
# They were previously excluded from coastal grading, which let the
# wilderness heightfield protrude through their raised interior decks.
const LEGACY_LOTS: Array[Vector4]=[
    Vector4(18,-8,16,12),Vector4(-19,-29,14,11),
    Vector4(46,-36,11,10),Vector4(-48,22,12,12)
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
        protection*= _smooth_ramp(Vector2(x,z).distance_to(center),25.0,28.0)
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



func legacy_grading_weight(x: float,z: float) -> Dictionary:
    # Graded historic lots prevent snow-covered mountains from entering
    # the four old houses. The level area includes floor corners, at least
    # 8m of doorway approach and approximately one terrain grid cell margin.
    var strongest: float=0.0
    var height: float=0.0
    for lot in LEGACY_LOTS:
        var dx: float=maxf(0.0,absf(x-lot.x)-(lot.z*.5+6.0))
        var back: float=lot.w*.5+6.0
        var front: float=lot.w*.5+12.0
        var dz: float=maxf(0.0,maxf(lot.y-z-back,z-lot.y-front))
        var outside: float=Vector2(dx,dz).length()
        var t: float=clampf(outside/6.0,0.0,1.0)
        var weight: float=1.0-t*t*(3.0-2.0*t)
        if weight>strongest:
            strongest=weight
            height=_wilderness_height(lot.x,lot.y)
    return {"weight":strongest,"height":height}


func _elevation(x: float,z: float) -> float:
    var old_world: float=_wilderness_height(x,z)
    var base: float=lerpf(old_world,COAST_SHELF_ELEVATION,
        _coastal_shelf_weight(x,z))
    # Both historic and newer houses rest on the actual terrain collider.
    # Keep hills outside all protected residential building footprints.
    var legacy: Dictionary=legacy_grading_weight(x,z)
    base=lerpf(base,float(legacy["height"]),float(legacy["weight"]))
    var residential: float=RESIDENTIAL.grading_weight(x,z)
    return lerpf(base,RESIDENTIAL.PAD_HEIGHT,residential)


func residential_pad_height(x: float,z: float) -> float:
    # Exposed for precise regression assertions against the shared plan.
    return RESIDENTIAL.PAD_HEIGHT if RESIDENTIAL.grading_weight(x,z)>=.999 else height_at(x,z)

func _terrain_micro_normal() -> ImageTexture:
    # Original low-memory 64x64 detail map. Snow is almost smooth while
    # glacial rock gets modest microstructure from vertex-color slope masks.
    # No parallax or expensive triplanar sampling on Motorola GPUs.
    const SIZE: int=64
    var image:=Image.create(SIZE,SIZE,false,Image.FORMAT_RGB8)
    for py in range(SIZE):
        for px in range(SIZE):
            var angle_x: float=float(px)*TAU/float(SIZE)
            var angle_y: float=float(py)*TAU/float(SIZE)
            var nx: float=.09*sin(angle_x*4.0+cos(angle_y*2.0)*.7)
            var ny: float=.09*cos(angle_y*4.0+sin(angle_x*3.0)*.7)
            var normal:=Vector3(nx,ny,1.0).normalized()
            image.set_pixel(px,py,Color(normal.x*.5+.5,
                normal.y*.5+.5,normal.z*.5+.5))
    return ImageTexture.create_from_image(image)


func _ready() -> void:
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var colors := PackedColorArray()
    var uvs := PackedVector2Array()
    var tangents:=PackedFloat32Array()
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
            # Tangent frame is mandatory for real normal mapping on custom
            # ArrayMesh surfaces. World-aligned UVs prevent 450-m stretching.
            var tangent: Vector3=(Vector3.RIGHT-normal*normal.dot(Vector3.RIGHT)).normalized()
            tangents.append_array(PackedFloat32Array([tangent.x,tangent.y,tangent.z,-1.0]))
            var rock := Color(0.35, 0.45, 0.49)
            var snow := Color(0.79, 0.88, 0.90)
            var upper_snow := clampf((y + 1.0) / 23.0, 0.0, 1.0)
            var slope_rock := clampf((0.83 - normal.y) * 3.7, 0.0, 1.0)
            var coastal := clampf((y - sea_level - 0.5) / 5.0, 0.0, 1.0)
            var coastal_color := Color(0.46, 0.55, 0.55).lerp(rock, coastal)
            var natural := coastal_color.lerp(snow, upper_snow * (1.0 - slope_rock))
            # Distinguish level residential soil from surrounding snowy,
            # mountainous terrain using existing vertex colors (zero draw
            # calls/textures added on mobile).
            var lot: float=RESIDENTIAL.grading_weight(x,z)
            natural=natural.lerp(Color(.58,.53,.43),lot*.77)
            colors.append(natural)
            uvs.append(Vector2(x/7.5,z/7.5))

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
    arrays[Mesh.ARRAY_TANGENT] = tangents
    arrays[Mesh.ARRAY_INDEX] = indices

    var surface := ArrayMesh.new()
    surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var terrain_material := StandardMaterial3D.new()
    terrain_material.albedo_color = Color.WHITE
    terrain_material.vertex_color_use_as_albedo = true
    terrain_material.roughness = 0.9
    terrain_material.normal_enabled=true
    terrain_material.normal_scale=.34
    terrain_material.normal_texture=_terrain_micro_normal()
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
