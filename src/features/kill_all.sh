#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
. "$MODDIR/../lib/paths.sh"
. "$MODDIR/../lib/package_list.sh"

log "KILL_ALL" "Start"

ALL_PKGS="$DETECTOR_APPS $GMS_APPS"

for pkg in $ALL_PKGS; do
  if ! pm list packages | grep -q "$pkg"; then
    log "KILL_ALL" "Package $pkg not installed, skipping"
    continue
  fi
  am force-stop "$pkg" >/dev/null 2>&1 || true
  pm clear "$pkg" >/dev/null 2>&1 || true
done

log "KILL_ALL" "Finish"
