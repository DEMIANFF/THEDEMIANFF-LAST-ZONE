@tool
extends EditorPlugin
## Only install this addon after verifying Gradle host Google Services and
## Firebase/Credential Manager Maven dependencies. The preview remains native
## Vulkan without the addon or an untested Firebase session.
var _android_export_plugin: EditorExportPlugin


func _enter_tree() -> void:
    _android_export_plugin=AuroraFirebaseAndroidExport.new()
    add_export_plugin(_android_export_plugin)


func _exit_tree() -> void:
    if _android_export_plugin!=null:
        remove_export_plugin(_android_export_plugin)
        _android_export_plugin=null


class AuroraFirebaseAndroidExport extends EditorExportPlugin:
    const ADDON: String="AuroraFirebase"

    func _get_name() -> String:
        return ADDON

    func _supports_platform(platform: EditorExportPlatform) -> bool:
        return platform is EditorExportPlatformAndroid

    func _get_android_libraries(_platform: EditorExportPlatform,
            debug: bool) -> PackedStringArray:
        var variant: String="debug" if debug else "release"
        return PackedStringArray([
            ADDON+"/bin/"+variant+"/"+ADDON+"-"+variant+".aar"
        ])

    func _get_android_dependencies(_platform: EditorExportPlatform,
            _debug: bool) -> PackedStringArray:
        # Do not guess versions outside the Firebase BOM. Host Gradle template
        # must add Firebase Auth, Functions, Play Integrity and Credential
        # Manager dependencies according to plugin/build.gradle.kts.
        return PackedStringArray()
