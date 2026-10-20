# Hardware Wiring & Connection Guide

## Overview
The ESP32-S3 acts as a smart USB flash drive that streams live audio directly from the internet over Wi-Fi.

```
+--------------------------+                         +--------------------------+
|  Bluetooth Speaker       |                         |  ESP32-S3 Board          |
|                          |     USB-A to USB-C      |                          |
|  [USB-A Port] <==========|========================>| [Native USB-C / OTG Port]|
|  (Flash Drive Input)     |                         |                          |
+--------------------------+                         +--------------------------+
```

---

## 1. Physical Connections
- **Cable**: Use a standard USB-C to USB-A cable (or USB-C to USB-A adapter).
- **Speaker Side**: Plug the USB-A end into the USB flash drive slot on your speaker.
- **ESP32-S3 Side**: Plug the USB-C end into the **Native USB / OTG** port on the ESP32-S3 (usually marked `USB` or `OTG`, NOT the secondary `UART/COM` port used only for serial debugging).

### ESP32-S3 Pin Mapping for Native USB OTG:
| ESP32-S3 Native Signal | Default GPIO | Notes |
|---|---|---|
| **USB D- (Data Minus)** | GPIO 19 | Connected internally on ESP32-S3 USB port |
| **USB D+ (Data Plus)**  | GPIO 20 | Connected internally on ESP32-S3 USB port |
| **VBUS (+5V Power)**    | 5V / VBUS | Powered directly from speaker's USB port |
| **GND (Ground)**        | GND | Common Ground |

---

## 2. Power Considerations
- The USB-A port on most Bluetooth speakers provides 5V at 500mA - 1A, which powers the ESP32-S3 directly through the same cable.
- No external battery or power supply is required when connected to the speaker!

---

## 3. How Playback Works
1. Turn on the speaker and switch it to **USB Mode** (or plug the ESP in; many speakers auto-switch to USB mode when a drive is inserted).
2. The speaker detects a USB Mass Storage device (`ESPMUSIC`).
3. When you choose a song or playlist in the ESP Music Android App, the ESP32-S3 starts streaming the audio data over Wi-Fi and feeds the bytes directly into the virtual MP3 stream file read by the speaker.
