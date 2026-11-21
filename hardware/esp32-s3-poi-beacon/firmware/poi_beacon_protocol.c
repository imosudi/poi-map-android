#include "poi_beacon_protocol.h"

#include <ctype.h>
#include <string.h>

const uint8_t POI_BEACON_SERVICE_UUID_LE[POI_BEACON_SERVICE_UUID_SIZE] = {
    0x87, 0xDC, 0xA8, 0xBD, 0x29, 0xEB, 0x65, 0x9E,
    0x46, 0x48, 0x38, 0x00, 0x13, 0xCA, 0x28, 0x4A
};

static int hex_nibble(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return 10 + (c - 'a');
    if (c >= 'A' && c <= 'F') return 10 + (c - 'A');
    return -1;
}

static bool is_all_same_byte(const uint8_t *buf, size_t len, uint8_t value) {
    for (size_t i = 0; i < len; i++) {
        if (buf[i] != value) return false;
    }
    return true;
}

poi_beacon_status_t poi_beacon_parse_hex_id(
    const char *hex_str,
    uint8_t out_id[POI_BEACON_ID_SIZE]
) {
    if (hex_str == NULL || out_id == NULL) {
        return POI_BEACON_ERR_NULL_ARG;
    }
    if (strlen(hex_str) != POI_BEACON_ID_SIZE * 2U) {
        return POI_BEACON_ERR_INVALID_HEX;
    }

    uint8_t tmp[POI_BEACON_ID_SIZE];
    for (size_t i = 0; i < POI_BEACON_ID_SIZE; i++) {
        int hi = hex_nibble(hex_str[i * 2U]);
        int lo = hex_nibble(hex_str[i * 2U + 1U]);
        if (hi < 0 || lo < 0) {
            return POI_BEACON_ERR_INVALID_HEX;
        }
        tmp[i] = (uint8_t)((hi << 4) | lo);
    }

    if (is_all_same_byte(tmp, POI_BEACON_ID_SIZE, 0x00U) ||
        is_all_same_byte(tmp, POI_BEACON_ID_SIZE, 0xFFU)) {
        return POI_BEACON_ERR_INVALID_ID;
    }

    memcpy(out_id, tmp, POI_BEACON_ID_SIZE);
    return POI_BEACON_OK;
}

poi_beacon_status_t poi_beacon_format_hex_id(
    const uint8_t beacon_id[POI_BEACON_ID_SIZE],
    char *out_hex,
    size_t out_hex_size
) {
    static const char HEX_DIGITS[] = "0123456789abcdef";
    if (beacon_id == NULL || out_hex == NULL) {
        return POI_BEACON_ERR_NULL_ARG;
    }
    if (out_hex_size < (POI_BEACON_ID_SIZE * 2U) + 1U) {
        return POI_BEACON_ERR_BUFFER_TOO_SMALL;
    }
    for (size_t i = 0; i < POI_BEACON_ID_SIZE; i++) {
        out_hex[i * 2U] = HEX_DIGITS[(beacon_id[i] >> 4) & 0x0FU];
        out_hex[i * 2U + 1U] = HEX_DIGITS[beacon_id[i] & 0x0FU];
    }
    out_hex[POI_BEACON_ID_SIZE * 2U] = '\0';
    return POI_BEACON_OK;
}

poi_beacon_status_t poi_beacon_validate_config(
    const poi_beacon_runtime_config_t *config
) {
    if (config == NULL) {
        return POI_BEACON_ERR_NULL_ARG;
    }
    if (config->protocol_version != POI_BEACON_PROTOCOL_VERSION) {
        return POI_BEACON_ERR_INVALID_VERSION;
    }
    if ((config->flags & ~POI_BEACON_FLAGS_VALID_MASK) != 0U) {
        return POI_BEACON_ERR_INVALID_FLAGS;
    }
    if (is_all_same_byte(config->beacon_id, POI_BEACON_ID_SIZE, 0x00U) ||
        is_all_same_byte(config->beacon_id, POI_BEACON_ID_SIZE, 0xFFU)) {
        return POI_BEACON_ERR_INVALID_ID;
    }
    if (config->advertising_interval_ms < POI_BEACON_MIN_ADV_INTERVAL_MS ||
        config->advertising_interval_ms > POI_BEACON_MAX_ADV_INTERVAL_MS) {
        return POI_BEACON_ERR_INVALID_INTERVAL;
    }
    if (config->tx_power_dbm < POI_BEACON_MIN_TX_POWER_DBM ||
        config->tx_power_dbm > POI_BEACON_MAX_TX_POWER_DBM) {
        return POI_BEACON_ERR_INVALID_TX_POWER;
    }
    return POI_BEACON_OK;
}

poi_beacon_status_t poi_beacon_build_service_data(
    const poi_beacon_runtime_config_t *config,
    uint8_t out_service_data[POI_BEACON_SERVICE_DATA_SIZE]
) {
    if (config == NULL || out_service_data == NULL) {
        return POI_BEACON_ERR_NULL_ARG;
    }
    poi_beacon_status_t status = poi_beacon_validate_config(config);
    if (status != POI_BEACON_OK) {
        return status;
    }

    out_service_data[0] = config->protocol_version;
    out_service_data[1] = config->flags;
    memcpy(&out_service_data[2], config->beacon_id, POI_BEACON_ID_SIZE);
    return POI_BEACON_OK;
}

poi_beacon_status_t poi_beacon_build_adv_pdu(
    const poi_beacon_runtime_config_t *config,
    uint8_t out_pdu[POI_BEACON_ADV_PDU_SIZE],
    size_t *out_len
) {
    if (config == NULL || out_pdu == NULL || out_len == NULL) {
        return POI_BEACON_ERR_NULL_ARG;
    }

    uint8_t service_data[POI_BEACON_SERVICE_DATA_SIZE];
    poi_beacon_status_t status = poi_beacon_build_service_data(config, service_data);
    if (status != POI_BEACON_OK) {
        return status;
    }

    /* AD Structure 1: Flags (3 bytes) */
    out_pdu[0] = 0x02U;
    out_pdu[1] = 0x01U; /* AD Type: Flags */
    out_pdu[2] = 0x06U; /* LE General Discoverable | BR/EDR Not Supported */

    /* AD Structure 2: Service Data - 128-bit UUID (28 bytes) */
    out_pdu[3] = (uint8_t)(1U + POI_BEACON_SERVICE_UUID_SIZE + POI_BEACON_SERVICE_DATA_SIZE); /* 0x1B */
    out_pdu[4] = 0x21U; /* AD Type: Service Data - 128-bit UUID */
    memcpy(&out_pdu[5], POI_BEACON_SERVICE_UUID_LE, POI_BEACON_SERVICE_UUID_SIZE);
    memcpy(&out_pdu[21], service_data, POI_BEACON_SERVICE_DATA_SIZE);

    *out_len = POI_BEACON_ADV_PDU_SIZE;
    return POI_BEACON_OK;
}

uint16_t poi_beacon_ms_to_ble_units(uint16_t interval_ms) {
    uint32_t units = ((uint32_t)interval_ms * 1000U + 312U) / 625U;
    if (units < 0x0020U) units = 0x0020U;
    if (units > 0x4000U) units = 0x4000U;
    return (uint16_t)units;
}

const char *poi_beacon_status_str(poi_beacon_status_t status) {
    switch (status) {
        case POI_BEACON_OK: return "OK";
        case POI_BEACON_ERR_NULL_ARG: return "NULL_ARG";
        case POI_BEACON_ERR_INVALID_HEX: return "INVALID_HEX";
        case POI_BEACON_ERR_INVALID_ID: return "INVALID_BEACON_ID";
        case POI_BEACON_ERR_INVALID_VERSION: return "INVALID_VERSION";
        case POI_BEACON_ERR_INVALID_FLAGS: return "INVALID_FLAGS";
        case POI_BEACON_ERR_INVALID_INTERVAL: return "INVALID_INTERVAL";
        case POI_BEACON_ERR_INVALID_TX_POWER: return "INVALID_TX_POWER";
        case POI_BEACON_ERR_BUFFER_TOO_SMALL: return "BUFFER_TOO_SMALL";
        default: return "UNKNOWN";
    }
}

