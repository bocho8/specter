#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/lib/common.sh"
. "$MODDIR/lib/paths.sh"

log "POST-FS-DATA" "Early boot property setup"

# ============================================================================
# EARLY ROM-SPECIFIC PROPS
# Applied at post-fs-data stage before any system service reads them
# ============================================================================

# Samsung — warranty bit spoofing
resetprop_if_diff ro.boot.warranty_bit 0
resetprop_if_diff ro.warranty_bit 0
resetprop_if_diff ro.vendor.boot.warranty_bit 0
resetprop_if_diff ro.vendor.warranty_bit 0

# Realme — fingerprint scanner compatibility
resetprop_if_diff ro.boot.realme.lockstate 1
resetprop_if_diff ro.boot.realmebootstate green

# OnePlus — display mode compatibility
resetprop_if_diff ro.is_ever_orange 0

# Oppo / ColorOS — fingerprint compatibility
resetprop_if_diff ro.boot.vbmeta.device_state locked

# ============================================================================
# DISABLE CONFLICTING CROM SPOOF HOOKS
# Some custom ROMs ship with stale built-in Play Integrity spoofing that
# conflicts with Specter. Detect their control signals and override so
# Specter's fresh logic takes over without interference.
# ============================================================================

if resetprop 2>/dev/null | grep -qE \
  "persist\.sys\.pihooks|persist\.sys\.pixelprops|persist\.sys\.entryhooks" \
  || [ -f /data/system/gms_certified_props.json ]; then

  log "POST-FS-DATA" "ROM spoof hooks detected — disabling built-in spoofing"

  # PIHooks: re-enable blocking of GMS prop spoofing and key attestation
  persistprop persist.sys.pihooks.disable.gms_props true
  persistprop persist.sys.pihooks.disable.gms_key_attestation_block true

  # Entryhooks: disable ROM-level hook injection
  persistprop persist.sys.entryhooks_enabled false

  # PixelProps: disable all ROM spoof categories
  for _crom_prop in gms gapps google pi; do
    persistprop "persist.sys.pixelprops.$_crom_prop" false
  done
  unset _crom_prop

  # LeafOS gmscompat: disable dynamic GMS prop spoofing
  [ -f /data/system/gms_certified_props.json ] && persistprop persist.sys.spoof.gms false
fi

# ============================================================================
# VBMETA FROM REAL BLOCK DEVICE
# Read actual vbmeta partition to populate size, digest, and hash algorithm
# ============================================================================

_vbmeta_out=$(read_vbmeta 2>/dev/null || echo "")
if [ -n "$_vbmeta_out" ]; then
  _vbmeta_size="${_vbmeta_out%% *}"
  _vbmeta_digest="${_vbmeta_out#* }"
  [ -n "$_vbmeta_size" ] && resetprop -n ro.boot.vbmeta.size "$_vbmeta_size"
  resetprop -n ro.boot.vbmeta.hash_alg sha256
  if [ ! -f /sdcard/TSupportConfig/boot_hash ] && [ ! -f /data/adb/boot_hash ] && [ -n "$_vbmeta_digest" ]; then
    resetprop -n ro.boot.vbmeta.digest "$_vbmeta_digest"
  fi
  unset _vbmeta_size _vbmeta_digest
else
  log "POST-FS-DATA" "VBMeta block device not found"
fi
unset _vbmeta_out

log "POST-FS-DATA" "Done"
