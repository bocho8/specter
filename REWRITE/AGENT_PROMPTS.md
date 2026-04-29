# YuriKey — AI Agent Prompts

## How To Use

Each prompt is designed for one AI agent. Give one prompt per agent. The agent reads the prompt, produces the file(s), and marks the checklist.

**Phase 1** runs first (4 agents). **Phase 2** runs after Phase 1 (up to 17 agents in parallel). **Phase 3** runs last (1 agent).

---

## PHASE 1 PROMPTS

---

### Agent Prompt: Stream 1 — Shell Libraries

**Role:** Create the shared shell libraries that every other script depends on.

**Files to create:**
- `src/lib/paths.sh`
- `src/lib/urls.sh`
- `src/lib/common.sh`
- `src/lib/config_env.sh` **(NEW — dual-layer config persistence)**
- `src/lib/package_list.sh`

**Rules:**
- Only define functions and variables. Never call `exit` or `return` at top level.
- All functions must be POSIX-compatible (`/system/bin/sh` on Android).
- No hardcoded paths — derive everything from `MODDIR=${0%/*}` at the caller level.
- **CRITICAL: Do NOT define `YURIKEY_BASE`** — that was the old hardcoded module path. All paths use `$MODDIR`.

**Specifications for each file:**

**`src/lib/paths.sh`** — All path constants (NO hardcoded YURIKEY_BASE):
```sh
# Tricky Store
TRICKY_DIR="/data/adb/tricky_store"
TARGET_FILE="$TRICKY_DIR/keybox.xml"
BACKUP_FILE="$TRICKY_DIR/keybox.xml.bak"
TARGET_TXT="$TRICKY_DIR/target.txt"
SECURITY_PATCH_FILE="$TRICKY_DIR/security_patch.txt"
TEE_STATUS="$TRICKY_DIR/tee_status"

# Other system paths (not module-relative)
BOOT_HASH_FILE="/data/adb/boot_hash"
BBIN="/data/adb/Yurikey/bin"
HMA_DIR="/data/user/0/org.frknkrc44.hma_oss/files"
HMA_FILE="$HMA_DIR/config.json"
IDFILE="/data/local/tmp/yurid"

# Config persistence (fallback directory when ksud unavailable)
YURIKEY_CONFIG_DIR="/data/adb/Yurikey/config"
MIGRATION_MARKER="/data/adb/Yurikey/.migrated"
```

**IMPORTANT:** `paths.sh` does NOT have `YURIKEY_BASE="/data/adb/modules/Yurikey"`. Each script determines the module root via `${0%/*}` at runtime. The WebUI discovers its own path from `module_paths.json` (written by `customize.sh`).

**`src/lib/urls.sh`** — All remote URLs AND shared secrets (single source of truth):
```
KEYBOX_URL="https://raw.githubusercontent.com/Yurii0307/yurikey/main/key"
HMA_CONFIG_URL="https://raw.githubusercontent.com/Yurii0307/yurikey/main/config.json"
SQLITE_BASE_URL="https://raw.githubusercontent.com/Yurii0307/yurikey/main/rka"
RKA_HOST="rp.mhmrdd.me"
RKA_TCP=59416
RKA_TOKEN="yurikey-5b70e270d6d69cd399c59ca3d62ccf6e"
```
**CRITICAL:** `RKA_TOKEN` goes HERE, not hardcoded in `features/rka.sh`. Feature scripts source `urls.sh` to get it.

**`src/lib/config_env.sh`** — Dual-layer config persistence:
```sh
# Config persistence: tries ksud module config first, falls back to flat files
# This ensures settings survive on ALL root managers (KSU, Magisk, APatch)

# cfg_get(key, default) — reads a config value
# Returns: the value (or default if not set)
cfg_get() {
    local key="$1" default="$2" val
    val=$(ksud module config get "$key" 2>/dev/null) || \
        val=$(cat "$YURIKEY_CONFIG_DIR/$key.val" 2>/dev/null)
    printf '%s' "${val:-$default}"
}

# cfg_set(key, value) — writes a config value
# Returns: 0 on success
cfg_set() {
    local key="$1" val="$2"
    ksud module config set "$key" "$val" 2>/dev/null || {
        mkdir -p "$YURIKEY_CONFIG_DIR" 2>/dev/null
        printf '%s' "$val" > "$YURIKEY_CONFIG_DIR/$key.val"
    }
}

# cfg_delete(key) — deletes a config value
# Returns: 0 on success (even if key didn't exist)
cfg_delete() {
    local key="$1"
    ksud module config delete "$key" 2>/dev/null || {
        rm -f "$YURIKEY_CONFIG_DIR/$key.val" 2>/dev/null
    }
}
```

**`src/lib/common.sh`** — Shared functions:
```sh
# log(tag, message) — prints timestamped log line
log() { echo "$(date +%Y-%m-%d\ %H:%M:%S) [$1] $2"; }

# die(message) — logs and exits 1
die() { log "ERROR" "$1"; exit 1; }

# download(url) — prints file contents to stdout
# Tries curl first, falls back to busybox wget.
# PATH is temporarily extended with common locations.
download() { ... }

# check_prop(name, expected) — resets property if not matching
check_prop() {
    local NAME=$1 EXPECTED=$2 VALUE
    VALUE=$(resetprop "$NAME")
    [ -z "$VALUE" ] || [ "$VALUE" = "$EXPECTED" ] || resetprop -n "$NAME" "$EXPECTED"
}

# contains_check_prop(name, substring, newval) — if property contains substring, reset it
contains_check_prop() { ... Returns 0 if changed, 1 if not }

# ensure_dir(path) — idempotent mkdir -p
ensure_dir() { mkdir -p "$1" 2>/dev/null; }
```

**`src/lib/package_list.sh`** — All package lists:
```
FIXED_TARGETS — the multiline string of packages for target.txt
DETECTOR_APPS — space-separated list of detector package names
GMS_APPS — Google Mobile Services packages
REMOTE_CONTROL_APPS — AnyDesk, TeamViewer, RustDesk, etc.
TOOL_APPS — MT Manager, Shizuku, Termux, etc.
```

Extract these from the existing codebase at:
- `Module/webroot/common/clear_all_detection_traces.sh` — detector, tool, remote control lists
- `Module/Yuri/target_txt.sh` — fixed targets list
- `Module/Yuri/kill_all.sh` — GMS/detector apps list

**Checklist:**
- [ ] `src/lib/paths.sh` created with all path constants (NO `YURIKEY_BASE` hardcoded)
- [ ] `src/lib/urls.sh` created with remote URLs
- [ ] `src/lib/common.sh` created with `log()`, `die()`, `download()`, `check_prop()`, `contains_check_prop()`, `ensure_dir()`
- [ ] `src/lib/config_env.sh` created with `cfg_get()`, `cfg_set()`, AND `cfg_delete()` (ksud + flat-file fallback)
- [ ] `src/lib/package_list.sh` created with all app lists
- [ ] No `exit` or `return` at top level
- [ ] All functions are POSIX-compatible
- [ ] No reference to `YURIKEY_BASE` or `/data/adb/modules/Yurikey` in any lib file

---

### Agent Prompt: Stream 6 — Build System

**Files to create:**
- `package.json`
- `.gitignore`
- Update `.github/workflows/build-test.yml`
- Update `.github/workflows/build-release.yml`

**Specifications:**

**`package.json`:**
```json
{
  "name": "yurikey-module",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "npm run build:web && npm run build:module",
    "build:web": "parcel build src/webroot/index.html --dist-dir Module/webroot --public-url ./",
    "build:module": "mkdir -p Module && cp -r src/META-INF src/module.prop src/lib src/features src/pipelines src/rka Module/ && cp src/*.sh Module/ && cp -r src/webroot/lang Module/webroot/ && cp -r src/webroot/json Module/webroot/ && cp -r src/webroot/common Module/webroot/",
    "dev": "parcel src/webroot/index.html --dist-dir Module/webroot --public-url ./"
  },
  "devDependencies": {
    "parcel": "^2.12.0"
  },
  "dependencies": {
    "@material/web": "2.4.1",
    "lit": "3.0.0"
  },
  "optionalDependencies": {
    "kernelsu": "3.0.2"
  },
  "targets": {
    "default": {
      "distDir": "./Module/webroot",
      "engines": {
        "browsers": "Chrome >= 100"
      }
    }
  }
}
```

**`.gitignore`:**
```
key
attestation
Module/
node_modules/
.parcel-cache/
```
**IMPORTANT:** Do NOT add `config.json` to `.gitignore`. It must stay tracked — it's the download source for `hma.sh`'s config download. It just shouldn't be bundled in the module ZIP.

**`.github/workflows/build-test.yml`:**
```yaml
name: Build Test Module
on: workflow_dispatch
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - name: Setup Node
        uses: actions/setup-node@v4
        with: { node-version: 22 }
      - name: Lint shell scripts
        run: sudo apt install -y shellcheck && find src/ -name '*.sh' -exec shellcheck {} +
      - name: Build
        run: npm ci && npm run build
      - name: Verify module structure
        run: |
          test -f Module/module.prop
          test -f Module/META-INF/com/google/android/updater-script
          test -f Module/webroot/index.html
          test -f Module/lib/common.sh
          test -f Module/lib/config_env.sh
          test -f Module/webroot/json/module_paths.json
      - name: Check no hardcoded paths
        run: |
          ! grep -rn "/data/adb/modules/Yurikey" Module/lib/ Module/features/ --include="*.sh"
      - name: Check no su -c in features
        run: |
          ! grep -rn "su -c" Module/features/ --include="*.sh"
```

**`.github/workflows/build-release.yml`:**
Copy the existing `build-release.yml` and:
- Add `Setup Node` step before the version extraction
- Add `npm ci && npm run build` step before zipping
- The zip should still package `Module/` content

**Checklist:**
- [ ] `package.json` created with correct dependencies and build scripts
- [ ] `.gitignore` updated with `key`, `attestation`, `Module/`, `node_modules/`, `.parcel-cache/`
- [ ] `build-test.yml` updated with shellcheck + npm build + verify
- [ ] `build-release.yml` updated with npm build step

---

### Agent Prompt: Stream 7 — WebUI (YOU)

**You handle this directly.** See `ARCHITECTURE.md` for the full spec.

**Files to create:**
- `src/webroot/config.json` — KernelSU WebUI config
- `src/webroot/index.html` — MWC components + history dialog + output <pre> + **MWC load guard inline `<script>` in `<head>`** (MUST be outside app.js module since MWC import failure kills the module)
- `src/webroot/css/style.css` — Theme variables + layout (~100 lines)
- `src/webroot/css/fallback.css` — Styles applied when MWC fails to load (shown via load guard)
- `src/webroot/js/app.js` — ES module entry (~200 lines). **Must NOT hardcode `/data/adb/modules/Yurikey/`**
- `src/webroot/js/i18n.js` — Translation helper (~50 lines, async, handles HTML in translations)
- `src/webroot/json/dev.json` — Contributor list
- `src/webroot/json/module_paths.json` — Written by customize.sh, read by app.js at boot
- `src/webroot/lang/` — Keep existing Crowdin structure (`source/string.json` for English)

**CRITICAL REQUIREMENTS for app.js:**

0. **MWC load guard in `<head>` (MUST be inline script, NOT inside app.js module):**
   ```html
   <!-- In index.html <head>, BEFORE the module <script> tag -->
   <script>
     Promise.race([
       customElements.whenDefined('md-filled-button'),
       new Promise(function(r) { setTimeout(r, 5000); }),
     ]).then(function() {
       document.getElementById('mwc-loaded')?.remove();
     }).catch(function() {
       var link = document.createElement('link'); link.rel = 'stylesheet'; link.href = 'css/fallback.css';
       document.head.appendChild(link);
       document.querySelectorAll('[data-script],[data-url]').forEach(function(el) { el.classList.add('fallback-visible'); });
     });
   </script>
   ```
   This MUST be an inline `<script>` in `<head>` because if the ES module (app.js) fails to load due to MWC import failure, the guard inside the module never executes. The inline script runs regardless.

1. **Bridge detection (MUST be cross-platform):** Do NOT import `exec` from `kernelsu` directly. Use a 4-tier fallback that works on all root managers:
   ```js
   async function getBridge() {
     // Tier 1: kernelsu npm package (nice Promise API, KSU/APatch only)
     try { const ksu = await import('kernelsu'); return { exec: ksu.exec, toast: ksu.toast }; } catch {}
     // Tier 2: raw window.ksu bridge (KSU/APatch native)
     if (typeof window.ksu?.exec === 'function') {
       return {
         exec: (cmd) => new Promise((res, rej) => window.ksu.exec(cmd, '{}', (e, o, s) => e ? rej({e,s}) : res({stdout:o, stderr:s}))),
         toast: (msg) => window.ksu.toast?.(msg),
       };
     }
     // Tier 3: MMRL bridge (Magisk via MMRL app)
     if (typeof window.YuriKeyHost?.execScript === 'function') {
       return {
         exec: (cmd) => new Promise((res) => Promise.resolve(window.YuriKeyHost.execScript(cmd, '')).then(o => res({stdout:o})).catch(() => res({stdout:''}))),
         toast: () => {},
       };
     }
     // Tier 4: Legacy MMRL bridge
     if (typeof window.execYurikeyScript === 'function') {
       return {
         exec: (cmd) => new Promise((res) => Promise.resolve(window.execYurikeyScript(cmd, '')).then(o => res({stdout:o})).catch(() => res({stdout:''}))),
         toast: () => {},
       };
     }
     return null;
   }
   const bridge = await getBridge();
   if (!bridge) throw new Error('No script executor available');
   const { exec, toast } = bridge;
   ```

2. **Path discovery (NO hardcoded paths):** Read `module_paths.json` to get `MODULE.MODDIR`:
   ```js
   const MODULE = await (async () => {
     try {
       const r = await fetch('/json/module_paths.json?ts=' + Date.now());
       return await r.json();
     } catch {
       const src = document.currentScript?.src || '';
       const match = src.match(/^(file:\/\/\/data\/adb\/modules\/[^/]+)/);
       return match ? { MODDIR: match[1] } : null;
     }
   })();
   if (!MODULE) throw new Error('Cannot determine module path');
   ```

3. **Script execution with history (SHELL-SAFE via printf):**
   - Save output to `$MODULE.MODDIR/script_history.log` (persistent ring buffer, ~80 entries)
   - Provide a button to view history in a dialog
   - `addHistory()` MUST use `printf '%s\n'` not `echo` for shell-safe output (echo doesn't handle `\n`, backticks, `$`, `\`). Write via temp file:
   ```js
   async function addHistory(script, output) {
     if (!output?.trim()) return;
     const ts = new Date().toISOString();
     const entry = `=== ${ts} [${script}] ===\n${output}`;
     const tmp = `${HISTORY}.tmp`;
     await exec(
       `printf '%s\n' '${entry.replace(/'/g, "'\\''")}' > "${tmp}" && ` +
       `head -240 "${HISTORY}" 2>/dev/null >> "${tmp}" && mv "${tmp}" "${HISTORY}"`
     );
   }
   ```

4. **Config persistence (in-memory cache + ksud + flat-file fallback):**
   ```js
   const CFG = {
     _cache: {},
     async get(key, def) {
       if (key in this._cache) return this._cache[key];
       const {stdout} = await exec(`ksud module config get "${key}" 2>/dev/null || cat "${MODULE.MODDIR}/config/${key}.val" 2>/dev/null`);
       this._cache[key] = stdout.trim() || def;
       return this._cache[key];
     },
     async set(key, val) {
       this._cache[key] = val;
       setTimeout(() => { exec(`ksud module config set "${key}" "${val}" 2>/dev/null || mkdir -p "${MODULE.MODDIR}/config" && printf '%s' "${val}" > "${MODULE.MODDIR}/config/${key}.val"`); }, 0);
     },
     async delete(key) {
       delete this._cache[key];
       exec(`ksud module config delete "${key}" 2>/dev/null || rm -f "${MODULE.MODDIR}/config/${key}.val" 2>/dev/null`);
     }
   };
   ```
   Add localStorage migration on init:
   ```js
   (async () => {
     if (localStorage.getItem('_cfg_migrated')) return;
     for (const [o, n] of Object.entries({ selectedLanguage: 'lang', themeMode: 'theme', clockFormat: 'clock_format' })) {
       const v = localStorage.getItem(o); if (v) await CFG.set(n, v);
     }
     localStorage.setItem('_cfg_migrated', '1');
   })();
   ```

5. **i18n:** Load translations, handle `en` → `source/string.json` fallback, preserve HTML in translations:
   ```js
   export async function loadI18n(lang) {
     const path = lang === 'en' ? '/lang/source/string.json' : `/lang/${lang}.json`;
     try {
       const r = await fetch(`${path}?ts=${Date.now()}`);
       strings = await r.json();
     } catch { strings = {}; }
     document.querySelectorAll('[data-i18n]').forEach(el => {
       const key = el.getAttribute('data-i18n');
       const val = strings[key];
       if (!val) return;
       if (el.children.length > 0 && val.includes('<')) {
         el.innerHTML = val;   // Preserve HTML markup in translations
       } else if (el.children.length > 0) {
         const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
         let node; while ((node = walker.nextNode())) { if (node.nodeValue.trim()) { node.nodeValue = val; break; } }
       } else {
         el.textContent = val;
       }
     });
     // data-i18n-label for MWC components
     document.querySelectorAll('[data-i18n-label]').forEach(el => {
       if (strings[el.getAttribute('data-i18n-label')]) el.setAttribute('label', strings[el.getAttribute('data-i18n-label')]);
     });
     document.documentElement.lang = lang;
   }
   ```

6. **URL buttons:** Use `exec('am start ...')` with injection protection (only `https://`/`http://` schemes, escape single quotes)

---

### Agent Prompt: Stream 8 — Housekeeping

**Files to delete:**
- `src/webroot/common/assets/` — entire directory (10 files, 228K, unreferenced)
- `src/webroot/common/boot_hash.sh` — duplicate of `features/boot_hash.sh`

**DO NOT delete `config.json` at repo root** — it's the download source for `hma.sh`'s HMA config. It must stay tracked in git.

**.gitignore entries to add:**
- `key`
- `attestation`
- `Module/`
- `node_modules/`
- `.parcel-cache/`

**DO NOT add `config.json` to .gitignore** — it must remain tracked.

**Git tracking cleanup:**
Run these commands to stop tracking files that should never have been committed:
```sh
git rm --cached key attestation 2>/dev/null || true
```
**Do NOT `git rm --cached config.json`** — it needs to stay tracked as the download source.

**Checklist:**
- [ ] `src/webroot/common/assets/` deleted (recursively)
- [ ] `src/webroot/common/boot_hash.sh` deleted
- [ ] `.gitignore` has all required entries (DO NOT include config.json)
- [ ] `git rm --cached` run for key, attestation (NOT config.json)

---

## PHASE 2 PROMPTS

Run these **after** Stream 1 completes. All can run in parallel.

---

### Agent Prompt: Stream 2a — `src/features/keybox.sh`

**File to create:** `src/features/keybox.sh`

**Purpose:** Download the Yuri keybox from GitHub, decode it, and install it to Tricky Store.

**Behavior:**
1. Source `../lib/common.sh` and `../lib/paths.sh` (feature script — use `"$MODDIR/../lib/"`)
2. Check that Tricky Store is installed (`/data/adb/modules/tricky_store` exists)
3. If Tricky Store not found, log warning and `exit 0` (skip gracefully)
4. If `keybox.xml` already exists, back it up to `keybox.xml.bak` (overwrite old backup)
5. Download keybox from `$KEYBOX_URL` using the shared `download()` function
6. Base64 decode the downloaded content into `keybox.xml`
7. If download or decode fails, restore backup and `exit 1`
8. Clean up temp files

**Key differences from the current code:**
- Uses `"$MODDIR/../lib/common.sh"` for sourcing (not inline functions)
- Uses `log()` for all output
- Uses `exit` not `return` (this is a standalone script)

**Checklist:**
- [ ] Script sources `"$MODDIR/../lib/common.sh"` and `"$MODDIR/../lib/paths.sh"`
- [ ] Checks Tricky Store dependency
- [ ] Backs up existing keybox
- [ ] Downloads and decodes keybox
- [ ] Uses `exit` not `return`

---

### Agent Prompt: Stream 2b — `src/features/target.sh`

**File to create:** `src/features/target.sh`

**Purpose:** Generate Tricky Store `target.txt` with fixed target packages + all installed apps.

**Behavior:**
1. Source libs (feature script path — use `"$MODDIR/../lib/"`)
2. Check `tee_status` file for `teeBroken` flag
3. Write fixed targets to `target.txt` (extract from current `target_txt.sh:24-49` or `src/lib/package_list.sh`)
4. Query `pm list packages -3` (user apps) and add them
5. Query `pm list packages -s` (system apps) and add them
6. If `teeBroken=true`, append `?` suffix to dynamic entries

**CRITICAL BUG TO FIX:** The current code at `Module/Yuri/target_txt.sh:67-82` uses `echo "$pkgs" | cut | while read...` which creates a subshell. `return` inside the `while` does NOT exit the function. Fix this using one of:
   - Redirect input instead of pipe: `done < <(echo "$pkgs" | cut -d ":" -f 2)` (works in /system/bin/sh with BusyBox)
   - Or store results in a variable and process after the pipe

**Key differences from the current code:**
- No subshell pipe bug
- Uses `log()` for all output
- Uses `exit` not `return`

**Checklist:**
- [ ] No subshell pipe (`| while read`) — use input redirection
- [ ] Handles `teeBroken` flag for `?` suffix
- [ ] Adds all user and system packages
- [ ] Uses `exit` not `return`

---

### Agent Prompt: Stream 2c — `src/features/security_patch.sh`

**File to create:** `src/features/security_patch.sh`

**Purpose:** Write a `security_patch.txt` for Tricky Store with a computed date.

**Behavior:**
1. Source libs (feature script path)
2. Get current year/month/day from `date`
3. If day >= 5, use current month; if day < 5, use previous month (handle January → December rollover)
4. Write to `/data/adb/tricky_store/security_patch.txt` in format:
   ```
   system=prop
   boot=YYYY-MM-DD
   vendor=YYYY-MM-DD
   ```

**BUG TO FIX:** The current code (`Module/Yuri/security_patch.sh:28-41`) uses `< 10` instead of `< 5`. The comment says "drop on the 5th" but the code checks "before the 10th". Fix to use `< 5` as the comment describes.

**Key differences from the current code:**
- Fixed day threshold (`5` not `10`)
- Uses `log()` for all output
- Uses `exit` not `return`

**Checklist:**
- [ ] Date threshold is `5` (matches the comment, not the buggy `10`)
- [ ] Handles month rollover (January → December of previous year)
- [ ] Writes correct Tricky Store format

---

### Agent Prompt: Stream 2d — `src/features/boot_hash.sh`

**File to create:** `src/features/boot_hash.sh`

**Purpose:** Read the verified boot hash and write it to `/data/adb/boot_hash`.

**Behavior:**
1. Source libs (feature script path)
2. Read `ro.boot.vbmeta.digest` via `getprop` (no `su` needed — script runs as root)
3. If empty, use all-zero hash (64 zeros)
4. Write to `/data/adb/boot_hash`
5. Reset the property to ensure consistency

**Key differences from the current code:**
- No `su -c` (scripts already run as root in Magisk/KSU context)
- Uses `log()` for all output
- Uses `exit` not `return`

**Checklist:**
- [ ] No `su -c`
- [ ] Uses `exit` not `return`
- [ ] Falls back to all-zero hash if digest is empty

---

### Agent Prompt: Stream 2e — `src/features/pif.sh`

**File to create:** `src/features/pif.sh`

**Purpose:** Trigger Play Integrity Fix fingerprint auto-update.

**Behavior:**
1. Source libs (feature script path)
2. Check if Play Integrity Fix is installed at `/data/adb/modules/playintegrityfix`
3. If not installed, log warning and `exit 0` (skip gracefully)
4. Read `module.prop` to determine variant:
   - "Play Integrity Fix [INJECT]" → run `autopif_ota.sh`, then `autopif.sh`
   - "Play Integrity Fork" → run `autopif4.sh -m`
   - Unknown → log warning, `exit 0`

**Key differences from the current code:**
- Simplified directory check (single `-f` check for `module.prop`)
- No `mkdir -p` on the module directory (it already exists or doesn't)

**Checklist:**
- [ ] Detects both INJECT and Fork variants
- [ ] Skips gracefully if not installed
- [ ] Uses `exit` not `return`

---

### Agent Prompt: Stream 2f — `src/features/hma.sh`

**File to create:** `src/features/hma.sh`

**Purpose:** Download and deploy HMA-OSS configuration.

**Behavior:**
1. Source libs (feature script path)
2. Check if HMA-OSS is installed (`pm list packages | grep -q org.frknkrc44.hma_oss`)
3. If not installed, check for legacy HMA (`com.tsng.hidemyapplist`) and log deprecation warning, then `exit 0`
4. Download config from `$HMA_CONFIG_URL` using shared `download()`
5. Write to config file with `chmod 600`
6. Set owner dynamically: `stat -c "%u" /data/user/0/org.frknkrc44.hma_oss` → `chown $UID:$UID`

**SECURITY FIX:** Use `chmod 600` not `chmod 777`. Derive UID dynamically, don't hardcode `u0_a0`.

**Checklist:**
- [ ] `chmod 600` not `777`
- [ ] Dynamic UID via `stat -c "%u"`
- [ ] Graceful skip if HMA-OSS not installed

---

### Agent Prompt: Stream 2g — `src/features/znctl.sh`

**File to create:** `src/features/znctl.sh`

**Purpose:** Configure Zygisk Next with optimal settings.

**Behavior:**
1. Source libs (feature script path)
2. Check Zygisk Next is installed (`/data/adb/modules/zygisksu/module.prop`)
3. If not installed, log warning and `exit 0`
4. Extract version string, compare against `1.3.0` using `awk` (BusyBox `sort` does NOT support `-V`):
   ```sh
   # Version comparison helper — POSIX-compatible, works in BusyBox ash
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
   version_ge "$CURRENT" "$REQUIRED" || { log "ZNCTL" "Error: Zygisk Next version too low, need $REQUIRED"; exit 0; }
   ```
5. If version too low, log warning and `exit 0`
6. Run `znctl` commands to configure:
   - `enforce-denylist just_umount`
   - `memory-type anonymous`
   - `linker builtin`

**CRITICAL BUGS TO FIX:**
- **Line 23 of the current code** uses `$VERSION` (undefined) instead of `$REQUIRED` — the version check is a no-op. Use `$REQUIRED`.
- **Line 24 of the current code** calls `log_messgae` (typo) instead of `log_message`. Call `log` instead.
- **Line 49 of the current code** does `mkdir -p "$SCRIPT_FILE"` where `SCRIPT_FILE` is the path to a binary (`zygiskd`). This creates a directory named `zygiskd`, then tries to execute it as a script. Use `ensure_dir "$(dirname "$SCRIPT_FILE")"` instead.

**Checklist:**
- [ ] Uses `$REQUIRED` not undefined `$VERSION`
- [ ] Version comparison uses `awk` not `sort -V` (BusyBox incompatibility)
- [ ] No `log_messgae` typo — uses `log()`
- [ ] `mkdir -p` or `ensure_dir` on directory, not file path
- [ ] Graceful skip if Zygisk Next not installed

---

### Agent Prompt: Stream 2h — `src/features/rka.sh`

**File to create:** `src/features/rka.sh`

**Purpose:** Provision Remote Key Attestation configuration for PassIt.

**Behavior:**
1. Source `../lib/common.sh` and `../lib/paths.sh` (feature script path)
2. Source `../rka/jsonarray.sh` for JSON manipulation
3. Check PassIt is installed (`pm path io.github.mhmrdd.libxposed.ps.passit`)
4. If not installed, log warning and `exit 0`
5. Read existing RKA config JSON, or create if not exists
6. Add/update "Yuri RKA" entry with host `rp.mhmrdd.me`, TCP port `59416`, auth token
7. Deactivate all other RKA entries
8. Save config ID to `/data/local/tmp/yurid`

**CRITICAL CHANGE:** The old `yurirka.sh` hardcoded `RKA_TOKEN="yurikey-5b70e270d6d69cd399c59ca3d62ccf6e"`. This is now in `lib/urls.sh`. Source `urls.sh` and use `$RKA_TOKEN`, `$RKA_HOST`, `$RKA_TCP`:
```sh
. "$MODDIR/../lib/common.sh"
. "$MODDIR/../lib/paths.sh"
. "$MODDIR/../lib/urls.sh"      # <-- for RKA_TOKEN, RKA_HOST, RKA_TCP
. "$MODDIR/../rka/jsonarray.sh"
```
Replace all hardcoded values with the variables from `urls.sh`.

**Keep the existing logic from** `Module/Yuri/yurirka.sh` — just update:
1. Sourcing paths (add `urls.sh`)
2. Replace hardcoded `"yurikey-5b70e270d6d69cd399c59ca3d62ccf6e"` with `"$RKA_TOKEN"`
3. Replace hardcoded `"rp.mhmrdd.me"` with `"$RKA_HOST"`
4. Replace hardcoded `59416` with `$RKA_TCP`

**Checklist:**
- [ ] Sources `"$MODDIR/../lib/common.sh"`, `"$MODDIR/../lib/paths.sh"`, `"$MODDIR/../lib/urls.sh"`
- [ ] Sources `"$MODDIR/../rka/jsonarray.sh"` for JSON functions
- [ ] Uses `$RKA_TOKEN` from urls.sh (not hardcoded)
- [ ] Graceful skip if PassIt not installed

---

### Agent Prompt: Stream 2i — `src/features/cleanup.sh`

**File to create:** `src/features/cleanup.sh`

**Purpose:** Clear all detection traces — app data, system props, temp files, ODEX.

**Behavior:**
1. Source libs (feature script path)
2. Source `src/lib/package_list.sh` for all app lists
3. Remove detector app data dirs from `/storage/emulated/0/Android/data/`
4. Remove detector app OBB and media dirs
5. Remove tool app data dirs (MT Manager, Shizuku, Termux, etc.)
6. Remove remote control app data dirs (AnyDesk, TeamViewer, RustDesk, etc.)
7. Reset system properties using `check_prop()` and `resetprop`
8. Delete `/data/local/tmp/*` but with caution (log what's deleted)
9. Delete ODEX files from `/data/app`

**KEY CHANGES from current `clear_all_detection_traces.sh`:**
- Source `package_list.sh` instead of hardcoding lists inline
- Use `check_prop()` from `lib/common.sh` instead of inline `resetprop`
- No `rm -rf /data/local/tmp/*` — delete specific known paths only
- No `su -c` (scripts run as root)
- Uses `log()` for all output
- **Must poll `sys.boot_completed` before `settings put` commands** — `settings put` requires fully booted system:
  ```sh
  while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 1
  done
  ```

**SECURITY FIX:** The current code does `rm -rf /data/local/tmp/*` which destroys all apps' temp files. Only clean known YuriKey-related paths.

**Checklist:**
- [ ] Sources `package_list.sh` for app lists
- [ ] Uses `check_prop()` from `common.sh`
- [ ] `sys.boot_completed` polling before `settings put` commands
- [ ] No `rm -rf /data/local/tmp/*` — only specific paths
- [ ] No `su -c`

---

### Agent Prompt: Stream 2j — `src/features/gms.sh`

**File to create:** `src/features/gms.sh`

**Purpose:** Force-stop and clear Google Play Store.

**Behavior:**
1. Source libs (feature script path)
2. Force-stop `com.android.vending`
3. Clear its cache via `cmd package trim-caches`
4. Check if package exists before operating

**Checklist:**
- [ ] Checks package existence before acting
- [ ] Uses `exit` not `return`
- [ ] Uses `log()` for all output

---

### Agent Prompt: Stream 2k — `src/features/kill_all.sh`

**File to create:** `src/features/kill_all.sh`

**Purpose:** Force-stop and clear data for all known detector apps.

**Behavior:**
1. Source libs (feature script path)
2. Source `package_list.sh` for `DETECTOR_APPS` and `GMS_APPS`
3. For each package: check if installed via `pm list packages | grep -q`, then force-stop and clear
4. If package not installed, skip with a log message (do not fail)

**BUG FIX:** The current code aborts the entire chain if `pm clear` fails for a missing package. Check existence first, skip missing packages with `continue`.

**Checklist:**
- [ ] Checks `pm list packages | grep -q "$pkg"` before acting
- [ ] Uses `continue` for missing packages, not `exit 1`
- [ ] Sources `package_list.sh`

---

### Agent Prompt: Stream 2l — `src/features/widevine.sh`

**File to create:** `src/features/widevine.sh`

**Purpose:** Fix Widevine L1 DRM by installing a keybox.

**Behavior:**
1. Source libs (feature script path)
2. Copy `FixWidevineL1/` contents from module directory to `/data/local/tmp/`
3. Set permissions on the copied files
4. Run `/vendor/bin/KmInstallKeybox` with the attestation file
5. Clean up temp files

**BUG FIX:** The current `widevinel1.sh` uses `cp -r ./FixWidevineL1/*` with a relative path. Since this script runs from `features/`, the relative path won't work. Use `"$MODDIR/../webroot/common/FixWidevineL1/"` instead.

**Note:** The FixWidevineL1 directory lives at `src/webroot/common/FixWidevineL1/`. At runtime it's at `$MODDIR/../webroot/common/FixWidevineL1/` (relative from `features/`).

**Checklist:**
- [ ] Uses absolute path derived from `$MODDIR`, not relative `./`
- [ ] No `su -c`

---

### Agent Prompt: Stream 2m — `src/features/lsposed.sh`

**File to create:** `src/features/lsposed.sh`

**Purpose:** Delete all LSPosed ODEX traces.

**Behavior:**
1. Source libs (feature script path)
2. Find and delete all `base.odex` files under `/data/app`
3. Log how many files were deleted

**Checklist:**
- [ ] Simple — this is a one-liner with `find`
- [ ] Uses `log()` for output

---

### Agent Prompt: Stream 2n — `src/features/migrate.sh`

**File to create:** `src/features/migrate.sh`

**Purpose:** One-time migration for users upgrading from the old module structure.

**Behavior:**
1. Source libs (feature script path)
2. Check if migration already done (`/data/adb/Yurikey/.migrated` exists) → if so, `exit 0`
3. Delete old `Module/Yuri/` directory if present (the old monolithic script directory)
4. Remove old duplicate files that may exist from previous versions
5. Log what was cleaned up
6. Write completion marker: `touch /data/adb/Yurikey/.migrated`

**Checklist:**
- [ ] Migration marker prevents re-running
- [ ] Deletes old `Module/Yuri/` structure
- [ ] Logs all actions taken

---

### Agent Prompt: Stream 3 — Orchestrator + Pipelines

**Files to create:**
- `src/orchestrator.sh`
- `src/pipelines/full_integrity`
- `src/pipelines/root_hide`

**`src/orchestrator.sh`:**
Root-level script — uses `"$MODDIR/lib/common.sh"` (not `../lib/`).

Takes one argument: pipeline name. Reads the corresponding file from `pipelines/`, iterates through each line, runs `sh features/$feature`. Supports:
- `#` comments (skip lines starting with `#`)
- `?` suffix: if the feature file doesn't exist on disk, skip it
- Empty lines (skip)
- Error handling: if any feature fails (exit != 0), log and abort with `die()`

**`src/pipelines/full_integrity`:**
```
gms.sh
target.sh
security_patch.sh
boot_hash.sh
keybox.sh
pif.sh?
```

**`src/pipelines/root_hide`:**
```
hma.sh
znctl.sh?
```

**Checklist:**
- [ ] Root-level script — uses `"$MODDIR/lib/common.sh"`
- [ ] Supports `?` suffix for optional features
- [ ] Supports `#` comments
- [ ] Aborts on feature failure unless optional

---

### Agent Prompt: Stream 4 — Boot + Installer + Action

**Files to create:**
- `src/customize.sh`
- `src/service.sh`
- `src/boot-completed.sh`
- `src/uninstall.sh`
- `src/action.sh`

**`src/customize.sh`:**
Installer script — **sourced by the installer**, NOT run directly. Use `$MODPATH` not `$MODDIR`. Use `return` not `exit`.

Behavior:
1. Source `"$MODPATH/lib/common.sh"` and `"$MODPATH/lib/urls.sh"`
2. Download keybox via shared `download()` and base64-decode into Tricky Store directory
3. **Write `module_paths.json`** for WebUI path discovery:
   ```sh
   mkdir -p "$MODPATH/webroot/json"
   cat > "$MODPATH/webroot/json/module_paths.json" <<JSON
   {"MODDIR": "$MODPATH"}
   JSON
   ```
4. **Determine architecture for sqlite3 download.** The installer provides `$ARCH` (one of: `arm`, `arm64`, `x86`, `x64`, `riscv64`) but the RKA binaries use Android ABI naming (`arm64-v8a`, `armeabi-v7a`, `x86_64`, `x86`, `armeabi`). Map the short name to ABI:
   ```sh
   # Map Magisk ARCH to ABI directory name for RKA sqlite3
   case "$ARCH" in
     arm64) RKA_ARCH="arm64-v8a" ;;
     arm)   RKA_ARCH="armeabi-v7a" ;;
     x64)   RKA_ARCH="x86_64" ;;
     x86)   RKA_ARCH="x86" ;;
     *)     RKA_ARCH="arm64-v8a" ;;  # fallback
   esac
   mkdir -p "$MODPATH/rka/$RKA_ARCH"
   download "$SQLITE_BASE_URL/${RKA_ARCH}/sqlite3" > "$MODPATH/rka/$RKA_ARCH/sqlite3" 2>/dev/null && chmod 755 "$MODPATH/rka/$RKA_ARCH/sqlite3" \
     || ui_print "- Warning: RKA sqlite3 download failed (non-fatal)"
   ```
   **Note:** The `$ARCH` variable is provided by the Magisk/KSU/APatch installer environment. On Magisk it's set automatically; on KSU/APatch it's also available. Using it avoids a redundant `getprop` call.
5. **Run one-time migration** if upgrading from old module structure:
   ```sh
   if [ -f "$MODPATH/features/migrate.sh" ]; then
     sh "$MODPATH/features/migrate.sh" || ui_print "- Warning: migration incomplete"
   fi
   ```
6. Bootstrap device info: `sh "$MODPATH/webroot/common/device-info.sh"`
7. On error, use `return 1` (never `exit`)

**`src/service.sh`:**
Root-level script — uses `"$MODDIR/lib/common.sh"`. Uses `exit`.

Runs at late_start service stage. Sets all boot-time properties using `check_prop()`:

Properties to set (extract from current `Module/service.sh`):
- `ro.boot.vbmeta.device_state` → `locked`
- `ro.boot.verifiedbootstate` → `green`
- `ro.boot.flash.locked` → `1`
- `ro.boot.veritymode` → `enforcing`
- `ro.boot.warranty_bit` → `0`
- `ro.warranty_bit` → `0`
- `ro.debuggable` → `0`
- `ro.force.debuggable` → `0`
- `ro.secure` → `1`
- `ro.adb.secure` → `1`
- `ro.build.type` → `user`
- `ro.build.tags` → `release-keys`
- `vendor.boot.vbmeta.device_state` → `locked`
- `vendor.boot.verifiedbootstate` → `green`
- `sys.oem_unlock_allowed` → `0`
- `ro.oem_unlock_supported` → `0`
- `ro.boot.realme.lockstate` → `1`
- `ro.secureboot.lockstate` → `locked`
- `ro.boot.bootmode` → contains "recovery" → set to "unknown"
- `vendor.boot.bootmode` → contains "recovery" → set to "unknown"
- `persist.sys.usb.config` → `none`
- `service.adb.root` → `0`
- `ro.crypto.state` → `encrypted`

No duplicate properties (each set once).

**MAGISK FALLBACK:** On Magisk (detected via `$KSU` not being set), `service.sh` must ALSO handle post-boot actions that would normally run in `boot-completed.sh`. Add polling:
```sh
if [ "$KSU" != "true" ]; then
  log "SERVICE" "Magisk detected — polling sys.boot_completed"
  resetprop -w sys.boot_completed 0
  settings put global development_settings_enabled 0
  settings put global adb_enabled 0
  settings put global oem_unlock_allowed 0
  resetprop --delete persist.service.adb.enable
  resetprop --delete persist.service.debuggable
  resetprop persist.sys.developer_options 0
fi
```

**`src/boot-completed.sh`:**
Root-level script. Uses `"$MODDIR/lib/common.sh"` and `"$MODDIR/lib/config_env.sh"`. Uses `exit`.

**KernelSU-only.** Must guard at the top so it's a no-op on other root managers:
```sh
# boot-completed.sh is KernelSU-specific — Magisk/APatch ignore this file but guard anyway
[ "$KSU" != "true" ] && exit 0
```

Runs at `ACTION_BOOT_COMPLETED`.

Behavior:
1. `settings put global development_settings_enabled 0`
2. `settings put global adb_enabled 0`
3. `settings put global oem_unlock_allowed 0`
4. `resetprop --delete persist.service.adb.enable`
5. `resetprop --delete persist.service.debuggable`
6. `resetprop persist.sys.developer_options 0`
7. Update module description using **cfg_set** (not raw ksud):
   ```sh
   . "$MODDIR/lib/config_env.sh"
   if [ -f "$TRICKY_DIR/keybox.xml" ]; then
     cfg_set "override.description" "✅ Active | $(getprop ro.build.version.release)"
   else
     cfg_set "override.description" "⚠️ Run action button to set up keybox"
   fi
   ```
   Using `cfg_set` ensures this works on Magisk too (via flat-file fallback).

**`src/uninstall.sh`:**
Sourced by uninstaller. Uses `MODDIR=${0%/*}` and `"$MODDIR/lib/common.sh"`. Uses `return`.

Behavior:
1. If `keybox.xml` contains "yuriiroot" signature, restore backup (`keybox.xml.bak`)
2. Remove `/data/adb/Yurikey/bin/` directory
3. Remove `/data/adb/Yurikey/config/` directory (user settings from flat-file fallback)
4. Remove migration marker `/data/adb/Yurikey/.migrated`
5. Remove boot hash file `/data/adb/boot_hash`
6. Remove RKA ID file `/data/local/tmp/yurid`

**`src/action.sh`:**
Sourced by action button OR run as subprocess (behavior differs between Magisk and KSU). **Do NOT use bare `return`** — top-level `return` outside a function is undefined behavior in `/system/bin/sh`.

Use **context detection**:
```sh
MODDIR=${0%/*}
. "$MODDIR/lib/common.sh"

sh "$MODDIR/orchestrator.sh" full_integrity
RC=$?

# Context detection: exit if subprocess, return if sourced
[ "${0##*/}" = "action.sh" ] && exit $RC || return $RC
```
The detection works because:
- When **sourced** (Magisk): `$0` is the caller (e.g., `manager.sh`), NOT `action.sh`
- When **run as subprocess** (KSU): `$0` IS `action.sh`

**Checklist:**
- [ ] `customize.sh` uses `$MODPATH` not `$MODDIR`
- [ ] `customize.sh` uses `return` not `exit`
- [ ] `customize.sh` writes `module_paths.json` to `$MODPATH/webroot/json/`
- [ ] `customize.sh` downloads arch-specific sqlite3 (no bundled binaries)
- [ ] `service.sh` has no duplicate property entries
- [ ] `service.sh` has Magisk-only `sys.boot_completed` polling (when `$KSU` not true)
- [ ] `boot-completed.sh` has `[ "$KSU" != "true" ] && exit 0` guard at top (KernelSU-only)
- [ ] `boot-completed.sh` uses `cfg_set()` for `override.description` (from config_env.sh)
- [ ] `action.sh` uses context detection: `"${0##*/}" = "action.sh" && exit || return`

---

### Agent Prompt: Stream 5 — RKA

**File to modify:** `src/rka/` — keep `jsonarray.sh` and `lspmcfg.sh`, **REMOVE pre-bundled sqlite3 binaries**.

**Files to create in `src/rka/`:**
- `src/rka/jsonarray.sh` — copy from `Module/Yuri/rka/jsonarray.sh`
- `src/rka/lspmcfg.sh` — copy from `Module/Yuri/rka/lspmcfg.sh` (with path update)

**Files to NOT create:**
- Do NOT copy any sqlite3 binaries — they will be downloaded at install time for the current architecture only (~700KB vs ~3MB bundled)

**Update** `src/rka/lspmcfg.sh` line 42 to use `$MODDIR` (not hardcoded path):
- Old: `LSP_SQLITE="/data/adb/modules/Yurikey/Yuri/rka/${_lsp_abi}/sqlite3"`
- New: `LSP_SQLITE="${MODDIR}/rka/${_lsp_abi}/sqlite3"`  (MODDIR is set by the caller via `${0%/*}`)

**The `customize.sh`** (Stream 4) will handle sqlite3 download at install time. Use the installer-provided `$ARCH` (Magisk/KSU/APatch) with an ABI mapping:
```sh
case "$ARCH" in
  arm64) RKA_ARCH="arm64-v8a" ;;
  arm)   RKA_ARCH="armeabi-v7a" ;;
  x64)   RKA_ARCH="x86_64" ;;
  x86)   RKA_ARCH="x86" ;;
  *)     RKA_ARCH="arm64-v8a" ;;
esac
mkdir -p "$MODPATH/rka/$RKA_ARCH"
download "$SQLITE_BASE_URL/${RKA_ARCH}/sqlite3" > "$MODPATH/rka/$RKA_ARCH/sqlite3" 2>/dev/null && chmod 755 "$MODPATH/rka/$RKA_ARCH/sqlite3"
```

**Checklist:**
- [ ] `jsonarray.sh` copied to `src/rka/jsonarray.sh`
- [ ] `lspmcfg.sh` copied to `src/rka/lspmcfg.sh` with path updated
- [ ] No sqlite3 binaries in `src/rka/` (downloaded at install time)

---

## PHASE 3 PROMPT

Run **after** all Phase 2 streams complete.

---

### Agent Prompt: Stream 9 — Final Assembly

**Purpose:** Build the module and verify everything.

**Steps:**
1. Navigate to the repo root
2. Run `npm ci` to install dependencies
3. Run `npm run build` to generate `Module/` directory
4. Verify the structure:
   ```
   Module/
   ├── module.prop
   ├── META-INF/com/google/android/updater-script  (contains: #MAGISK)
   ├── lib/
   │   ├── paths.sh
   │   ├── urls.sh
   │   ├── common.sh
   │   ├── config_env.sh           ← NEW
   │   └── package_list.sh
   ├── features/
   │   ├── keybox.sh
   │   ├── target.sh
   │   ├── security_patch.sh
   │   ├── boot_hash.sh
   │   ├── pif.sh
   │   ├── hma.sh
   │   ├── znctl.sh
   │   ├── rka.sh
   │   ├── cleanup.sh
   │   ├── gms.sh
   │   ├── kill_all.sh
   │   ├── widevine.sh
   │   ├── lsposed.sh
   │   └── migrate.sh              ← NEW
   ├── orchestrator.sh
   ├── pipelines/
   ├── customize.sh
   ├── service.sh
   ├── boot-completed.sh
   ├── uninstall.sh
   ├── action.sh
   ├── rka/
   │   ├── jsonarray.sh
   │   └── lspmcfg.sh              ← NO bundled sqlite3 binaries
   └── webroot/
       ├── config.json
       ├── index.html
       ├── css/style.css
       ├── js/app.js (bundled by Parcel)
       ├── js/i18n.js               ← NEW
       ├── json/
       │   └── module_paths.json    ← NEW (written by customize.sh)
       ├── lang/
       └── common/device-info.sh
   ```
5. Run verification checks:
   ```sh
   # No hardcoded paths in shell scripts (module_paths.json is the only allowed hardcoded ref)
   grep -rn "/data/adb/modules/Yurikey" Module/lib/ Module/features/ Module/*.sh --include="*.sh" \
     && echo "FAIL: hardcoded paths found" || echo "OK"

   # Feature scripts use exit, not return
   ! grep -rn "^[[:space:]]*return[^_]" Module/features/ --include="*.sh" \
     || echo "FAIL: return in feature scripts"

   # Feature scripts use ../lib/ (not lib/)
   head -5 Module/features/keybox.sh | grep -q "\.\./lib" && echo "OK" || echo "FAIL: features not using ../lib/"

   # Root-level scripts use MODDIR/lib/ (not ../lib/)
   head -5 Module/service.sh | grep -q 'MODDIR/lib/' && echo "OK" || echo "FAIL: service.sh not using MODDIR/lib/"

   # customize.sh uses $MODPATH (not MODDIR)
   head -20 Module/customize.sh | grep -q "MODPATH" && echo "OK" || echo "FAIL: customize.sh not using MODPATH"

   # action.sh uses context detection (not bare return)
   grep -q 'exit.*return' Module/action.sh && echo "OK" || echo "FAIL: action.sh missing context detection"

   # No su -c in feature scripts
   ! grep -rn "su -c" Module/features/ --include="*.sh" \
     || echo "FAIL: su -c found"

   # config_env.sh exists with cfg_get, cfg_set, and cfg_delete
   grep -q 'cfg_get' Module/lib/config_env.sh || echo "FAIL: config_env.sh missing cfg_get"
   grep -q 'cfg_set' Module/lib/config_env.sh || echo "FAIL: config_env.sh missing cfg_set"
   grep -q 'cfg_delete' Module/lib/config_env.sh || echo "FAIL: config_env.sh missing cfg_delete"

   # app.js uses bridge detection, not top-level kernelsu import
   grep -q 'getBridge' Module/webroot/js/app.js && echo "OK" || echo "FAIL: app.js missing bridge detection"

   # kernelsu is optional (not in dependencies)
   grep -q '"optionalDependencies"' Module/../package.json 2>/dev/null && echo "OK" || echo "FAIL: kernelsu not in optionalDependencies"

   # No sqlite3 binaries in rka/ (check for any ELF binary)
   ! file Module/rka/*/sqlite3 2>/dev/null | grep -q ELF \
     || echo "FAIL: sqlite3 binary found in rka/ (should be downloaded at install)"

   # module_paths.json exists
   test -f Module/webroot/json/module_paths.json && echo "OK" || echo "FAIL: module_paths.json missing"

    # device-info.sh sources lib/
    grep -q '\.\./\.\./lib/common.sh' Module/webroot/common/device-info.sh \
      && echo "OK" || echo "FAIL: device-info.sh not sourcing lib/"

    # MWC load guard in <head> (inline script, not in module)
    grep -q 'customElements.whenDefined' Module/webroot/index.html \
      && echo "OK" || echo "FAIL: MWC load guard missing from index.html head"

    # CFG has in-memory cache (_cache property)
    grep -q '_cache' Module/webroot/js/app.js \
      && echo "OK" || echo "FAIL: CFG missing in-memory cache"

    # addHistory uses printf not echo
    grep -q 'printf' Module/webroot/js/app.js \
      && echo "OK" || echo "FAIL: addHistory does not use printf"

    # i18n handles en → source/string.json
    grep -q 'source/string.json' Module/webroot/js/i18n.js \
      && echo "OK" || echo "FAIL: i18n.js missing en fallback to source/string.json"

    # i18n preserves HTML (uses innerHTML for translations with markup)
    grep -q 'innerHTML' Module/webroot/js/i18n.js \
      && echo "OK" || echo "FAIL: i18n.js missing HTML preservation"

    # rka.sh sources urls.sh for RKA_TOKEN
    grep -q 'urls.sh' Module/features/rka.sh \
      && echo "OK" || echo "FAIL: rka.sh does not source urls.sh for RKA_TOKEN"

    # url.sh contains RKA_TOKEN
    grep -q 'RKA_TOKEN' Module/lib/urls.sh \
      && echo "OK" || echo "FAIL: urls.sh missing RKA_TOKEN"

    # customize.sh runs migrate.sh
    grep -q 'migrate.sh' Module/customize.sh \
      && echo "OK" || echo "FAIL: customize.sh does not run migrate.sh"

    # cleanup.sh polls sys.boot_completed
    grep -q 'sys.boot_completed' Module/features/cleanup.sh \
      && echo "OK" || echo "FAIL: cleanup.sh missing sys.boot_completed polling"

    # znctl.sh uses awk not sort -V for version comparison
    grep -q 'sort -V' Module/features/znctl.sh \
      && echo "FAIL: znctl.sh uses sort -V (BusyBox incompatible)" || echo "OK"

    # boot-completed.sh has KSU guard
    grep -q 'KSU.*exit 0' Module/boot-completed.sh \
      && echo "OK" || echo "FAIL: boot-completed.sh missing KSU guard"

    # customize.sh uses ARCH mapping not getprop
    grep -q 'getprop ro.product.cpu.abi' Module/customize.sh \
      && echo "FAIL: customize.sh uses getprop instead of \$ARCH mapping" || echo "OK"

    # lang/ directory exists in output
    test -f Module/webroot/lang/en.json || test -f Module/webroot/lang/source/string.json \
      && echo "OK" || echo "FAIL: lang/ directory missing from Module/webroot/"
    ```
6. If all checks pass, delete old directories (with rollback safety):
   ```sh
   # Backup old layout first
   if [ -d Module/Yuri ]; then
     cp -r Module/Yuri Module/Yuri.bak
     rm -rf Module/Yuri/
   fi
   if [ -f Module/webroot/index.html ] && grep -q beercss Module/webroot/index.html 2>/dev/null; then
     cp -r Module/webroot Module/webroot.bak
     rm -rf Module/webroot/
   fi
   ```
7. Run verification again — if it FAILS, restore:
   ```sh
   [ -d Module/Yuri.bak ] && mv Module/Yuri.bak Module/Yuri
   [ -d Module/webroot.bak ] && mv Module/webroot.bak Module/webroot
   ```
8. Clean up git tracking:
   ```sh
   git rm --cached key attestation 2>/dev/null || true
   ```
   **Do NOT `git rm --cached config.json`** — it must stay tracked as the download source for HMA config.
9. Commit

**Checklist:**
- [ ] `npm run build` completes without errors
- [ ] Module structure is complete (including config_env.sh, migrate.sh, module_paths.json)
- [ ] No hardcoded `/data/adb/modules/Yurikey` in shell scripts
- [ ] Feature scripts use `../lib/` not `lib/`
- [ ] Root-level scripts use `$MODDIR/lib/` not `../lib/`
- [ ] `customize.sh` uses `$MODPATH` not `$MODDIR`
- [ ] `action.sh` uses context detection (`exit`/`return` based on `$0`)
- [ ] No `return` in feature scripts (they use `exit`)
- [ ] No `su -c` in feature scripts
- [ ] `config_env.sh` exists with `cfg_get`/`cfg_set`/`cfg_delete` functions
- [ ] No bundled sqlite3 binaries in `rka/`
- [ ] `module_paths.json` written to `webroot/json/`
- [ ] `device-info.sh` sources `../../lib/common.sh`
- [ ] `key`, `attestation` removed from git tracking (NOT config.json)
- [ ] Old directories cleaned up with rollback safety (backup before delete)
- [ ] **app.js uses bridge detection (getBridge())** — no `import {exec,toast} from 'kernelsu'` at top level
- [ ] **app.js has MWC load guard in `<head>` inline script** (before module import, in index.html)
- [ ] **app.js CFG has in-memory `_cache`** (avoid shell exec on every read)
- [ ] **app.js `addHistory()` uses `printf '%s\n'`** not `echo` for shell safety
- [ ] **`i18n.js` handles `en` → `source/string.json`** fallback
- [ ] **`i18n.js` preserves HTML** in translations (uses `innerHTML` when children.length > 0 and HTML detected)
- [ ] **`features/rka.sh` sources `urls.sh`** and uses `$RKA_TOKEN` not hardcoded
- [ ] **`lib/urls.sh` defines `RKA_TOKEN`** (single source of truth)
- [ ] **`customize.sh` runs `migrate.sh`** during install
- [ ] **`cleanup.sh` polls `sys.boot_completed`** before `settings put`
- [ ] **`lib/lspmcfg.sh` uses `$MODDIR`** not hardcoded `/data/adb/modules/Yurikey/`
- [ ] **`znctl.sh` uses `awk`** not `sort -V` for version comparison
- [ ] **`boot-completed.sh` has KSU guard** at top
- [ ] **`customize.sh` uses `$ARCH` mapping** not `getprop` for sqlite3 arch
- [ ] **`Module/webroot/lang/` exists** with at least `source/string.json` (for English)
- [ ] `kernelsu` is in `optionalDependencies` in package.json (NOT in `dependencies`)
- [ ] All changes committed
