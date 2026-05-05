#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
. "$MODDIR/../lib/paths.sh"
. "$MODDIR/../lib/urls.sh"

log "KEYBOX" "Start"

check_network || { log "KEYBOX" "Error: No internet connection"; exit 1; }

[ -d "$TRICKY_DIR" ] || die "Tricky Store data directory not found"

if [ -f "$TARGET_FILE" ] && [ ! -f "$BACKUP_FILE" ]; then
  cp "$TARGET_FILE" "$BACKUP_FILE"
  log "KEYBOX" "Created backup of existing keybox"
fi

DECODE_FILE="/data/local/tmp/keybox_decode.$$"
TEMP_FILE="/data/local/tmp/keybox.tmp.$$"
trap 'rm -f "$DECODE_FILE" "$TEMP_FILE" 2>/dev/null' EXIT
_FALLBACK_BASE="${KEYBOX_URL}/fallback"

_custom_type=$(cat "$CONFIG_DIR/kb_custom_type.val" 2>/dev/null || echo "")
_custom_value=$(cat "$CONFIG_DIR/kb_custom_value.val" 2>/dev/null || echo "")

if [ -n "$_custom_type" ] && [ -n "$_custom_value" ]; then
  log "KEYBOX" "Using custom keybox: $_custom_type ($_custom_value)"
  case "$_custom_type" in
    file|path)
      if [ -f "$_custom_value" ]; then
        cp "$_custom_value" "$TARGET_FILE" || die "Failed to copy custom keybox"
        log "KEYBOX" "Custom keybox installed from $_custom_value"
        rm -f "$TEMP_FILE"
        exit 0
      fi
      log "KEYBOX" "Error: Custom keybox file not found: $_custom_value"
      rm -f "$TEMP_FILE"
      exit 1
      ;;
    url)
      log "KEYBOX" "Downloading custom keybox from URL..."
      download "$_custom_value" > "$TEMP_FILE" || {
        log "KEYBOX" "Error: Custom URL download failed"
        rm -f "$TEMP_FILE"
        [ -f "$BACKUP_FILE" ] && cp "$BACKUP_FILE" "$TARGET_FILE"
        exit 1
      }
      if base64 -d "$TEMP_FILE" > "$DECODE_FILE" 2>/dev/null && [ -s "$DECODE_FILE" ]; then
        mv "$DECODE_FILE" "$TARGET_FILE" || die "Failed to move decoded keybox"
      else
        cp "$TEMP_FILE" "$TARGET_FILE" || die "Failed to copy keybox"
      fi
      rm -f "$TEMP_FILE"
      log "KEYBOX" "Custom keybox installed from URL"
      exit 0
      ;;
  esac
fi

_provider=$(cat "$CONFIG_DIR/kb_provider.val" 2>/dev/null || echo "auto")

log "KEYBOX" "Fetching available keyboxes..."
_history=$(download "$CATALOG_URL" 2>/dev/null)

if [ -z "$_history" ]; then
  log "KEYBOX" "Catalog fetch failed, probing fallback URLs..."
  _valid=""
  for _i in 0 1 2 3 4 5 6 7 8 9; do
    _url="$_FALLBACK_BASE/keybox$_i"
    if wget --spider "$_url" 2>/dev/null || curl --output /dev/null --silent --head --fail "$_url"; then
      _valid="$_valid $_i"
    fi
  done
  if [ -n "$_valid" ]; then
    _pick=$(echo "$_valid" | tr ' ' '\n' | sort -R | head -1)
    _DL_SOURCE="fallback"
    _DL_VER="keybox$_pick"
    log "KEYBOX" "Fallback selected: $_DL_VER"
  else
    log "KEYBOX" "Error: No fallback keybox found"
    exit 1
  fi
else
  if [ "$_provider" = "auto" ]; then
    _working_source=$(echo "$_history" | grep -o '"working":{[^}]*"source":"[^"]*"' | sed 's/.*"source":"\([^"]*\)".*/\1/')
    _working_version=$(echo "$_history" | grep -o '"working":{[^}]*"version":"[^"]*"' | sed 's/.*"version":"\([^"]*\)".*/\1/')
    [ -n "$_working_source" ] && [ -n "$_working_version" ] || die "No working keybox available (all revoked?)"
    _DL_SOURCE="$_working_source"
    _DL_VER="$_working_version"
    log "KEYBOX" "Auto-selected: $_working_source $_working_version"
  else
    _DL_SOURCE="$_provider"
    _DL_VER=$(echo "$_history" | grep -o '"source":"'"$_provider"'"[^}]*"version":"[^"]*"' | sed 's/.*"version":"\([^"]*\)".*/\1/' | sort -rn | head -1)
    [ -n "$_DL_VER" ] || die "No versions found for provider '$_provider'"
    log "KEYBOX" "Selected provider: $_provider $_DL_VER"
  fi
fi

_DL_URL="${KEYBOX_URL}/${_DL_SOURCE}/${_DL_VER}"
[ "$_DL_SOURCE" = "fallback" ] && _DL_URL="${_FALLBACK_BASE}/${_DL_VER}"

log "KEYBOX" "Downloading keybox..."
download "$_DL_URL" > "$TEMP_FILE" || {
  log "KEYBOX" "Error: Download failed"
  rm -f "$TEMP_FILE" "$DECODE_FILE"
  [ -f "$BACKUP_FILE" ] && cp "$BACKUP_FILE" "$TARGET_FILE"
  exit 1
}

if ! base64 -d "$TEMP_FILE" > "$DECODE_FILE" 2>/dev/null; then
  log "KEYBOX" "Error: Base64 decode failed"
  rm -f "$TEMP_FILE" "$DECODE_FILE"
  [ -f "$BACKUP_FILE" ] && cp "$BACKUP_FILE" "$TARGET_FILE"
  exit 1
fi

[ -s "$DECODE_FILE" ] || {
  log "KEYBOX" "Error: Decoded keybox is empty"
  rm -f "$TEMP_FILE" "$DECODE_FILE"
  [ -f "$BACKUP_FILE" ] && cp "$BACKUP_FILE" "$TARGET_FILE"
  exit 1
}

_has_ecdsa=$(sed -n '/<Key algorithm="ecdsa">/,/<\/Key>/p' "$DECODE_FILE" 2>/dev/null)
_has_rsa=$(sed -n '/<Key algorithm="rsa">/,/<\/Key>/p' "$DECODE_FILE" 2>/dev/null)
_has_id=$(( $(grep -c '<serial>' "$DECODE_FILE" 2>/dev/null || echo 0) + $(grep -c 'DeviceID' "$DECODE_FILE" 2>/dev/null || echo 0) ))

[ -n "$_has_ecdsa" ] || log "KEYBOX" "Warning: Missing ECDSA key block"
[ -n "$_has_rsa" ] || log "KEYBOX" "Warning: Missing RSA key block"
[ -z "$_has_ecdsa" ] && [ -z "$_has_rsa" ] && log "KEYBOX" "Warning: No valid attestation keys found"
[ "$_has_id" -eq 0 ] && log "KEYBOX" "Warning: No identifier field found (serial/DeviceID)"

_author=$(grep 'author=' /data/adb/modules/tricky_store/module.prop 2>/dev/null | head -1 | cut -d= -f2 | tr '[:upper:]' '[:lower:]')

case "$_author" in
  *jingmatrix*)
    log "KEYBOX" "TEE Simulator detected, generating locked.xml format"
    _serial=$(decode_keybox_serial "$DECODE_FILE" 2>/dev/null || echo "unknown")
    _random=$(hexdump -n 4 -e '4/4 "%08X"' /dev/urandom 2>/dev/null || echo "$$")
    _ecdsa_block=$(sed -n '/<Key algorithm="ecdsa">/,/<\/Key>/p' "$DECODE_FILE" 2>/dev/null)
    _rsa_block=$(sed -n '/<Key algorithm="rsa">/,/<\/Key>/p' "$DECODE_FILE" 2>/dev/null)
    {
      echo '<?xml version="1.0" encoding="UTF-8"?>'
      echo '<AndroidAttestation>'
      echo '<NumberOfKeyboxes>1</NumberOfKeyboxes>'
      echo "<Keybox DeviceID=\"$_serial\">"
      [ -n "$_ecdsa_block" ] && printf '%s\n' "$_ecdsa_block"
      echo "  <serial>${_serial}_${_random}</serial>"
      [ -n "$_rsa_block" ] && printf '%s\n' "$_rsa_block"
      echo '</Keybox>'
      echo '</AndroidAttestation>'
    } > "$TRICKY_DIR/locked.xml"
    rm -f "$TEMP_FILE" "$DECODE_FILE"
    printf '%s' "" > "$CONFIG_DIR/kb_private.val" 2>/dev/null || true
    log "KEYBOX" "Locked XML written to $TRICKY_DIR/locked.xml"
    log "KEYBOX" "Finish"
    exit 0
    ;;
esac

mv "$DECODE_FILE" "$TARGET_FILE" || die "Failed to move decoded keybox to $TARGET_FILE"
rm -f "$TEMP_FILE"
printf '%s' "" > "$CONFIG_DIR/kb_private.val" 2>/dev/null || true
log "KEYBOX" "Keybox installed successfully"
log "KEYBOX" "Finish"
exit 0
