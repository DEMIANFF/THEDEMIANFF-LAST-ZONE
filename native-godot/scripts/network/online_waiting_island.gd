extends Node3D
## Same staging outpost geometry on both processes; only the server owns bodies.
const CENTER: Vector3=Vector3(295,0,285)
const SPAWN: Vector3=Vector3(295,3.3,285)
var physical: bool=false

func _ready() -> void:
    name="AuroraWaitingIsland"
    position=CENTER
    var land:=CylinderMesh.new()
    land.top_radius=24.0
    land.bottom_radius=28.0
    land.height=8.0
    land.radial_segments=40
    var ground:=CylinderShape3D.new()
    ground.radius=24.0
    ground.height=8.0
    _piece("IslandDeck",land,ground,Vector3(0,-1,0),0.0,Color(.29,.36,.39))
    for i in range(16):
        var angle: float=TAU*float(i)/16.0
        var at:=Vector3(sin(angle)*22.0,4.25,cos(angle)*22.0)
        var rail:=BoxMesh.new()
        rail.size=Vector3(8.8,2.5,.45)
        var shape:=BoxShape3D.new()
        shape.size=rail.size
        _piece("Perimeter%02d"%i,rail,shape,at,angle,Color(.17,.29,.35))
    for i in range(4):
        var post:=BoxMesh.new()
        post.size=Vector3(.65,3,.65)
        var shape:=BoxShape3D.new()
        shape.size=post.size
        _piece("LandingMarker%d"%i,post,shape,Vector3(float(i%2*2-1)*12,4.5,float(i/2*2-1)*12),0.0,Color(.20,.69,.78))

func _piece(label: String,mesh: Mesh,shape: Shape3D,at: Vector3,yaw: float,tint: Color) -> void:
    var visual:=MeshInstance3D.new()
    visual.name=label
    visual.mesh=mesh
    visual.position=at
    visual.rotation.y=yaw
    var material:=StandardMaterial3D.new()
    material.albedo_color=tint
    material.roughness=.85
    visual.material_override=material
    add_child(visual)
    if physical:
        var body:=StaticBody3D.new()
        body.name=label+"Body"
        body.position=at
        body.rotation.y=yaw
        add_child(body)
        var collision:=CollisionShape3D.new()
        collision.shape=shape
        body.add_child(collision)
