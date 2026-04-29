let MODULE = null;
let cache = {};
let flushTimer = null;

export function setModuleDir(path) { MODULE = path; }
export function getModuleDir() { return MODULE; }

async function readConfig(key) {
  if (!MODULE) return null;
  const { exec } = await import('./bridge.js');
  const { stdout } = await exec(
    `ksud module config get "${key}" 2>/dev/null || cat "${MODULE}/config/${key}.val" 2>/dev/null || true`
  );
  return stdout.trim() || null;
}

function writeConfig(key, val) {
  if (!MODULE) return;
  const cmd =
    `ksud module config set "${key}" "${val}" 2>/dev/null || ` +
    `mkdir -p "${MODULE}/config" && printf '%s' "${val}" > "${MODULE}/config/${key}.val"`;
  import('./bridge.js').then(({ exec }) => exec(cmd));
}

function deleteConfig(key) {
  if (!MODULE) return;
  const cmd =
    `ksud module config delete "${key}" 2>/dev/null || rm -f "${MODULE}/config/${key}.val" 2>/dev/null || true`;
  import('./bridge.js').then(({ exec }) => exec(cmd));
}

export async function cfgGet(key, defaultValue) {
  if (key in cache) return cache[key];
  const val = await readConfig(key);
  cache[key] = val ?? defaultValue;
  return cache[key];
}

export function cfgSet(key, val) {
  cache[key] = val;
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
      if (val) {
        cache[newKey] = val;
        writeConfig(newKey, val);
      }
    }
    localStorage.setItem('_cfg_migrated', '1');
  } catch { }
}
