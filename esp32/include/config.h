#pragma once

#include <Arduino.h>

// Wi-Fi Credentials
#define DEFAULT_WIFI_SSID       "Gupta_Wifi"
#define DEFAULT_WIFI_PASS       "Piyushgupta"

// mDNS hostname (resolves as http://espmusic.local)
#define MDNS_HOSTNAME           "espmusic"

// HTTP Server Port
#define HTTP_SERVER_PORT        80

// Ring Buffer Size in PSRAM (1.5 MB handles ~75 seconds of 160kbps audio)
#define PSRAM_BUFFER_SIZE       (1536 * 1024)

// Sector size for USB Mass Storage
#define DISK_BLOCK_SIZE         512
#define DISK_BLOCK_NUM          (2048 * 1024) // 1GB Virtual Drive (1024 * 1024 KB / 512 = 2097152 blocks)

// Virtual File Layout
#define VIRTUAL_FILE_NAME       "01_LIVE_STREAM.MP3"
#define VIRTUAL_FILE_SIZE       (500 * 1024 * 1024) // 500 MB virtual file length so speaker plays continuously

// USB Pins for ESP32-S3 Native USB OTG:
// GPIO 19: USB D-
// GPIO 20: USB D+
