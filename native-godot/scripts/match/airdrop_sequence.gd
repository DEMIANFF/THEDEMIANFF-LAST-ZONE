extends Node3D
## Aurora offline deployment sequence: aircraft -> freefall -> parachute -> land.
## It is a playable sector prototype, not an 8km aircraft network simulation.
signal touchdown

const FLIGHT_SECONDS: float=13.0
const FLIGHT_ALTITUDE: float=97.0
const ROUTE_START_Z: float=76.0
const ROUTE_END_Z: float=-78.0

var player: CharacterBody3D
var terrain: StaticBody3D
var hud: CanvasLayer
var phase: String="inactive"
var elapsed: float=0.0
var _craft: Node3D
var _drop_requested: bool=false


func _ready() -> void:
    set_physics_process(false)


func begin() -> void:
    phase="aircraft"
    elapsed=0.0
    _drop_requested=false
    player.begin_aircraft()
    player.global_position=_route_point(0.0)
    _build_craft()
    hud.set_air_stage("aircraft")
    hud.impact("VUELO AURORA / SALTA O ESPERA EL DESPLIEGUE")
    set_physics_process(true)


func request_jump_or_parachute() -> void:
    if phase=="aircraft":
        _drop_requested=true
    elif phase=="freefall":
        deploy_parachute()


func _route_point(progress: float) -> Vector3:
    var z: float=lerpf(ROUTE_START_Z,ROUTE_END_Z,clampf(progress,0.0,1.0))
    return Vector3(0.0,terrain.height_at(0.0,z)+FLIGHT_ALTITUDE,z)


func _physics_process(delta: float) -> void:
    if phase=="aircraft":
        elapsed+=delta
        player.global_position=_route_point(elapsed/FLIGHT_SECONDS)
        if _drop_requested or elapsed>=FLIGHT_SECONDS:
            jump_from_aircraft()
    elif phase=="freefall":
        var clearance: float=player.global_position.y-terrain.height_at(player.global_position.x,player.global_position.z)
        if clearance<26.0:
            deploy_parachute()


func jump_from_aircraft() -> void:
    if phase!="aircraft":
        return
    phase="freefall"
    if _craft:
        _craft.queue_free()
        _craft=null
    player.begin_freefall()
    hud.set_air_stage("freefall")
    hud.impact("CAÍDA LIBRE / MUEVE EL JOYSTICK")


func deploy_parachute() -> void:
    if phase!="freefall":
        return
    phase="parachute"
    player.deploy_parachute()
    hud.set_air_stage("parachute")
    hud.impact("PARACAÍDAS ABIERTO / CONTROLA EL ATERRIZAJE")


func landed() -> void:
    if phase=="inactive" or phase=="landed":
        return
    phase="landed"
    set_physics_process(false)
    hud.set_air_stage("ground")
    touchdown.emit()


func _build_craft() -> void:
    if _craft:
        _craft.queue_free()
    _craft=Node3D.new()
    _craft.name="AuroraTransportAircraft"
    _craft.position=Vector3(0,.7,-1)
    player.add_child(_craft)
    var wing_material:=StandardMaterial3D.new()
    wing_material.albedo_color=Color(.15,.26,.35)
    wing_material.metallic=.45
    wing_material.roughness=.48
    var accent:=StandardMaterial3D.new()
    accent.albedo_color=Color(.12,.68,.88)
    accent.metallic=.34
    accent.roughness=.4
    var body:=CylinderMesh.new()
    body.top_radius=.46
    body.bottom_radius=.46
    body.height=5.8
    body.radial_segments=12
    _piece("TransportFuselage",body,Vector3(0,0,0),Vector3(PI*.5,0,0),wing_material)
    var wings:=BoxMesh.new()
    wings.size=Vector3(8.2,.12,1.1)
    _piece("TransportMainWings",wings,Vector3(0,-.08,-.2),Vector3.ZERO,wing_material)
    var tail:=BoxMesh.new()
    tail.size=Vector3(3.0,.10,.55)
    _piece("TailPlane",tail,Vector3(0,.12,2.0),Vector3.ZERO,wing_material)
    var fin:=BoxMesh.new()
    fin.size=Vector3(.12,1.15,.65)
    _piece("TailFin",fin,Vector3(0,.62,2.10),Vector3.ZERO,accent)
    var stripe:=BoxMesh.new()
    stripe.size=Vector3(.22,.035,3.5)
    _piece("AuroraAircraftStripe",stripe,Vector3(0,.48,0),Vector3.ZERO,accent)


func _piece(label: String,mesh: Mesh,where: Vector3,angles: Vector3,material: Material) -> void:
    var o:=MeshInstance3D.new()
    o.name=label
    o.mesh=mesh
    o.position=where
    o.rotation=angles
    o.material_override=material
    o.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _craft.add_child(o)
