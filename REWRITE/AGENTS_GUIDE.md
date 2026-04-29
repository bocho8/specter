# AI Agents — Quick Guide

## How It Works

12 agents total (11 AI + you). Each agent gets **one prompt** from `AGENT_PROMPTS.md`, creates specific files, and reports done.

---

## Phase 1 — Foundation (run immediately, all 4 in parallel)

| Stream | Agent | Files | Depends on | Time |
|---|---|---|---|---|
| **1** | AI | `src/lib/` (**5 files**: paths.sh, urls.sh, common.sh, config_env.sh, package_list.sh) | Nothing | ~10 min |
| **6** | AI | `package.json`, `.gitignore`, CI files | Nothing | ~10 min |
| **7** | **YOU** | `src/webroot/` (HTML + JS + CSS + i18n.js + fallback.css) | Nothing | Your pace |
| **8** | AI | Delete old files (assets/, boot_hash.sh duplicate), update `.gitignore`, `git rm --cached` secrets | Nothing | ~10 min |

**CRITICAL for Stream 1:** `paths.sh` must NOT contain `YURIKEY_BASE="/data/adb/modules/Yurikey"`. That was the old hardcoded path. All paths derive from `$MODDIR` at runtime. The WebUI discovers its own path via `module_paths.json`.

**CRITICAL for Stream 1:** `urls.sh` must define `RKA_TOKEN` — the hardcoded `RKA_TOKEN` in the old `yurirka.sh` moves here. Feature scripts source `urls.sh` to get it. This is the single source of truth for the shared secret.

**CRITICAL for Stream 8:** Do NOT delete `config.json` from repo root — it's the download source for `hma.sh`. Do NOT add it to `.gitignore`.

**Give the prompt from `AGENT_PROMPTS.md` to each AI agent.** They can all start at the same time.

---

## Phase 2 — Shell Scripts (start after Stream 1 finishes)

| Group | Agent | Files | Depends on | Time |
|---|---|---|---|---|
| **A** | AI | `features/keybox.sh`, `target.sh`, `security_patch.sh`, `boot_hash.sh`, `pif.sh` | Stream 1 | ~10 min |
| **B** | AI | `features/hma.sh`, `znctl.sh`, `gms.sh`, `kill_all.sh`, `rka.sh` | Stream 1 | ~10 min |
| **C** | AI | `features/cleanup.sh`, `widevine.sh`, `lsposed.sh`, `migrate.sh` | Stream 1 | ~10 min |
| **D** | AI | `orchestrator.sh` + `pipelines/` | Stream 1 | ~5 min |
| **E** | AI | `customize.sh`, `service.sh`, `boot-completed.sh`, `uninstall.sh`, `action.sh` | Stream 1 | ~10 min |
| **F** | AI | Move `src/rka/` (no sqlite3 binaries), update `lspmcfg.sh` path | Stream 1 | ~5 min |

**All 6 can run in parallel** — they only read `src/lib/`, never write to it.

---

## Phase 3 — Assembly (after Phase 2)

| Stream | Agent | Task | Depends on | Time |
|---|---|---|---|---|
| **9** | AI | Run `npm run build`, verify structure, run grep checks, backup-and-delete old dirs, `git rm --cached` secrets (NOT config.json), commit | All above | ~15 min |

---

## Critical Rules The Agents Must Follow

| Rule | Applies to |
|---|---|
| Feature scripts → use `"$MODDIR/../lib/common.sh"` | Groups A, B, C |
| Root-level scripts → use `"$MODDIR/lib/common.sh"` | Groups D, E (service, boot-completed, action) |
| `customize.sh` → use `"$MODPATH/lib/common.sh"` (not `$MODDIR`) | Group E |
| `device-info.sh` → use `"$MODDIR/../../lib/common.sh"` | Stream 7 (YOU) |
| Feature scripts → use `exit 0` / `exit 1` | Groups A, B, C, D |
| Installer scripts (`customize.sh`, `uninstall.sh`) → use `return` | Group E |
| `action.sh` → use **context detection**: `"${0##*/}" = "action.sh" && exit || return` | Group E |
| No hardcoded `/data/adb/modules/Yurikey` anywhere | All streams |
| No `su -c` (scripts already run as root) | All streams |
| No `return` inside `\| while read` subshell pipes | All streams |
| `paths.sh` must NOT have `YURIKEY_BASE` hardcoded | Stream 1 |
| `service.sh` must include Magisk-only `sys.boot_completed` polling | Group E |
| `customize.sh` must write `module_paths.json` for WebUI path discovery | Group E |
| `config_env.sh` must have `cfg_get()`, `cfg_set()`, AND `cfg_delete()` with flat-file fallback | Stream 1 |
| `urls.sh` must define `RKA_TOKEN` (moved from old yurirka.sh) | Stream 1 |
| No sqlite3 binaries in `src/rka/` — downloaded at install time using `$SQLITE_BASE_URL` | Group F |
| `customize.sh` must run `migrate.sh` during install for one-time old-structure cleanup | Group E |
| `cleanup.sh` must poll `sys.boot_completed` before `settings put` commands (needs booted system) | Group C |
| `features/rka.sh` must source `../lib/urls.sh` for `RKA_TOKEN` (not hardcode it) | Group B |
| `features/znctl.sh` version comparison must use `awk`, NOT `sort -V` (BusyBox doesn't support `-V`) | Group B |
| `boot-completed.sh` must have `[ "$KSU" != "true" ] && exit 0` guard at top | Group E |
| `customize.sh` sqlite3 download must use installer `$ARCH` with ABI mapping (not `getprop`), see `AGENT_PROMPTS.md` for the `case` block | Group E |
| `build:module` must copy `src/webroot/lang/`, `src/webroot/json/`, AND `src/webroot/common/` — all three | Stream 6 |
| WebUI `app.js` must use MODULE.MODDIR (from `module_paths.json`) not hardcoded path | Stream 7 (YOU) |
| WebUI `app.js` must include script history log (`script_history.log`) + config migration from localStorage | Stream 7 (YOU) |
| WebUI `app.js` must import specific MWC modules, not `@material/web/all.js` | Stream 7 (YOU) |
| WebUI `app.js` must use **runtime bridge detection** (`getBridge()`: kernelsu→window.ksu→YuriKeyHost→execYurikeyScript), NOT a top-level `import {exec} from 'kernelsu'` | Stream 7 (YOU) |
| WebUI `app.js` must have **in-memory CFG cache** to avoid shell exec() on every config read (load once on init, flush writes async) | Stream 7 (YOU) |
| WebUI `app.js` `addHistory()` must use **`printf '%s\n'` not `echo`** for shell-safe output (echo doesn't handle `\n`, backticks, `$`, etc.) | Stream 7 (YOU) |
| MWC load guard must be in **`<head>` inline `<script>`** (not inside app.js module — if MWC imports fail, the module never loads) | Stream 7 (YOU) |
| WebUI `i18n.js` must handle `data-i18n` (light DOM slot content with **HTML preservation**) AND `data-i18n-label` (MWC label attrs) | Stream 7 (YOU) |
| WebUI `i18n.js` must handle **`en` → `source/string.json`** fallback (no `lang/en.json` exists) | Stream 7 (YOU) |
| `kernelsu` must be in `optionalDependencies` (not `dependencies`) in package.json — app works without it | Stream 6 |
| `config.json` stays tracked in git — it's the download source for HMA config | Stream 8 |
| Phase 3 must backup old dirs before deletion (rollback safety) | Stream 9 |

---

## Workflow

```
1. Give Phase 1 prompts to 3 AI agents + start your WebUI
2. Wait for Stream 1 to finish (libraries done — including config_env.sh with cfg_delete)
3. Give Phase 2 prompts to 6 AI agents (all at once)
4. Wait for all Phase 2 to finish
5. Give Phase 3 prompt to 1 AI agent (assembly + verify + rollback-safe git clean)
6. Verify: grep for hardcoded paths, return-in-features, su -c — should be zero
7. Done — all code in src/, Module/ generated by build
```
