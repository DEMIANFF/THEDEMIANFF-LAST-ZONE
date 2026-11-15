extends RefCounted
## Recolour the rig's clothing mask with the existing offline cosmetic IDs.
const ORIGINAL_SKIN: String="aurora_base"
const FABRIC_SHADER=preload("res://assets/characters/lila_fabric.gdshader")
const PALETTES: Dictionary={
    "aurora_glacier":[
        Color(.075,.19,.30),Color(.28,.65,.82),Color(.70,.93,1.0)],
    "aurora_ember":[
        Color(.19,.035,.075),Color(.66,.22,.29),Color(1.0,.60,.41)]
}


static func apply_to_operator(visual: Node3D,skin: String) -> bool:
    if visual==null or (skin!=ORIGINAL_SKIN and not PALETTES.has(skin)):
        return false
    var body:=visual.find_child("Lila_Aurora_Mesh",true,false) as MeshInstance3D
    if body==null or body.mesh==null:
        return false
    if skin==ORIGINAL_SKIN:
        body.set_surface_override_material(0,null)
        return true
    var source:=body.mesh.surface_get_material(0) as StandardMaterial3D
    if source==null or source.albedo_texture==null:
        return false
    var palette: Array=PALETTES[skin]
    var altered:=ShaderMaterial.new()
    altered.shader=FABRIC_SHADER
    altered.set_shader_parameter("source_albedo",source.albedo_texture)
    altered.set_shader_parameter("source_roughness",source.roughness)
    altered.set_shader_parameter("fabric_shadow",palette[0])
    altered.set_shader_parameter("fabric_mid",palette[1])
    altered.set_shader_parameter("fabric_light",palette[2])
    body.set_surface_override_material(0,altered)
    return true
