#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
. "$MODDIR/../lib/config_env.sh"
[ "$(cfg_get toggle_widevine 1)" = "0" ] && exit 0
. "$MODDIR/../lib/paths.sh"
. "$MODDIR/../lib/urls.sh"
WDIR="/data/local/tmp"
_attestation_file="$WDIR/attestation.$$"
trap 'rm -f "$_attestation_file" 2>/dev/null' EXIT

log "WIDEVINE" "Start"

check_network || { log "WIDEVINE" "Error: No internet connection"; exit 1; }

log "WIDEVINE" "Downloading attestation key..."
download "$ATTESTATION_URL" > "$_attestation_file" 2>/dev/null || {
  log "WIDEVINE" "Error: Failed to download attestation key"
  exit 1
}
log "WIDEVINE" "Attestation key downloaded successfully"

chmod 755 "$_attestation_file" 2>/dev/null || log "WIDEVINE" "Warning: Failed to set permissions on attestation"
chown root:root "$_attestation_file" 2>/dev/null || log "WIDEVINE" "Warning: Failed to set owner on attestation"

_abi=$(getprop ro.product.cpu.abi 2>/dev/null) || log "WIDEVINE" "Warning: Failed to read CPU ABI"
case "$_abi" in
  arm64|x86_64) _lib="/vendor/lib64/hw" ;;
  *)            _lib="/vendor/lib/hw" ;;
esac

log "WIDEVINE" "Searching for KmInstallKeybox vendor binary..."
KM_BIN=$(find_kmInstallKeybox)

if [ -n "$KM_BIN" ]; then
  log "WIDEVINE" "Found KmInstallKeybox at $KM_BIN"
  log "WIDEVINE" "Running KmInstallKeybox with attestation key..."
  LD_LIBRARY_PATH="$_lib" "$KM_BIN" "$_attestation_file" attestation true 2>/dev/null || {
    log "WIDEVINE" "Error: KmInstallKeybox exited with non-zero status"
    exit 1
  }
  log "WIDEVINE" "KmInstallKeybox completed successfully"
else
  log "WIDEVINE" "Error: KmInstallKeybox not found (non-Qualcomm device?)"
  exit 1
fi
unset KM_BIN
unset _abi _lib

log "WIDEVINE" "Finish"
exit 0
