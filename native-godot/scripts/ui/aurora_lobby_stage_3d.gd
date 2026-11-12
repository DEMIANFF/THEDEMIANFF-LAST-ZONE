extends Node3D
## A real original 3D stage behind Lila. No static concept art or online
## simulation. The SubViewport is disposed before a gameplay scene loads.

func _ready() -> void:
    name="AuroraLobbyHangarStage"
    var rock:=_mat(Color(.13,.23,.35))
    var snow:=_mat(Color(.72,.86,.96))
    var metal:=_mat(Color(.08,.15,.25))
    var cyan:=_glow(Color(.21,.86,1.0))
    var violet:=_glow(Color(.56,.27,.96))
    _box("PolarPlatform",Vector3(0,-.15,-3.0),Vector3(17,.13,17),rock)
    for i in range(-4,5):
        var p: float=float(i)
        _peak(Vector3(p*3.1,-.09,-11.0-absf(p)*.2),
            2.4,2.4+absf(sin(p))*.9,rock,snow)
    for side in [-1.0,1.0]:
        var x: float=side*3.25
        _box("AuroraResearchStation",Vector3(x,.91,-5.3),
            Vector3(2.3,1.82,2.5),metal)
        _box("StationRoof",Vector3(x,1.89,-5.3),
            Vector3(2.5,.15,2.7),rock)
        _box("ResearchLight",Vector3(x-side*1.15,1.1,-5.25),
            Vector3(.04,.56,1.16),cyan)
        _beam(Vector3(x,2.0,-5.3),Vector3(x,3.13,-5.3),.05,violet)
        for j in range(7):
            var z: float=.9-float(j)*.68
            _box("RunwayLight",Vector3(side*2.35,-.03,z),
                Vector3(.045,.026,.3),cyan)
    _ring(Vector3(0,1.75,-4.2),2.25,cyan)
    _ring(Vector3(0,1.75,-4.2),2.4,violet)
    _ribbon(Color(.17,.90,.83,.29),4.3,-9.6,.2)
    _ribbon(Color(.68,.31,1.0,.28),4.8,-10.0,2.1)


func _mat(color: Color) -> StandardMaterial3D:
    var m:=StandardMaterial3D.new()
    m.albedo_color=color
    m.roughness=.75
    return m


func _glow(color: Color) -> StandardMaterial3D:
    var m:=_mat(color)
    m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    m.emission_enabled=true
    m.emission=color
    m.emission_energy_multiplier=1.5
    return m


func _box(title: String,at: Vector3,size: Vector3,mat: Material) -> void:
    var node:=MeshInstance3D.new()
    node.name=title
    var mesh:=BoxMesh.new()
    mesh.size=size
    node.mesh=mesh
    node.material_override=mat
    node.position=at
    node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)


func _beam(a: Vector3,b: Vector3,r: float,mat: Material) -> void:
    var node:=MeshInstance3D.new()
    node.name="AuroraNeonBeam"
    var mesh:=CylinderMesh.new()
    mesh.radial_segments=6
    mesh.height=a.distance_to(b)
    mesh.top_radius=r
    mesh.bottom_radius=r
    node.mesh=mesh
    node.material_override=mat
    node.position=(a+b)*.5
    node.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
    add_child(node)


func _ring(origin: Vector3,radius: float,mat: Material) -> void:
    var last:=origin+Vector3(radius,0,0)
    for i in range(1,25):
        var angle: float=float(i)*TAU/24.0
        var next:=origin+Vector3(cos(angle)*radius,sin(angle)*radius,0)
        _beam(last,next,.023,mat)
        last=next


func _peak(at: Vector3,width: float,height: float,
        stone: Material,snow: Material) -> void:
    _pyramid(at,width,height,stone)
    _pyramid(at+Vector3.UP*height*.73,width*.28,height*.27,snow)


func _pyramid(at: Vector3,width: float,height: float,mat: Material) -> void:
    var builder:=SurfaceTool.new()
    builder.begin(Mesh.PRIMITIVE_TRIANGLES)
    var corners: Array[Vector3]=[
        Vector3(-width,0,-width),Vector3(width,0,-width),
        Vector3(width,0,width),Vector3(-width,0,width)]
    for j in range(4):
        builder.add_vertex(corners[j])
        builder.add_vertex(corners[(j+1)%4])
        builder.add_vertex(Vector3(0,height,0))
    builder.generate_normals()
    var shape:=MeshInstance3D.new()
    shape.name="AuroraSnowPeak"
    shape.mesh=builder.commit()
    shape.position=at
    shape.material_override=mat
    add_child(shape)


func _ribbon(tint: Color,altitude: float,depth: float,phase: float) -> void:
    var painter:=SurfaceTool.new()
    painter.begin(Mesh.PRIMITIVE_TRIANGLES)
    for j in range(18):
        var x: float=-8.0+float(j)*16.0/18.0
        var nx: float=-8.0+float(j+1)*16.0/18.0
        var y: float=altitude+sin(x*.5+phase)*.3
        var ny: float=altitude+sin(nx*.5+phase)*.3
        for v in [Vector3(x,y,depth),Vector3(nx,ny,depth),
                Vector3(x,y+.55,depth),Vector3(nx,ny,depth),
                Vector3(nx,ny+.55,depth),Vector3(x,y+.55,depth)]:
            painter.add_vertex(v)
    painter.generate_normals()
    var node:=MeshInstance3D.new()
    node.name="PolarAuroraCurtain"
    node.mesh=painter.commit()
    var mat:=StandardMaterial3D.new()
    mat.albedo_color=tint
    mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode=BaseMaterial3D.CULL_DISABLED
    mat.emission_enabled=true
    mat.emission=Color(tint.r,tint.g,tint.b)
    node.material_override=mat
    add_child(node)
