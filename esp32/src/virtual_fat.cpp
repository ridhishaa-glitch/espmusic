#include "../include/virtual_fat.h"
#include "../include/config.h"

// FAT16 Geometry Parameters
#define SECTOR_SIZE             512
#define SECTORS_PER_CLUSTER     64     // 32 KB clusters
#define RESERVED_SECTORS        1      // Boot sector
#define NUM_FATS                2
#define ROOT_ENTRIES            512    // 32 sectors of directory entries
#define ROOT_DIR_SECTORS        ((ROOT_ENTRIES * 32) / SECTOR_SIZE) // 32
#define SECTORS_PER_FAT         256
#define TOTAL_SECTORS           (1024 * 1024) // 512 MB virtual drive

#define FAT1_START_SECTOR       RESERVED_SECTORS                                  // 1
#define FAT2_START_SECTOR       (FAT1_START_SECTOR + SECTORS_PER_FAT)             // 257
#define ROOT_DIR_START_SECTOR   (FAT2_START_SECTOR + SECTORS_PER_FAT)             // 513
#define DATA_START_SECTOR       (ROOT_DIR_START_SECTOR + ROOT_DIR_SECTORS)        // 545

VirtualFAT virtualFAT;

VirtualFAT::VirtualFAT() : ringBuffer(nullptr), currentStreamOffset(0) {}

void VirtualFAT::setRingBuffer(AudioRingBuffer* rb) {
    ringBuffer = rb;
}

void VirtualFAT::resetPlaybackPosition() {
    currentStreamOffset = 0;
}

int32_t VirtualFAT::readSector(uint32_t lba, uint8_t* buffer, uint32_t bufsize) {
    if (bufsize < SECTOR_SIZE) return -1;
    memset(buffer, 0, SECTOR_SIZE);

    // 1. Boot Sector (LBA 0)
    if (lba == 0) {
        // Jump boot code
        buffer[0] = 0xEB; buffer[1] = 0x3C; buffer[2] = 0x90;
        // OEM Name
        memcpy(&buffer[3], "MSDOS5.0", 8);
        // Bytes per sector (512)
        buffer[11] = 0x00; buffer[12] = 0x02;
        // Sectors per cluster (64)
        buffer[13] = SECTORS_PER_CLUSTER;
        // Reserved sectors (1)
        buffer[14] = (uint8_t)(RESERVED_SECTORS & 0xFF);
        buffer[15] = (uint8_t)((RESERVED_SECTORS >> 8) & 0xFF);
        // Number of FATs (2)
        buffer[16] = NUM_FATS;
        // Root entries (512)
        buffer[17] = (uint8_t)(ROOT_ENTRIES & 0xFF);
        buffer[18] = (uint8_t)((ROOT_ENTRIES >> 8) & 0xFF);
        // Total sectors 16 (0, using 32-bit count)
        buffer[19] = 0; buffer[20] = 0;
        // Media descriptor (0xF8 = Hard disk / flash drive)
        buffer[21] = 0xF8;
        // Sectors per FAT (256)
        buffer[22] = (uint8_t)(SECTORS_PER_FAT & 0xFF);
        buffer[23] = (uint8_t)((SECTORS_PER_FAT >> 8) & 0xFF);
        // Sectors per track (63)
        buffer[24] = 63; buffer[25] = 0;
        // Number of heads (255)
        buffer[26] = 255; buffer[27] = 0;
        // Hidden sectors (0)
        buffer[28] = 0; buffer[29] = 0; buffer[30] = 0; buffer[31] = 0;
        // Total sectors 32
        uint32_t totalSec = TOTAL_SECTORS;
        memcpy(&buffer[32], &totalSec, 4);
        // Drive number
        buffer[36] = 0x80;
        // Extended boot signature
        buffer[38] = 0x29;
        // Volume ID
        uint32_t volId = 0x12345678;
        memcpy(&buffer[39], &volId, 4);
        // Volume label
        memcpy(&buffer[43], "ESPMUSIC   ", 11);
        // File system type
        memcpy(&buffer[54], "FAT16   ", 8);
        // Boot sector signature
        buffer[510] = 0x55;
        buffer[511] = 0xAA;
        return SECTOR_SIZE;
    }

    // 2. FAT Tables (FAT1 or FAT2)
    if ((lba >= FAT1_START_SECTOR && lba < FAT1_START_SECTOR + SECTORS_PER_FAT) ||
        (lba >= FAT2_START_SECTOR && lba < FAT2_START_SECTOR + SECTORS_PER_FAT)) {

        uint32_t fatSector = (lba < FAT2_START_SECTOR)
            ? (lba - FAT1_START_SECTOR)
            : (lba - FAT2_START_SECTOR);

        uint16_t* fatEntries = (uint16_t*)buffer;
        uint32_t startCluster = fatSector * (SECTOR_SIZE / 2); // 256 entries per sector

        for (uint32_t i = 0; i < (SECTOR_SIZE / 2); i++) {
            uint32_t cluster = startCluster + i;
            if (cluster == 0) {
                fatEntries[i] = 0xFFF8; // Media descriptor in FAT
            } else if (cluster == 1) {
                fatEntries[i] = 0xFFFF; // End of cluster marker
            } else {
                // Audio file cluster chain: continuous pointing to next cluster
                // Maximum virtual file clusters: (500MB / 32KB) = 16,000 clusters
                if (cluster < 16000) {
                    fatEntries[i] = (uint16_t)(cluster + 1);
                } else if (cluster == 16000) {
                    fatEntries[i] = 0xFFFF; // End of chain
                } else {
                    fatEntries[i] = 0x0000; // Free cluster
                }
            }
        }
        return SECTOR_SIZE;
    }

    // 3. Root Directory
    if (lba >= ROOT_DIR_START_SECTOR && lba < DATA_START_SECTOR) {
        uint32_t dirSector = lba - ROOT_DIR_START_SECTOR;

        // Entry 0 & 1 reside in the very first directory sector
        if (dirSector == 0) {
            // Entry 0: Volume Label
            uint8_t* entry0 = &buffer[0];
            memcpy(&entry0[0], "ESPMUSIC   ", 11);
            entry0[11] = 0x08; // Volume ID attribute

            // Entry 1: Virtual Stream File "STREAM  MP3"
            uint8_t* entry1 = &buffer[32];
            memcpy(&entry1[0], "STREAM  MP3", 11);
            entry1[11] = 0x20; // Archive attribute
            // Time & Date: 2026-01-01 12:00:00
            entry1[22] = 0x00; entry1[23] = 0x60; // 12:00
            entry1[24] = 0x21; entry1[25] = 0x5C; // 2026-01-01
            // First cluster: Cluster 2
            entry1[26] = 0x02; entry1[27] = 0x00;
            // File size: 500 MB (0x1F400000)
            uint32_t fileSize = VIRTUAL_FILE_SIZE;
            memcpy(&entry1[28], &fileSize, 4);
        }
        return SECTOR_SIZE;
    }

    // 4. Data Clusters (Audio Stream Bytes)
    if (lba >= DATA_START_SECTOR) {
        if (ringBuffer != nullptr && ringBuffer->available() > 0) {
            size_t bytesRead = ringBuffer->read(buffer, SECTOR_SIZE);
            if (bytesRead < SECTOR_SIZE) {
                // Pad remaining sector with MP3 frame silence or zeroes
                memset(&buffer[bytesRead], 0, SECTOR_SIZE - bytesRead);
            }
        } else {
            // No audio data buffered yet: output silence zeroes so host doesn't time out
            memset(buffer, 0, SECTOR_SIZE);
        }
        return SECTOR_SIZE;
    }

    return SECTOR_SIZE;
}
