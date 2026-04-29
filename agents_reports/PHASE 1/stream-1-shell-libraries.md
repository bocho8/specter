# Stream 1 — Shell Libraries Report

**Status:** ✅ Complete  
**Date:** 2026-04-29  
**Agent:** opencode (deepseek-v4-flash)

---

## Files Created

All 5 library files in `src/lib/`:

### `src/lib/paths.sh`
All path constants, no hardcoded `YURIKEY_BASE`:
- Tricky Store paths: `TRICKY_DIR`, `TARGET_FILE`, `BACKUP_FILE`, `TARGET_TXT`, `SECURITY_PATCH_FILE`, `TEE_STATUS`
- System paths: `BOOT_HASH_FILE`, `BBIN`, `HMA_DIR`, `HMA_FILE`, `IDFILE`
- Config persistence: `YURIKEY_CONFIG_DIR`, `MIGRATION_MARKER`

### `src/lib/urls.sh`
Single source of truth for remote URLs and shared secrets:
- `KEYBOX_URL`, `HMA_CONFIG_URL`, `SQLITE_BASE_URL`
- `RKA_HOST`, `RKA_TCP`, `RKA_TOKEN`

### `src/lib/common.sh`
6 shared functions:
- `log(tag, message)` — timestamped logging
- `die(message)` — log error and exit
- `download(url)` — curl with busybox wget fallback, PATH extended with `/data/adb/magisk` and Termux
- `check_prop(name, expected)` — reset property if not matching
- `contains_check_prop(name, substring, newval)` — regex-like property replacement
- `ensure_dir(path)` — idempotent mkdir -p

### `src/lib/config_env.sh`
Dual-layer config persistence (ksud → flat file):
- `cfg_get(key, default)` — read config value
- `cfg_set(key, value)` — write config value
- `cfg_delete(key)` — remove config value

### `src/lib/package_list.sh`
Package lists extracted from existing codebase:
- `FIXED_TARGETS` — 25 entries (from `Module/Yuri/target_txt.sh`)
- `DETECTOR_APPS` — 64 packages (from `Module/Yuri/clear_all_detection_traces.sh`)
- `GMS_APPS` — 8 Google packages (from `Module/Yuri/kill_all.sh`)
- `REMOTE_CONTROL_APPS` — 14 packages (AnyDesk, TeamViewer, RustDesk, etc.)
- `TOOL_APPS` — 8 packages (MT Manager, Shizuku, Termux, etc.)

---

## Verification Results

| Check | Result |
|---|---|
| No `YURIKEY_BASE` references | ✅ |
| No `/data/adb/modules/Yurikey` hardcoded paths | ✅ |
| No `exit`/`return` at top level | ✅ |
| No bashisms (`[[ ]]`) | ✅ |
| POSIX-compatible function syntax | ✅ |
| All required functions present in `common.sh` | ✅ (log, die, download, check_prop, contains_check_prop, ensure_dir) |
| All required functions present in `config_env.sh` | ✅ (cfg_get, cfg_set, cfg_delete) |

---

## Data Sources

- Detector/tool/remote control app lists: `Module/Yuri/clear_all_detection_traces.sh`
- Fixed targets list: `Module/Yuri/target_txt.sh:24-49`
- GMS apps list: `Module/Yuri/kill_all.sh:12`
- RKA token/host/port: `Module/Yuri/yurirka.sh:15-19`
- Boot-time properties: `Module/service.sh`
