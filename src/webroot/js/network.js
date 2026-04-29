let lastStatus = null;

export function initNetwork() {
  updateNetworkStatus();
  setInterval(updateNetworkStatus, 3000);
  window.addEventListener('online', updateNetworkStatus);
  window.addEventListener('offline', updateNetworkStatus);
}

export async function updateNetworkStatus() {
  const online = await checkOnline();

  if (online === lastStatus) return;
  const wasOnline = lastStatus;
  lastStatus = online;

  const statusCard  = document.getElementById('status-card');
  const statusIcon  = document.getElementById('status-icon');
  const statusValue = document.getElementById('status-value');
  const netChip     = document.getElementById('network-chip');
  const netChipText = netChip?.querySelector('span');

  const { getTranslation } = await import('./i18n.js');
  const onlineText  = getTranslation('home_status_online') || 'Online';
  const offlineText = getTranslation('home_status_offline') || 'Offline';

  if (online) {
    statusCard?.classList.remove('status-offline');
    if (statusIcon)  statusIcon.name = 'wifi';
    if (statusValue) statusValue.textContent = onlineText;
    if (netChipText) netChipText.textContent = onlineText;
    netChip?.classList.remove('offline');
    if (netChip) netChip.icon = 'wifi';
  } else {
    statusCard?.classList.add('status-offline');
    if (statusIcon)  statusIcon.name = 'wifi_off';
    if (statusValue) statusValue.textContent = offlineText;
    if (netChipText) netChipText.textContent = offlineText;
    netChip?.classList.add('offline');
    if (netChip) netChip.icon = 'wifi_off';

    if (wasOnline === true) {
      mdui.snackbar({ message: offlineText });
    }
  }
}

async function checkOnline() {
  if (!navigator.onLine) return false;
  try {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 2000);
    await fetch('https://clients3.google.com/generate_204', { signal: ctrl.signal });
    clearTimeout(timer);
    return true;
  } catch {
    try {
      const ctrl2 = new AbortController();
      const timer2 = setTimeout(() => ctrl2.abort(), 2000);
      await fetch('https://clients3.google.com/generate_204', { mode: 'no-cors', signal: ctrl2.signal });
      clearTimeout(timer2);
      return true;
    } catch {
      return false;
    }
  }
}
