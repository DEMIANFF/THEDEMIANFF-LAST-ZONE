extends SceneTree
## The SCAR source retains four real authored skeletal clips. This test
## distinguishes the private-source import path from the static fallback.
const VISUALS=preload("res://scripts/combat/weapon_visuals.gd")
const CATALOG=preload("res://scripts/combat/aurora_weapon_catalog.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,description: String) -> void:
    if not ok:
        failed=true
        push_error("AURORA_SCAR_NATIVE_ANIMATION "+description)


func _verify() -> void:
    var source_exists: bool=ResourceLoader.exists(VISUALS.SCAR_ANIMATED_SOURCE,"PackedScene")
    check(CATALOG.SCAR==2,"historical SCAR inventory slot changed")
    check(ResourceLoader.exists(str(CATALOG.ENTRIES[CATALOG.SCAR]["asset"])),
        "original static SCAR fallback missing")
    var scene: PackedScene=load("res://scenes/Main.tscn") as PackedScene
    var game: Node3D=scene.instantiate()
    root.add_child(game)
    var operator: CharacterBody3D=game.get_node("Operator")
    var combat: Node3D=game.get_node("CombatRange")
    operator.set_physics_process(false)
    combat.set_process(false)
    for bot: CharacterBody3D in combat._targets:
        bot.set_physics_process(false)
    check(combat._weapon_visuals.add_expansion(CATALOG.SCAR),
        "SCAR source or historical fallback failed to import")
    if source_exists:
        var visual: Node3D=combat._weapon_visuals._expansion[CATALOG.SCAR]
        check(visual.name=="AuroraAnimatedScar",
            "imported animated source not used")
        var anim: AnimationPlayer=combat._weapon_visuals._source_animation_players.get(
            CATALOG.SCAR) as AnimationPlayer
        check(anim!=null,"source animation player not found in original GLB")
        if anim:
            var clips: PackedStringArray=anim.get_animation_list()
            for expected in ["idle","reload","shoot","take"]:
                var found: bool=false
                for clip in clips:
                    if str(clip).to_lower().contains(expected):
                        found=true
                        break
                check(found,"original clip not imported: "+expected)
            for action in ["idle","fire","reload"]:
                check(combat._weapon_visuals.play_source_action(CATALOG.SCAR,action),
                    "original clip failed to play: "+action)
                await process_frame
                check(not anim.current_animation.is_empty(),
                    "no active native source animation: "+action)
    else:
        check(combat._weapon_visuals._source_animation_players.is_empty(),
            "source clip falsely claimed when private GLB is absent")
    game.queue_free()
    await process_frame
    if not failed:
        print("AURORA_SCAR_NATIVE_ANIMATION PASS source_imported=",int(source_exists),
            " preserved_static_fallback=1 no_fake_source_clips=1")
    quit(1 if failed else 0)
