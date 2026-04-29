# YuriKey — Full Rewrite Plan

## Overview

| Aspect | Value |
|---|---|
| **Total agents** | **12** (11 AI + you for WebUI) |
| **Max parallel** | **8 agents** (Phase 2) |
| **Phases** | 3 |
| **Files created** | ~35 |
| **Files deleted** | 15+ |
| **Total lines of new code** | ~1,700 |

## Execution Model

Multiple AI agents work in parallel. Each agent owns specific files with **no conflicts**. The streams are ordered by dependency — Phase 1 must finish before Phase 2 starts.

---

## Phase 1: Foundation (parallel, 4 agents)

### Stream 1 — Shell Libraries (`lib/`)
**Files owned exclusively:**
- `src/lib/paths.sh` — all path **constants** (no hardcoded `YURIKEY_BASE`; all paths derived from `MODDIR` at runtime)
- `src/lib/urls.sh` — all remote URLs (`KEYBOX_URL`, `HMA_CONFIG_URL`, etc.)
- `src/lib/common.sh` — `log()`, `download()`, `die()`, `check_prop()`, `contains_check_prop()`, `ensure_dir()`
- `src/lib/config_env.sh` — `cfg_get()`, `cfg_set()`: dual-layer config persistence (tries `ksud module config` first, falls back to flat files at `$YURIKEY_CONFIG_DIR/*.val`)
- `src/lib/package_list.sh` — `FIXED_TARGETS`, `DETECTOR_APPS`, `GMS_APPS`, `REMOTE_CONTROL_APPS`

**Contract:** Every other shell script will source these files. Never call `exit` or `return` at top level — only define functions.

**Deliverable:** 5 files, ~180 lines total.

**CRITICAL RULES for paths.sh:**
- NO `YURIKEY_BASE="/data/adb/modules/Yurikey"` — this is the old hardcoded path
- All paths use `$MODDIR` (set by each caller via `${0%/*}`)
- Define `YURIKEY_CONFIG_DIR="/data/adb/Yurikey/config"` for the config_env.sh fallback files

---

### Stream 6 — Build System
**Files owned exclusively:**
- `package.json` — dependencies: `@material/web`, `lit`. optionalDependencies: `kernelsu`. DevDep: `parcel`
- `.gitignore` — add `key`, `attestation`, `Module/webroot/`
- `.github/workflows/build-test.yml` — add `shellcheck` + `npm run build`
- `.github/workflows/build-release.yml` — add `npm run build` step before zipping

**Build script:**
```json
{
  "scripts": {
    "build": "npm run build:web && npm run build:module",
    "build:web": "parcel build src/webroot/index.html --dist-dir Module/webroot --public-url ./",
    "build:module": "mkdir -p Module && cp -r src/META-INF src/module.prop src/lib src/features src/pipelines src/rka Module/ && cp src/*.sh Module/ && cp -r src/webroot/lang Module/webroot/ && cp -r src/webroot/json Module/webroot/ && cp -r src/webroot/common Module/webroot/",
    "dev": "parcel src/webroot/index.html --dist-dir Module/webroot --public-url ./"
  }
}
```

**Deliverable:** 4 files.

---

### Stream 7 — WebUI (YOU — full control)
**Files owned exclusively:**
- `src/webroot/config.json` — KernelSU WebUI config
- `src/webroot/index.html` — Single HTML with MWC components + history dialog + script output pre
- `src/webroot/css/style.css` — Theme variables + layout (~100 lines)
- `src/webroot/js/app.js` — ES module entry (~100 lines): path discovery, script execution + history, config persistence, i18n, URL buttons
- `src/webroot/js/i18n.js` — Translation helper (~40 lines, async, no busy-wait loop)
- `src/webroot/json/dev.json` — Contributor list
- `src/webroot/lang/` — Keep existing Crowdin structure (28 files)

**Interface to maintain:**
1. Buttons use `data-script="keybox.sh"` attribute
2. URL buttons use `data-url="https://..."` attribute
3. Device info reads `/json/device-info.json`
4. Script execution uses **runtime bridge detection** (Tier 1: `kernelsu` npm → Tier 2: `window.ksu` → Tier 3: `YuriKeyHost` → Tier 4: `execYurikeyScript`). Do NOT top-level import from `kernelsu` — use `getBridge()` function.
5. Settings use `CFG.get/CFG.set` (dual-layer: `ksud module config` + flat-file fallback)
6. Script output saved to `$MODDIR/script_history.log`, viewable via history button
7. Module path discovered from `module_paths.json` (written by customize.sh)
8. Inline `<script>` in `<head>` handles MWC load guard (before app.js module loads)

**Deliverable:** Your redesigned WebUI with path discovery, script history, and working i18n.

**Can start:** Immediately.

---

### Stream 8 — Housekeeping
**Files to delete:**
- `config.json` at repo root (512KB HMA-OSS config — download it, don't bundle it)
- `src/webroot/common/assets/` (10 files, 228K, unreferenced) → **delete**
- `src/webroot/common/boot_hash.sh` (duplicate of `features/boot_hash.sh`) → **delete**

**.gitignore entries to add:**
- `key` — private key, never commit
- `attestation` — private key, never commit  
- `Module/` — build output, not source
- `node_modules/` — npm dependencies
- `.parcel-cache/` — Parcel cache

**Git tracking cleanup:**
- Run `git rm --cached key attestation` to stop tracking these files (they remain on disk for local use)
- **Do NOT `git rm --cached config.json`** — it must stay tracked as the download source for `hma.sh`

**The `update-binary` is kept for recovery compatibility** — `updater-script` contains `#MAGISK` (Magisk/KSU use their own handler), but the legacy binary stays for custom recovery installers.

**Deliverable:** File deletions + gitignore entries + untrack secrets from git.

---

## Phase 2: Shell Scripts (parallel, up to 8 agent groups)

### All agents run after Stream 1 finishes.

**IMPORTANT PATH RULES:**

Each script type navigates to `lib/` differently depending on its location:

| Script location | `$MODDIR` resolves to | Path to `lib/common.sh` |
|---|---|---|
| `features/keybox.sh` | `.../Yurikey/features` | `"$MODDIR/../lib/common.sh"` |
| `orchestrator.sh` (root) | `.../Yurikey` | `"$MODDIR/lib/common.sh"` |
| `service.sh` (root) | `.../Yurikey` | `"$MODDIR/lib/common.sh"` |
| `action.sh` (root) | `.../Yurikey` | `"$MODDIR/lib/common.sh"` |
| `customize.sh` | **N/A — sourced; use `$MODPATH`** | `"$MODPATH/lib/common.sh"` |
| `uninstall.sh` (root) | `.../Yurikey` | `"$MODDIR/lib/common.sh"` |

**Feature script contract:**
```sh
#!/system/bin/sh
MODDIR=${0%/*}               # = .../Yurikey/features
. "$MODDIR/../lib/common.sh" # go up one level
. "$MODDIR/../lib/paths.sh"

log "TAG" "Start"
# ... logic ...
log "TAG" "Finish"
```

**Root-level script contract (orchestrator.sh, service.sh, boot-completed.sh, action.sh):**
```sh
#!/system/bin/sh
MODDIR=${0%/*}               # = .../Yurikey/
. "$MODDIR/lib/common.sh"    # lib/ is directly under root
. "$MODDIR/lib/paths.sh"
```

**Installer contract (customize.sh):**
```sh
# customize.sh is SOURCED — $0 is the installer, not this file
# Use $MODPATH instead (provided by the installer environment)
. "$MODPATH/lib/common.sh"
. "$MODPATH/lib/urls.sh"
```

- Exits `0` on success, `1` on failure
- Idempotent — safe to run multiple times
- Check prerequisites; if missing, `exit 0` (skip gracefully)

**Agent consolidation:** Features are grouped into 5 agent groups (not 14 individual agents). Each group handles 2-3 related feature files, reducing overhead while maintaining parallelism.

---

### Group A — Core Integrity Features (`features/`)
**Agent handles: keybox.sh, target.sh, security_patch.sh, boot_hash.sh, pif.sh**

- `keybox.sh`: Download, base64 decode, write keybox to Tricky Store. Backup existing keybox first.
- `target.sh`: Generate `target.txt` with fixed + dynamic packages. No subshell pipe — use `< file` redirection.
- `security_patch.sh`: Compute target month, write `security_patch.txt`. Fix comment/logic mismatch (use 5th, not 10th).
- `boot_hash.sh`: Read `ro.boot.vbmeta.digest`, write to `/data/adb/boot_hash`. No `su -c` needed.
- `pif.sh`: Detect PIF variant (INJECT or Fork), run autopif. If neither installed, `exit 0`.

### Group B — Hiding & Config Features (`features/`)
**Agent handles: hma.sh, znctl.sh, gms.sh, kill_all.sh, rka.sh**

- `hma.sh`: Download HMA config, write with `chmod 600` and dynamic UID.
- `znctl.sh`: Check Zygisk Next version using `$REQUIRED` (not undefined `$VERSION`). Use `awk` for version comparison (BusyBox `sort -V` not available). `mkdir -p` on dirname, not on file path. Fix `log_messgae` typo.
- `gms.sh`: Force-stop + clear Play Store. Check package existence.
- `kill_all.sh`: Kill all detector apps. Check `pm list packages | grep -q "$pkg"` before acting.
- `rka.sh`: Provision PassIt RKA config. Keep existing logic.

### Group C — Cleanup & Utility Features (`features/`)
**Agent handles: cleanup.sh, widevine.sh, lsposed.sh, migrate.sh**

- `cleanup.sh`: Detection traces cleanup. **Poll `sys.boot_completed`** before running `settings put` (needs fully booted system). No `rm -rf /data/local/tmp/*` — only delete specific YuriKey-related temp paths. Check package existence before `pm clear`. Source `package_list.sh` for app lists instead of hardcoding inline.
- `widevine.sh`: Copy FixWidevineL1 files, set permissions, run. Use `$MODDIR` for paths, not relative `./`.
- `lsposed.sh`: Find and delete all `base.odex` from `/data/app`.
- `migrate.sh`: One-time migration script for users upgrading from the old module structure. Deletes old `Module/Yuri/` directory, converts old state files if any, writes a completion marker to `/data/adb/Yurikey/.migrated`. Source `paths.sh` for `$MIGRATION_MARKER`.

### Group D — Orchestrator + Pipelines
**Agent handles: orchestrator.sh, pipelines/full_integrity, pipelines/root_hide**

Pipeline-driven script runner. See full contract in AGENT_PROMPTS.md Stream 3.

### Group E — Boot + Installer + Action
**Agent handles: customize.sh, service.sh, boot-completed.sh, uninstall.sh, action.sh**

All installer/boot scripts with platform detection. See full contract in AGENT_PROMPTS.md Stream 4.

### Group F — RKA Subsystem
**Agent handles: jsonarray.sh, lspmcfg.sh (path update only)**

Keep existing code, update lspmcfg.sh path, remove bundled sqlite3 binaries.

---

### Stream 5 — RKA Subsystem (Updated)
**Files:** `src/rka/` — Keep `jsonarray.sh` and `lspmcfg.sh` as-is. **Remove pre-bundled sqlite3 binaries.**

In `customize.sh` (Stream 4), add sqlite3 download for the current architecture at install time. Use the installer-provided `$ARCH` with an ABI mapping (RKA binaries use ABI naming, not Magisk short names):
```sh
# Map Magisk ARCH → Android ABI for RKA sqlite3 paths
case "$ARCH" in
  arm64) RKA_ARCH="arm64-v8a" ;;
  arm)   RKA_ARCH="armeabi-v7a" ;;
  x64)   RKA_ARCH="x86_64" ;;
  x86)   RKA_ARCH="x86" ;;
  *)     RKA_ARCH="arm64-v8a" ;;
esac
SQLITE_URL="https://raw.githubusercontent.com/Yurii0307/yurikey/main/rka/${RKA_ARCH}/sqlite3"
mkdir -p "$MODPATH/rka/$RKA_ARCH"
download "$SQLITE_URL" > "$MODPATH/rka/$RKA_ARCH/sqlite3" 2>/dev/null && chmod 755 "$MODPATH/rka/$RKA_ARCH/sqlite3"
```

Also update `src/rka/lspmcfg.sh` line 42:
- Old: `LSP_SQLITE="/data/adb/modules/Yurikey/Yuri/rka/${_lsp_abi}/sqlite3"`
- New: `LSP_SQLITE="/data/adb/modules/Yurikey/rka/${_lsp_abi}/sqlite3"`

---

### Stream 3 — Orchestrator + Pipelines
**Files:**
- `src/orchestrator.sh` — reads pipeline file, runs features with error checking
- `src/pipelines/full_integrity` — `gms.sh target.sh security_patch.sh boot_hash.sh keybox.sh pif.sh?`
- `src/pipelines/root_hide` — `hma.sh znctl.sh?`

### Stream 4 — Boot + Installer + Action
**Files:**
- `src/customize.sh` — installer. **Uses `$MODPATH`** (not `${0%/*}`), uses `return`. Downloads keybox, **writes `module_paths.json`** for WebUI path discovery, downloads arch-specific sqlite3 for RKA, **runs `migrate.sh`** for one-time old-structure cleanup
- `src/service.sh` — late_start service. `check_prop()` for all boot props. **On Magisk (`$KSU != true`): polls `sys.boot_completed` for post-boot actions** (settings put, prop deletion). On KernelSU: just sets ro.* props
- `src/boot-completed.sh` — KernelSU only: runs at `ACTION_BOOT_COMPLETED`. Must have `[ "$KSU" != "true" ] && exit 0` guard at top. Uses `cfg_set()` for override.description (KernelSU + Magisk compat via config_env.sh fallback)
- `src/uninstall.sh` — restore backup keybox if present (uses `MODDIR=${0%/*}`)
- `src/action.sh` — thin wrapper with **context detection**: `"${0##*/}" = "action.sh" && exit $RC || return $RC`

### Stream 5 — RKA Subsystem
**Files:** `src/rka/` — keep everything as-is. Only change: in `customize.sh` (Stream 4), add (uses `$RKA_ARCH` mapped from installer's `$ARCH`):
```sh
set_perm "$MODPATH/rka/$RKA_ARCH/sqlite3" 0 0 0755
```

---

## Phase 3: Integration

### Stream 9 — Final Assembly
**After all Phase 2 streams complete:**
1. Run `npm run build` to generate `Module/` directory
2. Verify structure: `Module/` has `module.prop`, `META-INF/com/google/android/updater-script`, `lib/`, `features/`, `orchestrator.sh`, `pipelines/`, `rka/`, `webroot/`, `customize.sh`, `service.sh`, `boot-completed.sh`, `uninstall.sh`, `action.sh`
3. Grep for hardcoded `/data/adb/modules/Yurikey` — should be zero hits (must use `$MODDIR` or `$MODPATH`)
4. Grep for `return` at top level in feature scripts — should be zero hits outside `customize.sh` / `action.sh` / `uninstall.sh`
5. Grep for `su -c` — should be zero hits in feature scripts
6. Verify feature scripts use `../lib/` not `lib/` for sourcing
7. Verify `customize.sh` uses `$MODPATH` not `$MODDIR` or `${0%/*}`
8. Verify cross-agent contract consistency: `grep -c 'log(' Module/lib/common.sh` should match expected function count; verify `cfg_get`/`cfg_set`/`cfg_delete` all exist in `config_env.sh`; verify `check_prop` and `contains_check_prop` both exist in `common.sh`
9. Verify MWC load guard exists in `<head>` inline script (not just in app.js)
10. Verify `app.js` has `CFG` with in-memory cache + localStorage migration
11. Verify `i18n.js` handles `en` → `source/string.json` fallback
12. Verify `addHistory()` uses `printf '%s\n'` not `echo` for shell-safe output
13. Delete old `Module/Yuri/` directory if everything was migrated
14. Delete old `Module/webroot/` that may have stale Beer CSS version (replaced by new bundled version)
15. Commit

---

## Dependency Graph Summary

```
Phase 1 (parallel):
  Stream 1 (lib/)  ──── critical path ────┐
  Stream 6 (build) ──── independent ──────┤
  Stream 7 (WebUI) ──── independent ──────┤  ← YOU
  Stream 8 (clean) ──── independent ──────┘

Phase 2 (parallel, after Stream 1):
  Group A (5 core features) ──────────────┐
  Group B (5 hide/config features) ───────┤
  Group C (4 cleanup/utility features) ───┤  ← depends on lib/
  Group D (orchestrator + pipelines) ─────┤  ← depends on lib/
  Group E (boot + installer) ─────────────┤  ← depends on lib/
  Group F (rka subsystem) ────────────────┘  ← depends on lib/

Phase 3 (after all Phase 2):
  Stream 9 (final assembly + verify + rollback-safe git clean)
```

---

## Agent Handoff Checklist

When an agent completes a stream, it must confirm:

- [ ] All files created in the correct paths under `src/`
- [ ] Shell scripts use `#!/system/bin/sh` for device scripts
- [ ] **Feature scripts** (`features/`) use `"$MODDIR/../lib/common.sh"` (relative, up one level)
- [ ] **Root-level scripts** (`orchestrator.sh`, `service.sh`, `boot-completed.sh`, `action.sh`) use `"$MODDIR/lib/common.sh"` (direct, same level)
- [ ] **`customize.sh`** uses `"$MODPATH/lib/common.sh"` (not `${0%/*}`, not `MODDIR`)
- [ ] Feature scripts `exit 0` / `exit 1` (not `return`)
- [ ] Installer scripts (`customize.sh`, `uninstall.sh`) use `return`
- [ ] **`action.sh`** uses **context detection**: `"${0##*/}" = "action.sh" && exit || return`
- [ ] All paths derived from `MODDIR=${0%/*}` or `$MODPATH` (never hardcoded)
- [ ] No hardcoded `/data/adb/modules/Yurikey` (shell libs use `$MODDIR`; WebUI uses `module_paths.json`)
- [ ] No `su -c` (scripts run as root already)
- [ ] No `return` inside `while ... | while` subshell pipes (use `< file` not `| pipe`)
- [ ] `log()` output is captured, not `echo` directly
- [ ] **`config_env.sh`** has `cfg_get()`, `cfg_set()`, AND `cfg_delete()` with ksud + flat-file fallback
- [ ] **`device-info.sh`** sources `"$MODDIR/../../lib/common.sh"` (not standalone)
- [ ] **`service.sh`** has conditional Magisk‑only `sys.boot_completed` polling
- [ ] **`boot-completed.sh`** has `[ "$KSU" != "true" ] && exit 0` guard at top
- [ ] **`customize.sh`** writes `module_paths.json` to `$MODPATH/webroot/json/`
- [ ] **`znctl.sh`** version comparison uses `awk` not `sort -V` (BusyBox compatibility)
- [ ] **No sqlite3 binaries bundled** — downloaded at install time for current arch only, using `$SQLITE_BASE_URL` from `urls.sh`
- [ ] **`config.json` stays in git** — it's the download source for HMA config, NOT git-rm'd
- [ ] **`customize.sh` runs `migrate.sh`** during install for one-time old-structure cleanup
- [ ] **`customize.sh` uses installer `$ARCH` with ABI mapping** for sqlite3 download (not `getprop`)
- [ ] **`build:module` copies `src/webroot/lang/`** in addition to `json/` and `common/`
- [ ] **`cleanup.sh` polls `sys.boot_completed`** before `settings put` commands
- [ ] **`app.js` includes MWC load guard** in `<head>` inline script (not just inside module)
- [ ] **`app.js` has in-memory CFG cache** + localStorage migration
- [ ] **`i18n.js` handles `en` → `source/string.json`** fallback and preserves HTML in translations
- [ ] **`addHistory()` uses `printf '%s\n'`** not `echo` for shell-safe output
- [ ] **`features/rka.sh` sources `../lib/urls.sh`** for `RKA_TOKEN` (not hardcoded)
- [ ] **`urls.sh` defines `RKA_TOKEN`** (single source of truth for the shared secret)
