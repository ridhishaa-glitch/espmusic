#include "stream_client.h"
#include "config.h"
#include "virtual_fat.h"
#include "usb_msc.h"
#include <WiFiClientSecure.h>
#include <HTTPClient.h>

StreamClient streamClient;

StreamClient::StreamClient()
    : state(PlaybackState::IDLE),
      queueIndex(0),
      elapsedSeconds(0),
      volume(75),
      sleepTimerSeconds(0),
      streamTaskHandle(nullptr),
      timerTaskHandle(nullptr),
      stopRequested(false) {
}

bool StreamClient::init() {
    if (!ringBuffer.init(PSRAM_BUFFER_SIZE)) {
        Serial.println("[StreamClient] Failed to allocate ring buffer!");
        return false;
    }
    virtualFAT.setRingBuffer(&ringBuffer);

    // Launch FreeRTOS Timer & Stream tasks
    xTaskCreatePinnedToCore(
        timerTask,
        "TimerTask",
        4096,
        this,
        1,
        &timerTaskHandle,
        1
    );

    xTaskCreatePinnedToCore(
        streamTask,
        "StreamTask",
        16384,
        this,
        2,
        &streamTaskHandle,
        0
    );

    return true;
}

String StreamClient::getStateString() const {
    switch (state) {
        case PlaybackState::PLAYING:   return "playing";
        case PlaybackState::PAUSED:    return "paused";
        case PlaybackState::BUFFERING: return "buffering";
        default:                       return "idle";
    }
}

void StreamClient::playTrack(const TrackInfo& track) {
    stopRequested = true;
    delay(50);

    currentTrack = track;
    elapsedSeconds = 0;
    ringBuffer.reset();
    state = PlaybackState::BUFFERING;
    stopRequested = false;

    // Trigger soft USB reconnect so speaker reads the new audio from sector 0
    usbMscSoftReconnect();
}

void StreamClient::setQueue(const std::vector<TrackInfo>& newQueue, int startIndex, bool shuffle) {
    if (newQueue.empty()) return;
    queue = newQueue;

    if (shuffle) {
        // Simple Fisher-Yates shuffle
        for (size_t i = queue.size() - 1; i > 0; i--) {
            size_t j = random(i + 1);
            std::swap(queue[i], queue[j]);
        }
        queueIndex = 0;
    } else {
        queueIndex = constrain(startIndex, 0, (int)queue.size() - 1);
    }

    playTrack(queue[queueIndex]);
}

void StreamClient::pause() {
    if (state == PlaybackState::PLAYING) {
        state = PlaybackState::PAUSED;
    }
}

void StreamClient::resume() {
    if (state == PlaybackState::PAUSED) {
        state = PlaybackState::PLAYING;
    }
}

void StreamClient::next() {
    if (!queue.empty()) {
        queueIndex = (queueIndex + 1) % queue.size();
        playTrack(queue[queueIndex]);
    }
}

void StreamClient::previous() {
    if (!queue.empty()) {
        queueIndex = (queueIndex - 1 + queue.size()) % queue.size();
        playTrack(queue[queueIndex]);
    }
}

void StreamClient::stop() {
    stopRequested = true;
    ringBuffer.reset();
    state = PlaybackState::IDLE;
    currentTrack = TrackInfo();
}

void StreamClient::setVolume(int vol) {
    volume = constrain(vol, 0, 100);
}

void StreamClient::setSleepTimer(int minutes) {
    sleepTimerSeconds = minutes * 60;
    Serial.printf("[Timer] Sleep timer set to %d minutes (%d seconds)\n", minutes, sleepTimerSeconds);
}

void StreamClient::cancelSleepTimer() {
    sleepTimerSeconds = 0;
    Serial.println("[Timer] Sleep timer cancelled");
}

void StreamClient::timerTask(void* param) {
    StreamClient* self = (StreamClient*)param;
    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(1000));

        // Increment track elapsed time if playing
        if (self->state == PlaybackState::PLAYING) {
            self->elapsedSeconds++;
        }

        // Sleep timer countdown
        if (self->sleepTimerSeconds > 0) {
            self->sleepTimerSeconds--;
            if (self->sleepTimerSeconds == 0) {
                Serial.println("[Timer] Sleep timer expired! Stopping playback.");
                self->stop();
            }
        }
    }
}

void StreamClient::streamTask(void* param) {
    StreamClient* self = (StreamClient*)param;
    uint8_t chunkBuffer[4096];

    for (;;) {
        if (self->state != PlaybackState::BUFFERING && self->state != PlaybackState::PLAYING) {
            vTaskDelay(pdMS_TO_TICKS(100));
            continue;
        }

        if (self->currentTrack.url.isEmpty()) {
            vTaskDelay(pdMS_TO_TICKS(100));
            continue;
        }

        Serial.printf("[Stream] Connecting to URL: %s\n", self->currentTrack.url.c_str());

        WiFiClientSecure secureClient;
        secureClient.setInsecure(); // Skip certificate verification for speed & RAM savings
        HTTPClient http;

        if (!http.begin(secureClient, self->currentTrack.url)) {
            Serial.println("[Stream] Failed to begin HTTPClient");
            self->state = PlaybackState::IDLE;
            vTaskDelay(pdMS_TO_TICKS(1000));
            continue;
        }

        http.addHeader("User-Agent", "ESPMusic-Player/1.0");
        int httpCode = http.GET();

        if (httpCode != HTTP_CODE_OK) {
            Serial.printf("[Stream] HTTP GET failed with code: %d\n", httpCode);
            http.end();
            self->state = PlaybackState::IDLE;
            vTaskDelay(pdMS_TO_TICKS(1000));
            continue;
        }

        WiFiClient* stream = http.getStreamPtr();
        int totalBytes = http.getSize();
        int bytesReadTotal = 0;
        Serial.printf("[Stream] Streaming started (Size: %d bytes)\n", totalBytes);

        // Buffer initial preload before transitioning to PLAYING
        while (!self->stopRequested && http.connected() && (bytesReadTotal < totalBytes || totalBytes == -1)) {
            if (self->state == PlaybackState::PAUSED) {
                vTaskDelay(pdMS_TO_TICKS(100));
                continue;
            }

            // Check if buffer has room for incoming chunk
            if (self->ringBuffer.freeSpace() < sizeof(chunkBuffer)) {
                if (self->state == PlaybackState::BUFFERING) {
                    self->state = PlaybackState::PLAYING;
                    Serial.println("[Stream] Initial pre-buffer filled! Now Playing.");
                }
                vTaskDelay(pdMS_TO_TICKS(20));
                continue;
            }

            size_t availableBytes = stream->available();
            if (availableBytes > 0) {
                size_t toRead = (availableBytes < sizeof(chunkBuffer)) ? availableBytes : sizeof(chunkBuffer);
                int bytesRead = stream->read(chunkBuffer, toRead);
                if (bytesRead > 0) {
                    self->ringBuffer.write(chunkBuffer, bytesRead);
                    bytesReadTotal += bytesRead;

                    if (self->state == PlaybackState::BUFFERING && self->ringBuffer.fillPercentage() >= 20) {
                        self->state = PlaybackState::PLAYING;
                        Serial.println("[Stream] Pre-buffer threshold reached (20%)! Now Playing.");
                    }
                }
            } else {
                vTaskDelay(pdMS_TO_TICKS(10));
            }
        }

        http.end();
        Serial.printf("[Stream] Stream ended. Total bytes downloaded: %d\n", bytesReadTotal);

        // If song finished naturally (not stopped by user), wait for ring buffer to drain then play next
        if (!self->stopRequested && !self->queue.empty()) {
            while (self->ringBuffer.available() > 2048 && !self->stopRequested) {
                vTaskDelay(pdMS_TO_TICKS(200));
            }
            if (!self->stopRequested) {
                Serial.println("[Stream] Song completed. Advancing to next track in queue...");
                self->next();
            }
        }
    }
}
