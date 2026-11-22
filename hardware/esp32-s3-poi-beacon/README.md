# ESP32-S3-DevKitC-1 POI-BEACON Firmware

Production-structured **ESP-IDF / NimBLE** firmware implementing the custom **POI-BEACON v1** BLE advertisement protocol for **Vienna POI Explorer** (`at.fhtw.poi_map_android`).

---

## 1. Verified Hardware Baseline

Inspected on the connected physical unit via `esptool.py --port /dev/ttyUSB0 flash_id`:

| Property | Observed Value |
| :--- | :--- |
| **Board** | Espressif `ESP32-S3-DevKitC-1` |
| **Chip** | `ESP32-S3 (QFN56) (revision v0.2)` |
| **Crystal** | `40 MHz` |
| **Flash** | `8 MB` Quad SPI (`3.3 V`, Manufacturer `0x20`, Device `0x4017`) |
| **PSRAM** | `Embedded PSRAM 8MB (AP_3v3)` (not required by beacon firmware) |
| **MAC Address** | `94:a9:90:1c:78:14` |
| **Serial Port** | `/dev/ttyUSB0` (`115200` baud) |
| **Power Supply** | USB (`5 V`) |

> [!NOTE]
> `sdkconfig.defaults` and `platformio.ini` target the verified `8MB` Quad flash baseline without assuming PSRAM, keeping memory usage minimal.

---

## 2. Project Structure

```text
hardware/esp32-s3-poi-beacon/
├── CMakeLists.txt
├── platformio.ini
├── sdkconfig.defaults
├── README.md
├── configuration/
│   └── beacon_config.sample.json
├── firmware/
│   ├── CMakeLists.txt
│   ├── Kconfig.projbuild
│   ├── main.c
│   └── poi_beacon_protocol.c
├── include/
│   ├── poi_beacon_config.h
│   └── poi_beacon_protocol.h
└── test/
    └── test_poi_beacon_protocol.c
```

---

## 3. Building and Flashing

### Option A: PlatformIO (`ESP-IDF` 5.5.0)

```bash
cd hardware/esp32-s3-poi-beacon
pio run
pio run --target upload --upload-port /dev/ttyUSB0
pio device monitor --port /dev/ttyUSB0 --baud 115200
```

### Option B: Native ESP-IDF (`idf.py`)

```bash
cd hardware/esp32-s3-poi-beacon
idf.py set-target esp32s3
idf.py build
idf.py -p /dev/ttyUSB0 flash monitor
```

---

## 4. Configuration & Provisioning

1. **Sample Configuration**: See `configuration/beacon_config.sample.json` for reference fields (`beaconId`, `protocolVersion`, `serviceUuid`, `advertisingIntervalMs`, `txPowerDbm`, `firmwareVersion`).
2. **NVS Persistence**: On first boot, the firmware persists the active 8-byte `beacon_id` in NVS namespace `poi_beacon` so it remains stable across reboots.
3. **Customising Beacon ID**: Override `CONFIG_POI_BEACON_DEFAULT_ID_HEX` via `idf.py menuconfig` (or `sdkconfig.defaults` locally) before flashing a unit, or provision NVS directly. Invalid or sentinel IDs (`0000000000000000`, `ffffffffffffffff`) are rejected safely without starting advertising.

---

## 5. Expected Serial Output

```text
I (xxx) POI_BEACON: Booting Vienna POI-BEACON firmware v1.0.0
I (xxx) POI_BEACON: Advertising active | fw=1.0.0 | proto=v1 | flags=0x03 | beaconId=5649450000000001 | interval=200ms | tx=3dBm
```

---

## 6. Protocol Unit Tests (Host C)

```bash
cd hardware/esp32-s3-poi-beacon
gcc -std=c99 -Wall -Wextra -Werror -Iinclude firmware/poi_beacon_protocol.c test/test_poi_beacon_protocol.c -o /tmp/test_poi_beacon_protocol && /tmp/test_poi_beacon_protocol
```

---

## 7. Physical Validation & Troubleshooting

### BLE Scanner Verification
1. Open **nRF Connect** (or **Vienna POI Explorer** on Android).
2. Confirm the advertisement contains:
   - **Flags (`0x01`)**: `0x06`
   - **Service Data - 128-bit UUID (`0x21`)**: UUID `4a28ca13-0038-4846-9e65-eb29bda8dc87`
   - **Payload (10 bytes)**: `01 03 56 49 45 00 00 00 00 01`
3. In **Vienna POI Explorer**, tap **Scan** on **Explore** or **Map** and verify `Ankeruhr` (`SEHENSWUERDIGOGD.643871`) is detected via `BeaconRegistry`.

### Troubleshooting
- **Serial port busy or permission denied**: Ensure no other monitor holds `/dev/ttyUSB0` and the current account belongs to `dialout`.
- **Upload fails to sync**: Hold the `BOOT` button on the `ESP32-S3-DevKitC-1`, press `RST`, then release `BOOT` and retry upload.
- **Not visible in Android app**: Verify Bluetooth is enabled, `BLUETOOTH_SCAN` permission is granted, and the `beaconId` is enabled in `assets/config/beacon_registry.json`.

