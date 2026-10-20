#pragma once

#include <Arduino.h>
#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>

class AudioRingBuffer {
private:
    uint8_t* buffer;
    size_t capacity;
    size_t head; // write pointer
    size_t tail; // read pointer
    size_t count;
    SemaphoreHandle_t mutex;

public:
    AudioRingBuffer();
    ~AudioRingBuffer();

    bool init(size_t size);
    void reset();

    size_t write(const uint8_t* data, size_t len);
    size_t read(uint8_t* out, size_t len);

    size_t available() const;
    size_t freeSpace() const;
    int fillPercentage() const;
};
