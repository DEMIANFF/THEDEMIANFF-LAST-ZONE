extends SceneTree
## V75.130: real Boot-scene equipment filter and 3D operator preview QA.
## Lobby navigation MUST NOT grant match loot or claim CH02 is battle-ready.
const GEAR=preload("res://scripts/combat/aurora_equipment_families.gd")
const MALE=preload("res://scripts/player/aurora_mixamo_male_preview.gd")
var failed: bool=false


func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V75130_GEAR_OPERATORS "+why)


func _initialize() -> void:
    call_deferred("_verify")


func _verify() -> void:
    check(GEAR.ITEM_NAMES.size()==5 and GEAR.CATEGORY_BY_SLOT.size()==5,
        "original five equipment IDs were changed")
    var found: Array[int]=[]
    for family in range(1,GEAR.LABELS.size()):
        var slots: Array[int]=GEAR.slots_for_category(family)
        check(not slots.is_empty(),"empty advertised equipment category")
        for slot in slots:
            check(slot not in found,"equipment belongs to duplicate categories")
            found.append(slot)
    found.sort()
    check(found==GEAR.slots_for_category(GEAR.ALL),
        "original BR equipment types were dropped")
    check(GEAR.select_slot(GEAR.PROTECTION,2)==2 and
        GEAR.select_slot(GEAR.SUPPLIES,2)==3,
        "filter cannot preserve/change equipment slot as designed")
    check(GEAR.slots_for_category(-1).is_empty(),
        "invalid equipment category must not expose arbitrary gear")

    var boot: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(boot)
    await boot.wait_for_startup()
    boot._show_lobby()
    var original_ledger: Dictionary=boot._offline_records.snapshot()
    boot._select_tab("INVENTARIO")
    var category: OptionButton=boot._equipment_category_selector
    var gear: OptionButton=boot._equipment_selector
    check(category!=null and gear!=null and category.visible and gear.visible,
        "real inventory category and item controls not visible in lobby")
    if category==null or gear==null:
        quit(1)
        return
    check(category.item_count==4 and gear.item_count==5,
        "base inventory does not preserve five legacy equipment selections")
    category.select(GEAR.PROTECTION)
    boot._on_equipment_category_selected(GEAR.PROTECTION)
    check(gear.item_count==3 and gear.get_item_id(2)==2,
        "protection filter mislabels backpack/helmet/vest")
    gear.select(2)
    boot._on_equipment_selected(2)
    check(boot._equipment_selected==2 and
        boot._info.text.contains("CHALECO"),
        "filtered slot two did not inspect the real vest")
    category.select(GEAR.SUPPLIES)
    boot._on_equipment_category_selected(GEAR.SUPPLIES)
    check(gear.item_count==1 and gear.get_item_id(0)==3 and
        boot._equipment_selected==3 and
        boot._info.text.contains("BOTIQUÍN"),
        "filtered row zero did not resolve real medkit slot three")
    category.select(GEAR.THROWABLES)
    boot._on_equipment_category_selected(GEAR.THROWABLES)
    check(gear.item_count==1 and gear.get_item_id(0)==4 and
        boot._info.text.contains("GRANADA"),
        "throwables category did not contain real grenade")
    category.select(GEAR.ALL)
    boot._on_equipment_category_selected(GEAR.ALL)
    check(gear.item_count==5 and boot._equipment_selected==4 and
        gear.get_selected_id()==4,
        "restoring full inventory lost original grenade ID")
    check(boot._info.text.contains("no otorga objetos"),
        "inspection view falsely grants loot")
    boot._select_tab("PERSONAJE")
    var operator: OptionButton=boot._operator_selector
    check(operator!=null and operator.visible and operator.item_count==2,
        "character screen has no actual Lila / Ch02 preview selection")
    if operator!=null:
        check(operator.get_item_id(0)==0 and operator.get_item_id(1)==1 and
            operator.get_item_text(1).contains("VISTA"),
            "character menu claims unavailable combat operator")
        check(operator.is_item_disabled(1)==not MALE.source_available(),
            "male preview lacks honest GLB availability gating")
        var viewport: SubViewport=boot._preview_container.get_node(
            "PreviewViewport") as SubViewport
        var initial_id: int=viewport.get_instance_id()
        operator.select(0)
        boot._on_operator_selected(0)
        check(not boot._preview_male_active,
            "Lila selection no longer restores playable operator")
        if MALE.source_available():
            operator.select(1)
            boot._on_operator_selected(1)
            if boot._preview_male_active:
                check(boot._preview_avatar!=null and
                    boot._preview_avatar.name=="AuroraMaleMixamoPreview" and
                    boot._preview_container.get_node(
                        "PreviewViewport").get_instance_id()==initial_id,
                    "CH02 preview is not real 3D or reallocated the renderer")
                check(not boot._shop_selector.visible,
                    "Lila-only tactical outfit selector shown on CH02")
                operator.select(0)
                boot._on_operator_selected(0)
                check(not boot._preview_male_active,
                    "cannot return from male preview to playable Lila")
            else:
                check(operator.selected==0,
                    "unsupported male model appeared selected despite failure")
        check(boot._preview_container.get_node(
            "PreviewViewport").get_instance_id()==initial_id,
            "character switch allocated a second heavyweight viewport")
    boot._select_tab("JUGAR")
    check(not category.visible and not gear.visible and
        (operator==null or not operator.visible),
        "inventory/character controls leaked into live play lobby")
    var after: Dictionary=boot._offline_records.snapshot()
    check(after==original_ledger,
        "catalog browsing unexpectedly changed persistent match/coin ledger")
    if not failed:
        print("V75130_GEAR_OPERATORS PASS slots=5 categories=4 "+
            "real_3d=1 source_gating=1 no_entitlements=1")
    boot.queue_free()
    await process_frame
    quit(1 if failed else 0)
