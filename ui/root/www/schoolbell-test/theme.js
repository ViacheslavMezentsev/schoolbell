(function () {
  'use strict';
  var storageKey = 'schoolbell.sound-test.theme';
  var modes = ['system', 'dark', 'light'];
  var labels = {system: 'как в системе', dark: 'тёмная', light: 'светлая'};
  var mode = 'system';
  try { var saved = localStorage.getItem(storageKey); if (modes.indexOf(saved) !== -1) mode = saved; } catch (_) {}
  var system = window.matchMedia('(prefers-color-scheme: dark)');
  var icons = {
    system: '<rect x="3" y="4" width="18" height="13" rx="2"/><path d="M8 21h8m-4-4v4"/>',
    dark: '<path d="M20.5 13A8.7 8.7 0 0 1 11 3.5 8.7 8.7 0 1 0 20.5 13Z"/>',
    light: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M2 12h2m16 0h2M5 5l1.5 1.5m11 11L19 19M5 19l1.5-1.5m11-11L19 5"/>'
  };
  function apply() {
    document.documentElement.dataset.theme = mode === 'system' ? (system.matches ? 'dark' : 'light') : mode;
    var button = document.getElementById('theme-toggle');
    if (!button) return;
    var next = modes[(modes.indexOf(mode) + 1) % modes.length];
    button.setAttribute('aria-label', 'Тема: ' + labels[mode] + '. Переключить: ' + labels[next]);
    button.title = 'Тема: ' + labels[mode] + '. Следующая: ' + labels[next];
    button.innerHTML = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + icons[mode] + '</svg>';
  }
  // Apply before the body is painted; storage is optional for local-file use.
  apply();
  document.addEventListener('DOMContentLoaded', function () {
    apply();
    document.getElementById('theme-toggle').addEventListener('click', function () {
      mode = modes[(modes.indexOf(mode) + 1) % modes.length];
      try { localStorage.setItem(storageKey, mode); } catch (_) {}
      apply();
    });
  });
  if (system.addEventListener) system.addEventListener('change', apply);
  else system.addListener(apply);
}());
