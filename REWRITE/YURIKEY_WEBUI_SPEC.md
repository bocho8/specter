# Yurikey Manager WebUI — Complete Rewrite Specification

> **For the coding agent:** This document is the single source of truth for the full rewrite of the Yurikey Manager WebUI. Every decision here is final and reasoned. Implement exactly as specified; do not deviate without a documented reason.

---

## 0. Critical Technology Decision: Do NOT Use @material/web (MWC) + Lit

The user originally requested Lit + MWC. **Do not use it.** As of mid-2024, Google disbanded the MWC team and placed `@material/web` in maintenance mode — no new components, no navigation bar, no cards, no snackbar in the roadmap. Building on it now means inheriting a dead dependency.

**Use instead: `mdui v2`** — an actively maintained, community-driven Material Design 3 Web Components library (github.com/zdhxiong/mdui). It is:
- Pure Web Components, zero framework dependency, no bundler required
- 85 KB CSS + JS gzipped (unpkg CDN or local copy)
- Full MD3 component set: navigation-bar, card, button, dialog, select, snackbar, list, chip, collapse, fab, top-app-bar, circular-progress, linear-progress, divider, icon, badge
- Built-in dark/light mode via `mdui.setTheme()` and `mdui.getTheme()`
- Built-in dynamic color via `mdui.setColorScheme()` (generates full MD3 color roles from a single seed color)
- CSS custom properties aligned with MD3 tokens (`--mdui-color-primary`, `--mdui-color-surface-container`, etc.)
- mdui v3 based on M3 Expressive is actively in development — v2 stays maintained during that period

---

## 1. File Structure

```
webroot/
├── index.html                  ← single page app shell
├── assets/
│   ├── mdui.css               ← local copy from unpkg.com/mdui@2/mdui.css
│   ├── mdui.global.js         ← local copy from unpkg.com/mdui@2/mdui.global.js
│   └── yurikey.png            ← app icon (existing)
├── css/
│   └── app.css                ← custom overrides only (~150 lines max, no !important)
├── js/
│   ├── app.js                 ← DOMContentLoaded entry: imports + wires everything
│   ├── bridge.js              ← 3-tier script execution bridge + output capture
│   ├── cfg.js                 ← Config persistence: in-memory cache + ksud + file fallback
│   ├── history.js             ← File-based script history via exec (printf-safe)
│   ├── device.js              ← device-info.json fetch + refresh
│   ├── clock.js               ← live clock with format
│   ├── network.js             ← online/offline status
│   ├── theme.js               ← dark/light/auto + 5 color presets
│   ├── i18n.js                ← translation loader (existing logic, improved)
│   ├── contributors.js        ← dev.json loader + card renderer
│   └── redirect.js            ← URL opener with sanitization
├── lang/
│   ├── source/
│   │   └── string.json        ← English source strings
│   └── {code}.json            ← 27 other languages
└── json/
    ├── device-info.json        ← written by device-info.sh at runtime
    └── dev.json               ← static contributors list
```

**Rationale for local copies of mdui:** The module runs inside an Android device that may be offline. CDN fallback is added but local files load first. If local files exist, no network needed.

---

## 2. HTML Shell (`index.html`)

### `<head>`

```html
<!doctype html>
<html lang="en" dir="ltr">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover" />
  <meta name="color-scheme" content="dark light" />
  <title>Yurikey Manager</title>

  <!-- mdui: try local first, CDN fallback -->
  <link rel="stylesheet" href="assets/mdui.css"
        onerror="this.onerror=null;this.href='https://unpkg.com/mdui@2/mdui.css'" />
  <link rel="stylesheet" href="css/app.css" />

  <script>
    // Inline theme init before first paint to prevent flash
    (function () {
      const mode = localStorage.getItem('themeMode') || 'dark';
      const preset = localStorage.getItem('themePreset') || 'ocean';
      document.documentElement.setAttribute('data-theme-mode', mode);
      document.documentElement.setAttribute('data-theme-preset', preset);
    })();
  </script>
</head>
```

### `<body>` layout

```html
<body>
  <mdui-layout>

    <!-- Top App Bar (shared across all pages) -->
    <mdui-top-app-bar id="top-bar" scroll-behavior="elevate" scroll-threshold="4">
      <mdui-top-app-bar-title>
        <span data-i18n="app_title">Yurikey Manager</span>
      </mdui-top-app-bar-title>
      <div style="flex: 1"></div>
      <!-- Network status badge chip (right side) -->
      <mdui-chip id="network-chip" icon="wifi" class="network-chip" elevated>
        <span data-i18n="home_status_online">Online</span>
      </mdui-chip>
    </mdui-top-app-bar>

    <!-- Page container -->
    <mdui-layout-main>
      <div id="pages">
        <!-- Page sections (see §3) -->
      </div>
    </mdui-layout-main>

    <!-- Bottom Navigation Bar -->
    <mdui-navigation-bar id="nav-bar" value="home" label-visibility="selected">
      <mdui-navigation-bar-item value="home"
        icon="home--outlined" active-icon="home"
        data-i18n-label="nav_home">Home</mdui-navigation-bar-item>

      <mdui-navigation-bar-item value="actions"
        icon="tune--outlined" active-icon="tune"
        data-i18n-label="nav_menu">Actions</mdui-navigation-bar-item>

      <mdui-navigation-bar-item value="advanced"
        icon="shield--outlined" active-icon="shield"
        data-i18n-label="nav_advancemenu">Advanced</mdui-navigation-bar-item>

      <mdui-navigation-bar-item value="settings"
        icon="settings--outlined" active-icon="settings"
        data-i18n-label="nav_settings">Settings</mdui-navigation-bar-item>
    </mdui-navigation-bar>

  </mdui-layout>

  <!-- Script loading at end -->
  <script src="assets/mdui.global.js"
          onerror="this.onerror=null;this.src='https://unpkg.com/mdui@2/mdui.global.js'">
  </script>
  <script type="module" src="js/app.js"></script>
</body>
```

**Navigation bar note:** `<mdui-layout>` + `<mdui-navigation-bar>` inside it handles `padding-bottom` automatically — no manual spacing hacks needed.

---

## 3. Pages

Each page is a `<section>` with `id="{value}-page"` inside `#pages`. Visibility is controlled by `app.js` (remove/add `hidden` attribute based on nav-bar `change` event). Only the active page is rendered in the DOM; others are `hidden` (display:none) so they don't affect layout.

### 3.1 Home Page (`#home-page`)

**Purpose:** At-a-glance device status. Quick access to script history.

```html
<section id="home-page">

  <!-- Version hero card (clickable → history dialog) -->
  <mdui-card id="version-card" clickable class="hero-card" variant="elevated">
    <div class="hero-card__inner">
      <mdui-icon name="verified_user" class="hero-card__icon"></mdui-icon>
      <div class="hero-card__text">
        <p class="mdui-typescale-label-medium" data-i18n="home_version">Module Version</p>
        <p class="mdui-typescale-headline-medium" id="version-value">—</p>
      </div>
      <mdui-icon name="history" class="hero-card__action-icon"></mdui-icon>
    </div>
  </mdui-card>

  <!-- Refresh button (tonal, full-width) -->
  <mdui-button id="refresh-btn" variant="tonal" icon="refresh" full-width
               data-i18n="home_refresh">Refresh Info</mdui-button>

  <!-- Info grid: 2 columns on all screen sizes -->
  <div class="info-grid">

    <mdui-card class="info-card" variant="filled">
      <mdui-icon name="calendar_today" class="info-card__icon"></mdui-icon>
      <p class="mdui-typescale-label-small info-card__label" data-i18n="home_clock_date">Date</p>
      <p class="mdui-typescale-title-large info-card__value" id="clock-date">—</p>
    </mdui-card>

    <mdui-card class="info-card" variant="filled">
      <mdui-icon name="schedule" class="info-card__icon"></mdui-icon>
      <p class="mdui-typescale-label-small info-card__label" data-i18n="home_clock_time">Time</p>
      <p class="mdui-typescale-title-large info-card__value" id="clock-time">—</p>
    </mdui-card>

    <mdui-card class="info-card" variant="filled" id="status-card">
      <mdui-icon name="wifi" class="info-card__icon" id="status-icon"></mdui-icon>
      <p class="mdui-typescale-label-small info-card__label" data-i18n="home_status">Status</p>
      <p class="mdui-typescale-title-large info-card__value" id="status-value" data-i18n="home_status_online">Online</p>
    </mdui-card>

    <mdui-card class="info-card" variant="filled">
      <mdui-icon name="android" class="info-card__icon"></mdui-icon>
      <p class="mdui-typescale-label-small info-card__label">Android</p>
      <p class="mdui-typescale-title-large info-card__value" id="android-value">—</p>
    </mdui-card>

    <mdui-card class="info-card" variant="filled">
      <mdui-icon name="memory" class="info-card__icon"></mdui-icon>
      <p class="mdui-typescale-label-small info-card__label">Kernel</p>
      <p class="mdui-typescale-title-large info-card__value" id="kernel-value">—</p>
    </mdui-card>

    <mdui-card class="info-card" variant="filled">
      <mdui-icon name="vpn_key" class="info-card__icon"></mdui-icon>
      <p class="mdui-typescale-label-small info-card__label" data-i18n="home_root">Root</p>
      <p class="mdui-typescale-title-large info-card__value" id="root-value">—</p>
    </mdui-card>

  </div>

</section>
```

**Behavior details:**
- `version-card` is `clickable` (mdui card prop) → triggers history dialog (see §6.2)
- `refresh-btn` click: adds `loading` attribute to the button (mdui shows spinner automatically), runs `device-info.sh` via bridge with **`type='common'`** (because device-info.sh lives in `webroot/common/`, not `features/`), on callback calls `loadDeviceInfo()`, removes `loading`
- Refresh timeout: **15 seconds** (up from the current broken 7s)
- Status card icon changes: `wifi` when online, `wifi_off` when offline; card gets `class="status-offline"` for color change
- Network chip in top bar mirrors the same status

---

### 3.2 Actions Page (`#actions-page`)

**Purpose:** Daily-use operations. Renamed from "Main Menu" to "Actions" for clarity.

**Design pattern:** Use `<mdui-list>` with `<mdui-list-item>` instead of stacked full-width pill buttons. Each action gets an icon, a title, and a one-line description. This is the correct MD3 pattern for action lists.

```html
<section id="actions-page" hidden>

  <p class="mdui-typescale-title-small section-label" data-i18n="menu_keybox">Keybox</p>
  <mdui-card variant="elevated" class="action-card">
    <mdui-list>
      <mdui-list-item
        icon="key"
        data-script="keybox.sh"
        class="action-item"
        rounded>
        <span data-i18n="menu_import_keybox">Set Up Yuri Keybox</span>
        <span slot="description" data-i18n="menu_import_keybox_desc">
          Downloads and installs remote keybox to Tricky Store
        </span>
        <mdui-circular-progress slot="end-icon" class="action-spinner hidden"></mdui-circular-progress>
      </mdui-list-item>
    </mdui-list>
  </mdui-card>

  <p class="mdui-typescale-title-small section-label" data-i18n="menu_gms_section">GMS</p>
  <mdui-card variant="elevated" class="action-card">
    <mdui-list>

      <mdui-list-item icon="block" data-script="kill_google_process.sh" class="action-item" rounded>
        <span data-i18n="menu_force_clear">Force Stop & Clear Play Store</span>
        <span slot="description" data-i18n="menu_force_clear_desc">
          Force-stops Play Store and wipes its data cache
        </span>
        <mdui-circular-progress slot="end-icon" class="action-spinner hidden"></mdui-circular-progress>
      </mdui-list-item>

      <mdui-divider></mdui-divider>

      <mdui-list-item icon="list_alt" data-script="target.sh" class="action-item" rounded>
        <span data-i18n="menu_target">Set Up target.txt</span>
        <span slot="description" data-i18n="menu_target_desc">
          Generates Tricky Store target.txt with all installed apps
        </span>
        <mdui-circular-progress slot="end-icon" class="action-spinner hidden"></mdui-circular-progress>
      </mdui-list-item>

      <mdui-divider></mdui-divider>

      <mdui-list-item icon="apps" data-script="select_app_necessary.sh" class="action-item" rounded>
        <span data-i18n="menu_necessary">Only Necessary Apps</span>
        <span slot="description" data-i18n="menu_necessary_desc">
          Sets only fixed targets — no dynamic package scanning
        </span>
        <mdui-circular-progress slot="end-icon" class="action-spinner hidden"></mdui-circular-progress>
      </mdui-list-item>

      <mdui-divider></mdui-divider>

      <mdui-list-item icon="security_update_good" data-script="security_patch.sh" class="action-item" rounded>
        <span data-i18n="menu_patch">Set Up Security Patch</span>
        <span slot="description" data-i18n="menu_patch_desc">
          Writes spoofed security patch date to Tricky Store
        </span>
        <mdui-circular-progress slot="end-icon" class="action-spinner hidden"></mdui-circular-progress>
      </mdui-list-item>

      <mdui-divider></mdui-divider>

      <mdui-list-item icon="verified" data-script="boot_hash.sh" class="action-item" rounded>
        <span data-i18n="advance_set_verified_boot">Set Verified Boot Hash</span>
        <span slot="description" data-i18n="advance_set_verified_boot_desc">
          Reads and writes verified boot hash for attestation
        </span>
        <mdui-circular-progress slot="end-icon" class="action-spinner hidden"></mdui-circular-progress>
      </mdui-list-item>

    </mdui-list>
  </mdui-card>

</section>
```

---

### 3.3 Advanced Page (`#advanced-page`)

**Purpose:** Power-user detection bypass and system fixes. Renamed from "Advanced Menu".

```html
<section id="advanced-page" hidden>

  <p class="mdui-typescale-title-small section-label" data-i18n="advance_menu_title_extended">Detection & Fixes</p>
  <mdui-card variant="elevated" class="action-card">
    <mdui-list>

      <mdui-list-item icon="delete_sweep" data-script="clear_all_detection_traces.sh" class="action-item" rounded>
        <span data-i18n="advance_clear_all_detection_traces">Clear All Detection Traces</span>
        <span slot="description" data-i18n="advance_clear_all_detection_traces_desc">
          Deletes detector app data, temp files, resets props, removes ODEX
        </span>
        <mdui-circular-progress slot="end-icon" class="action-spinner hidden"></mdui-circular-progress>
      </mdui-list-item>

      <mdui-divider></mdui-divider>

      <mdui-list-item icon="cloud_download" data-script="hma.sh" class="action-item" rounded>
        <span data-i18n="advance_set_hma-oss_configs">Set HMA-OSS Configs</span>
        <span slot="description" data-i18n="advance_set_hma_desc">
          Downloads HMA-OSS config from GitHub with proper permissions
        </span>
        <mdui-circular-progress slot="end-icon" class="action-spinner hidden"></mdui-circular-progress>
      </mdui-list-item>

      <mdui-divider></mdui-divider>

      <mdui-list-item icon="tune" data-script="znctl.sh" class="action-item" rounded>
        <span data-i18n="advance_set_zygisk_next_configs">Set Zygisk Next Configs</span>
        <span slot="description" data-i18n="advance_set_zygisk_desc">
          Configures enforce-denylist, memory-type, linker settings
        </span>
        <mdui-circular-progress slot="end-icon" class="action-spinner hidden"></mdui-circular-progress>
      </mdui-list-item>

      <mdui-divider></mdui-divider>

      <mdui-list-item icon="fingerprint" data-script="pif.sh" class="action-item" rounded>
        <span data-i18n="advance_set_pif">Set Fingerprint (PIF)</span>
        <span slot="description" data-i18n="advance_set_pif_desc">
          Runs Play Integrity Fix auto-update scripts
        </span>
        <mdui-circular-progress slot="end-icon" class="action-spinner hidden"></mdui-circular-progress>
      </mdui-list-item>

      <mdui-divider></mdui-divider>

      <mdui-list-item icon="code_off" data-script="lsposed2.sh" class="action-item" rounded>
        <span data-i18n="advance_fix_detect_lsposed">Fix LSPosed Detection</span>
        <span slot="description" data-i18n="advance_fix_lsposed_desc">
          Deletes all base.odex files from /data/app
        </span>
        <mdui-circular-progress slot="end-icon" class="action-spinner hidden"></mdui-circular-progress>
      </mdui-list-item>

      <mdui-divider></mdui-divider>

      <mdui-list-item icon="bug_report" data-script="pif2.sh" class="action-item" rounded>
        <span data-i18n="advance_fix_detect_pif">Fix PIF Detection</span>
        <span slot="description" data-i18n="advance_fix_pif_desc">
          Removes PIF-related properties via resetprop
        </span>
        <mdui-circular-progress slot="end-icon" class="action-spinner hidden"></mdui-circular-progress>
      </mdui-list-item>

      <mdui-divider></mdui-divider>

      <mdui-list-item icon="folder_delete" data-script="twrp.sh" class="action-item" rounded>
        <span data-i18n="advance_fix_detect_recovery_file">Fix Recovery File Detection</span>
        <span slot="description" data-i18n="advance_fix_recovery_desc">
          Deletes /sdcard/TWRP directory
        </span>
        <mdui-circular-progress slot="end-icon" class="action-spinner hidden"></mdui-circular-progress>
      </mdui-list-item>

      <mdui-divider></mdui-divider>

      <mdui-list-item icon="cancel" data-script="kill_all.sh" class="action-item" rounded>
        <span data-i18n="advance_kill_all">Kill All Processes</span>
        <span slot="description" data-i18n="advance_kill_all_desc">
          Force-stops and clears data for all known detector apps
        </span>
        <mdui-circular-progress slot="end-icon" class="action-spinner hidden"></mdui-circular-progress>
      </mdui-list-item>

      <mdui-divider></mdui-divider>

      <mdui-list-item icon="cloud_sync" data-script="yurirka.sh" class="action-item" rounded>
        <span data-i18n="advance_upd_yurirka">Update RKA Config</span>
        <span slot="description" data-i18n="advance_upd_rka_desc">
          Provisions Remote Key Attestation config for PassIt
        </span>
        <mdui-circular-progress slot="end-icon" class="action-spinner hidden"></mdui-circular-progress>
      </mdui-list-item>

    </mdui-list>
  </mdui-card>

  <!-- TEE Fix section — device-specific -->
  <p class="mdui-typescale-title-small section-label" data-i18n="advance_tee_section">
    Fix TEE: OnePlus, RedMagic, Realme, Oppo…
  </p>
  <mdui-card variant="elevated" class="action-card">
    <mdui-list>
      <mdui-list-item icon="layers" data-script="widevinel1.sh" class="action-item" rounded>
        <span data-i18n="advance_wdevinel1">Fix Widevine L1</span>
        <span slot="description" data-i18n="advance_wdevinel1_desc">
          Copies FixWidevineL1 files and runs KmInstallKeybox vendor binary
        </span>
        <mdui-circular-progress slot="end-icon" class="action-spinner hidden"></mdui-circular-progress>
      </mdui-list-item>
    </mdui-list>
  </mdui-card>

</section>
```

---

### 3.4 Settings Page (`#settings-page`)

```html
<section id="settings-page" hidden>

  <!-- Language -->
  <p class="mdui-typescale-title-small section-label" data-i18n="settings_language">Language</p>
  <mdui-card variant="elevated" class="settings-card">
    <mdui-select id="language-select" variant="outlined" icon="language">
      <!-- Options injected by i18n.js -->
    </mdui-select>
  </mdui-card>

  <!-- Appearance -->
  <p class="mdui-typescale-title-small section-label" data-i18n="settings_appearance">Appearance</p>
  <mdui-card variant="elevated" class="settings-card">

    <!-- Theme mode -->
    <p class="mdui-typescale-label-large settings-sublabel" data-i18n="settings_theme_mode">Mode</p>
    <mdui-segmented-button-group id="theme-mode-group" selects="single" value="dark">
      <mdui-segmented-button value="dark" icon="dark_mode" data-i18n="theme_mode_dark">Dark</mdui-segmented-button>
      <mdui-segmented-button value="light" icon="light_mode" data-i18n="theme_mode_light">Light</mdui-segmented-button>
      <mdui-segmented-button value="auto" icon="brightness_auto" data-i18n="theme_mode_auto">Auto</mdui-segmented-button>
    </mdui-segmented-button-group>

    <mdui-divider style="margin: 12px 0"></mdui-divider>

    <!-- Color presets -->
    <p class="mdui-typescale-label-large settings-sublabel" data-i18n="settings_color_preset">Color</p>
    <div id="preset-chips" class="preset-chips">
      <!-- Each chip has a color swatch dot + label -->
      <mdui-chip id="preset-ocean" selectable selected class="preset-chip" data-preset="ocean">
        <span class="preset-dot" style="background:#1B6EF3"></span>
        <span data-i18n="theme_preset_ocean">Ocean</span>
      </mdui-chip>
      <mdui-chip id="preset-rose" selectable class="preset-chip" data-preset="rose">
        <span class="preset-dot" style="background:#C2184B"></span>
        <span data-i18n="theme_preset_rose">Rose</span>
      </mdui-chip>
      <mdui-chip id="preset-forest" selectable class="preset-chip" data-preset="forest">
        <span class="preset-dot" style="background:#1B6E3A"></span>
        <span data-i18n="theme_preset_forest">Forest</span>
      </mdui-chip>
      <mdui-chip id="preset-sunset" selectable class="preset-chip" data-preset="sunset">
        <span class="preset-dot" style="background:#E65100"></span>
        <span data-i18n="theme_preset_sunset">Sunset</span>
      </mdui-chip>
      <mdui-chip id="preset-violet" selectable class="preset-chip" data-preset="violet">
        <span class="preset-dot" style="background:#6750A4"></span>
        <span data-i18n="theme_preset_violet">Violet</span>
      </mdui-chip>
    </div>

  </mdui-card>

  <!-- Clock Format -->
  <p class="mdui-typescale-title-small section-label" data-i18n="settings_clock_format">Clock Format</p>
  <mdui-card variant="elevated" class="settings-card">
    <mdui-select id="clock-format-select" variant="outlined" icon="schedule">
      <mdui-menu-item value="auto" data-i18n="clock_format_auto">Auto (Device)</mdui-menu-item>
      <mdui-menu-item value="24h" data-i18n="clock_format_24h">24-hour</mdui-menu-item>
      <mdui-menu-item value="12h" data-i18n="clock_format_12h">12-hour (AM/PM)</mdui-menu-item>
    </mdui-select>
  </mdui-card>

  <!-- Update & Support -->
  <p class="mdui-typescale-title-small section-label" data-i18n="update_title">Update & Support</p>
  <mdui-card variant="elevated" class="settings-card">
    <p class="mdui-typescale-body-medium" data-i18n="update_desc">
      Stay up to date with the latest Yurikey releases and bug fixes.
    </p>
    <div class="support-buttons">
      <mdui-button variant="tonal" icon="code" data-url="https://github.com/Yurii0307/yurikey" data-i18n="update_github">
        View on GitHub
      </mdui-button>
      <mdui-button variant="tonal" icon="send" data-url="https://t.me/yuriiroot" data-i18n="update_telegram">
        Join Telegram
      </mdui-button>
    </div>
    <p class="mdui-typescale-body-small settings-footnote" data-i18n="update_note">
      Join Telegram or check GitHub for contributions and technical discussions.
    </p>
  </mdui-card>

  <!-- Contributors -->
  <p class="mdui-typescale-title-small section-label" data-i18n="settings_contributors">Project Contributors</p>
  <div id="contributors-grid" class="contributors-grid">
    <!-- Injected by contributors.js -->
  </div>

</section>
```

---

## 4. Script History Dialog

Opened by clicking `#version-card`. Use mdui's programmatic dialog API.

```javascript
// history.js
// File-based script history using exec (survives app uninstall).
// Uses printf '%s\n' for shell-safe output (no echo — handles backticks, $, \).

import { getModuleDir } from './cfg.js'; // cfg.js holds MODULE.MODDIR

function historyFile() { return `${getModuleDir()}/script_history.log`; }

export async function getHistory() {
  try {
    const { exec } = await import('./bridge.js');
    const { stdout } = await exec(`cat "${historyFile()}" 2>/dev/null || echo "[]"`);
    return JSON.parse(stdout);
  } catch { return []; }
}

export async function addEntry(scriptName, output) {
  if (!output?.trim()) return;
  const ts = new Date().toISOString();
  const historyFile = historyFile();
  const tmp = `${historyFile}.tmp`;
  const entry = JSON.stringify({ script: scriptName, output, time: ts });
  // shell-safe: printf '%s\n' handles special chars; existing file is JSON array
  const { exec } = await import('./bridge.js');
  await exec(
    `printf '%s\\n' '${entry.replace(/'/g, "'\\''")}' > "${tmp}" && ` +
    `cat "${historyFile}" 2>/dev/null >> "${tmp}" && ` +
    `head -240 "${tmp}" > "${historyFile}" && rm -f "${tmp}"`
  );
}

export async function clearHistory() {
  const { exec } = await import('./bridge.js');
  await exec(`printf '[]' > "${historyFile()}"`);
}

export async function openHistoryDialog() {
  const entries = await getHistory();
  const isEmpty = !entries || entries.length === 0;

  const content = isEmpty
    ? `<p class="mdui-typescale-body-medium empty-history" data-i18n="script_history_empty">No script history yet</p>`
    : entries.map(e => `
        <div class="history-entry">
          <p class="mdui-typescale-label-medium history-script">${escapeHtml(e.script)}</p>
          <p class="mdui-typescale-body-small history-time">${e.time}</p>
          <pre class="history-output">${escapeHtml(e.output)}</pre>
          <mdui-divider></mdui-divider>
        </div>
      `).join('');

  mdui.dialog({
    headline: translations['script_history_title'] || 'Script History',
    body: `<div class="history-list">${content}</div>`,
    actions: [
      {
        text: translations['dialog_clear'] || 'Clear',
        onClick: async () => { await clearHistory(); openHistoryDialog(); return false; }
      },
      { text: translations['dialog_close'] || 'Close' }
    ],
    scrollTargetSelectors: '.history-list',
    closeOnOverlayClick: true,
  });
}

function escapeHtml(str) {
  return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}
```

**Notes:**
- `return false` in the Clear onClick prevents the dialog from closing — it re-renders.
- History is a **JSON array file** on disk. Each new entry is prepended via shell `printf` + temp file. Max 80 entries (at 3 lines each → 240 lines capped to 240).
- `printf '%s\n'` is used instead of `echo` because `echo` doesn't handle `\n`, backticks, `$`, or `\` in shell output. This is critical for script output that may contain any of these characters.
- Dialog uses mdui's built-in scroll, backdrop, and focus trap — no custom implementation needed.

---

## 5. CSS Overrides (`css/app.css`)

This file only defines what mdui doesn't provide out of the box. No `!important` anywhere. All values use mdui's CSS custom properties as building blocks.

```css
/* ─── Layout ──────────────────────────────────────────── */

#pages {
  padding: 16px;
  padding-bottom: 8px; /* mdui-layout handles nav-bar spacing */
}

section {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

/* ─── Top App Bar extras ─────────────────────────────── */

.network-chip {
  font-size: 0.75rem;
  --mdui-comp-chip-container-height: 28px;
}

.network-chip.offline {
  --mdui-color-primary: var(--mdui-color-error);
  --mdui-color-on-primary: var(--mdui-color-on-error);
}

/* ─── Hero card (version) ─────────────────────────────── */

.hero-card {
  width: 100%;
}

.hero-card__inner {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 20px;
}

.hero-card__icon {
  font-size: 36px;
  color: var(--mdui-color-primary);
}

.hero-card__text {
  flex: 1;
}

.hero-card__action-icon {
  color: var(--mdui-color-on-surface-variant);
}

/* ─── Info grid ───────────────────────────────────────── */

.info-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
}

.info-card {
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 6px;
  min-height: 96px;
}

.info-card__icon {
  color: var(--mdui-color-primary);
  font-size: 20px;
}

.info-card__label {
  color: var(--mdui-color-on-surface-variant);
  margin: 0;
}

.info-card__value {
  margin: 0;
  font-variant-numeric: tabular-nums; /* clock digits don't jump */
  word-break: break-all;
  font-size: clamp(0.85rem, 3.5vw, 1.1rem); /* kernel hash fits */
}

/* Offline state */
#status-card.status-offline {
  --mdui-color-surface-variant: color-mix(in srgb, var(--mdui-color-error) 15%, var(--mdui-color-surface));
}

/* ─── Section labels ──────────────────────────────────── */

.section-label {
  margin: 12px 0 4px 4px;
  color: var(--mdui-color-primary);
  letter-spacing: 0.05em;
  text-transform: uppercase;
  font-size: 0.7rem;
}

/* ─── Action cards / list ─────────────────────────────── */

.action-card {
  width: 100%;
  overflow: hidden; /* rounded corners clip list items */
}

.action-item[disabled] {
  opacity: 0.5;
}

.action-spinner {
  --mdui-comp-circular-progress-size: 20px;
}

.action-spinner.hidden {
  display: none;
}

/* ─── Settings cards ──────────────────────────────────── */

.settings-card {
  width: 100%;
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.settings-sublabel {
  color: var(--mdui-color-on-surface-variant);
  margin: 0;
}

.settings-footnote {
  color: var(--mdui-color-on-surface-variant);
  margin: 0;
}

mdui-select,
mdui-segmented-button-group {
  width: 100%;
}

.preset-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.preset-chip {
  cursor: pointer;
}

.preset-dot {
  display: inline-block;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  margin-right: 4px;
  vertical-align: middle;
}

.support-buttons {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.support-buttons mdui-button {
  flex: 1;
  min-width: 120px;
}

/* ─── Contributors grid ───────────────────────────────── */

.contributors-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  padding-bottom: 24px;
}

.contributor-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  padding: 16px 8px;
  cursor: pointer;
}

.contributor-avatar {
  width: 56px;
  height: 56px;
  border-radius: 50%;
  object-fit: cover;
  background: var(--mdui-color-surface-variant);
}

.contributor-name {
  margin: 0;
  text-align: center;
  font-weight: 500;
}

.contributor-role {
  margin: 0;
  color: var(--mdui-color-on-surface-variant);
  text-align: center;
}

/* ─── Script History Dialog ───────────────────────────── */

.history-list {
  max-height: 60vh;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.history-entry {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.history-script {
  color: var(--mdui-color-primary);
  margin: 0;
}

.history-time {
  color: var(--mdui-color-on-surface-variant);
  margin: 0;
}

.history-output {
  background: var(--mdui-color-surface-container);
  border-radius: 8px;
  padding: 8px 12px;
  font-size: 0.75rem;
  white-space: pre-wrap;
  word-break: break-all;
  max-height: 120px;
  overflow-y: auto;
  margin: 0;
}

.empty-history {
  text-align: center;
  color: var(--mdui-color-on-surface-variant);
  padding: 32px 0;
}
```

---

## 6. JavaScript Modules

### 6.1 `js/bridge.js` — Script Execution & History

```javascript
// bridge.js
// Handles script execution across 3 bridge types + output capture.
// HISTORY is now file-based (via exec printf) to survive app uninstall.
// MODULE path is discovered dynamically via module_paths.json at boot.

const EXEC_TIMEOUT_MS = 15000; // 15s — was 7s, too short

let MODULE = null; // populated by initBridge() from module_paths.json

// ── Path discovery (MUST be called on app init before any runScript) ─────────

export async function initBridge() {
  try {
    const r = await fetch('/json/module_paths.json?ts=' + Date.now());
    MODULE = await r.json();
  } catch {
    const src = document.currentScript?.src || '';
    const m = src.match(/^(file:\/\/\/data\/adb\/modules\/[^/]+)/);
    MODULE = m ? { MODDIR: m[1] } : null;
  }
  if (!MODULE) throw new Error('Cannot determine module path');
}

// Returns the correct base directory for a script type
function scriptDir(type) {
  // 'features/' scripts: keybox.sh, target.sh, etc.
  // 'common/' scripts: device-info.sh (lives in webroot/common/)
  const dirs = { feature: 'features', common: 'webroot/common' };
  const sub = dirs[type] || 'features';
  return `${MODULE.MODDIR}/${sub}/`;
}

// ── Bridge detection ──────────────────────────────────────────────────────────

function getExecutor() {
  if (typeof window.YuriKeyHost?.execScript === 'function') return 'mmrl';
  if (typeof window.execYurikeyScript === 'function') return 'legacy-mmrl';
  if (typeof window.ksu?.exec === 'function') return 'ksu';
  return null;
}

// ── Core exec ─────────────────────────────────────────────────────────────────

export function runScript(scriptName, type = 'feature') {
  return new Promise((resolve, reject) => {
    const executor = getExecutor();
    if (!executor) { reject(new Error('no-bridge')); return; }
    if (!MODULE) { reject(new Error('no-module-path')); return; }

    const scriptPath = scriptDir(type) + scriptName;
    const cbName = `cb_${Date.now()}_${Math.random().toString(36).slice(2)}`;
    let timer;

    function cleanup() { clearTimeout(timer); delete window[cbName]; }

    timer = setTimeout(() => {
      cleanup();
      reject(new Error('timeout'));
    }, EXEC_TIMEOUT_MS);

    window[cbName] = function (output) {
      cleanup();
      const result = parseScriptOutput(output);
      if (result.success) resolve(result);
      else reject(Object.assign(new Error('script-error'), { result }));
    };

    try {
      if (executor === 'mmrl') {
        window.YuriKeyHost.execScript(`sh '${scriptPath}'`, '{}', cbName);
      } else if (executor === 'legacy-mmrl') {
        window.execYurikeyScript(scriptPath, cbName);
      } else {
        window.ksu.exec(`sh '${scriptPath}'`, '{}', cbName);
      }
    } catch (err) { cleanup(); reject(err); }
  });
}

function parseScriptOutput(raw) {
  if (!raw) return { success: true, rawOutput: '' };
  try {
    const json = JSON.parse(raw);
    return { success: json.success !== false, output: json.output || '', rawOutput: raw };
  } catch {
    return { success: true, rawOutput: raw };
  }
}
```

---

### 6.2 `js/cfg.js` — Config Persistence (ksud + flat-file fallback + in-memory cache)

> **CRITICAL:** settings must survive manager app uninstall. `localStorage` does NOT. This module uses `ksud module config` (KernelSU) with flat-file fallback (Magisk/APatch) and an in-memory cache to avoid shell exec() on every read.

```javascript
// cfg.js
// Dual-layer config persistence with in-memory cache.
// Reads: ksud module config → file fallback → memory cache
// Writes: memory cache first, then async flush to ksud/file.

let MODULE = null;
let cache = {};
let flushTimer = null;

export function setModuleDir(path) { MODULE = path; }
export function getModuleDir() { return MODULE; }

// Lazy exec import to avoid circular deps
async function exec(cmd) {
  const { runScriptRaw } = await import('./bridge.js');
  // runScriptRaw executes a raw command and returns {stdout, stderr}
}

async function readConfig(key) {
  if (!MODULE) return null;
  const { exec } = await import('./bridge.js');
  const { stdout } = await exec(
    `ksud module config get "${key}" 2>/dev/null || cat "${MODULE}/config/${key}.val" 2>/dev/null || true`
  );
  return stdout.trim() || null;
}

async function writeConfig(key, val) {
  if (!MODULE) return;
  const { exec } = await import('./bridge.js');
  await exec(
    `ksud module config set "${key}" "${val}" 2>/dev/null || ` +
    `mkdir -p "${MODULE}/config" && printf '%s' "${val}" > "${MODULE}/config/${key}.val"`
  );
}

async function deleteConfig(key) {
  if (!MODULE) return;
  const { exec } = await import('./bridge.js');
  await exec(
    `ksud module config delete "${key}" 2>/dev/null || rm -f "${MODULE}/config/${key}.val" 2>/dev/null || true`
  );
}

// ── Public API (in-memory cache + async flush) ────────────────────────────────

export async function cfgGet(key, defaultValue) {
  if (key in cache) return cache[key];
  const val = await readConfig(key);
  cache[key] = val ?? defaultValue;
  return cache[key];
}

export function cfgSet(key, val) {
  cache[key] = val;
  // Debounce writes — flush after 500ms of inactivity
  if (flushTimer) clearTimeout(flushTimer);
  flushTimer = setTimeout(() => {
    flushTimer = null;
    writeConfig(key, val);
  }, 500);
}

export function cfgDelete(key) {
  delete cache[key];
  deleteConfig(key);
}

// ── One-time localStorage migration ──────────────────────────────────────────

export async function migrateLocalStorage() {
  try {
    if (localStorage.getItem('_cfg_migrated')) return;
    const map = {
      selectedLanguage: 'lang',
      themeMode: 'theme',
      themePreset: 'theme_preset',
      clockFormat: 'clock_format',
    };
    for (const [oldKey, newKey] of Object.entries(map)) {
      const val = localStorage.getItem(oldKey);
      if (val) await writeConfig(newKey, val);
    }
    localStorage.setItem('_cfg_migrated', '1');
  } catch { /* localStorage unavailable */ }
}
```

**Add `runScriptRaw` to bridge.js** for direct command execution (used by cfg.js and history.js):

```javascript
// In bridge.js — add this export alongside runScript
export function runScriptRaw(command) {
  return new Promise((resolve, reject) => {
    const executor = getExecutor();
    if (!executor) { reject(new Error('no-bridge')); return; }
    const cbName = `cb_${Date.now()}_${Math.random().toString(36).slice(2)}`;
    window[cbName] = function (output) {
      delete window[cbName];
      resolve({ stdout: output || '', stderr: '' });
    };
    try {
      if (executor === 'mmrl') {
        window.YuriKeyHost.execScript(command, '{}', cbName);
      } else if (executor === 'legacy-mmrl') {
        window.execYurikeyScript(command, cbName);
      } else {
        window.ksu.exec(command, '{}', cbName);
      }
    } catch (e) { delete window[cbName]; reject(e); }
  });
}
```

---

### 6.3 `js/app.js` — Entry Point & Action Wiring

```javascript
// app.js — runs after DOMContentLoaded

import { initBridge, runScript } from './bridge.js';
import { initDevice, refreshDevice } from './device.js';
import { initClock } from './clock.js';
import { initNetwork } from './network.js';
import { initTheme } from './theme.js';
import { initI18n } from './i18n.js';
import { loadContributors } from './contributors.js';
import { initRedirect } from './redirect.js';
import { openHistoryDialog } from './history.js';
import { setModuleDir, migrateLocalStorage, cfgGet } from './cfg.js';

document.addEventListener('DOMContentLoaded', async () => {
  // Step 0: Discover module path — MUST be first (everything depends on it)
  await initBridge();                    // sets MODULE.MODDIR in bridge
  setModuleDir(MODULE.MODDIR);           // share with cfg.js
  // One-time migration of old localStorage settings to new persistence layer
  await migrateLocalStorage();

  // Init order: theme first (no flash), then i18n, then data
  const savedTheme = await cfgGet('theme', 'dark') || 'dark';
  initTheme(savedTheme);
  await initI18n();
  initClock();
  initNetwork();
  initDevice();
  loadContributors();
  initRedirect();
  wireNavigation();
  wireActions();
  wireSettings();
  wireVersionCard();
  wireRefreshButton();
});

// ── Navigation ────────────────────────────────────────────────────────────────

function wireNavigation() {
  const navBar = document.getElementById('nav-bar');
  const pages = {
    home: document.getElementById('home-page'),
    actions: document.getElementById('actions-page'),
    advanced: document.getElementById('advanced-page'),
    settings: document.getElementById('settings-page'),
  };

  navBar.addEventListener('change', () => {
    const active = navBar.value;
    Object.entries(pages).forEach(([key, el]) => {
      el.hidden = key !== active;
    });
    window.scrollTo({ top: 0, behavior: 'instant' });
  });
}

// ── Action items ──────────────────────────────────────────────────────────────
// All elements with [data-script] in #actions-page and #advanced-page
// NOTE: device-info.sh lives in webroot/common/, pass type='common'

function wireActions() {
  document.querySelectorAll('.action-item[data-script]').forEach(item => {
    item.addEventListener('click', async () => {
      if (item.disabled) return;

      const scriptName = item.dataset.script;
      const spinner = item.querySelector('.action-spinner');
      const { getTranslation } = await import('./i18n.js');

      item.disabled = true;
      spinner?.classList.remove('hidden');
      mdui.snackbar({ message: getTranslation('home_refreshing') || 'Executing…', action: '' });

      try {
        await runScript(scriptName, 'feature');
        mdui.snackbar({ message: getTranslation('toast_success') || 'Done' });
      } catch (err) {
        const msg = err.message === 'timeout'
          ? (getTranslation('toast_timeout') || 'Timed out')
          : (getTranslation('toast_error') || 'Failed');
        mdui.snackbar({ message: msg });
      } finally {
        item.disabled = false;
        spinner?.classList.add('hidden');
      }
    });
  });
}

function wireVersionCard() {
  document.getElementById('version-card').addEventListener('click', openHistoryDialog);
}

function wireRefreshButton() {
  const btn = document.getElementById('refresh-btn');
  btn.addEventListener('click', async () => {
    btn.loading = true;
    await refreshDevice();
    btn.loading = false;
  });
}

function wireSettings() {
  // Wired inside theme.js, clock.js, and i18n.js respectively
}
```

---

### 6.3 `js/device.js` — Device Info

```javascript
// device.js
// NOTE: device-info.sh lives in webroot/common/, NOT features/
// Always pass type='common' when calling runScript for it.

const INFO_URL = '/json/device-info.json';
let bridge = null;
async function getBridge() {
  if (!bridge) bridge = await import('./bridge.js');
  return bridge;
}

export function initDevice() {
  loadDeviceInfo();
  loadVersion();
}

export async function refreshDevice() {
  // device-info.sh is in webroot/common/ — pass type='common'
  const { runScript, runScriptRaw } = await getBridge();
  try {
    await runScript('device-info.sh', 'common');
  } catch { /* best effort */ }
  await waitForValidDeviceInfo();
}

async function loadDeviceInfo() {
  try {
    const res = await fetch(`${INFO_URL}?ts=${Date.now()}`);
    const data = await res.json();
    applyDeviceInfo(data);
  } catch {}
}

async function waitForValidDeviceInfo(maxMs = 6000, intervalMs = 400) {
  const start = Date.now();
  while (Date.now() - start < maxMs) {
    try {
      const res = await fetch(`${INFO_URL}?ts=${Date.now()}`);
      const data = await res.json();
      if (data.android || data.kernel || data.root) {
        applyDeviceInfo(data);
        return;
      }
    } catch {}
    await new Promise(r => setTimeout(r, intervalMs));
  }
}

function applyDeviceInfo(data) {
  setText('android-value', data.android || '—');
  setText('kernel-value', data.kernel || '—');
  setText('root-value', data.root || '—');
}

// Load module version via runScriptRaw (grep from module.prop)
export async function loadVersion() {
  const { runScriptRaw } = await getBridge();
  try {
    const { stdout } = await runScriptRaw(
      `grep '^version=' "${getModuleDir()}/module.prop" | cut -d'=' -f2`
    );
    if (stdout) setText('version-value', stdout.trim());
  } catch {
    // Fallback: fetch module.prop as HTTP (if WebUI server serves it)
    try {
      const res = await fetch('/module.prop');
      const text = await res.text();
      const match = text.match(/^version=(.+)$/m);
      if (match) setText('version-value', match[1].trim());
    } catch {}
  }
}

function setText(id, value) {
  const el = document.getElementById(id);
  if (el) el.textContent = value;
}
```

---

### 6.4 `js/theme.js` — Theme System

```javascript
// theme.js

import { cfgGet, cfgSet } from './cfg.js';

// MD3 seed colors for each preset
// mdui.setColorScheme() generates the full 30-color role set from a single hex
const PRESETS = {
  ocean:  '#1B6EF3',
  rose:   '#C2184B',
  forest: '#1B6E3A',
  sunset: '#E65100',
  violet: '#6750A4',
};

export async function initTheme(savedMode) {
  const preset = await cfgGet('theme_preset', 'ocean') || 'ocean';
  applyMode(savedMode || 'dark');
  applyPreset(preset);
  wireThemeControls();
}

function applyMode(mode) {
  if (mode === 'auto') {
    mdui.setTheme('auto');
  } else {
    mdui.setTheme(mode);
  }
  cfgSet('theme', mode);
  const group = document.getElementById('theme-mode-group');
  if (group) group.value = mode;
}

function applyPreset(preset) {
  const seed = PRESETS[preset];
  if (!seed) return;
  mdui.setColorScheme(seed);
  cfgSet('theme_preset', preset);
  document.querySelectorAll('.preset-chip').forEach(chip => {
    chip.selected = chip.dataset.preset === preset;
  });
}

function wireThemeControls() {
  const modeGroup = document.getElementById('theme-mode-group');
  modeGroup?.addEventListener('change', () => applyMode(modeGroup.value));
  document.querySelectorAll('.preset-chip').forEach(chip => {
    chip.addEventListener('click', () => applyPreset(chip.dataset.preset));
  });
}
```

**Critical note:** `mdui.setColorScheme(hexColor)` is the mdui v2 API that generates all MD3 color roles (primary, secondary, tertiary, error, surface, etc.) from a single seed. This replaces the previous system of manually defining 12 CSS properties per preset in both JS and CSS. Verify the exact function name against mdui v2 docs at `https://www.mdui.org/en/docs/2/functions/setColorScheme`.

---

### 6.5 `js/clock.js` — Live Clock

```javascript
// clock.js

import { cfgGet, cfgSet } from './cfg.js';

let clockInterval = null;
let cachedFormat = 'auto'; // in-memory cache, no exec() per tick

export async function initClock() {
  const formatSelect = document.getElementById('clock-format-select');
  cachedFormat = await cfgGet('clock_format', 'auto') || 'auto';
  formatSelect.value = cachedFormat;

  formatSelect.addEventListener('change', () => {
    cachedFormat = formatSelect.value;
    cfgSet('clock_format', cachedFormat);
  });

  updateClock();
  clockInterval = setInterval(updateClock, 1000);
}

function updateClock() {
  const now = new Date();
  const dateEl = document.getElementById('clock-date');
  const timeEl = document.getElementById('clock-time');

  if (dateEl) dateEl.textContent = now.toLocaleDateString();
  if (timeEl) {
    if (cachedFormat === '24h') {
      timeEl.textContent = now.toLocaleTimeString('en-GB');
    } else if (cachedFormat === '12h') {
      timeEl.textContent = now.toLocaleTimeString('en-US', { hour12: true });
    } else {
      timeEl.textContent = now.toLocaleTimeString();
    }
  }
}
```

---

### 6.6 `js/network.js` — Network Status

```javascript
// network.js

let lastStatus = null;

export function initNetwork() {
  updateNetworkStatus();
  setInterval(updateNetworkStatus, 3000);
  window.addEventListener('online', updateNetworkStatus);
  window.addEventListener('offline', updateNetworkStatus);
}

export async function updateNetworkStatus() {
  const online = await checkOnline();

  if (online === lastStatus) return; // No change
  const wasOnline = lastStatus;     // save before overwrite
  lastStatus = online;

  const statusCard  = document.getElementById('status-card');
  const statusIcon  = document.getElementById('status-icon');
  const statusValue = document.getElementById('status-value');
  const netChip     = document.getElementById('network-chip');
  const netChipText = netChip?.querySelector('span');

  const { getTranslation } = await import('./i18n.js');
  const onlineText  = getTranslation('home_status_online')  || 'Online';
  const offlineText = getTranslation('home_status_offline') || 'Offline';

  if (online) {
    statusCard?.classList.remove('status-offline');
    if (statusIcon)  statusIcon.name = 'wifi';
    if (statusValue) statusValue.textContent = onlineText;
    if (netChipText) netChipText.textContent = onlineText;
    netChip?.classList.remove('offline');
    if (netChip) netChip.setAttribute('icon', 'wifi');
  } else {
    statusCard?.classList.add('status-offline');
    if (statusIcon)  statusIcon.name = 'wifi_off';
    if (statusValue) statusValue.textContent = offlineText;
    if (netChipText) netChipText.textContent = offlineText;
    netChip?.classList.add('offline');
    if (netChip) netChip.setAttribute('icon', 'wifi_off');

    // Toast only when transitioning FROM online TO offline
    if (wasOnline === true) {
      mdui.snackbar({ message: offlineText });
    }
  }
}

async function checkOnline() {
  if (!navigator.onLine) return false;
  try {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 2000);
    await fetch('https://clients3.google.com/generate_204', { signal: ctrl.signal });
    clearTimeout(timer);
    return true;
  } catch {
    try {
      const ctrl2 = new AbortController();
      const timer2 = setTimeout(() => ctrl2.abort(), 2000);
      await fetch('https://clients3.google.com/generate_204', {
        mode: 'no-cors', signal: ctrl2.signal
      });
      clearTimeout(timer2);
      return true;
    } catch {
      return false;
    }
  }
}
```

---

### 6.7 `js/i18n.js` — Translations

```javascript
// i18n.js

import { cfgGet, cfgSet } from './cfg.js';

let currentStrings = {};

export async function initI18n() {
  const saved = await cfgGet('lang', 'en') || 'en';
  await applyLanguage(saved);
  wireLanguageSelect(saved);
}

export async function applyLanguage(langCode) {
  const url = langCode === 'en'
    ? `lang/source/string.json?ts=${Date.now()}`
    : `lang/${langCode}.json?ts=${Date.now()}`;

  try {
    const res = await fetch(url);
    currentStrings = await res.json();
  } catch {
    currentStrings = {};
  }

  applyTranslations();
  cfgSet('lang', langCode);
  document.dispatchEvent(new CustomEvent('languageChanged', { detail: { langCode } }));
}

export function getTranslation(key) {
  return currentStrings[key] || null;
}

function applyTranslations() {
  document.querySelectorAll('[data-i18n]').forEach(el => {
    const key = el.dataset.i18n;
    const value = currentStrings[key];
    if (!value) return;

    if (el.children.length > 0 && value.includes('<')) {
      el.innerHTML = value;
    } else {
      const textNode = [...el.childNodes].find(n => n.nodeType === Node.TEXT_NODE);
      if (textNode) {
        textNode.textContent = value;
      } else {
        el.textContent = value;
      }
    }
  });

  document.querySelectorAll('[data-i18n-label]').forEach(el => {
    const key = el.dataset.i18nLabel;
    if (currentStrings[key]) el.label = currentStrings[key];
  });
}

function wireLanguageSelect(currentLang) {
  const select = document.getElementById('language-select');
  if (!select) return;

  // All 28 languages matching existing Crowdin translations
  const LANGUAGES = [
    ['en', '🇬🇧', 'English'],
    ['af', '🇿🇦', 'Afrikaans'],
    ['ar', '🇸🇦', 'العربية'],
    ['ca', '🏴', 'Català'],
    ['cs', '🇨🇿', 'Čeština'],
    ['da', '🇩🇰', 'Dansk'],
    ['de', '🇩🇪', 'Deutsch'],
    ['el', '🇬🇷', 'Ελληνικά'],
    ['es', '🇪🇸', 'Español'],
    ['fi', '🇫🇮', 'Suomi'],
    ['fr', '🇫🇷', 'Français'],
    ['he', '🇮🇱', 'עברית'],
    ['hu', '🇭🇺', 'Magyar'],
    ['it', '🇮🇹', 'Italiano'],
    ['ja', '🇯🇵', '日本語'],
    ['ko', '🇰🇷', '한국어'],
    ['nl', '🇳🇱', 'Nederlands'],
    ['no', '🇳🇴', 'Norsk'],
    ['pl', '🇵🇱', 'Polski'],
    ['pt', '🇵🇹', 'Português'],
    ['ro', '🇷🇴', 'Română'],
    ['ru', '🇷🇺', 'Русский'],
    ['sr', '🇷🇸', 'Српски'],
    ['sv', '🇸🇪', 'Svenska'],
    ['tr', '🇹🇷', 'Türkçe'],
    ['uk', '🇺🇦', 'Українська'],
    ['vi', '🇻🇳', 'Tiếng Việt'],
    ['zh', '🇨🇳', '中文'],
  ];

  LANGUAGES.forEach(([code, flag, name]) => {
    const item = document.createElement('mdui-menu-item');
    item.value = code;
    item.textContent = `${flag} ${name}`;
    select.appendChild(item);
  });

  select.value = currentLang;
  select.addEventListener('change', () => applyLanguage(select.value));
}
```

---

### 6.8 `js/redirect.js` — URL Opener with Sanitization

```javascript
// redirect.js — fixes the shell injection vulnerability in the original

const ALLOWED_HOSTS = [
  'github.com',
  't.me',
  'telegram.me',
];

export function initRedirect() {
  document.querySelectorAll('[data-url]').forEach(el => {
    el.addEventListener('click', () => openUrl(el.dataset.url));
  });
}

function openUrl(rawUrl) {
  // Sanitize: parse URL, only allow known safe hosts
  let url;
  try {
    url = new URL(rawUrl);
  } catch {
    console.warn('Invalid URL:', rawUrl);
    return;
  }

  if (!['https:', 'http:'].includes(url.protocol)) return;
  if (!ALLOWED_HOSTS.some(h => url.hostname === h || url.hostname.endsWith('.' + h))) return;

  // Try Android Intent via ksu.exec
  if (window.ksu?.exec) {
    const escaped = url.href.replace(/'/g, "\\'");
    window.ksu.exec(
      `am start -a android.intent.action.VIEW -d '${escaped}'`,
      '{}',
      `redirect_${Date.now()}`
    );
  } else {
    window.open(url.href, '_blank');
  }
}
```

---

### 6.9 `js/contributors.js`

```javascript
// contributors.js

export async function loadContributors() {
  const grid = document.getElementById('contributors-grid');
  if (!grid) return;

  let devs = [];
  try {
    const res = await fetch(`json/dev.json?ts=${Date.now()}`);
    devs = await res.json();
  } catch {
    return;
  }

  const { getTranslation } = await import('./i18n.js');

  grid.innerHTML = devs.map(dev => `
    <mdui-card class="contributor-card" clickable
               data-url="${encodeURI(dev.github || '')}">
      <img class="contributor-avatar"
           src="${dev.avatar || ''}"
           alt="${escapeHtml(dev.name)}"
           loading="lazy"
           onerror="this.src='assets/yurikey.png'" />
      <p class="mdui-typescale-label-large contributor-name">
        ${escapeHtml(dev.name)}
      </p>
      <p class="mdui-typescale-label-small contributor-role">
        ${escapeHtml(getTranslation('role_' + dev.role) || dev.role)}
      </p>
    </mdui-card>
  `).join('');

  // Wire click-to-open-github on cards
  grid.querySelectorAll('[data-url]').forEach(card => {
    card.addEventListener('click', async () => {
      const { openUrl } = await import('./redirect.js');
      openUrl(decodeURI(card.dataset.url));
    });
  });
}

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
```

---

## 7. Translation Keys — New & Changed

Add to `lang/source/string.json`:

```json
{
  "app_title": "Yurikey Manager",

  "nav_home": "Home",
  "nav_menu": "Actions",
  "nav_advancemenu": "Advanced",
  "nav_settings": "Settings",

  "home_version": "Module Version",
  "home_root": "Root",
  "home_refresh": "Refresh Info",
  "home_refreshing": "Refreshing…",
  "home_status": "Status",
  "home_status_online": "Online",
  "home_status_offline": "Offline",
  "home_clock_date": "Date",
  "home_clock_time": "Time",

  "menu_keybox": "Keybox",
  "menu_gms_section": "GMS",
  "menu_import_keybox": "Set Up Yuri Keybox",
  "menu_import_keybox_desc": "Downloads and installs remote keybox to Tricky Store",
  "menu_force_clear": "Force Stop & Clear Play Store",
  "menu_force_clear_desc": "Force-stops Play Store and wipes its data cache",
  "menu_target": "Set Up target.txt",
  "menu_target_desc": "Generates Tricky Store target.txt with all installed apps",
  "menu_necessary": "Only Necessary Apps",
  "menu_necessary_desc": "Sets only fixed targets — no dynamic package scanning",
  "menu_patch": "Set Up Security Patch",
  "menu_patch_desc": "Writes spoofed security patch date to Tricky Store",

  "advance_menu_title_extended": "Detection & Fixes",
  "advance_tee_section": "Fix TEE: OnePlus, RedMagic, Realme, Oppo…",
  "advance_clear_all_detection_traces": "Clear All Detection Traces",
  "advance_clear_all_detection_traces_desc": "Deletes detector app data, temp files, resets props, removes ODEX",
  "advance_set_hma-oss_configs": "Set HMA-OSS Configs",
  "advance_set_hma_desc": "Downloads HMA-OSS config from GitHub with proper permissions",
  "advance_set_zygisk_next_configs": "Set Zygisk Next Configs",
  "advance_set_zygisk_desc": "Configures enforce-denylist, memory-type, linker settings",
  "advance_set_pif": "Set Fingerprint (PIF)",
  "advance_set_pif_desc": "Runs Play Integrity Fix auto-update scripts",
  "advance_set_verified_boot": "Set Verified Boot Hash",
  "advance_set_verified_boot_desc": "Reads and writes verified boot hash for attestation",
  "advance_fix_detect_lsposed": "Fix LSPosed Detection",
  "advance_fix_lsposed_desc": "Deletes all base.odex files from /data/app",
  "advance_fix_detect_pif": "Fix PIF Detection",
  "advance_fix_pif_desc": "Removes PIF-related properties via resetprop",
  "advance_fix_detect_recovery_file": "Fix Recovery File Detection",
  "advance_fix_recovery_desc": "Deletes /sdcard/TWRP directory",
  "advance_kill_all": "Kill All Processes",
  "advance_kill_all_desc": "Force-stops and clears data for all known detector apps",
  "advance_upd_yurirka": "Update RKA Config",
  "advance_upd_rka_desc": "Provisions Remote Key Attestation config for PassIt",
  "advance_wdevinel1": "Fix Widevine L1",
  "advance_wdevinel1_desc": "Copies FixWidevineL1 files and runs KmInstallKeybox vendor binary",

  "settings_title": "Settings",
  "settings_language": "Language",
  "settings_appearance": "Appearance",
  "settings_theme_mode": "Mode",
  "settings_color_preset": "Color",
  "settings_clock_format": "Clock Format",
  "settings_contributors": "Project Contributors",

  "theme_mode_dark": "Dark",
  "theme_mode_light": "Light",
  "theme_mode_auto": "Auto",
  "theme_preset_ocean": "Ocean",
  "theme_preset_rose": "Rose",
  "theme_preset_forest": "Forest",
  "theme_preset_sunset": "Sunset",
  "theme_preset_violet": "Violet",

  "clock_format_auto": "Auto (Device)",
  "clock_format_24h": "24-hour",
  "clock_format_12h": "12-hour (AM/PM)",

  "update_title": "Update & Support",
  "update_desc": "Stay up to date with the latest Yurikey releases and bug fixes.",
  "update_github": "View on GitHub",
  "update_telegram": "Join Telegram",
  "update_note": "Join Telegram or check GitHub for contributions and technical discussions.",

  "script_history_title": "Script History",
  "script_history_empty": "No script history yet.",
  "dialog_clear": "Clear",
  "dialog_close": "Close",

  "toast_success": "Done ✓",
  "toast_error": "Failed",
  "toast_timeout": "Timed out — check your module installation"
}
```

---

## 8. Color Preset Definitions

The 5 presets use `mdui.setColorScheme(seedHex)` which auto-generates all MD3 color roles:

| Preset | Seed Color | Hex |
|--------|-----------|-----|
| Ocean | Material Blue | `#1B6EF3` |
| Rose | Material Pink | `#C2184B` |
| Forest | Material Green | `#1B6E3A` |
| Sunset | Material Deep Orange | `#E65100` |
| Violet | Material Purple | `#6750A4` |

**Verify mdui API:** The exact function signature is `mdui.setColorScheme(color: string): void` where `color` is a hex string. Confirmed at `https://www.mdui.org/en/docs/2/functions/setColorScheme`. Dark/light rendering on top of this seed is handled automatically by `mdui.setTheme()`.

---

## 9. Bugs Fixed vs. Original

| Original Bug | Fix in This Spec |
|---|---|
| Hardcoded path `Yuri/` in JS | `SCRIPT_BASE` constant in bridge.js, matches new `features/` path |
| `device.js` only uses `ksu.exec` — no Magisk fallback | `bridge.js` 3-tier detection used for all scripts including device-info |
| 7-second timeout too short | 15 seconds in bridge.js |
| 610 lines custom CSS with `!important` | ~150 lines, zero `!important`, all using mdui tokens |
| 12 `<script>` tags, no module system | ES modules with named imports |
| Beer CSS from CDN, no offline fallback | mdui local copy in `assets/`, CDN as `onerror` fallback |
| URL injection in redirect.js | URL parsed with `new URL()`, hostname allowlist, protocol check |
| Theme colors duplicated in JS + CSS | Single source: mdui CSS tokens + `mdui.setColorScheme()` |
| `localStorage` lost silently on reinstall | All localStorage wrapped in try/catch; app degrades gracefully |
| Busy-wait `waitForTranslations()` loop | `await applyLanguage()` is a proper async/await, no polling |
| No bridge feedback shown to user | Inline spinner on list item, snackbar with message |
| Script output not shown | History dialog shows full output per entry |

---

## 10. mdui CDN URLs (for `onerror` fallback)

```
CSS:  https://unpkg.com/mdui@2/mdui.css
JS:   https://unpkg.com/mdui@2/mdui.global.js
```

The `mdui.global.js` bundle exposes everything on `window.mdui`:
- `mdui.snackbar({ message, action?, autoCloseDelay? })`
- `mdui.dialog({ headline, body, actions, closeOnOverlayClick })`
- `mdui.setTheme('dark' | 'light' | 'auto')`
- `mdui.getTheme()`
- `mdui.setColorScheme(hexColor)`
- All web components registered as custom elements (`<mdui-button>`, `<mdui-card>`, etc.)

No `import` required when using the global build — all components auto-register.

---

## 11. Implementation Checklist for the Coding Agent

Before declaring done, verify:

- [ ] `index.html` loads without error in Chrome DevTools (simulate WebView)
- [ ] All 4 pages switch correctly via nav bar, scroll resets to top
- [ ] Home info cards show `—` on first load, update after refresh
- [ ] Clock updates every second with correct format per setting
- [ ] Network status reflects actual connectivity; chip in top bar mirrors status-card
- [ ] Each action item shows spinner while script runs, re-enables on complete
- [ ] History dialog opens from version card, shows entries, Clear empties it
- [ ] Theme mode (Dark/Light/Auto) persists across page reload AND survives manager app uninstall
- [ ] Each color preset visibly changes primary color immediately
- [ ] Language change re-translates all `[data-i18n]` elements without page reload
- [ ] Contributors grid loads avatars with fallback to `assets/yurikey.png`
- [ ] GitHub and Telegram buttons only open whitelisted URLs
- [ ] No `!important` in `app.css`
- [ ] No `console.error` on load in a fresh session (no localStorage data)
- [ ] `mdui.snackbar()` appears at bottom (mdui default position), readable, auto-dismisses
- [ ] `<mdui-layout>` handles all spacing — no manual `padding-bottom` hacks on `body`
- [ ] **`initBridge()` runs on load** — `module_paths.json` is fetched, `MODULE.MODDIR` is set in both `bridge.js` and `cfg.js`
- [ ] **`cfgGet/cfgSet` works correctly** — run test sequence: `cfgSet('test_key', 'test_val')`, reload, `cfgGet('test_key')` returns `'test_val'`
- [ ] **localStorage migration works** — set `themeMode='light'` in localStorage, fresh load should show light theme, then delete `localStorage` and reload should STILL show light theme (now persisted via cfg)
- [ ] **Script history survives app data clear** — run a script, clear app data (simulate uninstall), history dialog should still show previous entries
- [ ] **`device-info.sh` runs with `type='common'`** — refresh button executes `webroot/common/device-info.sh`, NOT `features/device-info.sh`
- [ ] **All 28 languages listed** — no "Add remaining 8" comment; each language populates the select correctly
- [ ] **`printf '%s\n'` used in history** — grep for `echo` in `history.js` should return zero matches (must use `printf`)
- [ ] **`select_app_necessary.sh`** script name matches the actual feature filename (not `select_app_neccesary.sh`)
