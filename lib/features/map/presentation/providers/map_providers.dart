import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/map_config_service.dart';

final mapConfigServiceProvider = Provider<MapConfigService>((ref) {
  return const MapConfigService();
});

final mapApiKeyConfiguredProvider = FutureProvider<bool>((ref) {
  return ref.watch(mapConfigServiceProvider).isApiKeyConfigured();
});
