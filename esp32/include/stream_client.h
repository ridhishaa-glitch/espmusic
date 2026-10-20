#pragma once

#include <Arduino.h>
#include <vector>
#include "ring_buffer.h"

struct TrackInfo {
    String id;
    String name;
    String artist;
    String url;
    uint32_t duration;
};

enum class PlaybackState {
    IDLE,
    BUFFERING,
    PLAYING,
    PAUSED
};

class StreamClient {
private:
    AudioRingBuffer ringBuffer;
    PlaybackState state;
    TrackInfo currentTrack;
    std::vector<TrackInfo> queue;
    int queueIndex;
    uint32_t elapsedSeconds;
    int volume;
    int sleepTimerSeconds;

    TaskHandle_t streamTaskHandle;
    TaskHandle_t timerTaskHandle;
    bool stopRequested;

    static void streamTask(void* param);
    static void timerTask(void* param);

public:
    StreamClient();
    bool init();

    void playTrack(const TrackInfo& track);
    void setQueue(const std::vector<TrackInfo>& newQueue, int startIndex = 0, bool shuffle = false);

    void pause();
    void resume();
    void next();
    void previous();
    void stop();

    void setVolume(int vol);
    int getVolume() const { return volume; }

    void setSleepTimer(int minutes);
    void cancelSleepTimer();
    int getSleepTimerSeconds() const { return sleepTimerSeconds; }

    PlaybackState getState() const { return state; }
    String getStateString() const;
    const TrackInfo& getCurrentTrack() const { return currentTrack; }
    int getQueueCount() const { return queue.size(); }
    int getQueueIndex() const { return queueIndex; }
    uint32_t getElapsedSeconds() const { return elapsedSeconds; }
    int getBufferPercent() const { return ringBuffer.fillPercentage(); }

    AudioRingBuffer* getRingBuffer() { return &ringBuffer; }
};

extern StreamClient streamClient;
