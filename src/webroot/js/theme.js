import { cfgGet, cfgSet } from './cfg.js';

const PRESETS = {
  ocean:  '#1B6EF3',
  rose:   '#C2184B',
  forest: '#1B6E3A',
  sunset: '#E65100',
  violet: '#6750A4',
};

export async function initTheme(savedMode) {
  const preset = await cfgGet('theme_preset', 'ocean') || 'ocean';
  applyMode(savedMode || 'dark');
  applyPreset(preset);
  wireThemeControls();
}

function applyMode(mode) {
  if (mode === 'auto') {
    mdui.setTheme('auto');
  } else {
    mdui.setTheme(mode);
  }
  cfgSet('theme', mode);
  const group = document.getElementById('theme-mode-group');
  if (group) group.value = mode;
}

function applyPreset(preset) {
  const seed = PRESETS[preset];
  if (!seed) return;
  mdui.setColorScheme(seed);
  cfgSet('theme_preset', preset);
  document.querySelectorAll('.preset-chip').forEach(chip => {
    chip.selected = chip.dataset.preset === preset;
  });
}

function wireThemeControls() {
  const modeGroup = document.getElementById('theme-mode-group');
  modeGroup?.addEventListener('change', () => applyMode(modeGroup.value));
  document.querySelectorAll('.preset-chip').forEach(chip => {
    chip.addEventListener('click', () => applyPreset(chip.dataset.preset));
  });
}
