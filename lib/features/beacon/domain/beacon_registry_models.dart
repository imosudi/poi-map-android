import '../../../core/errors/app_exception.dart';

/// A validated mapping from a hardware beacon identifier to a Vienna OGD POI ID.
final class BeaconRegistryEntry {
  const BeaconRegistryEntry({
    required this.beaconId,
    required this.poiId,
    this.poiName = '',
    this.label = '',
    this.enabled = true,
  });

  /// Canonical 16-character lowercase hex identifier from POI-BEACON v1.
  final String beaconId;

  /// Target Vienna OGD POI identifier (e.g., `SEHENSWUERDIGOGD.643871`).
  final String poiId;

  /// Optional exact POI name used as a fallback if OGD `OBJECTID`s rotate.
  final String poiName;

  /// Optional human-readable placement label.
  final String label;

  /// Whether this beacon mapping is currently active.
  final bool enabled;

  BeaconRegistryEntry copyWith({
    String? beaconId,
    String? poiId,
    String? poiName,
    String? label,
    bool? enabled,
  }) {
    return BeaconRegistryEntry(
      beaconId: beaconId ?? this.beaconId,
      poiId: poiId ?? this.poiId,
      poiName: poiName ?? this.poiName,
      label: label ?? this.label,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BeaconRegistryEntry &&
        other.beaconId == beaconId &&
        other.poiId == poiId &&
        other.poiName == poiName &&
        other.label == label &&
        other.enabled == enabled;
  }

  @override
  int get hashCode => Object.hash(beaconId, poiId, poiName, label, enabled);
}

/// Validates and normalises [BeaconRegistryEntry] records.
abstract final class BeaconRegistryValidator {
  static final RegExp _hex16Pattern = RegExp(r'^[0-9a-f]{16}$');

  /// Normalises a raw beacon identifier to trimmed lowercase hex.
  static String normaliseBeaconId(String raw) => raw.trim().toLowerCase();

  /// Returns a validated and normalised [BeaconRegistryEntry] or throws
  /// [BeaconRegistryException] when invalid.
  static BeaconRegistryEntry validate(BeaconRegistryEntry entry) {
    final beaconId = normaliseBeaconId(entry.beaconId);
    if (!_hex16Pattern.hasMatch(beaconId)) {
      throw BeaconRegistryException(
        'Invalid beacon ID "${entry.beaconId}": expected 16 hexadecimal characters.',
      );
    }
    if (beaconId == '0000000000000000' || beaconId == 'ffffffffffffffff') {
      throw BeaconRegistryException(
        'Beacon ID "$beaconId" uses a reserved sentinel value.',
      );
    }

    final poiId = entry.poiId.trim();
    if (poiId.isEmpty) {
      throw BeaconRegistryException(
        'POI ID for beacon "$beaconId" must not be empty.',
      );
    }

    return BeaconRegistryEntry(
      beaconId: beaconId,
      poiId: poiId,
      label: entry.label.trim(),
      enabled: entry.enabled,
    );
  }
}

/// Local registry mapping project-defined 8-byte beacon IDs to Vienna OGD POIs.
///
/// Guarantees unique beacon IDs while allowing multiple beacons to map to the
/// same [Poi.id].
final class BeaconRegistry {
  BeaconRegistry._({
    required Map<String, BeaconRegistryEntry> byBeaconId,
    required Map<String, List<BeaconRegistryEntry>> byPoiId,
  }) : _byBeaconId = Map.unmodifiable(byBeaconId),
       _byPoiId = Map.unmodifiable({
         for (final entry in byPoiId.entries)
           entry.key: List<BeaconRegistryEntry>.unmodifiable(entry.value),
       });

  factory BeaconRegistry.empty() {
    return BeaconRegistry._(
      byBeaconId: const <String, BeaconRegistryEntry>{},
      byPoiId: const <String, List<BeaconRegistryEntry>>{},
    );
  }

  /// Builds a validated [BeaconRegistry] from [entries], rejecting duplicates.
  factory BeaconRegistry.fromEntries(Iterable<BeaconRegistryEntry> entries) {
    final byBeaconId = <String, BeaconRegistryEntry>{};
    final byPoiId = <String, List<BeaconRegistryEntry>>{};

    for (final rawEntry in entries) {
      final entry = BeaconRegistryValidator.validate(rawEntry);
      if (byBeaconId.containsKey(entry.beaconId)) {
        throw BeaconRegistryException(
          'Duplicate beacon ID "${entry.beaconId}" in beacon registry.',
        );
      }
      byBeaconId[entry.beaconId] = entry;
      byPoiId
          .putIfAbsent(entry.poiId, () => <BeaconRegistryEntry>[])
          .add(entry);
    }

    return BeaconRegistry._(byBeaconId: byBeaconId, byPoiId: byPoiId);
  }

  final Map<String, BeaconRegistryEntry> _byBeaconId;
  final Map<String, List<BeaconRegistryEntry>> _byPoiId;

  List<BeaconRegistryEntry> get entries =>
      List<BeaconRegistryEntry>.unmodifiable(_byBeaconId.values);

  int get length => _byBeaconId.length;
  bool get isEmpty => _byBeaconId.isEmpty;

  /// Looks up a registered beacon by its 16-char hex [beaconId].
  ///
  /// Returns `null` when [beaconId] is unknown or (unless [includeDisabled] is
  /// `true`) disabled.
  BeaconRegistryEntry? findByBeaconId(
    String beaconId, {
    bool includeDisabled = false,
  }) {
    final normalised = BeaconRegistryValidator.normaliseBeaconId(beaconId);
    final entry = _byBeaconId[normalised];
    if (entry == null) return null;
    if (!includeDisabled && !entry.enabled) return null;
    return entry;
  }

  /// Returns all beacons mapped to [poiId] (supports multiple beacons per POI).
  List<BeaconRegistryEntry> findByPoiId(
    String poiId, {
    bool includeDisabled = false,
  }) {
    final list = _byPoiId[poiId.trim()];
    if (list == null) return const <BeaconRegistryEntry>[];
    if (includeDisabled) return list;
    return list.where((e) => e.enabled).toList(growable: false);
  }

  /// Returns a new [BeaconRegistry] with [entry] inserted or updated.
  BeaconRegistry withUpsertedEntry(BeaconRegistryEntry entry) {
    final validated = BeaconRegistryValidator.validate(entry);
    final updated = Map<String, BeaconRegistryEntry>.from(_byBeaconId);
    updated[validated.beaconId] = validated;
    return BeaconRegistry.fromEntries(updated.values);
  }

  /// Returns a new [BeaconRegistry] without [beaconId].
  BeaconRegistry withoutBeaconId(String beaconId) {
    final normalised = BeaconRegistryValidator.normaliseBeaconId(beaconId);
    if (!_byBeaconId.containsKey(normalised)) return this;
    final updated = Map<String, BeaconRegistryEntry>.from(_byBeaconId)
      ..remove(normalised);
    return BeaconRegistry.fromEntries(updated.values);
  }
}
