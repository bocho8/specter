#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
. "$MODDIR/../lib/paths.sh"

log "GMS" "Start"

if ! pm list packages | grep -q com.android.vending; then
  log "GMS" "Warning: Play Store not installed, skipping"
  exit 0
fi

am force-stop com.android.vending >/dev/null 2>&1 || true
cmd package trim-caches 0 com.android.vending >/dev/null 2>&1 || true

log "GMS" "Finish"
