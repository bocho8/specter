import { getModuleDir } from './cfg.js';

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
  const { runScript } = await getBridge();
  try {
    await runScript('device-info.sh', 'common');
  } catch { }
  await waitForValidDeviceInfo();
}

async function loadDeviceInfo() {
  try {
    const res = await fetch(`${INFO_URL}?ts=${Date.now()}`);
    const data = await res.json();
    applyDeviceInfo(data);
  } catch { }
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
    } catch { }
    await new Promise(r => setTimeout(r, intervalMs));
  }
}

function applyDeviceInfo(data) {
  setText('android-value', data.android || '—');
  setText('kernel-value', data.kernel || '—');
  setText('root-value', data.root || '—');
}

export async function loadVersion() {
  const { runScriptRaw } = await getBridge();
  try {
    const { stdout } = await runScriptRaw(
      `grep '^version=' "${getModuleDir()}/module.prop" | cut -d'=' -f2`
    );
    if (stdout) setText('version-value', stdout.trim());
  } catch {
    try {
      const res = await fetch('/module.prop');
      const text = await res.text();
      const match = text.match(/^version=(.+)$/m);
      if (match) setText('version-value', match[1].trim());
    } catch { }
  }
}

function setText(id, value) {
  const el = document.getElementById(id);
  if (el) el.textContent = value;
}
