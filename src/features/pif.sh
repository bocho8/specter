#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"

log "PIF" "Start"

TARGET_FILE="/data/adb/modules/playintegrityfix"

if [ ! -d "$TARGET_FILE" ]; then
  log "PIF" "Warning: Play Integrity Fix not installed, skipping"
  exit 0
fi

MODULE_NAME=$(grep "^name=" "$TARGET_FILE/module.prop" 2>/dev/null | cut -d= -f2-)
[ -z "$MODULE_NAME" ] && { log "PIF" "Warning: Cannot read module.prop, skipping"; exit 0; }

case "$MODULE_NAME" in
  "Play Integrity Fix [INJECT]")
    log "PIF" "Detected INJECT variant"
    sh "$TARGET_FILE/autopif_ota.sh" 2>/dev/null || true
    sh "$TARGET_FILE/autopif.sh" 2>/dev/null || log "PIF" "Warning: autopif.sh failed"
    ;;
  "Play Integrity Fork")
    log "PIF" "Detected Fork variant"
    sh "$TARGET_FILE/autopif4.sh" -m 2>/dev/null || log "PIF" "Warning: autopif4.sh failed"
    ;;
  *)
    log "PIF" "Warning: Unknown module: $MODULE_NAME"
    exit 0
    ;;
esac

log "PIF" "Finish"
