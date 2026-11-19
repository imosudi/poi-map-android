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
- `lib/features/poi/`, `lib/features/map/`, `lib/features/favourites/`: Layered `domain/`, `data/`, and `presentation/` modules with no cross-feature coupling.

See [Architecture](docs/architecture.md) and [Application Features](docs/application-features.md) for details.

## Data Source, Branding & Licensing

- **Data Source**: City of Vienna Open Government Data WFS (`ogdwien:SEHENSWUERDIGOGD`, EPSG:4326 GeoJSON, CC BY 4.0). See [Data Source](docs/data-source.md).
- **Branding**: Uses supplied Vienna POI Explorer assets in `assets/branding/`, `assets/icons/`, `assets/markers/`, and `assets/ui/` with a `#FAF7F2` / `#14264A` / `#D10A29` Material 3 palette. See [Branding Guide](docs/branding-guide.md).
- **Permissions**: Requests `INTERNET`, `ACCESS_FINE_LOCATION`, and `ACCESS_COARSE_LOCATION` for foreground positioning only (no background location tracking).

## Prerequisites & Configuration

- Flutter SDK `3.32.7+`, Dart `3.8.1+`, Android SDK (`ANDROID_HOME`), and JDK 11+.
- Add your Google Maps API key to `android/local.properties` (excluded from Git):

```properties
MAPS_API_KEY=your_google_maps_api_key
```

See [Development Guide](docs/development-guide.md) and [Android Configuration](docs/android-configuration.md).

## Running, Testing & Building

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter run
flutter build apk --release
```

See [Testing Guide](docs/testing-guide.md) and [Release Guide](docs/release-guide.md).

## Known Limitations

- `ogdwien:SEHENSWUERDIGOGD` does not provide a category attribute, so sight categories are derived from names via `PoiCategoryClassifier`.
- Release builds currently use the debug signing config in `android/app/build.gradle.kts` until a production keystore is configured.
- `integration_test/` is not yet populated; end-to-end flows are verified via offline widget tests.

## Licence

See [LICENSE](LICENSE) for details.
