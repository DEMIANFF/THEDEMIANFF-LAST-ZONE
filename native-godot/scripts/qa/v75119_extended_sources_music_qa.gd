extends SceneTree
## Ground truth: no visual/audio claim when the private source is absent.
const CATALOG=preload("res://scripts/combat/aurora_weapon_catalog.gd")
const FRONT_MUSIC=preload("res://scripts/audio/aurora_lobby_music_service.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V75119_EXPANDED_SOURCES "+message)


func _verify() -> void:
    var expected: Array[Dictionary]=[
        {"slot":CATALOG.MP5,"id":"MP5","clips":3},
        {"slot":CATALOG.SHOTGUN,"id":"SHOTGUN","clips":7},
        {"slot":CATALOG.MAGNUM,"id":"MAGNUM","clips":5},
        {"slot":CATALOG.KNIFE,"id":"KNIFE","clips":4},
        {"slot":CATALOG.SNIPER,"id":"SNIPER","clips":6}
    ]
    check(CATALOG.ENTRIES.size()==13,"expanded catalog did not preserve all 13 slots")
    var staged: int=0
    for spec in expected:
        var slot: int=int(spec["slot"])
        var path: String=str(CATALOG.ENTRIES[slot]["asset"])
        check(path.begins_with("res://assets/weapons/aurora_v3_extended/"),
            "source asset path escaped private staging: "+path)
        if not ResourceLoader.exists(path):
            continue
        staged+=1
        var packed:=load(path) as PackedScene
        check(packed!=null,"staged GLB not an imported scene: "+path)
        if packed==null:
            continue
        var weapon: Node3D=packed.instantiate() as Node3D
        check(weapon!=null,"staged GLB has no Node3D root: "+path)
        if weapon==null:
            continue
        root.add_child(weapon)
        var animator: AnimationPlayer=weapon.find_child(
            "*AnimationPlayer*",true,false) as AnimationPlayer
        check(animator!=null,"staged original missing AnimationPlayer: "+path)
        if animator:
            check(animator.get_animation_list().size()>=int(spec["clips"]),
                "original skeleton animation clips lost: "+path)
        var meshes: Array[Node]=weapon.find_children("*","MeshInstance3D",true,false)
        check(meshes.size()>=1,"source has no visible meshes: "+path)
        weapon.queue_free()
    # Music must be the user's real converted recording, not a synthesized
    # replacement. Absence is a truthful silent fallback.
    var lobby_track: String="res://assets/audio/aurora_v3_addendum/aurora_lobby_loop.ogg"
    check(FRONT_MUSIC.TRACK=="aurora_lobby_loop.ogg",
        "lobby music service points away from user's source")
    if ResourceLoader.exists(lobby_track):
        check(load(lobby_track) is AudioStream,
            "lobby BGM staged but Godot cannot import audio")
    await process_frame
    if not failed:
        print("V75119_EXPANDED_SOURCES PASS source_slots=5 source_glbs_staged=",
            staged," original_clips_if_present=1 lobby_music_import_if_present=1")
    quit(1 if failed else 0)
