import { exec as bridgeExec } from './bridge.js';

let MODULE = null;
let cache = {};
let flushTimer = null;
let pendingFlush = [];

export function setModuleDir(path) { MODULE = path; }

function shEscape(v) {
  return "'" + String(v).replace(/'/g, "'\\''") + "'";
}

async function readConfig(key) {
  if (!MODULE) return null;
  const { stdout } = await bridgeExec(
    `ksud module config get ${shEscape(key)} 2>/dev/null || cat ${shEscape(MODULE + '/config/' + key + '.val')} 2>/dev/null || true`
  );
  return stdout.trim() || null;
}

function writeConfig(key, val) {
  if (!MODULE) return;
  const cmd =
    `ksud module config set ${shEscape(key)} ${shEscape(val)} 2>/dev/null || ` +
    `mkdir -p ${shEscape(MODULE + '/config')} && printf '%s' ${shEscape(val)} > ${shEscape(MODULE + '/config/' + key + '.val')}`;
  bridgeExec(cmd).catch(err => console.warn('Config write failed for', key, err));
}

function deleteConfig(key) {
  if (!MODULE) return;
  const cmd =
    `ksud module config delete ${shEscape(key)} 2>/dev/null || rm -f ${shEscape(MODULE + '/config/' + key + '.val')} 2>/dev/null || true`;
  bridgeExec(cmd);
}

export async function cfgGet(key, defaultValue) {
  if (key in cache) return cache[key];
  const val = await readConfig(key);
  cache[key] = val ?? defaultValue;
  return cache[key];
}

export function cfgSet(key, val) {
  cache[key] = val;
  pendingFlush.push({ key, val });
  if (flushTimer) clearTimeout(flushTimer);
  flushTimer = setTimeout(() => {
    flushTimer = null;
    const batch = pendingFlush;
    pendingFlush = [];
    for (const { key: k, val: v } of batch) {
      writeConfig(k, v);
    }
  }, 500);
}

window.addEventListener('beforeunload', () => {
  if (flushTimer) clearTimeout(flushTimer);
  const batch = pendingFlush;
  pendingFlush = [];
  for (const { key, val } of batch) {
    bridgeExec(
      `ksud module config set ${shEscape(key)} ${shEscape(val)} 2>/dev/null || ` +
      `mkdir -p ${shEscape(MODULE + '/config')} && printf '%s' ${shEscape(val)} > ${shEscape(MODULE + '/config/' + key + '.val')}`
    ).catch(() => {});
  }
});

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
  } catch (e) {
    console.warn('Migration failed:', e);
  }
}
