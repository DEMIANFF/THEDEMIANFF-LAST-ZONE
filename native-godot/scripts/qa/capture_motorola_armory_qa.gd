extends SceneTree
## Actual Godot lobby/armory render captures at the 964x434 phone layout.
## Desktop Xvfb capture is visual CI evidence, NOT a physical Motorola trial.
const CAPTURE_VERSION=preload("res://scripts/qa/aurora_capture_version.gd")
const CATALOG=preload("res://scripts/combat/aurora_weapon_catalog.gd")
const FAMILIES=preload("res://scripts/combat/aurora_weapon_families.gd")


func _initialize() -> void:
    call_deferred("_capture")


func _capture() -> void:
    root.size=Vector2i(964,434)
    var tag: String=CAPTURE_VERSION.tag()
    if tag.is_empty():
        push_error("ARMORY_MOTOROLA_CAPTURE missing version tag")
        quit(2)
        return
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    front._enter_local_lobby()
    for frame in range(12):
        await process_frame
    front._select_tab("ARMAS")
    for frame in range(5):
        await process_frame
    var captured: int=0
    for slot in range(CATALOG.ENTRIES.size()):
        if not front._armory_has_model(slot):
            continue
        # Show the REAL filtered category in every captured screenshot.
        # The displayed row number is never the persistent combat slot.
        var family: int=FAMILIES.family_for_slot(slot)
        front._armory_category_selector.select(family)
        front._on_armory_category_selected(family)
        var row: int=-1
        for index in range(front._armory_list.item_count):
            if int(front._armory_list.get_item_metadata(index))==slot:
                row=index
                break
        if row<0:
            push_error("ARMORY_MOTOROLA_CAPTURE filtered slot missing "+str(slot))
            quit(7)
            return
        front._armory_list.select(row)
        front._on_armory_slot_selected(row)
        if front._armory_selected_slot!=slot:
            push_error("ARMORY_MOTOROLA_CAPTURE filtered row remapped weapon")
            quit(8)
            return
        for frame in range(10):
            await process_frame
        front._layout_safe()
        await RenderingServer.frame_post_draw
        var model: Node3D=front._preview_weapon
        if model==null or not is_instance_valid(model):
            push_error("ARMORY_MOTOROLA_CAPTURE no actual model for slot "+str(slot))
            quit(3)
            return
        var shown:=model.get_node_or_null("SelectedOriginalWeaponGLB") as Node3D
        if shown==null or shown.scene_file_path!=front._armory_model_path(slot):
            push_error("ARMORY_MOTOROLA_CAPTURE original GLB missing "+str(slot))
            quit(4)
            return
        var image: Image=root.get_texture().get_image()
        if image.get_size()!=Vector2i(964,434):
            push_error("ARMORY_MOTOROLA_CAPTURE incorrect phone layout")
            quit(5)
            return
        var label: String=str(CATALOG.ENTRIES[slot]["short"]).to_lower()
        var output: String="res://out/aurora-"+tag+"-motorola-armory-"+label+".png"
        if image.save_png(output)!=OK:
            push_error("ARMORY_MOTOROLA_CAPTURE unable to save "+output)
            quit(6)
            return
        captured+=1
        print("ARMORY_MOTOROLA_CAPTURE slot=",slot," weapon=",label,
            " output=",output)
    front._welcome()
    front.queue_free()
    for frame in range(8):
        await RenderingServer.frame_post_draw
    print("ARMORY_MOTOROLA_CAPTURE PASS resolution=964x434 "+
        "actual_glbs=%d renderer=desktop not_phone=1"%captured)
    quit(0)
