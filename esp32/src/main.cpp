#include <Arduino.h>
#include <WiFi.h>
#include <ESPmDNS.h>
#include "config.h"
#include "usb_msc.h"
#include "stream_client.h"
#include "api_server.h"

// Wi-Fi Connection Helper
void connectWiFi() {
    Serial.printf("\n[WiFi] Connecting to %s", DEFAULT_WIFI_SSID);
    WiFi.mode(WIFI_STA);
    WiFi.begin(DEFAULT_WIFI_SSID, DEFAULT_WIFI_PASS);

    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 30) {
        delay(500);
        Serial.print(".");
        attempts++;
    }

    if (WiFi.status() == WL_CONNECTED) {
        Serial.println("\n[WiFi] Connected successfully!");
        Serial.printf("[WiFi] IP Address: %s\n", WiFi.localIP().toString().c_str());
        Serial.printf("[WiFi] Signal (RSSI): %d dBm\n", WiFi.RSSI());
    } else {
        Serial.println("\n[WiFi] Failed to connect! Please check Wi-Fi credentials in config.h");
    }
}

// mDNS Responder Setup
void setupMDNS() {
    if (MDNS.begin(MDNS_HOSTNAME)) {
        Serial.printf("[mDNS] Responder started: http://%s.local\n", MDNS_HOSTNAME);
        MDNS.addService("http", "tcp", HTTP_SERVER_PORT);
    } else {
        Serial.println("[mDNS] Error setting up mDNS responder!");
    }
}

void setup() {
    Serial.begin(115200);
    delay(1000);

    Serial.println("\n===========================================");
    Serial.println("        ESP Music Smart Speaker Mod        ");
    Serial.println("===========================================");

    // 1. Initialize USB Mass Storage Class (Emulated USB Drive)
    initUsbMsc();

    // 2. Initialize PSRAM Ring Buffer & FreeRTOS Stream Task
    if (!streamClient.init()) {
        Serial.println("[Error] Failed to initialize Stream Client / PSRAM!");
    }

    // 3. Connect to Home Wi-Fi
    connectWiFi();

    // 4. Start mDNS (espmusic.local)
    setupMDNS();

    // 5. Start HTTP REST API Server
    initApiServer();

    Serial.println("===========================================");
    Serial.println("[System] Ready! Connect speaker to USB-C OTG.");
    Serial.printf("[System] Control via app at: http://%s.local\n", MDNS_HOSTNAME);
    Serial.println("===========================================\n");
}

void loop() {
    delay(100);
}
