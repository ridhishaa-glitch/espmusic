#include "ring_buffer.h"

AudioRingBuffer::AudioRingBuffer()
    : buffer(nullptr), capacity(0), head(0), tail(0), count(0) {
    mutex = xSemaphoreCreateMutex();
}

AudioRingBuffer::~AudioRingBuffer() {
    if (buffer) {
        free(buffer);
        buffer = nullptr;
    }
    if (mutex) {
        vSemaphoreDelete(mutex);
        mutex = nullptr;
    }
}

bool AudioRingBuffer::init(size_t size) {
    capacity = size;
    head = 0;
    tail = 0;
    count = 0;

    // Attempt allocation in PSRAM if available, fallback to internal heap
    if (psramFound()) {
        buffer = (uint8_t*)ps_malloc(capacity);
        Serial.printf("[Buffer] Allocated %u bytes in PSRAM\n", (unsigned int)capacity);
    } else {
        // Limited internal RAM fallback
        capacity = 128 * 1024;
        buffer = (uint8_t*)malloc(capacity);
        Serial.printf("[Buffer] Fallback allocated %u bytes in internal RAM\n", (unsigned int)capacity);
    }

    return (buffer != nullptr);
}

void AudioRingBuffer::reset() {
    if (xSemaphoreTake(mutex, pdMS_TO_TICKS(100))) {
        head = 0;
        tail = 0;
        count = 0;
        xSemaphoreGive(mutex);
    }
}

size_t AudioRingBuffer::write(const uint8_t* data, size_t len) {
    if (!buffer || len == 0) return 0;

    if (xSemaphoreTake(mutex, pdMS_TO_TICKS(50))) {
        size_t availableSpace = capacity - count;
        size_t toWrite = (len < availableSpace) ? len : availableSpace;

        for (size_t i = 0; i < toWrite; i++) {
            buffer[head] = data[i];
            head = (head + 1) % capacity;
        }

        count += toWrite;
        xSemaphoreGive(mutex);
        return toWrite;
    }
    return 0;
}

size_t AudioRingBuffer::read(uint8_t* out, size_t len) {
    if (!buffer || len == 0) return 0;

    if (xSemaphoreTake(mutex, pdMS_TO_TICKS(50))) {
        size_t toRead = (len < count) ? len : count;

        for (size_t i = 0; i < toRead; i++) {
            out[i] = buffer[tail];
            tail = (tail + 1) % capacity;
        }

        count -= toRead;
        xSemaphoreGive(mutex);
        return toRead;
    }
    return 0;
}

size_t AudioRingBuffer::available() const {
    return count;
}

size_t AudioRingBuffer::freeSpace() const {
    return capacity - count;
}

int AudioRingBuffer::fillPercentage() const {
    if (capacity == 0) return 0;
    return (int)((count * 100) / capacity);
}
