# cafeana_kitchen_terminal — Firmware

ESP32-based kitchen display terminal for Cafeana.

## Hardware Target

| Parameter | Value |
|---|---|
| MCU | ESP32-DevKitC (ESP32-WROOM-32) |
| Framework | Arduino (via PlatformIO) |
| Display | TFT (ILI9341 / SSD1306) — TBD |

## Setup

1. Install [PlatformIO](https://platformio.org/install) (VS Code extension or CLI)
2. From this directory:
   ```bash
   pio run                 # Build
   pio run --target upload # Flash to connected ESP32
   pio device monitor      # Open serial monitor
   ```

## Planned Features

- [ ] Wi-Fi provisioning (SmartConfig or hard-coded credentials)
- [ ] Firebase REST API client for order polling
- [ ] TFT display rendering of order queue
- [ ] Physical button to mark order as "ready"
- [ ] LED status indicator (idle / order pending / Wi-Fi disconnected)

## Serial Output (placeholder)

```
===========================================
  Cafeana Kitchen Terminal
  Cafeana v0.1.0 — Scaffold placeholder
===========================================
TODO: Connect Wi-Fi
TODO: Connect Firebase
TODO: Init display
[heartbeat] Kitchen terminal running...
```
