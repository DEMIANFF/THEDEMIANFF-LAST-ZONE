extends SceneTree
## V75.85 real local-only cosmetics, exact wallet debits and skinned Lila.
const LEDGER=preload("res://scripts/persistence/offline_match_records.gd")
const COSMETICS=preload("res://scripts/player/aurora_operator_cosmetics.gd")
const QA_PATH="user://qa/aurora_v7585_cosmetic.json"
const QA_UI="user://qa/aurora_v7585_shop_button.json"
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7585_REAL_SKIN_SHOP "+reason)


func _clean(path: String) -> void:
    var full: String=ProjectSettings.globalize_path(path)
    DirAccess.make_dir_recursive_absolute(full.get_base_dir())
    for suffix in ["",".bak",".tmp",".auto",".auto.tmp"]:
        if FileAccess.file_exists(full+suffix):
            DirAccess.remove_absolute(full+suffix)


func _verify() -> void:
    _clean(QA_PATH)
    _clean(QA_UI)
    var ledger=LEDGER.new(QA_PATH)
    check(ledger.cosmetic_state()["owned"]==["aurora_base"] and
        str(ledger.cosmetic_state()["equipped"])=="aurora_base",
        "new profile has invented paid skins")
    check(not ledger.purchase_local_skin("aurora_glacier"),
        "free account purchased unaffordable armor")
    for match_id in range(1,4):
        check(ledger.record_result(match_id,true,12,600),
            "legitimate match did not earn local shop coins")
    var initial_coins: int=int(ledger.snapshot()["local_coins"])
    check(initial_coins>=500,"earned matches did not fund store")
    check(ledger.purchase_local_skin("aurora_glacier"),
        "original local Glacial armor cannot be bought")
    check(int(ledger.snapshot()["local_coins"])==initial_coins-200 and
        not ledger.purchase_local_skin("aurora_glacier"),
        "duplicate purchase double-charged same skin")
    check(ledger.equip_local_skin("aurora_base") and
        ledger.equip_local_skin("aurora_glacier"),
        "legitimately owned gear cannot be switched")
    check(ledger.purchase_local_skin("aurora_ember") and
        int(ledger.snapshot()["local_coins"])==initial_coins-500,
        "second local skin did not charge exact earned coins")
    var saved_revision: int=int(ledger.snapshot()["profile_revision"])
    var persisted=LEDGER.new(QA_PATH)
    check(persisted.cosmetic_state()["owned"].size()==3 and
        str(persisted.cosmetic_state()["equipped"])=="aurora_ember" and
        int(persisted.snapshot()["profile_revision"])==saved_revision,
        "cosmetics were not loaded from committed signed profile")
    var damaged:=FileAccess.open(QA_PATH,FileAccess.WRITE)
    check(damaged!=null,"could not create corrupted-primary fixture")
    if damaged!=null:
        damaged.store_string("{invalid-primary")
        damaged.close()
    var recovered=LEDGER.new(QA_PATH)
    check(recovered.cosmetic_state()["owned"].size()==3 and
        str(recovered.cosmetic_state()["equipped"])=="aurora_ember" and
        recovered.retry_pending(),
        "actual purchases and equipped item lost during backup recovery")

    # Verify live native storefront UI against independent offline ledger.
    var visual_ledger=LEDGER.new(QA_UI)
    check(visual_ledger.record_result(1,true,12,600) and
        visual_ledger.record_result(2,true,12,600),
        "visual shop cannot fund actual purchases from saved battles")
    var menu: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(menu)
    await menu.wait_for_startup()
    await process_frame
    menu._enter_local_lobby()
    await process_frame
    menu._offline_records=visual_ledger
    menu._select_tab("TIENDA")
    check(menu._shop_selector.visible and menu._shop_buy_button.visible and
        menu._shop_selector.get_item_count()==3,
        "storefront UI has no native purchasable local cosmetic catalog")
    var old_coins: int=int(visual_ledger.cosmetic_state()["coins"])
    check(not menu._shop_buy_button.disabled,
        "legitimately earned coins did not enable purchase button")
    menu._shop_buy_button.emit_signal("pressed")
    var paid: Dictionary=visual_ledger.cosmetic_state()
    check(int(paid["coins"])==old_coins-200 and
        str(paid["equipped"])=="aurora_glacier" and
        menu._currency_strip.text.contains(str(old_coins-200)),
        "real store button failed to charge actual profile and equip armor")
    var rig: Node3D=menu._preview_avatar
    var kit: MeshInstance3D=rig.find_child("Lila_Aurora_Mesh",
        true,false) as MeshInstance3D
    check(kit!=null and kit.get_surface_override_material(0) is ShaderMaterial,
        "Glacial purchase did not repaint actual skinned Lila armor")
    menu._shop_selector.select(0)
    menu._on_shop_skin_selected(0)
    menu._shop_equip_button.emit_signal("pressed")
    check(str(visual_ledger.cosmetic_state()["equipped"])=="aurora_base" and
        kit!=null and kit.get_surface_override_material(0)==null,
        "equipping original skin did not restore source PBR material")
    menu.queue_free()
    await process_frame
    _clean(QA_PATH)
    _clean(QA_UI)
    if not failed:
        print("V7585_REAL_SKIN_SHOP PASS earned_purchases=2 "+
            "atomic_wallet=1 duplicate_rejected=1 recovery=1 "+
            "lobby_button=real 3d_armor=live_pbr offline_only=1")
    quit(1 if failed else 0)
