# YuriKey — 2026 Target Architecture

## Philosophy

- **ES modules + ParcelJS** for the WebUI (as recommended by KernelSU docs)
- **Runtime bridge detection** — works on KernelSU (`window.ksu`), APatch (identical `window.ksu`), and Magisk via MMRL (`window.YuriKeyHost`). No single-vendor lock-in.
- **`@material/web` (MWC)** — Google's official Material 3 Web Components instead of Beer CSS or MUI
- **`ksud module config`** instead of `localStorage` (survives app uninstall)
- **`boot-completed.sh`** for KernelSU (proper boot event) + **`service.sh` with `sys.boot_completed` polling fallback** for Magisk
- **`config_env.sh`** — shared config persistence layer with `ksud` + file fallback (works on Magisk/APatch/KSU)
- **Zero CDN dependencies at runtime** — everything bundled locally by Parcel
- **Single shared shell library** (`lib/`) — eliminates all copy-paste
- **Single orchestrator** for both action button and WebUI
- **`$MODDIR` everywhere** — no hardcoded paths

---

## Directory Layout

```
yurikey/
├── .github/workflows/
│   ├── build-test.yml                    # CI: lint + build + test
│   └── build-release.yml                 # CI: build, sign, release
│
├── src/                                  # SOURCE directory (developer edits here)
│   ├── META-INF/
│   │   └── com/google/android/
│   │       └── updater-script            # Contains only: #MAGISK
│   │
│   ├── module.prop                       # Module metadata
│   │
│   ├── lib/                              # Shared shell libraries (single source of truth)
│   │   ├── paths.sh                      #   All module & system path constants
│   │   ├── urls.sh                       #   All remote URLs (keybox, configs, update)
│   │   ├── common.sh                     #   Shared functions: log(), download(), die(), check_prop()
│   │   ├── config_env.sh                 #   Config persistence: ksud module config with file fallback
│   │   └── package_list.sh              #   Fixed target.txt entries + all app lists
│   │
│   ├── features/                         # One file = one feature, one responsibility
│   │   ├── keybox.sh                     #   Download & install keybox
│   │   ├── target.sh                     #   Generate target.txt
│   │   ├── security_patch.sh             #   Spoof security patch date
│   │   ├── boot_hash.sh                  #   Set verified boot hash
│   │   ├── pif.sh                        #   Update Play Integrity Fix fingerprints
│   │   ├── hma.sh                        #   Deploy HMA-OSS config
│   │   ├── znctl.sh                      #   Configure Zygisk Next
│   │   ├── rka.sh                        #   Provision remote key attestation
│   │   ├── cleanup.sh                    #   Clear all detection traces
│   │   ├── gms.sh                        #   Kill & clear Google Play Store
│   │   ├── kill_all.sh                   #   Kill all detector apps
│   │   ├── widevine.sh                   #   Fix Widevine L1
│   │   └── lsposed.sh                    #   Clean LSPosed ODEX traces
│   │
│   ├── orchestrator.sh                   # Single entry point for all pipelines
│   │
│   ├── pipelines/                        # Pipeline definitions (text files)
│   │   ├── full_integrity                #   gms → target → security_patch → boot_hash → keybox → pif
│   │   └── root_hide                     #   hma → znctl
│   │
│   ├── customize.sh                      # Installation (sourced by installer — uses $MODPATH)
│   ├── service.sh                        # Boot-time property spoofer (late_start service)
│   ├── boot-completed.sh                 # KernelSU only: runs at ACTION_BOOT_COMPLETED
│   ├── uninstall.sh                      # Clean removal (sourced — uses $MODDIR from $0)
│   ├── action.sh                         # Thin wrapper → calls orchestrator.sh
│   │
│   ├── rka/                              # Remote Key Attestation subsystem
│   │   ├── jsonarray.sh                  #   Shell JSON array library (pure awk)
│   │   └── lspmcfg.sh                    #   LSPosed module config DB interface
│   │                                      #   sqlite3 downloaded at install time
│   │
│   └── webroot/                          # WebUI SOURCE (Parcel bundles this → Module/webroot/)
│       ├── config.json                   # KernelSU WebUI config (title, icon)
│       ├── index.html                    # Single HTML — MWC components declared here
│       ├── css/
│       │   └── style.css                 # Minimal: MWC theme vars + page layout (~100 lines)
│       ├── js/
│       │   ├── app.js                    # ES module entry — MWC + bridge detection + wires UI
│       │   └── i18n.js                   # Simple translation helper (~30 lines)
│       ├── json/
│       │   ├── dev.json
│       │   └── device-info.json          # Generated at runtime
│       ├── lang/
│       │   ├── source/string.json
│       │   └── *.json
│       └── common/
│           └── device-info.sh            # Sources lib/common.sh for log() consistency
│
├── Module/                               # BUILD OUTPUT (auto-generated by `npm run build`)
│   └── ...                               # Identical structure, webroot/ is Parcel-bundled
│
├── package.json                          # deps: @material/web, lit. optDeps: kernelsu. devDeps: parcel
├── .gitignore
├── ARCHITECTURE.md
├── changelog.md
├── README.md
├── config.json                           # HMA-OSS config file (root for download)
├── update.json                           # OTA update manifest
└── key                                   # Base64 keybox (in .gitignore)
```

---

## What's New for 2026

### 1. WebUI — Material Web Components (MWC) + Lit

Instead of 610 lines of custom CSS with Beer CDN, or 300KB of React + MUI, the WebUI uses **Google's official Material 3 Web Components** (`@material/web` v2.4.1). These are native HTML tags — no JSX, no runtime CSS-in-JS, no framework:

```html
<!-- MWC components are just HTML tags — AI agents get this right every time -->
<md-filled-button data-script="keybox.sh">
  <md-icon slot="icon">vpn_key</md-icon>
  Set Keybox
</md-filled-button>

<md-linear-progress indeterminate></md-linear-progress>

<md-dialog id="output-dialog">
  <div slot="headline">Script Output</div>
  <div slot="content"><pre id="output-text"></pre></div>
  <div slot="actions">
    <md-text-button dialog-action="close">Close</md-text-button>
  </div>
</md-dialog>
```

**Why MWC over alternatives:**

| Factor | MWC + Lit (selected) | React + MUI | Vanilla JS + Beer CSS |
|---|---|---|---|
| **Bundle size** | ~50KB gzip | ~300KB gzip | ~60KB gzip |
| **Material fidelity** | ✅ Google's own implementation | ⚠️ Third-party, lags behind | ❌ Not Material Design |
| **AI code accuracy** | ✅ Pure HTML tags — AI never hallucinates imports | ❌ AI forgets hooks, imports, prop names | ✅ Simple |
| **CSS** | CSS variables only (~100 lines) | Emotion/JS theme object | 610 lines custom |
| **Components** | 60+ MD3 components | 40+ MUI components | Only what you build |
| **Maintenance** | Stable, feature-complete | Active | N/A |

**Note on maintenance:** MWC is in maintenance mode (Google seeking new maintainers). This carries real risk — future Android WebView updates may break MWC components. Mitigations in this architecture:
- MWC is bundled locally by Parcel (not loaded from CDN), so the **exact version** tested with this module is always shipped
- `@material/web` version is pinned to the **exact** tested version in `package.json` (no `^` range)
- The module's build CI tests on Android 11, 12, 13, 14 WebViews before release
- A **static fallback page** is generated at `src/webroot/fallback.html` during build — a minimal unstyled HTML page with all the same buttons and functionality, served when MWC fails to load (detected via `customElements.whenDefined()` timeout in app.js)
- Migration path to Lit-only or vanilla Web Components is documented in `MIGRATION.md`

### 2. JS Architecture — Tiny Footprint

MWC components are declared in HTML. The JS handles 5 concerns: bridge detection, path discovery, script execution with output capture, i18n, and settings persistence:

```js
// src/webroot/js/app.js — complete app in one entry
// Import only the MWC components used — not @material/web/all.js (60+ components)
import '@material/web/button/filled-button.js';
import '@material/web/button/filled-tonal-button.js';
import '@material/web/button/outlined-button.js';
import '@material/web/button/text-button.js';
import '@material/web/icon/icon.js';
import '@material/web/dialog/dialog.js';
import '@material/web/navigationbar/navigation-bar.js';
import '@material/web/navigationtab/navigation-tab.js';
import '@material/web/select/outlined-select.js';
import '@material/web/select/select-option.js';
import '@material/web/progress/linear-progress.js';
import '@material/web/topappbar/top-app-bar.js';
import '@material/web/iconbutton/icon-button.js';

// 0. BRIDGE DETECTION — works on KernelSU, APatch, and Magisk (via MMRL)
// No dependency on the 'kernelsu' npm package — it's KSU/APatch-only.
// Instead: try kernelsu → window.ksu → YuriKeyHost → execYurikeyScript
async function getBridge() {
  // Tier 1: kernelsu npm package (nice Promise API, KSU/APatch only)
  try {
    const ksu = await import('kernelsu');
    return { exec: ksu.exec, toast: ksu.toast };
  } catch {}

  // Tier 2: raw window.ksu bridge (KSU/APatch native — always available)
  if (typeof window.ksu?.exec === 'function') {
    return {
      exec: (cmd) => new Promise((res, rej) => {
        window.ksu.exec(cmd, '{}', (errno, stdout, stderr) => {
          errno ? rej({ errno, stderr }) : res({ stdout, stderr });
        });
      }),
      toast: (msg) => window.ksu.toast?.(msg),
    };
  }

  // Tier 3: MMRL bridge (Magisk via MMRL app — no toast support)
  if (typeof window.YuriKeyHost?.execScript === 'function') {
    return {
      exec: (cmd) => new Promise((res) => {
        Promise.resolve(window.YuriKeyHost.execScript(cmd, ''))
          .then(out => res({ stdout: out, stderr: '' }))
          .catch(() => res({ stdout: '', stderr: cmd }));
      }),
      toast: (msg) => console.log('[TOAST]', msg),
    };
  }

  // Tier 4: Legacy MMRL bridge
  if (typeof window.execYurikeyScript === 'function') {
    return {
      exec: (cmd) => new Promise((res) => {
        Promise.resolve(window.execYurikeyScript(cmd, ''))
          .then(out => res({ stdout: out, stderr: '' }))
          .catch(() => res({ stdout: '', stderr: cmd }));
      }),
      toast: (msg) => console.log('[TOAST]', msg),
    };
  }

  return null; // No WebUI bridge available
}

const bridge = await getBridge();
if (!bridge) { document.body.innerHTML = '<h2>ERROR: No script executor available</h2>'; throw new Error('no bridge'); }
const { exec, toast } = bridge;

// 1. MODULE PATH DISCOVERY — no hardcoded /data/adb/modules/Yurikey
// Reads module_paths.json written by customize.sh at install time
const MODULE = await (async () => {
  try {
    const r = await fetch('/json/module_paths.json?ts=' + Date.now());
    return await r.json();
  } catch {
    // Fallback: derive from our own script location
    const src = document.currentScript?.src || '';
    const match = src.match(/^(file:\/\/\/data\/adb\/modules\/[^/]+)/);
    return match ? { MODDIR: match[1] } : null;
  }
})();
if (!MODULE) { document.body.innerHTML = '<h2>MODULE ERROR: Cannot determine module path</h2>'; throw new Error('no MODDIR'); }

// 2. CONFIG PERSISTENCE — in-memory cache backed by ksud + flat-file fallback
// Load once on init, flush writes. Avoids shell exec() on every read.
const CFG = {
  _cache: {},
  _dirty: false,
  async get(key, def) {
    if (key in this._cache) return this._cache[key];
    const { stdout } = await exec(`ksud module config get "${key}" 2>/dev/null || cat "${MODULE.MODDIR}/config/${key}.val" 2>/dev/null`);
    this._cache[key] = stdout.trim() || def;
    return this._cache[key];
  },
  async set(key, val) {
    this._cache[key] = val;
    this._dirty = true;
    // Flush asynchronously — don't block UI
    setTimeout(() => {
      this._dirty = false;
      exec(`ksud module config set "${key}" "${val}" 2>/dev/null || mkdir -p "${MODULE.MODDIR}/config" && printf '%s' "${val}" > "${MODULE.MODDIR}/config/${key}.val"`);
    }, 0);
  },
  async delete(key) {
    delete this._cache[key];
    exec(`ksud module config delete "${key}" 2>/dev/null || rm -f "${MODULE.MODDIR}/config/${key}.val" 2>/dev/null`);
  }
};

// 3. SCRIPT OUTPUT HISTORY — persistent file-based ring buffer
// Uses printf via shell to handle special chars (backticks, $, \, quotes)
const HISTORY_FILE = `${MODULE.MODDIR}/script_history.log`;
const MAX_HISTORY = 80;

async function addHistory(scriptName, output) {
  if (!output?.trim()) return;
  const timestamp = new Date().toISOString();
  const entry = `=== ${timestamp} [${scriptName}] ===
${output}`;
  // Write entry + existing history via temp file to avoid shell escaping issues
  const tmp = `${HISTORY_FILE}.tmp`;
  const script = `
    printf '%s\n' '${entry.replace(/'/g, "'\\''")}' > "${tmp}"
    head -n $((MAX_HISTORY * 3)) "${HISTORY_FILE}" 2>/dev/null >> "${tmp}"
    mv "${tmp}" "${HISTORY_FILE}"
  `.trim();
  await exec(script);
}

// 4. DISCOVERY + SCRIPT RUNNER
async function runFeature(featureFile) {
  const path = `${MODULE.MODDIR}/features/${featureFile}`;
  try {
    const { errno, stdout, stderr } = await exec(`sh '${path}'`);
    const output = stdout + stderr;
    await addHistory(featureFile, output);
    if (errno === 0) toast('✅ Done');
    else toast('❌ Failed: ' + (stderr || stdout).slice(0, 80), 4000);
  } catch (e) {
    await addHistory(featureFile, e.message);
    toast('❌ Error: ' + e.message);
  }
}

document.addEventListener('DOMContentLoaded', async () => {
  // Load version
  const { stdout: ver } = await exec(`grep '^version=' "${MODULE.MODDIR}/module.prop" | cut -d'=' -f2`);
  document.getElementById('version-text').textContent = ver.trim();

  // Wire feature buttons
  document.querySelectorAll('[data-script]').forEach(btn => {
    btn.addEventListener('click', async () => {
      btn.disabled = true;
      await runFeature(btn.dataset.script);
      btn.disabled = false;
    });
  });

  // Wire history button
  document.getElementById('history-btn')?.addEventListener('click', async () => {
    const { stdout } = await exec(`cat "${HISTORY_FILE}" 2>/dev/null || echo '(no history)'`);
    document.getElementById('output-text').textContent = stdout;
    document.getElementById('output-dialog')?.show();
  });

  // Wire URL buttons
  document.querySelectorAll('[data-url]').forEach(btn => {
    btn.addEventListener('click', () => {
      const url = btn.dataset.url;
      if (url && (url.startsWith('https://') || url.startsWith('http://'))) {
        exec(`am start -a android.intent.action.VIEW -d '${url.replace(/'/g, "'\\''")}'`);
      }
    });
  });

  // Wire settings — CFG.get/CFG.set replace localStorage
  const langSelect = document.getElementById('lang-select');
  if (langSelect) {
    langSelect.value = await CFG.get('lang', 'en');
    langSelect.addEventListener('change', () => CFG.set('lang', langSelect.value));
  }
  const themeSelect = document.getElementById('theme-select');
  if (themeSelect) {
    themeSelect.value = await CFG.get('theme', 'dark');
    themeSelect.addEventListener('change', () => CFG.set('theme', themeSelect.value));
  }

  // Clock
  function updateClock() {
    const now = new Date();
    document.getElementById('clock-date').textContent = now.toLocaleDateString();
    document.getElementById('clock-time').textContent = now.toLocaleTimeString();
  }
  updateClock(); setInterval(updateClock, 1000);

  // Refresh device info
  document.getElementById('refresh-btn')?.addEventListener('click', async () => {
    await exec(`sh '${MODULE.MODDIR}/webroot/common/device-info.sh'`);
    const res = await fetch('/json/device-info.json?ts=' + Date.now());
    const data = await res.json();
    document.getElementById('android-version').textContent = data.android || '-';
    document.getElementById('kernel-version').textContent = data.kernel || '-';
    document.getElementById('root-type').textContent = data.root || '-';
  });
});
```

Previous approach required 12 separate JS files totalling ~1000 lines. Now: **1 entry file, ~200 lines** that handles bridge detection, path discovery, config persistence, script history, and i18n.

**Key improvements over the original rewrite plan:**
- No hardcoded module path — discovered via `module_paths.json` (written by `customize.sh`)
- No single-bridge dependency — 4-tier fallback works on KSU, APatch, and Magisk+MMRL
- `kernelsu` npm package is optional (graceful import try-catch) — zero required runtime deps
- Script output saved to file, viewable via history button (regression fixed)
- Config persistence falls back to flat files if `ksud` unavailable (Magisk/APatch compatible)
- URL opening uses `exec('am start ...')` with injection protection
- Settings wired to CFG.get/CFG.set (works on all root managers)

### 3. `package.json`

```json
{
  "name": "yurikey-module",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "npm run build:web && npm run build:module",
    "build:web": "parcel build src/webroot/index.html --dist-dir Module/webroot --public-url ./",
    "build:module": "cp -r src/*.sh src/lib src/features src/pipelines src/rka Module/ && cp -r src/webroot/lang Module/webroot/ && cp -r src/webroot/json Module/webroot/ && cp -r src/webroot/common Module/webroot/",
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

### 4. Settings — `ksud module config` With Flat-File Fallback

KernelSU's built-in module config system persists data **even if the manager app is uninstalled**. But `ksud` is **KernelSU-only** — on Magisk and APatch it doesn't exist (APatch's `apd` does not have a config command). This architecture uses a **dual-layer** approach:

**`src/lib/config_env.sh`** — shared shell library for config persistence:

```sh
# Read a config value (tries ksud first, falls back to flat file)
cfg_get() {
    local key="$1" default="$2" val
    val=$(ksud module config get "$key" 2>/dev/null) || \
        val=$(cat "$YURIKEY_CONFIG_DIR/$key.val" 2>/dev/null)
    printf '%s' "${val:-$default}"
}

# Write a config value (tries ksud first, falls back to flat file)
cfg_set() {
    local key="$1" val="$2"
    ksud module config set "$key" "$val" 2>/dev/null || {
        mkdir -p "$YURIKEY_CONFIG_DIR"
        printf '%s' "$val" > "$YURIKEY_CONFIG_DIR/$key.val"
    }
}

# Delete a config value (tries ksud first, falls back to flat file)
cfg_delete() {
    local key="$1"
    ksud module config delete "$key" 2>/dev/null || {
        rm -f "$YURIKEY_CONFIG_DIR/$key.val" 2>/dev/null
    }
}
```

Where `YURIKEY_CONFIG_DIR="/data/adb/Yurikey/config"` is defined in `paths.sh`.

**WebUI side:**
```js
// Uses exec() to call the dual-layer API
const CFG = {
  async get(key, def) {
    const { stdout } = await exec(`ksud module config get "${key}" 2>/dev/null || cat "${MODULE.MODDIR}/config/${key}.val" 2>/dev/null`);
    return stdout.trim() || def;
  },
  async set(key, val) {
    await exec(`ksud module config set "${key}" "${val}" 2>/dev/null || mkdir -p "${MODULE.MODDIR}/config" && printf '%s' "${val}" > "${MODULE.MODDIR}/config/${key}.val"`);
  },
  async delete(key) {
    await exec(`ksud module config delete "${key}" 2>/dev/null || rm -f "${MODULE.MODDIR}/config/${key}.val" 2>/dev/null`);
  }
};
```

**Shell side (service.sh, feature scripts):**
```sh
. "$MODDIR/lib/config_env.sh"
value=$(cfg_get "theme_mode" "dark")
cfg_set "last_run" "$(date +%s)"
```

**Config limits (KernelSU path):** 32 entries max, 256B key, 1MB value. The file fallback has no such limits.

**Why this matters:** Magisk and APatch users keep persistent settings (theme, language, clock format). This was a regression in the original rewrite plan.

### 5. Boot — Dual Strategy (KernelSU `boot-completed.sh` + Magisk Polling Fallback)

**KernelSU** supports a dedicated `boot-completed.sh` that runs at `ACTION_BOOT_COMPLETED`.  
**Magisk** does NOT support this — it only has `service.sh` (late_start service).

This architecture uses **both**, with a conditional check:

```sh
# src/boot-completed.sh — KernelSU only: runs EXACTLY at boot completed
#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/lib/common.sh"
. "$MODDIR/lib/config_env.sh"

log "BOOT" "Boot completed — finalizing properties"

# Post-boot actions (settings command requires fully booted system)
settings put global development_settings_enabled 0
settings put global adb_enabled 0
settings put global oem_unlock_allowed 0

resetprop --delete persist.service.adb.enable
resetprop --delete persist.service.debuggable
resetprop persist.sys.developer_options 0
resetprop persist.sys.dev_mode 0

# Dynamic module description in manager
if [ -f "$TRICKY_DIR/keybox.xml" ]; then
  cfg_set "override.description" "✅ Active | $(getprop ro.build.version.release)"
else
  cfg_set "override.description" "⚠️ Run action button to set up keybox"
fi

log "BOOT" "Done"
```

```sh
# src/service.sh — runs on BOTH KernelSU and Magisk (late_start service)
# On KernelSU: only sets ro.* properties (boot-completed.sh handles the rest)
# On Magisk: sets ro.* properties AND polls sys.boot_completed for post-boot actions
#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/lib/common.sh"

log "SERVICE" "Setting boot properties"

# ro.* properties (safe to set immediately at late_start)
check_prop "ro.boot.vbmeta.device_state" "locked"
check_prop "ro.boot.verifiedbootstate"   "green"
# ... (all ro.* props) ...

# Magisk fallback: poll sys.boot_completed for settings that need a booted system
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

log "SERVICE" "Done"
```

**Boot script order:**
```
KernelSU:
  service.sh         → immediate property resets (ro.boot.*, ro.build.*)
  boot-completed.sh  → settings put, persistent props, override.description (at ACTION_BOOT_COMPLETED)

Magisk:
  service.sh         → immediate property resets + sys.boot_completed polling for post-boot actions
```

**IMPORTANT:** The `settings put` commands REQUIRE a fully booted system. On Magisk, the `resetprop -w sys.boot_completed 0` polling is the only reliable way to ensure this. The original rewrite plan removed this polling, which would have caused `settings put` failures on Magisk.

### 6. Root Manager Detection — Use Environment Variables

```sh
# KernelSU sets KSU=true, APatch also sets KSU=true (compat), Magisk sets MAGISK_VER
if [ "$KSU" = "true" ] && [ -f /data/adb/ksu/bin/busybox ]; then
    BUSYBOX="/data/adb/ksu/bin/busybox"
elif [ "$APATCH" = "true" ] || [ "$KSU" = "true" ] && [ -f /data/adb/ap/bin/busybox ]; then
    BUSYBOX="/data/adb/ap/bin/busybox"
else
    BUSYBOX="/data/adb/magisk/busybox"
fi

# NOTE: APatch sets KSU=true too (compatibility layer), so service.sh's
# `[ "$KSU" != "true" ]` correctly identifies ONLY Magisk (the one platform
# that does NOT set KSU). This is why no separate APATCH check is needed
# in service.sh — APatch behaves like KSU for boot scripts.

# NOTE on device-info.sh root detection (inherited from current module):
# Detection order: SukiSU-Ultra → KernelSU-Next → KernelSU → Magisk → APatch
# The KernelSU-Next check using /data/adb/ksud is inexact (ksud exists on all
# KSU variants). Cosmetic issue only — the display label may show "KernelSU-Next"
# on plain KernelSU if ksud is present.
```

### 7. `module.prop` — Modern Metadata

```
id=Yurikey
name=Yurikey Manager
version=v3.1.0
versionCode=310
author=Yurikey Dev
description=A systemless module to get strong integrity so easily
updateJson=https://raw.githubusercontent.com/Yurii0307/yurikey/main/update.json
actionIcon=icon/action.png          # icon for action button in manager
webuiIcon=icon/webui.png            # icon for WebUI in manager
```

### 8. Dynamic Module Description

KernelSU allows overriding `description` at runtime via `ksud module config`:

```sh
# In boot-completed.sh — show status in the module list
if [ -f "/data/adb/tricky_store/keybox.xml" ]; then
  ksud module config set override.description \
    "✅ Strong Integrity Ready | $(getprop ro.build.version.release)"
else
  ksud module config set override.description \
    "⚠️ Keybox not installed — run action button"
fi
```

### 9. Internationalization (i18n)

The WebUI loads translations from the existing Crowdin-managed `lang/*.json` files. Unlike the current implementation (which busy-waits for translation loading), the new approach uses a simple async helper:

```js
// src/webroot/js/i18n.js — ~50 lines, handles English fallback + HTML translations
let strings = {};

export async function loadI18n(lang) {
  try {
    // English uses source/string.json; all others use lang/{code}.json
    const path = lang === 'en' ? '/lang/source/string.json' : `/lang/${lang}.json`;
    const r = await fetch(`${path}?ts=${Date.now()}`);
    strings = await r.json();
  } catch {
    strings = {};
  }
  // data-i18n on light DOM slot content — preserves child elements (e.g. <strong>)
  document.querySelectorAll('[data-i18n]').forEach(el => {
    const key = el.getAttribute('data-i18n');
    const val = strings[key];
    if (!val) return;
    if (el.children.length > 0 && val.includes('<')) {
      el.innerHTML = val;            // HTML-safe: translation contains markup
    } else if (el.children.length > 0) {
      // Replace only the first text node, leave child elements intact
      const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
      let node;
      while ((node = walker.nextNode())) {
        if (node.nodeValue.trim()) { node.nodeValue = val; break; }
      }
    } else {
      el.textContent = val;          // Plain text
    }
  });
  // data-i18n-label on MWC custom elements with a "label" attribute
  document.querySelectorAll('[data-i18n-label]').forEach(el => {
    const key = el.getAttribute('data-i18n-label');
    if (strings[key]) el.setAttribute('label', strings[key]);
  });
  document.documentElement.lang = lang;
}

export function t(key) { return strings[key] || key; }
```

On DOMContentLoaded, `app.js` calls:
```js
const savedLang = await CFG.get('lang', 'en');
const { loadI18n } = await import('./i18n.js');
await loadI18n(savedLang);
```

**Key improvements over the current code:**
- No busy-waiting `while` loop — translations load asynchronously
- Uses `ksud` + file fallback for language persistence (not localStorage)
- Falls back gracefully to English if translation file is missing
- All 28 existing language files from Crowdin are preserved
- `data-i18n` targets light DOM slot content (not MWC shadow DOM which is unreachable)
- `data-i18n-label` attribute supported for MWC components that use a `label` property (e.g. `md-navigation-tab`)

### 10. `index.html` — MWC Components, No CDN

```html
<!-- src/webroot/index.html -->
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Yurikey Manager</title>
  <link rel="stylesheet" href="css/style.css" />
  <link rel="stylesheet" href="css/fallback.css" media="none" onload="this.media='all'" />
  <!-- MWC load guard: runs BEFORE app.js module, so fallback works even if MWC import fails -->
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
</head>
<body>
  <!-- Top bar -->
  <md-top-app-bar>
    <h1 slot="headline">Yurikey Manager</h1>
    <md-icon-button slot="action" id="refresh-btn" data-script="device-info.sh">
      <md-icon>refresh</md-icon>
    </md-icon-button>
  </md-top-app-bar>

  <!-- Home page -->
  <section id="home-page" class="page active">
    <md-card>
      <div class="card-content">
        <div class="info-row"><span data-i18n="home_version">Version</span><span id="version-text">--</span></div>
        <div class="info-row"><span data-i18n="home_android">Android</span><span id="android-version">--</span></div>
        <div class="info-row"><span data-i18n="home_kernel">Kernel</span><span id="kernel-version">--</span></div>
        <div class="info-row"><span data-i18n="home_root">Root</span><span id="root-type">--</span></div>
        <div class="info-row"><span data-i18n="home_status">Status</span><span id="status-text" class="status-offline">Offline</span></div>
      </div>
    </md-card>

    <md-card>
      <div class="card-content">
        <div class="info-row"><span data-i18n="home_clock_date">Date</span><span id="clock-date">--/--/--</span></div>
        <div class="info-row"><span data-i18n="home_clock_time">Time</span><span id="clock-time">--:--:--</span></div>
      </div>
    </md-card>
  </section>

  <!-- Actions page -->
  <section id="actions-page" class="page">
    <h2 class="md-typescale-title-medium" data-i18n="menu_keybox_header">Keybox</h2>
    <!-- Native fallback <button> is hidden until MWC fails to load -->
    <md-filled-button data-script="keybox.sh">
      <md-icon slot="icon">vpn_key</md-icon>
      <span data-i18n="menu_keybox">Set Up Yuri Keybox</span>
    </md-filled-button>
    <button class="fallback-btn" data-script="keybox.sh" data-i18n="menu_keybox">Set Up Yuri Keybox</button>

    <h2 class="md-typescale-title-medium" data-i18n="menu_gms_header">GMS</h2>
    <md-outlined-button data-script="gms.sh">
      <md-icon slot="icon">cleaning_services</md-icon>
      <span data-i18n="menu_force_clear">Force Stop & Clear Play Store</span>
    </md-outlined-button>
    <button class="fallback-btn" data-script="gms.sh" data-i18n="menu_force_clear">Force Stop & Clear Play Store</button>

    <md-outlined-button data-script="target.sh">
      <md-icon slot="icon">list</md-icon>
      <span data-i18n="menu_target">Set up target.txt</span>
    </md-outlined-button>
    <button class="fallback-btn" data-script="target.sh" data-i18n="menu_target">Set up target.txt</button>

    <md-outlined-button data-script="security_patch.sh">
      <md-icon slot="icon">calendar_month</md-icon>
      <span data-i18n="menu_patch">Set Security Patch</span>
    </md-outlined-button>
    <button class="fallback-btn" data-script="security_patch.sh" data-i18n="menu_patch">Set Security Patch</button>

    <md-outlined-button data-script="boot_hash.sh">
      <md-icon slot="icon">fingerprint</md-icon>
      <span data-i18n="advance_set_verified_boot">Set Verified Boot Hash</span>
    </md-outlined-button>
    <button class="fallback-btn" data-script="boot_hash.sh" data-i18n="advance_set_verified_boot">Set Verified Boot Hash</button>

    <h2 class="md-typescale-title-medium" data-i18n="advance_menu_title_extended">Menu +</h2>
    <md-outlined-button data-script="cleanup.sh">
      <md-icon slot="icon">delete_sweep</md-icon>
      <span data-i18n="advance_clear_all_detection_traces">Clear Detection Traces</span>
    </md-outlined-button>
    <button class="fallback-btn" data-script="cleanup.sh" data-i18n="advance_clear_all_detection_traces">Clear Detection Traces</button>

    <md-outlined-button data-script="pif.sh">
      <md-icon slot="icon">fingerprint</md-icon>
      <span data-i18n="advance_set_pif">Update PIF Fingerprint</span>
    </md-outlined-button>
    <button class="fallback-btn" data-script="pif.sh" data-i18n="advance_set_pif">Update PIF Fingerprint</button>

    <md-outlined-button data-script="hma.sh">
      <md-icon slot="icon">security</md-icon>
      <span data-i18n="advance_set_hma-oss_configs">Set HMA-OSS Config</span>
    </md-outlined-button>
    <button class="fallback-btn" data-script="hma.sh" data-i18n="advance_set_hma-oss_configs">Set HMA-OSS Config</button>

    <md-outlined-button data-script="znctl.sh">
      <md-icon slot="icon">memory</md-icon>
      <span data-i18n="advance_set_zygisk_next_configs">Set Zygisk Next Config</span>
    </md-outlined-button>
    <button class="fallback-btn" data-script="znctl.sh" data-i18n="advance_set_zygisk_next_configs">Set Zygisk Next Config</button>

    <md-outlined-button data-script="widevine.sh">
      <md-icon slot="icon">hd</md-icon>
      <span data-i18n="advance_widevinel1">Fix Widevine L1</span>
    </md-outlined-button>
    <button class="fallback-btn" data-script="widevine.sh" data-i18n="advance_widevinel1">Fix Widevine L1</button>

    <md-outlined-button data-script="rka.sh">
      <md-icon slot="icon">key</md-icon>
      <span data-i18n="advance_upd_yurirka">Update RKA Config</span>
    </md-outlined-button>
    <button class="fallback-btn" data-script="rka.sh" data-i18n="advance_upd_yurirka">Update RKA Config</button>
  </section>

  <!-- Settings page -->
  <section id="settings-page" class="page">
    <h2 class="md-typescale-title-medium" data-i18n="settings_title">Settings</h2>

    <md-outlined-select id="lang-select">
      <md-select-option value="en"><div slot="headline" data-i18n="lang_en">English</div></md-select-option>
      <md-select-option value="ja"><div slot="headline" data-i18n="lang_ja">日本語</div></md-select-option>
      <!-- ... more options with data-i18n on the div inside the slot -->
    </md-outlined-select>

    <md-outlined-select id="theme-select">
      <md-select-option value="dark"><div slot="headline" data-i18n="theme_mode_dark">Dark</div></md-select-option>
      <md-select-option value="light"><div slot="headline" data-i18n="theme_mode_light">Light</div></md-select-option>
      <md-select-option value="auto"><div slot="headline" data-i18n="theme_mode_auto">Auto</div></md-select-option>
    </md-outlined-select>

    <h2 class="md-typescale-title-medium" data-i18n="settings_presets_header">Theme Presets</h2>
    <div class="preset-row">
      <button class="preset-btn" data-preset="ocean" data-i18n="theme_preset_ocean">Ocean</button>
      <button class="preset-btn" data-preset="rose" data-i18n="theme_preset_rose">Rose</button>
      <button class="preset-btn" data-preset="forest" data-i18n="theme_preset_forest">Forest</button>
      <button class="preset-btn" data-preset="sunset" data-i18n="theme_preset_sunset">Sunset</button>
      <button class="preset-btn" data-preset="violet" data-i18n="theme_preset_violet">Violet</button>
    </div>

    <md-outlined-select id="clock-format-select">
      <md-select-option value="auto"><div slot="headline" data-i18n="clock_format_auto">Auto</div></md-select-option>
      <md-select-option value="24h"><div slot="headline" data-i18n="clock_format_24h">24-hour</div></md-select-option>
      <md-select-option value="12h"><div slot="headline" data-i18n="clock_format_12h">12-hour</div></md-select-option>
    </md-outlined-select>

    <h2 class="md-typescale-title-medium" data-i18n="update_title">Update & Support</h2>
    <md-filled-tonal-button data-url="https://github.com/Yurii0307/yurikey">
      <md-icon slot="icon">open_in_new</md-icon>
      <span data-i18n="update_github">View on GitHub</span>
    </md-filled-tonal-button>
    <md-filled-tonal-button data-url="https://t.me/yuriiroot">
      <md-icon slot="icon">telegram</md-icon>
      <span data-i18n="update_telegram">Join Telegram</span>
    </md-filled-tonal-button>

    <h2 class="md-typescale-title-medium" data-i18n="settings_contributors">Contributors</h2>
    <div id="contrib-list"></div>
  </section>

  <!-- Bottom navigation — data-i18n on label attribute works for MWC nav tabs -->
  <md-navigation-bar active-index="0">
    <md-navigation-tab label="Home" data-i18n-label="nav_home"><md-icon slot="active-icon">home</md-icon></md-navigation-tab>
    <md-navigation-tab label="Actions" data-i18n-label="nav_menu"><md-icon slot="active-icon">grid_view</md-icon></md-navigation-tab>
    <md-navigation-tab label="Settings" data-i18n-label="nav_settings"><md-icon slot="active-icon">settings</md-icon></md-navigation-tab>
  </md-navigation-bar>

  <!-- Output dialog -->
  <md-dialog id="output-dialog">
    <div slot="headline" data-i18n="dialog_output_title">Script Output</div>
    <div slot="content"><pre id="output-text"></pre></div>
    <div slot="actions">
      <md-text-button dialog-action="close" data-i18n="dialog_close">Close</md-text-button>
    </div>
  </md-dialog>

  <!-- Bundle -->
  <script src="js/app.js" type="module"></script>
</body>
</html>
```

### 11. `style.css` — Minimal (~100 lines, just CSS vars)

```css
/* src/webroot/css/style.css — theme variables + layout + presets */
:root {
  /* MWC theme tokens — overridden by JS at runtime for each preset */
  --md-sys-color-primary: #0061a4;
  --md-sys-color-surface: #fdfaff;
  --md-sys-color-on-surface: #1a1c1e;
  --md-sys-color-secondary: #535f70;
  --md-sys-color-tertiary: #6b5778;
  --md-sys-color-error: #ba1a1a;
  --md-sys-color-background: #fdfaff;
  --md-sys-color-outline: #73777f;
}

.page { display: none; }
.page.active { display: block; }

.card-content {
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.info-row {
  display: flex;
  justify-content: space-between;
  padding: 4px 0;
}

md-card { margin: 12px; }
md-navigation-bar { position: fixed; bottom: 0; width: 100%; }

/* Native fallback buttons (hidden by default, shown when MWC fails) */
.fallback-btn { display: none; }
.fallback-btn.fallback-visible { display: inline-block; }

/* Theme preset buttons */
.preset-row { display: flex; gap: 8px; flex-wrap: wrap; margin: 12px 0; }
.preset-btn {
  padding: 6px 14px;
  border: 1px solid var(--md-sys-color-outline, #73777f);
  border-radius: 20px;
  background: transparent;
  color: var(--md-sys-color-on-surface, #1a1c1e);
  cursor: pointer;
}
.preset-btn.active {
  background: var(--md-sys-color-primary, #0061a4);
  color: var(--md-sys-color-on-primary, #ffffff);
  border-color: var(--md-sys-color-primary, #0061a4);
}
```

### Theme Presets (5 Color Schemes)

MWC uses CSS custom properties for theming. Unlike the earlier approach (which relied on MWC auto-deriving ~40 tokens from 3 colors), each preset explicitly sets the 7 core tokens to guarantee distinct visual results:

```js
const THEME_PRESETS = {
  ocean: { dark:  { primary:'#9ecaff',  surface:'#111a26', onSurface:'#e1e2e5', secondary:'#8faece', tertiary:'#a5c1e6', error:'#ffb4ab',  background:'#111a26' },
           light: { primary:'#0061a4',  surface:'#fdfaff', onSurface:'#1a1c1e', secondary:'#535f70', tertiary:'#6b5778', error:'#ba1a1a',  background:'#fdfaff' } },
  rose:  { dark:  { primary:'#ffb4a9',  surface:'#221516', onSurface:'#e6e1e1', secondary:'#e6bdad', tertiary:'#f5c3a8', error:'#ffb4ab',  background:'#221516' },
           light: { primary:'#bb1614',  surface:'#fff8f7', onSurface:'#211a1a', secondary:'#77574d', tertiary:'#6e5e32', error:'#ba1a1a',  background:'#fff8f7' } },
  forest:{ dark:  { primary:'#78dc77',  surface:'#132016', onSurface:'#e0e3df', secondary:'#a3c99d', tertiary:'#6dcc96', error:'#ffb4ab',  background:'#132016' },
           light: { primary:'#006e1c',  surface:'#f5fcf4', onSurface:'#1a1c1a', secondary:'#52634d', tertiary:'#3e6756', error:'#ba1a1a',  background:'#f5fcf4' } },
  sunset:{ dark:  { primary:'#ffb870',  surface:'#241911', onSurface:'#e6e0da', secondary:'#e5be93', tertiary:'#e5c28d', error:'#ffb4ab',  background:'#241911' },
           light: { primary:'#8b5000',  surface:'#fff8f4', onSurface:'#1e1b18', secondary:'#745943', tertiary:'#6d5c3b', error:'#ba1a1a',  background:'#fff8f4' } },
  violet:{ dark:  { primary:'#f9abff',  surface:'#1f1626', onSurface:'#e7dde8', secondary:'#ceabd2', tertiary:'#edb3c9', error:'#ffb4ab',  background:'#1f1626' },
           light: { primary:'#9a25ae',  surface:'#fdf7ff', onSurface:'#1d1b1e', secondary:'#6b5870', tertiary:'#815461', error:'#ba1a1a',  background:'#fdf7ff' } },
};

function applyPreset(name, isDark) {
  const mode = isDark ? 'dark' : 'light';
  const colors = THEME_PRESETS[name]?.[mode] || THEME_PRESETS.ocean[mode];
  const root = document.documentElement;
  for (const [key, val] of Object.entries(colors)) {
    root.style.setProperty(`--md-sys-color-${key}`, val);
  }
  MWC auto-derives the remaining ~20 less-visible tokens from these 7 key colors.
}

// In app.js event listener:
const savedPreset = await CFG.get('theme_preset', 'ocean');
applyPreset(savedPreset, document.documentElement.getAttribute('data-theme-mode') !== 'light');
document.querySelectorAll('.preset-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    CFG.set('theme_preset', btn.dataset.preset);
    applyPreset(btn.dataset.preset, ...);
  });
});
```

---

## Execution Flow

```
Action button
  → action.sh
    → detects if sourced (Magisk) or subprocess (KSU) via "${0##*/}"
    → MODDIR=${0%/*}; . "$MODDIR/lib/common.sh"
    → sh "$MODDIR/orchestrator.sh" full_integrity
      → reads pipelines/full_integrity
      → sh features/gms.sh
      → sh features/target.sh
      → sh features/security_patch.sh
      → sh features/boot_hash.sh
      → sh features/keybox.sh
      → sh features/pif.sh?          (? = optional, skips if file missing with warning)

WebUI button
  → bridge detection (tries kernelsu npm → window.ksu → YuriKeyHost → execYurikeyScript)
  → reads module_paths.json → MODULE.MODDIR
  → const { stdout, stderr } = await exec(`sh '${path}'`)
  → output saved to script_history.log (persistent ring buffer)
  → features/keybox.sh             (same script, same contract)

Boot (KernelSU):
  → service.sh (late_start service, non-blocking)
    → check_prop() for ro.boot.*, ro.build.*, ro.debuggable, etc.
  → boot-completed.sh (at ACTION_BOOT_COMPLETED)
    → settings put, persistent props, cfg_set for override.description

Boot (Magisk):
  → service.sh (late_start service)
    → check_prop() for ro.boot.*, ro.build.* (same as KSU)
    → polls sys.boot_completed (resetprop -w) for post-boot actions
    → settings put, persistent props (done inline in service.sh)
```

---

## Contracts & Patterns

### `return` vs `exit` — The Boundary Rule (With Context Detection)

| Context | Execution Method | Use |
|---|---|---|
| Feature scripts (`features/*.sh`) | `sh features/foo.sh` (subprocess) | **`exit`** |
| Orchestrator (`orchestrator.sh`) | `sh orchestrator.sh` (subprocess) | **`exit`** |
| Library scripts (`lib/*.sh`) | Sourced via `. lib/common.sh` | **Never call `exit` or `return` at top level** |
| `customize.sh` | Sourced by installer | **`return`** |
| `service.sh` | Subprocess (Magisk/KSU runs it) | **`exit`** |
| `boot-completed.sh` | Subprocess (KSU runs it) | **`exit`** |
| `uninstall.sh` | Sourced by installer | **`return`** |
| `action.sh` | KSU: subprocess. Magisk: sourced. | **Use `exit` + context detection** (see below) |

**Critical fix for `action.sh`:** The original rewrite plan used `return` for `action.sh` claiming it's "safe in both" subprocess and sourced contexts. In `/system/bin/sh` on Android, `return` at top level outside a function is **undefined behavior** — some shells treat it as `exit`, others silently continue, others error. The fix is to **detect the context**:

```sh
#!/system/bin/sh
# action.sh — detects whether sourced or subprocess
MODDIR=${0%/*}
. "$MODDIR/lib/common.sh"

# Run the pipeline
sh "$MODDIR/orchestrator.sh" full_integrity
RC=$?

# If we were sourced (Magisk), return. If subprocess (KSU), exit.
[ "${0##*/}" = "action.sh" ] && exit $RC || return $RC
```

The detection `"${0##*/}" = "action.sh"` works because:
- When **sourced** (Magisk): `$0` is the caller's name (installer or manager script), NOT `action.sh`
- When **run as subprocess** (KSU): `$0` is `action.sh`

### Every Script Follows Path Contracts

All scripts use `MODDIR=${0%/*}` to locate themselves. The path to `lib/` is relative to each script's location:

| Script location | `$MODDIR` resolves to | Path to `lib/common.sh` |
|---|---|---|
| `features/keybox.sh` | `.../Yurikey/features` | `"$MODDIR/../lib/common.sh"` |
| `orchestrator.sh` | `.../Yurikey` | `"$MODDIR/lib/common.sh"` |
| `service.sh` | `.../Yurikey` | `"$MODDIR/lib/common.sh"` |
| `boot-completed.sh` | `.../Yurikey` | `"$MODDIR/lib/common.sh"` |
| `action.sh` | `.../Yurikey` | `"$MODDIR/lib/common.sh"` |
| `customize.sh` | **N/A — sourced by installer** | Use `$MODPATH` (provided by installer) |
| `uninstall.sh` | `.../Yurikey` | `"$MODDIR/lib/common.sh"` |
| `webroot/common/device-info.sh` | `.../Yurikey/webroot/common` | Sources `"$MODDIR/../../lib/common.sh"` |

### Feature Script Contract

```sh
#!/system/bin/sh
MODDIR=${0%/*}               # resolves to .../Yurikey/features
. "$MODDIR/../lib/common.sh" # go up one level to module root, then into lib/
. "$MODDIR/../lib/paths.sh"

log "FEATURE" "Start"
# ... one responsibility, idempotent, check prerequisites first ...
log "FEATURE" "Finish"
```

- Exits `0` on success, `1` on failure
- All output via `log()`
- **Idempotent** — safe to run multiple times
- **Checks prerequisites** — if a required module is missing, `exit 0` (skip gracefully)

### Root-Level Script Contract (orchestrator.sh, service.sh, boot-completed.sh, action.sh)

```sh
#!/system/bin/sh
MODDIR=${0%/*}               # resolves to .../Yurikey/
. "$MODDIR/lib/common.sh"    # lib/ is directly under module root
. "$MODDIR/lib/paths.sh"
```

### Installer Script Contract (customize.sh, uninstall.sh)

```sh
# customize.sh — sourced by installer, MODPATH is provided by environment
# MODPATH = /data/adb/modules/Yurikey (the target install directory)
. "$MODPATH/lib/common.sh"

# uninstall.sh — sourced by uninstaller, MODDIR works here
MODDIR=${0%/*}
. "$MODDIR/lib/common.sh"
```

### Orchestrator With Conditional Execution

```sh
#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/lib/common.sh"

PIPELINE="$1"
PIPELINE_FILE="$MODDIR/pipelines/$PIPELINE"

[ -z "$PIPELINE" ] && die "No pipeline specified"
[ ! -f "$PIPELINE_FILE" ] && die "Pipeline not found: $PIPELINE"

while IFS= read -r line; do
    [ -z "$line" ] && continue
    [ "${line#\#}" != "$line" ] && continue

    feature="$line"
    optional=false
    [ "${feature%\?}" != "$feature" ] && optional=true && feature="${feature%\?}"

    FEATURE_PATH="$MODDIR/features/$feature"
    if [ "$optional" = "true" ] && [ ! -f "$FEATURE_PATH" ]; then
        log "ORCH" "Warning: Optional feature '$feature' not found — skipping"
        continue
    fi

    log "ORCH" "Running: $feature"
    if ! sh "$FEATURE_PATH"; then
        die "Pipeline aborted: $feature failed"
    fi
done < "$PIPELINE_FILE"
```

### Pipeline Definitions

**`pipelines/full_integrity`**:
```
gms.sh
target.sh
security_patch.sh
boot_hash.sh
keybox.sh
pif.sh?
```

**`pipelines/root_hide`**:
```
hma.sh
znctl.sh?
```

### `service.sh` — Immediate Boot Props

```sh
#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/lib/common.sh"

log "SERVICE" "Setting boot properties"

# Bootloader / verified boot
check_prop "ro.boot.vbmeta.device_state" "locked"
check_prop "ro.boot.verifiedbootstate"   "green"
check_prop "ro.boot.flash.locked"        "1"
check_prop "ro.boot.veritymode"          "enforcing"
check_prop "ro.boot.warranty_bit"        "0"

# Build type
check_prop "ro.build.type"    "user"
check_prop "ro.build.tags"    "release-keys"
check_prop "ro.debuggable"    "0"
check_prop "ro.secure"        "1"

# Vendor properties
check_prop "vendor.boot.verifiedbootstate"   "green"
check_prop "vendor.boot.vbmeta.device_state" "locked"

# OEM unlock
check_prop "ro.oem_unlock_supported" "0"
check_prop "sys.oem_unlock_allowed"  "0"

# OEM-specific
check_prop "ro.boot.realme.lockstate"  "1"
check_prop "ro.secureboot.lockstate"   "locked"

# Boot mode
contains_check_prop "ro.boot.bootmode"    "recovery" "unknown"
contains_check_prop "vendor.boot.bootmode" "recovery" "unknown"

# ADB / USB
check_prop "persist.sys.usb.config" "none"
check_prop "service.adb.root"       "0"
check_prop "ro.adb.secure"          "1"

# Encryption
check_prop "ro.crypto.state" "encrypted"

log "SERVICE" "Done"
```

### `boot-completed.sh` — Post-Boot Actions (KernelSU Only)

`boot-completed.sh` is **KernelSU-specific** — Magisk does not support this script. On Magisk, `service.sh` handles the same operations **after polling** `sys.boot_completed` (see Section 5). The script MUST guard at the top so it's a no-op on other platforms:

```sh
# src/boot-completed.sh — KernelSU only: runs EXACTLY at boot completed
#!/system/bin/sh
MODDIR=${0%/*}
# Guard: KernelSU-only — Magisk/APatch don't run this, but be explicit
[ "$KSU" != "true" ] && exit 0

. "$MODDIR/lib/common.sh"
. "$MODDIR/lib/config_env.sh"

log "BOOT" "Boot completed — finalizing"

settings put global development_settings_enabled 0
settings put global adb_enabled 0
settings put global oem_unlock_allowed 0

resetprop --delete persist.service.adb.enable
resetprop --delete persist.service.debuggable
resetprop persist.sys.developer_options 0
resetprop persist.sys.dev_mode 0

# Dynamic module description — uses cfg_set for cross-platform compat
if [ -f "$TRICKY_DIR/keybox.xml" ]; then
  cfg_set "override.description" "✅ Active | $(getprop ro.build.version.release)"
else
  cfg_set "override.description" "⚠️ Run action button to set up keybox"
fi

log "BOOT" "Done"
```

### `customize.sh` — Installer

`customize.sh` is **sourced by the installer**, so `${0%/*}` does NOT point to the module directory. Use `$MODPATH` (provided by the installer environment):

```sh
#!/system/bin/sh
# customize.sh — SOURCED by installer. MODPATH is provided.
# NOT using MODDIR=${0%/*} because $0 is the installer script, not this file.

. "$MODPATH/lib/common.sh"
. "$MODPATH/lib/urls.sh"

ui_print "- Installing keybox..."
download "$KEYBOX_URL" | base64 -d > "/data/adb/tricky_store/keybox.xml" \
  || { ui_print "Error: Keybox install failed"; return 1; }

# Write module_paths.json for WebUI path discovery
# This eliminates the hardcoded /data/adb/modules/Yurikey in JS
mkdir -p "$MODPATH/webroot/json"
cat > "$MODPATH/webroot/json/module_paths.json" <<JSON
{"MODDIR": "$MODPATH"}
JSON

# Bootstrap device info
sh "$MODPATH/webroot/common/device-info.sh"

# Run one-time migration if upgrading from old module structure
# migrate.sh cleans up old Module/Yuri/ dir, converts old state files
if [ -f "$MODPATH/features/migrate.sh" ]; then
  sh "$MODPATH/features/migrate.sh" || ui_print "- Warning: migration incomplete"
fi

# Download sqlite3 for RKA at install time (arch-specific, not bundled)
# Use installer-provided $ARCH (Magisk/KSU/APatch set this) with ABI name mapping
# URL from lib/urls.sh: $SQLITE_BASE_URL
ui_print "- Installing RKA sqlite3..."
case "$ARCH" in
  arm64) RKA_ARCH="arm64-v8a" ;;
  arm)   RKA_ARCH="armeabi-v7a" ;;
  x64)   RKA_ARCH="x86_64" ;;
  x86)   RKA_ARCH="x86" ;;
  *)     RKA_ARCH="arm64-v8a" ;;
esac
mkdir -p "$MODPATH/rka/$RKA_ARCH"
download "$SQLITE_BASE_URL/${RKA_ARCH}/sqlite3" > "$MODPATH/rka/$RKA_ARCH/sqlite3" 2>/dev/null && chmod 755 "$MODPATH/rka/$RKA_ARCH/sqlite3" \
  || ui_print "- Warning: RKA sqlite3 download failed (non-fatal)"
```

**Why `module_paths.json`?** The WebUI runs in a WebView context where shell variables (`$MODDIR`) don't exist. Previously, the JS hardcoded `/data/adb/modules/Yurikey/`. Now it reads `module_paths.json` at boot and discovers its own path dynamically — surviving module ID renames.

**Why on-demand sqlite3?** The old module bundled ~3MB of sqlite3 binaries for 5 architectures. Now only the current device's binary is downloaded at install time, ~700KB max. This reduces module ZIP size from >5MB to ~1.5MB.

### Shell Injection Protection (Inlined in app.js)

```js
// URL opening in app.js — uses exec() with injection protection
function openUrl(url) {
  if (!url?.startsWith('https://') && !url?.startsWith('http://')) return;
  exec(`am start -a android.intent.action.VIEW -d '${url.replace(/'/g, "'\\''")}'`);
}
```

The key protections:
1. Only `https://` and `http://` URLs allowed (scheme whitelist)
2. Single quotes in the URL are escaped for shell safety
3. No `\n` or `\r` needed since `am start` handles URL encoding

### HMA Config Permissions

```sh
chmod 600 "$HMA_FILE"
HMA_UID=$(stat -c "%u" "/data/user/0/org.frknkrc44.hma_oss" 2>/dev/null)
[ -n "$HMA_UID" ] && chown "$HMA_UID:$HMA_UID" "$HMA_FILE"
```

### `app.js` — Single Entry Point (With Bridge Detection, Path Discovery, History, Config)

```js
// src/webroot/js/app.js — complete app with bridge detection + path discovery + config
// Import only the MWC components used — not @material/web/all.js
import '@material/web/button/filled-button.js';
import '@material/web/button/filled-tonal-button.js';
import '@material/web/button/outlined-button.js';
import '@material/web/button/text-button.js';
import '@material/web/icon/icon.js';
import '@material/web/dialog/dialog.js';
import '@material/web/navigationbar/navigation-bar.js';
import '@material/web/navigationtab/navigation-tab.js';
import '@material/web/select/outlined-select.js';
import '@material/web/select/select-option.js';
import '@material/web/progress/linear-progress.js';
import '@material/web/topappbar/top-app-bar.js';
import '@material/web/iconbutton/icon-button.js';

// 0. BRIDGE DETECTION — 4-tier fallback: kernelsu → window.ksu → YuriKeyHost → execYurikeyScript
// Works on KernelSU (native ksu), APatch (identical ksu), and Magisk (via MMRL's YuriKeyHost)
async function getBridge() {
  try { const ksu = await import('kernelsu'); return { exec: ksu.exec, toast: ksu.toast }; } catch {}
  if (typeof window.ksu?.exec === 'function') {
    return {
      exec: (cmd) => new Promise((res, rej) => window.ksu.exec(cmd, '{}', (e, o, s) => e ? rej({e, s}) : res({stdout:o, stderr:s}))),
      toast: (msg) => window.ksu.toast?.(msg),
    };
  }
  if (typeof window.YuriKeyHost?.execScript === 'function') {
    return {
      exec: (cmd) => new Promise((res) => Promise.resolve(window.YuriKeyHost.execScript(cmd, '')).then(o => res({stdout:o})).catch(() => res({stdout:''}))),
      toast: () => {},
    };
  }
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

// MWC load guard runs from inline <script> in <head> (before this module loads)
// If this code executes, MWC loaded successfully — mark it
document.getElementById('mwc-loaded')?.remove();

// 1. MODULE PATH DISCOVERY — no hardcoded module paths
const MODULE = await (async () => {
  try { const r = await fetch('/json/module_paths.json?ts=' + Date.now()); return await r.json(); }
  catch { const m = (document.currentScript?.src || '').match(/^(file:\/\/\/data\/adb\/modules\/[^/]+)/); return m ? { MODDIR: m[1] } : null; }
})();
if (!MODULE) throw new Error('Cannot determine module path');

// 2. CONFIG PERSISTENCE — ksud with flat-file fallback
const CFG = {
  async get(key, def) { const {stdout} = await exec(`ksud module config get "${key}" 2>/dev/null || cat "${MODULE.MODDIR}/config/${key}.val" 2>/dev/null`); return stdout.trim() || def; },
  async set(key, val) { await exec(`ksud module config set "${key}" "${val}" 2>/dev/null || mkdir -p "${MODULE.MODDIR}/config" && printf '%s' "${val}" > "${MODULE.MODDIR}/config/${key}.val"`); },
  async delete(key) { await exec(`ksud module config delete "${key}" 2>/dev/null || rm -f "${MODULE.MODDIR}/config/${key}.val" 2>/dev/null`); },
};

// Migrate legacy localStorage settings (one-time)
(async () => {
  try {
    if (localStorage.getItem('_cfg_migrated')) return;
    for (const [o, n] of Object.entries({ selectedLanguage: 'lang', themeMode: 'theme', clockFormat: 'clock_format' })) {
      const v = localStorage.getItem(o); if (v) await CFG.set(n, v);
    }
    localStorage.setItem('_cfg_migrated', '1');
  } catch {}
})();

// 3. SCRIPT HISTORY — persistent ring buffer in a log file
// Uses printf via shell script block — safe from shell escaping bugs
const HISTORY = `${MODULE.MODDIR}/script_history.log`;
async function addHistory(script, output) {
  if (!output?.trim()) return;
  const ts = new Date().toISOString();
  const entry = `=== ${ts} [${script}] ===
${output}`;
  const tmp = `${HISTORY}.tmp`;
  await exec(
    `printf '%s\n' '${entry.replace(/'/g, "'\\''")}' > "${tmp}" && ` +
    `head -240 "${HISTORY}" 2>/dev/null >> "${tmp}" && mv "${tmp}" "${HISTORY}"`
  );
}

document.addEventListener('DOMContentLoaded', async () => {
  // Version
  const { stdout: ver } = await exec(`grep '^version=' "${MODULE.MODDIR}/module.prop" | cut -d'=' -f2`);
  document.getElementById('version-text').textContent = ver.trim();

  // Feature buttons with output capture
  document.querySelectorAll('[data-script]').forEach(btn => {
    btn.addEventListener('click', async () => {
      btn.disabled = true;
      const path = `${MODULE.MODDIR}/features/${btn.dataset.script}`;
      try {
        const { errno, stdout, stderr } = await exec(`sh '${path}'`);
        await addHistory(btn.dataset.script, stdout + stderr);
        errno === 0 ? toast('✅ Done') : toast('❌ Failed', 4000);
      } catch (e) {
        await addHistory(btn.dataset.script, e.message);
        toast('❌ Error: ' + e.message);
      } finally { btn.disabled = false; }
    });
  });

  // History button
  document.getElementById('history-btn')?.addEventListener('click', async () => {
    const { stdout } = await exec(`cat "${HISTORY}" 2>/dev/null || echo '(no history)'`);
    document.getElementById('output-text').textContent = stdout;
    document.getElementById('output-dialog')?.show();
  });

  // URL buttons (injection-safe)
  document.querySelectorAll('[data-url]').forEach(btn => {
    btn.addEventListener('click', () => {
      const url = btn.dataset.url;
      if (url && (url.startsWith('https://') || url.startsWith('http://'))) {
        exec(`am start -a android.intent.action.VIEW -d '${url.replace(/'/g, "'\\''")}'`);
      }
    });
  });

  // Settings via CFG (works on all root managers)
  const langSel = document.getElementById('lang-select');
  if (langSel) {
    langSel.value = await CFG.get('lang', 'en');
    langSel.addEventListener('change', () => CFG.set('lang', langSel.value));
  }
  const themeSel = document.getElementById('theme-select');
  if (themeSel) {
    themeSel.value = await CFG.get('theme', 'dark');
    themeSel.addEventListener('change', () => CFG.set('theme', themeSel.value));
  }

  // Navigation
  const tabs = document.querySelectorAll('md-navigation-tab');
  const pages = document.querySelectorAll('.page');
  tabs.forEach((tab, i) => tab.addEventListener('click', () => {
    pages.forEach(p => p.classList.remove('active'));
    pages[i]?.classList.add('active');
  }));

  // Clock
  function updateClock() {
    const n = new Date();
    document.getElementById('clock-date').textContent = n.toLocaleDateString();
    document.getElementById('clock-time').textContent = n.toLocaleTimeString();
  }
  updateClock(); setInterval(updateClock, 1000);

  // Refresh device info
  document.getElementById('refresh-btn')?.addEventListener('click', async () => {
    await exec(`sh '${MODULE.MODDIR}/webroot/common/device-info.sh'`);
    const r = await fetch('/json/device-info.json?ts=' + Date.now());
    const d = await r.json();
    document.getElementById('android-version').textContent = d.android || '-';
    document.getElementById('kernel-version').textContent = d.kernel || '-';
    document.getElementById('root-type').textContent = d.root || '-';
  });
});
```

**Changes from original rewrite:**
1. Reads `module_paths.json` instead of hardcoding `/data/adb/modules/Yurikey/` (fixes path brittleness)
2. Adds script output history persisted to a log file, viewable via history button (fixes regression)
3. Settings use `CFG.get/CFG.set` with `ksud` + file fallback (works on Magisk/APatch, not just KSU)
4. URL opening uses `exec('am start')` with injection protection (fixes security issue)

---

## Build Process

```sh
# One command
npm ci
npm run build
```

`npm run build` runs:
1. `parcel build src/webroot/index.html` → bundles MWC + Lit into `Module/webroot/` (kernelsu is an optional dependency — if unavailable at build time, the bridge detection in app.js gracefully falls through to the raw `window.ksu` or `YuriKeyHost` bridges at runtime)
2. Shell scripts copied from `src/` to `Module/`

---

## CI Pipeline (`.github/workflows/`)

### `build-test.yml`
```yaml
- name: Lint shell scripts
  run: find src/ -name '*.sh' -exec shellcheck {} +

- name: Build
  run: npm ci && npm run build

- name: Verify module structure
  run: test -f Module/module.prop && test -f Module/webroot/index.html
```

### `build-release.yml`
Same as current but adds `npm ci && npm run build` before zipping.

---

## What This Fixes vs Current Code

| Current Problem | Solution |
|---|---|---|
| `ksu.exec` callback hacks | **Cross-platform bridge detection** — 4-tier fallback: `kernelsu` npm → `window.ksu` → `YuriKeyHost` → `execYurikeyScript`. Works on KSU, APatch, and Magisk+MMRL |
| `kernelsu` npm as required dep (KSU-only lock-in) | Moved to `optionalDependencies` — app works without it via raw bridge fallbacks |
| `localStorage` lost on app uninstall | `config_env.sh` — `ksud` + file fallback (works on all root managers) |
| Settings don't persist on Magisk | `cfg_get/cfg_set` with flat-file fallback when `ksud` unavailable |
| No `cfg_delete()` for config cleanup | Added `cfg_delete()` to both `config_env.sh` and WebUI `CFG.delete()` |
| i18n busy-wait + failed on MWC shadow DOM | Async i18n + `data-i18n` on slot content + `data-i18n-label` for MWC `label` attrs |
| Theme presets dropped in rewrite | 5 presets restored via MWC CSS custom properties |
| MWC `all.js` imported (60+ unused components) | Only needed 13 MWC modules imported |
| `kernelsu` version loose (`^3.0.2`) | Pinned to exact `3.0.2` |
| `config.json` git-rm'd (broke HMA download) | Kept tracked — download source, not bundled in ZIP |
| `shellcheck` used broken `**/*.sh` glob | Fixed to `find ... -exec shellcheck +` |
| No MWC failure fallback | MWC load guard + native `fallback-btn` elements |
| No config migration from localStorage | CFG migration on first WebUI load |
| sqlite3 URL hardcoded in customize.sh | `SQLITE_BASE_URL` in `lib/urls.sh` — single source |
| sqlite3 arch via `getprop` (redundant with installer `$ARCH`) | Uses installer `$ARCH` with ABI mapping (`arm64`→`arm64-v8a`, `arm`→`armeabi-v7a`, etc.) |
| `sort -V` in znctl.sh (BusyBox unsupported) | Replaced with `awk`-based version comparison |
| `boot-completed.sh` has no platform guard | Added `[ "$KSU" != "true" ] && exit 0` — safe no-op on non-KSU |
| `resetprop -w sys.boot_completed` polling removed (breaks Magisk) | **Restored** in Magisk-only code path of `service.sh` |
| Beer CSS CDN (offline = unstyled) | MWC bundled locally by Parcel |
| 610 lines CSS with `!important` hacks | ~100 lines CSS, just MWC theme vars |
| 12 separate `<script>` tags (slow) | 1 bundled `<script>` (fast) |
| `color-mix()` unsupported on Android 12/13 | MWC uses standard CSS — no compat issues |
| `update-binary` dead code (184 lines) | Kept for recovery compatibility; Magisk/KSU use built-in `#MAGISK` handler |
| 228K unreferenced assets | Removed |
| `return` vs `exit` inconsistency | Context detection: `"${0##*/}"` check |
| `action.sh` uses `return` (undefined behavior) | Context detection → `exit` or `return` based on `$0` |
| `download()` triplicated | `lib/common.sh` |
| `log_message` copy-pasted 10x | `lib/common.sh` |
| `boot_hash.sh` duplicated | Single file in `features/` |
| Two execution paths | Single `orchestrator.sh` |
| Hardcoded paths in shell scripts | `$MODDIR` everywhere |
| Hardcoded module path in WebUI JS | `module_paths.json` — dynamic path discovery |
| Shell injection in `redirect.js` | `sanitizeUrl()` + `exec()` |
| `chmod 777` on HMA config | `chmod 600` + dynamic UID |
| `znctl.sh` 3 bugs (undefined var, typo, mkdir on file) | Fixed in `features/znctl.sh` |
| No linting in CI | ShellCheck in CI |
| sqlite3 binaries get 0644 perms (3MB for 5 archs) | On-demand download at install time (~700KB) |
| No dynamic module status | `cfg_set` for `override.description` |
| `YurikeyDev` vs `Yurii0307` URL mismatch | `lib/urls.sh` — single source of truth |
| Material Design not implemented at all | Google's official Material 3 Web Components |
| WebUI only worked on KernelSU (single backend) | MWC failover + 3-way exec fallback (kernelsu→YuriKeyHost→ksu.exec) for Magisk/APatch compat |
| No theme presets in rewritten plan | 5 theme presets (ocean, rose, forest, sunset, violet) via MWC CSS vars |
| No script output history in WebUI | `script_history.log` — persistent file-based ring buffer |
| `config.json` (512KB) bloats module ZIP | Kept in repo as download source for `hma.sh`; not bundled into `Module/` ZIP |
| No migration path for existing users | `migrate.sh` — converts old state to new structure |
| `key` and `attestation` in git history | `git rm --cached` — removed from tracking |

---

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────┐
│                     Module Root                           │
├──────────────────────────────────────────────────────────┤
│                                                            │
│  ┌──────────┐   ┌──────────┐   ┌──────────────────────┐   │
│  │ customize │   │ service  │   │   boot-completed     │   │
│  │   .sh     │   │   .sh    │   │   (KernelSU only)    │   │
│  │ writes    │   │ + Magisk │   └──────────┬───────────┘   │
│  │ module_   │   │ fallback │    boot done (KSU) /         │
│  │ paths.json│   └────┬─────┘    inline in service (Mgk)  │
│  └────┬──────┘        │ boot                               │
│       │ install       ▼                                    │
│       ▼           ┌──────────────────────────────────┐     │
│  ┌─────────────────┤           lib/                    │     │
│  │  ┌────────────┐ ├┐ ┌──────────┐ ┌────────────────┐ ││    │
│  │  │ migrate.sh │ ││ │ paths.sh │ │   urls.sh      │ ││    │
│  │  └────────────┘ ││ │(no hard- │ │(single source  │ ││    │
│  │                 ││ │ coded    │ │ of truth for   │ ││    │
│  │                 ││ │ path)    │ │ all URLs)      │ ││    │
│  │                 ││ └──────────┘ └────────────────┘ ││    │
│  │                 ││ ┌──────────────────────────────┐││    │
│  │                 ││ │       common.sh              │││    │
│  │                 ││ │ log, download, die,          │││    │
│  │                 ││ │ check_prop, contains_check   │││    │
│  │                 ││ └──────────────────────────────┘││    │
│  │                 ││ ┌──────────────────────────────┐││    │
│  │                 ││ │    config_env.sh             │││    │
│  │                 ││ │ cfg_get/cfg_set              │││    │
│  │                 ││ │ (ksud + flat-file fallback)  │││    │
│  │                 ││ └──────────────────────────────┘││    │
│  │                 ││ ┌──────────────────────────────┐││    │
│  │                 ││ │     package_list.sh          │││    │
│  │                 ││ └──────────────────────────────┘││    │
│  │                 └──────────────────────────────────┘     │
│  │                                                            │
│  │  ┌──────────────┐     ┌─────────────────────────────┐     │
│  │  │ orchestrator │────→│     pipelines/               │     │
│  │  │    .sh       │     │  full_integrity              │     │
│  │  └──────┬───────┘     │  root_hide                   │     │
│  │         │             └─────────────────────────────┘     │
│  │         ▼                                                  │
│  │  ┌──────────────────────────────────────────────────┐     │
│  │  │               features/                           │     │
│  │  │  keybox  target  security_patch  boot_hash        │     │
│  │  │  pif  hma  znctl  rka  cleanup  gms  kill_all     │     │
│  │  │  widevine  lsposed  migrate                       │     │
│  │  └──────────────────────────────────────────────────┘     │
│  │                                                            │
│  │  ┌──────────────────────────────────────────────────┐     │
│  │  │              webroot/ (Parcel-bundled)             │     │
│  │  │  index.html → MWC + Lit + kernelsu                │     │
│  │  │  style.css (~100 lines, theme vars only)           │     │
│  │  │  app.js (~200 lines: path discovery, history,      │     │
│  │  │          config persistence, i18n, refresh)        │     │
│  │  │  i18n.js (~40 lines, async translation loader)     │     │
│  │  │  lang/ (28 languages via Crowdin)                  │     │
│  │  │  json/ (module_paths.json, dev.json, device-info)  │     │
│  │  └──────────────────────────────────────────────────┘     │
│  │                                                            │
│  │  ┌──────────────────────────────────────────────────┐     │
│  │  │   rka/ (jsonarray.sh + lspmcfg.sh)                │     │
│  │  │   sqlite3 downloaded at install time for current   │     │
│  │  │   arch only (not bundled — saves ~3MB)             │     │
│  │  └──────────────────────────────────────────────────┘     │
│  │                                                            │
│  │  script_history.log  (auto-created, persistent)            │
│  │  config/*.val        (auto-created, ksud fallback)         │
│  └──────────────────────────────────────────────────────────┘
```

**File count summary:**
- `lib/` — 5 files (paths, urls, common, config_env, package_list)
- `features/` — 14 files (keybox, target, security_patch, boot_hash, pif, hma, znctl, rka, cleanup, gms, kill_all, widevine, lsposed, migrate)
- `webroot/` — index.html, style.css, app.js, i18n.js, config.json + lang/*.json + json/*.json
- Boot layer — customize.sh, service.sh, boot-completed.sh, uninstall.sh, action.sh, orchestrator.sh
- Total new code: ~1700 lines across ~35 files
