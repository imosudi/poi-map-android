idf_component_register(
    SRCS "main.c" "poi_beacon_protocol.c"
    INCLUDE_DIRS "../include"
    REQUIRES bt nvs_flash esp_timer esp_driver_rmt
)

