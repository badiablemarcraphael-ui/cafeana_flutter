# Caféana — Free Spark Plan Push & Taskbar Notifications Guide

> **Core Philosophy**: Caféana is designed to operate **100% on the Free Firebase Spark Plan**.  
> You do **not** need a paid Blaze plan, credit cards, or Cloud Functions to have instant notifications across mobile phones and websites.

---

## 1. How It Works on the Free Spark Plan

| Notification Channel | Target Device | Spark Plan Mechanism | Cost |
|---|---|---|---|
| **Live Order Tracking (Ongoing Notification)** | Customer Android Cellphone | Flutter Local Notifications with high-priority channel (`cafeana_orders`). Pinned to Android notification drawer while order is active (`queued`, `preparing`, `ready`). Updates in-place with sound & vibration. | **$0.00 (Free)** |
| **Website / Desktop Taskbar** | Windows / macOS / Linux Browser | HTML5 Web Notifications API (`Notification.requestPermission` & `showNotification`). Pops native Windows Taskbar toast / Mac Notification Center. | **$0.00 (Free)** |
| **Foreground & Background Listeners** | Mobile App & Web App | Real-time Firestore snapshot listeners (`orders/{id}`). Instant status detection when ESP32 or staff advances the order. | **$0.00 (Free)** |
| **Tap-to-Track Navigation** | Mobile & Web | Tapping any notification from the notification tray or taskbar automatically navigates directly to the specific `/customer/order/:orderId` tracking screen. | **$0.00 (Free)** |

---

## 2. Order Notification Flow

```
Customer Places Order
        │
        ▼
Status: "queued" ⏳
   • Mobile: Pinned ongoing notification appears in Android status bar:
     "Order #4 Received ⏳ — Your order has been queued in the kitchen."
   • Web: Desktop taskbar notification pops up.
        │
        ▼
Kitchen starts making drink (Staff app)
Status: "preparing" ☕
   • Mobile: Notification updates in-place with sound & vibration:
     "Preparing Order #4 ☕ — The kitchen has started preparing your artisanal drink!"
   • Web: Desktop taskbar notification pops up.
        │
        ▼
Cook presses ESP32 Terminal button
Status: "ready" 🎉
   • Mobile: High-priority heads-up notification with sound & vibration:
     "Order #4 Ready for Pickup! 🎉 — Order #4 is ready at the counter!"
   • Web: Desktop taskbar notification pops up.
        │
        ▼
Customer picks up drink (Staff marks complete)
Status: "completed" ✨
   • Mobile: "Order #4 Completed ✨ — Thank you for ordering at Caféana!"
   • Notification unpins and can be dismissed.
```

---

## 3. Real-Time Dispatcher (Optional for Store POS / Cashier PC)

If you want FCM push notifications delivered to customer phones even if their app was forcefully killed from recent apps:
- FCM messaging itself is **100% free and unlimited** on the Spark Plan.
- You can run the lightweight listener on your cashier PC or terminal:
  ```bash
  cd mobile_web_app/functions
  npm run listen
  ```
- This standalone dispatcher listens to Firestore `orders` and pushes FCM notifications without needing Cloud Functions or a Blaze plan.

---

## 4. Spark Plan Quota Best Practices

- **Reads Quota**: Spark plan allows **50,000 reads/day**. Real-time Firestore listeners hold a single open connection and do not repeatedly poll.
- **Writes Quota**: Spark plan allows **20,000 writes/day**. Each order status transition is a single document write.
- **Push Messaging**: Firebase Cloud Messaging (FCM) is **unlimited and free** forever on the Spark plan.
