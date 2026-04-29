#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
. "$MODDIR/../lib/paths.sh"

log "WIDEVINE" "Start"

FWV_DIR="$MODDIR/../webroot/common/FixWidevineL1"

if [ ! -d "$FWV_DIR" ]; then
  log "WIDEVINE" "Error: FixWidevineL1 directory not found at $FWV_DIR"
  exit 1
fi

cp -r "$FWV_DIR"/* /data/local/tmp/ 2>/dev/null || {
  log "WIDEVINE" "Error: Failed to copy FixWidevineL1 files"
  exit 1
}

chmod 755 /data/local/tmp/FixWidevineL1.sh 2>/dev/null
chmod 755 /data/local/tmp/attestation 2>/dev/null
chown root:root /data/local/tmp/FixWidevineL1.sh 2>/dev/null
chown root:root /data/local/tmp/attestation 2>/dev/null

if [ -f /vendor/bin/KmInstallKeybox ]; then
  /vendor/bin/KmInstallKeybox /data/local/tmp/attestation 2>/dev/null || \
    log "WIDEVINE" "Warning: KmInstallKeybox exited non-zero"
else
  log "WIDEVINE" "Warning: /vendor/bin/KmInstallKeybox not found"
fi

rm -f /data/local/tmp/FixWidevineL1.sh /data/local/tmp/attestation 2>/dev/null

log "WIDEVINE" "Finish"
