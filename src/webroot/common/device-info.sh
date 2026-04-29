#!/system/bin/sh
MODDIR=${0%/*}/../..
. "$MODDIR/lib/common.sh"

INFO_PATH="$MODDIR/webroot/json/device-info.json"

android_ver=$(getprop ro.build.version.release)
kernel_ver=$(uname -r)

# Root Implementation
if [ -d "/data/adb/magisk" ] && [ -f "/data/adb/magisk.db" ]; then
  root_type="Magisk"
elif [ -f "/data/apatch/apatch" ]; then
  root_type="Apatch"
elif [ -d "/data/adb/ksu" ] && { [ -d "/data/adb/kpm" ] || [ -f "/data/adb/ksu/.dynamic_sign" ]; }; then
  root_type="SukiSU-Ultra"
elif [ -d "/data/adb/ksu" ] && { [ -f "/data/adb/ksud" ] || [ -f "/sys/module/kernelsu/parameters/expected_manager_size" ]; }; then
  root_type="KernelSU-Next"
elif [ -d "/data/adb/ksu" ]; then
  root_type="KernelSU"
else
  root_type="Unknown"
fi

# Output JSON
cat <<EOF > "$INFO_PATH"
{
  "android": "$android_ver",
  "kernel": "$kernel_ver",
  "root": "$root_type"
}
EOF