#include <ESP8266WiFi.h>
#include <ESPAsyncTCP.h>
#include <ESPAsyncWebServer.h>
#include <LiquidCrystal_I2C.h>

LiquidCrystal_I2C lcd(0x27, 16, 2);
AsyncWebServer server(80);

const char* kAccessPointName = "ECG Monitor";
const char* kAccessPointPassword = "12341234";
const uint16_t kServerPort = 80;
const uint8_t kLeadPositivePin = D5;
const uint8_t kLeadNegativePin = D6;
const uint8_t kSignalPin = A0;
const unsigned long kSampleIntervalMs = 8;
const unsigned long kDisplayRefreshMs = 350;
const unsigned long kSerialRefreshMs = 1200;

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
uint8_t displayFrame = 0;

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

  showScreen("ECG Monitor", "Initializing");
  delay(500);

  for (uint8_t i = 0; i < 6; i++) {
    showScreen("System Startup", bootFrames[i]);
    delay(180);
  }

  showScreen("Checking Leads", "Hold steady...");
  delay(450);
  showScreen("Starting Wi-Fi", "SoftAP Mode");
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

void sendCommandResponse(
    AsyncWebServerRequest* request,
    int statusCode,
    bool ok,
    const String& message) {
  request->send(
      statusCode,
      "application/json",
      "{\"ok\":" + jsonBool(ok) + ",\"message\":\"" + message + "\"}");
}

void handleCommand(AsyncWebServerRequest* request) {
  if (!request->hasParam("action")) {
    sendCommandResponse(request, 400, false, "Missing action query parameter");
    return;
  }

  const String action = request->getParam("action")->value();

  if (action == "start_recording") {
    recordingEnabled = true;
    sendCommandResponse(request, 200, true, "Recording enabled");
    return;
  }

  if (action == "stop_recording") {
    recordingEnabled = false;
    sendCommandResponse(request, 200, true, "Recording stopped");
    return;
  }

  if (action == "calibrate") {
    baselineSample = latestSample;
    sendCommandResponse(request, 200, true, "Baseline captured");
    return;
  }

  if (action == "status") {
    request->send(200, "application/json", buildHealthPayload());
    return;
  }

  sendCommandResponse(request, 400, false, "Unsupported action");
}

void setupServer() {
  server.on("/", HTTP_GET, [](AsyncWebServerRequest* request) {
    request->send(
        200,
        "text/plain",
        "ECG Monitor ready\n" + connectionSummary() +
            "\nUse /health, /ecg and /command?action=start_recording");
  });

  server.on("/health", HTTP_GET, [](AsyncWebServerRequest* request) {
    request->send(200, "application/json", buildHealthPayload());
  });

  server.on("/ecg", HTTP_GET, [](AsyncWebServerRequest* request) {
    if (!leadsAttached) {
      request->send(
          503,
          "application/json",
          "{\"status\":\"lead_off\",\"message\":\"Attach ECG leads before recording\"}");
      return;
    }

    request->send(200, "application/json", buildSamplePayload());
  });

  server.on("/getDustDensity", HTTP_GET, [](AsyncWebServerRequest* request) {
    if (!leadsAttached) {
      request->send(503, "text/plain", "lead_off");
      return;
    }

    request->send(200, "text/plain", String(latestSample));
  });

  server.on("/command", HTTP_GET, handleCommand);

  server.onNotFound([](AsyncWebServerRequest* request) {
    request->send(
        404,
        "application/json",
        "{\"ok\":false,\"message\":\"Unknown endpoint. Use /health, /ecg or /command\"}");
  });

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
  Serial.println(F("=== ECG Monitor Device Ready ==="));
  Serial.println(connectionSummary());
  Serial.println(F("Health endpoint : http://192.168.4.1/health"));
  Serial.println(F("ECG endpoint    : http://192.168.4.1/ecg"));
  Serial.println(F("Command endpoint: http://192.168.4.1/command?action=start_recording"));
  Serial.println(F("Commands        : start_recording, stop_recording, calibrate, status"));
  Serial.println(F("If the app shows lead_off, attach the electrodes and try again."));
  Serial.println(F("================================"));
  Serial.println();
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
  printStartupInstructions();

  showScreen("Wi-Fi Ready", apAddress.toString());
  delay(1200);
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
  if (millis() - lastDisplayAt < kDisplayRefreshMs) {
    return;
  }

  lastDisplayAt = millis();
  displayFrame = (displayFrame + 1) % 4;

  if (!leadsAttached) {
    const String lineTwo = displayFrame % 2 == 0 ? "Attach leads" : apAddress.toString();
    showScreen("Lead Check", lineTwo);
    return;
  }

  if (recordingEnabled) {
    const String lineTwo =
        displayFrame % 2 == 0 ? "Sample " + String(latestSample)
                              : "IP " + apAddress.toString();
    showScreen("Recording Live", lineTwo);
    return;
  }

  const String idleLine = displayFrame % 2 == 0 ? "Port 80 Ready" : "Cmd /command";
  showScreen("ECG Ready", idleLine);
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

void loop() {
  if (millis() - lastSampleAt >= kSampleIntervalMs) {
    lastSampleAt = millis();
    updateSignalState();
  }

  refreshDisplay();
  refreshSerialLog();
}
