#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "poi_beacon_protocol.h"

static void test_valid_pdu_matches_p17_and_shared_fixtures(void) {
    poi_beacon_runtime_config_t cfg = {
        .protocol_version = POI_BEACON_PROTOCOL_VERSION,
        .flags = POI_BEACON_FLAG_PROXIMITY_ACTIVE | POI_BEACON_FLAG_USB_POWERED,
        .advertising_interval_ms = 200,
        .tx_power_dbm = 3,
    };
    assert(poi_beacon_parse_hex_id("5649450000000001", cfg.beacon_id) == POI_BEACON_OK);

    uint8_t service_data[POI_BEACON_SERVICE_DATA_SIZE];
    assert(poi_beacon_build_service_data(&cfg, service_data) == POI_BEACON_OK);

    const uint8_t expected_sd[POI_BEACON_SERVICE_DATA_SIZE] = {
        0x01, 0x03, 0x56, 0x49, 0x45, 0x00, 0x00, 0x00, 0x00, 0x01
    };
    assert(memcmp(service_data, expected_sd, sizeof(expected_sd)) == 0);

    uint8_t pdu[POI_BEACON_ADV_PDU_SIZE];
    size_t pdu_len = 0;
    assert(poi_beacon_build_adv_pdu(&cfg, pdu, &pdu_len) == POI_BEACON_OK);
    assert(pdu_len == 31);

    /* AD1: Flags */
    assert(pdu[0] == 0x02 && pdu[1] == 0x01 && pdu[2] == 0x06);
    /* AD2: 128-bit Service Data */
    assert(pdu[3] == 0x1B && pdu[4] == 0x21);
    assert(memcmp(&pdu[5], POI_BEACON_SERVICE_UUID_LE, 16) == 0);
    assert(memcmp(&pdu[21], expected_sd, 10) == 0);
}

static void test_rejects_invalid_beacon_ids_and_hex(void) {
    uint8_t out[POI_BEACON_ID_SIZE];
    assert(poi_beacon_parse_hex_id("short", out) == POI_BEACON_ERR_INVALID_HEX);
    assert(poi_beacon_parse_hex_id("zzzzzzzzzzzzzzzz", out) == POI_BEACON_ERR_INVALID_HEX);
    assert(poi_beacon_parse_hex_id("0000000000000000", out) == POI_BEACON_ERR_INVALID_ID);
    assert(poi_beacon_parse_hex_id("ffffffffffffffff", out) == POI_BEACON_ERR_INVALID_ID);
}

static void test_rejects_invalid_version_flags_interval_tx_power(void) {
    poi_beacon_runtime_config_t base = {
        .protocol_version = POI_BEACON_PROTOCOL_VERSION,
        .flags = POI_BEACON_FLAG_PROXIMITY_ACTIVE,
        .advertising_interval_ms = 200,
        .tx_power_dbm = 3,
    };
    assert(poi_beacon_parse_hex_id("a1b2c3d4e5f60708", base.beacon_id) == POI_BEACON_OK);
    assert(poi_beacon_validate_config(&base) == POI_BEACON_OK);

    poi_beacon_runtime_config_t bad_ver = base;
    bad_ver.protocol_version = 2;
    assert(poi_beacon_validate_config(&bad_ver) == POI_BEACON_ERR_INVALID_VERSION);

    poi_beacon_runtime_config_t bad_flags = base;
    bad_flags.flags = 0x80;
    assert(poi_beacon_validate_config(&bad_flags) == POI_BEACON_ERR_INVALID_FLAGS);

    poi_beacon_runtime_config_t bad_interval = base;
    bad_interval.advertising_interval_ms = 10;
    assert(poi_beacon_validate_config(&bad_interval) == POI_BEACON_ERR_INVALID_INTERVAL);

    poi_beacon_runtime_config_t bad_tx = base;
    bad_tx.tx_power_dbm = 20;
    assert(poi_beacon_validate_config(&bad_tx) == POI_BEACON_ERR_INVALID_TX_POWER);
}

static void test_formats_hex_and_converts_ble_units(void) {
    const uint8_t id[POI_BEACON_ID_SIZE] = {
        0xA1, 0xB2, 0xC3, 0xD4, 0xE5, 0xF6, 0x07, 0x08
    };
    char hex[17];
    assert(poi_beacon_format_hex_id(id, hex, sizeof(hex)) == POI_BEACON_OK);
    assert(strcmp(hex, "a1b2c3d4e5f60708") == 0);
    assert(poi_beacon_ms_to_ble_units(200) == 320);
}

int main(void) {
    test_valid_pdu_matches_p17_and_shared_fixtures();
    test_rejects_invalid_beacon_ids_and_hex();
    test_rejects_invalid_version_flags_interval_tx_power();
    test_formats_hex_and_converts_ble_units();
    printf("All POI-BEACON protocol C unit tests passed!\n");
    return 0;
}

