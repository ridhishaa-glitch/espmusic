#include "api_server.h"
#include "stream_client.h"
#include "config.h"
#include <WiFi.h>
#include <ESPAsyncWebServer.h>
#include <ArduinoJson.h>

static AsyncWebServer server(HTTP_SERVER_PORT);

void setCorsHeaders(AsyncWebServerResponse* response) {
    response->addHeader("Access-Control-Allow-Origin", "*");
    response->addHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    response->addHeader("Access-Control-Allow-Headers", "Content-Type");
}

void initApiServer() {
    Serial.println("[HTTP] Registering API endpoints...");

    // OPTIONS pre-flight handler
    server.onNotFound([](AsyncWebServerRequest* request) {
        if (request->method() == HTTP_OPTIONS) {
            AsyncWebServerResponse* response = request->beginResponse(204);
            setCorsHeaders(response);
            request->send(response);
        } else {
            request->send(404, "text/plain", "Not found");
        }
    });

    // 1. GET /api/status
    server.on("/api/status", HTTP_GET, [](AsyncWebServerRequest* request) {
        JsonDocument doc;
        doc["status"] = streamClient.getStateString();

        JsonObject trackObj = doc["current_track"].to<JsonObject>();
        const TrackInfo& track = streamClient.getCurrentTrack();
        trackObj["id"] = track.id;
        trackObj["name"] = track.name;
        trackObj["artist"] = track.artist;
        trackObj["duration"] = track.duration;
        trackObj["elapsed"] = streamClient.getElapsedSeconds();

        doc["queue_count"] = streamClient.getQueueCount();
        doc["queue_index"] = streamClient.getQueueIndex();
        doc["volume"] = streamClient.getVolume();
        doc["sleep_timer_seconds"] = streamClient.getSleepTimerSeconds();
        doc["wifi_rssi"] = WiFi.RSSI();
        doc["buffer_percent"] = streamClient.getBufferPercent();

        String responseStr;
        serializeJson(doc, responseStr);

        AsyncWebServerResponse* response = request->beginResponse(200, "application/json", responseStr);
        setCorsHeaders(response);
        request->send(response);
    });

    // 2. POST /api/play
    server.on(
        "/api/play",
        HTTP_POST,
        [](AsyncWebServerRequest* request) {},
        nullptr,
        [](AsyncWebServerRequest* request, uint8_t* data, size_t len, size_t index, size_t total) {
            JsonDocument doc;
            DeserializationError err = deserializeJson(doc, data, len);

            if (err) {
                request->send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
                return;
            }

            TrackInfo track;
            track.id = doc["id"] | "";
            track.name = doc["name"] | "Unknown Track";
            track.artist = doc["artist"] | "Unknown Artist";
            track.url = doc["url"] | "";
            track.duration = doc["duration"] | 0;

            if (track.url.isEmpty()) {
                request->send(400, "application/json", "{\"error\":\"Missing URL\"}");
                return;
            }

            Serial.printf("[API] Play command received: %s - %s\n", track.name.c_str(), track.artist.c_str());
            streamClient.playTrack(track);

            AsyncWebServerResponse* response = request->beginResponse(200, "application/json", "{\"status\":\"ok\"}");
            setCorsHeaders(response);
            request->send(response);
        }
    );

    // 3. POST /api/queue
    server.on(
        "/api/queue",
        HTTP_POST,
        [](AsyncWebServerRequest* request) {},
        nullptr,
        [](AsyncWebServerRequest* request, uint8_t* data, size_t len, size_t index, size_t total) {
            JsonDocument doc;
            DeserializationError err = deserializeJson(doc, data, len);

            if (err) {
                request->send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
                return;
            }

            JsonArray tracksArr = doc["tracks"];
            std::vector<TrackInfo> newQueue;

            for (JsonObject t : tracksArr) {
                TrackInfo track;
                track.id = t["id"] | "";
                track.name = t["name"] | "";
                track.artist = t["artist"] | "";
                track.url = t["url"] | "";
                track.duration = t["duration"] | 0;
                if (!track.url.isEmpty()) {
                    newQueue.push_back(track);
                }
            }

            int startIndex = doc["startIndex"] | 0;
            bool shuffle = doc["shuffle"] | false;

            Serial.printf("[API] Queue received with %u tracks (startIndex: %d, shuffle: %d)\n",
                (unsigned int)newQueue.size(), startIndex, shuffle);
            streamClient.setQueue(newQueue, startIndex, shuffle);

            AsyncWebServerResponse* response = request->beginResponse(200, "application/json", "{\"status\":\"ok\"}");
            setCorsHeaders(response);
            request->send(response);
        }
    );

    // 4. POST /api/control
    server.on(
        "/api/control",
        HTTP_POST,
        [](AsyncWebServerRequest* request) {},
        nullptr,
        [](AsyncWebServerRequest* request, uint8_t* data, size_t len, size_t index, size_t total) {
            JsonDocument doc;
            deserializeJson(doc, data, len);

            String action = doc["action"] | "";
            Serial.printf("[API] Control action: %s\n", action.c_str());

            if (action == "pause") {
                streamClient.pause();
            } else if (action == "resume") {
                streamClient.resume();
            } else if (action == "next") {
                streamClient.next();
            } else if (action == "prev" || action == "previous") {
                streamClient.previous();
            } else if (action == "stop") {
                streamClient.stop();
            }

            AsyncWebServerResponse* response = request->beginResponse(200, "application/json", "{\"status\":\"ok\"}");
            setCorsHeaders(response);
            request->send(response);
        }
    );

    // 5. POST /api/volume
    server.on(
        "/api/volume",
        HTTP_POST,
        [](AsyncWebServerRequest* request) {},
        nullptr,
        [](AsyncWebServerRequest* request, uint8_t* data, size_t len, size_t index, size_t total) {
            JsonDocument doc;
            deserializeJson(doc, data, len);

            int vol = doc["volume"] | 75;
            streamClient.setVolume(vol);

            AsyncWebServerResponse* response = request->beginResponse(200, "application/json", "{\"status\":\"ok\"}");
            setCorsHeaders(response);
            request->send(response);
        }
    );

    // 6. POST /api/timer
    server.on(
        "/api/timer",
        HTTP_POST,
        [](AsyncWebServerRequest* request) {},
        nullptr,
        [](AsyncWebServerRequest* request, uint8_t* data, size_t len, size_t index, size_t total) {
            JsonDocument doc;
            deserializeJson(doc, data, len);

            String action = doc["action"].as<String>();
            if (action == "cancel") {
                streamClient.cancelSleepTimer();
            } else {
                int minutes = doc["minutes"].is<int>() 
                    ? doc["minutes"].as<int>() 
                    : (doc["minutes"].is<const char*>() ? atoi(doc["minutes"].as<const char*>()) : 30);
                streamClient.setSleepTimer(minutes);
            }

            AsyncWebServerResponse* response = request->beginResponse(200, "application/json", "{\"status\":\"ok\"}");
            setCorsHeaders(response);
            request->send(response);
        }
    );

    server.begin();
    Serial.println("[HTTP] Server listening on port 80.");
}
