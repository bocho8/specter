#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
. "$MODDIR/../lib/config_env.sh"
[ "$(cfg_get toggle_lsposed 1)" = "0" ] && exit 0

log "LSPOSED" "Start"

_count=$(find /data/app -type f -name base.odex 2>/dev/null | wc -l)
if [ "$_count" -gt 0 ]; then
  find /data/app -type f -name base.odex -delete 2>/dev/null || log "LSPOSED" "Warning: Failed to delete some base.odex files"
  log "LSPOSED" "Deleted $_count base.odex files"
else
  log "LSPOSED" "No base.odex files found"
fi

log "LSPOSED" "Finish"
exit 0
