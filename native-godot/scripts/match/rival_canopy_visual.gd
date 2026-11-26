extends RefCounted
## Shared original rival canopy geometry for the physical bot and its visual-only replica.
static func create() -> MeshInstance3D:
    var canopy:=MeshInstance3D.new()
    canopy.name="RealRivalParachute"
    var dome:=SphereMesh.new()
    dome.radius=1.38
    dome.height=.74
    dome.radial_segments=10
    dome.rings=4
    canopy.mesh=dome
    canopy.position=Vector3(0,3.15,0)
    canopy.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var fabric:=StandardMaterial3D.new()
    fabric.albedo_color=Color(.33,.66,.88)
    fabric.roughness=.90
    canopy.material_override=fabric
    return canopy
