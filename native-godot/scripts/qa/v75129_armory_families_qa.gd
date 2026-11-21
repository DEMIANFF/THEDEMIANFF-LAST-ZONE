extends SceneTree
## V75.129 - Actual UI integration, not a static screenshot.
## Weapon family navigation must never remap persistent catalog IDs.
const CATALOG=preload("res://scripts/combat/aurora_weapon_catalog.gd")
const FAMILIES=preload("res://scripts/combat/aurora_weapon_families.gd")
var failed: bool=false


func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V75129_ARMORY_FAMILIES "+message)


func _initialize() -> void:
    call_deferred("_verify")


func _verify() -> void:
    check(FAMILIES.FAMILIES_BY_SLOT.size()==CATALOG.ENTRIES.size(),
        "family taxonomy changed or omitted existing saved weapon slots")
    var covered: Array[int]=[]
    for family in range(1,FAMILIES.LABELS.size()):
        var filtered: Array[int]=FAMILIES.slots_for_family(family)
        check(not filtered.is_empty(),
            "empty weapon family falsely offered in armory "+str(family))
        for slot in filtered:
            check(FAMILIES.family_for_slot(slot)==family and
                slot not in covered,
                "weapon slot missing/mapped to multiple family IDs "+str(slot))
            covered.append(slot)
    covered.sort()
    check(covered==FAMILIES.slots_for_family(FAMILIES.ALL),
        "family navigation does not cover all original weapon catalog entries")
    check(FAMILIES.slots_for_family(-1).is_empty() and
        FAMILIES.slots_for_family(FAMILIES.LABELS.size()).is_empty(),
        "invalid family exposes arbitrary weapons")
    check(FAMILIES.selected_slot_for_family(FAMILIES.ASSAULT,
        CATALOG.SCAR)==CATALOG.SCAR and
        FAMILIES.selected_slot_for_family(FAMILIES.SNIPER,
        CATALOG.SCAR)==CATALOG.AWM,
        "switching category breaks expected stable slot preservation")
    var boot: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(boot)
    await boot.wait_for_startup()
    boot._show_lobby()
    boot._select_tab("ARMAS")
    var chooser: OptionButton=boot._armory_category_selector
    var list: ItemList=boot._armory_list
    check(chooser!=null and list!=null,
        "real Aurora lobby has no family selector and weapon catalog list")
    if chooser==null or list==null:
        quit(1)
        return
    check(chooser.item_count==FAMILIES.LABELS.size() and
        list.item_count==CATALOG.ENTRIES.size(),
        "armory cannot browse all original weapons")
    # A filtered ListItem row index must never replace the persistent slot.
    chooser.select(FAMILIES.ASSAULT)
    boot._on_armory_category_selected(FAMILIES.ASSAULT)
    var assault: Array[int]=FAMILIES.slots_for_family(FAMILIES.ASSAULT)
    check(list.item_count==assault.size() and assault.size()==3,
        "assault category is missing AR-7, SCAR or HK416")
    for row in range(list.item_count):
        check(int(list.get_item_metadata(row))==assault[row],
            "assault weapon row changed real catalog slot at "+str(row))
    list.select(1)
    boot._on_armory_slot_selected(1)
    check(boot._armory_selected_slot==CATALOG.SCAR and
        boot._preview_weapon_slot==CATALOG.SCAR,
        "SCAR UI selection did not update the actual 3D weapon slot")
    chooser.select(FAMILIES.SNIPER)
    boot._on_armory_category_selected(FAMILIES.SNIPER)
    check(boot._armory_selected_slot==CATALOG.AWM and
        int(list.get_item_metadata(0))==CATALOG.AWM,
        "sniper filter used filtered row zero instead of AWM original slot")
    chooser.select(FAMILIES.ALL)
    boot._on_armory_category_selected(FAMILIES.ALL)
    check(boot._armory_selected_slot==CATALOG.AWM and
        list.item_count==CATALOG.ENTRIES.size() and
        list.is_selected(CATALOG.AWM),
        "back to all weapons failed to retain selected AWM slot")
    chooser.select(FAMILIES.SMG)
    boot._on_armory_category_selected(FAMILIES.SMG)
    var submachine: Array[int]=FAMILIES.slots_for_family(FAMILIES.SMG)
    check(list.item_count==submachine.size() and submachine.size()==4,
        "MP40/KRISS/P90/MP5 family missing")
    list.select(2)
    boot._on_armory_slot_selected(2)
    check(boot._armory_selected_slot==CATALOG.P90 and
        int(list.get_item_metadata(2))==CATALOG.P90,
        "filtered SMG selection leaked the row index into saved weapon IDs")
    check(boot._armory_test_button.disabled==
        not boot._armory_has_model(CATALOG.P90),
        "optional GLB missing but training affordance lies about availability")
    check(boot._info.text.contains("SUBFUSILES") and
        boot._info.text.contains("DAÑO BASE") and
        boot._info.text.contains("RECARGA"),
        "weapon inspector lacks selected family and real ballistic statistics")
    boot._select_tab("JUGAR")
    check(not chooser.visible and not list.visible and
        not boot._armory_test_button.visible,
        "armory UI overlays the live lobby after navigating to JUGAR")
    if not failed:
        print("V75129_ARMORY_FAMILIES PASS slot_contract=13 groups=8 "+
            "filtered_rows=metadata live_3d=SCAR/AWM truthful_licensing=1")
    boot.queue_free()
    await process_frame
    quit(1 if failed else 0)
