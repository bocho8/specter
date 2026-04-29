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

export function getStrings() {
  return currentStrings;
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
