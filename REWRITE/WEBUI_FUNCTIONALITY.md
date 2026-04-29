# YuriKey WebUI — Full Functionality Reference

> This document exhaustively describes every feature, screen, action, data point, and behavior of the current YuriKey WebUI. Use this as the source of truth for UI/UX redesign planning.

---

## 1. Architecture Overview

### Current Tech Stack
- **Runtime**: Android WebView (served by KernelSU Manager or MMRL)
- **CSS Framework**: Beer CSS v3.9.8 (loaded from CDN) + 610 lines custom CSS
- **JS**: 12 separate vanilla JS files (~1000 lines total), no bundler
- **Icons**: Google Material Symbols Rounded (loaded from CDN font)
- **i18n**: 28 languages via Crowdin, stored as `lang/*.json` files, `en` → `source/string.json`

### JS File Breakdown
| File | Lines | Purpose |
|------|-------|---------|
| `js/main.js` | 51 | Entry point: wires all buttons, history dialog, refresh |
| `js/device.js` | 109 | Device info display + refresh mechanism |
| `js/version.js` | 30 | Reads module version from `module.prop` |
| `js/theme.js` | 242 | Dark/light mode, 5 color presets, snackbar color customization |
| `js/redirect.js` | 39 | URL opening via Android Intent |
| `js/dev.js` | 43 | Loads and renders contributors from JSON |
| `js/utils/i18n.js` | 138 | Translation loader + language dropdown |
| `js/utils/toast.js` | 22 | Snackbar toast notifications |
| `js/utils/scriptExecutor.js` | 169 | Script execution with 3-way bridge detection + history |
| `js/components/navigation.js` | 13 | Bottom tab navigation switching |
| `js/components/clock.js` | 94 | Live clock with format selection |
| `js/components/networkStatus.js` | 85 | Internet connectivity checker |

### Config
- **`config.json`**: `{"title":"Yurikey Manager","icon":"yurikey.png","windowResize":false,"exitConfirm":false}`
- **Path**: `/data/adb/modules/Yurikey/webroot/`

---

## 2. Screens / Pages

The app has **4 tabbed pages** via a fixed bottom navigation bar.

### 2.1 Home Page (`#home-page`)

**Header**: "Yurikey Manager" title

**Top Controls Row:**
| Element | Action |
|---------|--------|
| **Module Version card** (clickable) | Opens **Script History dialog** |
| **Refresh Info button** | Runs `device-info.sh`, re-reads device info JSON, updates network status |

**Info Cards (6-card grid):**
| Card | Data Source | Update Method |
|------|-------------|---------------|
| **Clock Date** | `new Date().toLocaleDateString()` | Every 1s via `setInterval` |
| **Clock Time** | `new Date().toLocaleTimeString()` | Every 1s via `setInterval` |
| **Status** (Online/Offline) | `navigator.onLine` + `fetch("https://clients3.google.com/generate_204")` | Every 3s via `setInterval`, also on `online`/`offline` events |
| **Android** | `/json/device-info.json` → `android` field | On page load + Refresh button |
| **Kernel** | `/json/device-info.json` → `kernel` field | On page load + Refresh button |
| **Root Implementation** | `/json/device-info.json` → `root` field | On page load + Refresh button |

**Status detection logic:**
1. Check `navigator.onLine`
2. If true, try `fetch("https://clients3.google.com/generate_204")` with 2s timeout
3. If that fails, retry with `mode: "no-cors"` as fallback
4. Returns true/false. Changes trigger toast notification when going offline.

**device-info.json structure** (written by `device-info.sh`):
```json
{
  "android": "14",
  "kernel": "5.10.xxx",
  "root": "Magisk|KernelSU|KernelSU-Next|SukiSU-Ultra|APatch|Unknown"
}
```

### 2.2 Main Menu Page (`#actions-page`)

**Header**: "Main Menu"

**Section: Keybox**
| Button | Script | Function |
|--------|--------|----------|
| **Set Up Yuri Keybox** | `yuri_keybox.sh` | Downloads remote keybox, base64-decodes, writes to `/data/adb/tricky_store/keybox.xml` |

**Section: GMS**
| Button | Script | Function |
|--------|--------|----------|
| **Force Stop & Clear Data Play Store** | `kill_google_process.sh` | Force-stops Play Store + clears its cache |
| **Set up target.txt** | `target_txt.sh` | Generates Tricky Store `target.txt` with fixed targets + all installed user/system apps |
| **Set Necessary App** | `select_app_neccesary.sh` | Same as target.txt but ONLY fixed targets (no dynamic package scanning) |
| **Set up Security Patch** | `security_patch.sh` | Writes spoofed security patch date to Tricky Store |
| **Set Verified Boothash** | `boot_hash.sh` | Reads + writes verified boot hash |

### 2.3 Advanced Menu Page (`#advance-menu`)

**Header**: "Advanced Menu"

**Section: Menu +**
| Button | Script | Function |
|--------|--------|----------|
| **Clear all detection traces** | `clear_all_detection_traces.sh` | Aggressive cleanup: deletes detector app data, temp files, resets props, deletes ODEX |
| **Set HMA-oss configs** | `hma.sh` | Downloads HMA-OSS config from GitHub, writes with proper permissions |
| **Set Zygisk Next configs** | `znctl.sh` | Configures Zygisk Next (enforce-denylist, memory-type, linker) |
| **Set fingerprint (PIF)** | `pif.sh` | Runs Play Integrity Fix auto-update scripts |
| **Fix LSPosed Detection** | `lsposed2.sh` | Deletes all `base.odex` from `/data/app` |
| **Fix PIF Detection** | `pif2.sh` | Removes pif-related properties via resetprop |
| **Fix Recovery File Detection** | `twrp.sh` | Deletes `/sdcard/TWRP` directory |
| **Kill All Process** | `kill_all.sh` | Force-stops + clears data for all known detector apps |
| **Update RKA config** | `yurirka.sh` | Provisions Remote Key Attestation for PassIt |

**Section: Fix TEE broken** (Oneplus, Redmagic, Realme, Oppo,...)
| Button | Script | Function |
|--------|--------|----------|
| **Fix Widevine L1** | `widevinel1.sh` | Copies FixWidevineL1 files, runs KmInstallKeybox vendor binary |

### 2.4 Settings Page (`#settings-page`)

**Header**: "Settings"

**Language**
- Custom dropdown with 28 languages (Afrikaans → Chinese)
- Flag emoji + language name shown
- Selection loads corresponding `lang/{code}.json` translations
- Persisted to `localStorage.setItem("selectedLanguage", langCode)`
- English loads from `lang/source/string.json`

**Appearance**
- **Theme Mode**: Dark / Light / Auto (System) — custom dropdown
- **Theme Presets**: 5 color schemes — Ocean, Rose, Forest, Sunset, Violet — as toggle buttons
- Dark/light mode switch: changes `data-theme-mode` on `<html>` + applies preset colors
- Auto mode listens to `matchMedia("(prefers-color-scheme: light)")`
- Persisted to `localStorage` (`themeMode`, `themePreset`)
- Theme system applies 12 CSS custom properties per mode per preset via JS

**Clock Format**
- Custom dropdown: Auto (Device) / 24-hour / 12-hour (AM/PM)
- Persisted to localStorage (`clockFormat`)

**Update & Support**
- Description text with HTML (`<strong>` preserved in translation)
- **View on GitHub** button — opens `https://github.com/Yurii0307/yurikey` via Android Intent
- **Join Telegram Channel** button — opens `https://t.me/yuriiroot` via Android Intent
- Footer note about joining community

**Project Contributors**
- Loads contributors from `/json/dev.json`
- Renders each as a card with avatar (GitHub profile picture), name, role
- Cards are clickable → opens contributor's GitHub profile via Intent
- Role supports translation via `data-i18n="role_{RoleText}"`

---

## 3. Shared / Cross-Cutting Features

### 3.1 Bottom Navigation Bar
- 4 tabs: Home, Menu, Menu +, Settings
- Active tab highlighted with colored background
- Click swaps `active` class on both the nav button and the section page
- Scrolls to top on page switch

### 3.2 Script Execution System
**Bridge Detection** (3-tier, in `scriptExecutor.js`):
1. `window.YuriKeyHost?.execScript` — MMRL bridge (Magisk)
2. `window.execYurikeyScript` — Legacy MMRL bridge (Magisk)
3. `window.ksu?.exec` — KernelSU/APatch native bridge

**Execution Flow:**
1. Button click → `runScript(scriptName, basePath, button)` in `main.js`
2. `basePath` is hardcoded: `/data/adb/modules/Yurikey/Yuri/`
3. Adds `executing` CSS class to button for visual feedback
4. Generates a unique callback name `cb_{timestamp}_{random}`
5. Calls `executeScript(scriptPath, scriptName, cbName)`
6. Sets **7-second timeout** — if no response, shows error toast
7. On response: removes `executing` class, calls `handleScriptResult`
8. **7s timeout** if no response

**Result Handling:**
- Empty output → success toast
- JSON output with `{success: true}` → capture output, success toast
- JSON output with `{success: false}` → capture output, error toast
- Non-JSON output → success toast (treats as success)
- All output (success or failure) → saved to **Script History**

### 3.3 Script History
- Stored in `localStorage` as `scriptHistoryLogs` array (max 80 entries)
- Each entry: `{script, output, time}`
- Accessed via **click on Module Version card** (Home page)
- Opens a modal dialog with:
  - Scrollable output area with HTML-safe rendering (escaped, `<br>` for newlines)
  - **Clear** button → empties history
  - **Close** button
  - Overlay blur backdrop

### 3.4 Toast Notification System
- Fixed snackbar at top center of screen
- 4 types: `info` (blue), `success` (green), `warning` (yellow), `error` (red)
- Auto-dismiss after configurable duration (default: 3s, error: 4s)
- Colorized via CSS custom properties (customizable per-type)
- Uses `showToast(message, type, duration)` — also has convenience wrappers

### 3.5 URL Opening
- Buttons with `data-url` attribute trigger `openUrlViaIntent(url)`
- Constructs `am start -a android.intent.action.VIEW -d '{url}'` command
- Executed via KernelSU bridge (`ksu.exec`)
- **No URL validation or sanitization** (shell injection possible)
- Fallback: `window.open(url, "_blank")` → `window.location.href = url` for desktop browsers

### 3.6 i18n System
- All static text marked with `data-i18n="key"` attribute
- `en` language → loads `lang/source/string.json`
- Other languages → loads `lang/{code}.json`
- Cache-busted via `?ts=Date.now()` query parameter
- Applied via `document.querySelectorAll("[data-i18n]")` loop
- **HTML-aware**: if element has children AND innerHTML contains `<`, uses `innerHTML`; otherwise replaces first text node
- Fires `languageChanged` custom event on translation complete
- Calls `updateNetworkStatus()` after language change to re-translate status text
- Also supports `data-i18n-label` attribute (for MWC components in the new design)

---

## 4. Data Flows

### 4.1 Initialization Sequence
```
DOMContentLoaded
  ├── main.js
  │   ├── Wire all [data-script] buttons in #actions-page → runScript
  │   ├── Wire all [data-script] buttons in #advance-menu → runScript
  │   ├── Wire module-version-card click → openHistoryDialog
  │   ├── Wire history dialog buttons (close, clear)
  │   └── Wire refresh-info-btn click → run device-info.sh + loadDeviceInfo + updateNetworkStatus
  ├── device.js
  │   ├── waitForTranslations() (busy-poll up to 3s)
  │   ├── loadDeviceInfo() (fetch /json/device-info.json)
  │   └── setupRefreshButton() (animation + re-fetch with polling)
  ├── version.js
  │   └── loadVersionFromModuleProp() — exec(`grep '^version=' ...`)
  ├── i18n.js (auto-executes)
  │   ├── applyLanguage(localStorage.lang || 'en')
  │   └── setupLanguageDropdown()
  ├── theme.js (auto-executes)
  │   ├── applyThemeMode(localStorage.themeMode || 'dark')
  │   ├── applyThemePreset(localStorage.themePreset || 'ocean')
  │   ├── applySnackbarColors()
  │   └── bindSnackbarColorInputs()
  ├── networkStatus.js (auto-executes, 500ms delay)
  │   └── updateNetworkStatus() → setInterval(3s)
  ├── clock.js (auto-executes)
  │   ├── setupClockFormatDropdown()
  │   └── updateClock() → setInterval(1s)
  ├── dev.js (auto-executes)
  │   └── loadContributors() → fetch json/dev.json → render cards
  └── redirect.js (auto-executes)
      └── setupIntentLinks() → wire all [data-url]
```

### 4.2 Script Execution Flow
```
Button click
  → runScript(scriptName, basePath, button)
    → getScriptExecutor() (3-tier bridge detection)
    → showToast("Executing...", "info")
    → ksu.exec("sh '/data/adb/modules/Yurikey/Yuri/{script}'", "{}", callbackName)
    → [7s timeout]
    → callback receives output string
    → handleScriptResult(output, scriptName)
      → if JSON {success: true}: capture .output, show success toast
      → if JSON {success: false}: capture raw, show error toast
      → if plain text: treat as success, show success toast
      → addScriptHistory(scriptName, output) → localStorage
```

### 4.3 Device Info Refresh Flow
```
Refresh button click
  → button.rotating class added (CSS animation)
  → button.disabled = true
  → runScript("device-info.sh") via ksu.exec
    → device-info.sh writes /json/device-info.json
  → callback fires
  → waitForValidDeviceInfo() (poll up to 4s, every 400ms)
    → fetch("/json/device-info.json?ts=...")
    → check data.android || data.kernel || data.root is non-empty
  → update UI cards (Android, Kernel, Root)
  → button.rotating removed
  → button.disabled = false
```

---

## 5. Scripts Referenced by WebUI

| Script | Location | Path in data-adb |
|--------|----------|-----------------|
| `yuri_keybox.sh` | `Module/Yuri/yuri_keybox.sh` | `/data/adb/modules/Yurikey/Yuri/yuri_keybox.sh` |
| `kill_google_process.sh` | `Module/Yuri/kill_google_process.sh` | `/data/adb/modules/Yurikey/Yuri/kill_google_process.sh` |
| `target_txt.sh` | `Module/Yuri/target_txt.sh` | `/data/adb/modules/Yurikey/Yuri/target_txt.sh` |
| `select_app_neccesary.sh` | `Module/Yuri/select_app_neccesary.sh` | `/data/adb/modules/Yurikey/Yuri/select_app_neccesary.sh` |
| `security_patch.sh` | `Module/Yuri/security_patch.sh` | `/data/adb/modules/Yurikey/Yuri/security_patch.sh` |
| `boot_hash.sh` | `Module/Yuri/boot_hash.sh` | `/data/adb/modules/Yurikey/Yuri/boot_hash.sh` |
| `clear_all_detection_traces.sh` | `Module/Yuri/clear_all_detection_traces.sh` | `/data/adb/modules/Yurikey/Yuri/clear_all_detection_traces.sh` |
| `hma.sh` | `Module/Yuri/hma.sh` | `/data/adb/modules/Yurikey/Yuri/hma.sh` |
| `znctl.sh` | `Module/Yuri/znctl.sh` | `/data/adb/modules/Yurikey/Yuri/znctl.sh` |
| `pif.sh` | `Module/Yuri/pif.sh` | `/data/adb/modules/Yurikey/Yuri/pif.sh` |
| `lsposed2.sh` | `Module/webroot/common/lsposed2.sh` | `/data/adb/modules/Yurikey/webroot/common/lsposed2.sh` |
| `pif2.sh` | `Module/webroot/common/pif2.sh` | `/data/adb/modules/Yurikey/webroot/common/pif2.sh` |
| `twrp.sh` | `Module/webroot/common/twrp.sh` | `/data/adb/modules/Yurikey/webroot/common/twrp.sh` |
| `kill_all.sh` | `Module/Yuri/kill_all.sh` | `/data/adb/modules/Yurikey/Yuri/kill_all.sh` |
| `yurirka.sh` | `Module/Yuri/yurirka.sh` | `/data/adb/modules/Yurikey/Yuri/yurirka.sh` |
| `widevinel1.sh` | `Module/webroot/common/widevinel1.sh` | `/data/adb/modules/Yurikey/webroot/common/widevinel1.sh` |
| `device-info.sh` | `Module/webroot/common/device-info.sh` | `/data/adb/modules/Yurikey/webroot/common/device-info.sh` |

**NEW architecture paths** (for the rewrite):
All scripts move from `Module/Yuri/` and `Module/webroot/common/` to `Module/features/` + `Module/webroot/common/device-info.sh`. Script names also change (e.g., `target_txt.sh` → `target.sh`, `yuri_keybox.sh` → `keybox.sh`, etc.).

---

## 6. Storage / Persistence

### localStorage Keys
| Key | Type | Used By | Purpose |
|-----|------|---------|---------|
| `selectedLanguage` | string | i18n.js | Language code (e.g., `"en"`, `"fr"`) |
| `themeMode` | string | theme.js | `"dark"`, `"light"`, `"auto"` |
| `themePreset` | string | theme.js | `"ocean"`, `"rose"`, `"forest"`, `"sunset"`, `"violet"` |
| `clockFormat` | string | clock.js | `"auto"`, `"24h"`, `"12h"` |
| `scriptHistoryLogs` | JSON array | scriptExecutor.js | Max 80 entries of `{script, output, time}` |
| `snackbarInfoColor` | hex string | theme.js | Custom snackbar colors (5 keys) |

### Runtime JSON Files
| File | Written By | Read By |
|------|-----------|---------|
| `/json/device-info.json` | `common/device-info.sh` | `device.js` (initial + refresh) |
| `/json/dev.json` | Static file (committed) | `dev.js` (contributors) |

---

## 7. Visual / UI Details

### Color System
- **610 lines of custom CSS** on top of Beer CSS framework
- 12 CSS custom properties per theme preset + dark/light mode
- Dark mode default: navy/dark blue background, blue accent (#9ecaff)
- Light mode: light blue background, dark blue accent (#0061a4)
- 5 color presets (ocean, rose, forest, sunset, violet) — each with dark + light variants
- Uses `color-mix()` CSS function for hover states and blends

### Layout
- Single-column responsive layout
- Bottom nav bar: fixed, pill-shaped, 4-tab, glassmorphism effect (blur + shadow)
- Home: 6 info cards in a responsive grid (auto-fit, min 200px columns)
- Menu pages: sections with headers and stacked buttons
- Settings: stacked sections with dropdowns and button groups

### Component Sizes (Mobile-first)
- Bottom nav: height ~56px, floating with margin
- Info cards: min-height 100px (90px on mobile)
- Buttons: pill-shaped, full-width, 46px+ min-height
- Dropdowns: custom (not native `<select>`), with arrow indicator

### Animations
- Button hover: background color transition
- Button active: translateY(1px) press effect
- Tab switch: smooth scroll to top
- Snackbar: opacity + translateY transition (0.25s)
- History overlay: backdrop-filter blur + opacity transition
- Contributor cards: translateY(-2px) on hover

---

## 8. Known Issues / Problems (for the redesign to fix)

| Issue | Severity |
|-------|----------|
| Hardcoded module path `/data/adb/modules/Yurikey/Yuri/` in JS | **Critical** |
| Script execution only works on KernelSU (`ksu.exec`) — no Magisk fallback in `device.js` | **High** |
| 7-second timeout for scripts — too short for slow operations | Medium |
| `localStorage` lost on manager app uninstall | **High** |
| Beer CSS loaded from CDN — no offline support | Medium |
| 610 lines of custom CSS with `!important` hacks | Medium |
| 12 separate `<script>` tags — slow loading | Low |
| No script execution output shown to user (only toast + history) | Low |
| Manual `waitForTranslations()` busy-poll loop | Low |
| `waitForValidDeviceInfo()` busy-poll loop after refresh | Low |
| URL injection vulnerability in `redirect.js` (no URL sanitization) | **High** |
| No MWC/component library fallback if CDN fails | Medium |
| Busy-wait pattern for translation loading | Low |
| Theme system duplicates color definitions in JS + CSS | Medium |

---

## 9. Translation Keys Used

The `data-i18n` attributes reference these keys (from `source/string.json`):

```
nav_home, nav_menu, nav_advancemenu, nav_settings
home_version, home_root, home_refresh, home_refreshing
home_status, home_status_online, home_status_offline
home_clock_date, home_clock_time
menu_title, menu_force_clear, menu_keybox, menu_import_keybox
menu_target, menu_necessary, menu_patch
advance_menu_title, advance_clear_all_detection_traces
advance_set_hma-oss_configs, advance_fix_detect_lsposed
advance_fix_detect_pif, advance_fix_detect_recovery_file
advance_kill_all, advance_wdevinel1, advance_set_verified_boot
advance_set_pif, advance_set_zygisk_next_configs
advance_upd_yurirka, advance_menu_title_extended
settings_title, settings_language, settings_appearance
settings_clock_format, settings_contributors
theme_mode_dark, theme_mode_light, theme_mode_auto
theme_preset_ocean, theme_preset_rose, theme_preset_forest
theme_preset_sunset, theme_preset_violet
clock_format_auto, clock_format_24h, clock_format_12h
update_title, update_desc, update_github, update_telegram, update_note
script_history_title, script_history_empty, dialog_clear, dialog_close
lang_en, lang_ja, ... (one per language)
role_{RoleText} (dynamic, one per contributor role)
```

---

## 10. Edge Cases & States

| State | Behavior |
|-------|----------|
| First load (no localStorage) | Dark mode, English, Auto clock, empty history |
| No internet | Status shows "Offline", error toast shown once on transition |
| Script execution fails | Error toast + entry in history with error message |
| Script execution times out (7s) | Error toast + "timeout" entry in history |
| No bridge available | Console warning in `device.js`; `main.js` shows "executor-unavailable" error |
| No device-info.json yet | Cards show "--" placeholders, retries every 400ms for 4s on refresh |
| Translation file missing | Keys show as raw `data-i18n` attribute values (English fallback) |
| Empty script history | Dialog shows "No script history yet" (translated via `script_history_empty`) |
| Language change | Re-applies i18n to all visible elements, updates network status text, saves to localStorage |
| Theme mode change | Re-applies preset colors for new mode, saves to localStorage |
| Preset change | Updates 12 CSS custom properties, saves to localStorage |
