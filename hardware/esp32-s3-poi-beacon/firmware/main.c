#include <stdio.h>
#include <string.h>

#include "driver/rmt_tx.h"
#include "esp_bt.h"
#include "esp_err.h"
#include "esp_log.h"
#include "esp_system.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "host/ble_hs.h"
#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"
#include "nvs.h"
#include "nvs_flash.h"

#include "poi_beacon_config.h"
#include "poi_beacon_protocol.h"

static const char *TAG = "POI_BEACON";

static poi_beacon_runtime_config_t s_beacon_config;
static uint8_t s_own_addr_type = BLE_OWN_ADDR_PUBLIC;
static bool s_advertising_active = false;
typedef struct {
  rmt_channel_handle_t chan;
  rmt_encoder_handle_t encoder;
} status_led_output_t;

static status_led_output_t s_leds[2] = {{NULL, NULL}, {NULL, NULL}};
static uint8_t s_led_grb[3] = {0, 0, 0};

static void status_led_init_pin(status_led_output_t *out, int gpio_num) {
  if (gpio_num < 0) {
    return;
  }
  rmt_tx_channel_config_t tx_cfg = {
      .clk_src = RMT_CLK_SRC_DEFAULT,
      .gpio_num = gpio_num,
      .mem_block_symbols = 64,
      .resolution_hz = 10000000, /* 10 MHz: 100 ns per tick */
      .trans_queue_depth = 1,
  };
  if (rmt_new_tx_channel(&tx_cfg, &out->chan) != ESP_OK) {
    ESP_LOGW(TAG, "Unable to initialise status LED RMT channel on GPIO %d",
             gpio_num);
    out->chan = NULL;
    return;
  }

  rmt_bytes_encoder_config_t enc_cfg = {
      .bit0 =
          {
              .level0 = 1,
              .duration0 = 3, /* 300 ns */
              .level1 = 0,
              .duration1 = 9, /* 900 ns */
          },
      .bit1 =
          {
              .level0 = 1,
              .duration0 = 9, /* 900 ns */
              .level1 = 0,
              .duration1 = 3, /* 300 ns */
          },
      .flags.msb_first = 1,
  };
  if (rmt_new_bytes_encoder(&enc_cfg, &out->encoder) != ESP_OK) {
    ESP_LOGW(TAG, "Unable to create status LED RMT encoder on GPIO %d",
             gpio_num);
    rmt_del_channel(out->chan);
    out->chan = NULL;
    return;
  }

  if (rmt_enable(out->chan) != ESP_OK) {
    ESP_LOGW(TAG, "Unable to enable status LED RMT channel on GPIO %d",
             gpio_num);
    rmt_del_encoder(out->encoder);
    rmt_del_channel(out->chan);
    out->encoder = NULL;
    out->chan = NULL;
  }
}

static void status_led_init(void) {
  status_led_init_pin(&s_leds[0], CONFIG_POI_BEACON_STATUS_LED_GPIO);
  if (CONFIG_POI_BEACON_STATUS_LED_ALT_GPIO !=
      CONFIG_POI_BEACON_STATUS_LED_GPIO) {
    status_led_init_pin(&s_leds[1], CONFIG_POI_BEACON_STATUS_LED_ALT_GPIO);
  }
}

static void status_led_set_rgb(uint8_t r, uint8_t g, uint8_t b) {
  /* WS2812 expects GRB byte order. */
  s_led_grb[0] = g;
  s_led_grb[1] = r;
  s_led_grb[2] = b;
  rmt_transmit_config_t tx_config = {
      .loop_count = 0,
      .flags.eot_level = 0,
  };
  for (size_t i = 0; i < sizeof(s_leds) / sizeof(s_leds[0]); i++) {
    if (s_leds[i].chan == NULL || s_leds[i].encoder == NULL) {
      continue;
    }
    if (rmt_transmit(s_leds[i].chan, s_leds[i].encoder, s_led_grb,
                     sizeof(s_led_grb), &tx_config) == ESP_OK) {
      rmt_tx_wait_all_done(s_leds[i].chan, 200);
    }
  }
}

static esp_power_level_t map_tx_power_dbm(int8_t dbm) {
  if (dbm <= -12)
    return ESP_PWR_LVL_N12;
  if (dbm <= -9)
    return ESP_PWR_LVL_N9;
  if (dbm <= -6)
    return ESP_PWR_LVL_N6;
  if (dbm <= -3)
    return ESP_PWR_LVL_N3;
  if (dbm <= 0)
    return ESP_PWR_LVL_N0;
  if (dbm <= 3)
    return ESP_PWR_LVL_P3;
  if (dbm <= 6)
    return ESP_PWR_LVL_P6;
  return ESP_PWR_LVL_P9;
}

static void load_config_with_nvs_fallback(void) {
  memset(&s_beacon_config, 0, sizeof(s_beacon_config));
  s_beacon_config.protocol_version = POI_BEACON_PROTOCOL_VERSION;
  s_beacon_config.flags = POI_BEACON_FLAG_PROXIMITY_ACTIVE;
#if CONFIG_POI_BEACON_USB_POWERED
  s_beacon_config.flags |= POI_BEACON_FLAG_USB_POWERED;
#endif
  s_beacon_config.advertising_interval_ms = CONFIG_POI_BEACON_ADV_INTERVAL_MS;
  s_beacon_config.tx_power_dbm = (int8_t)CONFIG_POI_BEACON_TX_POWER_DBM;

  poi_beacon_status_t parse_status = poi_beacon_parse_hex_id(
      CONFIG_POI_BEACON_DEFAULT_ID_HEX, s_beacon_config.beacon_id);
  if (parse_status != POI_BEACON_OK) {
    ESP_LOGE(TAG,
             "Invalid Kconfig fallback beacon ID (%s); advertising disabled "
             "until valid ID is provisioned.",
             poi_beacon_status_str(parse_status));
  }

  nvs_handle_t nvs = 0;
  esp_err_t err = nvs_open(POI_BEACON_NVS_NAMESPACE, NVS_READWRITE, &nvs);
  if (err != ESP_OK) {
    ESP_LOGW(TAG, "Unable to open NVS namespace (%s); using build defaults",
             esp_err_to_name(err));
    return;
  }

  uint8_t stored_id[POI_BEACON_ID_SIZE];
  size_t id_len = sizeof(stored_id);
  if (nvs_get_blob(nvs, POI_BEACON_NVS_KEY_ID, stored_id, &id_len) == ESP_OK &&
      id_len == POI_BEACON_ID_SIZE) {
    memcpy(s_beacon_config.beacon_id, stored_id, POI_BEACON_ID_SIZE);
  } else if (parse_status == POI_BEACON_OK) {
    /* Persist initial ID so identifier stays stable across reboots. */
    nvs_set_blob(nvs, POI_BEACON_NVS_KEY_ID, s_beacon_config.beacon_id,
                 POI_BEACON_ID_SIZE);
    nvs_commit(nvs);
  }

  uint8_t stored_flags = 0;
  if (nvs_get_u8(nvs, POI_BEACON_NVS_KEY_FLAGS, &stored_flags) == ESP_OK) {
    s_beacon_config.flags = stored_flags;
  }

  uint16_t stored_interval = 0;
  if (nvs_get_u16(nvs, POI_BEACON_NVS_KEY_INTERVAL_MS, &stored_interval) ==
      ESP_OK) {
    s_beacon_config.advertising_interval_ms = stored_interval;
  }

  int8_t stored_tx = 0;
  if (nvs_get_i8(nvs, POI_BEACON_NVS_KEY_TX_DBM, &stored_tx) == ESP_OK) {
    s_beacon_config.tx_power_dbm = stored_tx;
  }

  nvs_close(nvs);
}

static esp_err_t start_poi_beacon_advertising(void) {
  poi_beacon_status_t valid = poi_beacon_validate_config(&s_beacon_config);
  if (valid != POI_BEACON_OK) {
    ESP_LOGE(TAG,
             "Invalid POI-BEACON configuration (%s); refusing to start BLE "
             "advertising",
             poi_beacon_status_str(valid));
    return ESP_ERR_INVALID_ARG;
  }

  uint8_t pdu[POI_BEACON_ADV_PDU_SIZE];
  size_t pdu_len = 0;
  poi_beacon_status_t encode_status =
      poi_beacon_build_adv_pdu(&s_beacon_config, pdu, &pdu_len);
  if (encode_status != POI_BEACON_OK) {
    ESP_LOGE(TAG, "Failed to build advertising PDU: %s",
             poi_beacon_status_str(encode_status));
    return ESP_ERR_INVALID_ARG;
  }

  if (s_advertising_active || ble_gap_adv_active()) {
    int stop_rc = ble_gap_adv_stop();
    if (stop_rc != 0 && stop_rc != BLE_HS_EALREADY) {
      ESP_LOGW(TAG, "ble_gap_adv_stop returned rc=%d", stop_rc);
    }
    s_advertising_active = false;
  }

  esp_power_level_t pwr = map_tx_power_dbm(s_beacon_config.tx_power_dbm);
  esp_err_t pwr_err = esp_ble_tx_power_set(ESP_BLE_PWR_TYPE_ADV, pwr);
  if (pwr_err != ESP_OK) {
    ESP_LOGW(TAG, "esp_ble_tx_power_set failed (%s)", esp_err_to_name(pwr_err));
  }

  int rc = ble_gap_adv_set_data(pdu, (int)pdu_len);
  if (rc != 0) {
    ESP_LOGE(TAG, "ble_gap_adv_set_data failed (rc=%d)", rc);
    return ESP_FAIL;
  }

  struct ble_gap_adv_params adv_params;
  memset(&adv_params, 0, sizeof(adv_params));
  adv_params.conn_mode = BLE_GAP_CONN_MODE_NON;
  adv_params.disc_mode = BLE_GAP_DISC_MODE_GEN;
  uint16_t units =
      poi_beacon_ms_to_ble_units(s_beacon_config.advertising_interval_ms);
  adv_params.itvl_min = units;
  adv_params.itvl_max = units;

  rc = ble_gap_adv_start(s_own_addr_type, NULL, BLE_HS_FOREVER, &adv_params,
                         NULL, NULL);
  if (rc != 0) {
    ESP_LOGE(TAG, "ble_gap_adv_start failed (rc=%d)", rc);
    return ESP_FAIL;
  }

  s_advertising_active = true;
  status_led_set_rgb(0, 32, 0);

  char hex_id[POI_BEACON_ID_SIZE * 2U + 1U];
  poi_beacon_format_hex_id(s_beacon_config.beacon_id, hex_id, sizeof(hex_id));
  ESP_LOGI(TAG,
           "Advertising active | fw=%s | proto=v%u | flags=0x%02X | "
           "beaconId=%s | interval=%ums | tx=%ddBm",
           POI_BEACON_FIRMWARE_VERSION, s_beacon_config.protocol_version,
           s_beacon_config.flags, hex_id,
           s_beacon_config.advertising_interval_ms,
           s_beacon_config.tx_power_dbm);
  return ESP_OK;
}

static void on_ble_sync(void) {
  int rc = ble_hs_id_infer_auto(0, &s_own_addr_type);
  if (rc != 0) {
    ESP_LOGE(TAG, "ble_hs_id_infer_auto failed (rc=%d)", rc);
    return;
  }
  start_poi_beacon_advertising();
}

static void on_ble_reset(int reason) {
  s_advertising_active = false;
  status_led_set_rgb(0, 0, 0);
  ESP_LOGW(TAG, "BLE host reset (reason=%d); awaiting sync", reason);
}

static void nimble_host_task(void *param) {
  (void)param;
  nimble_port_run();
  nimble_port_freertos_deinit();
}

void app_main(void) {
  ESP_LOGI(TAG, "Booting Vienna POI-BEACON firmware v%s",
           POI_BEACON_FIRMWARE_VERSION);
  status_led_init();
  status_led_set_rgb(0, 0, 0);

  esp_err_t nvs_err = nvs_flash_init();
  if (nvs_err == ESP_ERR_NVS_NO_FREE_PAGES ||
      nvs_err == ESP_ERR_NVS_NEW_VERSION_FOUND) {
    ESP_ERROR_CHECK(nvs_flash_erase());
    nvs_err = nvs_flash_init();
  }
  if (nvs_err != ESP_OK) {
    ESP_LOGE(TAG, "NVS init failed (%s)", esp_err_to_name(nvs_err));
    return;
  }

  load_config_with_nvs_fallback();

  esp_err_t bt_err = nimble_port_init();
  if (bt_err != ESP_OK) {
    ESP_LOGE(TAG, "NimBLE init failed (%s)", esp_err_to_name(bt_err));
    return;
  }

  ble_hs_cfg.sync_cb = on_ble_sync;
  ble_hs_cfg.reset_cb = on_ble_reset;
  nimble_port_freertos_init(nimble_host_task);

  /* Periodic diagnostic heartbeat and controlled advertising watchdog. */
  while (true) {
    vTaskDelay(pdMS_TO_TICKS(30000));
    if (!ble_gap_adv_active() &&
        poi_beacon_validate_config(&s_beacon_config) == POI_BEACON_OK) {
      ESP_LOGW(TAG, "Advertising inactive; attempting controlled restart");
      start_poi_beacon_advertising();
    }
  }
}
