# Vienna POI Explorer (`poi-map-android`)

A Flutter-based Android application for discovering Points of Interest (POIs) in Vienna, Austria, using Vienna Open Government Data (OGD).

## Features

- Searchable and filterable Vienna POI catalogue (`ogdwien:SEHENSWUERDIGOGD`).
- Interactive Google Maps view with location-aware distance calculation.
- Persistent favourite places.

## Prerequisites

- Flutter SDK (`3.32.x` or later) and Dart SDK (`3.8.x` or later).
- Android SDK (`ANDROID_HOME` configured) and Java Development Kit (JDK 11+).
- A Google Maps API key with **Maps SDK for Android** enabled.

## Configuration

Add your Google Maps API key to `android/local.properties` (ignored by Git):

```properties
MAPS_API_KEY=your_google_maps_api_key
```

Alternatively, export `MAPS_API_KEY` as an environment variable before building.

## Architecture

The codebase under `lib/` is organised into clear layer and feature boundaries:

- `lib/app/`: Application bootstrap (`bootstrap.dart`), Riverpod root providers (`providers.dart`), named routing and navigation shell (`router.dart`), Material 3 theme tokens (`theme/`), and root widget (`app.dart`).
- `lib/core/`: Shared, feature-agnostic infrastructure including environment configuration (`config/`), asset paths (`constants/`), exception hierarchy and error mapping (`errors/`), structured redacting logger (`logging/`), shared async state helpers (`state/`), and reusable UI states and attribution widgets (`widgets/`).
- `lib/features/poi/`: Vienna POI catalogue feature (`domain/`, `data/`, `presentation/`).
- `lib/features/map/`: Reserved for interactive map functionality (`presentation/`).
- `lib/features/favourites/`: Reserved for saved places functionality (`presentation/`).

Dependency direction: `app` wires `core` and `features`; `features` depend on `core` (and theme via `Theme.of(context)`) without cross-feature imports; `core` has no dependencies on `app` or `features`.

## Common Commands

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

## Licence

See [LICENSE](LICENSE) for details.
