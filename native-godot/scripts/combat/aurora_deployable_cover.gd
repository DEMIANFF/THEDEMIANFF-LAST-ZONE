extends StaticBody3D
## Original faceted ice barrier for Aurora combat. Real world collider and HP.
## This is NOT borrowed geometry or branding from another battle royale.
signal broken

const MAX_HEALTH: float=220.0
const LIFETIME_SECONDS: float=48.0

var health: float=MAX_HEALTH
var seconds_left: float=LIFETIME_SECONDS
var _destroyed: bool=false


func _ready() -> void:
    add_to_group("aurora_deployable_cover")
    collision_layer=1
    collision_mask=0

    var collider:=CollisionShape3D.new()
    collider.name="AuroraIceWallCollision"
    var shape:=BoxShape3D.new()
    shape.size=Vector3(3.45,2.30,.62)
    collider.shape=shape
    collider.position.y=1.17
    add_child(collider)

    # Five tapered hexagonal ice spires make an original Aurora silhouette.
    # Only five meshes and one collision proxy per wall: bounded mobile cost.
    var frost:=StandardMaterial3D.new()
    frost.albedo_color=Color(.20,.65,.86)
    frost.roughness=.27
    frost.metallic=.08
    var core:=StandardMaterial3D.new()
    core.albedo_color=Color(.13,.45,.67)
    core.roughness=.36
    for i in range(5):
        var deviation: int=absi(i-2)
        var height: float=2.58-float(deviation)*.16
        var pillar:=MeshInstance3D.new()
        pillar.name="AuroraCrystal"+str(i)
        var facet:=CylinderMesh.new()
        facet.top_radius=.16
        facet.bottom_radius=.43
        facet.height=height
        facet.radial_segments=6
        pillar.mesh=facet
        pillar.position=Vector3((float(i)-2.0)*.65,height*.5,0)
        pillar.material_override=frost if i%2==0 else core
        pillar.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(pillar)


func _process(delta: float) -> void:
    if _destroyed:
        return
    seconds_left=maxf(0.0,seconds_left-maxf(0.0,delta))
    if seconds_left<=0.0:
        _destroy()


func take_damage(amount: float) -> bool:
    if _destroyed or not is_finite(amount) or amount<=0.0:
        return false
    health=maxf(0.0,health-amount)
    if health<=0.0:
        _destroy()
        return true
    return false


func is_active() -> bool:
    return not _destroyed and not is_queued_for_deletion() and health>0.0 and seconds_left>0.0


func _destroy() -> void:
    if _destroyed:
        return
    _destroyed=true
    broken.emit()
    queue_free()
