ROOT_SOL=""

log() { echo "[$1] $2"; }

die() { log "ERROR" "$1"; exit 1; }

download() {
    _dl_url="$1" _dl_output="$2" _dl_sha256="$3" _dl_oldpath="$PATH"
    PATH="/data/adb/magisk:/data/data/com.termux/files/usr/bin:$PATH"
    _dl_tmp="" _dl_code=1 _dl_try=0

    if [ -z "$_dl_output" ]; then
        _dl_tmp=$(mktemp 2>/dev/null || echo "/data/local/tmp/.specter_dl_${$}_$(date +%s)")
        _dl_output="$_dl_tmp"
    fi

    for _dl_try in 1 2 3; do
        if command -v curl >/dev/null 2>&1; then
            curl --connect-timeout 10 -Ls -o "$_dl_output" "$_dl_url" 2>/dev/null && _dl_code=0 && break
        elif command -v wget >/dev/null 2>&1; then
            wget -T 10 -qO "$_dl_output" "$_dl_url" 2>/dev/null && _dl_code=0 && break
        else
            break
        fi
        sleep 1
    done

    if [ "$_dl_code" -eq 0 ] && [ -n "$_dl_sha256" ]; then
        _dl_sum=$(sha256sum "$_dl_output" 2>/dev/null | cut -d' ' -f1)
        if [ "$_dl_sum" != "$_dl_sha256" ]; then
            rm -f "$_dl_output"
            PATH="$_dl_oldpath"
            unset _dl_url _dl_output _dl_sha256 _dl_oldpath _dl_tmp _dl_code _dl_try _dl_sum
            return 1
        fi
    fi

    if [ -n "$_dl_tmp" ] && [ "$_dl_code" -eq 0 ]; then
        cat "$_dl_tmp"
        rm -f "$_dl_tmp"
    fi

    PATH="$_dl_oldpath"
    unset _dl_url _dl_output _dl_sha256 _dl_oldpath _dl_tmp _dl_code _dl_try _dl_sum
    return $_dl_code
}

check_network() {
    _cn_oldpath="$PATH"
    PATH="/data/adb/magisk:/data/data/com.termux/files/usr/bin:$PATH"
    _cn_dns="" _cn_endpoint="https://clients3.google.com/generate_204" _cn_retry=0

    for _cn_dns in "1.1.1.1" "8.8.8.8" "9.9.9.9"; do
        ping -c1 -W2 "$_cn_dns" >/dev/null 2>&1 && PATH="$_cn_oldpath" && unset _cn_oldpath _cn_dns _cn_endpoint _cn_retry && return 0
    done

    for _cn_retry in 1 2 3; do
        if command -v curl >/dev/null 2>&1; then
            curl --connect-timeout 5 -sI "$_cn_endpoint" >/dev/null 2>&1 && PATH="$_cn_oldpath" && unset _cn_oldpath _cn_dns _cn_endpoint _cn_retry && return 0
        fi
        if command -v wget >/dev/null 2>&1; then
            wget -T 5 --spider "$_cn_endpoint" >/dev/null 2>&1 && PATH="$_cn_oldpath" && unset _cn_oldpath _cn_dns _cn_endpoint _cn_retry && return 0
        fi
        sleep "$_cn_retry"
    done

    PATH="$_cn_oldpath"
    unset _cn_oldpath _cn_dns _cn_endpoint _cn_retry
    return 1
}

check_prop() {
    _cp_name=$1 _cp_expected=$2
    _cp_value=$(resetprop "$_cp_name")
    [ -z "$_cp_value" ] || [ "$_cp_value" = "$_cp_expected" ] || resetprop -n "$_cp_name" "$_cp_expected"
    unset _cp_name _cp_expected _cp_value
}

detect_root_solution() {

    if [ -f "/data/adb/ksud" ]; then
        ROOT_SOL="kernelsu"
    elif [ -f "/data/adb/apd" ]; then
        ROOT_SOL="apatch"
    elif [ -f "/data/adb/magisk" ]; then
        ROOT_SOL="magisk"
    else
        ROOT_SOL="legacy"
    fi

    if command -v resetprop >/dev/null 2>&1; then
        :
    else
        ROOT_SOL="legacy"
    fi

    log "ROOT" "Detected root solution: $ROOT_SOL"
}

resetprop_if_diff() {
    _rid_name="$1" _rid_expected="$2"
    _rid_current=$(resetprop "$_rid_name" 2>/dev/null || echo "")

    if [ -z "$_rid_current" ] || [ "$_rid_current" != "$_rid_expected" ]; then
        case "$ROOT_SOL" in
            legacy) setprop "$_rid_name" "$_rid_expected" 2>/dev/null || true ;;
            *) resetprop -n "$_rid_name" "$_rid_expected" 2>/dev/null || true ;;
        esac
    fi

    unset _rid_name _rid_expected _rid_current
}

resetprop_if_match() {
    _rim_name="$1" _rim_contains="$2" _rim_value="$3"
    _rim_current=$(resetprop "$_rim_name" 2>/dev/null || echo "")

    case "$_rim_current" in
        *"$_rim_contains"*)
            case "$ROOT_SOL" in
                legacy) setprop "$_rim_name" "$_rim_value" 2>/dev/null || true ;;
                *) resetprop -n "$_rim_name" "$_rim_value" 2>/dev/null || true ;;
            esac
            unset _rim_name _rim_contains _rim_value _rim_current
            return 0
            ;;
    esac

    unset _rim_name _rim_contains _rim_value _rim_current
    return 1
}

PERSIST_RESTORE_FILE="/data/adb/Specter/persist_backup.txt"

persistprop() {
    _pp_name="$1" _pp_value="$2"
    _pp_restore=""

    case "$ROOT_SOL" in
        legacy) setprop "$_pp_name" "$_pp_value" 2>/dev/null || true ;;
        *) resetprop -n -p "$_pp_name" "$_pp_value" 2>/dev/null || true ;;
    esac

    _pp_restore=$(resetprop "$_pp_name" 2>/dev/null || echo "")
    if [ -n "$_pp_restore" ]; then
        ensure_dir "/data/adb/Specter"
        if ! grep -q "^resetprop -n -p \"$_pp_name\"" "$PERSIST_RESTORE_FILE" 2>/dev/null; then
            echo "resetprop -n -p \"$_pp_name\" \"$_pp_restore\"" >> "$PERSIST_RESTORE_FILE" 2>/dev/null || true
        fi
    fi

    unset _pp_name _pp_value _pp_restore
}

hide_recovery_folders() {
    [ -f "/data/adb/Specter/twrp" ] && return 0

    _hrf_backup="/data/adb/recovery_backups"
    _hrf_random="" _hrf_subdirs=0 _hrf_path=""

    for _hrf_folder in TWRP OrangeFox FOX PBRP PitchBlack Recovery; do
        _hrf_path="/sdcard/$_hrf_folder"
        [ ! -d "$_hrf_path" ] && continue

        if [ -f "$_hrf_path/.twrps" ]; then
            rm -f "$_hrf_path/.twrps" 2>/dev/null || {
                _hrf_random=$(head /dev/urandom 2>/dev/null | tr -dc A-Za-z0-9 | head -c 12)
                [ -z "$_hrf_random" ] && _hrf_random="recovery_${$}"
                mv "$_hrf_path" "/sdcard/$_hrf_random" 2>/dev/null
                continue
            }
        fi

        _hrf_path_recurse="$_hrf_path"
        _hrf_subdirs=$(find "$_hrf_path_recurse" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)

        if [ "$_hrf_subdirs" -gt 0 ]; then
            mkdir -p "$_hrf_backup" 2>/dev/null
            mv "$_hrf_path" "$_hrf_backup/" 2>/dev/null
        else
            rm -rf "$_hrf_path" 2>/dev/null
        fi
    done

    unset _hrf_backup _hrf_random _hrf_subdirs _hrf_path _hrf_path_recurse _hrf_folder
}

apply_prop_hardening() {
    check_prop "ro.build.fingerprint" ""
    check_prop "ro.boot.vbmeta.device_state" "locked"
    check_prop "ro.boot.verifiedbootstate" "green"
    check_prop "ro.boot.flash.locked" "1"
    check_prop "ro.boot.veritymode" "enforcing"
    check_prop "ro.boot.warranty_bit" "0"
    check_prop "ro.warranty_bit" "0"
    check_prop "ro.debuggable" "0"
    check_prop "ro.secure" "1"
    check_prop "ro.adb.secure" "1"
    check_prop "ro.build.type" "user"
    check_prop "ro.build.tags" "release-keys"
    check_prop "ro.system.build.tags" "release-keys"
    check_prop "ro.vendor.build.tags" "release-keys"
    resetprop_if_diff "ro.boot.warranty_bit" "0"
    resetprop_if_diff "ro.vendor.boot.warranty_bit" "0"
    resetprop_if_diff "ro.vendor.warranty_bit" "0"
    resetprop_if_diff "ro.warranty_bit" "0"
    resetprop_if_diff "ro.is_ever_orange" "0"

    while IFS= read -r _aph_prop; do
        [ -z "$_aph_prop" ] && continue
        resetprop_if_diff "$_aph_prop" "user"
    done <<PROPS
$(resetprop 2>/dev/null | grep -oE 'ro.*\.build\.type' | grep -v 'ro.build.type')
PROPS

    while IFS= read -r _aph_prop; do
        [ -z "$_aph_prop" ] && continue
        resetprop_if_diff "$_aph_prop" "release-keys"
    done <<PROPS
$(resetprop 2>/dev/null | grep -oE 'ro.*\.build\.tags' | grep -v 'ro.build.tags')
PROPS
}

apply_boot_hardening() {
  settings put global development_settings_enabled 0
  settings put global adb_enabled 0
  settings put global oem_unlock_allowed 0
  settings put global adb_wifi_enabled 0
  settings put global adb_wifi_port -1
  resetprop --delete persist.service.adb.enable 2>/dev/null || true
  resetprop --delete persist.service.debuggable 2>/dev/null || true
  resetprop -n persist.sys.developer_options 0
}

ensure_dir() { mkdir -p "$1" 2>/dev/null; }

_escape_json() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

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

read_vbmeta() {
  _rv_slot=$(getprop ro.boot.slot_suffix 2>/dev/null || echo "")
  _rv_dev="/dev/block/by-name/vbmeta${_rv_slot}"
  [ -b "$_rv_dev" ] || return 1
  _rv_size=$(blockdev --getsize64 "$_rv_dev" 2>/dev/null) || return 1
  _rv_digest=$(sha256sum "$_rv_dev" 2>/dev/null | awk '{print $1}') || return 1
  echo "$_rv_size $_rv_digest"
  unset _rv_slot _rv_dev _rv_size _rv_digest
}

run_device_info() {
  for _rdi_root in "$@"; do
    [ -n "$_rdi_root" ] || continue
    [ -f "$_rdi_root/webroot/common/device-info.sh" ] && sh "$_rdi_root/webroot/common/device-info.sh" && return 0
  done
  for _rdi_p in \
    "/data/adb/modules_update/Specter/webroot/common/device-info.sh" \
    "/data/adb/modules/Specter/webroot/common/device-info.sh"; do
    [ -f "$_rdi_p" ] && sh "$_rdi_p" && return 0
  done
  return 1
}

_parse_serial() {
  _h="$1"
  case "$_h" in 30*) _h="${_h#30}" ;; *) return 1 ;; esac
  _l_hex="${_h:0:2}" _l_dec=$((16#$_l_hex))
  [ $_l_dec -ge 128 ] && _h="${_h:2 + ($_l_dec - 128) * 2}" || _h="${_h:2}"

  case "$_h" in 30*) _h="${_h#30}" ;; *) return 1 ;; esac
  _l_hex="${_h:0:2}" _l_dec=$((16#$_l_hex))
  [ $_l_dec -ge 128 ] && _h="${_h:2 + ($_l_dec - 128) * 2}" || _h="${_h:2}"

  case "$_h" in
    a0*)
      _ctx_len_hex="${_h:2:2}"
      _ctx_len=$((16#$_ctx_len_hex))
      _h="${_h:4 + _ctx_len * 2}"
      ;;
  esac

  case "$_h" in 02*) _h="${_h#02}" ;; *) return 1 ;; esac
  _l_hex="${_h:0:2}" _l_dec=$((16#$_l_hex))
  if [ $_l_dec -ge 128 ]; then
    _n=$((_l_dec - 128))
    _sl=$((16#${_h:2:_n * 2}))
    _serial_hex="${_h:2 + _n * 2:$_sl * 2}"
  else
    _serial_hex="${_h:2:$_l_dec * 2}"
  fi

  _serial=$(echo "$_serial_hex" | sed 's/^0*//')
  [ -z "$_serial" ] && _serial="0"
  return 0
}

decode_keybox_serial() {
  _b64=$(sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' "$1" | head -20 | grep -v 'CERTIFICATE' | tr -d '\n')
  [ -z "$_b64" ] && return 1
  _hex=$(echo "$_b64" | base64 -d 2>/dev/null | od -v -tx1 | awk 'BEGIN{ORS=""} {for(i=2;i<=NF;i++) printf "%s", $i}')
  [ -z "$_hex" ] && return 1
  _parse_serial "$_hex" || return 1
  echo "$_serial"
}

find_kmInstallKeybox() {
  _fk_abi=$(getprop ro.product.cpu.abi 2>/dev/null || echo "arm64")
  _fk_lib_dir="/vendor/lib64"
  [ "$_fk_abi" != "arm64" ] && [ "$_fk_abi" != "x86_64" ] && _fk_lib_dir="/vendor/lib"
  _fk_bin=""
  for _fk_dir in "$_fk_lib_dir/hw" "$_fk_lib_dir"; do
    _fk_bin=$(find "$_fk_dir" -name "*kmInstallKeybox*" 2>/dev/null | head -1)
    [ -n "$_fk_bin" ] && break
  done
  echo "${_fk_bin:-}"
  unset _fk_abi _fk_lib_dir _fk_bin _fk_dir
}

resolve_module_root() {
  MODDIR="${0%/*}"
  if echo "$MODDIR" | grep -q "webroot/common"; then
    MODULE_ROOT="${MODDIR%/webroot/common}"
  else
    MODULE_ROOT="$MODDIR"
  fi
  echo "$MODULE_ROOT"
}
