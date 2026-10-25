# Cafeana — Firestore Data Model

> **Last updated**: 2026-09-11  
> **Design constraints**: Firebase Spark plan (no Cloud Functions). All server-side logic is handled via Firestore transactions in the Flutter app or manually by staff.

---

## Collection Index

| Collection | Purpose | Writers | Readers |
|---|---|---|---|
| `users` | Auth profiles + roles | Staff (admin creates), device account self-created | Owner, staff |
| `counters` | Sequential number generation | Authenticated (transactional) | Authenticated |
| `products` | Menu catalogue | Staff | All authenticated |
| `orders` | Customer orders lifecycle | Customer (create), staff (update status) | Customer (own), staff, device |
| `deviceStatus` | ESP32 terminal heartbeat | Device | Staff |
| `feedback` | Post-order ratings | Customer (own order) | Customer (own), staff |
| `inventoryLog` | Stock change audit trail | Staff only | Staff |

---

## Document Schemas

### `users/{uid}`

Populated on first sign-in (Flutter app) or manually for the device account.

| Field | Type | Required | Notes |
|---|---|---|---|
| `uid` | `string` | ✅ | Mirrors the document ID |
| `name` | `string` | ✅ | Display name |
| `email` | `string` | ✅ | |
| `role` | `string` | ✅ | `"customer"` \| `"staff"` \| `"device"` |
| `isActive` | `bool` | ✅ | `false` = soft-deactivated, cannot use app |
| `createdAt` | `timestamp` | ✅ | Server timestamp on creation |

**Indexes**: none needed (looked up by UID which is the doc ID).

```jsonc
// Example — customer
{
  "uid": "abc123",
  "name": "Alice Tan",
  "email": "alice@example.com",
  "role": "customer",
  "isActive": true,
  "createdAt": "2026-09-11T00:00:00Z"
}

// Example — device account (kitchen terminal)
{
  "uid": "device-uid-xyz",
  "name": "Kitchen Terminal 1",
  "email": "device@cafeana.internal",
  "role": "device",
  "isActive": true,
  "createdAt": "2026-09-11T00:00:00Z"
}
```

---

### `counters/global`

Single document used to generate sequential order numbers via Firestore transactions.
The Flutter app runs a transaction: read → increment → return new value → write to order.

| Field | Type | Notes |
|---|---|---|
| `nextOrderNumber` | `number` | Starts at 1, incremented atomically per order |

```jsonc
{
  "nextOrderNumber": 42
}
```

> **Security**: Only authenticated users can read. Only authenticated users can update
> `nextOrderNumber` **upward** (rules enforce increment-only semantics via
> `request.resource.data.nextOrderNumber == resource.data.nextOrderNumber + 1`).

---

### `products/{productId}`

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | `string` | ✅ | Display name on menu |
| `price` | `number` | ✅ | In local currency, stored as float (e.g. `12.50`) |
| `category` | `string` | ✅ | e.g. `"drink"`, `"food"`, `"dessert"` |
| `stock` | `number` | ✅ | Current stock count; `null` = unlimited |
| `isAvailable` | `bool` | ✅ | Staff toggle; hides from customer menu when `false` |
| `imageUrl` | `string` | ❌ | Firebase Storage URL; omit if no image |
| `updatedAt` | `timestamp` | ✅ | Last modified |

```jsonc
{
  "name": "Caramel Latte",
  "price": 15.00,
  "category": "drink",
  "stock": null,
  "isAvailable": true,
  "imageUrl": "gs://cafeana.appspot.com/products/caramel-latte.jpg",
  "updatedAt": "2026-09-11T05:00:00Z"
}
```

**Indexes**: `category ASC, isAvailable ASC` (for filtered menu queries).

---

### `orders/{orderId}`

| Field | Type | Required | Notes |
|---|---|---|---|
| `orderNumber` | `number` | ✅ | Sequential integer from `counters/global` |
| `customerId` | `string` | ✅ | UID of the placing customer |
| `terminalId` | `string` | ❌ | Set by ESP32 when it picks up the order |
| `items` | `array<Item>` | ✅ | Embedded line items (see below) |
| `total` | `number` | ✅ | Sum of `item.price × item.quantity` |
| `paymentStatus` | `string` | ✅ | `"pending"` \| `"paid"` |
| `status` | `string` | ✅ | See lifecycle below |
| `note` | `string` | ❌ | Optional customer note |
| `createdAt` | `timestamp` | ✅ | Server timestamp |
| `updatedAt` | `timestamp` | ✅ | Updated on every status change |

**`Item` object** (embedded in `items` array):

| Field | Type | Notes |
|---|---|---|
| `productId` | `string` | Reference to `products/{productId}` |
| `name` | `string` | Snapshot of name at order time (denormalised) |
| `quantity` | `number` | Integer ≥ 1 |
| `price` | `number` | Snapshot of unit price at order time |

**Order lifecycle**:

```
created (by customer)
    │
    ▼
"queued"      ← initial status; ESP32 picks up here
    │
    ▼
"preparing"   ← staff/device acknowledges
    │
    ▼
"ready"       ← kitchen marks ready; customer notified
    │
    ▼
"received"    ← customer confirms pickup
    │
    ▼
"completed"   ← final state; triggers feedback prompt
```

> `paymentStatus` transitions independently: `"pending"` → `"paid"` (set by staff after payment received).

**Indexes**:
- `customerId ASC, createdAt DESC` — customer order history
- `status ASC, createdAt ASC` — device polling for queued orders
- `status ASC, updatedAt DESC` — staff dashboard

```jsonc
{
  "orderNumber": 42,
  "customerId": "abc123",
  "terminalId": "kitchenTerminal",
  "items": [
    {
      "productId": "prod-001",
      "name": "Caramel Latte",
      "quantity": 2,
      "price": 15.00
    }
  ],
  "total": 30.00,
  "paymentStatus": "pending",
  "status": "queued",
  "note": "Extra hot please",
  "createdAt": "2026-09-11T05:10:00Z",
  "updatedAt": "2026-09-11T05:10:00Z"
}
```

---

### `deviceStatus/{terminalId}`

One document per physical terminal. `terminalId` is a human-readable slug, e.g. `kitchenTerminal`.

| Field | Type | Notes |
|---|---|---|
| `online` | `bool` | `true` while heartbeat is current |
| `lastSeen` | `timestamp` | Updated by ESP32 on every heartbeat (every 30 s) |
| `currentOrderNumber` | `number` \| `null` | Order the terminal is currently displaying |
| `firmwareVersion` | `string` | e.g. `"0.1.0"` |

```jsonc
{
  "online": true,
  "lastSeen": "2026-09-11T05:15:00Z",
  "currentOrderNumber": 41,
  "firmwareVersion": "0.1.0"
}
```

**Staleness rule**: If `lastSeen` > 60 s ago, the Flutter staff app should display the terminal as offline regardless of the `online` flag (the ESP32 may have crashed without writing `online: false`).

---

### `feedback/{feedbackId}`

| Field | Type | Required | Notes |
|---|---|---|---|
| `orderId` | `string` | ✅ | Parent order |
| `customerId` | `string` | ✅ | Must match `orders/{orderId}.customerId` |
| `rating` | `number` | ✅ | Integer 1–5 |
| `comment` | `string` | ❌ | Free text, max 500 chars |
| `createdAt` | `timestamp` | ✅ | |

**Business rule**: One feedback document per order. Enforced in security rules by checking `!exists(/databases/.../feedback/<orderId>)`.

```jsonc
{
  "orderId": "order-xyz",
  "customerId": "abc123",
  "rating": 5,
  "comment": "Fast and delicious!",
  "createdAt": "2026-09-11T05:30:00Z"
}
```

---

### `inventoryLog/{logId}`

| Field | Type | Required | Notes |
|---|---|---|---|
| `productId` | `string` | ✅ | Which product was adjusted |
| `change` | `number` | ✅ | Signed integer: negative = stock reduced, positive = restocked |
| `reason` | `string` | ✅ | `"restock"` \| `"damage"` \| `"correction"` \| `"sale"` |
| `orderId` | `string` | ❌ | Populated when reason is `"sale"` |
| `staffId` | `string` | ✅ | UID of staff member who made the entry |
| `timestamp` | `timestamp` | ✅ | |

```jsonc
{
  "productId": "prod-001",
  "change": -2,
  "reason": "sale",
  "orderId": "order-xyz",
  "staffId": "staff-uid-456",
  "timestamp": "2026-09-11T05:10:30Z"
}
```

---

## Relationships Diagram

```
users/{uid}
    │
    ├─── orders/{orderId} (customerId → uid)
    │         │
    │         ├─── feedback/{feedbackId} (orderId)
    │         └─── inventoryLog/{logId}  (orderId, reason="sale")
    │
    └─── inventoryLog/{logId} (staffId → uid)

products/{productId}
    ├─── orders/{orderId}.items[].productId
    └─── inventoryLog/{logId}.productId

counters/global  ←  read+increment when creating order

deviceStatus/{terminalId}  ←  ESP32 heartbeat + current order
    └─── orders/{orderId}.terminalId
```

---

## Design Decisions & Rationale

| Decision | Rationale |
|---|---|
| Items embedded in orders array | Orders are rarely >10 items; embedding avoids subcollection reads |
| Prices denormalised in order items | Prevents price changes from retroactively affecting historical orders |
| `counters/global` transaction | Only safe Spark-compatible way to get sequential integers |
| `role: "device"` in users doc | Avoids custom claims (requires Cloud Functions / Blaze) |
| `deviceStatus` as collection | Zero extra work now; supports multiple terminals in future |
| `feedback` ID = `orderId` | Enables `!exists()` check to enforce one-feedback-per-order rule |
| Staff manages inventory manually | Spark plan has no Cloud Functions for automatic stock decrement |
