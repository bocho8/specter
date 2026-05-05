import { escapeHtml } from './utils.js';
import { getTranslation } from './i18n.js';
import { openUrl } from './redirect.js';

export async function loadContributors() {
  const grid = document.getElementById('contributors-grid');
  if (!grid) return;

  let devs = [];
  try {
    const res = await fetch(`json/dev.json?ts=${Date.now()}`);
    devs = await res.json();
  } catch {
    console.warn('Failed to load contributors');
    return;
  }

  grid.innerHTML = devs.map(dev => `
    <md-outlined-card class="contributor-card"
               data-url="${encodeURIComponent(dev.github || '')}">
      <img class="contributor-avatar"
           src="${escapeHtml(dev.avatar || '')}"
           alt="${escapeHtml(dev.name)}"
           loading="lazy" />
      <p class="md-typescale-label-large contributor-name">
        ${escapeHtml(dev.name)}
      </p>
      <p class="md-typescale-label-small contributor-role">
        ${escapeHtml(getTranslation('role_' + dev.role) || dev.role)}
      </p>
    </md-outlined-card>
  `).join('');

  grid.querySelectorAll('.contributor-avatar').forEach(img => {
    img.addEventListener('error', () => { img.src = 'assets/icon.png'; }, { once: true });
  });

  grid.querySelectorAll('[data-url]').forEach(card => {
    card.addEventListener('click', () => {
      openUrl(decodeURI(card.dataset.url));
    });
  });
}
