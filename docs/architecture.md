# Cafeana — System Architecture

## High-Level Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        Cafeana System                       │
│                                                             │
│  ┌──────────────────┐         ┌────────────────────────┐   │
│  │  Mobile/Web App  │◄───────►│      Firebase          │   │
│  │  (Flutter)       │         │  ┌──────────────────┐  │   │
│  │                  │         │  │  Authentication  │  │   │
│  │  Roles:          │         │  ├──────────────────┤  │   │
│  │  • Customer      │         │  │  Firestore DB    │  │   │
│  │  • Staff         │         │  ├──────────────────┤  │   │
│  └──────────────────┘         │  │  Cloud Functions │  │   │
│                               │  └──────────────────┘  │   │
│  ┌──────────────────┐         └────────────────────────┘   │
│  │  ESP32 Kitchen   │                    ▲                  │
│  │  Terminal        │────────────────────┘                  │
│  │  (PlatformIO)    │  WebSocket / REST                     │
│  └──────────────────┘                                       │
└─────────────────────────────────────────────────────────────┘
```

## Flutter App Layers

```
lib/
├── app/          → App bootstrap, router config
├── core/         → Shared providers, models, utilities
└── features/
    ├── auth/     → Login, session management
    ├── customer/ → Customer-facing screens (menu, ordering)
    └── staff/    → Staff-facing screens (orders queue, kitchen view)
```

## Role-Based Routing

```
User logs in
    │
    ▼
Firestore: users/{uid} → role field
    │
    ├── "customer" ──► /customer/home  (CustomerShell)
    │                      /customer/menu
    │
    └── "staff"    ──► /staff/home     (StaffShell)
                           /staff/orders
```

## State Management

**Riverpod** is used throughout. Key providers:

| Provider | Type | Purpose |
|---|---|---|
| `authStateChangesProvider` | `StreamProvider<User?>` | Auth session stream |
| `userProfileProvider(uid)` | `StreamProvider<UserProfile>` | Firestore profile stream |
| `firebaseAuthProvider` | `Provider<FirebaseAuth>` | Auth instance |
| `firestoreProvider` | `Provider<FirebaseFirestore>` | Firestore instance |

## ESP32 Firmware

The kitchen terminal firmware (`cafeana_kitchen_terminal`) connects to
Firebase via HTTP REST or MQTT to receive order updates and display them
on a screen. Placeholder implementation — details TBD.
