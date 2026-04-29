# Stream 2a–2e — Group A: Core Integrity

**Agent:** 5
**Files created:** 5 feature scripts under `src/features/`
**Date:** 2026-04-29

---

## Summary

Created 5 core integrity feature scripts for Phase 2, porting from the legacy `Module/Yuri/` directory with all specified bug fixes.

---

## Files Created

### 1. `src/features/keybox.sh` (Stream 2a)

- Sources `../lib/common.sh` and `../lib/paths.sh`
- Checks Tricky Store is installed (`/data/adb/modules/tricky_store` or `modules_update`)
- Backs up existing `keybox.xml` → `keybox.xml.bak`
- Downloads keybox via shared `download()` from `$KEYBOX_URL`
- Base64-decodes into `keybox.xml`
- On failure: restores backup, exits 1
- Uses `exit` not `return`

### 2. `src/features/target.sh` (Stream 2b)

- Sources libs + `package_list.sh` for `$FIXED_TARGETS`
- Reads `tee_status` for `teeBroken` flag → appends `?` suffix to dynamic entries
- **Fixed subshell pipe bug**: writes `pm list packages` output to a temp file (`/tmp/yurikey_pkgs.txt`), then uses `while read ... < file` instead of `| while read`. This ensures the loop body runs in the main shell, not a subshell.
- Adds user apps (`-3`) and system apps (`-s`)
- Uses `exit` not `return`

### 3. `src/features/security_patch.sh` (Stream 2c)

- Computes security patch date based on current day
- **Fixed day threshold**: uses `< 5` (matches the comment "drop on the 5th") instead of the buggy `< 10`
- Handles January → December of previous year rollover
- Writes Tricky Store format: `system=prop`, `boot=YYYY-MM-DD`, `vendor=YYYY-MM-DD`
- Uses `exit` not `return`

### 4. `src/features/boot_hash.sh` (Stream 2d)

- Reads `ro.boot.vbmeta.digest` via `getprop` (no `su -c` needed)
- Falls back to all-zero hash (64 zeros) if empty
- Writes to `/data/adb/boot_hash`
- Resets the property for consistency
- Uses `exit` not `return`

### 5. `src/features/pif.sh` (Stream 2e)

- Checks Play Integrity Fix installed at `/data/adb/modules/playintegrityfix`
- Reads `module.prop` `name=` field to detect variant:
  - `"Play Integrity Fix [INJECT]"` → runs `autopif_ota.sh` then `autopif.sh`
  - `"Play Integrity Fork"` → runs `autopif4.sh -m`
  - Unknown → logs warning, exits 0
- Skips gracefully if not installed
- Uses `exit` not `return`

---

## Bug Fixes Applied

| Bug | Location | Fix |
|---|---|---|
| Subshell pipe in target generation | `Module/Yuri/target_txt.sh:67` | Replaced `\| while read` with `while read < file` |
| Wrong day threshold (10 vs 5) | `Module/Yuri/security_patch.sh:28` | Changed `< 10` to `< 5` |
| Unnecessary `su -c` in boot_hash | `Module/Yuri/boot_hash.sh:10,20` | Removed `su -c`, use direct `getprop`/`resetprop` |
| Inline function duplication | All old scripts | Replaced with shared `lib/common.sh` functions (`log()`, `download()`, `die()`, `ensure_dir()`) |
| Hardcoded paths | All old scripts | Replaced with `$MODDIR/../lib/` sourcing and `lib/paths.sh` constants |
| `return` in standalone scripts | All old scripts | Changed to `exit` (these are standalone, not sourced) |

---

## Verification

- Shell syntax check: **PASS** (`bash -n` on all 5 files)
- No `su -c` in any feature script: **PASS**
- No top-level `return` in any feature script: **PASS**
- All scripts use `"$MODDIR/../lib/"` for sourcing: **PASS**
