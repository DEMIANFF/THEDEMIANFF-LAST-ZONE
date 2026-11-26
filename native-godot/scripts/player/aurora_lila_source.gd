extends RefCounted
## Single source selection for the playable operator and every female lobby preview.
## Only the exact reviewed, bundled Godot scene is accepted in debug builds.
## No downloading, no arbitrary resource loading, no private asset in public APK.
const PRIVATE_PATH: String="user://lila_private/Lila_Rev9_LOD_privada.scn"
const PRIVATE_SHA: String="236056e220607d9e8920b5be924e12ef84ba88e5a928edae5e46b43fe7b419e3"
const PRIVATE_BYTES: int=37055211
const PUBLIC_PATH: String="res://assets/characters/lila_aurora.glb"

static func scene() -> PackedScene:
    if OS.is_debug_build() and FileAccess.file_exists(PRIVATE_PATH):
        var file:=FileAccess.open(PRIVATE_PATH,FileAccess.READ)
        if file!=null:
            var size: int=file.get_length()
            file.close()
            if size==PRIVATE_BYTES and FileAccess.get_sha256(PRIVATE_PATH)==PRIVATE_SHA:
                var private_scene: PackedScene=ResourceLoader.load(PRIVATE_PATH,"PackedScene") as PackedScene
                if private_scene!=null and private_scene.can_instantiate():
                    print("AURORA_LILA_SOURCE private_rev9_lod sha256=",PRIVATE_SHA)
                    return private_scene
        push_warning("AURORA_LILA_SOURCE invalid private scene; using bundled Lila")
    return load(PUBLIC_PATH) as PackedScene if ResourceLoader.exists(PUBLIC_PATH,"PackedScene") else null

static func tag_instance(visual: Node3D, source: PackedScene) -> void:
    if visual!=null and source!=null:
        visual.set_meta("aurora_private_lila_rev9",source.resource_path==PRIVATE_PATH)
