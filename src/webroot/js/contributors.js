export async function loadContributors() {
  const grid = document.getElementById('contributors-grid');
  if (!grid) return;

  let devs = [];
  try {
    const res = await fetch(`json/dev.json?ts=${Date.now()}`);
    devs = await res.json();
  } catch {
    return;
  }

  const { getTranslation } = await import('./i18n.js');

  grid.innerHTML = devs.map(dev => `
    <mdui-card class="contributor-card" clickable
               data-url="${encodeURI(dev.github || '')}">
      <img class="contributor-avatar"
           src="${dev.avatar || ''}"
           alt="${escapeHtml(dev.name)}"
           loading="lazy"
           onerror="this.src='assets/yurikey.png'" />
      <p class="mdui-typescale-label-large contributor-name">
        ${escapeHtml(dev.name)}
      </p>
      <p class="mdui-typescale-label-small contributor-role">
        ${escapeHtml(getTranslation('role_' + dev.role) || dev.role)}
      </p>
    </mdui-card>
  `).join('');

  grid.querySelectorAll('[data-url]').forEach(card => {
    card.addEventListener('click', async () => {
      const { openUrl } = await import('./redirect.js');
      openUrl(decodeURI(card.dataset.url));
    });
  });
}

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
