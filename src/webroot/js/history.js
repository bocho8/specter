import { getModuleDir } from './cfg.js';

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
  const file = historyFile();
  const tmp = `${file}.tmp`;
  const entry = JSON.stringify({ script: scriptName, output, time: ts });
  const { exec } = await import('./bridge.js');
  await exec(
    `printf '%s\\n' '${entry.replace(/'/g, "'\\''")}' > "${tmp}" && ` +
    `cat "${file}" 2>/dev/null >> "${tmp}" && ` +
    `head -240 "${tmp}" > "${file}" && rm -f "${tmp}"`
  );
}

export async function clearHistory() {
  const { exec } = await import('./bridge.js');
  await exec(`printf '[]' > "${historyFile()}"`);
}

function escapeHtml(str) {
  return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

export async function openHistoryDialog() {
  const entries = await getHistory();
  const isEmpty = !entries || entries.length === 0;

  const content = isEmpty
    ? '<p class="mdui-typescale-body-medium empty-history" data-i18n="script_history_empty">No script history yet</p>'
    : entries.map(e => `
        <div class="history-entry">
          <p class="mdui-typescale-label-medium history-script">${escapeHtml(e.script)}</p>
          <p class="mdui-typescale-body-small history-time">${e.time}</p>
          <pre class="history-output">${escapeHtml(e.output)}</pre>
          <mdui-divider></mdui-divider>
        </div>
      `).join('');

  const { getTranslation } = await import('./i18n.js');

  mdui.dialog({
    headline: getTranslation('script_history_title') || 'Script History',
    body: `<div class="history-list">${content}</div>`,
    actions: [
      {
        text: getTranslation('dialog_clear') || 'Clear',
        onClick: async () => { await clearHistory(); openHistoryDialog(); return false; }
      },
      { text: getTranslation('dialog_close') || 'Close' }
    ],
    scrollTargetSelectors: '.history-list',
    closeOnOverlayClick: true,
  });
}
