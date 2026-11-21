#ifndef POI_BEACON_PROTOCOL_H
#define POI_BEACON_PROTOCOL_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "poi_beacon_config.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    POI_BEACON_OK = 0,
    POI_BEACON_ERR_NULL_ARG = -1,
    POI_BEACON_ERR_INVALID_HEX = -2,
    POI_BEACON_ERR_INVALID_ID = -3,
    POI_BEACON_ERR_INVALID_VERSION = -4,
    POI_BEACON_ERR_INVALID_FLAGS = -5,
    POI_BEACON_ERR_INVALID_INTERVAL = -6,
    POI_BEACON_ERR_INVALID_TX_POWER = -7,
    POI_BEACON_ERR_BUFFER_TOO_SMALL = -8
} poi_beacon_status_t;

typedef struct {
    uint8_t protocol_version;
    uint8_t flags;
    uint8_t beacon_id[POI_BEACON_ID_SIZE];
    uint16_t advertising_interval_ms;
    int8_t tx_power_dbm;
} poi_beacon_runtime_config_t;

/* Canonical UUID: 4a28ca13-0038-4846-9e65-eb29bda8dc87 (little-endian wire order). */
extern const uint8_t POI_BEACON_SERVICE_UUID_LE[POI_BEACON_SERVICE_UUID_SIZE];

/* Parses a 16-character hex string into an 8-byte big-endian beacon ID. */
poi_beacon_status_t poi_beacon_parse_hex_id(
    const char *hex_str,
    uint8_t out_id[POI_BEACON_ID_SIZE]
);

/* Formats an 8-byte beacon ID as a 16-character lowercase hex string. */
poi_beacon_status_t poi_beacon_format_hex_id(
    const uint8_t beacon_id[POI_BEACON_ID_SIZE],
    char *out_hex,
    size_t out_hex_size
);

/* Validates protocol version, flags, non-sentinel beacon ID, interval, and Tx power. */
poi_beacon_status_t poi_beacon_validate_config(
    const poi_beacon_runtime_config_t *config
);

/* Encodes the 10-byte POI-BEACON v1 Service Data payload. */
poi_beacon_status_t poi_beacon_build_service_data(
    const poi_beacon_runtime_config_t *config,
    uint8_t out_service_data[POI_BEACON_SERVICE_DATA_SIZE]
);

/* Encodes the complete 31-byte legacy BLE advertising PDU (Flags + Service Data). */
poi_beacon_status_t poi_beacon_build_adv_pdu(
    const poi_beacon_runtime_config_t *config,
    uint8_t out_pdu[POI_BEACON_ADV_PDU_SIZE],
    size_t *out_len
);

/* Converts advertising interval in ms to BLE 0.625 ms units. */
uint16_t poi_beacon_ms_to_ble_units(uint16_t interval_ms);

/* Returns human-readable description for a protocol status code. */
const char *poi_beacon_status_str(poi_beacon_status_t status);

#ifdef __cplusplus
}
#endif

#endif /* POI_BEACON_PROTOCOL_H */

