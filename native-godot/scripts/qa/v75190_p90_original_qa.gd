extends SceneTree
const CATALOG=preload("res://scripts/combat/aurora_weapon_catalog.gd")
const CREDITS=preload("res://scripts/ui/aurora_asset_credits.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75190_P90 "+reason)

func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var combat: Node3D=game.get_node("CombatRange")
    var player: CharacterBody3D=game.get_node("Operator")
    game.get_node("AuroraSectorMatch").set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    combat.open_training_armory()
    check(combat.collect_sector_loot("weapon_p90"),"original P90 cannot enter real inventory")
    combat._equip_inventory_weapon(CATALOG.P90)
    player.set_equipped_weapon(CATALOG.P90)
    var visuals: Node3D=combat._weapon_visuals
    var model: Node3D=visuals.currently_equipped()
    var parts: Array[Node]=model.find_children("*","MeshInstance3D",true,false)
    check(parts.size()==8,"P90 original geometry was substituted or lost")
    check(combat.ammo[CATALOG.P90]==50,"P90 does not have its 50-round magazine")
    check(not visuals._source_animation_players.has(CATALOG.P90),
        "static P90 falsely advertised as an authored animated source")
    for item in parts:
        var part:=item as MeshInstance3D
        for surface in range(part.mesh.get_surface_count()):
            var material:=part.get_active_material(surface) as StandardMaterial3D
            if material and material.albedo_texture:
                check(maxi(material.albedo_texture.get_width(),
                    material.albedo_texture.get_height())<=512,
                    "unbudgeted original P90 texture in runtime")
    var controller: Node=player._animation_controller
    controller.set_process(false)
    controller.tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    for clip in ["AuroraArmedIdle","AuroraAim","AuroraCrouch","AuroraArmedWalk"]:
        controller.reset_ground_pose()
        controller.playback.start(clip)
        for frame in range(24):
            controller.tree.advance(1.0/60.0)
            await process_frame
        check(visuals._support_ik.solved,"P90 two-hand correction absent for "+clip)
        check(visuals._support_ik.last_error_m<.045 and
            visuals._support_ik.right_error_m<.045,"P90 grip detached in "+clip)
        check(visuals.equipped_global_length()>.55 and
            visuals.equipped_global_length()<1.10,"P90 imported at incorrect human scale")
    # A normal reload consumes the shared SMG reserve exactly once.
    combat.ammo[CATALOG.P90]=37
    var reserve_before: int=combat.reserve[CATALOG.MP40]
    combat._on_reload()
    check(combat.reload_timer>0.0,"P90 reload did not use the real action timer")
    combat._process(float(CATALOG.ENTRIES[CATALOG.P90].reload)+.01)
    check(combat.ammo[CATALOG.P90]==50 and
        combat.reserve[CATALOG.MP40]==reserve_before-13,"P90 reload duplicated or lost ammunition")
    var credited: bool=false
    for entry in CREDITS.MODELS:
        if str(entry.source).ends_with("080897fc0366455884b1a916684313fe"):
            credited=str(entry.author).contains("doomsentinel") and str(entry.license).contains("CC-BY-4.0")
    check(credited,"P90 author/source/license absent from the exported credits")
    var settings: CanvasLayer=(load("res://scripts/ui/aurora_settings_overlay.gd") as Script).new()
    root.add_child(settings)
    settings._show_asset_credits()
    check(settings._content.get_child_count()>=20,"credit page did not render attributed models")
    settings._close()
    game.queue_free()
    await process_frame
    if not failed:
        print("V75190_P90_ORIGINAL PASS source_meshes=8 max_texture=512 grips=4 magazine=50 ammo_conserved=1 credits=1 original_clips=0")
    call_deferred("quit",1 if failed else 0)
