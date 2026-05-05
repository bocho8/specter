#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
. "$MODDIR/../lib/package_list.sh"

log "GMS" "Start"

_installed_pkgs=$(pm list packages 2>/dev/null)
_count=0

for _pkg in $GMS_KILL_LIST; do
  echo "$_installed_pkgs" | grep -Fq "package:$_pkg" || continue
  log "GMS" "Force-stopping $_pkg"
  am force-stop "$_pkg" >/dev/null 2>&1 || log "GMS" "Warning: Failed to force-stop $_pkg"
  _count=$((_count + 1))
done

if echo "$_installed_pkgs" | grep -q "package:com.android.vending"; then
  log "GMS" "Trimming Play Store cache..."
  cmd package trim-caches 999999999 com.android.vending >/dev/null 2>&1 || log "GMS" "Warning: Failed to clear Play Store cache"
fi
unset _installed_pkgs

log "GMS" "Force-stopped $_count packages"
log "GMS" "Finish"
exit 0
