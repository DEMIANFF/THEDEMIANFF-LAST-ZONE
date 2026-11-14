extends RefCounted
## Real skin overrides on original, skinned Lila tactical-armor mesh.
## Duplicating source materials preserves UVs, metallic/roughness and rig.
const ORIGINAL_SKIN: String="aurora_base"
const PALETTES: Dictionary={
    "aurora_glacier":[
        Color(.075,.19,.30),Color(.60,.89,1.0),Color(.06,.89,.99)],
    "aurora_ember":[
        Color(.19,.035,.075),Color(.92,.44,.25),Color(1.0,.60,.13)]
}


static func apply_to_operator(visual: Node3D,skin: String) -> bool:
    if visual==null or (
            skin!=ORIGINAL_SKIN and not PALETTES.has(skin)):
        return false
    var kit: MeshInstance3D=visual.find_child(
        "LilaAuroraSignatureKit",true,false) as MeshInstance3D
    if kit==null or kit.mesh==null or kit.mesh.get_surface_count()<3:
        return false
    # A legacy character or unmodified rig uses the source asset
    # untouched; no skin resource persists outside the owned profile.
    for surface in range(3):
        if skin==ORIGINAL_SKIN:
            kit.set_surface_override_material(surface,null)
            continue
        var source: Material=kit.mesh.surface_get_material(surface)
        var altered: StandardMaterial3D=(
            (source as StandardMaterial3D).duplicate() as StandardMaterial3D
            if source is StandardMaterial3D else StandardMaterial3D.new())
        altered.albedo_color=(PALETTES[skin] as Array)[surface]
        kit.set_surface_override_material(surface,altered)
    return true
