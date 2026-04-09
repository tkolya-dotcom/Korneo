const CACHE_NAME = 'korneo-mobile-v3';
const urlsToCache = [
  '/',
  '/manifest.json',
  '/favicon.ico',
  '/assets/icon.png',
  '/assets/favicon.png',
  '/assets/adaptive-icon.png',
  '/~/_expo/static/js/bundle.js',
  '/~/_expo/static/js/polyfills.js',
  // Critical route shells
  '/login',
  '/(tabs)',
  '/(tabs)/index',
  '/(tabs)/tasks',
  '/(tabs)/installations',
  '/(tabs)/avr',
];

// Install SW
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => {
      console.log('SW: Installing cache');
      return cache.addAll(urlsToCache.map(url => new Request(url, { cache: 'force-cache' })));
    })
  );
  self.skipWaiting();
});

// Activate SW
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.map(cacheName => {
          if (cacheName !== CACHE_NAME) {
            console.log('SW: Deleting old cache', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
  self.clients.claim();
});

// Cache-first strategy for assets
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  
  // Runtime cache API requests (Supabase)
  if (url.origin === 'jmxjbdnqnzkzxgsfywha.supabase.co' || event.request.destination === 'image') {
    event.respondWith(
      caches.match(event.request).then(response => {
        if (response) return response; // Cache hit
        
        return fetch(event.request.clone(), {
          cache: 'no-cache'
        }).then(networkResponse => {
          if (!networkResponse || networkResponse.status !== 200 || networkResponse.type !== 'basic') {
            return networkResponse;
          }
          
          const responseClone = networkResponse.clone();
          caches.open(CACHE_NAME).then(cache => {
            cache.put(event.request, responseClone);
          });
          
          return networkResponse;
        }).catch(() => {
          // Network fail → stale cache for API
          return caches.match(event.request) || new Response('Offline', { status: 503 });
        });
      })
    );
  } else {
    // Cache-first for app shell
    event.respondWith(
      caches.match(event.request).then(response => {
        return response || fetch(event.request).then(fetchResponse => {
          const responseClone = fetchResponse.clone();
          caches.open(CACHE_NAME).then(cache => {
            cache.put(event.request, responseClone);
          });
          return fetchResponse;
        });
      }).catch(() => {
        // Offline fallback
        return caches.match('/') || new Response('Korneo Mobile offline', {
          status: 503,
          headers: { 'Content-Type': 'text/html' }
        });
      })
    );
  }
});

// Background sync for tasks (optional)
self.addEventListener('sync', event => {
  if (event.tag === 'sync-tasks') {
    event.waitUntil(syncPendingTasks());
  }
});

async function syncPendingTasks() {
  // Impl pending mutations from IndexedDB
  console.log('SW: Background sync tasks');
}
