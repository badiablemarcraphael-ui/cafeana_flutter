# Firebase Setup Guide

The Flutter app ships with a **stub** `firebase_options.dart` that has
placeholder credentials. Follow these steps to connect it to a real Firebase
project.

## Prerequisites

- A Google account
- Node.js 18+ (for the Firebase CLI)
- The `flutterfire` CLI

## Step 1 — Install CLIs

```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli
```

## Step 2 — Create a Firebase Project

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Click **Add project** → name it `cafeana-prod` (or similar)
3. Enable **Authentication** → Sign-in method → Email/Password
4. Enable **Cloud Firestore** → Start in test mode (lock down rules before production)

## Step 3 — Configure the Flutter App

Run from within `mobile_web_app/`:

```bash
cd mobile_web_app
flutterfire configure --project=<your-firebase-project-id>
```

This will:
- Register Android & Web apps in Firebase
- Download `google-services.json` into `android/app/`
- Overwrite `lib/firebase_options.dart` with real credentials

## Step 4 — Firestore Data Model

Create a `users` collection. Each document ID = Firebase Auth UID:

```json
{
  "uid": "abc123",
  "email": "user@example.com",
  "displayName": "Alice",
  "role": "customer"   // or "staff"
}
```

## Step 5 — Firestore Security Rules (starter)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read: if request.auth.uid == uid;
      allow write: if false; // Only Cloud Functions should write
    }
  }
}
```

## Step 6 — Verify

```bash
flutter run -d chrome
```

Sign in with a user that has a valid `role` field — you should be redirected
to the correct app shell.
