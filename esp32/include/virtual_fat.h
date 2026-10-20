#pragma once

#include <Arduino.h>
#include "ring_buffer.h"

// Forward declaration
class VirtualFAT {
private:
    AudioRingBuffer* ringBuffer;
    uint32_t currentStreamOffset;

public:
    VirtualFAT();
    void setRingBuffer(AudioRingBuffer* rb);

    int32_t readSector(uint32_t lba, uint8_t* buffer, uint32_t bufsize);
    void resetPlaybackPosition();
};

extern VirtualFAT virtualFAT;
