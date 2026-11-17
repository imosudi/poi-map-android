import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/repositories/poi_repository.dart';
import 'datasources/vienna_ogd_api_service.dart';
import 'repositories/remote_poi_repository.dart';

/// Provides the Vienna OGD API service.
final viennaOgdApiServiceProvider = Provider<ViennaOgdApiService>((ref) {
  return ViennaOgdApiService(
    dio: ref.watch(dioProvider),
    errorHandler: ref.watch(errorHandlerProvider),
  );
});

/// Provides the remote-backed [PoiRepository].
final poiRepositoryProvider = Provider<PoiRepository>((ref) {
  return RemotePoiRepository(
    apiService: ref.watch(viennaOgdApiServiceProvider),
    logger: ref.watch(appLoggerProvider),
  );
});
