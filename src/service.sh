#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/lib/common.sh"
. "$MODDIR/lib/package_list.sh"

log "SERVICE" "Setting boot properties"

# ============================================================================
# EARLY BOOT PROPS (immediate, no wait)
# ============================================================================

# --- Bootloader / VBMeta state ---
# Hide unlocked bootloader from apps and integrity checks
resetprop_if_diff ro.boot.vbmeta.device_state locked
resetprop_if_diff vendor.boot.vbmeta.device_state locked
resetprop_if_diff ro.boot.verifiedbootstate green
resetprop_if_diff vendor.boot.verifiedbootstate green
resetprop_if_diff ro.boot.flash.locked 1
resetprop_if_diff ro.boot.veritymode enforcing
resetprop_if_diff ro.boot.veritymode.managed yes

# --- Warranty & debug bits ---
# Prevent apps detecting debug or engineering builds
# Samsung warranty bit spoofing — required for Samsung device integrity
resetprop_if_diff ro.boot.warranty_bit 0
resetprop_if_diff ro.warranty_bit 0
resetprop_if_diff ro.vendor.boot.warranty_bit 0
resetprop_if_diff ro.vendor.warranty_bit 0
resetprop_if_diff ro.debuggable 0
resetprop_if_diff ro.force.debuggable 0
resetprop_if_diff ro.secure 1
resetprop_if_diff ro.adb.secure 1

# --- Build identity ---
# Mask userdebug/eng builds as user release builds
resetprop_if_diff ro.build.type user
resetprop_if_diff ro.build.tags release-keys
# Loop over all ro.*.build.type and ro.*.build.tags variants
while IFS= read -r _prop; do
  [ -z "$_prop" ] && continue
  case "$_prop" in
    *.build.type) resetprop_if_diff "$_prop" user ;;
    *.build.tags) resetprop_if_diff "$_prop" release-keys ;;
  esac
done <<PROPS
$(resetprop 2>/dev/null | grep -oE 'ro\.[^.]+\.build\.(type|tags)')
PROPS
unset _prop

# --- Static vbmeta metadata ---
# Always set to known-good values as fallback
resetprop_if_diff ro.boot.vbmeta.size 4096
resetprop_if_diff ro.boot.vbmeta.hash_alg sha256
resetprop_if_diff ro.boot.vbmeta.avb_version 2.0

# --- OEM-specific props ---
# MIUI secureboot — Xiaomi devices check this for boot state
resetprop_if_diff ro.secureboot.lockstate locked
# avoid breaking Realme fingerprint scanners
resetprop_if_diff ro.boot.realme.lockstate 1
resetprop_if_diff ro.boot.realmebootstate green
# avoid breaking OnePlus display modes
resetprop_if_diff ro.is_ever_orange 0
# Oppo/ColorOS fingerprint compatibility
resetprop_if_diff ro.boot.vbmeta.device_state locked

# --- Recovery mode hiding ---
# Prevent apps from detecting device booted into recovery
resetprop_if_match ro.bootmode recovery unknown
resetprop_if_match ro.boot.bootmode recovery unknown
resetprop_if_match vendor.boot.bootmode recovery unknown
resetprop_if_match ro.boot.mode recovery unknown

# --- USB / ADB lockdown ---
# Disable debugging, OEM unlock, and restrict USB modes
resetprop_if_diff sys.oem_unlock_allowed 0
resetprop_if_diff ro.oem_unlock_supported 0
resetprop_if_diff persist.sys.usb.config none
resetprop_if_diff sys.usb.config mtp
resetprop_if_diff service.adb.root 0

# --- Emulation detection ---
# Specter's unique anti-emulation props
resetprop_if_diff ro.kernel.qemu 0
resetprop_if_diff ro.boot.qemu 0
# --- SELinux ---
resetprop_if_diff ro.boot.selinux enforcing
# If SELinux is enforcing, set the build indicator
[ "$(getprop ro.boot.selinux)" = "enforcing" ] && resetprop_if_diff ro.build.selinux 1

# --- Crypto ---
# Hide unencrypted state from apps checking ro.crypto.state
resetprop_if_diff ro.crypto.state encrypted

# ============================================================================
# AFTER BOOT COMPLETED
# ============================================================================

# KernelSU / APatch: boot-completed.sh handles hardening
[ "$KSU" = "true" ] && {
  log "SERVICE" "KernelSU/APatch detected — boot-completed.sh handles hardening"
  exit 0
}

# Magisk: poll sys.boot_completed, then apply hardening
log "SERVICE" "Magisk detected — waiting for boot completion"
while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 1
done
log "SERVICE" "Boot completed — applying hardening"

# Apply boot hardening (settings + prop deletes)
apply_boot_hardening

# DroidGuard killer — force-stop GMS and related services to break attestation
for _pkg in $GMS_KILL_LIST; do
  am force-stop "$_pkg" 2>/dev/null || true
done
unset _pkg

# Hide TWRP / OrangeFox / FOX recovery folders from /sdcard
hide_recovery_folders

# Delayed spoofing — 120s delay to re-apply props that system may have overridden
(
  sleep 120
  log "SERVICE" "Delayed spoofing — reapplying critical props"
  resetprop_if_diff ro.crypto.state encrypted
  resetprop_if_diff ro.build.tags release-keys
  hide_recovery_folders
) &

log "SERVICE" "Done"
