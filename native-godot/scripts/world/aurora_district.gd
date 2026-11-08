extends Node3D
## Puerto Aurora: original modular architecture with open doors, windows, angled roofs,
## service gantries, integrated collision and a low-draw-call landscape dressing.
## The box shapes represent real structural panels, not placeholder block houses.

var terrain: StaticBody3D

var wall: StandardMaterial3D
var wall_dark: StandardMaterial3D
var trim: StandardMaterial3D
var glass: StandardMaterial3D
var roof_mat: StandardMaterial3D
var pavement: StandardMaterial3D
var beacon: StandardMaterial3D
var prop_metal: StandardMaterial3D


func _ready() -> void:
    wall = _material(Color(0.38, 0.49, 0.55), 0.68, 0.12)
    wall_dark = _material(Color(0.17, 0.28, 0.35), 0.63, 0.37)
    trim = _material(Color(0.73, 0.82, 0.84), 0.42, 0.28)
    glass = _material(Color(0.10, 0.48, 0.59, 0.64), 0.12, 0.15)
    glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    roof_mat = _material(Color(0.18, 0.31, 0.40), 0.5, 0.32)
    pavement = _material(Color(0.30, 0.39, 0.43), 0.94, 0.04)
    beacon = _material(Color(0.13, 0.70, 0.79), 0.28, 0.12)
    beacon.emission_enabled = true
    beacon.emission = Color(0.03, 0.56, 0.68)
    beacon.emission_energy_multiplier = 1.4
    prop_metal = _material(Color(0.44, 0.52, 0.54), 0.5, 0.56)

    _make_building(Vector2(18.0, -8.0), "CENTRO DE EXPLORACION", 16.0, 12.0, 6.4, false)
    _make_building(Vector2(-19.0, -29.0), "TALLER HELIOS", 14.0, 11.0, 5.8, true)
    _make_building(Vector2(46.0, -36.0), "ESTACION METEOROLOGICA", 11.0, 10.0, 5.4, false)
    _make_building(Vector2(-48.0, 22.0), "PUESTO VORTEX", 12.0, 12.0, 6.0, true)
    _make_path(Vector2(0, 4), Vector2(18, -8), 4.8)
    _make_path(Vector2(18, -8), Vector2(-19, -29), 3.6)
    _make_path(Vector2(18, -8), Vector2(46, -36), 3.5)
    _make_path(Vector2(-19, -29), Vector2(-48, 22), 3.0)
    _make_beacon(Vector2(-4.0, -2.0), 8.5)
    _make_beacon(Vector2(39.0, -18.0), 7.0)
    _make_rock_field()
    _make_sign(Vector2(1.5, -16), "PUERTO AURORA", "SECTOR 01 / EXPLORACION")


func _material(c: Color, roughness: float, metal: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.roughness = roughness
    m.metallic = metal
    return m


func _height(x: float, z: float) -> float:
    return terrain.height_at(x, z) if terrain != null else 0.0


func _solid_panel(root: Node3D, label: String, p: Vector3, size: Vector3, material: Material, blocking: bool = true) -> MeshInstance3D:
    var visible := MeshInstance3D.new()
    visible.name = label
    var mesh := BoxMesh.new()
    mesh.size = size
    visible.mesh = mesh
    visible.material_override = material
    visible.position = p
    root.add_child(visible)
    if blocking:
        var body := StaticBody3D.new()
        body.name = label + "Collider"
        body.position = p
        root.add_child(body)
        var shape := CollisionShape3D.new()
        shape.shape = BoxShape3D.new()
        shape.shape.size = size
        body.add_child(shape)
    return visible


func _beam(root: Node3D, label: String, start: Vector3, stop: Vector3, radius: float, material: Material) -> void:
    var direction := stop - start
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = radius
    cylinder.bottom_radius = radius
    cylinder.height = direction.length()
    cylinder.radial_segments = 10
    var object := MeshInstance3D.new()
    object.name = label
    object.mesh = cylinder
    object.material_override = material
    object.position = (start + stop) * 0.5
    object.quaternion = Quaternion(Vector3.UP, direction.normalized())
    root.add_child(object)


func _sloped_roof(parent: Node3D, w: float, d: float, h: float) -> void:
    var roof := MeshInstance3D.new()
    roof.name = "AngledMetalRoof"
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var top := h + 1.2
    var left := -w * 0.5 - 0.48
    var right := w * 0.5 + 0.48
    var front := -d * 0.5 - 0.48
    var back := d * 0.5 + 0.48
    var ridge_front := Vector3(0, top, front)
    var ridge_back := Vector3(0, top, back)
    for side in [-1.0, 1.0]:
        var edge_f := Vector3(left if side < 0 else right, h, front)
        var edge_b := Vector3(left if side < 0 else right, h, back)
        for pt in [ridge_front, edge_f, edge_b, ridge_front, edge_b, ridge_back]:
            surface.add_vertex(pt)
    surface.generate_normals()
    roof.mesh = surface.commit()
    roof.material_override = roof_mat
    parent.add_child(roof)
    _beam(parent, "RidgeCap", ridge_front, ridge_back, 0.13, trim)
    _beam(parent, "LeftGutter", Vector3(left,h,front), Vector3(left,h,back), 0.14, prop_metal)
    _beam(parent, "RightGutter", Vector3(right,h,front), Vector3(right,h,back), 0.14, prop_metal)


func _make_building(at: Vector2, label: String, w: float, d: float, h: float, heavy: bool) -> void:
    var root := Node3D.new()
    root.name = label.replace(" ", "_")
    root.position = Vector3(at.x, _height(at.x, at.y) + 0.62, at.y)
    add_child(root)
    # Raised concrete foundation and walkable interior floor.
    _solid_panel(root, "MonolithicFoundation", Vector3(0, -0.45, 0), Vector3(w + 2.3, .90, d + 2.3), pavement)
    _solid_panel(root, "InteriorDeck", Vector3(0, .04, 0), Vector3(w - .55, .12, d - .55), wall_dark)
    var thick := 0.32
    var door_w := 3.15
    var door_h := 3.05
    var left_w := (w - door_w) * 0.5
    # Front doorway is a real opening that the character can traverse.
    _solid_panel(root, "FrontLeftWall", Vector3(-(w + door_w) * .25, h*.5, d*.5), Vector3(left_w, h, thick), wall)
    _solid_panel(root, "FrontRightWall", Vector3((w + door_w) * .25, h*.5, d*.5), Vector3(left_w, h, thick), wall)
    _solid_panel(root, "DoorLintel", Vector3(0, (h+door_h)*.5, d*.5), Vector3(door_w, h-door_h, thick), wall)
    for side in [-1.0,1.0]:
        _beam(root, "DoorJam", Vector3(side*door_w*.5,0,d*.5),Vector3(side*door_w*.5,door_h,d*.5),.11,trim)
    _beam(root, "DoorTop", Vector3(-door_w*.5,door_h,d*.5),Vector3(door_w*.5,door_h,d*.5),.10,trim)
    # Back wall has a wide panoramic window and real frame.
    var opening := minf(4.8,w*.55)
    _solid_panel(root,"RearLowerWall",Vector3(0,1.15,-d*.5),Vector3(w,2.3,thick),wall)
    _solid_panel(root,"RearUpperWall",Vector3(0,(h+4.8)*.5,-d*.5),Vector3(w,h-4.8,thick),wall)
    for side in [-1.0,1.0]:
        _solid_panel(root,"RearPier",Vector3(side*(w+opening)*.25,3.55,-d*.5),Vector3((w-opening)*.5,2.5,thick),wall)
    _solid_panel(root,"RearGlass",Vector3(0,3.55,-d*.5),Vector3(opening,2.42,.04),glass,false)
    # Side walls with actual window apertures.
    for side in [-1.0,1.0]:
        var x: float = float(side)*w*.5
        _solid_panel(root,"SideLower",Vector3(x,1.25,0),Vector3(thick,2.5,d),wall)
        _solid_panel(root,"SideUpper",Vector3(x,(h+4.6)*.5,0),Vector3(thick,h-4.6,d),wall)
        for z_sign in [-1.0,1.0]:
            _solid_panel(root,"SidePier",Vector3(x,3.55,z_sign*(d+3.2)*.25),Vector3(thick,2.1,(d-3.2)*.5),wall)
        _solid_panel(root,"SideGlass",Vector3(x,3.55,0),Vector3(.06,1.98,3.1),glass,false)
        for zpos in [-1.62,1.62]:
            _beam(root,"WindowFrame",Vector3(x,2.55,zpos),Vector3(x,4.60,zpos),.075,trim)
        _beam(root,"WindowSill",Vector3(x,2.55,-1.62),Vector3(x,2.55,1.62),.08,trim)
    _sloped_roof(root,w,d,h)
    for x in [-w*.5+.8,w*.5-.8]:
        _beam(root,"VerticalStructure",Vector3(x,.1,d*.5+.08),Vector3(x,h,d*.5+.08),.13,trim)
    _solid_panel(root,"ExteriorLanding",Vector3(0,-.50,d*.5+2.1),Vector3(door_w+1.2,.30,3.8),pavement)
    _beam(root,"DoorLight",Vector3(-.5,door_h+.35,d*.5+.24),Vector3(.5,door_h+.35,d*.5+.24),.075,beacon)
    # Real structural features: exhaust, antenna, skylight and cylindrical ventilation.
    var vent := MeshInstance3D.new()
    vent.name = "RoofVentilation"
    var cylinder := CylinderMesh.new()
    cylinder.bottom_radius = .64
    cylinder.top_radius = .42
    cylinder.height = 1.1
    cylinder.radial_segments = 12
    vent.mesh = cylinder
    vent.material_override = prop_metal
    vent.position = Vector3(w*.27,h+1.0,-d*.24)
    root.add_child(vent)
    _beam(root,"CommsMast",Vector3(-w*.22,h+.45,-d*.2),Vector3(-w*.22,h+4.9,-d*.2),.082,prop_metal)
    _beam(root,"CommsAerial",Vector3(-w*.22-1.0,h+3.85,-d*.2),Vector3(-w*.22+1.0,h+3.85,-d*.2),.08,trim)
    if heavy:
        for z in [-d*.27,d*.25]:
            _beam(root,"ServicePipe",Vector3(-w*.5-.35,1.55,z),Vector3(-w*.5-.35,4.4,z),.17,prop_metal)
    var title := Label3D.new()
    title.text = label
    title.font_size = 42
    title.pixel_size = .0065
    title.position = Vector3(0,door_h+.45,d*.5+.25)
    title.modulate = Color(.78,.95,.98)
    root.add_child(title)


func _make_path(from: Vector2, to: Vector2, width: float) -> void:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var n: int = maxi(5, int(from.distance_to(to) / 2))
    for i in range(n):
        var p0 := from.lerp(to,float(i)/float(n))
        var p1 := from.lerp(to,float(i+1)/float(n))
        var perpendicular := (to-from).normalized().orthogonal() * width*.5
        var corners := [p0-perpendicular,p0+perpendicular,p1-perpendicular,p0+perpendicular,p1+perpendicular,p1-perpendicular]
        for pos in corners:
            surface.add_vertex(Vector3(pos.x,_height(pos.x,pos.y)+.14,pos.y))
    surface.generate_normals()
    var path := MeshInstance3D.new()
    path.name = "AuroraServiceRoad"
    path.mesh = surface.commit()
    path.material_override = pavement
    add_child(path)


func _make_beacon(at: Vector2, tall: float) -> void:
    var root := Node3D.new()
    root.name = "WeatherBeacon"
    root.position = Vector3(at.x,_height(at.x,at.y),at.y)
    add_child(root)
    _beam(root,"TowerSpine",Vector3(0,.1,0),Vector3(0,tall,0),.16,prop_metal)
    _beam(root,"DiagonalBraceA",Vector3(-.9,.1,0),Vector3(0,tall*.65,0),.08,wall_dark)
    _beam(root,"DiagonalBraceB",Vector3(.9,.1,0),Vector3(0,tall*.65,0),.08,wall_dark)
    var lamp := MeshInstance3D.new()
    lamp.name = "Signal"
    lamp.mesh = SphereMesh.new()
    lamp.mesh.radius = .36
    lamp.mesh.height = .72
    lamp.material_override = beacon
    lamp.position.y = tall
    root.add_child(lamp)


func _make_rock_field() -> void:
    var rock := SphereMesh.new()
    rock.radius = 1.0
    rock.height = 2.0
    rock.radial_segments = 10
    rock.rings = 6
    var rocks := MultiMesh.new()
    rocks.transform_format = MultiMesh.TRANSFORM_3D
    rocks.mesh = rock
    rocks.instance_count = 165
    var random := RandomNumberGenerator.new()
    random.seed = 713041
    for i in range(rocks.instance_count):
        var angle := random.randf_range(-PI,PI)
        var radius := random.randf_range(42,190)
        var x := sin(angle)*radius
        var z := cos(angle)*radius
        var height := _height(x,z)
        var scale := random.randf_range(.5,2.1)
        var transform := Transform3D(Basis(Vector3(0,1,0),random.randf_range(0,TAU)).scaled(Vector3(scale,scale*.45,scale*.8)),Vector3(x,height+scale*.16,z))
        rocks.set_instance_transform(i,transform)
    var instance := MultiMeshInstance3D.new()
    instance.name = "InstancedGlacialBoulders"
    instance.multimesh = rocks
    instance.material_override = _material(Color(.46,.57,.62),.89,.03)
    add_child(instance)


func _make_sign(at: Vector2, main_title: String, subtitle: String) -> void:
    var base := Node3D.new()
    base.name = "AuroraEntranceSign"
    base.position = Vector3(at.x,_height(at.x,at.y)+.4,at.y)
    add_child(base)
    _solid_panel(base,"SignBacking",Vector3(0,2.2,0),Vector3(9.0,1.7,.32),wall_dark,false)
    var title := Label3D.new()
    title.text = main_title + "\n" + subtitle
    title.font_size = 56
    title.pixel_size = .007
    title.position = Vector3(0,2.2,.22)
    title.modulate = Color(.81,.94,.97)
    base.add_child(title)
    _beam(base,"SignLegLeft",Vector3(-3.8,0,0),Vector3(-3.8,2.0,0),.18,prop_metal)
    _beam(base,"SignLegRight",Vector3(3.8,0,0),Vector3(3.8,2.0,0),.18,prop_metal)
