# Vienna POI Explorer (`poi-map-android`)

A Flutter-based Android application for discovering Points of Interest (POIs) in Vienna, Austria, powered by Vienna Open Government Data (`ogdwien:SEHENSWUERDIGOGD`).

## Capabilities

- **Vienna POI Catalogue**: Loads 63 Vienna sights on startup with lazy scrolling, case-insensitive name search, category chips, pull-to-refresh, and failure-safe refresh preservation.
- **Interactive Android Map**: Google Maps integration with category-styled markers, marker legend, single-selection detail card, foreground-only user location, and straight-line metric distance calculation.
- **Persistent Saved Places**: Local persistence (`SharedPreferences`) with duplicate prevention, offline snapshot fallback, synchronised state across all views, and confirmation-guarded individual removal.

## Technology Stack

- **Framework**: Flutter `3.32.7` / Dart `3.8.1` (Material 3)
- **State Management**: `flutter_riverpod`
- **Networking**: `dio` (WFS GeoJSON retrieval with timeouts and cancellation)
- **Maps & Location**: `google_maps_flutter`, `geolocator`
- **Local Persistence**: `shared_preferences`

## Architecture

- `lib/app/`: Application bootstrap, Riverpod root providers, named routing (`AppRouter`), navigation shell (`AppShell`), and Material 3 theme tokens.
- `lib/core/`: Environment configuration, structured redacting logger, centralised `ErrorHandler` / `AppException`, `DioFactory`, `CancellationToken`, and shared state views.
- `lib/features/poi/`, `lib/features/map/`, `lib/features/favourites/`, `lib/features/beacon/`, `lib/features/visited/`: Layered `domain/`, `data/`, and `presentation/` modules with no cross-feature coupling.

## Data Source, Branding & Licensing

- **Data Source**: City of Vienna Open Government Data WFS (`ogdwien:SEHENSWUERDIGOGD`, EPSG:4326 GeoJSON, CC BY 4.0).
- **Branding**: Custom icons, category markers, and banners are stored in `assets/branding/`, `assets/icons/`, `assets/markers/`, and `assets/ui/` with a `#FAF7F2` / `#14264A` / `#D10A29` Material 3 palette.
- **Permissions**: Requests `INTERNET`, `ACCESS_FINE_LOCATION`, and `ACCESS_COARSE_LOCATION` for foreground positioning only (no background location tracking).

## Prerequisites & Configuration

- Flutter SDK `3.32.7+`, Dart `3.8.1+`, Android SDK (`ANDROID_HOME`), and JDK 11+.
- Set `MAPS_API_KEY` in `android/local.properties`:

```properties
MAPS_API_KEY=google_maps_api_key
```

## Running, Testing & Building

### 1. Fork and Clone

1. Fork `imosudi/poi-map-android` on GitHub.
2. Clone the fork and enter the project directory:

```bash
git clone https://github.com/<username>/poi-map-android.git
cd poi-map-android
```

### 2. Android Application

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter run
flutter build apk --release
```

### 3. ESP32-S3 BLE Beacon Firmware

See [ESP32-S3 Firmware README](hardware/esp32-s3-poi-beacon/README.md) for hardware baseline and provisioning details.

```bash
cd hardware/esp32-s3-poi-beacon

# Host C protocol unit tests
gcc -std=c99 -Wall -Wextra -Werror -Iinclude firmware/poi_beacon_protocol.c test/test_poi_beacon_protocol.c -o /tmp/test_poi_beacon_protocol && /tmp/test_poi_beacon_protocol

# Build and flash via PlatformIO (ESP-IDF)
pio run --target upload --upload-port /dev/ttyUSB0
pio device monitor --port /dev/ttyUSB0 --baud 115200
```

## Known Limitations

- `ogdwien:SEHENSWUERDIGOGD` does not provide a category attribute, so sight categories are derived from names via `PoiCategoryClassifier`.
- Release builds currently use the debug signing config in `android/app/build.gradle.kts` until a production keystore is configured.

## Licence

See [LICENSE](LICENSE) for details.
