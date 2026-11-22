extends SceneTree
## V75.161 production 3D lobby acceptance from the supplied reference:
## true Godot Boot.tscn, Aurora 3D Lila stage and REAL functional controls.
## No static screenshot or UI illustration is substituted for the lobby.
var failed: bool=false


func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V75161_REFERENCE_LOBBY "+why)


func _initialize() -> void:
    call_deferred("_verify")


func _verify() -> void:
    root.size=Vector2i(964,434)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    front._show_lobby()
    await process_frame
    front._layout_safe()
    await process_frame

    check(front.stage=="lobby" and front._game==null and
        front._preview_container!=null and
        is_instance_valid(front._preview_avatar),
        "original 3D lobby rig was swapped for a drawing or gameplay started")
    var footer: HBoxContainer=front._bottom_navigation
    var rail: VBoxContainer=front._left_shortcuts
    var squad: PanelContainer=front._social_panel
    var battle: PanelContainer=front._play_match_card
    var mode: OptionButton=front._match_mode_selector
    var start: Button=front._battle_entry
    check(footer!=null and footer.get_child_count()==5 and
        footer.get_node_or_null("BottomPRESET")==null and
        footer.get_node_or_null("BottomJUGAR")!=null and
        footer.get_node_or_null("BottomINVENTARIO")!=null and
        footer.get_node_or_null("BottomARMAS")!=null and
        footer.get_node_or_null("BottomPERSONAJE")!=null and
        footer.get_node_or_null("BottomSOCIAL")!=null,
        "footer is not exactly JUGAR/INVENTARIO/ARMAS/PERSONAJES/SOCIAL")
    check(rail!=null and rail.get_child_count()==6 and
        rail.get_node_or_null("QuickTIENDA")!=null and
        rail.get_node_or_null("QuickPASE")!=null and
        rail.get_node_or_null("QuickJUGAR")!=null and
        rail.get_node_or_null("QuickEVENTS")!=null and
        rail.get_node_or_null("QuickMISSIONS")!=null and
        rail.get_node_or_null("QuickACHIEVEMENTS")!=null,
        "reference commerce left rail missing or includes duplicate MODOS")
    check(mode!=null and mode.is_visible_in_tree() and
        front._mode_gallery_entry==null and
        front._mode_gallery_overlay==null and
        start.text=="INICIAR",
        "only right-side BR selector and functional golden start allowed")
    check(squad.is_visible_in_tree() and
        squad.get_node("SocialContent/AuroraFourMemberSquad").get_child_count()==4,
        "four-slot LOCAL squad panel missing")
    check(front._preview_caption.visible and
        front._preview_caption.text.contains("LILA AURORA"),
        "native rotating operator no longer has original nameplate")
    var real_stage: Node3D=front._preview_container.get_node(
        "PreviewViewport/AuroraCharacterStage")
    for index in range(2):
        var ring: MeshInstance3D=real_stage.get_node_or_null(
            "AuroraPortraitPodiumRing%d"%index) as MeshInstance3D
        check(ring!=null and ring.mesh is TorusMesh and
            ring.material_override is StandardMaterial3D and
            (ring.material_override as StandardMaterial3D).emission_enabled,
            "original Aurora 3D stage lost its physically luminous podium ring")

    var footer_plate: Panel=front.find_child(
        "AuroraPremiumFooterGlass",true,false) as Panel
    var nameplate: Panel=front.find_child(
        "AuroraOperatorNameplate",true,false) as Panel
    var slash: ColorRect=front.find_child(
        "AuroraBrandSlash",true,false) as ColorRect
    check(footer_plate!=null and nameplate!=null and slash!=null and
        footer_plate.visible and nameplate.visible and slash.visible,
        "premium bottom glass, cyan brand and Lila controls weren't instantiated")
    if footer_plate!=null and nameplate!=null:
        check(footer_plate.get_global_rect().encloses(
            footer.get_global_rect()) and
            nameplate.get_global_rect().encloses(
            front._preview_caption.get_global_rect()),
            "native five-button footer or nameplate escapes its real glass panel")
    # Mobile controls should be in ONE row, outside the 3D character's feet
    # and on the same functional overlay, not on a secondary fake screenshot.
    var control_buttons: Array=front._operator_controls
    var gesture: Button=front._gesture_button
    check(control_buttons.size()>=3 and gesture!=null,
        "real operator turn/frame/gesture controls missing")
    var name_rect: Rect2=front._preview_caption.get_global_rect()
    for control in control_buttons:
        if (control as Button).name=="AuroraMalePreviewSelector":
            continue
        var button: Button=control as Button
        var action_rect: Rect2=button.get_global_rect()
        check(not action_rect.intersects(name_rect) and
            absf(action_rect.get_center().y-name_rect.get_center().y)<22,
            "operator control overlaps central nameplate or sits in another row")
    check(not gesture.get_global_rect().intersects(name_rect),
        "gesture button obscures Lila's actual nameplate")

    # Match card must remain visually separate from team panel and footer.
    var panel_rect: Rect2=battle.get_global_rect()
    var squad_rect: Rect2=squad.get_global_rect()
    check(not panel_rect.intersects(squad_rect) and
        not panel_rect.intersects(footer.get_global_rect()) and
        not squad_rect.intersects(footer.get_global_rect()),
        "battle/squad/footer panels overlap the phone layout")
    var facts: Control=front._lobby_compact_intel
    check(panel_rect.encloses(start.get_global_rect()) and
        panel_rect.encloses(mode.get_global_rect()) and
        panel_rect.encloses(facts.get_global_rect()) and
        not facts.get_global_rect().intersects(start.get_global_rect()),
        "match selector, start or physical match facts escape golden BR card")

    # Top identity and account buttons must remain separate from each other.
    var profile: Label=front._profile_strip
    var stats: Label=front._stats_strip
    var currency: Label=front._currency_strip
    var account: Button=front._top_account_button
    var gear: Button=front._top_settings_button
    var top_social: Button=front._top_social_button
    check(not profile.get_global_rect().intersects(stats.get_global_rect()) and
        not stats.get_global_rect().intersects(currency.get_global_rect()) and
        not currency.get_global_rect().intersects(top_social.get_global_rect()) and
        not top_social.get_global_rect().intersects(account.get_global_rect()) and
        not account.get_global_rect().intersects(gear.get_global_rect()),
        "brand, true player stats, coins or native account/gear overlaps")

    # This invokes the actual navigation; inactive pages cannot falsely
    # leave INICIAR over an armory, or manufacture online squad members.
    footer.get_node("BottomARMAS").pressed.emit()
    check(front._selected_tab=="ARMAS" and
        not battle.visible and not squad.visible and
        front._armory_list.visible,
        "ARMAS tab is a decorative button instead of an actual connected catalog")
    footer.get_node("BottomJUGAR").pressed.emit()
    check(front._selected_tab=="JUGAR" and
        battle.visible and squad.visible and start.visible,
        "return to original playable BR lobby failed")
    rail.get_node("QuickMISSIONS").pressed.emit()
    check(front._selected_tab=="OBJETIVOS" and
        front._objective_page=="missions",
        "left mission action does not open the real progress ledger")
    footer.get_node("BottomJUGAR").pressed.emit()
    gear.pressed.emit()
    check(front._settings_modal!=null and
        front.stage=="lobby" and front._game==null,
        "settings gear is still detached or unexpectedly starts a training scene")
    if front._settings_modal!=null:
        front._settings_modal.call("_close")
    front.queue_free()
    await process_frame
    if not failed:
        print("V75161_REFERENCE_LOBBY PASS phone=964x434 real_3D_lila=1 "+
            "premium_glass=1 top_identity=1 controls_in_one_row=1 "+
            "four_squad_slots=1 single_BR_selector=1 "+
            "footer=5 no_PRESET=1 no_left_MODOS=1 "+
            "actual_armory_missions_settings=3 no_fake_online=1")
    quit(1 if failed else 0)
