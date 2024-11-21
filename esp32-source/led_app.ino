#include <WiFi.h>
#include <FastLED.h>
#include <WebServer.h>
#include <ArduinoJson.h>

// Dane sieci Wi-Fi
const char* ssid = "";
const char* password = "";

// Definicje LED
#define LED_PIN     5
#define NUM_LEDS    60
#define LED_TYPE    WS2812
#define COLOR_ORDER GRB

CRGB leds[NUM_LEDS];

// Ustawienia serwera
WebServer server(80);

// Zmienne sterujące
uint8_t brightness = 255;
bool ledOn = true;
CRGB currentColor = CRGB::White;
String currentPreset = "none";

// Deklaracje funkcji
void handleRoot();
void handleSetColor();
void handleSetBrightness();
void handleTurnOn();
void handleTurnOff();
void handleSetPreset();
void handleSetCustomLeds();

void setup() {
  // Inicjalizacja portu szeregowego
  Serial.begin(115200);

  // Połączenie z Wi-Fi
  WiFi.begin(ssid, password);
  Serial.print("Łączenie z Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.print(".");
  }
  Serial.println("\nPołączono! IP: " + WiFi.localIP().toString());

  // Inicjalizacja LED
  FastLED.addLeds<LED_TYPE, LED_PIN, COLOR_ORDER>(leds, NUM_LEDS);
  FastLED.setBrightness(brightness);
  FastLED.clear();
  FastLED.show();

  // Konfiguracja serwera
  server.on("/", handleRoot);
  server.on("/setColor", handleSetColor);
  server.on("/setBrightness", handleSetBrightness);
  server.on("/turnOn", handleTurnOn);
  server.on("/turnOff", handleTurnOff);
  server.on("/setPreset", handleSetPreset);
  server.on("/setCustomLeds", HTTP_POST, handleSetCustomLeds);
  server.begin();
  Serial.println("Serwer HTTP uruchomiony");
}

void loop() {
  server.handleClient();

  if (ledOn) {
    if (currentPreset == "blink") {
      static bool isOn = false;
      static unsigned long lastTime = 0;
      unsigned long currentTime = millis();
      if (currentTime - lastTime >= 500) {
        isOn = !isOn;
        if (isOn) {
          fill_solid(leds, NUM_LEDS, currentColor);
        } else {
          FastLED.clear();
        }
        FastLED.show();
        lastTime = currentTime;
      }
    } else if (currentPreset == "blade_runner") {
      static int position = 0;
      static int direction = 1; // 1 = w prawo, -1 = w lewo
      static unsigned long lastUpdate = 0;
      unsigned long currentTime = millis();

      if (currentTime - lastUpdate >= 50) { // Szybkość animacji
        FastLED.clear();
        for (int i = 0; i < 5; i++) { // Pasek o długości 5 LEDów
          int ledIndex = position + i;
          if (ledIndex >= 0 && ledIndex < NUM_LEDS) {
            leds[ledIndex] = CRGB::Red;
          }
        }
        FastLED.show();

        position += direction;
        if (position <= 0 || position >= NUM_LEDS - 5) {
          direction *= -1; // Zmiana kierunku
        }
        lastUpdate = currentTime;
      }
    } else if (currentPreset == "none" || currentPreset.startsWith("custom_")) {
      fill_solid(leds, NUM_LEDS, currentColor);
      FastLED.show();
    } else {
      // Inne presety
      if (currentPreset == "blue") {
        fill_solid(leds, NUM_LEDS, CRGB::Blue);
      } else if (currentPreset == "red") {
        fill_solid(leds, NUM_LEDS, CRGB::Red);
      } else if (currentPreset == "green") {
        fill_solid(leds, NUM_LEDS, CRGB::Green);
      } else if (currentPreset == "white") {
        fill_solid(leds, NUM_LEDS, CRGB::White);
      }
      FastLED.show();
    }
  } else {
    FastLED.clear();
    FastLED.show();
  }
  
}

// Funkcje obsługi żądań
void handleRoot() {
  server.send(200, "text/plain", "LED Controller działa");
}

void handleSetColor() {
  if (server.hasArg("r") && server.hasArg("g") && server.hasArg("b")) {
    uint8_t r = server.arg("r").toInt();
    uint8_t g = server.arg("g").toInt();
    uint8_t b = server.arg("b").toInt();
    currentColor = CRGB(r, g, b);
    currentPreset = "none";
    fill_solid(leds, NUM_LEDS, currentColor);
    FastLED.show();
    server.send(200, "text/plain", "Kolor zaktualizowany");
  } else {
    server.send(400, "text/plain", "Brak parametrów koloru");
  }
}

void handleSetBrightness() {
  if (server.hasArg("brightness")) {
    brightness = server.arg("brightness").toInt();
    FastLED.setBrightness(brightness);
    FastLED.show();
    server.send(200, "text/plain", "Jasność zaktualizowana");
  } else {
    server.send(400, "text/plain", "Brak parametru jasności");
  }
}

void handleTurnOn() {
  ledOn = true;
  server.send(200, "text/plain", "LED włączone");
}

void handleTurnOff() {
  ledOn = false;
  FastLED.clear();
  FastLED.show();
  server.send(200, "text/plain", "LED wyłączone");
}

void handleSetPreset() {
  if (server.hasArg("preset")) {
    currentPreset = server.arg("preset");

    // Sprawdź, czy jest to niestandardowy preset
    if (currentPreset.startsWith("custom_") || currentPreset == "none") {
      if (server.hasArg("r") && server.hasArg("g") && server.hasArg("b")) {
        uint8_t r = server.arg("r").toInt();
        uint8_t g = server.arg("g").toInt();
        uint8_t b = server.arg("b").toInt();
        currentColor = CRGB(r, g, b);
      } else {
        server.send(400, "text/plain", "Brak parametrów koloru dla niestandardowego presetu");
        return;
      }
    }

    server.send(200, "text/plain", "Preset ustawiony na: " + currentPreset);
  } else {
    server.send(400, "text/plain", "Brak parametru preset");
  }
}

void handleSetCustomLeds() {
  if (server.method() == HTTP_POST) {
    String jsonData = server.arg("plain");
    const size_t capacity = JSON_ARRAY_SIZE(12) + 12 * JSON_OBJECT_SIZE(4) + 1024;
    DynamicJsonDocument doc(capacity);
    DeserializationError error = deserializeJson(doc, jsonData);

    if (error) {
      server.send(400, "text/plain", "Błędny format danych JSON");
      return;
    }

    // Oczyszczamy LEDy
    FastLED.clear();

    // Przetwarzamy segmenty
    for (JsonObject segment : doc.as<JsonArray>()) {
      int segmentIndex = segment["segment"];
      int r = segment["r"];
      int g = segment["g"];
      int b = segment["b"];

      int startLed = segmentIndex * 5;
      int endLed = startLed + 5;

      for (int i = startLed; i < endLed && i < NUM_LEDS; i++) {
        leds[i] = CRGB(r, g, b);
      }
    }

    FastLED.show();
    server.send(200, "text/plain", "Segmenty zaktualizowane");
  } else {
    server.send(405, "text/plain", "Metoda nieobsługiwana");
  }
}
