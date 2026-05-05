#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/lib/common.sh"
. "$MODDIR/lib/paths.sh"

if [ -f "$BACKUP_FILE" ]; then
    rm -f "$TARGET_FILE"
    mv "$BACKUP_FILE" "$TARGET_FILE"
    log "UNINSTALL" "Restored original keybox from backup"
fi

if [ -d "$BBIN" ]; then
    rm -rf "$BBIN" 2>/dev/null
    log "UNINSTALL" "Removed $BBIN"
fi

if [ -d "$CONFIG_DIR" ]; then
    rm -rf "$CONFIG_DIR" 2>/dev/null
    log "UNINSTALL" "Removed $CONFIG_DIR"
fi

if [ -f "$MIGRATION_MARKER" ]; then
    rm -f "$MIGRATION_MARKER" 2>/dev/null
    log "UNINSTALL" "Removed migration marker"
fi

if [ -f "$BOOT_HASH_FILE" ]; then
    rm -f "$BOOT_HASH_FILE" 2>/dev/null
    log "UNINSTALL" "Removed boot hash file"
fi

if [ -f "$IDFILE" ]; then
    rm -f "$IDFILE" 2>/dev/null
    log "UNINSTALL" "Removed RKA ID file"
fi

# Clean up RKA config in PassIt app data
_uid=$(id -u 2>/dev/null || echo "")
if [ -n "$_uid" ]; then
  RKA_CFG="/data/user/$_uid/io.github.mhmrdd.libxposed.ps.passit/files/rka_configs.json"
  if [ -f "$RKA_CFG" ]; then
      rm -f "$RKA_CFG" 2>/dev/null
      log "UNINSTALL" "Removed RKA config"
  fi
  unset RKA_CFG
fi
unset _uid

# Restore persisted props
if [ -f "/data/adb/Specter/persist_backup.txt" ]; then
  sh "/data/adb/Specter/persist_backup.txt" 2>/dev/null || true
  rm -f "/data/adb/Specter/persist_backup.txt" 2>/dev/null
  log "UNINSTALL" "Restored persistent props"
fi

return 0
