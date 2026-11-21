extends SceneTree
## V75.132 - Purchase/equip original authored Lila skins via real mobile UI.
## An isolated QA ledger proves no premium currency or entitlement spoofing.
const LEDGER=preload("res://scripts/persistence/offline_match_records.gd")
const PATH="user://qa/aurora_v75132_shop.json"
var failed: bool=false


func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V75132_SKIN_GALLERY "+message)


func _clean() -> void:
    var full: String=ProjectSettings.globalize_path(PATH)
    DirAccess.make_dir_recursive_absolute(full.get_base_dir())
    for suffix in ["",".bak",".tmp",".auto",".auto.tmp"]:
        if FileAccess.file_exists(full+suffix):
            DirAccess.remove_absolute(full+suffix)


func _initialize() -> void:
    call_deferred("_verify")


func _verify() -> void:
    _clean()
    var ledger=LEDGER.new(PATH)
    check(ledger.cosmetic_state()["owned"]==["aurora_base"],
        "new profile has fictional purchased outfits")
    check(not ledger.purchase_local_skin("aurora_glacier"),
        "insufficient local coins did not block purchase")
    check(ledger.record_result(1,true,12,600) and
        ledger.record_result(2,true,12,600),
        "earned local match coins could not be recorded")
    var menu: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(menu)
    await menu.wait_for_startup()
    menu._enter_local_lobby()
    menu._offline_records=ledger
    menu._select_tab("TIENDA")
    var entry: Button=menu._shop_gallery_entry
    var overlay: Control=menu._shop_gallery_overlay
    var cards: Dictionary=menu._shop_gallery_cards
    check(entry!=null and overlay!=null and cards.size()==3 and
        menu._shop_selector.get_item_count()==3 and
        entry.visible and not overlay.visible,
        "three authentic Lila palettes or catalogue entry are missing")
    if entry==null or overlay==null or cards.size()!=3:
        quit(1)
        return
    root.size=Vector2i(964,434)
    await process_frame
    await process_frame
    menu._layout_safe()
    check(root.get_visible_rect().encloses(entry.get_global_rect()),
        "catalogue entry clipped on Motorola 964x434")
    entry.emit_signal("pressed")
    check(not menu._page.visible and overlay.visible,
        "legacy store purchase controls remain behind active skin drawer")
    check(overlay.visible and
        overlay.get_node_or_null("AuroraSkinGalleryPanel")!=null,
        "catalogue button does not show native interactive shop")
    await process_frame
    await process_frame
    var panel: PanelContainer=overlay.get_node("AuroraSkinGalleryPanel")
    check(root.get_visible_rect().encloses(panel.get_global_rect()),
        "skin gallery clipped outside the real mobile viewport")
    # The actual Lila is around the middle of the horizontal lobby.
    # Require the shop drawer to stay on the left, off the character.
    check(panel.get_global_rect().end.x<=
        float(root.get_visible_rect().size.x)*.42,
        "skin gallery blocks the real center-stage Lila operator")
    var scrim: ColorRect=overlay.get_node_or_null(
        "SkinGalleryBackdrop") as ColorRect
    check(scrim!=null and scrim.color.a<=.25 and
        menu._preview_avatar!=null and menu._preview_avatar.visible,
        "shop incorrectly hides/dims the original 3D playable Lila")
    var before: int=int(ledger.cosmetic_state()["coins"])
    check(not menu._shop_gallery_buy.disabled and
        menu._shop_selected_skin=="aurora_glacier" and
        menu._shop_gallery_buy.text.contains("200"),
        "glacier item is not the original 200-coin purchasable skin")
    menu._shop_gallery_buy.emit_signal("pressed")
    var paid: Dictionary=ledger.cosmetic_state()
    check(int(paid["coins"])==before-200 and
        (paid["owned"] as Array).has("aurora_glacier") and
        str(paid["equipped"])=="aurora_glacier" and
        menu._shop_gallery_buy.disabled and
        menu._shop_gallery_equip.disabled and
        menu._shop_gallery_balance.text.contains(str(before-200)),
        "shop card did not debit/own/equip actual Glacier profile")
    check(bool((cards["aurora_glacier"] as Button).get_meta(
        "aurora_selected_skin",false)) and
        (cards["aurora_glacier"] as Button).text.contains("EQUIPADO"),
        "actual purchased skin not reflected in 3D showroom catalogue")
    (cards["aurora_base"] as Button).emit_signal("pressed")
    check(menu._shop_selected_skin=="aurora_base" and
        menu._shop_selector.selected==0 and
        menu._shop_gallery_buy.disabled and
        not menu._shop_gallery_equip.disabled,
        "original owned skin not selectable from real card")
    menu._shop_gallery_equip.emit_signal("pressed")
    check(str(ledger.cosmetic_state()["equipped"])=="aurora_base" and
        int(ledger.cosmetic_state()["coins"])==before-200,
        "equip action incorrectly charges additional local coins")
    (cards["aurora_ember"] as Button).emit_signal("pressed")
    var remaining: int=int(ledger.cosmetic_state()["coins"])
    check(menu._shop_selected_skin=="aurora_ember" and
        menu._shop_gallery_buy.disabled==(remaining<300) and
        menu._shop_gallery_equip.disabled and
        not (ledger.cosmetic_state()["owned"] as Array).has("aurora_ember"),
        "Ember card fabricates ownership or bypasses real price gating")
    menu._select_tab("INVENTARIO")
    check(not entry.visible and not overlay.visible and
        menu._page.visible and menu._equipment_selector.visible,
        "closing catalogue on tab switch did not restore inventory page")
    menu._select_tab("TIENDA")
    entry.emit_signal("pressed")
    check(not menu._page.visible,
        "reopened skin catalogue exposed duplicate legacy purchase controls")
    var exit: Button=panel.find_child("CloseSkinGallery",true,false) as Button
    check(exit!=null and exit.custom_minimum_size.y>=40,
        "store catalogue cannot be dismissed by a physical touch target")
    if exit!=null:
        exit.emit_signal("pressed")
    check(not overlay.visible and menu._page.visible and menu.stage=="lobby",
        "closing shop must restore legacy store without a purchase or match")
    menu._welcome()
    check(not overlay.visible and menu._page.visible,
        "shop popup or hidden page persists into authentication screen")
    var persistent=LEDGER.new(PATH)
    check(str(persistent.cosmetic_state()["equipped"])=="aurora_base" and
        (persistent.cosmetic_state()["owned"] as Array).has("aurora_glacier") and
        int(persistent.cosmetic_state()["coins"])==before-200,
        "real local profile failed to persist store purchases and equip")
    menu.queue_free()
    await process_frame
    _clean()
    if not failed:
        print("V75132_SKIN_GALLERY PASS skins=3 real_ledger=1 "+
            "paid_glacier=200 equip_no_charge=1 "+
            "viewport=964x434 no_premium=1")
    quit(1 if failed else 0)
