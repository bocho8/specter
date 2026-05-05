#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
. "$MODDIR/../lib/paths.sh"
. "$MODDIR/../lib/package_list.sh"

log "CLEANUP" "Start"

log "CLEANUP" "Waiting for boot completion..."
while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 1
done

_rm() { [ -n "$1" ] && rm -rf "$1" 2>/dev/null; }

log "CLEANUP" "Hiding recovery folders..."
hide_recovery_folders

log "CLEANUP" "Removing detector app data directories..."
for _pkg in $DETECTOR_APPS; do
  _rm "/storage/emulated/0/Android/data/$_pkg"
  _rm "/storage/emulated/0/Android/obb/$_pkg"
  _rm "/storage/emulated/0/Android/media/$_pkg"
done

log "CLEANUP" "Removing detector log files..."
_rm "/storage/emulated/0/meow_detector.log"
_rm "/storage/emulated/0/keybox_status.json"

log "CLEANUP" "Removing tool app data directories..."
for _pkg in $TOOL_APPS; do
  _rm "/storage/emulated/0/Android/data/$_pkg"
done
_rm "/storage/emulated/0/MT2"
_rm "/storage/emulated/0/bin.mt.termux"
_rm "/storage/emulated/0/com.termux"
_rm "/storage/emulated/0/xzr.hkf"
_rm "/storage/emulated/0/Download/WechatXposed"
_rm "/storage/emulated/0/WechatXposed"
_rm "/storage/emulated/0/Android/naki"
_rm "/storage/emulated/0/最新版隐藏配置.json"
_rm "/storage/emulated/0/rlgg"
_rm "/storage/emulated/legacy"
_rm "/storage/emulated/com.luckyzyx.luckytool"

log "CLEANUP" "Removing remote control app data directories..."
for _pkg in $REMOTE_CONTROL_APPS; do
  _rm "/storage/emulated/0/Android/data/$_pkg"
done
_rm "/storage/emulated/0/.anydesk"
_rm "/storage/emulated/0/anydesk"
_rm "/storage/emulated/0/.rustdesk"
_rm "/storage/emulated/0/rustdesk"
_rm "/storage/emulated/0/.vysor"
_rm "/storage/emulated/0/Vysor"

log "CLEANUP" "Checking for suspicious properties..."
_suspicious=0
for _prop in persist.hyperceiler.log.level persist.sys.vold_app_data_isolation_enabled persist.zygote.app_data_isolation persist.com.luckyzyx.luckytool.log.level persist.com.luckyzyx.luckytool.debug persist.com.luckyzyx.luckytool.enable; do
  getprop "$_prop" >/dev/null 2>&1 && { _suspicious=1; break; }
done
if [ "$_suspicious" = "1" ]; then
  log "CLEANUP" "Suspicious props detected, backing up and cleaning..."
  [ -f "/data/property/persistent_properties" ] && cp -a "/data/property/persistent_properties" "/data/property/persistent_properties.bak" 2>/dev/null
  for _prop in persist.hyperceiler.log.level persist.sys.vold_app_data_isolation_enabled persist.zygote.app_data_isolation persist.com.luckyzyx.luckytool.log.level persist.com.luckyzyx.luckytool.debug persist.com.luckyzyx.luckytool.enable; do
    sed -i "/$_prop/d" "/data/property/persistent_properties" 2>/dev/null || true
  done
  log "CLEANUP" "Suspicious props cleaned"
else
  log "CLEANUP" "No suspicious props found"
fi
unset _suspicious

log "CLEANUP" "Cleaning temp files..."
_rm "/data/local/tmp/shizuku"
_rm "/data/local/tmp/shizuku_starter"
_rm "/data/local/tmp/byyang"
_rm "/data/local/tmp/HyperCeiler"
_rm "/data/local/tmp/luckys"
_rm "/data/local/tmp/input_devices"
_rm "/data/local/tmp/resetprop"

log "CLEANUP" "Cleaning system data..."
_rm "/data/system/graphicsstats"
_rm "/data/system/package_cache"
_rm "/data/system/NoActive"
_rm "/data/system/Freezer"
_rm "/data/system/junge"
_rm "/data/swap_config.conf"

_rm "/dev/memcg/scene_idle"
_rm "/dev/memcg/scene_active"
_rm "/dev/scene"
_rm "/dev/cpuset/scene-daemon"

pm clear com.juom >/dev/null 2>&1 || true

log "CLEANUP" "Applying prop hardening..."
apply_prop_hardening

log "CLEANUP" "Resetting USB and ADB properties..."
check_prop "sys.usb.adb.disabled" "1"
check_prop "persist.sys.usb.config" "mtp"
check_prop "sys.usb.config" "mtp"
check_prop "sys.usb.state" "mtp"
check_prop "service.adb.root" "0"
check_prop "vendor.boot.verifiedbootstate" "green"
check_prop "vendor.boot.vbmeta.device_state" "locked"
check_prop "ro.secureboot.lockstate" "locked"
check_prop "ro.boot.realme.lockstate" "1"
check_prop "ro.oem_unlock_supported" "0"
check_prop "sys.oem_unlock_allowed" "0"
check_prop "ro.kernel.qemu" "0"
check_prop "ro.boot.qemu" "0"
check_prop "ro.hardware.virtual_device" "0"

log "CLEANUP" "Removing persistent service props..."
resetprop -p --delete persist.service.adb.enable 2>/dev/null || true
resetprop -p --delete persist.service.debuggable 2>/dev/null || true
resetprop -p --delete persist.zygote.app_data_isolation 2>/dev/null || true
resetprop -p --delete persist.hyperceiler.log.level 2>/dev/null || true
resetprop -p --delete persist.sys.vold_app_data_isolation_enabled 2>/dev/null || true
resetprop -p --delete persist.com.luckyzyx.luckytool.log.level 2>/dev/null || true
resetprop -p --delete persist.com.luckyzyx.luckytool.debug 2>/dev/null || true
resetprop -p --delete persist.com.luckyzyx.luckytool.enable 2>/dev/null || true
resetprop -p --delete persist.sys.developer_options 2>/dev/null || true
resetprop -p --delete persist.sys.dev_mode 2>/dev/null || true

resetprop -n persist.sys.dev_mode 0
resetprop -n persist.sys.debuggable 0

log "CLEANUP" "Applying boot hardening..."
apply_boot_hardening

if [ "$(getenforce 2>/dev/null)" = "Enforcing" ]; then
  log "CLEANUP" "SELinux is Enforcing, locking boot properties..."
  resetprop ro.boot.selinux enforcing
  resetprop ro.build.selinux 1
fi

unset _rm _pkg
log "CLEANUP" "Finish"
exit 0
