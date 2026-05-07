#!/system/bin/sh
# shellcheck shell=sh
set -e
MODDIR=${0%/*}

# shellcheck disable=SC3040
set +o standalone
unset ASH_STANDALONE

. "$MODDIR/lib/common.sh"
. "$MODDIR/lib/config_env.sh"

_feature_enabled() { [ "$(cfg_get "$1" 1)" != "0" ]; }

log "ACTION" "Running full integrity pipeline"

_feature_enabled toggle_action_gms && sh "$MODDIR/features/kill_play_store.sh" 2>/dev/null || true
_feature_enabled toggle_action_target && sh "$MODDIR/features/target.sh" 2>/dev/null || true
_feature_enabled toggle_action_security_patch && sh "$MODDIR/features/security_patch.sh" 2>/dev/null || true
_feature_enabled toggle_action_boot_hash && sh "$MODDIR/features/boot_hash.sh" 2>/dev/null || true
sh "$MODDIR/features/keybox.sh" 2>/dev/null || true
_feature_enabled toggle_action_pif && sh "$MODDIR/features/pif.sh" 2>/dev/null || true

run_device_info "$MODDIR"

log "ACTION" "Meets Strong Integrity with Specter"

[ "${0##*/}" = "action.sh" ] && exit 0 || return 0
