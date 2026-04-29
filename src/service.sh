MODDIR=${0%/*}
. "$MODDIR/lib/common.sh"

check_prop "ro.boot.vbmeta.device_state" "locked"
check_prop "ro.boot.verifiedbootstate" "green"
check_prop "ro.boot.flash.locked" "1"
check_prop "ro.boot.veritymode" "enforcing"
check_prop "ro.boot.warranty_bit" "0"
check_prop "ro.warranty_bit" "0"
check_prop "ro.debuggable" "0"
check_prop "ro.force.debuggable" "0"
check_prop "ro.secure" "1"
check_prop "ro.adb.secure" "1"
check_prop "ro.build.type" "user"
check_prop "ro.build.tags" "release-keys"
check_prop "vendor.boot.vbmeta.device_state" "locked"
check_prop "vendor.boot.verifiedbootstate" "green"
check_prop "sys.oem_unlock_allowed" "0"
check_prop "ro.oem_unlock_supported" "0"
check_prop "ro.boot.realme.lockstate" "1"
check_prop "ro.secureboot.lockstate" "locked"
contains_check_prop "ro.boot.bootmode" "recovery" "unknown"
contains_check_prop "vendor.boot.bootmode" "recovery" "unknown"
check_prop "persist.sys.usb.config" "none"
check_prop "service.adb.root" "0"
check_prop "ro.crypto.state" "encrypted"

if [ "$KSU" != "true" ]; then
    log "SERVICE" "Magisk detected — polling sys.boot_completed"
    resetprop -w sys.boot_completed 0
    settings put global development_settings_enabled 0
    settings put global adb_enabled 0
    settings put global oem_unlock_allowed 0
    resetprop --delete persist.service.adb.enable
    resetprop --delete persist.service.debuggable
    resetprop persist.sys.developer_options 0
fi
