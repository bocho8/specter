#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
. "$MODDIR/../lib/paths.sh"
. "$MODDIR/../lib/package_list.sh"

log "TARGET" "Start"

teeBroken="false"
if [ -f "$TEE_STATUS" ]; then
  teeBroken=$(grep -E '^teeBroken=' "$TEE_STATUS" | cut -d '=' -f2 2>/dev/null || echo "false")
fi

rm -f "$TARGET_TXT"

for entry in $FIXED_TARGETS; do
  echo "$entry" >> "$TARGET_TXT"
done

for flag in "-3" "-s"; do
  pkgs=$(pm list packages "$flag" 2>/dev/null) || continue
  [ -z "$pkgs" ] && continue

  echo "$pkgs" | cut -d ":" -f 2 > /tmp/yurikey_pkgs.txt
  while read -r pkg; do
    [ -z "$pkg" ] && continue
    if [ "$teeBroken" = "true" ]; then
      echo "${pkg}?" >> "$TARGET_TXT"
    else
      echo "$pkg" >> "$TARGET_TXT"
    fi
  done < /tmp/yurikey_pkgs.txt
  rm -f /tmp/yurikey_pkgs.txt
done

log "TARGET" "Finish"
