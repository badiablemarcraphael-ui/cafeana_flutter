const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Maps an order status into a customer-friendly push notification title and body.
 */
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

/**
 * Sends a high-priority FCM push notification to a device token.
 * This delivers directly to the Android notification drawer / cellphone taskbar
 * even when the mobile app is completely closed / removed from recent apps.
 */
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
    console.log(`[FCM Success] Sent '${content.title}' to token ${token.substring(0, 15)}... ID: ${response}`);
    return response;
  } catch (error) {
    console.error(`[FCM Error] Failed sending to token ${token.substring(0, 15)}...:`, error);
    return null;
  }
}

/**
 * Cloud Function: Triggered when any order document in Firestore is modified.
 * Fired when ESP32 button marks order "ready", or staff marks "preparing"/"ready"/"completed".
 */
exports.onOrderUpdated = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const orderId = context.params.orderId;

    if (!beforeData || !afterData) return null;

    // Only notify if order status has changed
    if (beforeData.status === afterData.status) {
      return null;
    }

    const newStatus = afterData.status;
    const orderNumber = afterData.orderNumber || 0;
    const customerId = afterData.customerId;

    console.log(`[Order Update] Order #${orderNumber} (${orderId}) changed: ${beforeData.status} -> ${newStatus}`);

    // Retrieve the customer FCM token (first check order itself, then user document)
    let fcmToken = afterData.customerFcmToken;
    if (!fcmToken && customerId) {
      try {
        const userDoc = await admin.firestore().collection("users").doc(customerId).get();
        if (userDoc.exists) {
          fcmToken = userDoc.data().fcmToken;
        }
      } catch (err) {
        console.warn(`[Order Update] Could not fetch user doc for ${customerId}:`, err);
      }
    }

    if (!fcmToken) {
      console.log(`[Order Update] No FCM token found for customer ${customerId} (Order #${orderNumber})`);
      return null;
    }

    return sendPushToToken(fcmToken, orderId, orderNumber, newStatus);
  });

/**
 * Cloud Function: Triggered when a new order document is placed by customer.
 * Immediately pushes confirmation notification to their cellphone / taskbar.
 */
exports.onOrderCreated = functions.firestore
  .document("orders/{orderId}")
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    const orderId = context.params.orderId;
    if (!data) return null;

    const orderNumber = data.orderNumber || 0;
    const status = data.status || "queued";
    const customerId = data.customerId;

    let fcmToken = data.customerFcmToken;
    if (!fcmToken && customerId) {
      try {
        const userDoc = await admin.firestore().collection("users").doc(customerId).get();
        if (userDoc.exists) {
          fcmToken = userDoc.data().fcmToken;
        }
      } catch (err) {
        console.warn(`[Order Created] Could not fetch user doc for ${customerId}:`, err);
      }
    }

    if (!fcmToken) return null;

    return sendPushToToken(fcmToken, orderId, orderNumber, status);
  });
