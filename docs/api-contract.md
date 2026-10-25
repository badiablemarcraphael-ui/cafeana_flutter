# Cafeana — ESP32 Firestore REST API Contract

> **Audience**: Firmware engineers implementing `cafeana_kitchen_terminal`  
> **Transport**: HTTPS REST (Firestore REST API v1)  
> **Auth**: Firebase Auth via ID Token (obtained via REST sign-in, refreshed every 60 min)  
> **Base URL**: `https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents`

---

## Device Account Setup

The ESP32 authenticates as a dedicated Firebase Auth account with `role: "device"` stored in Firestore. This avoids custom claims (which require Cloud Functions on the Blaze plan).

### One-Time Setup Steps (done by a staff member, not the ESP32)

1. **Create the device Firebase Auth account**

   In Firebase Console → Authentication → Users → Add User:
   - Email: `device@cafeana.internal`
   - Password: generate a strong random password (≥ 32 chars), store it securely

   Note the UID that Firebase assigns (e.g., `device-uid-abc123`).

2. **Create the Firestore profile document**

   In Firebase Console → Firestore → `users` collection → Add document with ID = device UID:
   ```json
   {
     "uid":       "device-uid-abc123",
     "name":      "Kitchen Terminal 1",
     "email":     "device@cafeana.internal",
     "role":      "device",
     "isActive":  true,
     "createdAt": "<server timestamp>"
   }
   ```

3. **Store credentials on the ESP32**

   Flash the following into NVS (non-volatile storage) or `secrets.h`:
   ```cpp
   #define FIREBASE_API_KEY   "YOUR_WEB_API_KEY"     // Project Settings → General → Web API Key
   #define DEVICE_EMAIL       "device@cafeana.internal"
   #define DEVICE_PASSWORD    "STRONG_RANDOM_PASSWORD"
   #define FIREBASE_PROJECT   "YOUR_PROJECT_ID"
   ```

4. **Token refresh strategy**

   ID tokens expire after **60 minutes**. The ESP32 must refresh proactively:
   - Store `idToken` and `refreshToken` in memory (or NVS across reboots)
   - Refresh using the refresh endpoint (see §1.2 below) **before** the token expires

---

## §1 — Authentication

### §1.1 Sign In (obtain ID token)

Performed once on boot (or after token expiry with no refresh token in NVS).

```
POST https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword
     ?key={FIREBASE_API_KEY}
Content-Type: application/json
```

**Request body:**
```json
{
  "email":             "device@cafeana.internal",
  "password":          "STRONG_RANDOM_PASSWORD",
  "returnSecureToken": true
}
```

**Success response (200):**
```json
{
  "idToken":      "eyJhbG...",   // Use in Authorization header for all Firestore requests
  "refreshToken": "AMf-vB...",   // Store persistently for refresh
  "expiresIn":    "3600"         // Seconds; refresh before this elapses
}
```

**Error codes**: `EMAIL_NOT_FOUND`, `INVALID_PASSWORD`, `USER_DISABLED`

---

### §1.2 Refresh ID Token

```
POST https://securetoken.googleapis.com/v1/token
     ?key={FIREBASE_API_KEY}
Content-Type: application/json
```

**Request body:**
```json
{
  "grant_type":    "refresh_token",
  "refresh_token": "AMf-vB..."
}
```

**Success response (200):**
```json
{
  "id_token":      "eyJhbG...",
  "refresh_token": "AMf-vB...",   // May be a new token — always update stored value
  "expires_in":    "3600"
}
```

> **Recommended strategy**: Set a hardware timer for 55 minutes. On fire, call §1.2 before making any Firestore requests.

---

## §2 — Firestore REST Conventions

All Firestore requests use:
```
Authorization: Bearer {idToken}
Content-Type:  application/json
```

Firestore field values are typed objects:
```json
{ "stringValue": "hello" }
{ "integerValue": "42" }       // Note: integer is sent as a string in JSON
{ "doubleValue": 12.50 }
{ "booleanValue": true }
{ "timestampValue": "2026-09-11T05:00:00Z" }
{ "nullValue": null }
```

**Project base path:**
```
https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents
```

---

## §3 — Orders

### §3.1 Poll for Queued Orders

Fetch all orders with status `"queued"`, ordered by `createdAt` ascending (oldest first = serve in order).

```
POST {BASE}/orders:runQuery
Authorization: Bearer {idToken}
```

**Request body (structured query):**
```json
{
  "structuredQuery": {
    "from": [{ "collectionId": "orders" }],
    "where": {
      "fieldFilter": {
        "field": { "fieldPath": "status" },
        "op": "EQUAL",
        "value": { "stringValue": "queued" }
      }
    },
    "orderBy": [
      { "field": { "fieldPath": "createdAt" }, "direction": "ASCENDING" }
    ],
    "limit": 10
  }
}
```

**Success response (200):** Array of document objects. Each element:
```json
{
  "document": {
    "name": "projects/{PROJECT_ID}/databases/(default)/documents/orders/{orderId}",
    "fields": {
      "orderNumber":     { "integerValue": "42" },
      "customerId":      { "stringValue": "abc123" },
      "status":          { "stringValue": "queued" },
      "paymentStatus":   { "stringValue": "pending" },
      "total":           { "doubleValue": 30.0 },
      "createdAt":       { "timestampValue": "2026-09-11T05:10:00Z" },
      "updatedAt":       { "timestampValue": "2026-09-11T05:10:00Z" },
      "items": {
        "arrayValue": {
          "values": [
            {
              "mapValue": {
                "fields": {
                  "productId":  { "stringValue": "prod-001" },
                  "name":       { "stringValue": "Caramel Latte" },
                  "quantity":   { "integerValue": "2" },
                  "price":      { "doubleValue": 15.0 }
                }
              }
            }
          ]
        }
      }
    }
  }
}
```

> **Poll interval**: 5–10 seconds is sufficient. Use `updatedAt` to detect changes since last poll.

---

### §3.2 Acknowledge Order (queued → preparing)

Called when the ESP32 picks up an order to display it.

```
PATCH {BASE}/orders/{orderId}
      ?updateMask.fieldPaths=status
      &updateMask.fieldPaths=terminalId
      &updateMask.fieldPaths=updatedAt
Authorization: Bearer {idToken}
```

**Request body:**
```json
{
  "fields": {
    "status":     { "stringValue": "preparing" },
    "terminalId": { "stringValue": "kitchenTerminal" },
    "updatedAt":  { "timestampValue": "2026-09-11T05:11:00Z" }
  }
}
```

**Success response (200):** Updated document object.

> ⚠️ Use the `updateMask` query params — they prevent accidentally overwriting other fields.

---

### §3.3 Mark Order Ready (preparing → ready)

Called when staff physically presses the "ready" button on the terminal.

```
PATCH {BASE}/orders/{orderId}
      ?updateMask.fieldPaths=status
      &updateMask.fieldPaths=updatedAt
Authorization: Bearer {idToken}
```

**Request body:**
```json
{
  "fields": {
    "status":    { "stringValue": "ready" },
    "updatedAt": { "timestampValue": "2026-09-11T05:15:00Z" }
  }
}
```

---

## §4 — Device Status (Heartbeat)

### §4.1 Write Heartbeat

Called every **30 seconds** to indicate the terminal is online.

```
PATCH {BASE}/deviceStatus/kitchenTerminal
      ?updateMask.fieldPaths=online
      &updateMask.fieldPaths=lastSeen
      &updateMask.fieldPaths=firmwareVersion
Authorization: Bearer {idToken}
```

**Request body:**
```json
{
  "fields": {
    "online":          { "booleanValue": true },
    "lastSeen":        { "timestampValue": "2026-09-11T05:15:00Z" },
    "firmwareVersion": { "stringValue": "0.1.0" }
  }
}
```

**First-time boot** (document may not exist yet) — use `PUT` or `PATCH` with `currentDocument.exists: false`:

```
PATCH {BASE}/deviceStatus/kitchenTerminal
      ?currentDocument.exists=false
```

With full document:
```json
{
  "fields": {
    "online":              { "booleanValue": true },
    "lastSeen":            { "timestampValue": "2026-09-11T05:00:00Z" },
    "currentOrderNumber":  { "nullValue": null },
    "firmwareVersion":     { "stringValue": "0.1.0" }
  }
}
```

---

### §4.2 Update Current Order Number

Called when the terminal starts displaying a new order.

```
PATCH {BASE}/deviceStatus/kitchenTerminal
      ?updateMask.fieldPaths=currentOrderNumber
      &updateMask.fieldPaths=lastSeen
Authorization: Bearer {idToken}
```

**Request body:**
```json
{
  "fields": {
    "currentOrderNumber": { "integerValue": "42" },
    "lastSeen":           { "timestampValue": "2026-09-11T05:11:00Z" }
  }
}
```

---

### §4.3 Write Offline Status (clean shutdown)

Called in the `shutdown()` / watchdog handler when the device reboots or disconnects cleanly.

```
PATCH {BASE}/deviceStatus/kitchenTerminal
      ?updateMask.fieldPaths=online
      &updateMask.fieldPaths=lastSeen
Authorization: Bearer {idToken}
```

**Request body:**
```json
{
  "fields": {
    "online":   { "booleanValue": false },
    "lastSeen": { "timestampValue": "2026-09-11T05:59:00Z" }
  }
}
```

---

## §5 — Error Handling

| HTTP Code | Meaning | Action |
|---|---|---|
| `200` | Success | Continue |
| `400` | Bad request / malformed JSON | Log and skip — don't retry |
| `401` | Token expired or invalid | Refresh token (§1.2) then retry once |
| `403` | Permission denied | Role rule failed — check device `users` doc exists and `role == "device"` |
| `404` | Document not found | Create document (e.g., first heartbeat) |
| `409` | Conflict (concurrent write) | Retry with exponential backoff (max 3 attempts) |
| `429` | Quota exceeded | Back off for 60 seconds; log to serial |
| `500`/`503` | Firebase outage | Back off 30 s; log; retry |

**Recommended retry logic:**
```cpp
// Pseudo-code
int attempt = 0;
while (attempt < 3) {
  int status = makeFirestoreRequest(...);
  if (status == 200) break;
  if (status == 401) { refreshToken(); }
  delay(pow(2, attempt) * 1000);  // 1s, 2s, 4s
  attempt++;
}
```

---

## §6 — Firestore REST Timestamp Format

The ESP32 must format timestamps as **RFC 3339 UTC strings**:
```
YYYY-MM-DDTHH:MM:SSZ
```

**Arduino / ESP32 snippet using `time.h`:**
```cpp
#include <time.h>

String getTimestamp() {
  time_t now;
  time(&now);
  char buf[21];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", gmtime(&now));
  return String(buf);
}
```

Requires NTP sync on startup:
```cpp
configTime(0, 0, "pool.ntp.org", "time.nist.gov");
```

---

## §7 — Summary Table

| Operation | Method | Path | Frequency |
|---|---|---|---|
| Sign in | `POST` | `identitytoolkit.googleapis.com/v1/accounts:signInWithPassword` | Boot |
| Refresh token | `POST` | `securetoken.googleapis.com/v1/token` | Every 55 min |
| Poll queued orders | `POST` (runQuery) | `.../orders:runQuery` | Every 5–10 s |
| Acknowledge order | `PATCH` | `.../orders/{orderId}` | On new order |
| Mark order ready | `PATCH` | `.../orders/{orderId}` | On button press |
| Heartbeat | `PATCH` | `.../deviceStatus/kitchenTerminal` | Every 30 s |
| Update current order | `PATCH` | `.../deviceStatus/kitchenTerminal` | On display change |
| Mark offline | `PATCH` | `.../deviceStatus/kitchenTerminal` | On shutdown |
