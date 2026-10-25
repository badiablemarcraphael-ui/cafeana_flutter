// Firebase Messaging Service Worker for Cafeana Web Push Notifications
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker
firebase.initializeApp({
  apiKey: "AIzaSyCdBnSkIKPACwuQb_FBOhgAJSN-tOzUTvo",
  authDomain: "cafeana-7fa42.firebaseapp.com",
  projectId: "cafeana-7fa42",
  storageBucket: "cafeana-7fa42.firebasestorage.app",
  messagingSenderId: "495457806256",
  appId: "1:495457806256:web:d52ff4f29118ff371d5875"
});

const messaging = firebase.messaging();

// Handle background push messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message: ', payload);
  const notificationTitle = payload.notification?.title || payload.data?.title || 'Caféana Order Update';
  const notificationOptions = {
    body: payload.notification?.body || payload.data?.body || 'Your order status has changed.',
    icon: '/favicon.png',
    badge: '/favicon.png',
    tag: payload.data?.orderId || 'cafeana-order',
    data: payload.data
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Focus or open customer app when user clicks on notification in taskbar
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (const client of windowClients) {
        if ('focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    })
  );
});
