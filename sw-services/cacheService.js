
const CACHE_VERSION = 'v1';
const STATIC_CACHE = `static-${CACHE_VERSION}`;
const API_CACHE = `api-${CACHE_VERSION}`;
const IMAGE_CACHE = `images-${CACHE_VERSION}`;

const SUPABASE_URL = 'https://jmxjbdnqnzkzxgsfywha.supabase.co';

const STATIC_ASSETS = [
  './',
  './index.html',
  './manifest.json',
  './js/app.js',
  './js/auth.js',
  './js/api.js',
  './js/config.js',
  './js/utils.js',
  './js/chat.js',
  './js/tasks.js',
  './js/projects.js',
  './js/installations.js',
  './js/notifications.js'
];

const cacheService = {
  async install() {
    const cache = await caches.open(STATIC_CACHE);
    await cache.addAll(STATIC_ASSETS);
    console.log('[CacheService] Static assets cached');
  },

  async activate() {
    const cacheWhitelist = [STATIC_CACHE, API_CACHE, IMAGE_CACHE];
    const cacheNames = await caches.keys();
    
    await Promise.all(
      cacheNames.map(cacheName => {
        if (!cacheWhitelist.includes(cacheName)) {
          console.log('[CacheService] Deleting old cache:', cacheName);
          return caches.delete(cacheName);
        }
      })
    );
  },

  isStaticAsset(url) {
    const staticExtensions = /\.(js|css|png|jpg|jpeg|gif|svg|ico|woff|woff2|ttf|eot)$/;
    return staticExtensions.test(url.pathname);
  },

  isApiRequest(url) {
    return url.href.includes(SUPABASE_URL) || 
           url.pathname.startsWith('/rest/v1/') ||
           url.pathname.startsWith('/auth/v1/');
  },

  isImageRequest(url) {
    return /\.(png|jpg|jpeg|gif|svg|webp)$/i.test(url.pathname);
  },

  async cacheFirst(request) {
    const cache = await caches.open(STATIC_CACHE);
    const cached = await cache.match(request);
    
    if (cached) {
      fetch(request).then(response => {
        if (response.ok) {
          cache.put(request, response.clone());
        }
      }).catch(() => {});
      return cached;
    }
    
    const response = await fetch(request);
    if (response.ok) {
      cache.put(request, response.clone());
    }
    return response;
  },

  async networkFirst(request) {
    const cache = await caches.open(API_CACHE);
    
    try {
      const networkResponse = await fetch(request);
      if (networkResponse.ok) {
        cache.put(request, networkResponse.clone());
      }
      return networkResponse;
    } catch (error) {
      const cached = await cache.match(request);
      if (cached) {
        console.log('[CacheService] Serving cached API response');
        return cached;
      }
      throw error;
    }
  },

  async staleWhileRevalidate(request) {
    const cache = await caches.open(IMAGE_CACHE);
    const cached = await cache.match(request);
    
    const fetchPromise = fetch(request).then(response => {
      if (response.ok) {
        cache.put(request, response.clone());
      }
      return response;
    }).catch(() => cached);
    
    return cached || fetchPromise;
  },

  async fetchWithCache(request) {
    const url = new URL(request.url);
    
    if (request.method !== 'GET') {
      return fetch(request);
    }
    
    if (this.isApiRequest(url)) {
      return this.networkFirst(request);
    }
    
    if (this.isImageRequest(url)) {
      return this.staleWhileRevalidate(request);
    }
    
    if (this.isStaticAsset(url)) {
      return this.cacheFirst(request);
    }
    
    try {
      return await fetch(request);
    } catch (error) {
      const cached = await caches.match(request);
      if (cached) {
        return cached;
      }
      throw error;
    }
  },

  async clear() {
    const cacheNames = await caches.keys();
    await Promise.all(cacheNames.map(name => caches.delete(name)));
    console.log('[CacheService] All caches cleared');
  },

  async getStats() {
    const stats = {};
    const cacheNames = await caches.keys();
    
    for (const name of cacheNames) {
      const cache = await caches.open(name);
      const keys = await cache.keys();
      stats[name] = keys.length;
    }
    
    return stats;
  }
};
