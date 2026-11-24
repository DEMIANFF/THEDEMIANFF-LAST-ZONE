extends StaticBody3D
## Authentic one-shot physical BR supply locker. It never grants inventory
## items, combat damage, coins, experience or synthetic match results.
## The match director validates distance/line-of-sight before opening and
## instantiates normal Area3D pickups from the stored authored contents.

signal locker_opened(locker: StaticBody3D)

var sector_id: int=0
var authored_contents: Array[String]=[]
var terrain: StaticBody3D
var site: Vector2=Vector2.ZERO
var opened: bool=false

var _hinge: Node3D
var _caption: Label3D

static func is_in_reach(observer: Vector3,target: Vector3,
        radius: float=2.8) -> bool:
    if (not observer.is_finite() or not target.is_finite() or
            not is_finite(radius) or radius<=0.0 or radius>4.0):
        return false
    if absf(observer.y-target.y)>2.1:
        return false
    return Vector2(observer.x,observer.z).distance_squared_to(
        Vector2(target.x,target.z))<=radius*radius


func _ready() -> void:
    collision_layer=2
    collision_mask=0
    var ground: float=float(terrain.height_at(site.x,site.y))
    global_position=Vector3(site.x,ground+.34,site.y)
    var shape:=CollisionShape3D.new()
    shape.name="SupplyLockerCover"
    var bounds:=BoxShape3D.new()
    bounds.size=Vector3(1.30,.66,.94)
    shape.shape=bounds
    add_child(shape)

    var base:=MeshInstance3D.new()
    base.name="AuthoredSteelSupplyLocker"
    var shell:=BoxMesh.new()
    shell.size=Vector3(1.28,.62,.92)
    base.mesh=shell
    base.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    base.material_override=_material(Color(.08,.16,.22),.45)
    add_child(base)
    var stripe:=MeshInstance3D.new()
    stripe.name="AuroraGoldIdentificationStripe"
    var band:=BoxMesh.new()
    band.size=Vector3(1.29,.10,.94)
    stripe.mesh=band
    stripe.position.y=.11
    stripe.material_override=_material(Color(.97,.69,.19),.24)
    stripe.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(stripe)
    _hinge=Node3D.new()
    _hinge.name="FunctionalHingedLid"
    _hinge.position=Vector3(0,.37,-.46)
    add_child(_hinge)
    var lid:=MeshInstance3D.new()
    lid.name="MetalLid"
    lid.mesh=BoxMesh.new()
    (lid.mesh as BoxMesh).size=Vector3(1.33,.12,1.00)
    lid.position.z=.46
    lid.material_override=_material(Color(.16,.28,.35),.32)
    lid.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _hinge.add_child(lid)
    _caption=Label3D.new()
    _caption.name="RealSupplyLockerLabel"
    _caption.text="DEPÓSITO AURORA %02d"%sector_id
    _caption.font_size=32
    _caption.pixel_size=.004
    _caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED
    _caption.position.y=1.0
    _caption.modulate=Color(.95,.85,.54)
    add_child(_caption)


func _material(tint: Color,metal: float) -> StandardMaterial3D:
    var material:=StandardMaterial3D.new()
    material.albedo_color=tint
    material.metallic=metal
    material.roughness=.41
    return material


## Called only after the director confirms actual on-ground operator
## proximity, wall occlusion, vehicle state and active BR round.
func open_and_release() -> Array[String]:
    if opened or authored_contents.is_empty():
        return []
    opened=true
    _caption.text="DEPÓSITO %02d / ABIERTO"%sector_id
    _caption.modulate=Color(.50,.95,.71)
    if _hinge!=null:
        var lid_tween:=create_tween()
        lid_tween.tween_property(
            _hinge,"rotation:x",-1.65,.48).set_trans(
            Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    locker_opened.emit(self)
    # Return a copy; the actual resources live in world Area3D pickups
    # created by the director. Opening alone grants NOTHING to the player.
    return authored_contents.duplicate()
