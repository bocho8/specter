#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"

log "PIF2" "Start"

_deleted=0
_disabled=0

while IFS= read -r _prop; do
  [ -z "$_prop" ] && continue
  if resetprop -p --delete "$_prop" 2>/dev/null; then
    _deleted=$((_deleted + 1))
  fi
done <<PROPS
$(getprop 2>/dev/null | grep -E "pihook|pixelprops" | sed "s/^\[\(.*\)\]:.*/\1/")
PROPS

for _prop in \
  "persist.sys.pihooks.disable.gms_props=true" \
  "persist.sys.pihooks.disable.gms_key_attestation_block=true" \
  "persist.sys.pixelprops.gms=false" \
  "persist.sys.pixelprops.gapps=false" \
  "persist.sys.pixelprops.google=false" \
  "persist.sys.pixelprops.pi=false"; do
  _name="${_prop%%=*}"
  _val="${_prop#*=}"
  resetprop -n -p "$_name" "$_val" 2>/dev/null && _disabled=$((_disabled + 1))
done

if [ -f "/data/system/gms_certified_props.json" ]; then
  resetprop -n persist.sys.spoof.gms false 2>/dev/null
  log "PIF2" "LeafOS gmscompat disabled"
fi

log "PIF2" "Deleted $_deleted props, set $_disabled disable flags"
log "PIF2" "Finish"
exit 0
