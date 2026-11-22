extends MeshInstance3D
## Real 3D contact shadow under the physical operator. The authoritative
## 1.82m character capsule, 56-bone Lila and ground triangle are unchanged.
## Mobile shadows are optional, so a tiny alpha decal keeps boots visually
## grounded on snow, stairs and concrete even in FLUIDEZ.
const SIZE: int=64


static func shadow_image() -> Image:
    var im:=Image.create(SIZE,SIZE,false,Image.FORMAT_RGBA8)
    for py in range(SIZE):
        for px in range(SIZE):
            var centered:=Vector2(
                (float(px)+.5)/float(SIZE)*2.0-1.0,
                (float(py)+.5)/float(SIZE)*2.0-1.0)
            var radius: float=centered.length()
            # Anisotropic ellipse comes from the physical plane dimensions,
            # not from additional textured geometry or painted game imagery.
            var alpha: float=pow(1.0-smoothstep(.09,.98,radius),2.0)*.38
            im.set_pixel(px,py,Color(.045,.095,.15,alpha))
    im.generate_mipmaps()
    return im


func _ready() -> void:
    name="LilaPhysicalGroundContact"
    var plane:=PlaneMesh.new()
    plane.size=Vector2(1.24,.94)
    mesh=plane
    position=Vector3(0,.024,0)
    cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var mat:=StandardMaterial3D.new()
    mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_texture=ImageTexture.create_from_image(shadow_image())
    mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    mat.cull_mode=BaseMaterial3D.CULL_DISABLED
    mat.render_priority=-1
    material_override=mat
    visible=false


func set_physical_contact(grounded: bool) -> void:
    visible=grounded
