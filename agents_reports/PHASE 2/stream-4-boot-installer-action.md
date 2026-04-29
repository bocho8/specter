# Agent 9 (Group E) — Stream 4: Boot + Installer + Action

## Summary

Created the 5 boot/installer/action scripts that handle module installation, boot-time property hiding, boot-completed actions, uninstallation, and the action button entry point.

## Files Created

| File | Purpose |
|------|---------|
| `src/customize.sh` | Installer script — sourced by Magisk/KSU/APatch installer, uses `$MODPATH` and `return` |
| `src/service.sh` | Late_start service — sets boot-time locked/secure properties, Magisk polling fallback |
| `src/boot-completed.sh` | KernelSU-only boot-completed handler — disables dev settings, updates module description |
| `src/uninstall.sh` | Uninstaller — restores keybox backup, removes config/data dirs |
| `src/action.sh` | Action button entry point — runs `full_integrity` pipeline, context-aware exit/return |

## Design Details

### `customize.sh`
- **Sourced context** — uses `$MODPATH` (installer-provided), never `$MODDIR`, terminates with `return` not `exit`
- **Keybox install** — downloads via shared `download()` from `common.sh`, base64-decodes, backs up non-Yuri keyboxes
- **Path discovery** — writes `{"MODDIR": "$MODPATH"}` to `webroot/json/module_paths.json` so the WebUI can find its module root without hardcoded paths
- **Sqlite3 download** — maps short `$ARCH` (`arm64`, `arm`, `x64`, `x86`) to Android ABI directory names (`arm64-v8a`, `armeabi-v7a`, `x86_64`, `x86`) and downloads only the needed binary (~700KB vs ~3MB bundled)
- **Migration** — runs `features/migrate.sh` if present (one-time old-structure cleanup)
- **Device info** — runs `webroot/common/device-info.sh` to bootstrap device info JSON
- **Non-fatal** — all downloads gracefully degrade with `ui_print` warnings

### `service.sh`
- **Root-level** — `MODDIR=${0%/*}` then `"$MODDIR/lib/common.sh"` (not `../lib/`)
- **No duplicate props** — each of the 23 properties set exactly once
- **Contains-check** — uses `contains_check_prop()` for bootmode properties (contains "recovery" → set to "unknown")
- **Magisk polling** — guarded by `[ "$KSU" != "true" ]`, runs `resetprop -w sys.boot_completed 0` and disables dev/ADB settings since Magisk doesn't have `boot-completed.sh` support

### `boot-completed.sh`
- **KSU guard** — `[ "$KSU" != "true" ] && exit 0` as first executable line, making it a no-op on Magisk/APatch
- **Settings** — disables development_settings_enabled, adb_enabled, oem_unlock_allowed
- **Prop cleanup** — deletes `persist.service.adb.enable` and `persist.service.debuggable`, sets `persist.sys.developer_options 0`
- **Description via cfg_set** — uses `config_env.sh`'s `cfg_set()` for `override.description`, which works on all root managers (ksud module config + flat-file fallback)

### `uninstall.sh`
- **Sourced context** — uses `MODDIR` and `return`, same as customize.sh
- **Keybox safekeeping** — if `keybox.xml` contains "yuriiroot", restores the backed-up original
- **Cleanup** — removes `/data/adb/Yurikey/bin/`, `/data/adb/Yurikey/config/`, migration marker, boot hash, RKA ID file

### `action.sh`
- **Sourced-or-subprocess** — uses context detection: `[ "${0##*/}" = "action.sh" ]` determines whether to `exit` (subprocess, KSU) or `return` (sourced, Magisk)
- **Pipeline delegation** — runs `sh "$MODDIR/orchestrator.sh" full_integrity`, captures RC
- **Minimal** — 7 lines, delegates all logic to the orchestrator

## Verification Checklist

| Requirement | Status |
|-------------|--------|
| `customize.sh` uses `$MODPATH` not `$MODDIR` | pass |
| `customize.sh` uses `return` not `exit` | pass |
| `customize.sh` writes `module_paths.json` to `webroot/json/` | pass |
| `customize.sh` downloads arch-specific sqlite3 via `$ARCH` mapping | pass |
| `customize.sh` runs `migrate.sh` during install | pass |
| `service.sh` has no duplicate property entries | pass |
| `service.sh` Magisk polling guarded by `[ "$KSU" != "true" ]` | pass |
| `boot-completed.sh` has `[ "$KSU" != "true" ] && exit 0` guard at top | pass |
| `boot-completed.sh` uses `cfg_set()` for `override.description` | pass |
| `action.sh` context detection: `exit $RC \|\| return $RC` based on `$0` | pass |
| `uninstall.sh` restores keybox backup with "yuriiroot" check | pass |
| `uninstall.sh` removes `BBIN`, `YURIKEY_CONFIG_DIR`, migration marker, boot hash, RKA ID | pass |
