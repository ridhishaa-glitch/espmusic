# ESP Music: Smart Wi-Fi Speaker Mod & Android Companion

A complete smart music streaming solution that turns any Bluetooth speaker with a USB flash drive port into an autonomous, Wi-Fi connected smart speaker powered by an **ESP32-S3** and controlled via a custom **Android Flutter App**.

---

## Features
- **Standalone Wi-Fi Streaming**: The ESP32-S3 streams audio directly from high-speed CDNs over Wi-Fi. The phone does NOT need to remain connected or stream audio via Bluetooth.
- **Local Network Discovery**: Runs on your local Wi-Fi with mDNS at `http://espmusic.local`.
- **Music Catalog & Search**: Complete music search for songs, albums, artists, and playlists powered by the JioSaavn API (`https://saavn.sumit.co`).
- **Infinite Radio / Play Random**: Start an auto-expanding infinite playlist based on track suggestions.
- **Sleep Timer**: Built-in sleep timer with 15m, 30m, 45m, 60m presets and custom minutes. When the timer expires, the ESP stops playback automatically.
- **Automated GitHub Actions Build**: GitHub Actions workflow (`.github/workflows/build-apk.yml`) automatically compiles and generates the release `.apk` ready to install on your phone.

---

## Project Structure
```
espmusic/
├── .github/workflows/
│   └── build-apk.yml          # GitHub Actions workflow for building Android APK
├── PLAN.md                    # Comprehensive architecture plan
├── WIRING.md                  # Hardware connection and pinout guide
├── app/                       # Android Companion Application (Flutter)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/            # Song, Album, Playlist, Artist, EspStatus
│   │   ├── services/          # SaavnApiService, EspService
│   │   ├── providers/         # PlayerProvider
│   │   └── ui/                # Screens & Widgets (Player, Search, Timer, Settings)
│   ├── android/               # Gradle & Android manifest configurations
│   └── pubspec.yaml
└── esp32/                     # ESP32-S3 Firmware
    ├── platformio.ini         # PlatformIO configuration
    ├── include/               # Config, Virtual FAT, Ring Buffer, Stream Client
    └── src/                   # Main, WebServer API, TinyUSB MSC, Wi-Fi & mDNS
```

---

## Quick Start Guide

### 1. Configure Wi-Fi on the ESP32-S3
Open [config.h](file:///c:/Users/LENOVO/Documents/esp/espmusic/esp32/include/config.h) and set your Wi-Fi credentials:
```cpp
#define DEFAULT_WIFI_SSID       "YourHomeWiFiName"
#define DEFAULT_WIFI_PASS       "YourHomeWiFiPassword"
```

### 2. Flashing the ESP32-S3
Connect your ESP32-S3 via USB to your computer:
- **Using PlatformIO**:
  ```bash
  cd esp32
  pio run -t upload
  ```
- **Using Arduino IDE**:
  - Select Board: `ESP32S3 Dev Module`
  - USB Mode: `USB-OTG (TinyUSB)`
  - PSRAM: `OPI PSRAM` or `QSPI PSRAM` (depending on your board)
  - Flash Mode: `QIO`
  - Upload `esp32/src/main.cpp` and related files.

### 3. Connect to the Speaker
- Plug the USB-C end into the ESP32-S3 Native USB port.
- Plug the USB-A end into the speaker's USB flash drive port.
- Switch the speaker to **USB Mode**.

### 4. Build & Install the Android App
Push this repository to GitHub:
```bash
git add .
git commit -m "Initial commit for ESP Music mod"
git branch -M main
git remote add origin https://github.com/<your-username>/espmusic.git
git push -u origin main
```
- Open your repository on GitHub and navigate to the **Actions** tab.
- The **Build Android APK** workflow will compile the APK.
- Download `ESPMusic-release-apk` from the Actions artifacts and install it on your Android phone!
- The app will automatically find `http://espmusic.local`.
