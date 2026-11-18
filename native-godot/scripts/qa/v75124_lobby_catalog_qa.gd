extends SceneTree
## V75.124 UI acceptance: browse actual weapon/gear catalog from lobby,
## distinguish staged GLBs from missing private assets, and enter real armory.
const CATALOG=preload("res://scripts/combat/aurora_weapon_catalog.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,detail: String) -> void:
    if not ok:
        failed=true
        push_error("V75124_LOBBY_CATALOG "+detail)

func _verify() -> void:
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    front._show_lobby()
    front._select_tab("ARMAS")
    var weapons: ItemList=front._armory_list
    check(weapons!=null and weapons.visible and
        weapons.item_count==CATALOG.ENTRIES.size(),
        "visible armory must list all original and optional weapon slots")
    check(weapons.item_count==13,
        "historic 13-slot training catalog changed")
    for index in range(CATALOG.ENTRIES.size()):
        var item: Dictionary=CATALOG.ENTRIES[index]
        var path: String=str(item.get("asset",""))
        var imported: bool=path.is_empty() or ResourceLoader.exists(path,"PackedScene")
        var line: String=weapons.get_item_text(index)
        check(line.contains(str(item["short"])),
            "UI dropped catalog weapon "+str(item["short"]))
        check(line.contains("MODELO LISTO") if imported else line.contains("GLB PENDIENTE"),
            "UI claims an unimported private GLB is installed "+str(item["short"]))
    weapons.select(CATALOG.MP40)
    weapons.item_selected.emit(CATALOG.MP40)
    check(front._info.text.contains("MP40") and
        front._info.text.contains("CARGADOR"),
        "selection did not reveal live MP40 ballistic data")
    front._select_tab("INVENTARIO")
    check(front._equipment_selector.visible and not weapons.visible and
        front._equipment_selector.item_count==5,
        "lobby has no equipment browser or leaks weapons into gear tab")
    front._equipment_selector.select(4)
    front._equipment_selector.item_selected.emit(4)
    check(front._info.text.contains("GRANADA") and
        front._info.text.contains("no otorga objetos"),
        "inventory preview fabricates gear or ignores selection")
    front._select_tab("ARMAS")
    check(front._armory_test_button.visible,
        "no accessible path to physically try the staged weapons")
    front._open_weapon_training()
    for frame in range(10):
        await process_frame
    check(front.stage=="training" and front._game!=null,
        "weapon armory action did not launch actual training")
    if front._game!=null:
        var combat: Node3D=front._game.get_node("CombatRange")
        check(combat._training_armory!=null,
            "training failed to create a real pickup table")
    front.queue_free()
    await process_frame
    if not failed:
        print("V75124_LOBBY_CATALOG PASS weapons=13 equipment=5"+
            " resource_status=1 training_armory=1")
    quit(1 if failed else 0)
