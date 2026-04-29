const EXEC_TIMEOUT_MS = 15000;

let MODULE = null;

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

export function getModuleDir() {
  return MODULE?.MODDIR || null;
}

function scriptDir(type) {
  const dirs = { feature: 'features', common: 'webroot/common' };
  const sub = dirs[type] || 'features';
  return `${MODULE.MODDIR}/${sub}/`;
}

function getExecutor() {
  if (typeof window.ksu?.exec === 'function') return 'ksu';
  if (typeof window.YuriKeyHost?.execScript === 'function') return 'mmrl';
  if (typeof window.execYurikeyScript === 'function') return 'legacy-mmrl';
  return null;
}

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

export function exec(command) {
  return runScriptRaw(command);
}

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

function parseScriptOutput(raw) {
  if (!raw) return { success: true, rawOutput: '' };
  try {
    const json = JSON.parse(raw);
    return { success: json.success !== false, output: json.output || '', rawOutput: raw };
  } catch {
    return { success: true, rawOutput: raw };
  }
}
