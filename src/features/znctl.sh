#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
. "$MODDIR/../lib/paths.sh"

log "ZNCTL" "Start"

TARGET_FILE="/data/adb/modules/zygisksu/module.prop"
SCRIPT_FILE="/data/adb/modules/zygisksu/bin/zygiskd"
REQUIRED="1.3.0"

if [ ! -f "$TARGET_FILE" ]; then
  log "ZNCTL" "Warning: Zygisk Next not found, skipping"
  exit 0
fi

CURRENT=$(grep "^version=" "$TARGET_FILE" | cut -d'=' -f2 | cut -d' ' -f1)

version_ge() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    split(a,A,"."); split(b,B,".");
    for(i=1;i<=3;i++) {
      if(A[i]+0 > B[i]+0) { exit 0 }
      if(A[i]+0 < B[i]+0) { exit 1 }
    }
    exit 0
  }'
}

version_ge "$CURRENT" "$REQUIRED" || {
  log "ZNCTL" "Error: Zygisk Next version too low, need $REQUIRED"
  exit 0
}

ensure_dir "$(dirname "$SCRIPT_FILE")"

znctl() {
  [ -n "$1" ] && "$SCRIPT_FILE" "$@" 2>/dev/null
}

znctl enforce-denylist just_umount
znctl memory-type anonymous
znctl linker builtin

log "ZNCTL" "Finish"
