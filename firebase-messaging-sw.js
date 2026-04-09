// Firebase Messaging Service Worker
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyAM3t4qBtb2FhUElkWvKbEF4Oui2I9rZGk",
  authDomain: "planner-web-4fec7.firebaseapp.com",
  projectId: "planner-web-4fec7",
  storageBucket: "planner-web-4fec7.firebasestorage.app",
  messagingSenderId: "884674213029",
  appId: "1:884674213029:web:423491ba151fcd0177894c",
  measurementId: "G-FTVNHS8G2Y"
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Background message received:', payload);
  
  const notificationTitle = payload.notification?.title || 'ООО Корнео';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: './icon-192.png',
    badge: './icon-192.png',
    tag: 'korneo-' + Date.now(),
    data: payload.data || {}
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.includes('/Korneo') && 'focus' in client) {
          return client.focus();
        }
      }
      return clients.openWindow('/Korneo/');
    })
  );
});
