MODDIR=${0%/*}
. "$MODDIR/lib/common.sh"

sh "$MODDIR/orchestrator.sh" full_integrity
RC=$?

[ "${0##*/}" = "action.sh" ] && exit $RC || return $RC
