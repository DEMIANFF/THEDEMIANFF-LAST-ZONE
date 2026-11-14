extends RefCounted
## One source of truth for every in-engine lobby/cosmetic screenshot filename.
## Read the real export preset version instead of carrying stale V75.xx
## names into subsequent QA jobs. No Android package or APK is generated.
static func tag() -> String:
    var preset:=ConfigFile.new()
    if preset.load("res://export_presets.cfg")!=OK:
        push_error("AURORA_CAPTURE_VERSION cannot read Godot export preset")
        return ""
    var version: String=str(preset.get_value(
        "preset.0.options","version/name",""))
    var components: PackedStringArray=version.split(".")
    if (components.size()<2 or not components[0].is_valid_int() or
            not components[1].is_valid_int()):
        push_error("AURORA_CAPTURE_VERSION invalid version/name "+version)
        return ""
    return "v"+components[0]+"-"+components[1]
