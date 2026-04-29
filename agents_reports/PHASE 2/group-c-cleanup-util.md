# Group C — Cleanup & Util Report

**Streams:** 2i (cleanup.sh), 2l (widevine.sh), 2m (lsposed.sh), 2n (migrate.sh)

**Status:** ✅ Complete

---

## Files Created

### `src/features/cleanup.sh` — Clear Detection Traces
- Polls `sys.boot_completed` before `settings put` commands (waits for fully booted system)
- Sources `src/lib/package_list.sh` for `DETECTOR_APPS`, `TOOL_APPS`, `REMOTE_CONTROL_APPS`
- Removes detector app data/OBB/media dirs from `/storage/emulated/0/Android/`
- Removes tool app data dirs (MT Manager, Shizuku, HyperCeiler, etc.)
- Removes remote control app data dirs (AnyDesk, TeamViewer, RustDesk, etc.)
- Uses `check_prop()` from `common.sh` for property resets (no inline resetprop)
- No `rm -rf /data/local/tmp/*` — only deletes specific known YuriKey-related temp paths
- No `su -c`
- ODEX cleanup via `find /data/app -type f -name base.odex -delete 2>/dev/null`

### `src/features/widevine.sh` — Fix Widevine L1 DRM
- Copies `FixWidevineL1/` contents using `$MODDIR/../webroot/common/FixWidevineL1/` (absolute, not relative `./`)
- Sets permissions (755) and ownership (root:root)
- Runs `/vendor/bin/KmInstallKeybox` with the attestation file
- Cleans up temp files at `/data/local/tmp/`
- No `su -c`

### `src/features/lsposed.sh` — Delete LSPosed ODEX Traces
- Counts all `base.odex` files under `/data/app` before deletion
- Deletes them via `find -delete`
- Logs the number of files deleted

### `src/features/migrate.sh` — One-Time Old-Structure Cleanup
- Checks `$MIGRATION_MARKER` (`/data/adb/Yurikey/.migrated`) and exits early if present
- Removes old `Module/Yuri/` directory if it exists
- Removes old duplicate files from previous versions:
  - `webroot/common/clear_all_detection_traces.sh`
  - `webroot/common/widevinel1.sh`
  - `webroot/common/lsposed2.sh`
  - `webroot/common/boot_hash.sh`
- Writes completion marker: `touch /data/adb/Yurikey/.migrated`

---

## Checklist Verification

- [x] All 4 files source `"$MODDIR/../lib/common.sh"` and `"$MODDIR/../lib/paths.sh"` (feature script path convention)
- [x] `cleanup.sh` sources `"$MODDIR/../lib/package_list.sh"` for app lists
- [x] `cleanup.sh` polls `sys.boot_completed` before `settings put` commands
- [x] No `rm -rf /data/local/tmp/*` — only specific known paths
- [x] No `su -c` in any file
- [x] No `return` at top level — all use `exit 0`/`exit 1`
- [x] All output via `log()`
- [x] No hardcoded `/data/adb/modules/Yurikey` paths
- [x] `migrate.sh` uses `$MIGRATION_MARKER` from `paths.sh`
- [x] `widevine.sh` uses `$MODDIR/../webroot/common/FixWidevineL1/` (absolute), not relative `./`
