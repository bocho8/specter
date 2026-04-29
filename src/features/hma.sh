#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
. "$MODDIR/../lib/paths.sh"
. "$MODDIR/../lib/urls.sh"

log "HMA" "Start"

if pm list packages | grep -q org.frknkrc44.hma_oss; then
  ensure_dir "$HMA_DIR"
  download "$HMA_CONFIG_URL" > "$HMA_FILE" || {
    log "HMA" "Error: HMA-oss config download failed"
    exit 1
  }
  chmod 600 "$HMA_FILE"
  HMA_UID=$(stat -c "%u" "$HMA_DIR" 2>/dev/null) || HMA_UID=0
  chown "$HMA_UID:$HMA_UID" "$HMA_FILE"
elif pm list packages | grep -q com.tsng.hidemyapplist; then
  log "HMA" "Warning: Legacy HMA detected, use latest HMA-oss for config support"
else
  log "HMA" "Warning: HMA-oss not installed, skipping"
fi

log "HMA" "Finish"
