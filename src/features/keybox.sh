#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
. "$MODDIR/../lib/paths.sh"

log "KEYBOX" "Start"

if [ ! -d "/data/adb/modules/tricky_store" ] && [ ! -d "/data/adb/modules_update/tricky_store" ]; then
  log "KEYBOX" "Warning: Tricky Store not installed, skipping"
  exit 0
fi

if [ -f "$TARGET_FILE" ]; then
  cp "$TARGET_FILE" "$BACKUP_FILE"
fi

TEMP_FILE="$TRICKY_DIR/keybox.tmp"
download "$KEYBOX_URL" > "$TEMP_FILE" || {
  log "KEYBOX" "Error: Download failed"
  rm -f "$TEMP_FILE"
  [ -f "$BACKUP_FILE" ] && cp "$BACKUP_FILE" "$TARGET_FILE"
  exit 1
}

if ! base64 -d "$TEMP_FILE" > "$TARGET_FILE" 2>/dev/null; then
  log "KEYBOX" "Error: Base64 decode failed"
  rm -f "$TEMP_FILE"
  [ -f "$BACKUP_FILE" ] && cp "$BACKUP_FILE" "$TARGET_FILE"
  exit 1
fi

rm -f "$TEMP_FILE"
log "KEYBOX" "Finish"
