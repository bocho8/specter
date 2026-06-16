# shellcheck shell=sh
# shellcheck disable=SC2034
MODDIR="$MODPATH"
. "$MODPATH/lib/common.sh"
. "$MODPATH/lib/config_env.sh"
. "$MODPATH/lib/urls.sh"

# Clean up old uppercase paths (module id + data dir)
rm -rf /data/adb/modules/Specter /data/adb/Specter

ui_print ""
ui_print "____                  _            "
ui_print "/ ___| _ __   ___  ___| |_ ___ _ __ "
ui_print "\\___ \\| '_ \\ / _ \\/ __| __/ _ \\ '__|"
ui_print " ___) | |_) |  __/ (__| ||  __/ |   "
ui_print "|____/| .__/ \\___|\\___|\\__\\___|_|   "
ui_print "      |_|                           "
ui_print ""

ui_print "- Checking device info..."
detect_root_solution
[ "$ROOT_TYPE" != "Unknown" ] && ui_print "- $ROOT_TYPE detected"

_ts_found=false
_ts_name=$(_ts_prop)
case "$_ts_name" in
  TEESimulator-RS) _ts_found=true; ui_print "- TEESimulator-RS found" ;;
  TEESimulator)    _ts_found=true; ui_print "- TEESimulator found" ;;
  *Tricky*)        _ts_found=true; ui_print "- Tricky Store found" ;;
  "")              ;;
  *)               _ts_found=true; ui_print "- $_ts_name found" ;;
esac
unset _ts_name

_pif_name=$(_pif_prop)
[ -n "$_pif_name" ] && ui_print "- $_pif_name found"
unset _pif_name

# TEE status check, read from cache only
_tee=
if [ -f "$TEE_STATUS" ]; then
  _tee_val=$(grep -E '^(teeBroken|tee_broken)=' "$TEE_STATUS" 2>/dev/null | cut -d= -f2)
  case "$_tee_val" in
    true)  _tee="broken" ;;
    false) _tee="normal" ;;
  esac
  unset _tee_val
fi
case "$_tee" in
  normal|broken)
    ui_print "- TEE: $_tee"
    ;;
esac
unset _tee

# Download and install TEE check APK (done at install time while Binder is accessible)
mkdir -p "$MODPATH/apk"
curl -fsSL -o "$MODPATH/apk/specter.apk" "$TEE_CHECK_URL" 2>/dev/null || true
if [ -f "$MODPATH/apk/specter.apk" ]; then
  pm install -r "$MODPATH/apk/specter.apk" 2>/dev/null || true
fi

if [ "$_ts_found" = true ]; then
  ui_print ""
  ui_print " >> First-boot setup: keybox + target (next reboot)"
fi
unset _ts_found

# Mark first-boot setup as pending (runs once after reboot in boot_core.sh)
touch "$MODPATH/.first_boot_pending"

mkdir -p "$MODPATH/webroot/json"
echo "{\"MODDIR\": \"$MODPATH\", \"SPECTER_DIR\": \"$SPECTER_DIR\"}" > "$MODPATH/webroot/json/module_paths.json"

# Backup module.prop for description override system
cp "$MODPATH/module.prop" "$MODPATH/module.prop.bak"

# Mark TEE for first-boot check (removed by boot_core.sh after running)
mkdir -p "$SPECTER_DIR"
echo "1" > "$SPECTER_DIR/tee_reported"
echo "1" > "$SPECTER_DIR/rom_spoof_reported"

# Copy shipped config files to data dir
mkdir -p "$SPECTER_DIR/config"
cp "$MODPATH/config/conflicts.txt" "$SPECTER_DIR/config/conflicts.txt" 2>/dev/null || true

# Conflicts are resolved automatically at boot, no interactive prompts needed

# Generate fresh keybox info for description
if [ -d "$MODULES_BASE/tricky_store" ] || [ -d "${MODULES_BASE}_update/tricky_store" ]; then
  sh "$MODPATH/features/keybox_info.sh" >/dev/null 2>&1 || true
fi

# Refresh module description so manager shows dynamic status immediately
. "$MODPATH/lib/desc.sh"
refresh_module_description

return 0
