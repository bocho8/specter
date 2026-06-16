#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
. "$MODDIR/../lib/vbmeta.sh"
. "$MODDIR/../lib/config_env.sh"
APK="$MODDIR/../apk/specter.apk"
PACKAGE="com.dpejoh.specter"

log "TEE" "Start"

sleep 15

[ ! -f "$APK" ] && { log "TEE" "APK not found: $APK"; exit 1; }

for _i in 1 2 3 4 5; do
  _tee=$(content query --uri content://$PACKAGE/check 2>/dev/null \
    | grep -o 'status=[a-z]*' | cut -d= -f2) || true
  [ -n "$_tee" ] && break
  sleep 0.5
done
_hash=$(content query --uri content://$PACKAGE/hash 2>/dev/null \
  | grep -oE '[a-f0-9]{64}|unavailable') || true
case "$_hash" in
  0000000000000000000000000000000000000000000000000000000000000000) _hash="unavailable" ;;
esac
unset _i

pm uninstall $PACKAGE 2>/dev/null || true

ensure_dir "$SPECTER_DIR"

case "$_tee" in
  normal) echo "tee_broken=false" > "$TEE_STATUS"; log "TEE" "Status: normal" ;;
  broken) echo "tee_broken=true"  > "$TEE_STATUS"; log "TEE" "Status: broken" ;;
  *)      echo "tee_broken=unknown" > "$TEE_STATUS"; log "TEE" "Status: unavailable ($_tee)" ;;
esac

_publish_hash() {
  echo "$1" > "$TEE_HASH"
  [ -z "$(cfg_get custom_boot_hash "")" ] && echo "$1" > "$VBMETA_DIGEST"
  log "TEE" "Hash: $1 ($2)"
}

if [ "$_hash" != "unavailable" ] && [ -n "$_hash" ]; then
  _publish_hash "$_hash" "tee"
else
  _tee_slot=$(getprop ro.boot.slot_suffix 2>/dev/null || echo "")
  _tee_vbmeta_dev="/dev/block/by-name/vbmeta${_tee_slot}"
  [ -b "$_tee_vbmeta_dev" ] || _tee_vbmeta_dev="/dev/block/by-name/vbmeta"
  _partition_hash=$(vbmeta_digest "$_tee_vbmeta_dev" || true)
  unset _tee_slot _tee_vbmeta_dev
  if [ -n "$_partition_hash" ]; then
    _publish_hash "$_partition_hash" "fallback"
    echo "tee_fallback=true" >> "$TEE_STATUS"
    log "TEE" "Status: fallback (TEE unavailable, using partition hash)"
  else
    log "TEE" "Hash: unavailable (TEE and partition both failed)"
  fi
fi

log "TEE" "Done"
