. "$MODPATH/lib/common.sh"
. "$MODPATH/lib/urls.sh"

TEMP_FILE="$MODPATH/keybox.tmp"

download "$KEYBOX_URL" > "$TEMP_FILE" 2>/dev/null
if [ -f "$TEMP_FILE" ] && [ -s "$TEMP_FILE" ]; then
    TRICKY_DIR="/data/adb/tricky_store"
    mkdir -p "$TRICKY_DIR"
    TARGET_FILE="$TRICKY_DIR/keybox.xml"
    BACKUP_FILE="$TRICKY_DIR/keybox.xml.bak"

    if [ -f "$TARGET_FILE" ]; then
        if ! grep -q "yuriiroot" "$TARGET_FILE" 2>/dev/null; then
            cp "$TARGET_FILE" "$BACKUP_FILE"
        fi
    fi

    if base64 -d "$TEMP_FILE" > "$TARGET_FILE" 2>/dev/null; then
        ui_print "- Keybox installed successfully"
    else
        ui_print "- Error: Base64 decode failed"
    fi
    rm -f "$TEMP_FILE"
else
    ui_print "- Warning: Keybox download failed (non-fatal)"
    rm -f "$TEMP_FILE"
fi

mkdir -p "$MODPATH/webroot/json"
cat > "$MODPATH/webroot/json/module_paths.json" <<JSON
{"MODDIR": "$MODPATH"}
JSON

case "$ARCH" in
    arm64) RKA_ARCH="arm64-v8a" ;;
    arm)   RKA_ARCH="armeabi-v7a" ;;
    x64)   RKA_ARCH="x86_64" ;;
    x86)   RKA_ARCH="x86" ;;
    *)     RKA_ARCH="arm64-v8a" ;;
esac
mkdir -p "$MODPATH/rka/$RKA_ARCH"
download "$SQLITE_BASE_URL/${RKA_ARCH}/sqlite3" > "$MODPATH/rka/$RKA_ARCH/sqlite3" 2>/dev/null && chmod 755 "$MODPATH/rka/$RKA_ARCH/sqlite3" \
    || ui_print "- Warning: RKA sqlite3 download failed (non-fatal)"

if [ -f "$MODPATH/features/migrate.sh" ]; then
    sh "$MODPATH/features/migrate.sh" || ui_print "- Warning: migration incomplete"
fi

if [ -f "$MODPATH/webroot/common/device-info.sh" ]; then
    sh "$MODPATH/webroot/common/device-info.sh"
fi

return 0
