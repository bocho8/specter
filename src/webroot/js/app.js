import { initBridge, runScript, getModuleDir as getBridgeModuleDir } from './bridge.js';
import { setModuleDir, migrateLocalStorage, cfgGet } from './cfg.js';
import { initDevice, refreshDevice } from './device.js';
import { initClock } from './clock.js';
import { initNetwork } from './network.js';
import { initTheme } from './theme.js';
import { initI18n } from './i18n.js';
import { loadContributors } from './contributors.js';
import { initRedirect } from './redirect.js';
import { openHistoryDialog, addEntry } from './history.js';

document.addEventListener('DOMContentLoaded', async () => {
  await initBridge();
  setModuleDir(getBridgeModuleDir());
  await migrateLocalStorage();

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

function wireActions() {
  document.querySelectorAll('.action-item[data-script]').forEach(item => {
    item.addEventListener('click', async () => {
      if (item.disabled) return;

      const scriptName = item.dataset.script;
      const spinner = item.querySelector('.action-spinner');
      const { getTranslation } = await import('./i18n.js');

      item.disabled = true;
      spinner?.classList.remove('hidden');
      mdui.snackbar({ message: getTranslation('home_refreshing') || 'Executing…' });

      try {
        const result = await runScript(scriptName, 'feature');
        await addEntry(scriptName, result.rawOutput || result.output || '');
        mdui.snackbar({ message: getTranslation('toast_success') || 'Done ✓' });
      } catch (err) {
        const msg = err.message === 'timeout'
          ? (getTranslation('toast_timeout') || 'Timed out — check your module installation')
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
  const card = document.getElementById('version-card');
  if (card) card.addEventListener('click', openHistoryDialog);
}

function wireRefreshButton() {
  const btn = document.getElementById('refresh-btn');
  if (!btn) return;
  btn.addEventListener('click', async () => {
    btn.loading = true;
    await refreshDevice();
    btn.loading = false;
  });
}

function wireSettings() { }
