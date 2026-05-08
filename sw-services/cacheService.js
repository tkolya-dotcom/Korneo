// sw-services/cacheService.js - Cache management for Service Worker

const CACHE_VERSION = 'v1';
const STATIC_CACHE = `static-${CACHE_VERSION}`;
const API_CACHE = `api-${CACHE_VERSION}`;
const IMAGE_CACHE = `images-${CACHE_VERSION}`;

// Supabase config (hardcoded for SW context)
const SUPABASE_URL = 'https://jmxjbdnqnzkzxgsfywha.supabase.co';

// Static assets to cache on install (relative paths for GitHub Pages compatibility)
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

// Cache strategies
const cacheService = {
  // Initialize cache on install
  async install() {
    const cache = await caches.open(STATIC_CACHE);
    await cache.addAll(STATIC_ASSETS);
    console.log('[CacheService] Static assets cached');
  },

  // Clean up old caches on activate
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

  // Determine if request is for static asset
  isStaticAsset(url) {
    const staticExtensions = /\.(js|css|png|jpg|jpeg|gif|svg|ico|woff|woff2|ttf|eot)$/;
    return staticExtensions.test(url.pathname);
  },

  // Determine if request is API call
  isApiRequest(url) {
    return url.href.includes(SUPABASE_URL) || 
           url.pathname.startsWith('/rest/v1/') ||
           url.pathname.startsWith('/auth/v1/');
  },

  // Determine if request is for image
  isImageRequest(url) {
    return /\.(png|jpg|jpeg|gif|svg|webp)$/i.test(url.pathname);
  },

  // Cache-first strategy for static assets
  async cacheFirst(request) {
    const cache = await caches.open(STATIC_CACHE);
    const cached = await cache.match(request);
    
    if (cached) {
      // Update cache in background
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

  // Network-first strategy for API calls
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

  // Stale-while-revalidate for images
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

  // Main fetch handler
  async fetchWithCache(request) {
    const url = new URL(request.url);
    
    // Skip non-GET requests
    if (request.method !== 'GET') {
      return fetch(request);
    }
    
    // API calls - network first
    if (this.isApiRequest(url)) {
      return this.networkFirst(request);
    }
    
    // Images - stale while revalidate
    if (this.isImageRequest(url)) {
      return this.staleWhileRevalidate(request);
    }
    
    // Static assets - cache first
    if (this.isStaticAsset(url)) {
      return this.cacheFirst(request);
    }
    
    // Default - network with cache fallback
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

  // Clear all caches
  async clear() {
    const cacheNames = await caches.keys();
    await Promise.all(cacheNames.map(name => caches.delete(name)));
    console.log('[CacheService] All caches cleared');
  },

  // Get cache stats
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
