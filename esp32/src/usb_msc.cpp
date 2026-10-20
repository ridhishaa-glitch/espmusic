#include "usb_msc.h"
#include "virtual_fat.h"
#include "config.h"
#include "USB.h"
#include "USBMSC.h"

#if ARDUINO_USB_MODE
#warning This sketch should be used when USB is in OTG mode (ARDUINO_USB_MODE=0)
void initUsbMsc() {}
void usbMscSoftReconnect() {}
#else

static USBMSC msc;

static int32_t handle_msc_read(uint32_t lba, uint32_t offset, void* buffer, uint32_t bufsize) {
    return virtualFAT.readSector(lba, (uint8_t*)buffer, bufsize);
}

static int32_t handle_msc_write(uint32_t lba, uint32_t offset, uint8_t* buffer, uint32_t bufsize) {
    // Read-only virtual media
    return -1;
}

static bool handle_msc_start_stop(uint8_t power_condition, bool start, bool load_eject) {
    return true;
}

void initUsbMsc() {
    Serial.println("[USB] Initializing Native USB Mass Storage Class...");

    msc.vendorID("ESPMUSIC");
    msc.productID("Smart Audio Mod");
    msc.productRevision("1.0");
    msc.onRead(handle_msc_read);
    msc.onWrite(handle_msc_write);
    msc.onStartStop(handle_msc_start_stop);
    msc.mediaPresent(true);

    // 512 MB virtual drive (1,048,576 sectors of 512 bytes)
    msc.begin(1024 * 1024, DISK_BLOCK_SIZE);
    USB.begin();

    Serial.println("[USB] Native USB MSC Initialized.");
}

void usbMscSoftReconnect() {
    Serial.println("[USB] Soft media reset for new track...");
    msc.mediaPresent(false);
    delay(100);
    virtualFAT.resetPlaybackPosition();
    msc.mediaPresent(true);
}

#endif
