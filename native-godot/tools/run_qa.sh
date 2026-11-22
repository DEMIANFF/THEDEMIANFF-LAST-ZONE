#!/usr/bin/env bash
set -euo pipefail
ROOT="${AURORA_QA_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
GODOT="${GODOT:-godot}"
LOGS="${AURORA_QA_LOGS:-$ROOT/out/qa}"
mkdir -p "$LOGS"
# Full QA requires the same generated resources as the Android export.
if [ "${AURORA_QA_EXPORTED:-0}" = 1 ]; then
  test -s "$ROOT/project.binary"
else
  test -s "$ROOT/assets/characters/aurora_operator.glb"
  test -s "$ROOT/assets/characters/lila_aurora.glb"
  test -s "$ROOT/assets/weapons/aurora_awm.glb"
fi
export AURORA_REQUIRE_OPERATOR=1 GODOT_SILENCE_ROOT_WARNING=1
# Keep test ledgers independent from installed desktop profiles.
qa_data="$(mktemp -d)"
trap 'rm -rf "$qa_data"' EXIT
export XDG_DATA_HOME="$qa_data"
if [ "${AURORA_QA_EXPORTED:-0}" != 1 ]; then
  import_status=0
  "$GODOT" --headless --path "$ROOT" --editor --quit > "$LOGS/import.running" 2>&1 || import_status=$?
  mv "$LOGS/import.running" "$LOGS/import.log"
  if [ "$import_status" -ne 0 ]; then cat "$LOGS/import.log"; exit 1; fi
  if grep -E 'SCRIPT ERROR:|ERROR:' "$LOGS/import.log"; then exit 1; fi
  # Parse the affected runtime scripts BEFORE running hundreds of physics
  # tests. A broken dependency previously generated scores of 90s timeouts.
  # Do not parse aurora_frontend.gd as a standalone --check-only script:
  # it uses project autoload AuroraLobbyMusic, which is not registered in
  # standalone check-only mode. The real Boot scene is instantiated in
  # v75127/v75128 frontend QA and the Xvfb visual capture instead.
  # Check direct dependencies first: main.gd preloads native_hud.gd.
  # Otherwise an HUD syntax regression is only reported as an opaque
  # 'Could not preload resource script' at main.gd:6.
  for source in \
    scripts/ui/native_hud.gd \
    scripts/combat/aurora_grenade.gd \
    scripts/ai/aurora_bot.gd \
    scripts/combat/training_combat.gd \
    scripts/match/sector_director.gd \
    scripts/main.gd \
    scripts/ui/aurora_tactical_map.gd \
    scripts/qa/v75133_map_readability_qa.gd \
    scripts/qa/v75136_objective_progress_qa.gd \
    scripts/qa/v75138_opponent_loot_budget_qa.gd \
    scripts/qa/v75139_near_deck_loot_qa.gd \
    scripts/qa/v75140_grounded_enemy_crates_qa.gd \
    scripts/qa/v75141_live_map_loot_qa.gd \
    scripts/qa/v75142_physical_loot_minimap_qa.gd \
    scripts/qa/v75143_clean_br_nameplates_qa.gd \
    scripts/qa/v75144_grounded_weapon_models_qa.gd \
    scripts/qa/v75145_aircraft_live_map_qa.gd \
    scripts/qa/v75146_live_landing_guidance_qa.gd \
    scripts/qa/v75147_integrated_br_batch_qa.gd \
    scripts/qa/v75148_grenade_evasion_qa.gd \
    scripts/qa/v75149_grenade_fuse_sfx_qa.gd \
    scripts/qa/v75150_real_grenade_map_qa.gd \
    scripts/qa/v75151_real_awm_bolt_qa.gd \
    scripts/qa/v75152_weapon_recoil_reload_qa.gd \
    scripts/qa/v75153_weapon_round_lifecycle_qa.gd \
    scripts/qa/v75154_combat_camera_map_qa.gd \
    scripts/qa/v75157_map_edge_guidance_qa.gd \
    scripts/qa/v75156_tactical_map_pinch_anchor_qa.gd \
    scripts/qa/v75155_lobby_single_mode_hud_settings_qa.gd \
    scripts/qa/v75155_settings_hud_roundtrip_qa.gd \
    scripts/qa/capture_motorola_weapon_recoil_qa.gd \
    scripts/qa/capture_motorola_awm_bolt_qa.gd \
    scripts/qa/capture_motorola_grenade_threat_qa.gd \
    scripts/qa/capture_motorola_integrated_br_intel_qa.gd \
    scripts/qa/capture_motorola_flight_route_qa.gd \
    scripts/qa/capture_motorola_live_loot_minimap_qa.gd \
    scripts/qa/capture_motorola_live_loot_map_qa.gd \
    scripts/qa/capture_motorola_late_loot_qa.gd \
    scripts/ui/aurora_training_radar.gd \
    scripts/combat/aurora_weapon_families.gd \
    scripts/combat/aurora_equipment_families.gd \
    scripts/qa/v75132_skin_gallery_qa.gd \
    scripts/qa/v75131_mode_gallery_qa.gd \
    scripts/qa/v75130_gear_operators_qa.gd \
    scripts/qa/capture_motorola_inventory_operator_qa.gd \
    scripts/qa/v75129_armory_families_qa.gd \
    scripts/qa/v75128_level_armory_zone_rings_qa.gd \
    scripts/qa/capture_motorola_zone_map_qa.gd \
    scripts/qa/capture_motorola_armory_qa.gd; do
    safe_name="${source//\//_}"
    syntax_status=0
    timeout 40 "$GODOT" --headless --path "$ROOT" --check-only \
      --script "res://$source" > "$LOGS/${safe_name}.check.log" 2>&1 || syntax_status=$?
    if [ "$syntax_status" -ne 0 ] || \
        grep -Eq 'SCRIPT ERROR:|ERROR:' "$LOGS/${safe_name}.check.log"; then
      echo "AURORA_SCRIPT_CHECK_FAIL source=$source status=$syntax_status"
      tail -n 80 "$LOGS/${safe_name}.check.log"
      exit 1
    fi
    echo "AURORA_SCRIPT_CHECK_PASS source=$source"
  done
fi
failures=0
failed_scripts=()
for script in v75157_map_edge_guidance_qa v75156_tactical_map_pinch_anchor_qa v75155_settings_hud_roundtrip_qa v75155_lobby_single_mode_hud_settings_qa v75154_combat_camera_map_qa v75153_weapon_round_lifecycle_qa v75152_weapon_recoil_reload_qa v75151_real_awm_bolt_qa v75150_real_grenade_map_qa v75149_grenade_fuse_sfx_qa v75148_grenade_evasion_qa v75147_integrated_br_batch_qa v75146_live_landing_guidance_qa v75145_aircraft_live_map_qa v75144_grounded_weapon_models_qa v75143_clean_br_nameplates_qa v75142_physical_loot_minimap_qa v75141_live_map_loot_qa v75140_grounded_enemy_crates_qa v75139_near_deck_loot_qa v75138_opponent_loot_budget_qa v75136_objective_progress_qa v75133_map_readability_qa v75132_skin_gallery_qa v75131_mode_gallery_qa v75130_gear_operators_qa v75129_armory_families_qa v75128_level_armory_zone_rings_qa v75127_cartography_armory_qa v75126_airborne_loot_snap_qa v75125_real_enemy_airdrop_qa v75125_enemy_loadout_qa v75125_enemy_cover_qa v75125_expanded_world_qa v75125_health_balance_qa v75124_terrain_access_qa v75124_lobby_catalog_qa v75124_roof_collision_qa v75122_real_vehicles_qa v75121_backpack_levels_qa v75120_private_gear_qa v75120_mixamo_source_qa v75119_grenade_visual_qa v75119_extended_sources_music_qa v75118_scar_source_animations_qa v75118_optional_weapon_catalog_qa v75118_optional_weapon_visual_qa v75118_weapon_anchor_qa v75118_training_armory_qa v75117_awm_bolt_timeline_qa v75116_arctic_airfield_qa v75114_natural_polar_stage_qa v75114_loading_signal_motion_qa v75113_premium_frontend_rebuild_qa v75112_responsive_auth_briefing_qa v75111_lila_fullbody_framing_qa v75110_motorola_touch_loading_qa v75109_production_entry_lobby_qa v75108_interactive_operator_lobby_qa v75107_aurora_live_lobby_qa v75106_aurora_hud_reference_qa smoke_test combat_rules_test motorola_control_audit mobile_touch_routing_test camera_fire_qa multitouch_combat_qa sector_battle_qa launch_airdrop_qa persistent_match_qa crouch_collision_qa weapon_visual_qa v752_regression_qa persistence_recovery_qa responsive_layout_qa v753_combat_regression_qa v753_navigation_qa v753_animation_settings_qa v753_frontend_qa v754_aim_pose_qa v755_lobby_combat_qa v756_coastal_quarter_qa v757_world_audio_qa v758_world_stability_qa v759_camera_obstruction_qa v7510_animation_material_qa v7511_gait_coastal_qa v7512_player_settings_qa v7513_aurora_cover_qa v7514_freefall_crash_qa v7515_jump_transition_qa v7516_aircraft_startup_qa v7517_terrain_freefall_qa v7518_canopy_transition_qa v7519_canopy_preload_qa canopy_auto_handoff_qa canopy_diagnostic_modes_qa flight_blackbox_qa shared_scene_startup_qa v7520_navigation_batch_qa v7520_freefall_first_tick_qa v7523_audio_thread_qa v7524_wav_loop_guard_qa v7525_high_refresh_qa v7526_mobile_camera_controls_qa v7527_lobby_hud_editor_qa v7528_coastal_br_expansion_qa v7530_combat_sound_awareness_qa v7534_integrated_royale_qa v7540_residential_terrain_qa v7541_house_loot_qa v7541_settings_context_qa v7542_map_aircraft_brand_qa v7543_map_brand_awm_qa v7544_scale_lobby_qa v7545_mobile_render_pipeline_qa v7546_renderer_variants_qa v7547_render_frame_pacing_qa v7548_battle_loot_qa v7549_tactical_first_aid_qa v7550_tactical_ai_combat_qa v7555_unified_battle_royale_qa v7556_combat_feedback_qa v7557_ten_minute_ledger_qa v7558_physical_headshot_qa v7559_lila_rig_identity_qa v7560_lila_hair_holster_qa v7560_lila_tactical_ability_qa v7561_lila_motion_precision_qa v7562_bot_medicine_tactics_qa v7563_lila_medkit_visual_qa v7564_opponent_inventory_loot_qa v7565_tactical_strafe_animation_qa v7566_directional_hit_awm_recoil_qa v7567_lobby_mode_gate_qa v7568_local_coins_ledger_qa v7569_unified_objectives_qa v7570_local_autobackup_recovery_qa v7571_local_profile_export_qa v7573_local_name_identity_qa v7574_firebase_bridge_preflight_qa v7575_native_auth_link_qa v7577_lobby_account_ux_qa v7578_aurora_lobby_login_reference_qa v7579_premium_lobby_stage_qa v7580_lobby_preview_lifecycle_qa v7581_fifty_ai_final_zone_qa v7582_free_pass_claim_qa v7583_mobile_ai_rig_budget_qa v7584_near_enemy_rig_priority_qa v7585_real_local_skin_shop_qa v7587_single_fifty_roster_qa v7588_moving_zone_qa v7589_fifty_bot_ai_budget_qa v7590_proactive_zone_rotation_qa v7590_fifty_survivor_results_qa v7591_final_ring_ai_qa v7592_acoustic_radar_qa v7593_elimination_integrity_qa v7594_storm_ai_threat_qa v7595_safe_parachute_landing_qa v7596_elimination_visual_qa v7597_directional_opponent_impact_qa v7598_known_contact_pursuit_qa v7599_cover_visibility_qa v75100_bot_weapon_motion_qa v75101_bot_hand_rifle_qa v75102_rifle_muzzle_qa v75103_aurora_v3_qa v75104_aurora_addendum_qa v75105_aurora_entry_flow_qa; do
  extension=gd
  if [ "${AURORA_QA_EXPORTED:-0}" = 1 ]; then extension=gdc; fi
  status=0
  timeout 90 "$GODOT" --headless --path "$ROOT" --script "res://scripts/qa/$script.$extension" > "$LOGS/$script.running" 2>&1 || status=$?
  mv "$LOGS/$script.running" "$LOGS/$script.log"
  # Collect every independent regression result in one run. A failure
  # remains fatal for the overall QA job, but no longer hides later errors.
  failure_reason=""
  if [ "$status" -ne 0 ]; then
    failure_reason="exit=$status"
  fi
  if grep -Eq 'SCRIPT ERROR:|ERROR:' "$LOGS/$script.log"; then
    failure_reason="${failure_reason:+$failure_reason,}error_log"
  fi
  marker='PASS'
  case "$script" in
    smoke_test) marker='TPS HUD OK';;
    combat_rules_test) marker='AR automatic fire verified';;
    v752_regression_qa) marker='V752_COVER blocked=100 clear=';;
    responsive_layout_qa) marker='RESPONSIVE_LAYOUT (1024, 768)';;
  esac
  if ! grep -Fq "$marker" "$LOGS/$script.log"; then
    failure_reason="${failure_reason:+$failure_reason,}missing_marker"
  fi
  if [ -n "$failure_reason" ]; then
    printf '%s FAIL (%s)\n' "$script" "$failure_reason"
    tail -n 90 "$LOGS/$script.log"
    failed_scripts+=("$script:$failure_reason")
    failures=$((failures+1))
  else
    echo "$script PASS"
  fi
done
if [ "$failures" -gt 0 ]; then
  printf '%s\n' "AURORA_QA_FAILED_COUNT=$failures" > "$LOGS/summary.log"
  printf '%s\n' "${failed_scripts[@]}" | tee -a "$LOGS/summary.log"
  exit 1
fi
echo "AURORA_QA_ALL_PASS" | tee "$LOGS/summary.log"
