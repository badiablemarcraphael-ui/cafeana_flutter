# Cafeana — Project Overview

**Cafeana** is a full-stack café management system consisting of:

| Sub-project | Location | Description |
|---|---|---|
| Mobile & Web App | `mobile_web_app/` | Flutter app targeting Android & Chrome |
| Kitchen Terminal Firmware | `firmware/` | ESP32 firmware (PlatformIO / Arduino) |
| Documentation | `docs/` | Architecture, setup, and API docs |

## Quick Start

### Flutter App
```bash
cd mobile_web_app
flutter pub get
flutter run -d chrome          # Web
flutter run -d emulator-5554   # Android emulator
```

### Firmware
```bash
cd firmware
pio run --target upload        # Build & flash ESP32
pio device monitor             # Serial monitor
```

## Architecture

See [`architecture.md`](architecture.md) for a system-level overview.

## Firebase Setup

See [`firebase_setup.md`](firebase_setup.md) to connect the app to a real Firebase project.
