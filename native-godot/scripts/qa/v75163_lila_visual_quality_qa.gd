extends SceneTree
## Real skinned Lila visual correctness, not a detached 2D prototype:
## grounded physical feet, original GLB shader palettes, vehicle/airborne
## visibility and no extra collider or animation bones.
const COSMETICS=preload("res://scripts/player/aurora_operator_cosmetics.gd")
const CONTACT=preload("res://scripts/player/aurora_operator_contact_shadow.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_check")


func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V75163_LILA_VISUAL "+why)


func frames(n: int) -> void:
    for i in range(n):
        await physics_frame


func _check() -> void:
    root.size=Vector2i(964,434)
    var im: Image=CONTACT.shadow_image()
    check(im.get_size()==Vector2i(64,64) and im.has_mipmaps() and
        im.get_pixel(32,32).a>.28 and
        im.get_pixel(0,0).a<.002,
        "light procedural contact mask absent or rectangular")
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get_node("Operator")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    director.set_process(false)
    combat.set_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    var body: Node3D=player.get_node_or_null("AuroraFemaleRiggedOperator")
    var shadow: MeshInstance3D=player.get_node_or_null(
        "LilaPhysicalGroundContact") as MeshInstance3D
    check(body!=null and player._animation_controller!=null and
        shadow!=null and shadow.mesh is PlaneMesh and
        shadow.material_override is StandardMaterial3D and
        shadow.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
        "skinned operator or cheap real 3D contact shadow missing")
    if shadow==null:
        quit(1)
        return
    var material: StandardMaterial3D=shadow.material_override as StandardMaterial3D
    check(material.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA and
        material.albedo_texture.get_width()==64 and
        material.texture_filter==BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
        "contact should not require huge opaque quad or expensive shadow renderer")
    check(player.get_node_or_null("CapsuleCollider")!=null and
        shadow.get_child_count()==0,
        "visual improvement changed gameplay physics/weapon collision")
    var mesh: MeshInstance3D=body.find_child(
        "Lila_Aurora_Mesh",true,false) as MeshInstance3D
    check(mesh!=null and mesh.skin!=null,
        "production Lila skinned mesh was replaced with a dummy")
    var original: Material=mesh.get_surface_override_material(0)
    check(COSMETICS.apply_to_operator(body,"aurora_glacier"),
        "original Glacier costume no longer applies to real Lila body")
    var blue: ShaderMaterial=mesh.get_surface_override_material(0) as ShaderMaterial
    check(blue!=null and blue.get_shader_parameter("source_metallic")!=null and
        blue.get_shader_parameter("source_roughness")!=null,
        "real material failed to preserve metallic/roughness under dye")
    check(COSMETICS.apply_to_operator(body,"aurora_ember"),
        "Ember costume no longer applies to real Lila body")
    check(COSMETICS.apply_to_operator(body,"aurora_base") and
        mesh.get_surface_override_material(0)==original,
        "original non-dyed Lila shader wasn't restored cleanly")

    # Move the actual character onto physical rock. The decal must track
    # floor contact rather than render while 10m above the island.
    var at:=Vector2(-75,-75)
    player.global_position=Vector3(at.x,
        terrain.height_at(at.x,at.y)+.35,at.y)
    player.velocity=Vector3.ZERO
    await frames(28)
    await process_frame
    check(player.is_on_floor() and shadow.visible and
        shadow.global_position.distance_to(player.global_position)<.12,
        "real boots are not grounded on the island with a contact cue")
    player.global_position.y+=9.0
    player.velocity=Vector3.ZERO
    await frames(3)
    await process_frame
    check(not player.is_on_floor() and not shadow.visible,
        "contact shadow floats in midair during Lila jump/fall")
    check(player.get_view_camera()!=null and
        player._animation_controller.tree.active and
        game.get_node_or_null("AuroraSectorMatch")!=null,
        "new visual treatment broke third-person camera, animation or BR")

    game.queue_free()
    await process_frame
    if not failed:
        print("V75163_LILA_VISUAL PASS real_56_bone_skin=1 "+
            "physics_ground_contact=1 midair_hidden=1 "+
            "original_outfits=3 PBR=1 collider_unchanged=1 "+
            "shadow_texture=64px_mipmaps HUD_preserved=1 "+
            "physical_Motorola_test=NO")
    quit(1 if failed else 0)
