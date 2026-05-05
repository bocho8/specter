#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
. "$MODDIR/../lib/paths.sh"
. "$MODDIR/../lib/package_list.sh"

log "KILL_ALL" "Start"

_count=0
ALL_PKGS="$DETECTOR_APPS $GMS_APPS $REMOTE_CONTROL_APPS $TOOL_APPS"
_installed_pkgs=$(pm list packages 2>/dev/null)

for pkg in $ALL_PKGS; do
  echo "$_installed_pkgs" | grep -Fq "package:$pkg" || continue
  am force-stop "$pkg" >/dev/null 2>&1 || true
  pm clear "$pkg" >/dev/null 2>&1 || true
  _count=$((_count + 1))
done
unset _installed_pkgs

log "KILL_ALL" "Cleared $_count packages"
log "KILL_ALL" "Finish"
exit 0
