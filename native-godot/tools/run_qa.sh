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
fi
for script in smoke_test combat_rules_test motorola_control_audit mobile_touch_routing_test camera_fire_qa multitouch_combat_qa sector_battle_qa launch_airdrop_qa persistent_match_qa crouch_collision_qa weapon_visual_qa v752_regression_qa persistence_recovery_qa responsive_layout_qa v753_combat_regression_qa v753_navigation_qa v753_animation_settings_qa v753_frontend_qa v754_aim_pose_qa v755_lobby_combat_qa v756_coastal_quarter_qa v757_world_audio_qa v758_world_stability_qa v759_camera_obstruction_qa v7510_animation_material_qa v7511_gait_coastal_qa v7512_player_settings_qa v7513_aurora_cover_qa v7514_freefall_crash_qa v7515_jump_transition_qa v7516_aircraft_startup_qa v7517_terrain_freefall_qa v7518_canopy_transition_qa v7519_canopy_preload_qa canopy_auto_handoff_qa canopy_diagnostic_modes_qa flight_blackbox_qa shared_scene_startup_qa v7520_navigation_batch_qa v7520_freefall_first_tick_qa v7523_audio_thread_qa v7524_wav_loop_guard_qa v7525_high_refresh_qa v7526_mobile_camera_controls_qa v7527_lobby_hud_editor_qa v7528_coastal_br_expansion_qa v7530_combat_sound_awareness_qa v7534_integrated_royale_qa v7540_residential_terrain_qa v7541_house_loot_qa v7541_settings_context_qa v7542_map_aircraft_brand_qa v7543_map_brand_awm_qa v7544_scale_lobby_qa v7545_mobile_render_pipeline_qa v7546_renderer_variants_qa v7547_render_frame_pacing_qa v7548_battle_loot_qa v7549_tactical_first_aid_qa v7550_tactical_ai_combat_qa v7555_unified_battle_royale_qa v7556_combat_feedback_qa v7557_ten_minute_ledger_qa v7558_physical_headshot_qa v7559_lila_rig_identity_qa v7560_lila_hair_holster_qa v7560_lila_tactical_ability_qa v7561_lila_motion_precision_qa v7562_bot_medicine_tactics_qa v7563_lila_medkit_visual_qa v7564_opponent_inventory_loot_qa v7565_tactical_strafe_animation_qa v7566_directional_hit_awm_recoil_qa v7567_lobby_mode_gate_qa v7568_local_coins_ledger_qa v7569_unified_objectives_qa v7570_local_autobackup_recovery_qa v7571_local_profile_export_qa; do
  extension=gd
  if [ "${AURORA_QA_EXPORTED:-0}" = 1 ]; then extension=gdc; fi
  status=0
  timeout 90 "$GODOT" --headless --path "$ROOT" --script "res://scripts/qa/$script.$extension" > "$LOGS/$script.running" 2>&1 || status=$?
  mv "$LOGS/$script.running" "$LOGS/$script.log"
  if [ "$status" -ne 0 ]; then
    cat "$LOGS/$script.log"
    exit 1
  fi
  if grep -E 'SCRIPT ERROR:|ERROR:' "$LOGS/$script.log"; then exit 1; fi
  marker='PASS'
  case "$script" in
    smoke_test) marker='TPS HUD OK';;
    combat_rules_test) marker='AR automatic fire verified';;
    v752_regression_qa) marker='V752_COVER blocked=100 clear=';;
    responsive_layout_qa) marker='RESPONSIVE_LAYOUT (1024, 768)';;
  esac
  if ! grep -Fq "$marker" "$LOGS/$script.log"; then
    echo "Incomplete test: $script"
    cat "$LOGS/$script.log"
    exit 1
  fi
  echo "$script PASS"
done
