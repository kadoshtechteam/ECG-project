#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <LiquidCrystal_I2C.h>

LiquidCrystal_I2C lcd(0x27, 16, 2);
ESP8266WebServer server(80);

const char* kAccessPointName = "ECG Monitor";
const char* kAccessPointPassword = "12341234";
const uint16_t kServerPort = 80;
const uint8_t kLeadPositivePin = D5;
const uint8_t kLeadNegativePin = D6;
const uint8_t kSignalPin = A0;
const unsigned long kSampleIntervalMs = 8;
const unsigned long kSerialRefreshMs = 1200;
const unsigned long kLeadScreenHoldMs = 2800;
const unsigned long kReadyScreenHoldMs = 2600;
const unsigned long kRecordingScreenHoldMs = 2200;
const unsigned long kStartupIpHoldMs = 3800;
const unsigned long kLeadScrollStepMs = 320;
const char* kLeadScrollMessage =
    "Check if leads are attached and all probes are connected to user.  ";

const IPAddress kAccessPointIp(192, 168, 4, 1);
const IPAddress kGatewayIp(192, 168, 4, 1);
const IPAddress kSubnetMask(255, 255, 255, 0);

IPAddress apAddress;
int latestSample = 0;
int baselineSample = 512;
bool leadsAttached = false;
bool recordingEnabled = false;
unsigned long lastSampleAt = 0;
unsigned long lastDisplayAt = 0;
unsigned long lastSerialAt = 0;
unsigned long lastLeadScrollAt = 0;
uint8_t displayFrame = 0;
uint8_t leadScrollOffset = 0;
int displayMode = -1;

String jsonBool(bool value) {
  return value ? "true" : "false";
}

String clampLine(const String& value) {
  return value.substring(0, min((int)value.length(), 16));
}

void showScreen(const String& lineOne, const String& lineTwo) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print(clampLine(lineOne));
  lcd.setCursor(0, 1);
  lcd.print(clampLine(lineTwo));
}

void playStartupAnimation() {
  const char* bootFrames[] = {
      "[=             ]",
      "[====          ]",
      "[=======       ]",
      "[==========    ]",
      "[============= ]",
      "[==============]"};

  showScreen("Smart ECG Device", "Initializing");
  delay(500);

  for (uint8_t i = 0; i < 6; i++) {
    showScreen("Smart ECG Device", bootFrames[i]);
    delay(180);
  }

  showScreen("Checking Leads", "Hold steady...");
  delay(450);
  showScreen("Starting Wi-Fi", "SoftAP Ready");
  delay(450);
}

String connectionSummary() {
  return "SSID: " + String(kAccessPointName) + " | PASS: " +
         String(kAccessPointPassword) + " | IP: " + apAddress.toString() +
         " | PORT: " + String(kServerPort);
}

String buildHealthPayload() {
  return "{"
         "\"status\":\"ready\","
         "\"ssid\":\"" + String(kAccessPointName) + "\","
         "\"ip\":\"" + apAddress.toString() + "\","
         "\"port\":" + String(kServerPort) + ","
         "\"dataEndpoint\":\"/ecg\","
         "\"commandEndpoint\":\"/command\","
         "\"leadOff\":" + jsonBool(!leadsAttached) + ","
         "\"recording\":" + jsonBool(recordingEnabled) + ","
         "\"sample\":" + String(latestSample) +
         "}";
}

String buildSamplePayload() {
  return "{"
         "\"sample\":" + String(latestSample) + ","
         "\"baseline\":" + String(baselineSample) + ","
         "\"normalized\":" + String((float)latestSample / 1024.0f, 4) + ","
         "\"leadOff\":" + jsonBool(!leadsAttached) + ","
         "\"recording\":" + jsonBool(recordingEnabled) +
         "}";
}

void sendJsonResponse(int statusCode, const String& payload) {
  server.send(statusCode, "application/json", payload);
}

void sendCommandResponse(int statusCode, bool ok, const String& message) {
  sendJsonResponse(
      statusCode,
      "{\"ok\":" + jsonBool(ok) + ",\"message\":\"" + message + "\"}");
}

void handleRoot() {
  server.send(
      200,
      "text/plain",
      "ECG Monitor ready\n" + connectionSummary() +
          "\nUse /health, /ecg and /command?action=start_recording");
}

void handleHealth() {
  sendJsonResponse(200, buildHealthPayload());
}

void handleEcg() {
  if (!leadsAttached) {
    sendJsonResponse(
        503,
        "{\"status\":\"lead_off\",\"message\":\"Attach ECG leads before recording\"}");
    return;
  }

  sendJsonResponse(200, buildSamplePayload());
}

void handleLegacySample() {
  if (!leadsAttached) {
    server.send(503, "text/plain", "lead_off");
    return;
  }

  server.send(200, "text/plain", String(latestSample));
}

void handleCommand() {
  if (!server.hasArg("action")) {
    sendCommandResponse(400, false, "Missing action query parameter");
    return;
  }

  const String action = server.arg("action");

  if (action == "start_recording") {
    recordingEnabled = true;
    sendCommandResponse(200, true, "Recording enabled");
    return;
  }

  if (action == "stop_recording") {
    recordingEnabled = false;
    sendCommandResponse(200, true, "Recording stopped");
    return;
  }

  if (action == "calibrate") {
    if (!leadsAttached) {
      sendCommandResponse(409, false, "Attach leads before calibration");
      return;
    }

    baselineSample = latestSample;
    sendCommandResponse(200, true, "Baseline captured");
    return;
  }

  if (action == "status") {
    sendJsonResponse(200, buildHealthPayload());
    return;
  }

  sendCommandResponse(400, false, "Unsupported action");
}

void handleNotFound() {
  sendJsonResponse(
      404,
      "{\"ok\":false,\"message\":\"Unknown endpoint. Use /health, /ecg or /command\"}");
}

void setupServer() {
  server.on("/", HTTP_GET, handleRoot);
  server.on("/health", HTTP_GET, handleHealth);
  server.on("/ecg", HTTP_GET, handleEcg);
  server.on("/getDustDensity", HTTP_GET, handleLegacySample);
  server.on("/command", HTTP_GET, handleCommand);
  server.onNotFound(handleNotFound);
  server.begin();
}

void setupSoftAp() {
  WiFi.persistent(false);
  WiFi.mode(WIFI_AP);
  WiFi.softAPdisconnect(true);
  WiFi.softAPConfig(kAccessPointIp, kGatewayIp, kSubnetMask);
  WiFi.softAP(kAccessPointName, kAccessPointPassword, 1, false, 4);
  apAddress = WiFi.softAPIP();
}

void printStartupInstructions() {
  Serial.println();
  Serial.println(F("=== Smart ECG Device Ready ==="));
  Serial.println(connectionSummary());
  Serial.println(F("Health endpoint : http://192.168.4.1/health"));
  Serial.println(F("ECG endpoint    : http://192.168.4.1/ecg"));
  Serial.println(F("Command endpoint: http://192.168.4.1/command?action=start_recording"));
  Serial.println(F("Commands        : start_recording, stop_recording, calibrate, status"));
  Serial.println(F("If the app shows lead_off, attach the electrodes and try again."));
  Serial.println(F("================================"));
  Serial.println();
}

void showStartupIpScreen() {
  showScreen("Smart ECG Device", apAddress.toString());
  delay(kStartupIpHoldMs);
}

String buildScrollingLine(const String& text, uint8_t offset) {
  String padded = text;
  while (padded.length() < 16) {
    padded += ' ';
  }

  const String looped = padded + padded;
  return looped.substring(offset, offset + 16);
}

void updateDisplayPage(
    int nextMode,
    uint8_t totalPages,
    unsigned long holdMs,
    const String& lineOne,
    const String& lineTwo) {
  const bool modeChanged = displayMode != nextMode;
  if (modeChanged) {
    displayMode = nextMode;
    displayFrame = 0;
  } else if (millis() - lastDisplayAt < holdMs) {
    return;
  } else {
    displayFrame = (displayFrame + 1) % totalPages;
  }

  lastDisplayAt = millis();
  showScreen(lineOne, lineTwo);
}

void updateSignalState() {
  const bool leadPositiveOff = digitalRead(kLeadPositivePin) == HIGH;
  const bool leadNegativeOff = digitalRead(kLeadNegativePin) == HIGH;

  leadsAttached = !leadPositiveOff && !leadNegativeOff;

  if (leadsAttached) {
    latestSample = analogRead(kSignalPin);
    return;
  }

  latestSample = baselineSample;
}

void refreshDisplay() {
  if (recordingEnabled && !leadsAttached) {
    if (displayMode != 0) {
      displayMode = 0;
      displayFrame = 0;
      leadScrollOffset = 0;
      lastLeadScrollAt = 0;
    }

    if (millis() - lastLeadScrollAt >= kLeadScrollStepMs) {
      lastLeadScrollAt = millis();
      const uint8_t messageLength = String(kLeadScrollMessage).length();
      leadScrollOffset = (leadScrollOffset + 1) % messageLength;
    }

    showScreen(
        "Smart ECG Device",
        buildScrollingLine(String(kLeadScrollMessage), leadScrollOffset));
    return;
  }

  if (recordingEnabled) {
    const String lineOne = displayFrame == 0 ? "Smart ECG Live" : "Recording...";
    const String lineTwo =
        displayFrame == 0 ? "Sample " + String(latestSample)
                          : apAddress.toString();
    updateDisplayPage(1, 2, kRecordingScreenHoldMs, lineOne, lineTwo);
    return;
  }

  if (leadsAttached) {
    String lineOne = "Probes Ready";
    String lineTwo = "Sample " + String(latestSample);

    if (displayFrame == 1) {
      lineOne = "Open mobile app";
      lineTwo = "Start live test";
    } else if (displayFrame == 2) {
      lineOne = "Device IP";
      lineTwo = apAddress.toString();
    }

    updateDisplayPage(2, 3, kReadyScreenHoldMs, lineOne, lineTwo);
    return;
  }

  String lineOne = "Smart ECG Device";
  String lineTwo = "Ready for setup";

  if (displayFrame == 1) {
    lineOne = "Device IP";
    lineTwo = apAddress.toString();
  } else if (displayFrame == 2) {
    lineOne = "Port 80 Ready";
    lineTwo = "Open mobile app";
  }

  updateDisplayPage(3, 3, kReadyScreenHoldMs, lineOne, lineTwo);
}

void refreshSerialLog() {
  if (millis() - lastSerialAt < kSerialRefreshMs) {
    return;
  }

  lastSerialAt = millis();
  Serial.print(F("[ECG] leadsAttached="));
  Serial.print(leadsAttached ? F("yes") : F("no"));
  Serial.print(F(" recording="));
  Serial.print(recordingEnabled ? F("yes") : F("no"));
  Serial.print(F(" sample="));
  Serial.print(latestSample);
  Serial.print(F(" ip="));
  Serial.println(apAddress.toString());
}

void setup() {
  Serial.begin(115200);
  pinMode(kLeadPositivePin, INPUT);
  pinMode(kLeadNegativePin, INPUT);

  lcd.init();
  lcd.backlight();
  playStartupAnimation();

  setupSoftAp();
  setupServer();
  updateSignalState();
  printStartupInstructions();

  showStartupIpScreen();
}

void loop() {
  server.handleClient();

  if (millis() - lastSampleAt >= kSampleIntervalMs) {
    lastSampleAt = millis();
    updateSignalState();
  }

  refreshDisplay();
  refreshSerialLog();
}
