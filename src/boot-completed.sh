#!/system/bin/sh
set -e
MODDIR=${0%/*}
# Guard: KernelSU and APatch both set $KSU=true; skip if not running under them
[ -z "$KSU" ] && exit 0

. "$MODDIR/lib/common.sh"
. "$MODDIR/lib/paths.sh"
. "$MODDIR/lib/config_env.sh"

log "BOOT" "Boot completed — finalizing"

apply_boot_hardening

_release=$(getprop ro.build.version.release 2>/dev/null || echo "Unknown")
if [ -f "$TARGET_FILE" ]; then
    cfg_set "override.description" "Active | $_release"
    log "BOOT" "Description set to: Active | $_release"
else
    cfg_set "override.description" "Run action button to set up keybox"
    log "BOOT" "Description set to: Run action button to set up keybox"
fi
unset _release

log "BOOT" "Done"
