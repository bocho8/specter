import './material.js';
import { initBridge, spawnScript, exec, getModuleDir as getBridgeModuleDir } from './bridge.js';
import { setModuleDir, migrateLocalStorage, cfgGet, cfgSet, cfgFlush } from './cfg.js';
import { initDevice, refreshDevice, refreshKeyboxStatus, loadBlacklistContent, saveBlacklistContent, loadSmartmergeContent, saveSmartmergeContent } from './device.js';
import { initNetwork } from './network.js';
import { initTheme } from './theme.js';
import { initI18n, getTranslation } from './i18n.js';
import { loadContributors } from './contributors.js';
import { initRedirect } from './redirect.js';
import { escapeHtml, shellEscape, fetchJson } from './utils.js';
import { openRecentActivity, addEntry } from './history.js';
import { showToast, closeToast } from './toast.js';
import { initTerminal, appendToOutput } from './terminal.js';
import { openFileBrowser } from './file-browser.js';
import { showErrorDialog } from './dialog.js';
import { setFriendlyNames, getFriendlyName } from './state.js';
import { API_URLS } from './constants.js';
import type { CatalogJson } from './types.js';

let devMode = false;

async function confirmDestructive(friendlyName: string): Promise<boolean> {
  return new Promise(resolve => {
    const dialog = document.createElement('md-dialog');
    dialog.setAttribute('type', 'alert');
    dialog.innerHTML = `
      <div slot="headline">${getTranslation('tools_danger_zone') || 'Danger Zone'}</div>
      <div slot="content" style="padding:8px 24px 16px">
        <p style="margin:0;font-size:0.9375rem">${getTranslation('danger_confirm_msg') || 'This action may affect your device. Are you sure?'}</p>
        <p style="margin:8px 0 0;font-size:0.8125rem;color:var(--md-sys-color-on-surface-variant)"><strong>${escapeHtml(friendlyName)}</strong></p>
      </div>
      <div slot="actions">
        <md-text-button id="danger-cancel">${getTranslation('dialog_cancel') || 'Cancel'}</md-text-button>
        <div class="spacer"></div>
        <md-filled-tonal-button id="danger-confirm" style="--md-filled-tonal-button-container-color:var(--md-sys-color-error);--md-filled-tonal-button-label-text-color:var(--md-sys-color-on-error)">${getTranslation('danger_confirm') || 'Continue'}</md-filled-tonal-button>
      </div>
    `;
    document.body.appendChild(dialog);
    dialog.querySelector('#danger-cancel')!.addEventListener('click', () => { (dialog as any).close(); resolve(false); });
    dialog.querySelector('#danger-confirm')!.addEventListener('click', () => { (dialog as any).close(); resolve(true); });
    dialog.addEventListener('close', () => document.body.removeChild(dialog));
    (dialog as any).show();
  });
}

document.addEventListener('DOMContentLoaded', async () => {
  try {
    await initBridge();
    const modPath = getBridgeModuleDir();
    if (modPath) setModuleDir(modPath);
    await migrateLocalStorage();
  } catch (e) {
    console.warn('Bridge init failed, running without module path:', e);
  }

  wireTopBarScroll();
  const savedTheme = await cfgGet('theme', 'dark') || 'dark';
  initTheme(savedTheme);
  wireNavigation();
  wireActions();
  wireKeyboxCard();
  wireRefreshButton();
  wireCustomKeybox();
  wireKeyboxInstallButton();
  await initI18n();
  await Promise.all([initNetwork(), populateProviders(), loadContributors()]).catch(err => console.warn('Init error:', err));
  await initDevice();
  wireBlacklistToggle();
  wireSmartmergeEditor();
  wireToggles();
  wireControlToggles();
  initRedirect();
  buildFriendlyNames();

  const savedDevMode = await cfgGet('dev_mode', 'false') || 'false';
  devMode = savedDevMode === 'true';
  const sw = document.getElementById('dev-mode-switch') as any;
  if (sw) sw.selected = devMode;
  wireDevMode();
  initTerminal();
});

function wireTopBarScroll() {
  const topBar = document.getElementById('top-bar');
  if (!topBar) return;
  window.addEventListener('scroll', () => {
    topBar.classList.toggle('app-top-bar--scrolled', window.scrollY > 0);
  });
}

function wireNavigation() {
  // Migrate old hashes to new tools-page
  const oldHash = location.hash.replace('#', '');
  if (oldHash === 'setup' || oldHash === 'maintain') {
    history.replaceState(null, '', '#tools');
  }
  const savedTab = localStorage.getItem('lastTab');
  if (savedTab === 'setup' || savedTab === 'maintain') {
    localStorage.setItem('lastTab', 'tools');
  }

  const navTabs = document.querySelectorAll('.nav-tab');
  const indicator = document.getElementById('nav-indicator')!;
  const pageIds = ['home-page', 'tools-page', 'control-page', 'settings-page'];
  const pages = pageIds.map(id => document.getElementById(id)!).filter(Boolean);

  let lastClickTab: string | null = null;
  let clickTimer: ReturnType<typeof setTimeout> | null = null;

  function reposition(tab: HTMLElement) {
    indicator.style.left = tab.offsetLeft + 'px';
    indicator.style.width = tab.offsetWidth + 'px';
  }

  function activateTab(tab: HTMLElement) {
    const oldTab = document.querySelector('.nav-tab--active');
    if (oldTab && oldTab !== tab) {
      oldTab.classList.remove('nav-tab--active');
      oldTab.removeAttribute('aria-current');
      oldTab.querySelector('.nav-icon')?.classList.remove('nav-icon--filled');
    }
    tab.classList.add('nav-tab--active');
    tab.setAttribute('aria-current', 'page');
    tab.querySelector('.nav-icon')?.classList.add('nav-icon--filled');
    reposition(tab);
    const pageId = tab.dataset.page || '';
    pages.forEach((el) => { el.hidden = el.id !== pageId; });
    const hash = pageId.replace('-page', '');
    if (location.hash !== `#${hash}`) history.pushState(null, '', `#${hash}`);
    localStorage.setItem('lastTab', hash);
  }

  function navigateTo(hash: string) {
    const target = hash.replace('#', '') + '-page';
    const tab = Array.from(navTabs).find(t => (t as HTMLElement).dataset.page === target) as HTMLElement | null;
    if (tab && !tab.classList.contains('nav-tab--active')) activateTab(tab);
  }

  navTabs.forEach((tab) => {
    tab.addEventListener('click', () => {
      const pageId = (tab as HTMLElement).dataset.page || '';
      if (lastClickTab === pageId) {
        window.scrollTo({ top: 0, behavior: 'smooth' });
        lastClickTab = null;
        if (clickTimer) clearTimeout(clickTimer);
        clickTimer = null;
      } else {
        lastClickTab = pageId;
        activateTab(tab as HTMLElement);
        clickTimer = setTimeout(() => {
          lastClickTab = null;
          clickTimer = null;
        }, 400);
      }
    });
  });

  window.addEventListener('popstate', () => {
    navigateTo(location.hash || '#home');
  });

  window.addEventListener('resize', () => {
    const active = document.querySelector('.nav-tab--active') as HTMLElement | null;
    if (active) reposition(active);
  });

  requestAnimationFrame(() => {
    const savedTab = localStorage.getItem('lastTab');
    const initialHash = location.hash.replace('#', '');
    const tabName = initialHash || savedTab || 'home';
    navigateTo(`#${tabName}`);
  });
}

function buildFriendlyNames() {
  const names: Record<string, string> = {};
  document.querySelectorAll('.list-item[data-script]').forEach(item => {
    const el = item as HTMLElement;
    const scriptName = el.dataset.script;
    if (!scriptName) return;
    const headline = item.querySelector('.toggle-text[data-i18n]') as HTMLElement | null;
    if (headline) names[scriptName] = headline.dataset.i18n || '';
  });
  setFriendlyNames(names);
}

function wireDevMode() {
  const sw = document.getElementById('dev-mode-switch') as any;
  if (!sw) return;
  sw.addEventListener('change', () => {
    devMode = sw.selected;
    cfgSet('dev_mode', sw.selected ? 'true' : 'false');
  });
}

function wireActions() {
  document.querySelectorAll('.list-item[data-script]').forEach(item => {
    const el = item as HTMLElement;
    item.addEventListener('click', async (_e) => {
      if ((el as any).disabled) return;
      const scriptName = el.dataset.script || '';
      const isDestructive = el.hasAttribute('data-destructive');
      if (isDestructive) {
        const i18nKey = getFriendlyName(scriptName);
        const friendlyName = getTranslation(i18nKey) || i18nKey;
        const confirmed = await confirmDestructive(friendlyName);
        if (!confirmed) return;
      }
      const spinner = item.querySelector('.action-spinner') as HTMLElement | null;
      (el as any).disabled = true;
      spinner?.classList.remove('hidden');
      try {
        if (devMode) {
          await runDevAction(scriptName, el, spinner);
        } else {
          await runSimpleAction(scriptName, el, spinner);
        }
      } catch (_err) {
        console.warn('Action error:', _err);
      } finally {
        (el as any).disabled = false;
        spinner?.classList.add('hidden');
      }
    });
  });
}

async function runDevAction(scriptName: string, _item: HTMLElement, _spinner: HTMLElement | null) {
  const lines: string[] = [];
  appendToOutput(`> ${scriptName}`);
  const dialog = document.createElement('md-dialog');
  dialog.innerHTML = `
    <div slot="headline">${escapeHtml(scriptName)}</div>
    <div slot="content"><div class="terminal"><pre id="live-output"></pre></div></div>
    <div slot="actions">
      <md-text-button class="dialog-close">${getTranslation('dialog_close') || 'Close'}</md-text-button>
    </div>
  `;
  document.body.appendChild(dialog);
  dialog.querySelector('.dialog-close')!.addEventListener('click', () => (dialog as any).close());
  dialog.addEventListener('close', () => document.body.removeChild(dialog));
  (dialog as any).show();
  const pre = dialog.querySelector('#live-output');
  const child = spawnScript(scriptName, 'feature');
  child.stdout.on('data', (line: string) => {
    appendToOutput(line); lines.push(line);
    if (pre) pre.textContent += line + '\n';
    if (pre?.parentElement) pre.parentElement.scrollTop = pre.parentElement.scrollHeight;
  });
  child.stderr.on('data', (line: string) => {
    appendToOutput(line, true); lines.push('[!] ' + line);
    if (pre) pre.textContent += '[!] ' + line + '\n';
    if (pre?.parentElement) pre.parentElement.scrollTop = pre.parentElement.scrollHeight;
  });
  child.on('exit', (code: number) => {
    appendToOutput(`> ${scriptName} exited (code: ${code})`);
    addEntry(scriptName, lines.join('\n'));
  });
  child.on('error', (err: Error) => {
    const msg = err.message || 'Unknown error';
    appendToOutput(`> Error: ${msg}`, true);
    addEntry(scriptName, msg);
  });
}

async function runSimpleAction(scriptName: string, _item: HTMLElement, _spinner: HTMLElement | null) {
  const i18nKey = getFriendlyName(scriptName);
  const friendlyName = getTranslation(i18nKey) || i18nKey;
  const lines: string[] = [];
  appendToOutput(`> ${friendlyName}`);
  const dialog = document.getElementById('progress-dialog') as any;
  const label = document.getElementById('progress-label');
  const text = document.getElementById('progress-text');
  if (label) label.textContent = friendlyName;
  if (text) text.textContent = getTranslation('simple_dialog_wait') || 'This may take a moment';
  if (dialog) dialog.show();
  const child = spawnScript(scriptName, 'feature');
  child.stdout.on('data', (line: string) => {
    appendToOutput(line); lines.push(line);
  });
  child.stderr.on('data', (line: string) => {
    appendToOutput(line, true); lines.push('[!] ' + line);
  });
  child.on('exit', (code: number) => {
    appendToOutput(`> ${friendlyName} exited (code: ${code})`);
    addEntry(scriptName, lines.join('\n'));
    if (dialog) dialog.close();
    if (code !== 0) {
      const errorMsg = lines.find(l => l.includes('Error')) || lines[lines.length - 1] || friendlyName;
      showToast(`${getTranslation('simple_toast_error') || 'Failed'}: ${errorMsg}`, {
        icon: 'error', type: 'error' as any,
        action: getTranslation('simple_toast_view_details') || 'View Details',
        autoCloseDelay: 8000,
        onActionClick: () => {
          showErrorDialog(getTranslation('error_dialog_title') || 'Error Details', escapeHtml(lines.join('\n')));
        },
      });
    } else {
      showToast(getTranslation('toast_success') || 'Done', {
        icon: 'check_circle', type: 'success' as any, autoCloseDelay: 3000,
      });
    }
  });
  child.on('error', (err: Error) => {
    const msg = err.message || 'Unknown error';
    appendToOutput(`> Error: ${msg}`, true);
    addEntry(scriptName, msg);
    if (dialog) dialog.close();
    showToast(`${getTranslation('simple_toast_error') || 'Failed'}: ${friendlyName}`, {
      icon: 'error', type: 'error' as any,
      action: getTranslation('simple_toast_view_details') || 'View Details',
      autoCloseDelay: 8000,
      onActionClick: () => {
        showErrorDialog(getTranslation('error_dialog_title') || 'Error Details', escapeHtml(msg));
      },
    });
  });
}

function wireRefreshButton() {
  const btn = document.getElementById('refresh-btn') as HTMLButtonElement | null;
  if (!btn) return;
  btn.addEventListener('click', async () => {
    btn.disabled = true;
    await refreshDevice();
    await refreshKeyboxStatus();
    btn.disabled = false;
  });
}

function wireKeyboxCard() {
  const card = document.getElementById('keybox-card');
  if (!card) return;
  card.addEventListener('click', () => {
    const sw = document.getElementById('dev-mode-switch') as any;
    openRecentActivity(sw ? sw.selected : false);
  });
}

function renderProviderOptions(select: any, sources: string[]) {
  while (select.children.length > 1) select.removeChild(select.lastChild);
  for (const s of sources) {
    const opt = document.createElement('md-select-option');
    opt.setAttribute('value', s);
    opt.innerHTML = `<div slot="headline">${escapeHtml(s)}</div>`;
    select.appendChild(opt);
  }
}

async function populateProviders() {
  const select = document.getElementById('kb-provider') as any;
  if (!select) return;

  const saved = await cfgGet('kb_provider', 'auto') || 'auto';

  if (!select._listenerAttached) {
    select.addEventListener('click', (e: Event) => e.stopPropagation());
    select.addEventListener('change', (_e: Event) => { _e.stopPropagation(); select.value; cfgSet('kb_provider', select.value); });
    select._listenerAttached = true;
  }

  try {
    const data = await fetchJson<CatalogJson>(API_URLS.KEY_CATALOG);
    if (data?.entries) {
      const sources = [...new Set(data.entries.map(e => e.source))].sort();
      const currentValue = select.value;
      renderProviderOptions(select, sources);
      select.value = currentValue;
    }
  } catch (e) {
    console.warn('Provider fetch failed:', e);
  }
}

function wireCustomKeybox() {
  const btn = document.getElementById('custom-keybox-btn');
  if (!btn) return;
  btn.addEventListener('click', openCustomKeyboxDialog);
}

function wireKeyboxInstallButton() {
  const btn = document.getElementById('kb-install-btn') as any;
  const card = document.querySelector('.keybox-install-card');
  const spinner = card?.querySelector('.kic-spinner') as HTMLElement | null;
  if (!btn) return;

  btn.addEventListener('click', async (e: Event) => {
    e.stopPropagation();
    if (btn.disabled) return;

    btn.disabled = true;
    spinner?.classList.remove('hidden');

    try {
      cfgSet('kb_custom_type', '');
      cfgSet('kb_custom_value', '');
      await cfgFlush();
      if (devMode) {
        await runDevAction('keybox.sh', btn, spinner);
      } else {
        await runSimpleAction('keybox.sh', btn, spinner);
      }
    } catch (_e) {
      console.warn('Install error:', _e);
    } finally {
      btn.disabled = false;
      spinner?.classList.add('hidden');
    }
  });
}

async function openCustomKeyboxDialog() {
  const t = (key: string, fallback: string): string => getTranslation(key) || fallback;

  const dialog = document.createElement('md-dialog');

  dialog.innerHTML = `
    <div slot="headline" style="padding:20px 24px 4px">${t('custom_kb_title', 'Custom Keybox')}</div>
    <div slot="content" style="padding:4px 24px">
      <md-filled-card style="padding:12px;border-radius:14px;width:100%;box-sizing:border-box;--md-filled-card-container-color:var(--md-sys-color-surface-container-highest)">
        <div class="custom-kb-section">
          <div class="li-icon"><md-icon>upload_file</md-icon></div>
          <p style="margin:6px 0 2px;font-size:0.8125rem">${t('custom_kb_file', 'Import File')}</p>
          <p style="margin:0 0 8px;font-size:0.6875rem;color:var(--md-sys-color-on-surface-variant)">
            Select a keybox XML file from your device
          </p>
          <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap">
            <md-assist-chip id="kb-file-chip" label="${t('custom_kb_no_file', 'No file selected')}" style="height:36px;font-size:0.75rem"></md-assist-chip>
            <md-filled-tonal-button id="kb-file-btn" style="height:36px;font-size:0.75rem">${t('custom_kb_browse', 'Browse Files')}</md-filled-tonal-button>
          </div>
        </div>
      </md-filled-card>

      <md-filled-card style="padding:12px;border-radius:14px;width:100%;box-sizing:border-box;margin-top:8px;--md-filled-card-container-color:var(--md-sys-color-surface-container-highest)">
        <div class="custom-kb-section">
          <div class="li-icon"><md-icon>link</md-icon></div>
          <p style="margin:6px 0 2px;font-size:0.8125rem">${t('custom_kb_url', 'URL or Path')}</p>
          <p style="margin:0 0 8px;font-size:0.6875rem;color:var(--md-sys-color-on-surface-variant)">
            Paste a download URL or enter a device path
          </p>
          <md-outlined-text-field id="kb-url-input" style="width:100%;--md-outlined-text-field-container-shape:14px;--md-sys-shape-corner-extra-small:14px;border-radius:14px;height:44px" placeholder="https://example.com/keybox.xml or /sdcard/keybox.xml">
            <md-icon-button slot="trailing-icon" id="kb-paste-btn" aria-label="Paste from clipboard">
              <md-icon>content_paste</md-icon>
            </md-icon-button>
          </md-outlined-text-field>
        </div>
      </md-filled-card>
    </div>
    <div slot="actions" style="padding:4px 24px 20px">
      <md-text-button id="kb-clear"><md-icon slot="icon">delete</md-icon> ${t('custom_kb_clear', 'Clear')}</md-text-button>
      <div class="spacer"></div>
      <md-filled-tonal-button id="kb-apply">${t('custom_kb_apply', 'Apply')}</md-filled-tonal-button>
    </div>
  `;

  document.body.appendChild(dialog);

  const fileBtn = dialog.querySelector('#kb-file-btn');
  const urlInput = dialog.querySelector('#kb-url-input') as any;
  const pasteBtn = dialog.querySelector('#kb-paste-btn');
  const clearBtn = dialog.querySelector('#kb-clear');
  const applyBtn = dialog.querySelector('#kb-apply');

  fileBtn!.addEventListener('click', () => {
    openFileBrowser((filePath: string) => {
      urlInput.value = filePath;
      const chip = dialog.querySelector('#kb-file-chip') as any;
      if (chip) chip.label = filePath.split('/').pop();
    });
  });

  pasteBtn!.addEventListener('click', async () => {
    try {
      const text = await navigator.clipboard.readText();
      if (text) urlInput.value = text;
    } catch (e) {
      console.warn('Clipboard read failed:', e);
    }
  });

  clearBtn!.addEventListener('click', async () => {
    cfgSet('kb_custom_type', '');
    cfgSet('kb_custom_value', '');
    cfgSet('kb_private', '');
    showToast(t('custom_kb_cleared', 'Custom keybox cleared'), { icon: 'info', type: 'info' as any, autoCloseDelay: 2500 });
    (dialog as any).close();
  });

  applyBtn!.addEventListener('click', async () => {
    const moddir = getBridgeModuleDir();
    const text = urlInput.value.trim();

    if (!text) {
      showToast('Enter a URL or device path', { icon: 'error', type: 'error' as any, autoCloseDelay: 2500 });
      return;
    }

    const privateChoice = await new Promise<boolean>(resolve => {
      const pd = document.createElement('md-dialog');
      pd.setAttribute('type', 'alert');
      pd.innerHTML = `
        <div slot="headline">${t('custom_kb_title', 'Custom Keybox')}</div>
        <div slot="content" style="min-height:0;padding:8px 24px 16px">
          <p style="margin:0;font-size:0.9375rem">${t('custom_kb_private_ask', 'Is this a private keybox?')}</p>
        </div>
        <div slot="actions">
          <md-text-button id="kb-pri-no" value="no">${t('custom_kb_no', 'No')}</md-text-button>
          <md-filled-tonal-button id="kb-pri-yes" value="yes">${t('custom_kb_yes', 'Yes')}</md-filled-tonal-button>
        </div>
      `;
      document.body.appendChild(pd);
      pd.querySelector('#kb-pri-no')!.addEventListener('click', () => { (pd as any).close(); resolve(false); });
      pd.querySelector('#kb-pri-yes')!.addEventListener('click', () => { (pd as any).close(); resolve(true); });
      pd.addEventListener('close', () => document.body.removeChild(pd));
      (pd as any).show();
    });

    if (privateChoice) {
      if (text.startsWith('http://') || text.startsWith('https://')) {
        cfgSet('kb_custom_type', 'url');
      } else {
        cfgSet('kb_custom_type', 'path');
      }
      cfgSet('kb_custom_value', text);
      cfgSet('kb_private', 'true');
      await cfgFlush();
      const result: any = await exec(`sh ${shellEscape(moddir + '/features/keybox.sh')}`);
      if (result.code === 0) {
        showToast(t('custom_kb_installed', 'Custom keybox installed'), { icon: 'check_circle', type: 'success' as any, autoCloseDelay: 3000 });
      } else {
        showToast(t('custom_kb_install_failed', 'Install failed'), { icon: 'error', type: 'error' as any, autoCloseDelay: 5000 });
      }
      (dialog as any).close();
      return;
    }

    const detectingToast = showToast(t('custom_kb_detecting', 'Detecting keybox...'), { icon: 'info', type: 'info' as any, autoCloseDelay: 30000 });

    try {
      let serial = '';

      if (text.startsWith('http://') || text.startsWith('https://')) {
        const result: any = await exec(
          `curl -s ${shellEscape(text)} > /data/local/tmp/_kb_check.xml 2>/dev/null && ` +
          `. ${moddir}/lib/common.sh && decode_keybox_serial /data/local/tmp/_kb_check.xml`
        );
        serial = (result.stdout || '').trim();
      } else if (text.startsWith('/')) {
        const result: any = await exec(
          `. ${moddir}/lib/common.sh && decode_keybox_serial ${shellEscape(text)}`
        );
        serial = (result.stdout || '').trim();
      }

      let catalogInfo: any = null;
      if (serial) {
        try {
          const catalogData = await fetchJson<CatalogJson>(API_URLS.KEY_CATALOG);
          if (catalogData?.entries) {
            catalogInfo = catalogData.entries.find(e => e.serial === serial) || null;
          }
        } catch (e) {
          console.warn('Catalog fetch failed:', e);
        }
      }

      const detectedDialog = document.createElement('md-dialog');
      detectedDialog.innerHTML = `
        <div slot="headline">${t('custom_kb_detected', 'Keybox Detected')}</div>
        <div slot="content" style="text-align:center;padding:8px 16px">
          ${catalogInfo ? `
            <div class="li-icon" style="margin:0 auto 8px"><md-icon>verified_user</md-icon></div>
            <p style="font-size:0.9375rem;font-weight:500;margin:4px 0">${t('custom_kb_known', 'Known Keybox')}</p>
            <div style="display:inline-flex;align-items:center;gap:8px;margin:4px 0">
              <md-chip style="--md-chip-label-text-color:var(--md-sys-color-primary)">${escapeHtml(catalogInfo.source)}</md-chip>
              <span style="font-size:0.8125rem;color:var(--md-sys-color-on-surface-variant)">${escapeHtml(catalogInfo.version)}</span>
            </div>
            <md-chip style="--md-chip-label-text-color:${catalogInfo.revoked ? 'var(--md-sys-color-error)' : 'var(--md-sys-color-tertiary)'}">${catalogInfo.revoked ? t('custom_kb_revoked', 'Revoked') : t('custom_kb_active', 'Active')}</md-chip>
          ` : `
            <div class="li-icon" style="margin:0 auto 8px"><md-icon>search_off</md-icon></div>
            <p style="font-size:0.9375rem;font-weight:500;margin:4px 0">${t('custom_kb_not_found', 'Not Found in Catalog')}</p>
            <p style="font-size:0.75rem;color:var(--md-sys-color-on-surface-variant);margin:4px 0">${t('custom_kb_not_found_desc', 'This keybox could not be matched to any known source')}</p>
          `}
        </div>
        <div slot="actions">
          <md-text-button id="kb-detect-cancel">${t('dialog_close', 'Cancel')}</md-text-button>
          <div class="spacer"></div>
          <md-filled-tonal-button id="kb-detect-apply">${t('custom_kb_apply_confirm', 'Apply')}</md-filled-tonal-button>
        </div>
      `;
      document.body.appendChild(detectedDialog);

      detectedDialog.querySelector('#kb-detect-cancel')!.addEventListener('click', () => (detectedDialog as any).close());
      detectedDialog.querySelector('#kb-detect-apply')!.addEventListener('click', async () => {
        if (text.startsWith('http://') || text.startsWith('https://')) {
          cfgSet('kb_custom_type', 'url');
        } else {
          cfgSet('kb_custom_type', 'path');
        }
        cfgSet('kb_custom_value', text);
        cfgSet('kb_private', '');
        await cfgFlush();
        const result: any = await exec(`sh ${shellEscape(moddir + '/features/keybox.sh')}`);
        if (result.code === 0) {
          showToast(t('custom_kb_installed', 'Custom keybox installed'), { icon: 'check_circle', type: 'success' as any, autoCloseDelay: 3000 });
        } else {
          showToast(t('custom_kb_install_failed', 'Install failed'), { icon: 'error', type: 'error' as any, autoCloseDelay: 5000 });
        }
        (detectedDialog as any).close();
        (dialog as any).close();
      });
      detectedDialog.addEventListener('close', () => document.body.removeChild(detectedDialog));
      closeToast(detectingToast!);
      (detectedDialog as any).show();

    } catch (e) {
      console.warn('Keybox detection failed:', e);
      closeToast(detectingToast!);
      showToast('Failed to detect keybox', { icon: 'error', type: 'error' as any, autoCloseDelay: 3000 });
    }
  });

  dialog.addEventListener('close', () => {
    document.body.removeChild(dialog);
  });
  (dialog as any).show();
}

function wireBlacklistToggle() {
  const sw = document.getElementById('blacklist-switch') as any;
  const editor = document.getElementById('blacklist-editor');
  const input = document.getElementById('blacklist-input') as any;
  const saveBtn = document.getElementById('blacklist-save-btn');
  const resetBtn = document.getElementById('blacklist-reset-btn');
  if (!sw) return;

  sw.addEventListener('change', async () => {
    if (sw.selected) {
      await exec('mkdir -p /data/adb/Specter && touch /data/adb/Specter/blacklist_enabled');
      if (input) input.value = await loadBlacklistContent();
      if (editor) editor.style.display = 'block';
    } else {
      await exec('rm -f /data/adb/Specter/blacklist_enabled');
      if (editor) editor.style.display = 'none';
    }
  });

  if (sw.selected && editor) {
    editor.style.display = 'block';
  }

  if (saveBtn && input) {
    saveBtn.addEventListener('click', async () => {
      await saveBlacklistContent(input.value);
      showToast('Blacklist saved', { icon: 'check_circle', type: 'success' as any, autoCloseDelay: 2000 });
    });
  }

  if (resetBtn) {
    resetBtn.addEventListener('click', async () => {
      const defaults = [
        'com.android.chrome', 'com.google.android.apps.photos', 'com.google.android.youtube',
        'com.topjohnwu.magisk', 'io.github.vvb2060.mahoshojo', 'io.github.vvb2060.keyattestation',
        'io.github.qwq233.keyattestation', 'com.eltavine.duckdetector', 'com.rem01gaming.disclosure',
        'com.reveny.nativechecker', 'com.reveny.environmentchecker', 'com.reveny.rootchecker',
        'com.scottyab.rootbeer', 'com.scottyab.rootbeer.sample', 'com.kimchangyoun.rootbeerfresh',
        'com.kimchangyoun.magiskdetector', 'com.zhenxi.hunter', 'icu.nullptr.nativetest',
        'icu.nullptr.applistdetector', 'com.byxiaorun.detector', 'com.jrummyapps.rootchecker',
        'com.smlj.rootcheck', 'com.devadvance.rootcloak', 'com.devadvance.rootcloakplus', 'mmrl'
      ].join('\n');
      if (input) input.value = defaults;
      await saveBlacklistContent(defaults);
      showToast('Blacklist reset to defaults', { icon: 'check_circle', type: 'success' as any, autoCloseDelay: 2000 });
    });
  }
}

function wireSmartmergeEditor() {
  const row = document.getElementById('smartmerge-row');
  const editor = document.getElementById('smartmerge-editor');
  const input = document.getElementById('smartmerge-input') as any;
  const saveBtn = document.getElementById('smartmerge-save-btn');
  if (!row || !editor) return;

  row.addEventListener('click', async () => {
    const isVisible = editor.style.display !== 'none';
    if (!isVisible) {
      if (input) input.value = await loadSmartmergeContent();
      editor.style.display = 'block';
    } else {
      editor.style.display = 'none';
    }
  });

  if (saveBtn && input) {
    saveBtn.addEventListener('click', async () => {
      await saveSmartmergeContent(input.value);
      showToast('SmartMerge saved', { icon: 'check_circle', type: 'success' as any, autoCloseDelay: 2000 });
      editor.style.display = 'none';
    });
  }
}

function wireToggles() {
  const recoverySw = document.getElementById('toggle-recovery') as any;
  if (recoverySw) {
    recoverySw.addEventListener('change', async () => {
      if (recoverySw.selected) {
        await exec('mkdir -p /data/adb/Specter && touch /data/adb/Specter/twrp');
      } else {
        await exec('rm -f /data/adb/Specter/twrp');
      }
      showToast(recoverySw.selected ? 'Recovery hiding enabled' : 'Recovery hiding disabled', { icon: 'check_circle', type: 'success' as any, autoCloseDelay: 2000 });
    });
  }
}

function wireControlToggles() {
  const toggles: Array<{ id: string; key: string }> = [
    { id: 'toggle-recovery', key: 'toggle_recovery' },
    { id: 'toggle-boot_hardening', key: 'toggle_boot_hardening' },
    { id: 'toggle-bootloader_spoofer', key: 'toggle_bootloader_spoofer' },
    { id: 'toggle-rom_spoof', key: 'toggle_rom_spoof' },
    { id: 'toggle-lsposed', key: 'toggle_lsposed' },
    { id: 'toggle-action_gms', key: 'toggle_action_gms' },
    { id: 'toggle-action_target', key: 'toggle_action_target' },
    { id: 'toggle-action_security_patch', key: 'toggle_action_security_patch' },
    { id: 'toggle-action_boot_hash', key: 'toggle_action_boot_hash' },
    { id: 'toggle-action_pif', key: 'toggle_action_pif' },
  ];

  for (const { id, key } of toggles) {
    const sw = document.getElementById(id) as any;
    if (!sw) continue;
    cfgGet(key, '1').then(val => { sw.selected = val !== '0'; });
    sw.addEventListener('change', () => {
      cfgSet(key, sw.selected ? '1' : '0');
    });
  }
}
