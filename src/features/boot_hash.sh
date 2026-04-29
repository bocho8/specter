#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
. "$MODDIR/../lib/paths.sh"

log "BOOT_HASH" "Start"

boot_hash=$(getprop ro.boot.vbmeta.digest 2>/dev/null)
[ -z "$boot_hash" ] && boot_hash="0000000000000000000000000000000000000000000000000000000000000000"

ensure_dir "$(dirname "$BOOT_HASH_FILE")"
echo "$boot_hash" > "$BOOT_HASH_FILE"
chmod 644 "$BOOT_HASH_FILE"

resetprop -n ro.boot.vbmeta.digest "$boot_hash" >/dev/null 2>&1

log "BOOT_HASH" "Finish"
