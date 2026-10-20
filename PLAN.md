# ESP Music Mod: System Architecture & Execution Plan

## 1. Project Summary & Goals
This project converts a Bluetooth speaker with a USB flash drive (pendrive) playback port into an autonomous, Wi-Fi-enabled smart music streamer controlled by a dedicated Android app.

- **Microcontroller**: ESP32-S3 (Dual-core 240MHz, Native USB-OTG, Wi-Fi 2.4GHz, PSRAM).
- **Speaker Connection**: USB-C to USB-A cable connected into the speaker's USB-A flash drive port. The ESP32-S3 acts as a USB Mass Storage Class (MSC) Device presenting a virtual FAT filesystem that streams audio on the fly.
- **Autonomous Playback**: The ESP32-S3 streams audio directly from high-speed JioSaavn CDN servers over Wi-Fi without keeping the phone's battery or connection engaged.
- **Local Network & Discovery**: Accessible at `http://espmusic.local` using mDNS with fallback IP detection.
- **Music Catalog & API**: Full integration with the JioSaavn API (`https://saavn.sumit.co`) for global search, songs, albums, artists, playlists, infinite suggestions/radio, and high-quality audio stream URLs.
- **App Features**:
  - Search by song, album, artist, playlist.
  - Playlist playback and infinite random playback (via track suggestions).
  - Sleep timer with configurable countdown and auto-fade/stop.
  - Real-time ESP discovery, status tracking, volume, and playback controls.
- **CI/CD Build System**:
  - GitHub Actions workflow that automatically builds and outputs the Android APK on push and release.

---

## 2. Hardware Architecture & USB Mass Storage Emulation

```
+-------------------------------------------------------------+
|                     Bluetooth Speaker                       |
|  - Reads USB Flash Drive in "USB Mode"                      |
|  - Acts as USB Host (requests sectors via SCSI READ10)      |
|  - Decodes audio format (MP3 / WAV) from read sectors       |
+------------------------------^------------------------------+
                               | USB-A (Host) to USB-C (Device)
                               | Data Lines: D+ (GPIO 20), D- (GPIO 19)
+------------------------------v------------------------------+
|                    ESP32-S3 Microcontroller                 |
|                                                             |
|  +-------------------------------------------------------+  |
|  | TinyUSB MSC Peripheral (Virtual FAT32 / FAT16 Engine) |  |
|  | - Sector 0: Virtual Master Boot Record (MBR)          |  |
|  | - Sectors: FAT Allocation Tables                      |  |
|  | - Sectors: Root Directory with dynamic track entries  |  |
|  | - Cluster Sectors: Feeds bytes from Audio Ring Buffer |  |
|  +-------------------------------------------------------+  |
|                               ^                             |
|                               | (Decoded Audio / Stream)    |
|  +----------------------------+--------------------------+  |
|  | High-Speed Stream Client & Buffer Manager             |  |
|  | - Connects to HTTPS CDN stream URL                    |  |
|  | - Circular FIFO buffer in PSRAM (e.g., 2MB-4MB)       |  |
|  | - Jitter & underrun protection                        |  |
|  +-------------------------------------------------------+  |
|                               ^                             |
|                               | (Commands & Stream URLs)    |
|  +----------------------------+--------------------------+  |
|  | Async WebServer + mDNS (`espmusic.local`)             |  |
|  | - Endpoints: /api/play, /api/queue, /api/timer, etc.  |  |
|  +-------------------------------------------------------+  |
+------------------------------^------------------------------+
                               | Wi-Fi 802.11 b/g/n
                               |
+------------------------------+------------------------------+
|                 Mobile App (Flutter / Android)               |
|  - Communicates with `http://espmusic.local`                |
|  - Queries JioSaavn API (`https://saavn.sumit.co`)           |
+-------------------------------------------------------------+
```

### Virtual USB Mass Storage Mechanism
1. **Enumeration**: When plugged in, the speaker's USB Host sends SCSI `INQUIRY` and `READ_CAPACITY` commands. The ESP32-S3 responds as a standard FAT32 drive (e.g. 2GB capacity).
2. **Directory & File Layout**: The ESP32-S3 generates virtual boot sectors, partition tables, and directory entries on the fly. It exposes a primary audio file (e.g., `TRACK.MP3` / `STREAM.MP3` or `LIVE.WAV`).
3. **Sector Streaming**: When the speaker begins reading data clusters for the track via `SCSI READ(10)`, the ESP32-S3 pulls bytes directly from its streaming ring buffer filled over Wi-Fi.
4. **Track Transition & Re-indexing**: When the user changes songs from the app, the ESP32-S3 can update file metadata or perform a quick soft USB reconnect (toggling the USB D+ pull-up resistor) to trigger an immediate re-read by the speaker.

---

## 3. Communication Protocol (ESP32-S3 REST API)

All endpoints run on port 80 at `http://espmusic.local`:

### 3.1 Status & Diagnostics
- `GET /api/status`
  - Response:
    ```json
    {
      "status": "playing", // "idle", "playing", "paused", "buffering"
      "current_track": {
        "id": "0W6DtW_N",
        "name": "Believer",
        "artist": "Imagine Dragons",
        "duration": 144,
        "elapsed": 42
      },
      "queue_count": 5,
      "queue_index": 0,
      "sleep_timer_seconds": 900,
      "wifi_rssi": -55,
      "buffer_percent": 85
    }
    ```

### 3.2 Playback Control
- `POST /api/play`
  - Payload:
    ```json
    {
      "id": "0W6DtW_N",
      "name": "Believer",
      "artist": "Imagine Dragons",
      "url": "https://aac.saavncdn.com/...",
      "duration": 144
    }
    ```
- `POST /api/queue`
  - Payload:
    ```json
    {
      "tracks": [
        { "id": "...", "name": "...", "artist": "...", "url": "...", "duration": 180 }
      ],
      "startIndex": 0,
      "shuffle": false
    }
    ```
- `POST /api/control`
  - Payload: `{"action": "pause" | "resume" | "next" | "prev" | "stop"}`

### 3.3 Sleep Timer
- `POST /api/timer`
  - Payload: `{"action": "set", "minutes": 30}` or `{"action": "cancel"}`
  - Logic: ESP maintains an active countdown timer. When timer expires, audio softly fades out and enters idle standby.

---

## 4. Mobile Application (Flutter)

### Architecture
- **State Management**: `Provider` / `ChangeNotifier` for clean, decoupled state.
- **Theme**: Premium modern dark music streaming UI (inspired by Apple Music / Spotify).
- **Core Modules**:
  1. `JioSaavnApi`: Full implementation of all methods documented in OpenAPI schema:
     - Global search (`/api/search`)
     - Song search (`/api/search/songs`)
     - Album search & details (`/api/search/albums`, `/api/albums`)
     - Playlist search & details (`/api/search/playlists`, `/api/playlists`)
     - Artist search & details (`/api/search/artists`, `/api/artists/{id}`)
     - Song suggestions (`/api/songs/{id}/suggestions`)
  2. `EspController`:
     - Discovers `espmusic.local` (with manual IP address override).
     - Sends play/queue/control/timer commands.
     - Polls `/api/status` for live track progress, buffer status, and sleep countdown.
  3. `SleepTimer`:
     - Quick presets: 15 min, 30 min, 45 min, 60 min, custom picker.
     - Live countdown badge in player bar.
  4. `Player UI`:
     - Bottom Mini-Player with persistent controls.
     - Full-screen Now Playing with album art, scrub bar, sleep timer, shuffle/repeat.
     - Song, Playlist, Album, and Artist detail views.

---

## 5. CI/CD: Automated APK Compilation (GitHub Actions)

A GitHub Actions workflow (`.github/workflows/build-apk.yml`) that:
1. Sets up Java 17 and Flutter stable.
2. Checks out code and installs dependencies (`flutter pub get`).
3. Runs Flutter unit & widget tests.
4. Builds release APK (`flutter build apk --release`).
5. Uploads the `.apk` as a workflow artifact and publishes it to GitHub Releases when tagged.

---

## 6. Execution Steps
1. Create complete Flutter companion app codebase in `/app`.
2. Configure Android Gradle build files and Manifests with network permissions and cleartext HTTP for local IP/mDNS.
3. Create GitHub Actions APK compilation workflow in `/.github/workflows/build-apk.yml`.
4. Create ESP32-S3 firmware codebase in `/esp32` with TinyUSB Virtual FAT MSC engine, HTTPS stream buffering, mDNS responder, and REST API.
5. Create comprehensive user guide with wiring schematics and flashing instructions.
