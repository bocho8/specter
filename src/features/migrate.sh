#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
. "$MODDIR/../lib/paths.sh"

log "MIGRATE" "Start"

if [ -f "$MIGRATION_MARKER" ]; then
  log "MIGRATE" "Migration already completed, skipping"
  exit 0
fi

MODULE_ROOT="$(dirname "$MODDIR")"

if [ -d "$MODULE_ROOT/Yuri" ]; then
  rm -rf "$MODULE_ROOT/Yuri" 2>/dev/null
  log "MIGRATE" "Removed old Module/Yuri/ directory"
fi

_old_files="webroot/common/clear_all_detection_traces.sh webroot/common/widevinel1.sh webroot/common/lsposed2.sh webroot/common/boot_hash.sh"
for _f in $_old_files; do
  if [ -f "$MODULE_ROOT/$_f" ]; then
    rm -f "$MODULE_ROOT/$_f" 2>/dev/null
    log "MIGRATE" "Removed old file: $_f"
  fi
done

touch "$MIGRATION_MARKER" 2>/dev/null
log "MIGRATE" "Migration marker written to $MIGRATION_MARKER"

unset MODULE_ROOT _old_files _f
log "MIGRATE" "Finish"
