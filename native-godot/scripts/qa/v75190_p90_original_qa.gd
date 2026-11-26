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
    check(visuals._p90_magazine_parts.size()==2,
        "the two original P90 magazine meshes were not identified")
    var mag_rest: Array[Transform3D]=[]
    var mag_origins: Array[Vector3]=[]
    for part in visuals._p90_magazine_parts:
        mag_rest.append(part.transform)
        mag_origins.append(model.to_local(part.global_position))
    var other_parts: Dictionary={}
    for part in parts:
        if not part in visuals._p90_magazine_parts:
            other_parts[part]=part.transform
    check(combat.ammo[CATALOG.P90]==50,"P90 does not have its 50-round magazine")
    check(not visuals._source_animation_players.has(CATALOG.P90),
        "static P90 falsely advertised as an authored animated source")
    for item in parts:
        var part:=item as MeshInstance3D
        # Record actual imported mesh bounds in model coordinates for the
        # next visual audit. Never infer magazine identity from names alone.
        var low:=Vector3(INF,INF,INF)
        var high:=Vector3(-INF,-INF,-INF)
        for corner in range(8):
            var point: Vector3=model.to_local(part.to_global(part.get_aabb().get_endpoint(corner)))
            low=low.min(point)
            high=high.max(point)
        print("V75194_P90_PART ",model.get_path_to(part)," min=",low," max=",high)
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
    var cues: Array[StringName]=[]
    combat.reload_cue.connect(func(cue: StringName): cues.append(cue))
    var sound: Node=game.get_node("AuroraSoundStage")
    var audio_cursor: int=sound._cursor
    combat._on_reload()
    check(sound._cursor==audio_cursor and cues.is_empty(),
        "P90 played unrelated generic reload sound before its hand gesture")
    check(combat.reload_timer>0.0 and visuals.p90_reload_active,
        "P90 reload did not start its actual timed hand gesture")
    var reload_target: Node3D=visuals.support_grip_anchor()
    var rest: Vector3=reload_target.position
    var duration: float=float(CATALOG.ENTRIES[CATALOG.P90].reload)
    combat._process(duration*.5)
    check(is_equal_approx(visuals.p90_magazine_lift,1.0),
        "actual timed reload did not lift the original magazine")
    for i in range(visuals._p90_magazine_parts.size()):
        var part: MeshInstance3D=visuals._p90_magazine_parts[i]
        var displacement: Vector3=model.to_local(part.global_position)-mag_origins[i]
        check(absf(displacement.y*model.scale.x-.045)<.002 and
            absf(displacement.x*model.scale.x)<.002 and absf(displacement.z*model.scale.x)<.002,
            "original magazine pieces did not move together")
    for part in other_parts:
        check(part.transform.is_equal_approx(other_parts[part]),
            "reload changed unrelated original weapon geometry")
    check(cues.size()==2 and cues[0]==CATALOG.P90_RELOAD_CUES[0] and
        cues[1]==CATALOG.P90_RELOAD_CUES[1] and
        sound._cursor==(audio_cursor+2)%sound._voices.size(),
        "P90 release/contact cues were not synchronized or routed to audio")
    combat._process(0.0)
    check(cues.size()==2,"P90 repeated audio cues without advancing time")
    check(combat.ammo[CATALOG.P90]==37 and combat.reserve[CATALOG.MP40]==reserve_before,
        "P90 transferred ammunition before the timed action finished")
    check(reload_target.name=="P90ReloadHandTarget" and
        reload_target.position.distance_to(rest)>10.0 and visuals.support_grip_enabled(),
        "P90 hand failed to move to its distinct upper receiver target")
    # Evaluate real skeletal modifier through the same manual mixer path
    # used by the four existing grip fixtures. No mock hand movement.
    for frame in range(12):
        controller.tree.advance(1.0/60.0)
        await process_frame
    check(visuals._support_ik.solved and visuals._support_ik.last_error_m<.045 and
        visuals._support_ik.right_error_m<.045,
        "P90 reload loses reachable hand contact")
    combat._equip_inventory_weapon(CATALOG.AR)
    check(not visuals.p90_reload_active and reload_target.position.is_equal_approx(rest) and
        combat.ammo[CATALOG.P90]==37 and combat.reserve[CATALOG.MP40]==reserve_before,
        "weapon swap leaked reload pose or changed ammunition")
    check(cues.size()==2,"cancelled P90 reload emitted future audio")
    for i in range(visuals._p90_magazine_parts.size()):
        check(visuals._p90_magazine_parts[i].transform.is_equal_approx(mag_rest[i]),
            "cancelled reload left an original magazine mesh displaced")
    cues.clear()
    combat._equip_inventory_weapon(CATALOG.P90)
    combat._on_reload()
    combat._process(duration*.9)
    check(cues==CATALOG.P90_RELOAD_CUES and combat.ammo[CATALOG.P90]==37,
        "second reload missed its three ordered cues or transferred ammo too early")
    combat._process(duration*.1+.01)
    check(cues==CATALOG.P90_RELOAD_CUES,"reload completion repeated a sound cue")
    check(combat.ammo[CATALOG.P90]==50 and
        combat.reserve[CATALOG.MP40]==reserve_before-13 and
        not visuals.p90_reload_active and reload_target.position.is_equal_approx(rest),
        "P90 reload duplicated ammunition or retained reload pose")
    for i in range(visuals._p90_magazine_parts.size()):
        check(visuals._p90_magazine_parts[i].transform.is_equal_approx(mag_rest[i]),
            "completed reload did not restore the exact magazine transforms")
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
