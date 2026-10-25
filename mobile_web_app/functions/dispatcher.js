/**
 * Cafeana Push Dispatcher Daemon (Spark Plan / Standalone mode)
 *
 * This daemon connects directly to Firestore in real time, listens for order status updates,
 * and delivers high-priority FCM push notifications to customers' cellphones even when
 * their mobile app is closed.
 *
 * Runs on any workstation, cashier terminal, or server without requiring a paid Blaze plan.
 *
 * Usage:
 *   cd functions
 *   node dispatcher.js
 */

const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

// Initialize Firebase Admin with project credentials or service account
const keyPath = path.join(__dirname, "serviceAccountKey.json");
if (fs.existsSync(keyPath)) {
  const serviceAccount = require(keyPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: "cafeana-7fa42",
  });
  console.log("[Dispatcher] Loaded credentials from serviceAccountKey.json");
} else {
  admin.initializeApp({
    projectId: "cafeana-7fa42",
  });
  console.log("[Dispatcher] Using default application credentials / cloud environment");
}

const db = admin.firestore();

function getNotificationContent(orderNumber, status) {
  const normStatus = (status || "").toLowerCase();
  switch (normStatus) {
    case "queued":
      return {
        title: `Order #${orderNumber} Received ⏳`,
        body: "Your order has been queued in the kitchen. We will alert you when preparation starts!",
      };
    case "preparing":
      return {
        title: `Preparing Order #${orderNumber} ☕`,
        body: "The kitchen has started preparing your artisanal drink!",
      };
    case "ready":
      return {
        title: `Order #${orderNumber} Ready for Pickup! 🎉`,
        body: `Order #${orderNumber} is ready at the counter! Please come collect your order.`,
      };
    case "completed":
    case "received":
      return {
        title: `Order #${orderNumber} Completed ✨`,
        body: "Thank you for ordering at Caféana! Enjoy every sip.",
      };
    case "cancelled":
      return {
        title: `Order #${orderNumber} Cancelled`,
        body: `Your order #${orderNumber} has been cancelled.`,
      };
    default:
      return {
        title: `Order #${orderNumber} Update`,
        body: `Your order status is now: ${status}`,
      };
  }
}

async function sendPushToToken(token, orderId, orderNumber, status) {
  if (!token) return null;

  const content = getNotificationContent(orderNumber, status);

  const message = {
    token: token,
    notification: {
      title: content.title,
      body: content.body,
    },
    data: {
      orderId: String(orderId),
      orderNumber: String(orderNumber),
      status: String(status),
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: {
      priority: "high",
      notification: {
        channelId: "cafeana_orders",
        sound: "default",
        priority: "high",
        defaultSound: true,
        defaultVibrateTimings: true,
        notificationCount: 1,
        clickAction: "FLUTTER_NOTIFICATION_CLICK",
      },
    },
    webpush: {
      notification: {
        title: content.title,
        body: content.body,
        icon: "/favicon.png",
        badge: "/favicon.png",
      },
      fcmOptions: {
        link: `/customer/order/${orderId}`,
      },
    },
  };

  try {
    const response = await admin.messaging().send(message);
    console.log(`[Push Sent] '${content.title}' -> Order #${orderNumber} (FCM ID: ${response})`);
    return response;
  } catch (error) {
    console.error(`[Push Failed] Order #${orderNumber} token: ${token.substring(0, 15)}... Error:`, error.message);
    return null;
  }
}

console.log("=================================================");
console.log("  Caféana Real-Time Push Dispatcher Started  ");
console.log("  Project: cafeana-7fa42                          ");
console.log("  Listening for order updates across mobile & web ");
console.log("=================================================");

const knownStatuses = new Map();
let isInitialLoad = true;

db.collection("orders").onSnapshot(
  async (snapshot) => {
    if (isInitialLoad) {
      snapshot.forEach((doc) => {
        const data = doc.data();
        knownStatuses.set(doc.id, data.status);
      });
      console.log(`[Dispatcher] Initialized with ${knownStatuses.size} active order records.`);
      isInitialLoad = false;
      return;
    }

    for (const change of snapshot.docChanges()) {
      const doc = change.doc;
      const orderId = doc.id;
      const data = doc.data();
      const currentStatus = data.status;
      const orderNumber = data.orderNumber || 0;
      const customerId = data.customerId;

      let fcmToken = data.customerFcmToken;
      if (!fcmToken && customerId) {
        try {
          const userDoc = await db.collection("users").doc(customerId).get();
          if (userDoc.exists) {
            fcmToken = userDoc.data().fcmToken;
          }
        } catch (e) {
          // ignore lookup error
        }
      }

      if (change.type === "added") {
        if (!knownStatuses.has(orderId)) {
          console.log(`[Dispatcher] New order created: #${orderNumber} (${currentStatus})`);
          if (fcmToken) {
            await sendPushToToken(fcmToken, orderId, orderNumber, currentStatus);
          }
          knownStatuses.set(orderId, currentStatus);
        }
      } else if (change.type === "modified") {
        const prevStatus = knownStatuses.get(orderId);
        if (prevStatus !== currentStatus) {
          console.log(`[Dispatcher] Order #${orderNumber} status changed: ${prevStatus} -> ${currentStatus}`);
          if (fcmToken) {
            await sendPushToToken(fcmToken, orderId, orderNumber, currentStatus);
          }
          knownStatuses.set(orderId, currentStatus);
        }
      }
    }
  },
  (error) => {
    console.error("[Dispatcher Error] Firestore stream error:", error);
  }
);
