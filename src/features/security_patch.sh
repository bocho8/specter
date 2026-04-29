#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
. "$MODDIR/../lib/paths.sh"

log "SECURITY_PATCH" "Start"

current_year=$(date +%Y) || die "Failed to get year"
current_month=$(date +%m | sed 's/^0*//') || die "Failed to get month"
current_day=$(date +%d | sed 's/^0*//') || die "Failed to get day"

if [ "$current_day" -lt 5 ]; then
  if [ "$current_month" -eq 1 ]; then
    target_month=12
    target_year=$((current_year - 1))
  else
    target_month=$((current_month - 1))
    target_year=$current_year
  fi
else
  target_month=$current_month
  target_year=$current_year
fi

formatted_month=$(printf "%02d" "$target_month")
patch_date="${target_year}-${formatted_month}-05"

log "SECURITY_PATCH" "Writing $patch_date"

cat > "$SECURITY_PATCH_FILE" <<EOF
system=prop
boot=$patch_date
vendor=$patch_date
EOF

log "SECURITY_PATCH" "Finish"
