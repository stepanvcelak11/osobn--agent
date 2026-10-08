// Offline: všechny soubory hry v mezipaměti. Verzi při nasazení nahradí GitHub Actions (číslo commitu).
const CACHE = 'rovnovaha-__VERSION__';
const FILES = ['./', 'index.html', 'style.css', 'ui.js', 'game.js', 'cards.js', 'manifest.webmanifest',
  'icons/icon-192.png', 'icons/icon-512.png', 'icons/apple-touch-icon.png', 'art.js', 'world.js', 'ages.js', 'ages_more.js', 'bonds.js', 'events.js', 'history_more.js', 'duel.js', 'depth.js', 'projects.js', 'meta.js', 'saga.js', 'court.js', 'ages_extra.js', 'realm.js', 'quests.js', 'mystery.js', 'words.js', 'scene.js'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(FILES)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});

// Nejdřív síť (ať se nová verze projeví), bez signálu mezipaměť.
self.addEventListener('fetch', (e) => {
  if (e.request.method !== 'GET') return;
  e.respondWith(
    fetch(e.request).then((res) => {
      const copy = res.clone();
      if (res.ok && new URL(e.request.url).origin === location.origin) caches.open(CACHE).then((c) => c.put(e.request, copy));
      return res;
    }).catch(() => caches.match(e.request, { ignoreSearch: true })
      .then((r) => r || (e.request.mode === 'navigate' ? caches.match('index.html') : undefined)))
  );
});
