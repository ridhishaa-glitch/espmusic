#include "../include/usb_msc.h"
#include "../include/virtual_fat.h"
#include "../include/config.h"
#include "Adafruit_TinyUSB.h"

// TinyUSB MSC Object
static Adafruit_USBD_MSC usb_msc;

// Vendor & Product Strings for Speaker Display
static const char* MSC_VENDOR_ID  = "ESPMUSIC";
static const char* MSC_PRODUCT_ID = "Smart Audio Mod";
static const char* MSC_PRODUCT_REV = "1.0 ";

static int32_t msc_read_cb(uint32_t lba, void* buffer, uint32_t bufsize) {
    return virtualFAT.readSector(lba, (uint8_t*)buffer, bufsize);
}

static int32_t msc_write_cb(uint32_t lba, uint8_t* buffer, uint32_t bufsize) {
    // Read-only virtual media
    return -1;
}

static void msc_flush_cb(void) {
    // No-op for read-only
}

void initUsbMsc() {
    Serial.println("[USB] Initializing TinyUSB Mass Storage Class...");

    usb_msc.setID(MSC_VENDOR_ID, MSC_PRODUCT_ID, MSC_PRODUCT_REV);
    usb_msc.setCapacity(1024 * 1024, DISK_BLOCK_SIZE); // 512 MB virtual disk
    usb_msc.setReadWriteCallback(msc_read_cb, msc_write_cb, msc_flush_cb);
    usb_msc.setUnitReady(true);

    usb_msc.begin();
    Serial.println("[USB] TinyUSB Mass Storage Ready.");
}

void usbMscSoftReconnect() {
    // Trigger soft USB re-enumeration by resetting unit ready or re-mounting
    Serial.println("[USB] Soft USB reconnect triggered for new track...");
    usb_msc.setUnitReady(false);
    delay(100);
    virtualFAT.resetPlaybackPosition();
    usb_msc.setUnitReady(true);
}
