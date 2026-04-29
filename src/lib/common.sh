log() { echo "$(date +%Y-%m-%d\ %H:%M:%S) [$1] $2"; }

die() { log "ERROR" "$1"; exit 1; }

download() {
    _dl_url="$1" _dl_oldpath="$PATH"
    PATH="/data/adb/magisk:/data/data/com.termux/files/usr/bin:$PATH"
    if command -v curl >/dev/null 2>&1; then
        curl --connect-timeout 10 -Ls "$_dl_url"
    else
        busybox wget -T 10 --no-check-certificate -qO- "$_dl_url"
    fi
    PATH="$_dl_oldpath"
    unset _dl_url _dl_oldpath
}

check_prop() {
    _cp_name=$1 _cp_expected=$2 _cp_value
    _cp_value=$(resetprop "$_cp_name")
    [ -z "$_cp_value" ] || [ "$_cp_value" = "$_cp_expected" ] || resetprop -n "$_cp_name" "$_cp_expected"
    unset _cp_name _cp_expected _cp_value
}

contains_check_prop() {
    _ccp_name=$1 _ccp_contains=$2 _ccp_newval=$3
    case "$(resetprop "$_ccp_name")" in
        *"$_ccp_contains"*) resetprop -n "$_ccp_name" "$_ccp_newval"; unset _ccp_name _ccp_contains _ccp_newval; return 0 ;;
    esac
    unset _ccp_name _ccp_contains _ccp_newval
    return 1
}

ensure_dir() { mkdir -p "$1" 2>/dev/null; }
