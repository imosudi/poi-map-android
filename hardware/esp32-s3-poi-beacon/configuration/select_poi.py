Import("env")
import configparser
import os

cfg_path = os.path.join(env.subst("$PROJECT_DIR"), "configuration", "poi_beacon_selection.ini")
if os.path.exists(cfg_path):
    parser = configparser.ConfigParser(inline_comment_prefixes=(";", "#"))
    parser.read(cfg_path)

    active_poi = parser.get("poi_selection", "active_poi", fallback="").strip()
    override_nvs = parser.get("poi_selection", "override_nvs", fallback="0").strip()

    defines = []
    # Only inject active_poi if the selected PlatformIO environment didn't already set POI_BEACON_ENV_ID_HEX.
    existing_flags = " ".join(str(f) for f in env.get("BUILD_FLAGS", []))
    if "POI_BEACON_ENV_ID_HEX" not in existing_flags and active_poi:
        beacon_id = parser.get("poi_presets", active_poi, fallback=active_poi).strip().lower()
        if len(beacon_id) == 16:
            defines.append(("POI_BEACON_BUILD_ID_HEX", f'\\"{beacon_id}\\"'))
            print(f"[POI-BEACON] Selected POI '{active_poi}' -> beaconId={beacon_id}")
        else:
            print(f"[POI-BEACON] Warning: invalid beaconId '{beacon_id}' for '{active_poi}', using Kconfig default")

    if override_nvs in ("1", "true", "yes"):
        defines.append(("POI_BEACON_OVERRIDE_NVS_ON_BOOT", "1"))

    if defines:
        env.Append(CPPDEFINES=defines)

