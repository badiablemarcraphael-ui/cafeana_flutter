/**
 * cafeana_kitchen_terminal — main.cpp
 *
 * Full ESP32 firmware for the Cafeana Kitchen Terminal.
 * Target: ESP32 DevKit + SSD1306 128x64 OLED + push button + buzzer + LED
 *
 * Wokwi simulation: open /firmware/wokwi/diagram.json + wokwi.toml
 *
 * ── Compile flags ────────────────────────────────────────────────────────────
 *   MOCK_MODE       : Skip all Firestore calls. Cycles fake orders every 10s.
 *                     Useful for pure Wokwi hardware demo with no backend.
 *
 * ── Pin map (matches diagram.json) ──────────────────────────────────────────
 *   OLED SDA  → GPIO 21
 *   OLED SCL  → GPIO 22
 *   BUTTON    → GPIO 18  (INPUT_PULLUP, active LOW)
 *   LED       → GPIO 5   (External LED, active HIGH)
 *   ONBOARD   → GPIO 2   (ESP32 DevKit built-in blue LED, active HIGH)
 *
 * ── API contract reference ───────────────────────────────────────────────────
 *   See /docs/api-contract.md for all Firestore REST paths and payload shapes.
 */

#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

#ifdef USE_SECRETS_H
  #include "secrets.h"
#endif

// ── Conditional includes (WiFi + HTTP only when not in mock mode) ─────────────
#ifndef MOCK_MODE
  #include <WiFi.h>
  #include <WiFiClientSecure.h>
  #include <HTTPClient.h>
  #include <ArduinoJson.h>
#endif

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION — edit secrets.h for real credentials
// ═══════════════════════════════════════════════════════════════════════════════

// WiFi — Wokwi's built-in simulated network (no password required)
#define WIFI_SSID     "rachelpisonet"
#define WIFI_PASSWORD "arbibi@828"

// Firebase — fill from Firebase Console → Project Settings
// Keep these in secrets.h (gitignored) for production builds.
#ifndef MOCK_MODE
  #ifndef FIREBASE_API_KEY
    #define FIREBASE_API_KEY   "AIzaSyCdBnSkIKPACwuQb_FBOhgAJSN-tOzUTvo"
  #endif
  #ifndef DEVICE_EMAIL
    #define DEVICE_EMAIL       "terminal@cafeana.internal"
  #endif
  #ifndef DEVICE_PASSWORD
    #define DEVICE_PASSWORD    "cafeana1230"
  #endif
  #ifndef FIREBASE_PROJECT
    #define FIREBASE_PROJECT   "cafeana-7fa42"
  #endif
#endif

// Firmware version shown in heartbeat
#define FIRMWARE_VERSION   "0.1.0-wokwi"

// Timing (all in milliseconds)
#define POLL_INTERVAL_MS      5000UL   // How often to query Firestore for new orders
#define HEARTBEAT_INTERVAL_MS 30000UL  // How often to PATCH deviceStatus (§4.1)
#define TOKEN_REFRESH_MS      3300000UL// 55 minutes — refresh before 60-min expiry

// Hardware pins
#define PIN_BUTTON       18
#define PIN_BUZZER       19
#define PIN_LED           5  // External LED (GPIO 5)
#define PIN_LED_ONBOARD   2  // ESP32 DevKit onboard built-in blue LED (GPIO 2)

// OLED display
#define OLED_WIDTH  128
#define OLED_HEIGHT  64
#define OLED_ADDR   0x3C

// ═══════════════════════════════════════════════════════════════════════════════
// GLOBALS
// ═══════════════════════════════════════════════════════════════════════════════

Adafruit_SSD1306 display(OLED_WIDTH, OLED_HEIGHT, &Wire, -1);

// ── State machine ─────────────────────────────────────────────────────────────
enum class TerminalState {
  BOOTING,
  OFFLINE,       // WiFi/auth failed
  IDLE,          // Polling, no active order
  ORDER_SHOWN,   // Displaying an order, waiting for button press
};

TerminalState state = TerminalState::BOOTING;

// ── Current order data ────────────────────────────────────────────────────────
String  currentOrderId     = "";
int     currentOrderNumber = 0;

// ── Timers ────────────────────────────────────────────────────────────────────
unsigned long lastPollMs      = 0;
unsigned long lastHeartbeatMs = 0;
unsigned long lastTokenRefMs  = 0;

// ── Firebase auth tokens ──────────────────────────────────────────────────────
#ifndef MOCK_MODE
  String idToken      = "";
  String refreshToken = "";
#endif

// ── Button debounce ───────────────────────────────────────────────────────────
bool     lastButtonState = HIGH;
bool     buttonHandled   = false;
unsigned long lastDebounceMs = 0;
#define DEBOUNCE_MS 50

// ── Already-seen order IDs (ring buffer, avoids re-showing same order) ────────
static const int MAX_SEEN = 20;
String seenOrderIds[MAX_SEEN];
int    seenHead = 0;

// ═══════════════════════════════════════════════════════════════════════════════
// OLED HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

void oledClear() {
  display.clearDisplay();
  display.display();
}

void oledShowText(const char* line1, const char* line2 = "",
                  const char* line3 = "", const char* line4 = "") {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  display.setTextSize(1);
  display.setCursor(0, 0);
  display.println(line1);

  if (line2[0]) {
    display.setCursor(0, 16);
    display.println(line2);
  }
  if (line3[0]) {
    display.setCursor(0, 32);
    display.println(line3);
  }
  if (line4[0]) {
    display.setCursor(0, 48);
    display.println(line4);
  }
  display.display();
}

void oledShowOrder(int orderNum) {
  display.clearDisplay();

  // Header
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println("** NEW ORDER **");

  // Big order number
  display.setTextSize(3);
  display.setCursor(10, 18);
  display.print("#");
  display.println(orderNum);

  // Footer prompt
  display.setTextSize(1);
  display.setCursor(0, 52);
  display.println("[ Press BTN = READY ]");

  display.display();
}

void oledShowOffline() {
  display.clearDisplay();
  display.setTextSize(2);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(10, 10);
  display.println("OFFLINE");
  display.setTextSize(1);
  display.setCursor(0, 40);
  display.println("Check WiFi/Firebase");
  display.display();
}

void oledShowIdle() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println("Cafeana Terminal");
  display.setCursor(0, 14);
  display.println("v" FIRMWARE_VERSION);
  display.setCursor(0, 32);
  display.println("Waiting for orders...");
  display.display();
}

// ═══════════════════════════════════════════════════════════════════════════════
// BUZZER + LED
// ═══════════════════════════════════════════════════════════════════════════════

void setLed(bool state) {
  digitalWrite(PIN_LED, state ? HIGH : LOW);
  digitalWrite(PIN_LED_ONBOARD, state ? HIGH : LOW);
}

void buzzAndBlink(int durationMs = 3500, int beeps = 5) {
  int beepLen = durationMs / (beeps * 2);
  for (int i = 0; i < beeps; i++) {
    setLed(true);
    // Passive buzzer tone ~1kHz
    for (int t = 0; t < beepLen * 1000 / 500; t++) {
      digitalWrite(PIN_BUZZER, HIGH);
      delayMicroseconds(500);
      digitalWrite(PIN_BUZZER, LOW);
      delayMicroseconds(500);
    }
    setLed(false);
    delay(beepLen);
  }
}

void blinkLed(int times = 2, int onMs = 100) {
  for (int i = 0; i < times; i++) {
    setLed(true);
    delay(onMs);
    setLed(false);
    delay(onMs);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SEEN-ORDER TRACKING
// ═══════════════════════════════════════════════════════════════════════════════

bool isAlreadySeen(const String& orderId) {
  if (orderId.length() == 0) return true;
  for (int i = 0; i < MAX_SEEN; i++) {
    if (seenOrderIds[i].length() > 0 && seenOrderIds[i] == orderId) return true;
  }
  return false;
}

void markSeen(const String& orderId) {
  seenOrderIds[seenHead] = orderId;
  seenHead = (seenHead + 1) % MAX_SEEN;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MOCK MODE — no Firestore, cycles fake orders
// ═══════════════════════════════════════════════════════════════════════════════
#ifdef MOCK_MODE

static const int MOCK_ORDERS[] = {101, 102, 103};
static const int MOCK_COUNT    = 3;
static int       mockIndex     = 0;
unsigned long    lastMockMs    = 0;
#define MOCK_INTERVAL_MS 10000UL

void mockSetup() {
  Serial.println("[MOCK] Mock mode active — no Firebase calls.");
  oledShowIdle();
  state = TerminalState::IDLE;
}

void mockLoop() {
  // Simulate button press to mark ready
  bool btnPressed = (digitalRead(PIN_BUTTON) == LOW);
  if (btnPressed && state == TerminalState::ORDER_SHOWN) {
    Serial.printf("[MOCK] Button pressed — order #%d marked READY\n",
                  currentOrderNumber);
    digitalWrite(PIN_BUTTON, HIGH); // release
    setLed(false);
    blinkLed(3, 80);
    oledShowText("ORDER READY!", String("#" + String(currentOrderNumber)).c_str(),
                 "Sent to customer.");
    delay(1500);
    state = TerminalState::IDLE;
    currentOrderId     = "";
    currentOrderNumber = 0;
    lastMockMs         = millis(); // reset mock timer
    oledShowIdle();
    return;
  }

  // Auto-cycle new mock orders
  if (state == TerminalState::IDLE &&
      (millis() - lastMockMs >= MOCK_INTERVAL_MS)) {
    lastMockMs         = millis();
    currentOrderNumber = MOCK_ORDERS[mockIndex];
    currentOrderId     = String("mock-order-") + mockIndex;
    mockIndex          = (mockIndex + 1) % MOCK_COUNT;

    Serial.printf("[MOCK] New order #%d\n", currentOrderNumber);
    oledShowOrder(currentOrderNumber);
    buzzAndBlink(1000, 3);
    setLed(true); // Keep LED lit while order is pending
    state = TerminalState::ORDER_SHOWN;
  }
}

#endif // MOCK_MODE

// ═══════════════════════════════════════════════════════════════════════════════
// LIVE MODE — WiFi + Firestore REST
// ═══════════════════════════════════════════════════════════════════════════════
#ifndef MOCK_MODE

// ── URL builders ──────────────────────────────────────────────────────────────
String fsBase() {
  return String("https://firestore.googleapis.com/v1/projects/")
         + FIREBASE_PROJECT
         + "/databases/(default)/documents";
}

String authHeader() {
  return String("Bearer ") + idToken;
}

// ── Timestamp helper (requires NTP sync) ──────────────────────────────────────
String getTimestamp() {
  time_t now;
  time(&now);
  char buf[25];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", gmtime(&now));
  return String(buf);
}

// ── HTTP PATCH helper (returns HTTP status code) ──────────────────────────────
int httpPatch(const String& url, const String& body,
              const String& bearerToken = "") {
  WiFiClientSecure client;
  client.setInsecure(); // For Wokwi — use cert pinning in production
  HTTPClient http;

  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  if (bearerToken.length() > 0) {
    http.addHeader("Authorization", String("Bearer ") + bearerToken);
  }

  int code = http.PATCH(body);
  if (code < 0) {
    Serial.printf("[HTTP] PATCH error: %s\n", http.errorToString(code).c_str());
  }
  http.end();
  return code;
}

// ── HTTP POST helper (returns body string, "" on error) ───────────────────────
String httpPost(const String& url, const String& body,
                const String& bearerToken = "") {
  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient http;

  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  if (bearerToken.length() > 0) {
    http.addHeader("Authorization", String("Bearer ") + bearerToken);
  }

  int code = http.POST(body);
  String response = "";
  if (code == 200 || code == 201) {
    response = http.getString();
  } else {
    Serial.printf("[HTTP] POST %d — %s\n", code,
                  http.getString().substring(0, 200).c_str());
  }
  http.end();
  return response;
}

// ── §1.1 Sign in with email+password ─────────────────────────────────────────
bool signIn() {
  Serial.println("[Auth] Signing in...");
  String url = String("https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=")
               + FIREBASE_API_KEY;
  String body = String("{\"email\":\"") + DEVICE_EMAIL
                + "\",\"password\":\"" + DEVICE_PASSWORD
                + "\",\"returnSecureToken\":true}";

  String resp = httpPost(url, body);
  if (resp.length() == 0) {
    Serial.println("[Auth] Sign-in failed.");
    return false;
  }

  JsonDocument doc;
  if (deserializeJson(doc, resp) != DeserializationError::Ok) {
    Serial.println("[Auth] JSON parse error.");
    return false;
  }

  idToken      = doc["idToken"].as<String>();
  refreshToken = doc["refreshToken"].as<String>();
  Serial.println("[Auth] Signed in OK.");
  return true;
}

// ── §1.2 Refresh ID token ─────────────────────────────────────────────────────
bool refreshIdToken() {
  if (refreshToken.length() == 0) return signIn();
  Serial.println("[Auth] Refreshing token...");

  String url = String("https://securetoken.googleapis.com/v1/token?key=")
               + FIREBASE_API_KEY;
  String body = String("{\"grant_type\":\"refresh_token\",\"refresh_token\":\"")
                + refreshToken + "\"}";

  String resp = httpPost(url, body);
  if (resp.length() == 0) return signIn(); // fallback to full sign-in

  JsonDocument doc;
  if (deserializeJson(doc, resp) != DeserializationError::Ok) return signIn();

  idToken      = doc["id_token"].as<String>();
  refreshToken = doc["refresh_token"].as<String>();
  Serial.println("[Auth] Token refreshed OK.");
  return true;
}

// ── §4.1 Heartbeat PATCH ──────────────────────────────────────────────────────
void sendHeartbeat(bool online = true) {
  String ts  = getTimestamp();
  String url = fsBase()
               + "/deviceStatus/kitchenTerminal"
               + "?updateMask.fieldPaths=online"
               + "&updateMask.fieldPaths=lastSeen"
               + "&updateMask.fieldPaths=firmwareVersion";

  String body = String("{\"fields\":{")
    + "\"online\":{\"booleanValue\":" + (online ? "true" : "false") + "},"
    + "\"lastSeen\":{\"timestampValue\":\"" + ts + "\"},"
    + "\"firmwareVersion\":{\"stringValue\":\"" FIRMWARE_VERSION "\"}"
    + "}}";

  int code = httpPatch(url, body, idToken);
  if (code == 404) {
    // First boot — document doesn't exist yet; PATCH without updateMask creates it
    String initUrl = fsBase() + "/deviceStatus/kitchenTerminal";
    String initBody = String("{\"fields\":{")
      + "\"online\":{\"booleanValue\":true},"
      + "\"lastSeen\":{\"timestampValue\":\"" + ts + "\"},"
      + "\"currentOrderNumber\":{\"nullValue\":null},"
      + "\"firmwareVersion\":{\"stringValue\":\"" FIRMWARE_VERSION "\"}"
      + "}}";
    httpPatch(initUrl, initBody, idToken);
  } else if (code == 401) {
    refreshIdToken();
  }
  Serial.printf("[Heartbeat] %s → %d\n", online ? "ONLINE" : "OFFLINE", code);
}

// ── §4.2 Update currentOrderNumber ───────────────────────────────────────────
void updateCurrentOrder(int orderNum) {
  String ts  = getTimestamp();
  String url = fsBase()
               + "/deviceStatus/kitchenTerminal"
               + "?updateMask.fieldPaths=currentOrderNumber"
               + "&updateMask.fieldPaths=lastSeen";
  String numStr = String(orderNum);
  String body = String("{\"fields\":{")
    + "\"currentOrderNumber\":{\"integerValue\":\"" + numStr + "\"},"
    + "\"lastSeen\":{\"timestampValue\":\"" + ts + "\"}"
    + "}}";
  httpPatch(url, body, idToken);
}

// ── §3.1 Poll for active kitchen orders (queued & preparing) ───────────────────
// Returns true if an active order was found and displayed.
bool pollOrders() {
  String url = fsBase() + ":runQuery";
  Serial.println("[Poll] Checking Firestore for orders...");

  // 1. Look for incoming "queued" orders
  String bodyQueued =
    "{\"structuredQuery\":{"
    "  \"select\":{\"fields\":[{\"fieldPath\":\"orderNumber\"},{\"fieldPath\":\"status\"},{\"fieldPath\":\"paymentStatus\"}]},"
    "  \"from\":[{\"collectionId\":\"orders\"}],"
    "  \"where\":{\"fieldFilter\":{"
    "    \"field\":{\"fieldPath\":\"status\"},"
    "    \"op\":\"EQUAL\","
    "    \"value\":{\"stringValue\":\"queued\"}"
    "  }},"
    "  \"orderBy\":[{\"field\":{\"fieldPath\":\"createdAt\"},\"direction\":\"ASCENDING\"}],"
    "  \"limit\":5"
    "}}";

  String resp = httpPost(url, bodyQueued, idToken);
  Serial.printf("[Poll] Queued resp len: %d\n", resp.length());

  if (resp.length() > 0) {
    JsonDocument doc;
    DeserializationError err = deserializeJson(doc, resp, DeserializationOption::NestingLimit(25));
    if (err) {
      Serial.printf("[Poll] docQueued deserialize error: %s\n", err.c_str());
    } else {
      if (doc.is<JsonObject>() && doc["error"]["code"].as<int>() == 401) {
        refreshIdToken();
        return false;
      }

      JsonArray arr = doc.as<JsonArray>();
      for (JsonObject entry : arr) {
        JsonObject docObj = entry["document"];
        if (docObj.isNull()) continue;

        String name = docObj["name"].as<String>();
        String orderId = name.substring(name.lastIndexOf('/') + 1);

        if (isAlreadySeen(orderId)) continue;

        // Ensure order is marked as paid before buzzing or preparing
        const char* payStatus = docObj["fields"]["paymentStatus"]["stringValue"];
        if (!payStatus || strcmp(payStatus, "paid") != 0) {
          // Not paid yet — do not alert kitchen
          continue;
        }

        int orderNum = 0;
        const char* s = docObj["fields"]["orderNumber"]["integerValue"];
        if (s) {
          orderNum = atoi(s);
        } else {
          orderNum = docObj["fields"]["orderNumber"]["integerValue"].as<int>();
        }

        Serial.printf("[Poll] Incoming paid queued order: %s — #%d\n", orderId.c_str(), orderNum);

        // Acknowledge order: queued → preparing
        String ts  = getTimestamp();
        String patchUrl = fsBase() + "/orders/" + orderId
                        + "?updateMask.fieldPaths=status"
                        + "&updateMask.fieldPaths=terminalId"
                        + "&updateMask.fieldPaths=updatedAt";
        String patchBody = String("{\"fields\":{")
          + "\"status\":{\"stringValue\":\"preparing\"},"
          + "\"terminalId\":{\"stringValue\":\"kitchenTerminal\"},"
          + "\"updatedAt\":{\"timestampValue\":\"" + ts + "\"}"
          + "}}";
        int code = httpPatch(patchUrl, patchBody, idToken);
        Serial.printf("[Poll] Acknowledge PATCH → %d\n", code);

        if (code == 200) {
          markSeen(orderId);
          currentOrderId     = orderId;
          currentOrderNumber = orderNum;
          updateCurrentOrder(orderNum);
          oledShowOrder(orderNum);
          buzzAndBlink(3500, 5); // Longer buzzer alert: 5 beeps, 3.5 seconds
          setLed(true); // Keep LED lit while order is pending
          state = TerminalState::ORDER_SHOWN;
          return true;  // Show one order at a time
        }
      }
    }
  }

  // 2. If no queued order was picked up, check for active "preparing" orders
  String bodyPreparing =
    "{\"structuredQuery\":{"
    "  \"select\":{\"fields\":[{\"fieldPath\":\"orderNumber\"},{\"fieldPath\":\"status\"},{\"fieldPath\":\"paymentStatus\"}]},"
    "  \"from\":[{\"collectionId\":\"orders\"}],"
    "  \"where\":{\"fieldFilter\":{"
    "    \"field\":{\"fieldPath\":\"status\"},"
    "    \"op\":\"EQUAL\","
    "    \"value\":{\"stringValue\":\"preparing\"}"
    "  }},"
    "  \"orderBy\":[{\"field\":{\"fieldPath\":\"createdAt\"},\"direction\":\"ASCENDING\"}],"
    "  \"limit\":5"
    "}}";

  String respPrep = httpPost(url, bodyPreparing, idToken);
  Serial.printf("[Poll] Preparing resp len: %d\n", respPrep.length());

  if (respPrep.length() > 0) {
    JsonDocument docPrep;
    DeserializationError err = deserializeJson(docPrep, respPrep, DeserializationOption::NestingLimit(25));
    if (err) {
      Serial.printf("[Poll] docPrep deserialize error: %s\n", err.c_str());
    } else {
      if (docPrep.is<JsonObject>() && docPrep["error"]["code"].as<int>() == 401) {
        refreshIdToken();
        return false;
      }

      JsonArray prepArr = docPrep.as<JsonArray>();
      Serial.printf("[Poll] prepArr count: %d\n", prepArr.size());
      for (JsonVariant entry : prepArr) {
        if (!entry.is<JsonObject>()) continue;
        JsonObject docObj = entry["document"];
        if (docObj.isNull()) continue;

        String name = docObj["name"].as<String>();
        String orderId = name.substring(name.lastIndexOf('/') + 1);

        if (isAlreadySeen(orderId)) {
          Serial.printf("[Poll] Order %s already seen\n", orderId.c_str());
          continue;
        }

        // Ensure order is paid
        const char* payStatus = docObj["fields"]["paymentStatus"]["stringValue"];
        if (!payStatus || strcmp(payStatus, "paid") != 0) {
          continue;
        }

        int orderNum = 0;
        const char* s = docObj["fields"]["orderNumber"]["integerValue"];
        if (s) {
          orderNum = atoi(s);
        } else {
          orderNum = docObj["fields"]["orderNumber"]["integerValue"].as<int>();
        }

        Serial.printf("[Poll] Active preparing order: %s — #%d (PAID)\n", orderId.c_str(), orderNum);
        markSeen(orderId);
        currentOrderId     = orderId;
        currentOrderNumber = orderNum;
        updateCurrentOrder(orderNum);
        oledShowOrder(orderNum);
        buzzAndBlink(2500, 4); // Alert on reconnect: 4 beeps, 2.5s
        setLed(true); // Keep LED lit while order is pending
        state = TerminalState::ORDER_SHOWN;
        return true;
      }
    }
  }

  return false;
}

// ── §3.3 Mark order ready (button press) ─────────────────────────────────────
void markOrderReady() {
  Serial.printf("[Button] Marking order %s as READY\n", currentOrderId.c_str());

  String ts  = getTimestamp();
  String url = fsBase() + "/orders/" + currentOrderId
             + "?updateMask.fieldPaths=status"
             + "&updateMask.fieldPaths=updatedAt";
  String body = String("{\"fields\":{")
    + "\"status\":{\"stringValue\":\"ready\"},"
    + "\"updatedAt\":{\"timestampValue\":\"" + ts + "\"}"
    + "}}";

  int code = httpPatch(url, body, idToken);
  Serial.printf("[Button] PATCH ready → %d\n", code);

  if (code == 200) {
    oledShowText("ORDER READY!", String("#" + String(currentOrderNumber)).c_str(),
                 "Notifying customer...");
    setLed(false);
    blinkLed(4, 80);
    delay(1500);
    state              = TerminalState::IDLE;
    currentOrderId     = "";
    currentOrderNumber = 0;
    updateCurrentOrder(0);
    oledShowIdle();
  } else if (code == 401) {
    refreshIdToken();
  }
}

// ── WiFi connect ──────────────────────────────────────────────────────────────
bool connectWiFi() {
  Serial.print("[WiFi] Connecting to ");
  Serial.println(WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\n[WiFi] Connected. IP: %s\n",
                  WiFi.localIP().toString().c_str());
    return true;
  }
  Serial.println("\n[WiFi] Failed.");
  return false;
}

#endif // !MOCK_MODE

// ═══════════════════════════════════════════════════════════════════════════════
// BUTTON READING (shared between mock and live mode)
// ═══════════════════════════════════════════════════════════════════════════════

bool readButtonPress() {
  bool reading = digitalRead(PIN_BUTTON);
  if (reading != lastButtonState) {
    lastDebounceMs = millis();
    lastButtonState = reading;
  }

  if ((millis() - lastDebounceMs) > DEBOUNCE_MS) {
    if (reading == LOW && !buttonHandled) {
      buttonHandled = true;
      return true; // Clean single press on falling edge
    } else if (reading == HIGH) {
      buttonHandled = false; // Reset on release
    }
  }
  return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SETUP & LOOP
// ═══════════════════════════════════════════════════════════════════════════════

void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("\n=== Cafeana Kitchen Terminal ===");
  Serial.println("FW: " FIRMWARE_VERSION);

#ifdef MOCK_MODE
  Serial.println("Mode: MOCK (no Firebase)");
#else
  Serial.println("Mode: LIVE (Firebase Firestore)");
#endif

  // ── Hardware init ────────────────────────────────────────────────────────────
  pinMode(PIN_BUTTON,      INPUT_PULLUP);
  pinMode(PIN_BUZZER,      OUTPUT);
  pinMode(PIN_LED,         OUTPUT);
  pinMode(PIN_LED_ONBOARD, OUTPUT);
  digitalWrite(PIN_BUZZER, LOW);
  setLed(false);

  // Self-test: Flash LED 3 times on boot to verify both LEDs are working
  blinkLed(3, 150);

  // ── OLED init ────────────────────────────────────────────────────────────────
  Wire.begin(21, 22); // SDA=21, SCL=22
  if (!display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDR)) {
    Serial.println("[OLED] Init failed! Check wiring.");
    while (true) delay(1000);
  }
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  oledShowText("Cafeana Terminal", "v" FIRMWARE_VERSION, "Booting...");
  delay(1000);

#ifdef MOCK_MODE
  // ── Mock mode: skip WiFi/Firebase ─────────────────────────────────────────
  mockSetup();
  lastMockMs = millis() + 3000; // first mock order after 3s

#else
  // ── Live mode: WiFi → NTP → Firebase sign-in ──────────────────────────────
  oledShowText("Connecting WiFi...", WIFI_SSID);

  if (!connectWiFi()) {
    oledShowOffline();
    state = TerminalState::OFFLINE;
    return;
  }

  // NTP time sync (required for RFC 3339 timestamps)
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  Serial.print("[NTP] Syncing time");
  struct tm timeinfo;
  int ntpAttempts = 0;
  while (!getLocalTime(&timeinfo) && ntpAttempts < 10) {
    delay(500);
    Serial.print(".");
    ntpAttempts++;
  }
  Serial.println(" OK");

  oledShowText("Authenticating...", "Firebase Auth");

  if (!signIn()) {
    oledShowOffline();
    state = TerminalState::OFFLINE;
    return;
  }

  // First heartbeat (§4.1) — creates document if new device
  sendHeartbeat(true);

  lastTokenRefMs  = millis();
  lastHeartbeatMs = millis();
  lastPollMs      = 0; // poll immediately on first loop
  state = TerminalState::IDLE;
  oledShowIdle();

  Serial.println("[Boot] Ready.");
#endif
}

// ─────────────────────────────────────────────────────────────────────────────

void loop() {

#ifdef MOCK_MODE
  mockLoop();
  delay(50);
  return;
#else

  // ── Live mode loop ─────────────────────────────────────────────────────────

  // Reconnect WiFi if dropped
  if (WiFi.status() != WL_CONNECTED) {
    if (state != TerminalState::OFFLINE) {
      Serial.println("[WiFi] Disconnected.");
      state = TerminalState::OFFLINE;
      oledShowOffline();
    }
    delay(5000);
    connectWiFi();
    return;
  }

  // Back online after being offline
  if (state == TerminalState::OFFLINE) {
    static unsigned long lastOfflineRetryMs = 0;
    if (millis() - lastOfflineRetryMs >= 15000UL) {
      lastOfflineRetryMs = millis();
      Serial.println("[Auth] Retrying Firebase sign-in...");
      if (signIn()) {
        sendHeartbeat(true);
        state = TerminalState::IDLE;
        oledShowIdle();
      }
    }
    delay(100);
    return;
  }

  unsigned long now = millis();

  // ── §1.2 Token refresh (every 55 min) ────────────────────────────────────
  if (now - lastTokenRefMs >= TOKEN_REFRESH_MS) {
    refreshIdToken();
    lastTokenRefMs = now;
  }

  // ── §4.1 Heartbeat (every 30 s) ──────────────────────────────────────────
  if (now - lastHeartbeatMs >= HEARTBEAT_INTERVAL_MS) {
    sendHeartbeat(true);
    lastHeartbeatMs = now;
  }

  // ── Button press handler ─────────────────────────────────────────────────
  if (state == TerminalState::ORDER_SHOWN && readButtonPress()) {
    markOrderReady();
  }

  // ── §3.1 Poll for queued orders ──────────────────────────────────────────
  if (state == TerminalState::IDLE &&
      (now - lastPollMs >= POLL_INTERVAL_MS)) {
    lastPollMs = now;
    pollOrders();
  }

  delay(10);
#endif
}
