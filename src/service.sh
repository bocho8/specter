#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/lib/common.sh"
. "$MODDIR/lib/package_list.sh"
. "$MODDIR/lib/config_env.sh"
export ROOT_SOL

while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done

BOOT_LOG="$SPECTER_DIR/log/boot.log"
mkdir -p "$SPECTER_DIR/log" 2>/dev/null || true
log_rotate "$BOOT_LOG"
exec >>"$BOOT_LOG" 2>&1

log "SERVICE" "Running Specter boot tasks"

for _bf in boot_hardening adb_disabler rom_fingerprint vbmeta; do
  case "$_bf" in *[!a-zA-Z0-9_-]*) log "SERVICE" "Skipping invalid feature: $_bf"; continue ;; esac
  _bf_default=1
  case "$_bf" in adb_disabler|rom_fingerprint) _bf_default=0 ;; esac
  _feature_should_run "$_bf" $_bf_default || { log "SERVICE" "Skipping $_bf (disabled by config)"; continue; }
  sh "$MODDIR/features/$_bf.sh" >"$SPECTER_DIR/log/boot_${_bf}.log" 2>&1 || log "SERVICE" "$_bf failed (exit $?)"
done
unset _bf _bf_default

if _feature_should_run "prop_handler"; then
  [ "$(cfg_get boot_state_props 1)" != "0" ] && ! _conflict_claimed "boot_state_props" && apply_boot_props
  [ "$(cfg_get spoof_build_props 1)" != "0" ] && ! _conflict_claimed "spoof_build_props" && spoof_build_props
  [ "$(cfg_get region_props 1)" != "0" ] && ! _conflict_claimed "region_props" && apply_region_props
  sh "$MODDIR/features/boot_state_props.sh" >"$SPECTER_DIR/log/boot_state_props.log" 2>&1
else
  log "SERVICE" "Skipping prop_handler (disabled by config)"
fi

log "SERVICE" "Boot-time features done"

disable_bootloader_spoofer 2>/dev/null || true

[ -f "$SPECTER_DIR/tee_reported" ] && {
  sh "$MODDIR/features/tee.sh" >"$SPECTER_DIR/log/boot_tee.log" 2>&1
  [ -f "$TEE_STATUS" ] && rm -f "$SPECTER_DIR/tee_reported" || log "SERVICE" "TEE check failed, will retry on next boot"
}

[ -f "$SPECTER_DIR/rom_spoof_reported" ] && {
  sh "$MODDIR/features/rom_spoof_cleanup.sh" >/dev/null 2>&1 || true
  rm -f "$SPECTER_DIR/rom_spoof_reported"
}

ensure_dir "$SPECTER_DIR/backup" 2>/dev/null || true
if [ -f "$MODDIR/.first_boot_pending" ]; then
  log "SERVICE" "First-boot setup pending, running..."
  sh "$MODDIR/features/first_boot_setup.sh" >"$SPECTER_DIR/log/first_boot_setup.log" 2>&1 || log "SERVICE" "First-boot setup failed"
  rm -f "$MODDIR/.first_boot_pending"
  log "SERVICE" "First-boot setup complete"
fi

. "$MODDIR/lib/desc.sh"
refresh_module_description

[ "$(cfg_get toggle_scheduler 1)" != "0" ] && {
  sh "$MODDIR/lib/scheduler.sh" >"$SPECTER_DIR/log/scheduler.log" 2>&1 &
  log "SERVICE" "Scheduler launched (PID $!)"
}

log "SERVICE" "Specter boot tasks complete"
