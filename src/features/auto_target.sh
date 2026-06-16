#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
. "$MODDIR/../lib/paths.sh"
. "$MODDIR/../lib/package_list.sh"
. "$MODDIR/../lib/config_env.sh"

BLACKLIST="$SPECTER_DIR/blacklist.txt"
BLACKLIST_ENABLED="$SPECTER_DIR/blacklist_enabled"
KNOWN_PKGS="$SPECTER_DIR/auto_known_packages.txt"
TEMP_LIST="$SPECTER_DIR/auto_scan_tmp.txt"

log "AUTO_TARGET" "Scanning for new packages"

[ -f "$TARGET_TXT" ] || { log "AUTO_TARGET" "target.txt missing, skipping"; exit 0; }

pkgs=$(pm list packages -3 2>/dev/null) || { log "AUTO_TARGET" "pm failed"; exit 1; }
echo "$pkgs" | cut -d ":" -f 2 | sort -u > "$TEMP_LIST"
[ ! -s "$TEMP_LIST" ] && { rm -f "$TEMP_LIST"; exit 0; }

_known=""
[ -f "$KNOWN_PKGS" ] && _known=$(cat "$KNOWN_PKGS")

_new_pkgs=""
while IFS= read -r _pkg; do
  [ -z "$_pkg" ] && continue
    if ! echo "$_known" | grep -Fxq "$_pkg" 2>/dev/null && ! grep -Fxq "$_pkg" "$TARGET_TXT" 2>/dev/null; then
    if [ -f "$BLACKLIST_ENABLED" ] && [ -s "$BLACKLIST" ]; then
      if grep -Fxq "$_pkg" "$BLACKLIST" 2>/dev/null; then
        continue
      fi
    fi
    _new_pkgs="$_new_pkgs$_pkg
"
  fi
done < "$TEMP_LIST"

if [ -n "$_new_pkgs" ]; then
  _added=0
  while IFS= read -r _pkg; do
    [ -z "$_pkg" ] && continue
    echo "$_pkg" >> "$TARGET_TXT"
    _added=$((_added + 1))
  done <<EOF
$_new_pkgs
EOF
  log "AUTO_TARGET" "Added $_added new package(s)"
fi

cp "$TEMP_LIST" "$KNOWN_PKGS" 2>/dev/null || true
rm -f "$TEMP_LIST"
log "AUTO_TARGET" "Done"
exit 0
