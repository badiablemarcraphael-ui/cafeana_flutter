# Cafeana POS & Kiosk App

Cafeana is a modern, full-stack Flutter application serving as both a Customer Kiosk (self-service ordering) and a Staff Management Dashboard (Point of Sale, inventory, order fulfillment, and analytics) for a coffee shop. It uses Firebase as the backend for authentication, real-time database, and cloud functions.

## Features

### 🛒 Customer Kiosk
- **Self-Service Ordering**: Browse the menu, customize items, and place orders directly.
- **Order Queue Tracking**: Track order status in real-time from "In Queue" to "Ready" to "Completed".
- **Feedback System**: Provide ratings and feedback for completed orders.
- **Authentication**: Seamless customer login/signup flow.

### 👩‍🍳 Staff Dashboard
- **Live Order Queue**: Monitor and advance orders (In Queue ➔ Wokwi / Preparation ➔ Ready ➔ Completed).
- **Menu Management**: Add, edit, or remove products and categories from the menu dynamically.
- **Inventory Tracking**: Monitor stock levels in real-time. Highlights low-stock items automatically.
- **Sales & Analytics**: Export daily/weekly sales reports and inventory reports as CSV.
- **Customer Feedback**: Review customer ratings and comments.
- **Device Status**: Monitor the connection status of the Kitchen Terminal.

## Tech Stack
- **Framework**: [Flutter](https://flutter.dev/) (Mobile & Web)
- **State Management**: [Riverpod](https://riverpod.dev/) (Code Generation / AsyncNotifier)
- **Routing**: [GoRouter](https://pub.dev/packages/go_router) for deep linking and declarative routing.
- **Backend**: Firebase (Firestore, Firebase Auth)
- **Architecture**: Feature-first structure for scalability.

## Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- A Firebase project with Firestore and Authentication enabled.

### Setup Instructions

1. **Clone the repository**:
   ```bash
   git clone <repository_url>
   cd cafeana_flutter/mobile_web_app
   ```

2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**:
   Run the `flutterfire configure` command to connect the app to your Firebase project, which will generate `firebase_options.dart`.
   ```bash
   flutterfire configure
   ```

4. **Seed the Database (Dev Only)**:
   For local development, you can seed the database with dummy products, orders, and user accounts.
   - Launch the app as a Staff user.
   - Click the **Bug Icon** (🐞) in the top-right corner of the Staff Dashboard to seed the database instantly.

5. **Run the App**:
   ```bash
   flutter run
   ```

## Project Structure
The app follows a feature-first architecture (`lib/features/`):
- `auth`: Login, registration, and user session logic.
- `customer`: Kiosk UI, menu browsing, cart, and checkout.
- `staff`: POS dashboard, inventory, order feed, menu management, and analytics.
- `core`: Shared models, providers (Firebase, Riverpod), and utilities (e.g. CSV exporter).

## Architecture Highlights
- **StreamProviders**: Used extensively for real-time order queue and inventory sync across multiple devices.
- **Optimistic UI**: Riverpod `AsyncValue` patterns for responsive state transitions.
- **Empty States**: Professional fallback screens for empty orders, menus, and feedback.
