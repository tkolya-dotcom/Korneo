// service-worker.js - Modular Service Worker with Separation of Concerns
// Imports services from sw-services/

importScripts(
  './sw-services/cacheService.js',
  './sw-services/pushService.js',
  './sw-services/trackingService.js',
  './sw-services/chatService.js'
);

// Initialize services
trackingService.init();

// ===== Lifecycle Events =====

self.addEventListener('install', (event) => {
  event.waitUntil(cacheService.install());
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    cacheService.activate().then(() => {
      self.clients.claim();
      trackingService.track('sw_activate');
    })
  );
});

// ===== Fetch Events (Cache Service) =====

self.addEventListener('fetch', (event) => {
  event.respondWith(cacheService.fetchWithCache(event.request));
});

// ===== Push Events (Push Service) =====

self.addEventListener('push', (event) => {
  trackingService.updateState({ notificationsReceived: trackingService.state.notificationsReceived + 1 });
  
  // Всегда показываем push уведомление, независимо от активности чата
  // Проверяем через Chat Service только для обновления badge
  const pushData = event.data?.json() || {};
  if (pushData.chat_id) {
    chatService.handleMessage({
      chat_id: pushData.chat_id,
      id: pushData.message_id
    });
  }
  
  event.waitUntil(
    pushService.handlePush(event).then(() => {
      chatService.updateBadge();
    })
  );
});

// ===== Notification Click (Push Service) =====

self.addEventListener('notificationclick', (event) => {
  event.waitUntil(pushService.handleClick(event));
});

self.addEventListener('notificationclose', (event) => {
  trackingService.track('notification_close', { tag: event.notification.tag });
});

// ===== Message Events (Chat Service + Communication) =====

self.addEventListener('message', (event) => {
  // Chat service messages
  chatService.handleClientMessage(event);
  
  // Tracking
  if (event.data?.type) {
    trackingService.track('client_message', { type: event.data.type });
  }
  
  // Специальные команды
  switch (event.data?.type) {
    case 'GET_SW_STATE':
      event.source.postMessage({
        type: 'SW_STATE',
        state: trackingService.getState(),
        chat: chatService.getStats()
      });
      break;
      
    case 'TRACK_EVENT':
      trackingService.track(event.data.event, event.data.data);
      break;
      
    case 'SYNC_NOW':
      trackingService.flushQueue();
      chatService.flushQueue();
      break;
      
    case 'CLEAR_CACHE':
      event.waitUntil(cacheService.clear());
      break;
  }
});

// ===== Background Sync =====

self.addEventListener('sync', (event) => {
  if (event.tag === 'sync-messages') {
    event.waitUntil(
      chatService.flushQueue().then(() => {
        trackingService.track('background_sync');
      })
    );
  }
});

// ===== Periodic Background Sync (если поддерживается) =====

self.addEventListener('periodicsync', (event) => {
  if (event.tag === 'periodic-sync') {
    event.waitUntil(
      Promise.all([
        trackingService.syncState(),
        chatService.updateBadge()
      ])
    );
  }
});

